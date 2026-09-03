import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/connection_service.dart';
import 'timer_widget.dart';

class ControllerHeader extends StatelessWidget {
  final bool isDark;
  final bool isLandscape;
  final VoidCallback onSettingsTap;
  final VoidCallback onOrientationTap;

  const ControllerHeader({
    super.key,
    required this.isDark,
    required this.isLandscape,
    required this.onSettingsTap,
    required this.onOrientationTap,
  });

  @override
  Widget build(BuildContext context) {
    final connection = ConnectionService();

    return AnimatedBuilder(
      animation: connection,
      builder: (context, _) {
        const buttonSize = 42.0;

        return Row(
          children: [
            _CircularHeaderButton(
              icon: Icons.tune_rounded,
              tooltip: 'Pengaturan',
              size: buttonSize,
              onTap: onSettingsTap,
              isDark: isDark,
            ),
            const SizedBox(width: 8),

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
                                  color: connection.isConnected ? AppColors.accentGreen : AppColors.accentRed,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (connection.isConnected ? AppColors.accentGreen : AppColors.accentRed)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                connection.isConnected ? '${connection.pingMs}ms' : 'Offline',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Container(
                      width: 1,
                      height: 14,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),

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

            _CircularHeaderButton(
              icon: isLandscape ? Icons.stay_current_portrait_rounded : Icons.crop_rotate_rounded,
              tooltip: isLandscape ? 'Mode Potret' : 'Widescreen Trackpad',
              size: buttonSize,
              onTap: onOrientationTap,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }
}

class _CircularHeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;
  final double size;

  const _CircularHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
    this.size = 36.0,
  });

  @override
  Widget build(BuildContext context) {
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
}
