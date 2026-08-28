import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Official Vector Logo Widget for Glide
/// Renders the high-precision Aero Neo-Origami Glider with porcelain facets,
/// electric cyan underwing, and glowing emerald laser beacon.
class GlideLogoWidget extends StatelessWidget {
  final double size;
  final bool showSquircle;
  final bool showGlow;

  const GlideLogoWidget({
    super.key,
    this.size = 32.0,
    this.showSquircle = true,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showGlow
          ? BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  blurRadius: size * 0.25,
                  offset: Offset(0, size * 0.08),
                ),
              ],
            )
          : null,
      child: CustomPaint(
        size: Size(size, size),
        painter: _GlideLogoPainter(showSquircle: showSquircle),
      ),
    );
  }
}

class _GlideLogoPainter extends CustomPainter {
  final bool showSquircle;

  _GlideLogoPainter({required this.showSquircle});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Draw Squircle Frame if enabled
    if (showSquircle) {
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h),
        Radius.circular(w * 0.23),
      );

      final bgPaint = Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.0, -0.3),
          radius: 0.85,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
            Color(0xFF020617),
          ],
          stops: [0.0, 0.6, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h));

      canvas.drawRRect(rrect, bgPaint);

      // Subtle Border
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.02)
        ..color = const Color(0xFF334155).withValues(alpha: 0.5);

      canvas.drawRRect(rrect, borderPaint);
    }

    // 2. Draw Origami Glider inside scaled coordinate system
    canvas.save();
    
    // Scale and center the glider mark
    final scaleFactor = w / 512.0;
    canvas.scale(scaleFactor, scaleFactor);

    // Glider center is (256, 260) rotated by -14 deg
    canvas.translate(256, 260);
    canvas.rotate(-14 * math.pi / 180);
    canvas.translate(-256, -256);

    // A. Right Folded Wing (Vibrant Cyan Underlayer)
    final cyanPath = Path()
      ..moveTo(256, 96)
      ..lineTo(410, 330)
      ..cubicTo(424, 352, 408, 380, 382, 376)
      ..lineTo(256, 320)
      ..close();

    final cyanPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9), Color(0xFF0284C7)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(const Rect.fromLTWH(256, 96, 160, 284));

    canvas.drawPath(cyanPath, cyanPaint);

    // B. Left Wing Facet (Soft Shadow Pearl)
    final leftPath = Path()
      ..moveTo(256, 96)
      ..lineTo(256, 320)
      ..lineTo(130, 376)
      ..cubicTo(104, 380, 88, 352, 102, 330)
      ..close();

    final leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF1F5F9), Color(0xFFCBD5E1)],
      ).createShader(const Rect.fromLTWH(95, 96, 161, 284));

    canvas.drawPath(leftPath, leftPaint);

    // C. Top Body Spine Facet (Bright Porcelain Pearl)
    final topPath = Path()
      ..moveTo(256, 96)
      ..lineTo(330, 320)
      ..cubicTo(336, 338, 322, 354, 304, 350)
      ..lineTo(256, 338)
      ..lineTo(208, 350)
      ..cubicTo(190, 354, 176, 338, 182, 320)
      ..close();

    final topPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(0.2, 0.0),
        end: Alignment(0.8, 1.0),
        colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(const Rect.fromLTWH(176, 96, 160, 258));

    canvas.drawPath(topPath, topPaint);

    // D. Emerald Laser Pointer Beacon at Nose Cone
    final laserHaloPaint = Paint()
      ..color = const Color(0xFF34D399).withValues(alpha: 0.4);
    canvas.drawCircle(const Offset(256, 94), 22, laserHaloPaint);

    final laserCorePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF34D399), Color(0xFF10B981)],
      ).createShader(const Rect.fromLTWH(246, 84, 20, 20));
    canvas.drawCircle(const Offset(256, 94), 10, laserCorePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
