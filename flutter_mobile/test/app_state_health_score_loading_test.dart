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

  test('pre-conversion health caches cannot restore fractional oxygen', () async {
    final today = DateTime.now();
    final dateKey = _dateKey(today);
    SharedPreferences.setMockInitialValues({
      'health_sync_v12_science_v2_$dateKey': jsonEncode({
        'sleepScore': 81,
        'recoveryScore': 74,
        'dailyMetrics': {'spo2': 0.97},
        'historicalMetrics': {'spo2': [0.96, 0.98]},
        'algorithmVersion': defaultAlgorithmConfig.version,
      }),
    });
    final state = AppState();
    await state.init();
    await state.syncDailyHealthData(today);
    expect(state.dailyMetricsForDate(today), isNull);
    expect(state.historicalMetricsForDate(today), isNull);
    expect(state.recoveryScoreForDate(today), isNull);
  });

  test('opening today restores its cached scores without recalculating',
      () async {
    final today = DateTime.now();
    final dateKey = _dateKey(today);
    SharedPreferences.setMockInitialValues({
      'health_sync_v13_health_units_$dateKey': jsonEncode({
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
    expect(
        state.wellnessScoreLogs
            .where((log) => log.type == 'sleep_score')
            .single
            .value,
        81);
    expect(
        state.wellnessScoreLogs
            .where((log) => log.type == 'recovery_score')
            .single
            .value,
        74);
  });

  test(
      'an unavailable recalculated recovery cannot resurrect an older high score',
      () async {
    final today = DateTime.now();
    final dateKey = _dateKey(today);
    SharedPreferences.setMockInitialValues({
      'health_sync_v13_health_units_$dateKey': jsonEncode({
        'sleepScore': 58,
        'recoveryScore': null,
        'algorithmVersion': defaultAlgorithmConfig.version,
        'recoveryStatus': 'INSUFFICIENT_DATA',
      }),
    });
    final state = AppState();
    await state.init();
    state.addLocalBodyLog(BodyMetricLog(
        id: 'old-recovery', date: dateKey, type: 'recovery_score', value: 92));
    state.addLocalBodyLog(BodyMetricLog(
        id: 'old-sleep', date: dateKey, type: 'sleep_score', value: 95));
    // The recalculated cache is newer than the last persisted observations.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'health_sync_v13_health_units_$dateKey',
        jsonEncode({
          'sleepScore': 58,
          'recoveryScore': null,
          'algorithmVersion': defaultAlgorithmConfig.version,
          'recoveryStatus': 'INSUFFICIENT_DATA',
        }));
    await state.syncDailyHealthData(today);
    expect(state.sleepScoreForDate(today), 58);
    expect(state.recoveryScoreForDate(today), isNull);
    expect(state.wellnessScoreLogs.where((log) => log.type == 'recovery_score'),
        isEmpty);
    expect(
        state.wellnessScoreLogs
            .where((log) => log.type == 'sleep_score')
            .single
            .value,
        58);
    expect(state.wellnessScoreLogs.single.id, 'old-sleep');

    await state.syncDailyHealthData(today.subtract(const Duration(days: 1)));
    expect(state.recoveryScoreForDate(today), isNull);
    expect(state.wellnessScoreLogs.where((log) => log.type == 'recovery_score'),
        isEmpty);
  });

  test(
      'old algorithm caches are ignored and a newer score updates cards and series',
      () async {
    final today = DateTime.now();
    final dateKey = _dateKey(today);
    SharedPreferences.setMockInitialValues({
      'health_sync_v13_health_units_$dateKey': jsonEncode({
        'sleepScore': 99,
        'recoveryScore': 99,
        'algorithmVersion': 'old-version',
      }),
    });
    final state = AppState();
    await state.init();
    await state.syncDailyHealthData(today);
    expect(state.sleepScoreForDate(today), isNull);
    expect(state.recoveryScoreForDate(today), isNull);
    state.addLocalBodyLog(BodyMetricLog(
        id: 'new', date: dateKey, type: 'sleep_score', value: 58));
    expect(state.sleepScoreForDate(today), 58);
    expect(state.wellnessScoreLogs.single.value, 58);
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
