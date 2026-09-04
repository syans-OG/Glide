# Security Policy

## Supported versions

Security fixes are provided for the latest published Glide release.

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0.0 | :x:                |

---

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub Security Advisories:

1. Open the repository's **Security** tab.
2. Select **Advisories** and **Report a vulnerability**.
3. Include affected versions, reproduction steps, impact, and any suggested mitigation.

Do not disclose an unpatched vulnerability in a public issue or discussion. Please do not include private tokens, pairing codes, personal paths, or sensitive data in a report.

Reports concerning session token authentication bypass, WebSocket/RFCOMM transport injection, input simulation abuse, local network exposure, QR pairing interception, or Tauri CSP bypasses are especially helpful.

---

## Scope notes

Glide is a 100% offline, peer-to-peer presentation remote for Windows + Android:

- **No Telemetry or Analytics:** Glide does not collect, store, or transmit your presentation data, keystrokes, or control inputs.
- **No Hosted Accounts or Cloud Database:** All communication is direct between your laptop and phone over local Wi-Fi (WebSocket) or Bluetooth Classic (SPP). Session tokens are random per launch and never leave your devices.
- **System Permissions:** Low-level OS access is limited to cursor movement and simulated keystrokes for presentation control (`SendInput`) and a canvas overlay for the laser pointer.
- Third-party model providers, upstream Tauri/Flutter changes, and Windows/Android platform policy updates are outside the project's direct control.
