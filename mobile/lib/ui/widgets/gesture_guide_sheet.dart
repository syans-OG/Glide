import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

void showGestureGuideSheet({
  required BuildContext context,
}) {
  HapticFeedback.selectionClick();
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
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
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
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
                  const SizedBox(height: 18),
                  Text(
                    'Panduan Gestur',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GestureSection(
                    color: AppColors.accentBlue,
                    title: '1 Jari',
                    subtitle: 'Navigasi Dasar',
                    items: const [
                      'Geser: Gerakkan kursor',
                      'Tap: Klik Kiri',
                    ],
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _GestureSection(
                    color: AppColors.accentGreen,
                    title: '2 Jari',
                    subtitle: 'Scroll & Aksi Cepat',
                    items: const [
                      'Geser Vertikal: Precision Scroll',
                      'Tap: Klik Kanan',
                      'Double-Tap: Show Desktop (Win+D)',
                    ],
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _GestureSection(
                    color: const Color(0xFFBF5AF2),
                    title: '3 Jari',
                    subtitle: 'Window & Multitasking',
                    items: const [
                      'Tap: Task View (Win+Tab)',
                      'Geser Kanan: Next App (Alt+Tab)',
                      'Geser Kiri: Prev App (Alt+Shift+Tab)',
                    ],
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _GestureSection(
                    color: AppColors.accentRed,
                    title: 'Laser',
                    subtitle: 'Pointer Presentasi',
                    items: const [
                      'Usap: Gerakkan laser di touchpad',
                      'Gyro: Gerakkan HP ke arah layar',
                      'Tahan Tombol: Ganti Merah / Spotlight',
                    ],
                    isDark: isDark,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _GestureSection extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final List<String> items;
  final bool isDark;

  const _GestureSection({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textTertiary = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 16, top: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('– ', style: TextStyle(fontSize: 11, color: textTertiary)),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
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
}
