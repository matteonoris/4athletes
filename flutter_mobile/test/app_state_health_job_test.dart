import 'dart:async';

import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/services/health_sync_service.dart';
import 'package:flutter_mobile/utils/metrics_engine.dart';
import 'package:flutter_mobile/services/daily_strain_persistence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://placeholder.supabase.co',
        anonKey: 'test-key',
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false, detectSessionInUri: false));
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('navigation and reopening today keep the same calculation alive',
      () async {
    final source = _DelayedScores();
    final state = _TestState(source);
    await state.init();
    final today = DateTime.now();
    await state.syncDailyHealthData(today);
    final job = state.refreshAllHealthData(today);
    await source.waitForCall(1);
    final duplicate = state.refreshAllHealthData(today);
    expect(identical(job, duplicate), isTrue);
    await state.syncDailyHealthData(today);
    expect(state.isSyncingHealth, isTrue);
    expect(state.isSyncingHealthForDate(today), isTrue);
    source.requests.single.complete(_result());
    await job;
    expect(state.sleepScoreForDate(today), 72);
    expect(state.recoveryScoreForDate(today), 65);
    expect(state.isSyncingHealth, isFalse);
    expect(state.lastHealthScoreUpdate?.revision, 1);
    await state.syncDailyHealthData(today);
    expect(state.lastHealthScoreUpdate?.revision, 1);
    expect(source.requests, hasLength(1));
    expect(
        (await SharedPreferences.getInstance())
            .getString('health_sync_pending_'),
        isNull);
  });

  test(
      'finishing today while viewing yesterday updates history without changing the view',
      () async {
    final source = _DelayedScores();
    final state = _TestState(source);
    await state.init();
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    state.addLocalBodyLog(BodyMetricLog(
        id: 'old',
        date: localDateKey(yesterday),
        type: 'sleep_score',
        value: 54));
    await state.syncDailyHealthData(today);
    final job = state.refreshAllHealthData(today);
    await source.waitForCall(1);
    await state.syncDailyHealthData(yesterday);
    expect(state.isSyncingHealthForDate(yesterday), isFalse);
    source.requests.single.complete(_result());
    await job;
    expect(state.currentHealthDateKey, localDateKey(yesterday));
    expect(state.sleepScoreForDate(yesterday), 54);
    expect(state.sleepScoreForDate(today), 72);
    expect(state.wellnessScoreLogs.where((log) => log.type == 'sleep_score'),
        hasLength(2));
    await state.syncDailyHealthData(today);
    expect(state.dailyMetricsForDate(today)?['deepSleep'], 80);
  });

  test('a failed refresh retains the snapshot and never announces success',
      () async {
    final source = _DelayedScores();
    final state = _TestState(source);
    await state.init();
    final today = DateTime.now();
    state.addLocalBodyLog(BodyMetricLog(
        id: 'saved',
        date: localDateKey(today),
        type: 'sleep_score',
        value: 60));
    await state.syncDailyHealthData(today);
    final job = state.refreshAllHealthData(today);
    await source.waitForCall(1);
    source.requests.single
        .completeError(StateError('Unavailable health source'));
    await job;
    expect(state.sleepScoreForDate(today), 60);
    expect(state.lastHealthScoreUpdate, isNull);
    expect(state.isSyncingHealth, isFalse);
    expect(state.healthSyncError, contains('Unavailable'));
  });

  test('a queued date starts after the first job without cancelling it',
      () async {
    final source = _DelayedScores();
    final state = _TestState(source);
    await state.init();
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    await state.syncDailyHealthData(yesterday);
    final first = state.refreshAllHealthData(today);
    await source.waitForCall(1);
    final second = state.refreshAllHealthData(yesterday);
    source.requests.first.complete(_result());
    await first;
    await source.waitForCall(2);
    source.requests.last.complete(_result(sleep: 55));
    await second;
    expect(state.sleepScoreForDate(today), 72);
    expect(state.sleepScoreForDate(yesterday), 55);
    expect(state.currentHealthDateKey, localDateKey(yesterday));
    expect(state.lastHealthScoreUpdate?.revision, 2);
    expect(state.isSyncingHealth, isFalse);
  });
}

class _DelayedScores extends HealthSyncService {
  final requests = <Completer<HealthSyncResult>>[];
  @override
  Future<HealthSyncResult> fetchAndCalculateScores(
      UserProfile profile, List<BodyMetricLog> logs,
      {DateTime? targetDate, bool requestPermissions = true}) {
    final pending = Completer<HealthSyncResult>();
    requests.add(pending);
    return pending.future;
  }

  Future<void> waitForCall(int count) async {
    for (var i = 0; requests.length < count && i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(requests.length, count);
  }
}

class _TestState extends AppState {
  _TestState(HealthSyncService service) : super(healthSyncService: service);
  @override
  UserProfile get userProfile => UserProfile(
      firstName: 'Test',
      lastName: 'Athlete',
      email: '',
      birthDate: '1990-01-01',
      role: 'athlete',
      weight: 70,
      height: 175,
      maxHr: 190,
      unitSystem: 'metric',
      language: 'it',
      avatarUrl: '',
      notificationsEnabled: false,
      connectedDevices: []);
  @override
  Future<void> syncDailyHealthMetrics({bool requestPermissions = true}) async {}
  @override
  Future<void> syncDailyStrainScore(DateTime targetDate,
      {bool notify = true}) async {}
  @override
  Future<bool> addBodyLog(BodyMetricLog log,
      {bool updateProfile = true, bool notify = true}) async {
    addLocalBodyLog(log);
    return true;
  }
}

HealthSyncResult _result({double sleep = 72}) => HealthSyncResult(
    sleep,
    65,
    {'deepSleep': 80},
    {},
    [],
    RecoveryAndSleepResult(
      sleepScore: ScoreResult(
          score: sleep,
          status: ScoreStatus.ok,
          confidence: 1,
          components: {},
          warnings: []),
      recoveryScore: const ScoreResult(
          score: 65,
          status: ScoreStatus.ok,
          confidence: 1,
          components: {},
          warnings: []),
      dailySleepNeed: const DailySleepNeedResult(
          valueMinutes: 480,
          personalBaselineMinutes: 480,
          sleepDebtMinutes: 0,
          dailyStrainAdjustmentMinutes: 0,
          napsDeductionMinutes: 0,
          confidence: 1,
          warnings: []),
      appliedConfigVersion: defaultAlgorithmConfig.version,
    ));
