import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/connection_service.dart';
import '../services/gyro_service.dart';
import '../theme/app_theme.dart';
import 'pairing_screen.dart';
import 'widgets/timer_widget.dart';
import 'widgets/touchpad_widget.dart';

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
  late AnimationController _laserPulseController;
  late Animation<double> _laserPulseAnimation;

  bool _isLaserAiming = false;
  bool _isSpotlight = false;
  bool _useGyroForLaser = false;
  double _touchSensitivity = 1.3;
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
    HapticFeedback.selectionClick();
    setState(() {
      _isSpotlight = !_isSpotlight;
      _gyro.setMode(_isSpotlight ? 'spotlight' : 'laser');
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSpotlight ? 'Mode Gyro: Spotlight 🟡' : 'Mode Gyro: Laser Merah 🔴'),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showVolumeQuickSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.12),
                blurRadius: 36,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Kontrol Volume & Media',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildVolumeActionButton(
                    icon: Icons.volume_down_rounded,
                    label: 'Vol -',
                    onTap: _sendVolDown,
                    isDark: isDark,
                  ),
                  _buildVolumeActionButton(
                    icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_mute_rounded,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    color: _isMuted ? AppColors.accentRed : null,
                    onTap: () {
                      _toggleMute();
                      Navigator.pop(ctx);
                    },
                    isDark: isDark,
                  ),
                  _buildVolumeActionButton(
                    icon: Icons.volume_up_rounded,
                    label: 'Vol +',
                    onTap: _sendVolUp,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVolumeActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color?.withValues(alpha: 0.15) ??
                    (isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt),
                border: Border.all(
                  color: color?.withValues(alpha: 0.5) ??
                      (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
              child: Icon(
                icon,
                size: 26,
                color: color ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.12),
                    blurRadius: 36,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pengaturan Remote',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          widget.onToggleTheme();
                          setSheetState(() {});
                        },
                        icon: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          size: 20,
                          color: isDark ? AppColors.accentAmber : AppColors.accentBlue,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                        ),
                        tooltip: isDark ? 'Ganti ke Light Mode' : 'Ganti ke Dark Mode',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Touchpad Sensitivity
                  Text(
                    'Sensitivitas Touchpad: ${_touchSensitivity.toStringAsFixed(1)}x',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  Slider(
                    value: _touchSensitivity,
                    min: 0.6,
                    max: 2.8,
                    divisions: 11,
                    activeColor: AppColors.accentBlue,
                    onChanged: (val) {
                      setSheetState(() => _touchSensitivity = val);
                      setState(() => _touchSensitivity = val);
                    },
                  ),
                  const SizedBox(height: 8),

                  // Laser Control Mode Switch (Touchpad vs Gyroscope)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gunakan Sensor Gyro Laser',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _useGyroForLaser
                                    ? 'Laser digerakkan gerakan fisik HP'
                                    : 'Laser digerakkan usapan Touchpad (Default)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Switch.adaptive(
                          value: _useGyroForLaser,
                          activeTrackColor: AppColors.accentRed,
                          onChanged: (val) {
                            setSheetState(() => _useGyroForLaser = val);
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
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Gyro Laser Sensitivity (If Gyro Enabled)
                  if (_useGyroForLaser) ...[
                    Text(
                      'Sensitivitas Laser Gyro: ${_gyro.sensitivity.toStringAsFixed(1)}x',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Slider(
                      value: _gyro.sensitivity,
                      min: 0.5,
                      max: 3.5,
                      divisions: 15,
                      activeColor: AppColors.accentRed,
                      onChanged: (val) {
                        setSheetState(() => _gyro.setSensitivity(val));
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Laser Mode & Recenter
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _toggleSpotlightMode();
                            setSheetState(() {});
                          },
                          icon: Icon(
                            _isSpotlight ? Icons.highlight_rounded : Icons.radar_rounded,
                            size: 18,
                            color: _isSpotlight ? AppColors.accentAmber : AppColors.accentRed,
                          ),
                          label: Text(_isSpotlight ? 'Spotlight' : 'Laser Red'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _showGestureGuideDialog(context);
                          },
                          icon: const Icon(Icons.help_outline_rounded, size: 18),
                          label: const Text('Panduan Gestur'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Disconnect Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _connection.disconnect();
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => PairingScreen(onToggleTheme: widget.onToggleTheme),
                          ),
                        );
                      },
                      icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                      label: const Text('Putuskan Koneksi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentRed.withValues(alpha: 0.15),
                        foregroundColor: AppColors.accentRed,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      );
    });
  },
);
}

  void _showGestureGuideDialog(BuildContext context) {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.touch_app_rounded, color: AppColors.accentBlue, size: 22),
              const SizedBox(width: 8),
              Text(
                'Panduan Gestur',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGuideSection(
                  title: '1 Jari (Navigasi Dasar)',
                  items: [
                    'Geser 1 Jari: Menggerakkan kursor mouse',
                    'Tap 1 Jari: Klik Kiri (Left Click)',
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                _buildGuideSection(
                  title: '2 Jari (Scroll & Aksi Cepat)',
                  items: [
                    'Geser Vertikal: Natural Precision Scrolling',
                    'Tap 1x: Klik Kanan (Right Click)',
                    'Double-Tap: Show Desktop / Minimize (Win + D)',
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                _buildGuideSection(
                  title: '3 Jari (Window & Multitasking)',
                  items: [
                    'Tap 1x: Task View / Multitasking (Win + Tab)',
                    'Geser Kanan: Next App (Alt + Tab)',
                    'Geser Kiri: Prev App (Alt + Shift + Tab)',
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                _buildGuideSection(
                  title: 'Laser Pointer Presentasi',
                  items: [
                    'Mode Touchpad (Default): Usap jari di layar untuk sorot laser di PC',
                    'Mode Gyro (Opsional di Settings): Gerakkan fisik HP ke layar',
                    'Tahan Tombol Laser: Ganti Laser Merah 🔴 ↔ Spotlight 🟡',
                  ],
                  isDark: isDark,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideSection({
    required String title,
    required List<String> items,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.accentBlue,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
              // 1. TOP HEADER
              _buildHeader(isDark, isLandscape),
              SizedBox(height: isLandscape ? 8 : 14),

              // 2. GIANT CENTER TOUCHPAD CANVAS (100% Widescreen in Landscape)
              Expanded(
                child: TouchpadWidget(
                  sensitivity: _touchSensitivity,
                  isLaserActive: _isLaserAiming && !_useGyroForLaser,
                  laserMode: _isSpotlight ? 'spotlight' : 'laser',
                ),
              ),

              // 3. TACTICAL ARC BOTTOM DECK (Hidden in Landscape for Pure Trackpad)
              if (!isLandscape) ...[
                const SizedBox(height: 14),
                _buildNaturalArcDeck(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isLandscape) {
    return AnimatedBuilder(
      animation: _connection,
      builder: (context, _) {
        const buttonSize = 42.0;

        return Row(
          children: [
            // Left Circle: Settings Button
            _buildCircularHeaderButton(
              icon: Icons.tune_rounded,
              tooltip: 'Pengaturan',
              size: buttonSize,
              onTap: () => _showSettingsBottomSheet(context),
              isDark: isDark,
            ),
            const SizedBox(width: 8),

            // Center Dynamic Pill: Integrated Timer & Latency Status
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Left Section: Connection Status Dot & Latency (Fixed 50% Split)
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _connection.isConnected ? AppColors.accentGreen : AppColors.accentRed,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_connection.isConnected ? AppColors.accentGreen : AppColors.accentRed)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _connection.isConnected ? '${_connection.pingMs}ms' : 'Offline',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'JetBrains Mono',
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Elegant Divider (Permanently Locked at Dead Center)
                    Container(
                      width: 1,
                      height: 14,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),

                    // Right Section: Presentation Timer (Fixed 50% Split)
                    const Expanded(
                      child: Center(
                        child: TimerWidget(isInline: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Rightmost Circle: Orientation / Widescreen Trackpad Switch Button
            _buildCircularHeaderButton(
              icon: isLandscape ? Icons.stay_current_portrait_rounded : Icons.crop_rotate_rounded,
              tooltip: isLandscape ? 'Mode Potret' : 'Widescreen Trackpad',
              size: buttonSize,
              onTap: () => _toggleOrientation(context),
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCircularHeaderButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
    double size = 36.0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: 17,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // 3. TACTICAL ARC BOTTOM DECK (Matches Wireframe Geometry & Android Safe Inset)
  Widget _buildNaturalArcDeck(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ◀️ LEFT BIG CIRCLE (PREV)
          _buildBigArcButton(
            label: 'PREV',
            icon: Icons.arrow_back_ios_new_rounded,
            isPrimary: false,
            onTap: _sendPrev,
            isDark: isDark,
          ),

          // 🔴 ⏯️ 🔊 TRIANGULAR 3-CIRCLE POD (Vertically & Horizontally Balanced)
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TOP APEX: 🔴 LASER POINTER BUTTON
              _buildLaserArcButton(isDark),
              const SizedBox(height: 7),

              // BOTTOM BASE: ⏯️ PLAY/PAUSE & 🔊 VOLUME/MUTE PAIR
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSmallArcButton(
                    icon: Icons.play_arrow_rounded,
                    onTap: _sendPlayPause,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildSmallArcButton(
                    icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    iconColor: _isMuted ? AppColors.accentRed : null,
                    onTap: () => _showVolumeQuickSheet(context),
                    onLongPress: _toggleMute,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),

          // ▶️ RIGHT BIG CIRCLE (NEXT)
          _buildBigArcButton(
            label: 'NEXT',
            icon: Icons.arrow_forward_ios_rounded,
            isPrimary: true,
            onTap: _sendNext,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // BIG CIRCULAR PREV / NEXT BUTTON
  Widget _buildBigArcButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    const double size = 86.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isPrimary
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0A84FF), Color(0xFF0055D4)],
                  )
                : null,
            color: isPrimary
                ? null
                : (isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xFF409CFF)
                  : (isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: isPrimary
                    ? Colors.white
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isPrimary
                      ? Colors.white
                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // HERO LASER POINTER BUTTON (TOP CENTER - TAP: ON/OFF, HOLD: SWITCH MODE)
  Widget _buildLaserArcButton(bool isDark) {
    const double size = 42.0;

    return GestureDetector(
      onTap: _toggleLaserAim,
      onLongPress: _toggleSpotlightMode,
      child: AnimatedBuilder(
        animation: _laserPulseAnimation,
        builder: (context, _) {
          final isAiming = _isLaserAiming;
          final scale = isAiming ? _laserPulseAnimation.value : 1.0;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isAiming
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.accentRed, Color(0xFFD63031)],
                      )
                    : null,
                color: isAiming
                    ? null
                    : (isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface),
                border: Border.all(
                  color: isAiming
                      ? AppColors.accentRedGlow
                      : (isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong),
                  width: isAiming ? 2.2 : 1.2,
                ),
              ),
              child: Center(
                child: Icon(
                  isAiming
                      ? (_isSpotlight ? Icons.highlight_rounded : Icons.radar_rounded)
                      : Icons.radar_rounded,
                  size: 20,
                  color: isAiming
                      ? Colors.white
                      : (_isSpotlight ? AppColors.accentAmber : AppColors.accentRed),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // SMALL ARC BUTTONS (PLAY / PAUSE & VOLUME)
  Widget _buildSmallArcButton({
    required IconData icon,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    required bool isDark,
    Color? iconColor,
  }) {
    const double size = 36.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(size),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.1,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 19,
              color: iconColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
