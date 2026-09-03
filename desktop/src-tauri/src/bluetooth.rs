// Bluetooth Classic SPP (RFCOMM) server for Windows.
//
// The desktop advertises a Serial Port Profile (SPP) over the local Bluetooth
// adapter using the WinRT APIs (`RfcommServiceProvider` +
// `StreamSocketListener`), which handle the RFCOMM / SDP / discoverability
// machinery — no hand-built SDP records required. The serial-port service
// class is the standard SPP UUID, so an Android client connects with
// `createInsecureRfcommSocketToServiceRecord(SPP_UUID)`.
//
// Accepted sockets are wrapped in `BluetoothTransport`, which speaks the same
// newline-delimited JSON protocol as the WebSocket transport, so
// `handle_connection` stays transport-agnostic.
//
// Pattern follows the proven `btclip` project (windows 0.62 WinRT APIs).

use std::future::IntoFuture;
use std::sync::Arc;
use tauri::{AppHandle, Emitter};

use windows::core::Ref;
use windows::Devices::Bluetooth::Rfcomm::{RfcommServiceId, RfcommServiceProvider};
use windows::Foundation::TypedEventHandler;
use windows::Networking::Sockets::{
    StreamSocket, StreamSocketListener, StreamSocketListenerConnectionReceivedEventArgs,
};
use windows::Storage::Streams::{DataReader, DataWriter, InputStreamOptions};

use crate::server::{handle_connection, TransportKind};
use crate::transport::MessageTransport;

const PROFILE_NAME: &str = "Glide Presentation Remote";

// ---------------------------------------------------------------------------
// BluetoothTransport
// ---------------------------------------------------------------------------
//
// Wraps an accepted RFCOMM stream, framing messages as newline-delimited JSON
// (a trailing `\n` marks the end of a message). Holds the `StreamSocket` so
// the connection stays alive as long as the transport does.
pub struct BluetoothTransport {
    _socket: StreamSocket,
    reader: DataReader,
    writer: DataWriter,
}

impl BluetoothTransport {
    pub fn new(socket: StreamSocket) -> Result<Self, String> {
        let input_stream = socket
            .InputStream()
            .map_err(|e| format!("get InputStream failed: {:?}", e))?;
        let output_stream = socket
            .OutputStream()
            .map_err(|e| format!("get OutputStream failed: {:?}", e))?;

        let reader = DataReader::CreateDataReader(&input_stream)
            .map_err(|e| format!("create DataReader failed: {:?}", e))?;
        reader
            .SetInputStreamOptions(InputStreamOptions::Partial)
            .map_err(|e| format!("set input options failed: {:?}", e))?;

        let writer = DataWriter::CreateDataWriter(&output_stream)
            .map_err(|e| format!("create DataWriter failed: {:?}", e))?;

        Ok(BluetoothTransport {
            _socket: socket,
            reader,
            writer,
        })
    }
}

#[async_trait::async_trait]
impl MessageTransport for BluetoothTransport {
    async fn send_text(
        &mut self,
        text: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let mut payload = text.as_bytes().to_vec();
        payload.push(b'\n');
        self.writer
            .WriteBytes(&payload)
            .map_err(|e| Box::new(std::io::Error::other(format!("BT write: {:?}", e)))
                as Box<dyn std::error::Error + Send + Sync>)?;
        self.writer
            .StoreAsync()
            .map_err(|e| Box::new(std::io::Error::other(format!("BT store: {:?}", e)))
                as Box<dyn std::error::Error + Send + Sync>)?
            .into_future()
            .await
            .map_err(|e| Box::new(std::io::Error::other(format!("BT flush: {:?}", e)))
                as Box<dyn std::error::Error + Send + Sync>)?;
        Ok(())
    }

    async fn recv_text(
        &mut self,
    ) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        let mut pending: Vec<u8> = Vec::new();
        let mut chunk = vec![0u8; 4096];
        loop {
            let loaded = self
                .reader
                .LoadAsync(4096)
                .map_err(|e| Box::new(std::io::Error::other(format!("BT load: {:?}", e)))
                    as Box<dyn std::error::Error + Send + Sync>)?
                .into_future()
                .await
                .map_err(|e| Box::new(std::io::Error::other(format!("BT load wait: {:?}", e)))
                    as Box<dyn std::error::Error + Send + Sync>)?;
            if loaded == 0 {
                // Peer closed the connection.
                return Ok(None);
            }
            let read = &mut chunk[..loaded as usize];
            self.reader
                .ReadBytes(read)
                .map_err(|e| Box::new(std::io::Error::other(format!("BT read: {:?}", e)))
                    as Box<dyn std::error::Error + Send + Sync>)?;
            pending.extend_from_slice(read);
            if let Some(pos) = pending.iter().position(|&b| b == b'\n') {
                let line: Vec<u8> = pending.drain(..=pos).collect();
                let text = String::from_utf8_lossy(&line[..line.len() - 1])
                    .trim_end_matches('\r')
                    .to_string();
                return Ok(Some(text));
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Status events for the frontend
// ---------------------------------------------------------------------------
#[derive(Debug, Clone, serde::Serialize)]
pub struct BluetoothStatusEvent {
    pub adapter_name: Option<String>,
    pub discoverable: bool,
    pub connected: bool,
    pub error: Option<String>,
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------

struct BluetoothServer {
    _provider: RfcommServiceProvider,
    _listener: StreamSocketListener,
}

/// Start the Bluetooth RFCOMM server. Non-fatal: if Bluetooth is unavailable,
/// emits a status event and returns so the rest of the app still works.
pub async fn start_bluetooth_server(app: AppHandle, auth_token: String) {
    let (server, mut rx) = match setup_server().await {
        Ok(res) => res,
        Err(e) => {
            eprintln!("[Bluetooth] Failed to start: {}", e);
            let _ = app.emit(
                "bluetooth-status",
                BluetoothStatusEvent {
                    adapter_name: None,
                    discoverable: false,
                    connected: false,
                    error: Some(e),
                },
            );
            return;
        }
    };
    // Keep provider + listener alive for the process lifetime.
    let _server = server;

    let adapter_name = Some(PROFILE_NAME.to_string());
    let _ = app.emit(
        "bluetooth-status",
        BluetoothStatusEvent {
            adapter_name: adapter_name.clone(),
            discoverable: true,
            connected: false,
            error: None,
        },
    );

    let app = Arc::new(app);
    let token = Arc::new(auth_token);

    while let Some(socket) = rx.recv().await {
        let _ = app.emit(
            "bluetooth-status",
            BluetoothStatusEvent {
                adapter_name: adapter_name.clone(),
                discoverable: true,
                connected: true,
                error: None,
            },
        );

        match BluetoothTransport::new(socket) {
            Ok(transport) => {
                let app_clone = app.clone();
                let token_clone = token.clone();
                let name_for_event = adapter_name.clone();
                tokio::spawn(async move {
                    handle_connection(
                        transport,
                        "Bluetooth-client".to_string(),
                        app_clone.clone(),
                        token_clone,
                        TransportKind::Bluetooth,
                    )
                    .await;
                    let _ = app_clone.emit(
                        "bluetooth-status",
                        BluetoothStatusEvent {
                            adapter_name: name_for_event,
                            discoverable: true,
                            connected: false,
                            error: None,
                        },
                    );
                });
            }
            Err(e) => {
                eprintln!("[Bluetooth] Could not wrap accepted stream: {}", e);
            }
        }
    }
}

/// Create the SPP provider + listener, attach the accept handler, bind, and
/// begin advertising. Returns the server (must stay alive) plus a channel of
/// accepted sockets.
async fn setup_server(
) -> Result<(BluetoothServer, tokio::sync::mpsc::Receiver<StreamSocket>), String> {
    let service_id = RfcommServiceId::SerialPort()
        .map_err(|e| format!("create SerialPort service id failed: {:?}", e))?;

    let provider = RfcommServiceProvider::CreateAsync(&service_id)
        .map_err(|e| format!("RfcommServiceProvider::CreateAsync failed: {:?}", e))?
        .into_future()
        .await
        .map_err(|e| format!("initialize RfcommServiceProvider failed: {:?}", e))?;

    let listener = StreamSocketListener::new()
        .map_err(|e| format!("create StreamSocketListener failed: {:?}", e))?;

    let (tx, rx) = tokio::sync::mpsc::channel::<StreamSocket>(8);
    let handler_tx = tx.clone();
    listener
        .ConnectionReceived(&TypedEventHandler::new(
            move |_sender, args: Ref<StreamSocketListenerConnectionReceivedEventArgs>| {
                if let Some(args) = args.as_ref() {
                    if let Ok(socket) = args.Socket() {
                        // Handler runs on a WinRT thread: use blocking_send.
                        let _ = handler_tx.blocking_send(socket);
                    }
                }
                Ok(())
            },
        ))
        .map_err(|e| format!("register connection handler failed: {:?}", e))?;

    let service_name = provider
        .ServiceId()
        .map_err(|e| format!("get ServiceId failed: {:?}", e))?
        .AsString()
        .map_err(|e| format!("ServiceId to string failed: {:?}", e))?;

    listener
        .BindServiceNameAsync(&service_name)
        .map_err(|e| format!("bind listener failed: {:?}", e))?
        .into_future()
        .await
        .map_err(|e| format!("complete listener bind failed: {:?}", e))?;

    provider
        .StartAdvertisingWithRadioDiscoverability(&listener, true)
        .map_err(|e| format!("StartAdvertising failed: {:?}", e))?;

    println!(
        "[Bluetooth] SPP '{}' advertising ({})",
        PROFILE_NAME, service_name
    );

    Ok((
        BluetoothServer {
            _provider: provider,
            _listener: listener,
        },
        rx,
    ))
}
