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

class _PresentationRemoteAppState extends State<PresentationRemoteApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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
      home: PairingScreen(onToggleTheme: _toggleTheme),
    );
  }
}
