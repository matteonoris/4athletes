import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/widgets/workout_source_badges.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('badge allenatore e merge sono cumulabili', (tester) async {
    AppTheme.setThemeMode(
      AppTheme.lightMode,
      platformBrightness: Brightness.light,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: WorkoutSourceBadges(
            coachCreated: true,
            merged: true,
          ),
        ),
      ),
    );

    expect(find.text('ALLENATORE'), findsOneWidget);
    expect(find.text('MERGE'), findsOneWidget);
    expect(find.byKey(const ValueKey('workout_source_badges')), findsOneWidget);
  });
}
