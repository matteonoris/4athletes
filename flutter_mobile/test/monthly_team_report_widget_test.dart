import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/screens/monthly_team_report_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'le card KPI non vanno in overflow in tema ${mode.name}',
      (tester) async {
        AppTheme.setThemeMode(
          mode == ThemeMode.dark ? AppTheme.darkMode : AppTheme.lightMode,
          platformBrightness:
              mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        await tester.binding.setSurfaceSize(const Size(180, 320));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 150,
                  child: MonthlyTeamReportKpiCard(
                    label: 'Presenza media preparazione atletica',
                    value: '100%',
                    icon: Icons.fitness_center,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(MonthlyTeamReportKpiCard)).height,
          greaterThan(112),
        );
      },
    );
  }
}
