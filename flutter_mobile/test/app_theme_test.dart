import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/core/theme.dart';

void main() {
  testWidgets('system theme mode follows platform brightness',
      (WidgetTester tester) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    AppTheme.setThemeMode(AppTheme.systemMode);

    expect(AppTheme.isDark, isTrue);
  });

  testWidgets('explicit theme modes override platform brightness',
      (WidgetTester tester) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    AppTheme.setThemeMode(AppTheme.lightMode);
    expect(AppTheme.isDark, isFalse);

    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;

    AppTheme.setThemeMode(AppTheme.darkMode);
    expect(AppTheme.isDark, isTrue);
  });
}
