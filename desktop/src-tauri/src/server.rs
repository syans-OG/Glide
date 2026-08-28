use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use tauri::{AppHandle, Emitter, Manager};
use tokio::net::{TcpListener, TcpStream};
use tokio_tungstenite::tungstenite::Message;

use crate::input::{simulate_key, KeyAction};

static CONNECTED_CLIENTS: AtomicUsize = AtomicUsize::new(0);

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum IncomingMessage {
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

    #[serde(rename = "STATUS")]
    Status {
        connected: bool,
        server_version: String,
    },
}

#[derive(Debug, Clone, Serialize)]
pub struct DeviceEvent {
    pub client_count: usize,
    pub remote_addr: String,
}

pub async fn start_server(app_handle: AppHandle, port: u16) -> Result<(), Box<dyn std::error::Error>> {
    let addr = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&addr).await?;
    println!("[WebSocket Server] Listening on ws://{}", addr);

    let app = Arc::new(app_handle);

    tokio::spawn(async move {
        while let Ok((stream, remote_addr)) = listener.accept().await {
            let app_clone = app.clone();
            tokio::spawn(handle_connection(stream, remote_addr, app_clone));
        }
    });

    Ok(())
}

async fn handle_connection(stream: TcpStream, remote_addr: SocketAddr, app: Arc<AppHandle>) {
    let ws_stream = match tokio_tungstenite::accept_async(stream).await {
        Ok(ws) => ws,
        Err(err) => {
            eprintln!("[WebSocket] Handshake failed with {}: {:?}", remote_addr, err);
            return;
        }
    };

    let count = CONNECTED_CLIENTS.fetch_add(1, Ordering::SeqCst) + 1;
    let _ = app.emit(
        "device-status",
        DeviceEvent {
            client_count: count,
            remote_addr: remote_addr.to_string(),
        },
    );

    println!("[WebSocket] Client connected from {} (Total: {})", remote_addr, count);

    let (mut ws_sender, mut ws_receiver) = ws_stream.split();

    while let Some(msg_result) = ws_receiver.next().await {
        match msg_result {
            Ok(Message::Text(text)) => {
                if let Ok(incoming) = serde_json::from_str::<IncomingMessage>(&text) {
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
                                let _ = ws_sender.send(Message::Text(pong_text)).await;
                            }
                        }
                    }
                }
            }
            Ok(Message::Binary(_)) => {}
            Ok(Message::Close(_)) => break,
            Ok(Message::Ping(p)) => {
                let _ = ws_sender.send(Message::Pong(p)).await;
            }
            Ok(Message::Pong(_)) => {}
            Ok(Message::Frame(_)) => {}
            Err(err) => {
                eprintln!("[WebSocket] Error from {}: {:?}", remote_addr, err);
                break;
            }
        }
    }

    let count = CONNECTED_CLIENTS.fetch_sub(1, Ordering::SeqCst) - 1;
    let _ = app.emit(
        "device-status",
        DeviceEvent {
            client_count: count,
            remote_addr: String::new(),
        },
    );

    println!("[WebSocket] Client disconnected {} (Total: {})", remote_addr, count);
}
