import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Core Color Palette
  static const Color slate900 = Color(0xFF020617);
  static const Color slate800 = Color(0xFF0F172A);
  static const Color sky400 = Color(0xFF38BDF8);
  static const Color sky500 = Color(0xFF0EA5E9);
  static const Color textWhite = Color(0xFFF8FAFC);
  static const Color textGrey = Color(0xFF94A3B8);

  // Status Colors
  static const Color safeGreen = Color(0xFF34D399); // Emerald 400
  static const Color warningYellow = Color(0xFFEAB308);
  static const Color alertRed = Color(0xFFF43F5E); // Rose 500

  // The Global Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: false,
      scaffoldBackgroundColor: slate900,
      colorScheme: const ColorScheme.dark(
        primary: sky400,
        secondary: sky500,
        surface: slate800,
        onSurface: textWhite,
        error: alertRed,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textWhite,
        displayColor: textWhite,
      ),
    );
  }
}
