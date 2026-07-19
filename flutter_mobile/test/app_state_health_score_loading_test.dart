import 'dart:convert';

import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/utils/scoring/algorithm_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://placeholder.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTYwMDAwMDAwMCwiZXhwIjoyMDAwMDAwMDAwfQ.placeholder',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
      );
    }
  });

  test('opening today restores its cached scores without recalculating',
      () async {
    final today = DateTime.now();
    final dateKey = _dateKey(today);
    SharedPreferences.setMockInitialValues({
      'health_sync_v12_science_v2_$dateKey': jsonEncode({
        'sleepScore': 81.0,
        'recoveryScore': 74.0,
        'dailyMetrics': <String, double>{'strainScore': 39.0},
        'historicalMetrics': <String, List<double>>{},
        'localSleepHistory': <Map<String, dynamic>>[],
        'algorithmVersion': defaultAlgorithmConfig.version,
        'sleepStatus': 'OK',
        'recoveryStatus': 'OK',
      }),
    });

    final state = AppState();
    await state.init();
    await state.syncDailyHealthData(today);

    expect(state.isSyncingHealth, isFalse);
    expect(state.healthSyncCompleted, isTrue);
    expect(state.currentHealthDateKey, dateKey);
    expect(state.sleepScoreForDate(today), 81);
    expect(state.recoveryScoreForDate(today), 74);
    expect(state.strainScoreForDate(today), 39);
  });

  test('changing date hydrates persisted logs and scopes snapshot details',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    for (final entry in <(DateTime, String, double)>[
      (today, 'sleep_score', 80),
      (today, 'recovery_score', 70),
      (today, 'strain_score', 40),
      (yesterday, 'sleep_score', 77),
      (yesterday, 'recovery_score', 68),
      (yesterday, 'strain_score', 35),
    ]) {
      state.addLocalBodyLog(BodyMetricLog(
        id: '${entry.$2}_${_dateKey(entry.$1)}',
        date: _dateKey(entry.$1),
        type: entry.$2,
        value: entry.$3,
      ));
    }

    await state.syncDailyHealthData(today);
    expect(state.dailyMetricsForDate(today)?['strainScore'], 40);

    await state.syncDailyHealthData(yesterday);
    expect(state.currentHealthDateKey, _dateKey(yesterday));
    expect(state.sleepScoreForDate(yesterday), 77);
    expect(state.recoveryScoreForDate(yesterday), 68);
    expect(state.strainScoreForDate(yesterday), 35);
    expect(state.dailyMetricsForDate(today), isNull);
    expect(state.dailyMetricsForDate(yesterday)?['strainScore'], 35);
  });
}

String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
