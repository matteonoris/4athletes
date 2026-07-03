import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const String systemMode = 'system';
  static const String lightMode = 'light';
  static const String darkMode = 'dark';

  // Brand Colors
  static const Color _darkBackground = Color(0xFF0F1115);
  static const Color _darkSurface = Color(0xFF181A1F);
  static const Color _darkCard = Color(0xFF23262D);
  static const Color _lightBackground = Color(0xFFF5F7FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF13A4EC); // Blue main color
  static const Color secondary = Color(0xFF00E091); // Green accent

  static const Color _darkTextHighEmphasis = Colors.white;
  static const Color _darkTextMediumEmphasis =
      Color(0xFF9E9E9E); // Grey-400 equivalent
  static const Color _darkTextLowEmphasis = Color(0xFF757575);
  static const Color _lightTextHighEmphasis = Color(0xFF111827);
  static const Color _lightTextMediumEmphasis = Color(0xFF667085);
  static const Color _lightTextLowEmphasis = Color(0xFF98A2B3);

  static const Color error = Color(0xFFFF5252);
  static const Color success = Color(0xFF4CAF50);

  static bool _isDark = false;

  static bool get isDark => _isDark;

  static Color get background => _isDark ? _darkBackground : _lightBackground;
  static Color get surface => _isDark ? _darkSurface : _lightSurface;
  static Color get card => _isDark ? _darkCard : _lightCard;
  static Color get textHighEmphasis =>
      _isDark ? _darkTextHighEmphasis : _lightTextHighEmphasis;
  static Color get textMediumEmphasis =>
      _isDark ? _darkTextMediumEmphasis : _lightTextMediumEmphasis;
  static Color get textLowEmphasis =>
      _isDark ? _darkTextLowEmphasis : _lightTextLowEmphasis;
  static Color get divider =>
      _isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE4E7EC);
  static Color get subtleBorder =>
      _isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE4E7EC);
  static Color get subtleFill =>
      _isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF2F4F7);
  static Color get selectedSoftFill => _isDark
      ? primary.withValues(alpha: 0.16)
      : primary.withValues(alpha: 0.10);
  static Color get chartGrid =>
      _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE4E7EC);
  static Color get modalHandle => _isDark
      ? Colors.white.withValues(alpha: 0.20)
      : _lightTextLowEmphasis.withValues(alpha: 0.55);
  static Color get shadow => _isDark
      ? Colors.black.withValues(alpha: 0.35)
      : Colors.black.withValues(alpha: 0.08);

  static String normalizeThemeMode(String? mode) {
    return switch (mode) {
      systemMode => systemMode,
      darkMode => darkMode,
      lightMode => lightMode,
      _ => systemMode,
    };
  }

  static ThemeMode toFlutterThemeMode(String mode) {
    return switch (normalizeThemeMode(mode)) {
      darkMode => ThemeMode.dark,
      lightMode => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  static void setThemeMode(
    String mode, {
    Brightness? platformBrightness,
  }) {
    final normalized = normalizeThemeMode(mode);
    final effectivePlatformBrightness = platformBrightness ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _isDark = normalized == darkMode ||
        (normalized == systemMode &&
            effectivePlatformBrightness == Brightness.dark);
  }

  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      background: _lightBackground,
      surface: _lightSurface,
      cardColor: _lightCard,
      textHigh: _lightTextHighEmphasis,
      textMedium: _lightTextMediumEmphasis,
      textLow: _lightTextLowEmphasis,
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      background: _darkBackground,
      surface: _darkSurface,
      cardColor: _darkCard,
      textHigh: _darkTextHighEmphasis,
      textMedium: _darkTextMediumEmphasis,
      textLow: _darkTextLowEmphasis,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color cardColor,
    required Color textHigh,
    required Color textMedium,
    required Color textLow,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: _darkBackground,
        tertiary: secondary,
        onTertiary: _darkBackground,
        error: error,
        onError: Colors.white,
        surface: surface,
        onSurface: textHigh,
      ),
      textTheme: GoogleFonts.lexendTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ).copyWith(
        displayLarge:
            GoogleFonts.lexend(color: textHigh, fontWeight: FontWeight.bold),
        displayMedium:
            GoogleFonts.lexend(color: textHigh, fontWeight: FontWeight.bold),
        displaySmall:
            GoogleFonts.lexend(color: textHigh, fontWeight: FontWeight.bold),
        headlineLarge:
            GoogleFonts.lexend(color: textHigh, fontWeight: FontWeight.bold),
        headlineMedium:
            GoogleFonts.lexend(color: textHigh, fontWeight: FontWeight.w600),
        headlineSmall:
            GoogleFonts.lexend(color: textHigh, fontWeight: FontWeight.w600),
        titleLarge:
            GoogleFonts.lexend(color: textHigh, fontWeight: FontWeight.w600),
        titleMedium:
            GoogleFonts.lexend(color: textHigh, fontWeight: FontWeight.w500),
        titleSmall:
            GoogleFonts.lexend(color: textHigh, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.lexend(color: textHigh),
        bodyMedium: GoogleFonts.lexend(color: textMedium),
        bodySmall: GoogleFonts.lexend(color: textLow),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textHigh),
        titleTextStyle: TextStyle(
            color: textHigh, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
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
          foregroundColor: textHigh,
          side: BorderSide(color: surface, width: 2),
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
        labelStyle: TextStyle(color: textMedium),
        hintStyle: TextStyle(color: textMedium),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textLow,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
