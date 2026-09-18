import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/analytics_details_screen.dart';
import 'package:flutter_mobile/screens/health_screen.dart';
import 'package:flutter_mobile/utils/health_display_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('it');
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
          url: 'https://placeholder.supabase.co',
          anonKey:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.placeholder',
          authOptions: const FlutterAuthClientOptions(
              autoRefreshToken: false, detectSessionInUri: false));
    }
  });

  for (final brightness in Brightness.values) {
    for (final type in ['sleep_score', 'recovery_score']) {
      testWidgets(
          '$type athlete and coach detail keep 0–100 and calendar gaps in ${brightness.name}',
          (tester) async {
        final logs = [
          _log(type, 0, 95),
          _log(type, 0, 58),
          _log(type, 1, 0),
          _log(type, 2, double.nan),
          _log(type, 4, 65),
        ];
        final state = AppState();
        for (final log in logs) {
          state.addLocalBodyLog(log);
        }
        for (final preloaded in [false, true]) {
          await _mount(
              tester,
              state,
              brightness,
              AnalyticsDetailsScreen(
                title: type,
                type: 'body',
                exerciseId: type,
                preloadedLogs: preloaded ? logs : null,
                isReadOnly: true,
              ));
          final data = tester.widget<LineChart>(find.byType(LineChart)).data;
          expect(data.minY, 0);
          expect(data.maxY, 100);
          final series = data.lineBarsData.single;
          expect(series.isCurved, isFalse);
          expect(series.spots.length, 4);
          expect(series.spots[0], const FlSpot(0, 58));
          expect(series.spots[1], const FlSpot(1, 0));
          expect(series.spots[2], FlSpot.nullSpot);
          expect(series.spots[3], const FlSpot(4, 65));
          expect(find.text(wellnessScoreHistoryNote), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      });
    }

    testWidgets(
        'health cards do not label an old score as today in ${brightness.name}',
        (tester) async {
      final state = AppState();
      state.addLocalBodyLog(_log('sleep_score', 0, 88));
      state.addLocalBodyLog(_log('recovery_score', 0, 92));
      await _mount(tester, state, brightness, const HealthScreen());
      final charts =
          tester.widgetList<LineChart>(find.byType(LineChart)).toList();
      expect(charts.length, greaterThanOrEqualTo(2));
      for (final chart in charts.take(2)) {
        expect(chart.data.minY, 0);
        expect(chart.data.maxY, 100);
        expect(chart.data.lineBarsData.every((bar) => !bar.isCurved), isTrue);
      }
      expect(state.sleepScoreForDate(DateTime.now()), isNull);
      expect(state.recoveryScoreForDate(DateTime.now()), isNull);
      for (final title in ['Sleep Score', 'Recovery Score']) {
        expect(
            tester
                .widget<Text>(find.byKey(ValueKey('${title}_today_score')))
                .data,
            missingValue);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _mount(WidgetTester tester, AppState state, Brightness brightness,
    Widget screen) async {
  final dark = brightness == Brightness.dark;
  AppTheme.setThemeMode(dark ? AppTheme.darkMode : AppTheme.lightMode,
      platformBrightness: brightness);
  await tester.binding.setSurfaceSize(const Size(430, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: screen)));
  await tester.pumpAndSettle();
}

BodyMetricLog _log(String type, int offset, double value) {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day - 5 + offset);
  return BodyMetricLog(
      id: '$type-$offset-$value',
      type: type,
      date: day.toIso8601String().split('T').first,
      value: value);
}
