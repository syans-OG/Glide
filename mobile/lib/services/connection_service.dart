import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'bluetooth_service.dart';

enum ConnectionStatus { disconnected, connecting, connected, reconnecting }

enum TransportKind { wifi, bluetooth }

class ConnectionService extends ChangeNotifier {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  WebSocketChannel? _channel;
  final BluetoothService _bt = BluetoothService();
  TransportKind _transport = TransportKind.wifi;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  int _pingMs = 0;
  String _host = '192.168.1.100';
  int _port = 8765;
  String _authToken = '';
  String _lastError = '';
  String _lastErrorDetail = '';
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _missedPongs = 0;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  static const int _maxMissedPongs = 3;

  ConnectionStatus get status => _status;
  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isReconnecting => _status == ConnectionStatus.reconnecting;
  bool get isBluetooth => _transport == TransportKind.bluetooth;
  TransportKind get transport => _transport;
  BluetoothService get bluetooth => _bt;
  /// Machine-readable reason of the last failed attempt:
  /// '' | 'auth' | 'timeout' | 'unreachable' | 'bt-link' | 'bt-auth'.
  String get lastError => _lastError;
  /// Raw underlying error (truncated), shown to help diagnose failures.
  String get lastErrorDetail => _lastErrorDetail;

  String _shortErr(Object e) {
    final s = e.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }
  int get pingMs => _pingMs;
  String get host => _host;
  int get port => _port;

  Future<bool> connect(String ip, int port, {String token = ''}) async {
    _host = ip;
    _port = port;
    _authToken = token;
    _transport = TransportKind.wifi;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      final wsUrl = Uri.parse('ws://$ip:$port');
      _channel = WebSocketChannel.connect(wsUrl);

      // Connection timeout: 5 seconds
      await _channel!.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      // Send AUTH message
      _channel!.sink.add(jsonEncode({
        'type': 'AUTH',
        'token': token,
      }));

      // NOTE: WebSocketChannel.stream is single-subscription. Share one
      // broadcast view for the AUTH wait below and the message loop, or
      // the second listen throws "Bad state: Stream has already been
      // listened to" and the link drops right after AUTH_OK.
      final shared = _channel!.stream.asBroadcastStream();

      // Wait for AUTH response with timeout
      final authResponse = await shared.first
          .timeout(const Duration(seconds: 3), onTimeout: () {
        throw Exception('Auth response timeout');
      });

      final authData = jsonDecode(authResponse.toString());
      if (authData['type'] == 'AUTH_FAILURE') {
        debugPrint('[Auth] Failed: ${authData['reason']}');
        _channel?.sink.close();
        _channel = null;
        _status = ConnectionStatus.disconnected;
        _lastError = 'auth';
        _lastErrorDetail = 'AUTH_FAILURE: ${authData['reason']}';
        notifyListeners();
        return false;
      }

      if (authData['type'] != 'AUTH_OK') {
        debugPrint('[Auth] Unexpected response: ${authData['type']}');
        _channel?.sink.close();
        _channel = null;
        _status = ConnectionStatus.disconnected;
        _lastError = 'auth';
        notifyListeners();
        return false;
      }

      _status = ConnectionStatus.connected;
      _retryCount = 0;
      _missedPongs = 0;
      _lastError = '';
      _lastErrorDetail = '';
      notifyListeners();

      _listenMessages(shared);
      _startPingLoop();
      return true;
    } catch (e) {
      debugPrint('[Connection Error] $e');
      _channel?.sink.close();
      _channel = null;
      _lastErrorDetail = _shortErr(e);

      final msg = e.toString();
      if (msg.contains('Auth response timeout') ||
          msg.contains('Connection timeout')) {
        _lastError = 'timeout';
      } else {
        _lastError = 'unreachable';
      }

      // Auth failure = don't retry
      if (e.toString().contains('Invalid token') ||
          e.toString().contains('AUTH_FAILURE')) {
        _status = ConnectionStatus.disconnected;
        notifyListeners();
        return false;
      }

      // Other errors = attempt reconnect
      _status = ConnectionStatus.disconnected;
      notifyListeners();
      _attemptReconnect();
      return false;
    }
  }

  /// Connect over Classic Bluetooth SPP to the desktop host at [address]
  /// (MAC, e.g. "00:11:22:AA:BB:CC"). [token] is the 6-digit pairing code
  /// shown on the laptop's Bluetooth panel — fully offline, no QR needed.
  Future<bool> connectBluetooth(String address, {String token = ''}) async {
    _transport = TransportKind.bluetooth;
    _authToken = token;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    _bt.onMessage = _handleIncoming;
    _bt.onDisconnected = _handleBtDisconnect;

    final ok = await _bt.connect(address, token: token);
    if (ok) {
      _status = ConnectionStatus.connected;
      _lastError = '';
      _lastErrorDetail = '';
      _retryCount = 0;
      _missedPongs = 0;
      notifyListeners();
      _startPingLoop();
      return true;
    }
    _status = ConnectionStatus.disconnected;
    _lastError = _bt.lastError.isNotEmpty ? _bt.lastError : 'bt-link';
    _lastErrorDetail = _bt.lastErrorDetail;
    _transport = TransportKind.wifi;
    notifyListeners();
    return false;
  }

  void _handleBtDisconnect() {
    if (_transport != TransportKind.bluetooth) return;
    debugPrint('[Bluetooth] Link lost');
    _pingTimer?.cancel();
    _transport = TransportKind.wifi;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
    // No auto-reconnect on Bluetooth: user re-taps the device.
  }

  void _listenMessages(Stream<dynamic> stream) {
    stream.listen(
      (message) {
        _handleIncoming(message.toString());
      },
      onDone: () {
        debugPrint('[WebSocket] Connection closed by server');
        _handleDisconnect();
      },
      onError: (err) {
        debugPrint('[WebSocket Stream Error] $err');
        _handleDisconnect();
      },
    );
  }

  /// Shared inbound handler for both transports (Wi-Fi frames and BT lines).
  void _handleIncoming(String message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'PONG') {
        final sentTime = data['timestamp'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;
        _pingMs = (now - sentTime).clamp(1, 999);
        _missedPongs = 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Parse Error] $e');
    }
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _channel = null;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
    _attemptReconnect();
  }

  void _startPingLoop() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (isConnected) {
        _missedPongs++;
        if (_missedPongs >= _maxMissedPongs) {
          debugPrint('[Connection] Missed $_missedPongs pongs, reconnecting...');
          _handleDisconnect();
          return;
        }
        sendPing();
      }
    });
  }

  void _attemptReconnect() {
    if (_retryCount >= _maxRetries) {
      debugPrint('[Reconnect] Max retries reached');
      _status = ConnectionStatus.disconnected;
      notifyListeners();
      return;
    }

    _status = ConnectionStatus.reconnecting;
    notifyListeners();

    final delay = Duration(seconds: (1 << _retryCount).clamp(1, 30));
    _retryCount++;

    debugPrint('[Reconnect] Attempt $_retryCount/$_maxRetries in ${delay.inSeconds}s');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_status == ConnectionStatus.reconnecting) {
        final success = await connect(_host, _port, token: _authToken);
        if (!success && _status != ConnectionStatus.connected) {
          _attemptReconnect();
        }
      }
    });
  }

  void sendPing() {
    if (!isConnected) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _sendRaw({'type': 'PING', 'timestamp': now});
  }

  void sendKey(String code) {
    _sendRaw({'type': 'KEY', 'code': code});
  }

  void sendMouseMove(double dx, double dy) {
    _sendRaw({
      'type': 'MOUSE_MOVE',
      'dx': dx,
      'dy': dy,
    });
  }

  void sendMouseClick(String button) {
    _sendRaw({
      'type': 'MOUSE_CLICK',
      'button': button.toUpperCase(),
    });
  }

  void sendMouseScroll(double dy) {
    _sendRaw({
      'type': 'MOUSE_SCROLL',
      'dy': dy,
    });
  }

  void sendPointer(double x, double y, {String mode = 'laser', double radius = 120}) {
    _sendRaw({
      'type': 'PTR',
      'x': x.clamp(0.0, 1.0),
      'y': y.clamp(0.0, 1.0),
      'mode': mode,
      'radius': radius,
    });
  }

  void sendPointerOff() {
    _sendRaw({'type': 'PTR_OFF'});
  }

  void _sendRaw(Map<String, dynamic> data) {
    if (_status != ConnectionStatus.connected) return;
    if (_transport == TransportKind.bluetooth) {
      _bt.send(data).catchError((e) {
        debugPrint('[BT Send Error] $e');
        _handleBtDisconnect();
      });
      return;
    }
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (e) {
        debugPrint('[Send Error] $e');
      }
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _retryCount = _maxRetries; // Prevent auto-reconnect
    _channel?.sink.close();
    _channel = null;
    _bt.disconnect();
    _transport = TransportKind.wifi;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  void reconnect() {
    _retryCount = 0;
    _reconnectTimer?.cancel();
    connect(_host, _port, token: _authToken);
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
