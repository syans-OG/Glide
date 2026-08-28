mod input;
mod server;

use local_ip_address::local_ip;
use tauri::{AppHandle, Manager};

const SERVER_PORT: u16 = 8765;

#[tauri::command]
fn get_connection_info() -> Result<serde_json::Value, String> {
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
        "hostname": hostname
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
        "EXIT" => input::KeyAction::Exit,
        "BLACK" => input::KeyAction::Black,
        "WHITE" => input::KeyAction::White,
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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            get_connection_info,
            open_bluetooth_settings,
            simulate_key_command,
            set_overlay_visibility
        ])
        .setup(|app| {
            let handle = app.handle().clone();

            // Start WebSocket Server
            tauri::async_runtime::spawn(async move {
                if let Err(err) = server::start_server(handle, SERVER_PORT).await {
                    eprintln!("[Server Error] Failed to start WebSocket: {:?}", err);
                }
            });

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
