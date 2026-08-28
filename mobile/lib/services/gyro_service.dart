import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'connection_service.dart';

class GyroService extends ChangeNotifier {
  static final GyroService _instance = GyroService._internal();
  factory GyroService() => _instance;
  GyroService._internal();

  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  final ConnectionService _connection = ConnectionService();

  double _x = 0.5;
  double _y = 0.5;
  double _sensitivity = 1.6;
  bool _isAiming = false;
  String _currentMode = 'laser';
  final double _spotlightRadius = 130.0;

  // Anti-jitter low-pass parameters
  static const double _deadzone = 0.035; // rad/s
  static const double _alpha = 0.75; // EMA smoothing factor
  double _filteredDx = 0.0;
  double _filteredDy = 0.0;

  double get x => _x;
  double get y => _y;
  double get sensitivity => _sensitivity;
  bool get isAiming => _isAiming;
  String get currentMode => _currentMode;

  void setSensitivity(double value) {
    _sensitivity = value.clamp(0.5, 4.0);
    notifyListeners();
  }

  void setMode(String mode) {
    _currentMode = mode;
    notifyListeners();
  }

  void startAiming({String? mode}) {
    if (mode != null) _currentMode = mode;
    _isAiming = true;
    notifyListeners();

    _gyroSubscription?.cancel();
    _gyroSubscription = gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (GyroscopeEvent event) {
        if (!_isAiming) return;

        // In portrait orientation:
        // event.z is yaw (horizontal rotation) -> maps to x
        // event.x is pitch (vertical tilt) -> maps to y
        double rawDx = -event.z * 0.02 * _sensitivity;
        double rawDy = -event.x * 0.02 * _sensitivity;

        // Deadzone check for trembling hands
        if (rawDx.abs() < _deadzone * 0.02) rawDx = 0.0;
        if (rawDy.abs() < _deadzone * 0.02) rawDy = 0.0;

        // Exponential Low-Pass Filter
        _filteredDx = _filteredDx * (1 - _alpha) + rawDx * _alpha;
        _filteredDy = _filteredDy * (1 - _alpha) + rawDy * _alpha;

        _x = (_x + _filteredDx).clamp(0.02, 0.98);
        _y = (_y + _filteredDy).clamp(0.02, 0.98);

        _connection.sendPointer(
          _x,
          _y,
          mode: _currentMode,
          radius: _spotlightRadius,
        );
      },
      onError: (err) {
        debugPrint('[Gyro Error] $err');
      },
    );
  }

  void stopAiming() {
    _isAiming = false;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
    _connection.sendPointerOff();
    notifyListeners();
  }

  void reCenter() {
    _x = 0.5;
    _y = 0.5;
    _filteredDx = 0.0;
    _filteredDy = 0.0;
    if (_isAiming) {
      _connection.sendPointer(_x, _y, mode: _currentMode, radius: _spotlightRadius);
    }
    notifyListeners();
  }

  // Update coordinate directly from Touchpad gesture
  void updateFromTouchpadDelta(double dx, double dy) {
    _x = (_x + dx * 0.003 * _sensitivity).clamp(0.02, 0.98);
    _y = (_y + dy * 0.003 * _sensitivity).clamp(0.02, 0.98);

    _connection.sendPointer(
      _x,
      _y,
      mode: _currentMode,
      radius: _spotlightRadius,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    stopAiming();
    super.dispose();
  }
}
