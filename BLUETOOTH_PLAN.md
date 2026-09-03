# Glide Bluetooth Implementation Plan

## Decision Log

| Decision | Rationale |
|---|---|
| Bluetooth Classic SPP (not BLE) | Throughput untuk touchpad/laser pointer |
| Windows + Android only (Phase 1) | Most common presentasi setup |
| Approach A: Separate servers | Clean separation, protocol reuse |
| Tab-based UX (improved) | Transparent, user control, familiar |
| Auth token over Bluetooth | Same security model as WiFi |

## Architecture

```
Desktop (Rust):
┌─────────────────────────────────────┐
│         message_handler             │
│    (transport-agnostic dispatch)    │
│  ┌──────────────┐ ┌──────────────┐ │
│  │ WiFi Server  │ │ BT Server    │ │
│  │ (WS :8765)   │ │ (RFCOMM)     │ │
│  └──────────────┘ └──────────────┘ │
│              ▼                     │
│      input::simulate_*()           │
└─────────────────────────────────────┘

Mobile (Flutter):
┌─────────────────────────────────────┐
│       ConnectionService             │
│   (transport-agnostic interface)    │
│  ┌──────────────┐ ┌──────────────┐ │
│  │ WiFi Client  │ │ BT Client    │ │
│  │ (WebSocket)  │ │ (RFCOMM)     │ │
│  └──────────────┘ └──────────────┘ │
│              ▼                     │
│      sendKey / sendPointer / ...   │
└─────────────────────────────────────┘
```

## Implementation Phases

### Phase 1: Transport Abstraction (Rust)
- [ ] Create `Transport` trait in new `transport.rs`
- [ ] Refactor `handle_connection` to be generic over `Transport`
- [ ] Wrap existing WebSocket as `WebSocketTransport`
- [ ] All existing tests still pass

### Phase 2: Bluetooth Server (Rust - Windows)
- [ ] Add `bluetooth-serial-port` crate to Cargo.toml
- [ ] Create `bluetooth.rs` with RFCOMM server
- [ ] Implement `BluetoothTransport` using RFCOMM stream
- [ ] Start BT server alongside WS server in `lib.rs`
- [ ] Desktop shows BT device name + discoverable status

### Phase 3: Bluetooth Client (Flutter - Android)
- [ ] Add `flutter_bluetooth_serial` to pubspec.yaml
- [ ] Create `bluetooth_service.dart` with scan/connect
- [ ] Implement `BluetoothTransport` using RFCOMM socket
- [ ] Update `ConnectionService` to support both transports
- [ ] Add Android BLUETOOTH permissions

### Phase 4: UI Integration
- [ ] Desktop: Show Bluetooth tab with device name + status
- [ ] Mobile: Bluetooth tab with device scanner
- [ ] Connection flow: scan → select → pair → auth → done
- [ ] Header shows "BT" indicator when connected via Bluetooth

### Phase 5: Polish
- [ ] Auto-reconnect over Bluetooth
- [ ] Connection quality indicator for BT
- [ ] Error handling: permission denied, BT off, pair failed
- [ ] Fallback: if BT fails, suggest WiFi

## Key Files to Create/Modify

| File | Action |
|---|---|
| `desktop/src-tauri/src/transport.rs` | NEW - Transport trait |
| `desktop/src-tauri/src/bluetooth.rs` | NEW - BT RFCOMM server |
| `desktop/src-tauri/src/server.rs` | MODIFY - generic handle_connection |
| `desktop/src-tauri/src/lib.rs` | MODIFY - start BT server |
| `desktop/src-tauri/Cargo.toml` | MODIFY - add bluetooth crate |
| `mobile/lib/services/bluetooth_service.dart` | NEW - BT client |
| `mobile/lib/services/connection_service.dart` | MODIFY - transport abstraction |
| `mobile/lib/ui/pairing_screen.dart` | MODIFY - BT scanner UI |
| `mobile/pubspec.yaml` | MODIFY - add flutter_bluetooth_serial |

## Rust Bluetooth Crate Options

| Crate | Status | Notes |
|---|---|---|
| `bluetooth-serial-port` | Maintained | RFCOMM SPP, Windows/Linux |
| `btleplug` | Active | BLE only, not Classic |
| `windows` crate BT APIs | Native | Very verbose, low-level |
| `bluer` | Active | Linux only (BlueZ) |

**Recommendation:** `bluetooth-serial-port` for Phase 1 (Windows RFCOMM).
For Android, `flutter_bluetooth_serial` handles RFCOMM natively.

## Risk Assessment

| Risk | Mitigation |
|---|---|
| `bluetooth-serial-port` may have issues | Fallback to raw Win32 BT APIs |
| Android BT permission UX confusing | Clear permission request flow |
| BT latency too high for laser | Profile and optimize; fall back to WiFi |
| Windows BT discoverability issues | Manual pairing via PIN as fallback |
