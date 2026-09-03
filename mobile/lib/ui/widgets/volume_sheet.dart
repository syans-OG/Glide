import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

void showVolumeQuickSheet({
  required BuildContext context,
  required bool isMuted,
  required VoidCallback onVolDown,
  required VoidCallback onVolUp,
  required VoidCallback onToggleMute,
}) {
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
                _VolumeActionButton(
                  icon: Icons.volume_down_rounded,
                  label: 'Vol -',
                  onTap: onVolDown,
                  isDark: isDark,
                ),
                _VolumeActionButton(
                  icon: isMuted ? Icons.volume_off_rounded : Icons.volume_mute_rounded,
                  label: isMuted ? 'Unmute' : 'Mute',
                  color: isMuted ? AppColors.accentRed : null,
                  onTap: () {
                    onToggleMute();
                    Navigator.pop(ctx);
                  },
                  isDark: isDark,
                ),
                _VolumeActionButton(
                  icon: Icons.volume_up_rounded,
                  label: 'Vol +',
                  onTap: onVolUp,
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

class _VolumeActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final Color? color;

  const _VolumeActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
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
}
