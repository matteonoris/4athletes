import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color background = Color(0xFF0F1115);
  static const Color surface = Color(0xFF181A1F);
  static const Color card = Color(0xFF23262D);
  static const Color primary = Color(0xFF13A4EC); // Blue main color
  static const Color secondary = Color(0xFF00E091); // Green accent

  static const Color textHighEmphasis = Colors.white;
  static const Color textMediumEmphasis =
      Color(0xFF9E9E9E); // Grey-400 equivalent
  static const Color textLowEmphasis = Color(0xFF757575);

  static const Color error = Color(0xFFFF5252);
  static const Color success = Color(0xFF4CAF50);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
      ),
      textTheme:
          GoogleFonts.lexendTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.lexend(
            color: textHighEmphasis, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.lexend(
            color: textHighEmphasis, fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.lexend(
            color: textHighEmphasis, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.lexend(
            color: textHighEmphasis, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.lexend(
            color: textHighEmphasis, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.lexend(
            color: textHighEmphasis, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.lexend(
            color: textHighEmphasis, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.lexend(
            color: textHighEmphasis, fontWeight: FontWeight.w500),
        titleSmall: GoogleFonts.lexend(
            color: textHighEmphasis, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.lexend(color: textHighEmphasis),
        bodyMedium: GoogleFonts.lexend(color: textMediumEmphasis),
        bodySmall: GoogleFonts.lexend(color: textLowEmphasis),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textHighEmphasis),
        titleTextStyle: TextStyle(
            color: textHighEmphasis, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.lexend(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textHighEmphasis,
          side: const BorderSide(color: surface, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.lexend(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        labelStyle: const TextStyle(color: textMediumEmphasis),
        hintStyle: const TextStyle(color: textMediumEmphasis),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textLowEmphasis,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
