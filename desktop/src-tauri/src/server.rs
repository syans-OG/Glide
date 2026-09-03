use serde::Serialize;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use tauri::{AppHandle, Emitter, Manager};
use tokio::net::TcpListener;

use crate::input::simulate_key;
use crate::transport::{MessageTransport, WebSocketTransport};

static CONNECTED_CLIENTS: AtomicUsize = AtomicUsize::new(0);

pub mod protocol {
    use serde::{Deserialize, Serialize};

    use crate::input::KeyAction;

    #[derive(Debug, Clone, Serialize, Deserialize)]
    #[serde(tag = "type")]
    pub enum IncomingMessage {
        #[serde(rename = "AUTH")]
        Auth { token: String },

        #[serde(rename = "KEY")]
        Key { code: KeyAction },

        #[serde(rename = "MOUSE_MOVE")]
        MouseMove { dx: f64, dy: f64 },

        #[serde(rename = "MOUSE_CLICK")]
        MouseClick { button: String },

        #[serde(rename = "MOUSE_SCROLL")]
        MouseScroll { dy: f64 },

        #[serde(rename = "PTR")]
        Pointer {
            x: f64,
            y: f64,
            #[serde(default = "default_laser_mode")]
            mode: String,
            #[serde(default)]
            radius: Option<f64>,
        },

        #[serde(rename = "PTR_OFF")]
        PointerOff,

        #[serde(rename = "PING")]
        Ping { timestamp: i64 },
    }

    fn default_laser_mode() -> String {
        "laser".to_string()
    }

    #[derive(Debug, Clone, Serialize, Deserialize)]
    #[serde(tag = "type")]
    pub enum OutgoingMessage {
        #[serde(rename = "PONG")]
        Pong { timestamp: i64 },

        #[serde(rename = "AUTH_OK")]
        AuthOk { server_version: String },

        #[serde(rename = "AUTH_FAILURE")]
        AuthFailure { reason: String },
    }
}

use protocol::{IncomingMessage, OutgoingMessage};

#[derive(Debug, Clone, Serialize)]
pub struct TransportEvent {
    pub transport: String,
    pub client_count: usize,
    pub remote_addr: String,
}

/// Connection label used for logging/events.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum TransportKind {
    WebSocket,
    Bluetooth,
}

impl TransportKind {
    pub fn label(&self) -> &'static str {
        match self {
            TransportKind::WebSocket => "WebSocket",
            TransportKind::Bluetooth => "Bluetooth",
        }
    }
}

pub async fn start_server(
    app_handle: AppHandle,
    port: u16,
    auth_token: String,
) -> Result<(), Box<dyn std::error::Error>> {
    let addr = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&addr).await?;
    println!("[WebSocket Server] Listening on ws://{}", addr);

    let app = Arc::new(app_handle);
    let token = Arc::new(auth_token);

    tokio::spawn(async move {
        while let Ok((stream, remote_addr)) = listener.accept().await {
            let app_clone = app.clone();
            let token_clone = token.clone();
            tokio::spawn(async move {
                let ws = match tokio_tungstenite::accept_async(stream).await {
                    Ok(ws) => ws,
                    Err(err) => {
                        eprintln!(
                            "[WebSocket] Handshake failed with {}: {:?}",
                            remote_addr, err
                        );
                        return;
                    }
                };
                let transport = WebSocketTransport::new(ws);
                handle_connection(
                    transport,
                    remote_addr.to_string(),
                    app_clone,
                    token_clone,
                    TransportKind::WebSocket,
                )
                .await;
            });
        }
    });

    Ok(())
}

/// Shared connection handler: authenticates the peer, then dispatches
/// protocol messages to `input`/overlay. Transport-agnostic.
pub async fn handle_connection<T: MessageTransport>(
    mut transport: T,
    peer_label: String,
    app: Arc<AppHandle>,
    expected_token: Arc<String>,
    kind: TransportKind,
) {
    let label = kind.label();

    // ----- AUTH handshake -----
    loop {
        let text = match transport.recv_text().await {
            Ok(Some(text)) => text,
            Ok(None) => return,
            Err(err) => {
                eprintln!("[{}] Error during auth from {}: {:?}", label, peer_label, err);
                return;
            }
        };

        if let Ok(IncomingMessage::Auth { token }) =
            serde_json::from_str::<IncomingMessage>(&text)
        {
            if token == *expected_token {
                let ok_msg = OutgoingMessage::AuthOk {
                    server_version: "1.0".to_string(),
                };
                if let Ok(ok_text) = serde_json::to_string(&ok_msg) {
                    let _ = transport.send_text(&ok_text).await;
                }
                break;
            } else {
                eprintln!("[{}] AUTH rejected (invalid token) from {}", label, peer_label);
                let fail_msg = OutgoingMessage::AuthFailure {
                    reason: "Invalid token".to_string(),
                };
                if let Ok(fail_text) = serde_json::to_string(&fail_msg) {
                    let _ = transport.send_text(&fail_text).await;
                }
                return;
            }
        } else {
            eprintln!("[{}] AUTH rejected (first message not AUTH) from {}", label, peer_label);
            let fail_msg = OutgoingMessage::AuthFailure {
                reason: "First message must be AUTH".to_string(),
            };
            if let Ok(fail_text) = serde_json::to_string(&fail_msg) {
                let _ = transport.send_text(&fail_text).await;
            }
            return;
        }
    }

    let count = CONNECTED_CLIENTS.fetch_add(1, Ordering::SeqCst) + 1;
    let _ = app.emit(
        "device-status",
        TransportEvent {
            transport: label.to_string(),
            client_count: count,
            remote_addr: peer_label.clone(),
        },
    );

    println!(
        "[{}] Client authenticated from {} (Total: {})",
        label, peer_label, count
    );

    // ----- Post-auth message loop -----
    loop {
        let msg = match transport.recv_text().await {
            Ok(Some(text)) => text,
            Ok(None) => break,
            Err(_) => break,
        };

        if let Ok(incoming) = serde_json::from_str::<IncomingMessage>(&msg) {
            match incoming {
                IncomingMessage::Key { code } => {
                    simulate_key(code);
                }
                IncomingMessage::MouseMove { dx, dy } => {
                    crate::input::simulate_mouse_move(dx.round() as i32, dy.round() as i32);
                }
                IncomingMessage::MouseClick { button } => {
                    crate::input::simulate_mouse_click(&button);
                }
                IncomingMessage::MouseScroll { dy } => {
                    crate::input::simulate_mouse_scroll(dy.round() as i32);
                }
                IncomingMessage::Pointer { x, y, mode, radius } => {
                    if let Some(overlay) = app.get_webview_window("overlay") {
                        let _ = overlay.show();
                    }
                    let _ = app.emit(
                        "pointer-event",
                        serde_json::json!({
                            "active": true,
                            "x": x,
                            "y": y,
                            "mode": mode,
                            "radius": radius.unwrap_or(100.0)
                        }),
                    );
                }
                IncomingMessage::PointerOff => {
                    let _ = app.emit(
                        "pointer-event",
                        serde_json::json!({ "active": false }),
                    );
                    let app_clone = app.clone();
                    tokio::spawn(async move {
                        tokio::time::sleep(tokio::time::Duration::from_millis(300)).await;
                        if let Some(overlay) = app_clone.get_webview_window("overlay") {
                            let _ = overlay.hide();
                        }
                    });
                }
                IncomingMessage::Ping { timestamp } => {
                    let pong = OutgoingMessage::Pong { timestamp };
                    if let Ok(pong_text) = serde_json::to_string(&pong) {
                        let _ = transport.send_text(&pong_text).await;
                    }
                }
                IncomingMessage::Auth { .. } => {
                    // Ignore re-auth attempts
                }
            }
        }
    }

    let count = CONNECTED_CLIENTS.fetch_sub(1, Ordering::SeqCst) - 1;
    let _ = app.emit(
        "device-status",
        TransportEvent {
            transport: label.to_string(),
            client_count: count,
            remote_addr: String::new(),
        },
    );

    println!(
        "[{}] Client disconnected {} (Total: {})",
        label, peer_label, count
    );
}
