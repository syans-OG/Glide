import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/connection_service.dart';
import '../../theme/app_theme.dart';

class TouchpadWidget extends StatefulWidget {
  final double sensitivity;
  final bool isLaserActive;
  final String laserMode;

  const TouchpadWidget({
    super.key,
    this.sensitivity = 1.3,
    this.isLaserActive = false,
    this.laserMode = 'laser',
  });

  @override
  State<TouchpadWidget> createState() => _TouchpadWidgetState();
}

class _TouchpadWidgetState extends State<TouchpadWidget> with SingleTickerProviderStateMixin {
  final ConnectionService _connection = ConnectionService();

  final Map<int, Offset> _activePointers = {};
  late AnimationController _tickerController;

  // Multi-Touch Gesture Detection Variables
  DateTime? _touchStartTime;
  DateTime? _lastTwoFingerTapTime;
  int _maxPointersInGesture = 0;
  double _totalTravelDistance = 0.0;
  double _scrollAccumulator = 0.0;

  // Touchpad Laser Coordinates
  double _laserNormalizedX = 0.5;
  double _laserNormalizedY = 0.5;

  // 3-Finger Horizontal Gesture Tracking
  double _threeFingerDeltaX = 0.0;
  bool _threeFingerTriggered = false;

  @override
  void initState() {
    super.initState();
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant TouchpadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLaserActive && !oldWidget.isLaserActive) {
      _laserNormalizedX = 0.5;
      _laserNormalizedY = 0.5;
      _connection.sendPointer(0.5, 0.5, mode: widget.laserMode);
    }
  }

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;

    if (_activePointers.length > _maxPointersInGesture) {
      _maxPointersInGesture = _activePointers.length;
    }

    if (_activePointers.length == 1) {
      _touchStartTime = DateTime.now();
      _totalTravelDistance = 0.0;
      _threeFingerTriggered = false;
      if (widget.isLaserActive) {
        _connection.sendPointer(_laserNormalizedX, _laserNormalizedY, mode: widget.laserMode);
      }
    } else if (_activePointers.length == 2) {
      _scrollAccumulator = 0.0;
    } else if (_activePointers.length >= 3) {
      _threeFingerDeltaX = 0.0;
      _threeFingerTriggered = false;
    }
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    _activePointers[event.pointer] = event.localPosition;

    final delta = event.delta;
    _totalTravelDistance += delta.distance;

    if (_activePointers.length == 1) {
      if (widget.isLaserActive) {
        // Touchpad Laser Mode: Direct pointer positioning
        _laserNormalizedX = (_laserNormalizedX + (delta.dx * widget.sensitivity * 0.002)).clamp(0.0, 1.0);
        _laserNormalizedY = (_laserNormalizedY + (delta.dy * widget.sensitivity * 0.002)).clamp(0.0, 1.0);
        _connection.sendPointer(_laserNormalizedX, _laserNormalizedY, mode: widget.laserMode);
      } else {
        // Normal Cursor Mode: High precision mouse movement
        final dx = delta.dx * widget.sensitivity;
        final dy = delta.dy * widget.sensitivity;
        _connection.sendMouseMove(dx, dy);
      }
    } else if (_activePointers.length == 2) {
      // 2 Fingers: Natural High Precision Scrolling (Inverted for natural trackpad feel)
      _scrollAccumulator += delta.dy * (widget.sensitivity * 0.45);
      
      const double scrollStepThreshold = 6.0;
      if (_scrollAccumulator.abs() >= scrollStepThreshold) {
        final steps = (_scrollAccumulator / scrollStepThreshold).truncate();
        if (steps != 0) {
          _connection.sendMouseScroll(steps.toDouble());
          _scrollAccumulator -= steps * scrollStepThreshold;
        }
      }
    } else if (_activePointers.length >= 3 && !_threeFingerTriggered) {
      // 3 Fingers: Horizontal Window / App Switching
      _threeFingerDeltaX += delta.dx;

      const double gestureThreshold = 30.0;
      if (_threeFingerDeltaX > gestureThreshold) {
        // Swipe Right -> Next App (Alt + Tab)
        _threeFingerTriggered = true;
        HapticFeedback.mediumImpact();
        _connection.sendKey('APP_SWITCH_RIGHT');
      } else if (_threeFingerDeltaX < -gestureThreshold) {
        // Swipe Left -> Prev App (Alt + Shift + Tab)
        _threeFingerTriggered = true;
        HapticFeedback.mediumImpact();
        _connection.sendKey('APP_SWITCH_LEFT');
      }
    }
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);

    if (_activePointers.isEmpty) {
      final now = DateTime.now();
      final duration = _touchStartTime != null ? now.difference(_touchStartTime!).inMilliseconds : 999;

      // Tap Detection: Quick release (< 320ms) without large movement drag (< 18.0 dp total travel)
      final isTap = duration < 320 && _totalTravelDistance < 18.0;

      if (isTap) {
        if (_maxPointersInGesture == 1) {
          // 👆 1-Finger Tap -> Left Click
          HapticFeedback.lightImpact();
          _connection.sendMouseClick('LEFT');
        } else if (_maxPointersInGesture == 2) {
          // ✌️ 2-Finger Double Tap -> Show Desktop (Win + D) / Single Tap -> Right Click
          if (_lastTwoFingerTapTime != null && now.difference(_lastTwoFingerTapTime!).inMilliseconds < 360) {
            HapticFeedback.heavyImpact();
            _connection.sendKey('SHOW_DESKTOP');
            _lastTwoFingerTapTime = null;
          } else {
            _lastTwoFingerTapTime = now;
            HapticFeedback.mediumImpact();
            _connection.sendMouseClick('RIGHT');
          }
        } else if (_maxPointersInGesture >= 3 && !_threeFingerTriggered) {
          // 🖐️ 3-Finger Tap -> Task View / Multitasking (Win + Tab)
          HapticFeedback.heavyImpact();
          _connection.sendKey('TASK_VIEW');
        }
      }

      // Reset gesture session state
      _touchStartTime = null;
      _maxPointersInGesture = 0;
      _totalTravelDistance = 0.0;
      _scrollAccumulator = 0.0;
      _threeFingerDeltaX = 0.0;
      _threeFingerTriggered = false;
    }
    setState(() {});
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _maxPointersInGesture = 0;
      _totalTravelDistance = 0.0;
      _scrollAccumulator = 0.0;
      _threeFingerTriggered = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isScrolling = _activePointers.length == 2;
    final isThreeFinger = _activePointers.length >= 3;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF090A0E) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: widget.isLaserActive
              ? (widget.laserMode == 'spotlight' ? AppColors.accentAmber : AppColors.accentRed).withValues(alpha: 0.5)
              : (isDark ? const Color(0x30FFFFFF) : const Color(0x18000000)),
          width: widget.isLaserActive ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // 1. Kinetic Photon Matrix Canvas
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _tickerController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _KineticPhotonMatrixPainter(
                        activePointers: _activePointers.values.toList(),
                        waveProgress: _tickerController.value,
                        isDark: isDark,
                        isScrolling: isScrolling,
                        isThreeFinger: isThreeFinger,
                        isLaserActive: widget.isLaserActive,
                        laserMode: widget.laserMode,
                        laserPos: widget.isLaserActive ? Offset(_laserNormalizedX, _laserNormalizedY) : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// KINETIC PHOTON MATRIX PAINTER (DOTS BLOOM & WAVE EXPAND WITH TOUCH)
class _KineticPhotonMatrixPainter extends CustomPainter {
  final List<Offset> activePointers;
  final double waveProgress;
  final bool isDark;
  final bool isScrolling;
  final bool isThreeFinger;
  final bool isLaserActive;
  final String laserMode;
  final Offset? laserPos;

  _KineticPhotonMatrixPainter({
    required this.activePointers,
    required this.waveProgress,
    required this.isDark,
    required this.isScrolling,
    required this.isThreeFinger,
    required this.isLaserActive,
    required this.laserMode,
    this.laserPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseDotColor = isDark ? Colors.white : Colors.black;
    
    Color primaryAccent;
    if (isLaserActive) {
      primaryAccent = laserMode == 'spotlight' ? const Color(0xFFFF9F0A) : const Color(0xFFFF3B30);
    } else if (isThreeFinger) {
      primaryAccent = const Color(0xFFBF5AF2);
    } else if (isScrolling) {
      primaryAccent = const Color(0xFF30D158);
    } else {
      primaryAccent = AppColors.accentBlue;
    }

    const spacing = 20.0;
    const baseRadius = 1.1;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        final dotPos = Offset(x, y);

        double maxProximity = 0.0;
        double waveBoost = 0.0;

        for (final finger in activePointers) {
          final dx = finger.dx - x;
          final dy = finger.dy - y;
          final dist = math.sqrt((dx * dx) + (dy * dy));

          // 1. Proximity Bloom Factor (within 110px radius of touch)
          if (dist < 110.0) {
            final prox = 1.0 - (dist / 110.0);
            if (prox > maxProximity) maxProximity = prox;

            // 2. Kinetic Expanding Wave Ring
            final waveRadius = waveProgress * 130.0;
            final ringDist = (dist - waveRadius).abs();
            if (ringDist < 24.0) {
              final ringStrength = (1.0 - (ringDist / 24.0)) * (1.0 - waveProgress);
              if (ringStrength > waveBoost) waveBoost = ringStrength;
            }
          }
        }

        // Calculate dot radius & illumination
        final currentRadius = baseRadius + (maxProximity * 3.4) + (waveBoost * 1.5);
        final baseOpacity = isDark ? 0.065 : 0.06;

        Color dotColor;
        if (maxProximity > 0.05 || waveBoost > 0.05) {
          final totalEnergy = math.min(1.0, (maxProximity * 0.85) + (waveBoost * 0.6));
          dotColor = Color.lerp(
            baseDotColor.withValues(alpha: baseOpacity),
            primaryAccent.withValues(alpha: 0.95),
            totalEnergy,
          )!;
        } else {
          dotColor = baseDotColor.withValues(alpha: baseOpacity);
        }

        final paint = Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;

        canvas.drawCircle(dotPos, currentRadius, paint);
      }
    }

    // Draw Laser Target Beacon if active
    if (isLaserActive && laserPos != null) {
      final target = Offset(laserPos!.dx * size.width, laserPos!.dy * size.height);
      final isSpot = laserMode == 'spotlight';
      final laserColor = isSpot ? const Color(0xFFFF9F0A) : const Color(0xFFFF3B30);

      // Outer Halo
      final haloPaint = Paint()
        ..color = laserColor.withValues(alpha: 0.18 + (math.sin(waveProgress * math.pi * 2) * 0.06))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(target, isSpot ? 36.0 : 20.0, haloPaint);

      // Stroke Reticle
      final ringPaint = Paint()
        ..color = laserColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(target, isSpot ? 24.0 : 12.0, ringPaint);

      // Core Dot
      final corePaint = Paint()
        ..color = laserColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(target, isSpot ? 5.0 : 3.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _KineticPhotonMatrixPainter oldDelegate) {
    return true;
  }
}
