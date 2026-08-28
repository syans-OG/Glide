import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class ConnectionService extends ChangeNotifier {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  WebSocketChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  int _pingMs = 0;
  String _host = '192.168.1.100';
  int _port = 8765;
  Timer? _pingTimer;

  ConnectionStatus get status => _status;
  bool get isConnected => _status == ConnectionStatus.connected;
  int get pingMs => _pingMs;
  String get host => _host;
  int get port => _port;

  Future<bool> connect(String ip, int port) async {
    _host = ip;
    _port = port;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      final wsUrl = Uri.parse('ws://$ip:$port');
      _channel = WebSocketChannel.connect(wsUrl);

      await _channel!.ready;
      _status = ConnectionStatus.connected;
      notifyListeners();

      _listenMessages();
      _startPingLoop();
      return true;
    } catch (e) {
      debugPrint('[Connection Error] $e');
      _status = ConnectionStatus.disconnected;
      notifyListeners();
      return false;
    }
  }

  void _listenMessages() {
    _channel?.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message.toString());
          if (data['type'] == 'PONG') {
            final sentTime = data['timestamp'] as int;
            final now = DateTime.now().millisecondsSinceEpoch;
            _pingMs = (now - sentTime).clamp(1, 999);
            notifyListeners();
          }
        } catch (_) {}
      },
      onDone: () {
        disconnect();
      },
      onError: (err) {
        debugPrint('[WebSocket Stream Error] $err');
        disconnect();
      },
    );
  }

  void _startPingLoop() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (isConnected) {
        sendPing();
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
    if (_channel != null && _status == ConnectionStatus.connected) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (e) {
        debugPrint('[Send Error] $e');
      }
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
