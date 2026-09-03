import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class BottomDeckControls extends StatelessWidget {
  final bool isDark;
  final bool isMuted;
  final bool isLaserAiming;
  final bool isSpotlight;
  final Animation<double> laserPulseAnimation;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final VoidCallback onVolumeTap;
  final VoidCallback onVolumeLongPress;
  final VoidCallback onLaserTap;
  final VoidCallback onLaserLongPress;

  const BottomDeckControls({
    super.key,
    required this.isDark,
    required this.isMuted,
    required this.isLaserAiming,
    required this.isSpotlight,
    required this.laserPulseAnimation,
    required this.onPrev,
    required this.onNext,
    required this.onPlayPause,
    required this.onVolumeTap,
    required this.onVolumeLongPress,
    required this.onLaserTap,
    required this.onLaserLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _BigArcButton(
            label: 'PREV',
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onPrev,
            isDark: isDark,
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LaserArcButton(
                isDark: isDark,
                isLaserAiming: isLaserAiming,
                isSpotlight: isSpotlight,
                laserPulseAnimation: laserPulseAnimation,
                onTap: onLaserTap,
                onLongPress: onLaserLongPress,
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SmallArcButton(
                    icon: Icons.play_arrow_rounded,
                    onTap: onPlayPause,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _SmallArcButton(
                    icon: isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    iconColor: isMuted ? AppColors.accentRed : null,
                    onTap: onVolumeTap,
                    onLongPress: onVolumeLongPress,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),

          _BigArcButton(
            label: 'NEXT',
            icon: Icons.arrow_forward_ios_rounded,
            onTap: onNext,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _BigArcButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _BigArcButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
            color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
            border: Border.all(
              color: isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaserArcButton extends StatelessWidget {
  final bool isDark;
  final bool isLaserAiming;
  final bool isSpotlight;
  final Animation<double> laserPulseAnimation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LaserArcButton({
    required this.isDark,
    required this.isLaserAiming,
    required this.isSpotlight,
    required this.laserPulseAnimation,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 42.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedBuilder(
        animation: laserPulseAnimation,
        builder: (context, _) {
          final scale = isLaserAiming ? laserPulseAnimation.value : 1.0;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isLaserAiming
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.accentRed, Color(0xFFD63031)],
                      )
                    : null,
                color: isLaserAiming
                    ? null
                    : (isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface),
                border: Border.all(
                  color: isLaserAiming
                      ? AppColors.accentRedGlow
                      : (isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong),
                  width: isLaserAiming ? 2.2 : 1.2,
                ),
              ),
              child: Center(
                child: Icon(
                  isLaserAiming
                      ? (isSpotlight ? Icons.highlight_rounded : Icons.radar_rounded)
                      : Icons.radar_rounded,
                  size: 20,
                  color: isLaserAiming
                      ? Colors.white
                      : (isSpotlight ? AppColors.accentAmber : AppColors.accentRed),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SmallArcButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isDark;
  final Color? iconColor;

  const _SmallArcButton({
    required this.icon,
    this.onTap,
    this.onLongPress,
    required this.isDark,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
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
