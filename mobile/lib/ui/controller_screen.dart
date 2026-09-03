import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/connection_service.dart';
import '../services/gyro_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'widgets/touchpad_widget.dart';
import 'widgets/controller_header.dart';
import 'widgets/bottom_deck_controls.dart';
import 'widgets/volume_sheet.dart';
import 'widgets/settings_sheet.dart';

class ControllerScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const ControllerScreen({
    super.key,
    required this.onToggleTheme,
  });

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> with SingleTickerProviderStateMixin {
  final ConnectionService _connection = ConnectionService();
  final GyroService _gyro = GyroService();
  final SettingsService _settings = SettingsService();
  late AnimationController _laserPulseController;
  late Animation<double> _laserPulseAnimation;

  bool _isLaserAiming = false;
  bool _isSpotlight = false;
  bool _useGyroForLaser = false;
  double _touchSensitivity = SettingsService.defaultTouchSensitivity;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _laserPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _laserPulseAnimation = Tween<double>(begin: 0.96, end: 1.12).animate(
      CurvedAnimation(parent: _laserPulseController, curve: Curves.easeInOut),
    );

    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final touch = await _settings.touchSensitivity();
    final gyroSens = await _settings.gyroSensitivity();
    final gyroForLaser = await _settings.gyroForLaser();
    final spotlight = await _settings.spotlightMode();

    if (!mounted) return;
    setState(() {
      _touchSensitivity = touch;
      _useGyroForLaser = gyroForLaser;
      _isSpotlight = spotlight;
    });
    _gyro.setSensitivity(gyroSens);
    _gyro.setMode(spotlight ? 'spotlight' : 'laser');
  }

  @override
  void dispose() {
    _laserPulseController.dispose();
    super.dispose();
  }

  void _sendNext() {
    HapticFeedback.mediumImpact();
    _connection.sendKey('NEXT');
  }

  void _sendPrev() {
    HapticFeedback.lightImpact();
    _connection.sendKey('PREV');
  }

  void _sendPlayPause() {
    HapticFeedback.mediumImpact();
    _connection.sendKey('PLAYPAUSE');
  }

  void _sendVolUp() {
    HapticFeedback.lightImpact();
    _connection.sendKey('VOLUP');
  }

  void _sendVolDown() {
    HapticFeedback.lightImpact();
    _connection.sendKey('VOLDOWN');
  }

  void _toggleMute() {
    HapticFeedback.heavyImpact();
    setState(() => _isMuted = !_isMuted);
    _connection.sendKey('MUTE');
  }

  void _toggleLaserAim() {
    setState(() {
      _isLaserAiming = !_isLaserAiming;
      _gyro.reCenter();
      if (_isLaserAiming) {
        HapticFeedback.heavyImpact();
        if (_useGyroForLaser) {
          _gyro.startAiming();
        }
      } else {
        HapticFeedback.lightImpact();
        if (_useGyroForLaser) {
          _gyro.stopAiming();
        } else {
          _connection.sendPointerOff();
        }
      }
    });
  }

  void _toggleSpotlightMode() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSpotlight = !_isSpotlight;
      _gyro.setMode(_isSpotlight ? 'spotlight' : 'laser');
      if (_isLaserAiming) {
        _gyro.reCenter();
      }
    });
    _settings.saveSpotlightMode(_isSpotlight);
  }

  void _toggleOrientation(BuildContext context) {
    HapticFeedback.mediumImpact();
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.lightCanvas,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 16 : 16,
            vertical: isLandscape ? 8 : 10,
          ),
          child: Column(
            children: [
              ControllerHeader(
                isDark: isDark,
                isLandscape: isLandscape,
                onSettingsTap: () => showSettingsBottomSheet(
                  context: context,
                  onToggleTheme: widget.onToggleTheme,
                  isMuted: _isMuted,
                  touchSensitivity: _touchSensitivity,
                  onTouchSensitivityChanged: (val) {
                    _settings.saveTouchSensitivity(val);
                    setState(() => _touchSensitivity = val);
                  },
                  useGyroForLaser: _useGyroForLaser,
                  onUseGyroForLaserChanged: (val) {
                    _settings.saveGyroForLaser(val);
                    setState(() {
                      _useGyroForLaser = val;
                      if (_isLaserAiming) {
                        if (_useGyroForLaser) {
                          _gyro.reCenter();
                          _gyro.startAiming();
                        } else {
                          _gyro.stopAiming();
                        }
                      }
                    });
                  },
                  isLaserAiming: _isLaserAiming,
                  isSpotlight: _isSpotlight,
                  onToggleSpotlightMode: _toggleSpotlightMode,
                  isDark: isDark,
                  onGyroSensitivityChanged: (val) {
                    _settings.saveGyroSensitivity(val);
                    _gyro.setSensitivity(val);
                  },
                ),
                onOrientationTap: () => _toggleOrientation(context),
              ),
              SizedBox(height: isLandscape ? 8 : 14),

              Expanded(
                child: TouchpadWidget(
                  sensitivity: _touchSensitivity,
                  isLaserActive: _isLaserAiming && !_useGyroForLaser,
                  laserMode: _isSpotlight ? 'spotlight' : 'laser',
                ),
              ),

              if (!isLandscape) ...[
                const SizedBox(height: 14),
                BottomDeckControls(
                  isDark: isDark,
                  isMuted: _isMuted,
                  isLaserAiming: _isLaserAiming,
                  isSpotlight: _isSpotlight,
                  laserPulseAnimation: _laserPulseAnimation,
                  onPrev: _sendPrev,
                  onNext: _sendNext,
                  onPlayPause: _sendPlayPause,
                  onVolumeTap: () => showVolumeQuickSheet(
                    context: context,
                    isMuted: _isMuted,
                    onVolDown: _sendVolDown,
                    onVolUp: _sendVolUp,
                    onToggleMute: _toggleMute,
                  ),
                  onVolumeLongPress: _toggleMute,
                  onLaserTap: _toggleLaserAim,
                  onLaserLongPress: _toggleSpotlightMode,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
