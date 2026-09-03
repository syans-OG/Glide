import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:bluetooth_serial_android/bluetooth_serial_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Classic Bluetooth SPP (RFCOMM) link to the Glide desktop host.
///
/// The desktop advertises the standard Serial Port Profile, so we connect
/// with the default SPP UUID. Messages are the same newline-delimited JSON
/// protocol as the Wi-Fi/WebSocket transport.
class BluetoothService {
  static const String sppUuid = '00001101-0000-1000-8000-00805F9B34FB';

  bool _connected = false;
  bool _reading = false;
  String _address = '';
  String _lastError = '';
  String _lastErrorDetail = '';

  bool get isConnected => _connected;
  String get address => _address;
  /// '' | 'bt-link' (RFCOMM failed) | 'bt-auth' (AUTH rejected/timeout).
  String get lastError => _lastError;
  String get lastErrorDetail => _lastErrorDetail;

  /// Lines received from the peer (without the trailing newline).
  void Function(String line)? onMessage;

  /// Called when the link drops (remote close or write failure).
  void Function()? onDisconnected;

  Future<bool> ensurePermissions() async {
    try {
      return await FlutterBluetoothSerial.ensurePermissions();
    } catch (e) {
      debugPrint('[BT] ensurePermissions failed: $e');
      return false;
    }
  }

  Future<List<Map<String, String>>> bondedDevices() async {
    try {
      return await FlutterBluetoothSerial.getPairedDevices();
    } catch (e) {
      debugPrint('[BT] getPairedDevices failed: $e');
      return [];
    }
  }

  /// One-shot discovery; returns the devices found when the scan ends.
  Future<List<Map<String, String>>> scanDevices() async {
    try {
      return await FlutterBluetoothSerial.scanDevices();
    } catch (e) {
      debugPrint('[BT] scanDevices failed: $e');
      return [];
    }
  }

  /// Open the RFCOMM link and run the AUTH handshake. Returns true only
  /// after the desktop replies AUTH_OK.
  Future<bool> connect(String address, {String token = ''}) async {
    _address = address;
    _lastError = 'bt-link';
    try {
      final ok = await FlutterBluetoothSerial.connect(
        address,
        uuid: sppUuid,
        timeoutMs: 8000,
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => false,
      );
      if (!ok) {
        debugPrint('[BT] RFCOMM connect returned false for $address');
        _lastErrorDetail = 'RFCOMM connect -> false';
        return false;
      }
      _connected = true;

      // AUTH handshake (same protocol as WebSocket).
      // NOTE: the trailing newline is the frame delimiter — without it
      // the desktop keeps waiting for end-of-line and never replies,
      // surfacing here as "auth response timeout".
      _lastError = 'bt-auth';
      await write("${jsonEncode({'type': 'AUTH', 'token': token})}\n");
      final resp = await FlutterBluetoothSerial.readLine('\n').timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (resp == null) {
        debugPrint('[BT] AUTH response timeout');
        _lastErrorDetail = 'AUTH response timeout';
        await disconnect();
        return false;
      }
      try {
        final data = jsonDecode(resp.trim());
        if (data is Map && data['type'] == 'AUTH_OK') {
          debugPrint('[BT] AUTH_OK, link ready');
          _startReadLoop();
          return true;
        }
        debugPrint('[BT] AUTH rejected: ${data is Map ? data['type'] : resp}');
        _lastErrorDetail = 'AUTH rejected: ${data is Map ? data['type'] : resp}';
      } catch (e) {
        debugPrint('[BT] Bad AUTH response: $e');
        final s = e.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
        _lastErrorDetail = s.length > 120 ? '${s.substring(0, 120)}…' : s;
      }
      await disconnect();
      return false;
    } catch (e) {
      debugPrint('[BT] connect failed: $e');
      final s = e.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      _lastErrorDetail = s.length > 120 ? '${s.substring(0, 120)}…' : s;
      await disconnect();
      return false;
    }
  }

  /// Send one protocol message (newline-terminated JSON).
  Future<void> send(Map<String, dynamic> data) async {
    if (!_connected) throw StateError('BT not connected');
    try {
      await FlutterBluetoothSerial.write('${jsonEncode(data)}\n');
    } catch (e) {
      _connected = false;
      onDisconnected?.call();
      rethrow;
    }
  }

  Future<void> write(String raw) async {
    if (!_connected) throw StateError('BT not connected');
    await FlutterBluetoothSerial.write(raw);
  }

  void _startReadLoop() {
    if (_reading) return;
    _reading = true;
    () async {
      while (_reading && _connected) {
        try {
          final line = await FlutterBluetoothSerial.readLine('\n');
          if (line == null) continue; // read timeout: link idle
          final text = line.trim();
          if (text.isEmpty) continue;
          try {
            onMessage?.call(text);
          } catch (e) {
            debugPrint('[BT] onMessage handler error: $e');
          }
        } catch (e) {
          debugPrint('[BT] read loop ended: $e');
          break;
        }
      }
      _reading = false;
      if (_connected) {
        _connected = false;
        onDisconnected?.call();
      }
    }();
  }

  static const String _prefsLastName = 'bt_last_name';
  static const String _prefsLastAddr = 'bt_last_addr';

  /// The last successfully connected laptop, if any.
  Future<Map<String, String>?> lastDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addr = prefs.getString(_prefsLastAddr) ?? '';
      if (addr.isEmpty) return null;
      return {
        'name': prefs.getString(_prefsLastName) ?? '',
        'address': addr,
      };
    } catch (e) {
      debugPrint('[BT] lastDevice: $e');
      return null;
    }
  }

  Future<void> saveLastDevice(String name, String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsLastName, name);
      await prefs.setString(_prefsLastAddr, address);
    } catch (e) {
      debugPrint('[BT] saveLastDevice: $e');
    }
  }

  Future<void> disconnect() async {
    _reading = false;
    _connected = false;
    try {
      await FlutterBluetoothSerial.disconnect();
    } catch (e) {
      debugPrint('[BT] disconnect: $e');
    }
  }
}
