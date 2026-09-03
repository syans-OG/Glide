use futures_util::{SinkExt, StreamExt};
use tokio_tungstenite::tungstenite::Message;

/// A bidirectional message channel (WebSocket or Bluetooth RFCOMM).
/// Both transports emit/consume newline-delimited JSON text frames.
#[async_trait::async_trait]
pub trait MessageTransport: Send + 'static {
    /// Send a JSON string to the peer.
    async fn send_text(&mut self, text: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
    /// Receive the next JSON string (None on close/EOF).
    async fn recv_text(&mut self) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>>;
}

/// WebSocket-backed transport. Wraps the joined sender+receiver split.
pub struct WebSocketTransport {
    sender: futures_util::stream::SplitSink<
        tokio_tungstenite::WebSocketStream<tokio::net::TcpStream>,
        Message,
    >,
    receiver: futures_util::stream::SplitStream<
        tokio_tungstenite::WebSocketStream<tokio::net::TcpStream>,
    >,
}

impl WebSocketTransport {
    pub fn new(
        ws: tokio_tungstenite::WebSocketStream<tokio::net::TcpStream>,
    ) -> Self {
        let (sender, receiver) = ws.split();
        Self { sender, receiver }
    }
}

#[async_trait::async_trait]
impl MessageTransport for WebSocketTransport {
    async fn send_text(
        &mut self,
        text: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.sender
            .send(Message::Text(text.to_string().into()))
            .await?;
        Ok(())
    }

    async fn recv_text(
        &mut self,
    ) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        loop {
            match self.receiver.next().await {
                Some(Ok(Message::Text(text))) => return Ok(Some(text.to_string())),
                Some(Ok(Message::Close(_))) | None => return Ok(None),
                Some(Ok(Message::Ping(p))) => {
                    // Send Pong for liveness.
                    let _ = self.sender.send(Message::Pong(p)).await;
                    continue;
                }
                Some(Ok(_)) => continue,
                Some(Err(err)) => {
                    return Err(Box::new(std::io::Error::new(
                        std::io::ErrorKind::Other,
                        format!("{}", err),
                    )))
                }
            }
        }
    }
}
