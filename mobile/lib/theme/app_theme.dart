import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light Theme Tokens
  static const Color lightCanvas = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFE5E5EA);
  static const Color lightSurfaceElevated = Color(0xFFFBFBFD);
  static const Color lightTextPrimary = Color(0xFF1D1D1F);
  static const Color lightTextSecondary = Color(0xFF6E6E73);
  static const Color lightTextTertiary = Color(0xFF8E8E93);
  static const Color lightBorder = Color(0x14000000); // 8% opacity
  static const Color lightBorderStrong = Color(0x24000000);

  // Dark Theme Tokens (Deep OLED Obsidian)
  static const Color darkCanvas = Color(0xFF07080B);
  static const Color darkSurface = Color(0xFF111218);
  static const Color darkSurfaceAlt = Color(0xFF181A22);
  static const Color darkSurfaceElevated = Color(0xFF202330);
  static const Color darkTextPrimary = Color(0xFFF5F5F7);
  static const Color darkTextSecondary = Color(0xFF9898A0);
  static const Color darkTextTertiary = Color(0xFF63636E);
  static const Color darkBorder = Color(0x1AFFFFFF); // 10% opacity
  static const Color darkBorderStrong = Color(0x33FFFFFF);

  // Accents & Neon Glows
  static const Color accentBlue = Color(0xFF0A84FF);
  static const Color accentBlueHover = Color(0xFF0070E0);
  static const Color accentBlueGlow = Color(0x660A84FF);
  static const Color accentBlueSubtle = Color(0x1F0A84FF);

  static const Color accentRed = Color(0xFFFF375F);
  static const Color accentRedGlow = Color(0x66FF375F);
  static const Color accentRedSubtle = Color(0x24FF375F);

  static const Color accentGreen = Color(0xFF30D158);
  static const Color accentGreenGlow = Color(0x5530D158);

  static const Color accentAmber = Color(0xFFFF9F0A);
  static const Color accentPurple = Color(0xFFBF5AF2);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightCanvas,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentBlue,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.accentRed,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: AppColors.lightTextPrimary,
        displayColor: AppColors.lightTextPrimary,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkCanvas,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentBlue,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        error: AppColors.accentRed,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: AppColors.darkTextPrimary,
        displayColor: AppColors.darkTextPrimary,
      ),
    );
  }
}
