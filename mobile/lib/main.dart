import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'ui/pairing_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PresentationRemoteApp());
}

class PresentationRemoteApp extends StatefulWidget {
  const PresentationRemoteApp({super.key});

  @override
  State<PresentationRemoteApp> createState() => _PresentationRemoteAppState();
}

class _PresentationRemoteAppState extends State<PresentationRemoteApp>
    with SingleTickerProviderStateMixin {
  ThemeMode _themeMode = ThemeMode.dark;

  // Theme transition. Holds the color of the outgoing theme so the overlay
  // can fade from it down to reveal the incoming theme.
  AnimationController? _themeTransitionController;
  Color _outgoingBg = AppColors.darkCanvas;

  @override
  void initState() {
    super.initState();
    _themeTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _themeTransitionController?.dispose();
    super.dispose();
  }

  void _toggleThemeAnimated() {
    if (_themeTransitionController!.isAnimating) return;

    // Remember the outgoing canvas color before switching themes.
    _outgoingBg = _themeMode == ThemeMode.dark
        ? AppColors.darkCanvas
        : AppColors.lightCanvas;

    // Swap the theme underneath; the overlay (built by MaterialApp.builder)
    // currently covers the screen at full opacity, so the swap is hidden.
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });

    // Fade the cover out to reveal the new theme smoothly.
    _themeTransitionController!.forward(from: 0.0).whenComplete(() {
      _themeTransitionController!.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: PairingScreen(onToggleTheme: _toggleThemeAnimated),
      builder: (context, child) {
        return AnimatedBuilder(
          animation: _themeTransitionController!,
          builder: (context, _) {
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                IgnorePointer(
                  child: ColoredBox(
                    color: _outgoingBg.withValues(
                      alpha: 1.0 - _themeTransitionController!.value,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
