import 'package:flutter/material.dart';

class AppTheme {
  static const String systemMode = 'system';
  static const String lightMode = 'light';
  static const String darkMode = 'dark';

  // Brand Colors
  static const Color _darkBackground = Color(0xFF12161D);
  static const Color _darkSurface = Color(0xFF1B222C);
  static const Color _darkCard = Color(0xFF222936);
  static const Color _lightBackground = Color(0xFFF6F7FB);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF7466D7);
  static const Color secondary = Color(0xFF248574);
  static const Color sleep = Color(0xFF8275F4);
  static const Color strain = Color(0xFFEFA15A);
  static const Color recovery = Color(0xFF30BBA2);
  static const double panelRadius = 26;
  static const double controlRadius = 16;

  static const Color _darkTextHighEmphasis = Color(0xFFF2F3F7);
  static const Color _darkTextMediumEmphasis = Color(0xFFAAB2C0);
  static const Color _darkTextLowEmphasis = Color(0xFF929CAC);
  static const Color _lightTextHighEmphasis = Color(0xFF202532);
  static const Color _lightTextMediumEmphasis = Color(0xFF636B7B);
  static const Color _lightTextLowEmphasis = Color(0xFF717989);

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

  /// The Home readiness card is the source of the app's surface language.
  /// A context keeps reusable widgets correct inside locally overridden themes.
  static BoxDecoration panelDecoration({
    BuildContext? context,
    Color? color,
    BorderRadiusGeometry? borderRadius,
    BoxBorder? border,
    List<BoxShadow>? boxShadow,
  }) {
    final dark = context == null
        ? _isDark
        : Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? _darkTextHighEmphasis : _lightTextHighEmphasis;
    return BoxDecoration(
      color: color,
      borderRadius: borderRadius ?? BorderRadius.circular(panelRadius),
      border:
          border ?? Border.all(color: ink.withValues(alpha: dark ? .09 : .07)),
      gradient: color != null
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(0xFF252638),
                      Color(0xFF1B252C),
                      Color(0xFF1D242A)
                    ]
                  : const [
                      Color(0xFFF8F6FF),
                      Color(0xFFFFFFFF),
                      Color(0xFFF1FAF8)
                    ],
            ),
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .12 : .035),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
    );
  }

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
    final outline = textHigh.withValues(alpha: isDark ? .12 : .10);
    final accent = isDark ? const Color(0xFFB8AEFF) : primary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Lexend',
      brightness: brightness,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: isDark ? _darkBackground : Colors.white,
        primaryContainer: primary.withValues(alpha: isDark ? .22 : .10),
        onPrimaryContainer: accent,
        secondary: isDark ? const Color(0xFF73D8C2) : secondary,
        onSecondary: isDark ? _darkBackground : Colors.white,
        tertiary: isDark ? const Color(0xFFFFBE81) : const Color(0xFF9D5B20),
        onTertiary: isDark ? _darkBackground : Colors.white,
        error: error,
        onError: Colors.white,
        surface: surface,
        onSurface: textHigh,
        onSurfaceVariant: textMedium,
        surfaceContainerLowest: background,
        surfaceContainerLow: surface,
        surfaceContainer: cardColor,
        surfaceContainerHigh: cardColor,
        surfaceContainerHighest: cardColor,
        outline: textLow,
        outlineVariant: outline,
        surfaceTint: Colors.transparent,
      ),
      textTheme:
          (isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme)
              .apply(fontFamily: 'Lexend')
              .copyWith(
                displayLarge: TextStyle(
                    fontFamily: 'Lexend',
                    color: textHigh,
                    fontWeight: FontWeight.bold),
                displayMedium: TextStyle(
                    fontFamily: 'Lexend',
                    color: textHigh,
                    fontWeight: FontWeight.bold),
                displaySmall: TextStyle(
                    fontFamily: 'Lexend',
                    color: textHigh,
                    fontWeight: FontWeight.bold),
                headlineLarge: TextStyle(
                    fontFamily: 'Lexend',
                    color: textHigh,
                    fontWeight: FontWeight.bold),
                headlineMedium: TextStyle(
                    fontFamily: 'Lexend',
                    color: textHigh,
                    fontWeight: FontWeight.w600),
                headlineSmall: TextStyle(
                    fontFamily: 'Lexend',
                    color: textHigh,
                    fontWeight: FontWeight.w600),
                titleLarge: TextStyle(
                    fontFamily: 'Lexend',
                    color: textHigh,
                    fontWeight: FontWeight.w600),
                titleMedium: TextStyle(
                    fontFamily: 'Lexend',
                    color: textHigh,
                    fontWeight: FontWeight.w500),
                titleSmall: TextStyle(
                    fontFamily: 'Lexend',
                    color: textHigh,
                    fontWeight: FontWeight.w500),
                bodyLarge: TextStyle(fontFamily: 'Lexend', color: textHigh),
                bodyMedium: TextStyle(fontFamily: 'Lexend', color: textMedium),
                bodySmall: TextStyle(fontFamily: 'Lexend', color: textLow),
              ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: textHigh),
        titleTextStyle: TextStyle(
            fontFamily: 'Lexend',
            color: textHigh,
            fontSize: 18,
            fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(panelRadius),
          side: BorderSide(color: outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 52),
          shape: shape,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontFamily: 'Lexend',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textHigh,
          side: BorderSide(color: outline),
          minimumSize: const Size(48, 52),
          shape: shape,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontFamily: 'Lexend',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        labelStyle: TextStyle(color: textMedium),
        hintStyle: TextStyle(color: textMedium),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textLow,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 70,
        indicatorColor: primary.withValues(alpha: isDark ? .24 : .12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontFamily: 'Lexend',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color:
                states.contains(WidgetState.selected) ? accent : textMedium)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 22,
            color:
                states.contains(WidgetState.selected) ? accent : textMedium)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        shape: shape,
        textStyle: const TextStyle(
            fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.w600),
      )),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: accent,
        shape: shape,
        textStyle:
            const TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w600),
      )),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(panelRadius),
            side: BorderSide(color: outline)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(panelRadius))),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: .16),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle:
            TextStyle(fontFamily: 'Lexend', color: textHigh, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xFF303747) : _lightTextHighEmphasis,
        contentTextStyle: const TextStyle(
            fontFamily: 'Lexend', color: Colors.white, fontSize: 13),
        shape: shape,
        elevation: 2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      listTileTheme:
          ListTileThemeData(iconColor: textMedium, textColor: textHigh),
    );
  }
}
