import 'package:shared_preferences/shared_preferences.dart';

/// Persists user-adjustable controller preferences so they survive app
/// restarts and reconnects (touch sensitivity, gyro sensitivity, input mode).
class SettingsService {
  static const String _keyTouch = 'settings_touch_sensitivity';
  static const String _keyGyro = 'settings_gyro_sensitivity';
  static const String _keyGyroForLaser = 'settings_gyro_for_laser';
  static const String _keySpotlight = 'settings_spotlight_mode';

  /// Defaults matching the in-app initial values.
  static const double defaultTouchSensitivity = 1.3;
  static const double defaultGyroSensitivity = 1.6;

  Future<SharedPreferences> _prefs() async {
    return SharedPreferences.getInstance();
  }

  Future<double> touchSensitivity() async {
    final prefs = await _prefs();
    return prefs.getDouble(_keyTouch) ?? defaultTouchSensitivity;
  }

  Future<void> saveTouchSensitivity(double value) async {
    final prefs = await _prefs();
    await prefs.setDouble(_keyTouch, value);
  }

  Future<double> gyroSensitivity() async {
    final prefs = await _prefs();
    return prefs.getDouble(_keyGyro) ?? defaultGyroSensitivity;
  }

  Future<void> saveGyroSensitivity(double value) async {
    final prefs = await _prefs();
    await prefs.setDouble(_keyGyro, value);
  }

  Future<bool> gyroForLaser() async {
    final prefs = await _prefs();
    return prefs.getBool(_keyGyroForLaser) ?? false;
  }

  Future<void> saveGyroForLaser(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(_keyGyroForLaser, value);
  }

  Future<bool> spotlightMode() async {
    final prefs = await _prefs();
    return prefs.getBool(_keySpotlight) ?? false;
  }

  Future<void> saveSpotlightMode(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(_keySpotlight, value);
  }
}
