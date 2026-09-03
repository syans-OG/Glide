# Glide — Development Roadmap

> Offline Presentation Remote Controller  
> Tauri 2 Desktop + Flutter Mobile  

---

## Phase 1 — Security & Reliability

### 1.1 WebSocket Authentication
- [x] Generate random token on desktop app start
- [x] Embed token in QR code payload (`{ip, port, ws_url, token}`)
- [x] Mobile sends token in first message after connect
- [x] Server validates token, rejects unauthorized connections
- [x] Show clear error on mobile if auth fails
- **Files:** `server.rs`, `lib.rs`, `connection_service.dart`, `pairing_screen.dart`

### 1.2 WebSocket Reconnection
- [x] Add connection timeout on `await _channel!.ready` (5s default)
- [x] Implement missed-pong detection (3 unanswered pings = dead)
- [x] Auto-reconnect with exponential backoff (1s → 2s → 4s → 8s, max 5 attempts)
- [x] Show reconnecting state in mobile UI header
- [ ] Resume last mode (laser/touchpad) after reconnect
- **Files:** `connection_service.dart`, `controller_screen.dart`

### 1.3 Content Security Policy
- [x] Set proper CSP in `tauri.conf.json` (currently `null`)
- [x] Allow only `self` for scripts, styles, and connections
- **Files:** `tauri.conf.json`

### 1.4 Server Bind Failure Surfacing
- [x] Emit Tauri event when WebSocket server fails to bind
- [x] Frontend shows error state instead of infinite "waiting"
- [x] Log port number and suggest alternatives
- **Files:** `lib.rs`, `main.js`

---

## Phase 2 — Code Health

### 2.1 Split `controller_screen.dart`
- [ ] Extract `VolumeSheet` → `widgets/volume_sheet.dart`
- [ ] Extract `SettingsSheet` → `widgets/settings_sheet.dart`
- [ ] Extract `GestureGuideSheet` → `widgets/gesture_guide_sheet.dart`
- [ ] Extract `ControllerHeader` → `widgets/controller_header.dart`
- [ ] Extract `BottomDeckControls` → `widgets/bottom_deck_controls.dart`
- [ ] Extract `LandscapeThumbTrigger` → `widgets/landscape_thumb_trigger.dart`
- [ ] Extract `BottomSheetScaffold` (shared chrome) → `widgets/bottom_sheet_scaffold.dart`
- [ ] Target: `controller_screen.dart` shrinks to ~150 lines (state + build only)
- **Files:** `controller_screen.dart` → 7 new files in `widgets/`

### 2.2 Fix Overlay Canvas DPI Scaling
- [x] Reset transform before applying DPI scale: `ctx.setTransform(1,0,0,1,0,0)`
- [x] Only run animation loop when overlay is active
- [x] Stop loop 500ms after deactivation
- **Files:** `overlay.js`

### 2.3 Complete WebSocket Protocol
- [x] Send `STATUS` message on connect (server_version, capabilities) → `AUTH_OK`
- [x] Add `ERROR` message type for malformed/unsupported messages → `AUTH_FAILURE`
- **Files:** `server.rs`, `connection_service.dart`

### 2.4 Complete Tauri IPC Key Mapping
- [x] Map all 17 `KeyAction` variants in `simulate_key_command`
- [x] Missing: VolUp, VolDown, Mute, PlayPause, MediaNext, MediaPrev, TaskView, ShowDesktop, AppSwitchRight, AppSwitchLeft, Search
- **Files:** `lib.rs`

### 2.5 Fix Silent Error Swallowing
- [x] Replace `catch (_) {}` in `connection_service.dart` with logging
- [x] Proper error handling in Rust `let _ =` patterns
- **Files:** `connection_service.dart`, `lib.rs`

### 2.6 Fix Double-Click Blocking
- [x] Kept synchronous (acceptable for 50ms one-off delay)
- [x] Fixed `mouseData` cast (`as i32` → proper `as u32`)
- **Files:** `input.rs`

---

## Phase 3 — Features

### 3.1 Bluetooth Classic SPP Transport (implemented 2026-09-03)
- [x] Desktop (Windows): WinRT RFCOMM SPP server (`RfcommServiceProvider` +
  `StreamSocketListener`) sharing `handle_connection` via `MessageTransport`
  (`desktop/src-tauri/src/bluetooth.rs`); own 6-digit pairing code shown on
  the laptop BT panel (fully offline — no QR/Wi-Fi needed)
- [x] Desktop UI: Bluetooth tab unhidden (`index.html`), `bluetooth-status`
  listener + adapter status line (`main.js`, `styles.css`)
- [x] Mobile (Android): `bluetooth_serial_android` (^1.1.2) client —
  `BluetoothService` (AUTH handshake, line-framed JSON, read loop),
  `ConnectionService` routes all sends over active transport
  (`lib/services/bluetooth_service.dart`, `connection_service.dart`)
- [x] Mobile UI: functional Bluetooth tab (permissions, bonded list, scan,
  tap-to-connect) in `pairing_screen.dart`
- [x] Android: BLUETOOTH/SCAN/CONNECT + `ACCESS_FINE_LOCATION` permissions,
  `minSdk = 26` (`AndroidManifest.xml`, `build.gradle.kts`)
- [x] Verified: `cargo check` clean, `flutter analyze` clean
- [ ] Still to verify on hardware: Windows↔Android pairing, SDP discovery,
  AUTH over RFCOMM, sustained touchpad/laser latency
- **Files:** `bluetooth.rs`, `transport.rs`, `server.rs`, `lib.rs`,
  `Cargo.toml`, `index.html`, `main.js`, `styles.css`, `bluetooth_service.dart`,
  `connection_service.dart`, `pairing_screen.dart`, `pubspec.yaml`,
  `AndroidManifest.xml`, `build.gradle.kts`
- **Dropped:** `bluetooth-rust` (does not compile on Windows),
  `flutter_bluetooth_serial` (dead, SDK <3.0.0); raw Win32 `WSASetService`
  path abandoned (buggy `BTH_SET_SERVICE` binding) — see `BLUETOOTH_PLAN.md`

### 3.2 Slide Preview on Phone
- [ ] Desktop: capture active window screenshot periodically (2-3fps)
- [ ] Send thumbnails over WebSocket (compressed JPEG)
- [ ] Mobile: display in a collapsible preview panel
- [ ] Pinch-to-zoom on preview
- **Files:** New Rust capture module, `server.rs`, `connection_service.dart`, new mobile widget

### 3.3 Speaker Notes View
- [ ] Desktop: extract notes from PowerPoint via COM automation or clipboard
- [ ] Send notes text to mobile on slide change
- [ ] Mobile: scrollable notes panel below/above touchpad
- [ ] Auto-scroll to current position
- **Files:** New Rust notes module, `server.rs`, new mobile screen

### 3.4 Pen / Annotation Mode
- [ ] Add `PEN` KeyAction → sends `Ctrl+P` (PowerPoint pen mode)
- [ ] Add `ERASER` KeyAction → sends `Ctrl+E`
- [ ] Add mobile toggle button for pen mode
- [ ] When pen mode active, touchpad draws annotations on screen
- **Files:** `input.rs`, `server.rs`, `controller_screen.dart`

### 3.5 Error Boundary
- [ ] Add `FlutterError.onError` handler in `main.dart`
- [ ] Add `ErrorWidget.builder` for graceful crash UI
- [ ] Log errors to crash reporting (optional)
- **Files:** `main.dart`

### 3.6 Theme Persistence
- [ ] Save theme preference to `shared_preferences`
- [ ] Load on app start
- [ ] **Files:** `main.dart`, `pubspec.yaml` (add dependency)

### 3.7 Connection Quality Indicator
- [ ] Replace raw latency number with quality label (Excellent/Good/Poor)
- [ ] Color-code: green (<50ms), yellow (50-150ms), red (>150ms)
- [ ] Show disconnect warning snackbar
- **Files:** `controller_screen.dart`, `connection_service.dart`

### 3.8 Configurable Auto-Minimize
- [ ] Add setting toggle for auto-minimize on connect
- [ ] Add setting toggle for auto-restore on disconnect
- [ ] Default: enabled (current behavior)
- **Files:** `main.js`, `main.rs` (new command), settings UI

---

## Phase 4 — Polish & Cleanup

### 4.1 Delete Unused Files
- [ ] Remove 9 duplicate SVGs from `desktop/src/` (keep only `logo_official.svg`)
- [ ] Move `logo_showcase.html` to `docs/` or delete
- [ ] Remove `scripts/test.png`
- **Files:** `src/logo_lockup*.svg`, `src/logo_concept_*.svg`, `logo_showcase.html`

### 4.2 Remove Unused Dependencies
- [ ] Remove `cupertino_icons` from `pubspec.yaml` (~1MB savings)
- [ ] Remove `path_provider_android` override from `pubspec.yaml`
- [ ] Remove `@tauri-apps/plugin-shell` from `package.json` (unused in frontend)
- [ ] Remove `tray-icon` feature from `Cargo.toml` if tray not planned
- **Files:** `pubspec.yaml`, `package.json`, `Cargo.toml`

### 4.3 Clean Dead Code
- [ ] Remove 7 unused `AppColors` constants in `app_theme.dart`
- [ ] Remove unused `@tauri-apps/plugin-shell` import if present
- **Files:** `app_theme.dart`, `package.json`

### 4.4 README
- [ ] Write setup instructions (desktop + mobile)
- [ ] Add screenshots / GIF demo
- [ ] Document supported features
- [ ] Add build from source instructions
- **Files:** `README.md`

### 4.5 i18n Foundation
- [ ] Extract all Indonesian strings to a constants file
- [ ] Add English translations
- [ ] Set up basic locale switching (or default to English)
- **Files:** New `i18n/` directory, `main.js`, `index.html`

### 4.6 Single Instance Lock
- [ ] Add Tauri single-instance plugin
- [ ] Show existing window if user tries to launch second instance
- **Files:** `tauri.conf.json`, `lib.rs`

### 4.7 Overlay Animation Optimization
- [x] Only run `requestAnimationFrame` loop when pointer is active
- [x] Stop loop after fade-out completes
- [x] Clean `trailHistory` on deactivation
- **Files:** `overlay.js`

---

## Future Considerations

| Feature | Effort | Priority |
|---|---|---|
| macOS input simulation (`core-graphics`) | High | Medium |
| Linux input simulation (`uinput`/`xdotool`) | High | Medium |
| mDNS/Bonjour auto-discovery (no manual IP) | Medium | Medium |
| Customizable button layout on phone | Medium | Low |
| Multi-presenter support | High | Low |
| Bluetooth transport (actual implementation) | High | Low |
| Keyboard shortcut customization | Medium | Low |
| Timer with countdown (not just count-up) | Low | Low |

---

*Last updated: 2026-09-02*
