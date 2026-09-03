import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/connection_service.dart';
import '../../services/gyro_service.dart';
import '../pairing_screen.dart';
import 'gesture_guide_sheet.dart';

void showSettingsBottomSheet({
  required BuildContext context,
  required VoidCallback onToggleTheme,
  required bool isMuted,
  required double touchSensitivity,
  required ValueChanged<double> onTouchSensitivityChanged,
  required bool useGyroForLaser,
  required ValueChanged<bool> onUseGyroForLaserChanged,
  required bool isLaserAiming,
  required bool isSpotlight,
  required VoidCallback onToggleSpotlightMode,
  required bool isDark,
  required ValueChanged<double> onGyroSensitivityChanged,
  final String onToggleThemeLabel = '',
}) {
  final connection = ConnectionService();
  final gyro = GyroService();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      // Seed once from the parent's values; the StatefulBuilder below
      // captures them via closure, so setSheetState rebuilds with the
      // updated locals instead of re-seeding from frozen params.
      var touch = touchSensitivity;
      var useGyro = useGyroForLaser;
      var spotlight = isSpotlight;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          // Derive from ambient theme so the sheet follows toggle live,
          // instead of a frozen value captured when the sheet opened.
          final isDark = Theme.of(context).brightness == Brightness.dark;
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
                              onToggleTheme();
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

                      Text(
                        'Sensitivitas Touchpad: ${touch.toStringAsFixed(1)}x',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      Slider(
                        value: touch,
                        min: 0.6,
                        max: 2.8,
                        divisions: 11,
                        activeColor: AppColors.accentBlue,
                        onChanged: (val) {
                          touch = val;
                          setSheetState(() {});
                          onTouchSensitivityChanged(val);
                        },
                      ),
                      const SizedBox(height: 8),

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
                                    useGyro
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
                              value: useGyro,
                              activeTrackColor: AppColors.accentRed,
                              onChanged: (val) {
                                useGyro = val;
                                setSheetState(() {});
                                onUseGyroForLaserChanged(val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (useGyro) ...[
                        Text(
                          'Sensitivitas Laser Gyro: ${gyro.sensitivity.toStringAsFixed(1)}x',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        Slider(
                          value: gyro.sensitivity,
                          min: 0.5,
                          max: 3.5,
                          divisions: 15,
                          activeColor: AppColors.accentRed,
                          onChanged: (val) {
                            setSheetState(() => gyro.setSensitivity(val));
                            onGyroSensitivityChanged(val);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      Row(
                        children: [
                          Expanded(
                            child: _SettingsActionTile(
                              icon: spotlight ? Icons.highlight_rounded : Icons.radar_rounded,
                              accentColor: spotlight ? AppColors.accentAmber : AppColors.accentRed,
                              label: spotlight ? 'Spotlight' : 'Laser Red',
                              subtitle: 'Mode Pointer',
                              onTap: () {
                                spotlight = !spotlight;
                                setSheetState(() {});
                                onToggleSpotlightMode();
                              },
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SettingsActionTile(
                              icon: Icons.touch_app_rounded,
                              accentColor: AppColors.accentBlue,
                              label: 'Gestur',
                              subtitle: 'Panduan',
                              onTap: () {
                                showGestureGuideSheet(context: context);
                              },
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            connection.disconnect();
                            Navigator.of(ctx).pop();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => PairingScreen(onToggleTheme: onToggleTheme),
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
        },
      );
    },
  );
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const _SettingsActionTile({
    required this.icon,
    required this.accentColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.12 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.16),
                ),
                child: Center(
                  child: Icon(icon, size: 17, color: accentColor),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
