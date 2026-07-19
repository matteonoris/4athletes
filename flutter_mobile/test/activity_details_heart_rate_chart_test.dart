import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/activity_details_screen.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTYwMDAwMDAwMCwiZXhwIjoyMDAwMDAwMDAwfQ.placeholder',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });

  for (final mode in [AppTheme.lightMode, AppTheme.darkMode]) {
    testWidgets(
      'heart-rate chart preserves workout bounds and provider scale in $mode',
      (tester) async {
        final start = DateTime(2026, 7, 13, 17, 2);
        final end =
            start.add(const Duration(hours: 1, minutes: 9, seconds: 19));
        final samples = List.generate(18, (index) {
          final bpm = index == 12 ? 163.0 : 64.0 + (index * 4.5);
          return {
            'time': start
                .add(Duration(minutes: 1 + index * 4))
                .millisecondsSinceEpoch,
            'bpm': bpm,
          };
        });

        final session = TrainingSession(
          id: 'imported-strength-session',
          sportId: 'weightlifting',
          date: '2026-07-13',
          startTime: '17:02:00',
          endTime: '18:11:19',
          duration: '69',
          effort: 5,
          details: {
            'source': 'health_sync',
            'workout_start_ms': start.millisecondsSinceEpoch,
            'workout_end_ms': end.millisecondsSinceEpoch,
            'active_duration_seconds': 4159,
            'hr_reliable': true,
            'hr_sample_count': samples.length,
            'hr_coverage_seconds': 4080,
            'avg_hr': 109,
            'max_hr': 163,
            'hr_samples': samples,
            'hr_zone_boundaries': const [
              {'min': 102, 'max': 129},
              {'min': 130, 'max': 143},
              {'min': 144, 'max': 157},
              {'min': 158, 'max': 173},
              {'min': 174, 'max': 187},
            ],
            'hr_zones_seconds': const [1748, 1541, 398, 394, 78, 0],
            'dominant_hr_zone': 0,
          },
        );

        AppTheme.setThemeMode(
          mode,
          platformBrightness:
              mode == AppTheme.darkMode ? Brightness.dark : Brightness.light,
        );
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => AppState(),
            child: MaterialApp(
              theme: mode == AppTheme.darkMode
                  ? AppTheme.darkTheme
                  : AppTheme.lightTheme,
              home: ActivityDetailsScreen(
                session: session,
                prLogs: const [],
              ),
            ),
          ),
        );
        await tester.pump();

        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(chart.data.minX, 0);
        expect(chart.data.maxX, closeTo(69 + 19 / 60, 0.001));
        expect(chart.data.minY, 40);
        expect(chart.data.maxY, 170);
        expect(
          chart.data.titlesData.bottomTitles.sideTitles.interval,
          closeTo((69 + 19 / 60) / 4, 0.001),
        );
        expect(chart.data.titlesData.rightTitles.sideTitles.interval, 32.5);
        expect(
          chart.data.lineBarsData
              .expand((bar) => bar.spots)
              .any((spot) => spot.y == 163),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
