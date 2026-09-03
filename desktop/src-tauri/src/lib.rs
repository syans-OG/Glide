#[cfg(target_os = "windows")]
mod bluetooth;
mod input;
mod server;
mod transport;

use local_ip_address::local_ip;
use tauri::{AppHandle, Emitter, Manager};

const SERVER_PORT: u16 = 8765;

fn generate_auth_token() -> String {
    const CHARS: &[u8] = b"abcdefghijklmnopqrstuvwxyz0123456789";
    let mut token = String::with_capacity(24);
    for _ in 0..24 {
        let idx = (std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .subsec_nanos() as usize
            + token.len() * 31)
            % CHARS.len();
        token.push(CHARS[idx] as char);
    }
    token
}

/// Tokens enforced by the servers. Wi-Fi uses the long QR token; Bluetooth
/// uses a short pairing code shown on the laptop's Bluetooth panel so the
/// phone can connect fully offline (no QR/Wi-Fi needed) by typing 6 digits.
struct AppTokens {
    wifi_token: String,
    bt_code: String,
}

fn generate_pairing_code() -> String {
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .subsec_nanos();
    let code = (nanos ^ nanos.wrapping_div(1000)) % 10_000;
    format!("{:04}", code)
}

#[tauri::command]
fn get_connection_info(
    tokens: tauri::State<'_, AppTokens>,
) -> Result<serde_json::Value, String> {
    let ip = local_ip()
        .map(|addr| addr.to_string())
        .unwrap_or_else(|_| "127.0.0.1".to_string());

    let hostname = std::env::var("COMPUTERNAME")
        .or_else(|_| std::env::var("HOSTNAME"))
        .unwrap_or_else(|_| "Presentation Host".to_string());

    Ok(serde_json::json!({
        "ip": ip,
        "port": SERVER_PORT,
        "ws_url": format!("ws://{}:{}", ip, SERVER_PORT),
        "hostname": hostname,
        // Served via command (not window.eval) so the frontend can never
        // observe a missing/stale token due to page-load races.
        "token": tokens.wifi_token.clone(),
        "bt_code": tokens.bt_code.clone()
    }))
}

#[tauri::command]
fn open_bluetooth_settings() -> Result<(), String> {
    #[cfg(target_os = "windows")]
    {
        let _ = std::process::Command::new("cmd")
            .args(["/c", "start", "ms-settings:bluetooth"])
            .spawn();
    }
    Ok(())
}

#[tauri::command]
fn simulate_key_command(code: String) -> Result<(), String> {
    let action = match code.to_uppercase().as_str() {
        "NEXT" => input::KeyAction::Next,
        "PREV" => input::KeyAction::Prev,
        "PLAY" => input::KeyAction::Play,
        "PLAYPAUSE" => input::KeyAction::PlayPause,
        "EXIT" => input::KeyAction::Exit,
        "BLACK" => input::KeyAction::Black,
        "WHITE" => input::KeyAction::White,
        "VOLUP" => input::KeyAction::VolUp,
        "VOLDOWN" => input::KeyAction::VolDown,
        "MUTE" => input::KeyAction::Mute,
        "MEDIANEXT" => input::KeyAction::MediaNext,
        "MEDIAPREV" => input::KeyAction::MediaPrev,
        "TASKVIEW" => input::KeyAction::TaskView,
        "SHOWDESKTOP" => input::KeyAction::ShowDesktop,
        "APPSWITCHRIGHT" => input::KeyAction::AppSwitchRight,
        "APPSWITCHLEFT" => input::KeyAction::AppSwitchLeft,
        "SEARCH" => input::KeyAction::Search,
        _ => return Err(format!("Unknown key code: {}", code)),
    };

    input::simulate_key(action);
    Ok(())
}

#[tauri::command]
fn set_overlay_visibility(app: AppHandle, visible: bool) -> Result<(), String> {
    if let Some(overlay) = app.get_webview_window("overlay") {
        if visible {
            let _ = overlay.show();
        } else {
            let _ = overlay.hide();
        }
    }
    Ok(())
}

/// Exits the entire application (all windows + background servers), not just
/// the main window. Required because closing only the main window leaves the
/// overlay window alive and keeps the process (and terminal) running.
#[tauri::command]
fn exit_app(app: AppHandle) {
    app.exit(0);
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            get_connection_info,
            open_bluetooth_settings,
            simulate_key_command,
            set_overlay_visibility,
            exit_app
        ])
        .setup(|app| {
            let handle = app.handle().clone();
            let auth_token = generate_auth_token();
            let bt_code = generate_pairing_code();
            // Publish the tokens via managed state so get_connection_info
            // always returns the exact values the servers enforce.
            // (Replaces the old window.eval approach, which raced page load
            // and could leave the QR encoding an empty/stale token.)
            handle.manage(AppTokens {
                wifi_token: auth_token.clone(),
                bt_code: bt_code.clone(),
            });
            // Bluetooth enforces its own short pairing code (fully offline).
            #[cfg(target_os = "windows")]
            let bt_token = bt_code.clone();

            // Start WebSocket Server
            let handle_clone = handle.clone();
            let err_handle = handle.clone();
            tauri::async_runtime::spawn(async move {
                if let Err(err) = server::start_server(handle_clone, SERVER_PORT, auth_token).await {
                    eprintln!("[Server Error] Failed to start WebSocket: {:?}", err);
                    let _ = err_handle.emit("server-error", format!("{}", err));
                }
            });

            // Start Bluetooth Server (desktop only)
            #[cfg(target_os = "windows")]
            {
                let bt_handle = handle.clone();
                tauri::async_runtime::spawn(async move {
                    bluetooth::start_bluetooth_server(bt_handle, bt_token).await;
                });
            }

            if let Some(overlay_win) = app.get_webview_window("overlay") {
                let _ = overlay_win.set_ignore_cursor_events(true);

                #[cfg(target_os = "windows")]
                {
                    use windows::Win32::Foundation::HWND;
                    use windows::Win32::UI::WindowsAndMessaging::{
                        GetWindowLongPtrW, SetWindowLongPtrW, GWL_EXSTYLE, WS_EX_LAYERED, WS_EX_TRANSPARENT,
                    };

                    if let Ok(hwnd) = overlay_win.hwnd() {
                        unsafe {
                            let hwnd = HWND(hwnd.0 as _);
                            let ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
                            SetWindowLongPtrW(
                                hwnd,
                                GWL_EXSTYLE,
                                ex_style | (WS_EX_TRANSPARENT.0 as isize) | (WS_EX_LAYERED.0 as isize),
                            );
                        }
                    }
                }
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running presentation desktop host");
}
