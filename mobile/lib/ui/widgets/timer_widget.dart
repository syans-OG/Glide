import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class TimerWidget extends StatefulWidget {
  final bool isInline;

  const TimerWidget({
    super.key,
    this.isInline = true,
  });

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  int _secondsElapsed = 0;
  final int _targetMinutes = 15;
  bool _isRunning = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    HapticFeedback.lightImpact();
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _secondsElapsed++;
            _checkHapticAlerts();
          });
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _resetTimer() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRunning = false;
      _secondsElapsed = 0;
      _timer?.cancel();
    });
  }

  void _checkHapticAlerts() {
    final targetSeconds = _targetMinutes * 60;
    final remaining = targetSeconds - _secondsElapsed;

    // 5-minute warning
    if (remaining == 300) {
      HapticFeedback.heavyImpact();
    }
    // 1-minute warning
    if (remaining == 60) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.heavyImpact());
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetSeconds = _targetMinutes * 60;

    Color timerColor = _isRunning ? AppColors.accentBlue : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
    if (_secondsElapsed >= targetSeconds) {
      timerColor = AppColors.accentRed;
    } else if (_secondsElapsed >= targetSeconds - 300) {
      timerColor = AppColors.accentAmber;
    }

    final content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isRunning ? Icons.timer : Icons.timer_outlined,
            size: 14,
            color: timerColor,
          ),
          const SizedBox(width: 4),
          Text(
            _formatTime(_secondsElapsed),
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: timerColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '/ ${_targetMinutes}m',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
          ),
        ],
      ),
    );

    if (widget.isInline) {
      return GestureDetector(
        onTap: _toggleTimer,
        onLongPress: _resetTimer,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: content,
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleTimer,
      onLongPress: _resetTimer,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: _isRunning ? timerColor.withValues(alpha: 0.5) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: content,
      ),
    );
  }
}
