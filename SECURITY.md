# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

Only the latest release on the `main` branch receives security updates.

## Reporting a Vulnerability

If you discover a security vulnerability, please **do not** open a public issue.

Instead, report it privately:

- **Email:** 123starsquad@gmail.com
- **Subject:** `[Glide Security] <brief description>`

Please include:

- A clear description of the vulnerability and its impact
- Steps to reproduce (PoC, logs, or screenshots if applicable)
- Affected component (`desktop` / `mobile` / `transport` / `auth`) and version/commit

You can expect:

- **Acknowledgement** within 72 hours
- **Assessment and fix timeline** within 7 days for confirmed issues
- **Coordinated disclosure** — we will credit you in the fix notes if you wish, unless you prefer to remain anonymous

## Security Considerations

Glide is an **offline, peer-to-peer** remote. It has no cloud account, no central server, and no data collection.

- **Session authentication:** the desktop app generates a random per-session token at startup and embeds it in the QR/Bluetooth handshake. The server rejects any WebSocket/RFCOMM connection that does not present the correct token in its first message.
- **Local network only:** the desktop WebSocket server binds to the local network, and Bluetooth Classic (SPP) is device-to-device. No traffic leaves your devices.
- **Least-privilege Tauri capabilities:** frontend-to-Rust IPC is restricted to the declared capabilities in `desktop/src-tauri/capabilities/`, and the webview CSP is locked to `self`.
- **No secrets in repository:** no API keys, tokens, or keystores are committed. All auth material is ephemeral and generated at runtime.

If you are deploying Glide in an untrusted network environment, treat the LAN as the trust boundary and keep the QR/pairing code private for the duration of the session (it rotates on every app restart).

## Disclosure Policy

We follow coordinated disclosure. Once a fix is available, we will publish a GitHub Security Advisory and a patched release. Please allow us time to prepare the fix before any public disclosure.

Thank you for helping keep Glide and its users safe.
