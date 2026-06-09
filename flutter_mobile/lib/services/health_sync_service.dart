import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../models/models.dart';
import '../utils/metrics_engine.dart';

class HealthSyncResult {
  final double sleepScore;
  final double? recoveryScore;
  final Map<String, double> dailyMetrics;
  final Map<String, List<double>> historicalMetrics;
  final List<Map<String, dynamic>> localSleepHistory;
  final RecoveryAndSleepResult scoringResult;

  HealthSyncResult(
    this.sleepScore,
    this.recoveryScore,
    this.dailyMetrics,
    this.historicalMetrics,
    this.localSleepHistory,
    this.scoringResult,
  );
}

class HealthSyncService {
  final Health _health = Health();
  final AthleteMetricsEngine _metricsEngine = const AthleteMetricsEngine();
  static const Duration _mainSleepMaxGap = Duration(minutes: 90);
  static const int _napStartHour = 9;
  static const int _napEndHour = 20;

  Future<HealthSyncResult> fetchAndCalculateScores(
      bool isLutealPhase, List<BodyMetricLog> bodyLogs,
      [DateTime? targetDate]) async {
    await _health.configure();

    // Definizione dei tipi di dati da richiedere per le misurazioni orarie/giornaliere (es. sonno)
    final types = _readableSleepTypes;
    final permissions = types.map((_) => HealthDataAccess.READ).toList();

    // Verifica permessi
    bool? hasPermissions =
        await _health.hasPermissions(types, permissions: permissions);
    if (hasPermissions == null || !hasPermissions) {
      bool authorized =
          await _health.requestAuthorization(types, permissions: permissions);
      if (!authorized) {
        debugPrint(
            'Health sync: not every sleep permission was granted; continuing with available streams.');
      }
    }

    final target = targetDate ?? DateTime.now();
    final now = DateTime(target.year, target.month, target.day, 23, 59, 59);
    final sleepHistoryStart = now.subtract(const Duration(days: 90));
    final monthAgo = now.subtract(const Duration(days: 30));

    final targetStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(hours: 6));
    final targetEnd = now;

    // Estrazione dati storici SONNO
    List<HealthDataPoint> healthData = await _fetchHealthDataByType(
      startTime: sleepHistoryStart,
      endTime: now,
      types: types,
    );

    // Dati odierni SONNO
    List<HealthDataPoint> todayData = await _fetchHealthDataByType(
      startTime: targetStart,
      endTime: targetEnd,
      types: types,
    );

    // Helper per estrarre history e today dai bodyLogs
    List<double> extractHistory(String type) {
      var filtered = bodyLogs
          .where((l) =>
              l.type == type &&
              DateTime.parse(l.date).isAfter(monthAgo) &&
              DateTime.parse(l.date).isBefore(now.add(const Duration(days: 1))))
          .toList();
      filtered.sort((a, b) => a.date.compareTo(b.date));
      return filtered.map((e) => e.value).toList();
    }

    double? getValueForDate(String type, DateTime date) {
      String dateStr = date.toIso8601String().split('T')[0];
      var point =
          bodyLogs.where((l) => l.type == type && l.date == dateStr).lastOrNull;
      return point?.value;
    }

    double? getTodayVal(String type) {
      String dateStr = target.toIso8601String().split('T')[0];
      var point =
          bodyLogs.where((l) => l.type == type && l.date == dateStr).lastOrNull;
      return point?.value;
    }

    // --- AGGREGAZIONE DATI STORICI ---
    List<double> rhrHistory = extractHistory('resting_hr');
    List<double> tempHistory = extractHistory('temp');
    List<double> hrvHistory = extractHistory('hrv');
    List<double> respHistory = extractHistory('resp');
    List<double> spo2History = extractHistory('spo2');

    // --- AGGREGAZIONE DATI ODIERNI ---
    double? rhrToday = getTodayVal('resting_hr');
    double? tempToday = getTodayVal('temp');
    double? hrvToday = getTodayVal('hrv');
    double? respToday = getTodayVal('resp');
    double? spo2Today = getTodayVal('spo2');

    var todaySleep = _aggregateSleepForDate(todayData, target);
    if (todaySleep.totalSleepMinutes == null) {
      throw Exception('NO_TODAY_SLEEP_DATA');
    }

    final historicalWearableData = <DailyWearableData>[];
    for (int i = 30; i >= 1; i--) {
      final day = target.subtract(Duration(days: i));
      final sleep = _aggregateSleepForDate(healthData, day);
      historicalWearableData.add(
        DailyWearableData(
          date: _dateKey(day),
          totalSleepTimeMinutes: sleep.totalSleepMinutes,
          deepSleepMinutes: sleep.deepSleepMinutes,
          remSleepMinutes: sleep.remSleepMinutes,
          timeInBedMinutes: sleep.timeInBedMinutes,
          sleepOnsetTimestamp: sleep.sleepOnset,
          naps: _napsForDate(healthData, day),
          restingHeartRateBpm: getValueForDate('resting_hr', day),
          skinTemperatureCelsius: getValueForDate('temp', day),
          hrvRmssdMs: getValueForDate('hrv', day),
          respiratoryRate: getValueForDate('resp', day),
          spo2Percent: getValueForDate('spo2', day),
          previousDayStrainScore: getValueForDate(
            'strain_score',
            day.subtract(const Duration(days: 1)),
          ),
        ),
      );
    }

    final profile = AthleteProfile(
      athleteId: 'local-athlete',
      sex: isLutealPhase ? Sex.female : Sex.unknown,
      isLutealPhase: isLutealPhase,
      timezone: DateTime.now().timeZoneName,
    );
    final todayWearableData = DailyWearableData(
      date: _dateKey(target),
      totalSleepTimeMinutes: todaySleep.totalSleepMinutes,
      deepSleepMinutes: todaySleep.deepSleepMinutes,
      remSleepMinutes: todaySleep.remSleepMinutes,
      timeInBedMinutes: todaySleep.timeInBedMinutes,
      sleepOnsetTimestamp: todaySleep.sleepOnset,
      naps: _napsForDate(healthData, target),
      restingHeartRateBpm: rhrToday,
      skinTemperatureCelsius: tempToday,
      hrvRmssdMs: hrvToday,
      respiratoryRate: respToday,
      spo2Percent: spo2Today,
      previousDayStrainScore: getValueForDate(
        'strain_score',
        target.subtract(const Duration(days: 1)),
      ),
    );

    final scoringResult = calculateRecoveryAndSleep(
      profile,
      todayWearableData,
      historicalWearableData,
      config: _metricsEngine.config,
    );
    final sleepScore = scoringResult.sleepScore.score;
    if (sleepScore == null) {
      throw Exception('NO_TODAY_SLEEP_DATA');
    }
    final recoveryScore = scoringResult.recoveryScore.score;
    final circadianComponent =
        scoringResult.sleepScore.components['circadianRegularity'];
    final circadianScore = circadianComponent is Map<String, dynamic>
        ? (circadianComponent['value'] as num?)?.toDouble()
        : null;

    Map<String, double> dailyMetrics = {
      if (rhrToday != null) 'rhr': rhrToday,
      if (tempToday != null) 'temp': tempToday,
      if (hrvToday != null) 'hrv': hrvToday,
      if (respToday != null) 'resp': respToday,
      if (spo2Today != null) 'spo2': spo2Today,
      'totalSleep': todaySleep.totalSleepMinutes!,
      if (todaySleep.deepSleepMinutes != null)
        'deepSleep': todaySleep.deepSleepMinutes!,
      if (todaySleep.remSleepMinutes != null)
        'remSleep': todaySleep.remSleepMinutes!,
      if (todaySleep.lightSleepMinutes != null)
        'lightSleep': todaySleep.lightSleepMinutes!,
      if (todaySleep.awakeMinutes != null) 'awake': todaySleep.awakeMinutes!,
      if (todaySleep.timeInBedMinutes != null)
        'timeInBed': todaySleep.timeInBedMinutes!,
      if (circadianScore != null) 'sleepRegularity': circadianScore,
      'dailySleepNeed': scoringResult.dailySleepNeed.valueMinutes,
      'sleepDebt': scoringResult.dailySleepNeed.sleepDebtMinutes,
      'naps': scoringResult.dailySleepNeed.napsDeductionMinutes,
    };

    Map<String, List<double>> historicalMetrics = {
      'rhr': rhrHistory,
      'temp': tempHistory,
      'hrv': hrvHistory,
      'resp': respHistory,
      'spo2': spo2History,
    };

    List<Map<String, dynamic>> localSleepHistory =
        _extractLocalSleepHistory(healthData, target);

    return HealthSyncResult(
      sleepScore,
      recoveryScore,
      dailyMetrics,
      historicalMetrics,
      localSleepHistory,
      scoringResult,
    );
  }

  // --- Helper Functions per estrarre i dati grezzi ---

  Future<List<HealthDataPoint>> _fetchHealthDataByType({
    required DateTime startTime,
    required DateTime endTime,
    required List<HealthDataType> types,
  }) async {
    final points = <HealthDataPoint>[];

    for (final type in types) {
      try {
        final typePoints = await _health.getHealthDataFromTypes(
          startTime: startTime,
          endTime: endTime,
          types: [type],
        );
        points.addAll(typePoints);
        // Keep this lightweight but visible in debug logs; it is the fastest way
        // to diagnose Health Connect source/permission gaps on real devices.
        debugPrint(
            'Health sync: ${type.name} returned ${typePoints.length} points');
      } catch (e) {
        // Health Connect grants access per data class. Continue with any sleep
        // streams that are available instead of failing the whole readiness card.
        debugPrint('Health sync: failed to fetch ${type.name}: $e');
      }
    }

    return points;
  }

  double _sumSleepMinutes(
      List<HealthDataPoint> data, List<HealthDataType> types) {
    var filtered = data.where((d) => types.contains(d.type)).toList();
    if (filtered.isEmpty) return 0.0;

    double totalMinutes = 0.0;
    for (var point in filtered) {
      totalMinutes +=
          point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
    }
    return totalMinutes;
  }

  _SleepDayAggregate _aggregateSleepForDate(
    List<HealthDataPoint> data,
    DateTime day,
  ) {
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final sleepTypes = _readableSleepTypes;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayPoints = _mainSleepPointsForDate(
      data: data,
      sleepTypes: sleepTypes,
      dayStart: dayStart,
      dayEnd: end,
    );

    if (dayPoints.isEmpty) return const _SleepDayAggregate();

    var totalSleep = _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_ASLEEP]);
    if (totalSleep == 0) {
      totalSleep = _sumSleepMinutes(dayPoints, [
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
      ]);
    }
    if (totalSleep == 0) {
      // Some Android sources expose only a Sleep Session or an unknown sleep
      // stage. Treat that duration as usable for Sleep Score duration, while
      // leaving architecture unavailable instead of inventing deep/REM values.
      totalSleep = _sumSleepMinutes(dayPoints, [
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_UNKNOWN,
      ]);
    }

    final deepSleep = _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_DEEP]);
    final remSleep = _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_REM]);
    final lightSleep =
        _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_LIGHT]);
    final awake = _sumSleepMinutes(dayPoints, [
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_AWAKE_IN_BED,
    ]);
    var timeInBed = _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_IN_BED]);
    if (timeInBed == 0) {
      timeInBed = _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_SESSION]);
    }
    if (timeInBed == 0) {
      timeInBed = _sumSleepMinutes(
        dayPoints,
        [
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_REM,
          HealthDataType.SLEEP_UNKNOWN,
          HealthDataType.SLEEP_AWAKE,
          HealthDataType.SLEEP_AWAKE_IN_BED,
        ],
      );
    }

    return _SleepDayAggregate(
      totalSleepMinutes: totalSleep > 0 ? totalSleep : null,
      deepSleepMinutes: deepSleep > 0 ? deepSleep : null,
      remSleepMinutes: remSleep > 0 ? remSleep : null,
      lightSleepMinutes: lightSleep > 0 ? lightSleep : null,
      awakeMinutes: awake > 0 ? awake : null,
      timeInBedMinutes: timeInBed > 0 ? timeInBed : null,
      sleepOnset: _firstPointStart(dayPoints),
      wakeTime: _lastPointEnd(dayPoints),
    );
  }

  String _dateKey(DateTime date) => date.toIso8601String().split('T')[0];

  List<Map<String, dynamic>> _extractLocalSleepHistory(
      List<HealthDataPoint> data, DateTime target) {
    var sleepTypes = _readableSleepTypes;
    var sleepData = data.where((d) => sleepTypes.contains(d.type)).toList();

    List<Map<String, dynamic>> history = [];

    for (int i = 0; i < 90; i++) {
      DateTime day = target.subtract(Duration(days: i));
      DateTime dayStart = DateTime(day.year, day.month, day.day);
      DateTime end = DateTime(day.year, day.month, day.day, 23, 59, 59);

      var dayPoints = _mainSleepPointsForDate(
        data: sleepData,
        sleepTypes: sleepTypes,
        dayStart: dayStart,
        dayEnd: end,
      );
      if (dayPoints.isNotEmpty) {
        DateTime onset = _firstPointStart(dayPoints);
        DateTime wakeTime = _lastPointEnd(dayPoints);

        double totalSleepTime =
            _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_ASLEEP]);
        if (totalSleepTime == 0) {
          totalSleepTime = _sumSleepMinutes(dayPoints, [
            HealthDataType.SLEEP_LIGHT,
            HealthDataType.SLEEP_DEEP,
            HealthDataType.SLEEP_REM
          ]);
        }
        if (totalSleepTime == 0) {
          totalSleepTime = _sumSleepMinutes(dayPoints, [
            HealthDataType.SLEEP_SESSION,
            HealthDataType.SLEEP_UNKNOWN,
          ]);
        }
        if (totalSleepTime <= 0) continue;

        final deepSleep =
            _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_DEEP]);
        final remSleep =
            _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_REM]);
        final lightSleep =
            _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_LIGHT]);
        final awake = _sumSleepMinutes(dayPoints, [
          HealthDataType.SLEEP_AWAKE,
          HealthDataType.SLEEP_AWAKE_IN_BED,
        ]);
        var timeInBed =
            _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_IN_BED]);
        if (timeInBed == 0) {
          timeInBed =
              _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_SESSION]);
        }

        history.add({
          'date': day.toIso8601String().split('T')[0],
          'bedTime': onset.toIso8601String(),
          'wakeTime': wakeTime.toIso8601String(),
          'totalSleepMinutes': totalSleepTime,
          if (deepSleep > 0) 'deepSleepMinutes': deepSleep,
          if (remSleep > 0) 'remSleepMinutes': remSleep,
          if (lightSleep > 0) 'lightSleepMinutes': lightSleep,
          if (awake > 0) 'awakeMinutes': awake,
          if (timeInBed > 0) 'timeInBedMinutes': timeInBed,
        });
      }
    }

    return history;
  }

  List<HealthDataPoint> _mainSleepPointsForDate({
    required List<HealthDataPoint> data,
    required List<HealthDataType> sleepTypes,
    required DateTime dayStart,
    required DateTime dayEnd,
  }) {
    final blocks = _sleepBlocksForDate(
      data: data,
      sleepTypes: sleepTypes,
      dayStart: dayStart,
      dayEnd: dayEnd,
    );
    final mainBlock = _selectMainSleepBlock(blocks);
    if (mainBlock == null) return const [];

    return List<HealthDataPoint>.from(mainBlock)
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
  }

  List<Nap> _napsForDate(List<HealthDataPoint> data, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final blocks = _sleepBlocksForDate(
      data: data,
      sleepTypes: _readableSleepTypes,
      dayStart: dayStart,
      dayEnd: dayEnd,
    );
    final mainBlock = _selectMainSleepBlock(blocks);
    if (mainBlock == null) return const [];

    final naps = <Nap>[];
    for (final block in blocks) {
      if (identical(block, mainBlock)) continue;

      final start = _firstPointStart(block).toLocal();
      if (start.hour < _napStartHour || start.hour >= _napEndHour) {
        continue;
      }

      final duration = _mainSleepDuration(block);
      if (duration <= 0) continue;

      naps.add(
        Nap(
          startTimestamp: _firstPointStart(block),
          endTimestamp: _lastPointEnd(block),
          durationMinutes: duration,
        ),
      );
    }

    return naps;
  }

  List<List<HealthDataPoint>> _sleepBlocksForDate({
    required List<HealthDataPoint> data,
    required List<HealthDataType> sleepTypes,
    required DateTime dayStart,
    required DateTime dayEnd,
  }) {
    final candidates = data
        .where((point) =>
            sleepTypes.contains(point.type) &&
            point.dateFrom.isBefore(dayEnd) &&
            point.dateTo.isAfter(dayStart) &&
            !point.dateTo.isAfter(dayEnd))
        .toList()
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    if (candidates.isEmpty) return const [];
    if (candidates.length == 1) return [candidates];

    final blocks = <List<HealthDataPoint>>[];
    var current = <HealthDataPoint>[];
    DateTime? currentEnd;

    for (final point in candidates) {
      if (current.isEmpty ||
          currentEnd == null ||
          point.dateFrom.difference(currentEnd) <= _mainSleepMaxGap) {
        current.add(point);
      } else {
        blocks.add(current);
        current = [point];
      }
      if (currentEnd == null || point.dateTo.isAfter(currentEnd)) {
        currentEnd = point.dateTo;
      }
    }
    if (current.isNotEmpty) blocks.add(current);

    return blocks;
  }

  List<HealthDataPoint>? _selectMainSleepBlock(
    List<List<HealthDataPoint>> blocks,
  ) {
    if (blocks.isEmpty) return null;
    final sorted = List<List<HealthDataPoint>>.from(blocks)
      ..sort((a, b) {
        final bySleep = _mainSleepDuration(b).compareTo(_mainSleepDuration(a));
        if (bySleep != 0) return bySleep;
        return _blockDuration(b).compareTo(_blockDuration(a));
      });
    return sorted.first;
  }

  double _mainSleepDuration(List<HealthDataPoint> points) {
    var total = _sumSleepMinutes(points, [HealthDataType.SLEEP_ASLEEP]);
    if (total > 0) return total;

    total = _sumSleepMinutes(points, [
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
    ]);
    if (total > 0) return total;

    return _sumSleepMinutes(points, [
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_UNKNOWN,
    ]);
  }

  double _blockDuration(List<HealthDataPoint> points) {
    if (points.isEmpty) return 0;
    return _lastPointEnd(points)
        .difference(_firstPointStart(points))
        .inMinutes
        .toDouble();
  }

  DateTime _firstPointStart(List<HealthDataPoint> points) {
    return points
        .map((point) => point.dateFrom)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime _lastPointEnd(List<HealthDataPoint> points) {
    return points
        .map((point) => point.dateTo)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  List<HealthDataType> get _readableSleepTypes {
    if (Platform.isIOS) {
      return const [
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
      ];
    }

    return const [
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_AWAKE_IN_BED,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_OUT_OF_BED,
      HealthDataType.SLEEP_UNKNOWN,
    ];
  }
}

class _SleepDayAggregate {
  final double? totalSleepMinutes;
  final double? deepSleepMinutes;
  final double? remSleepMinutes;
  final double? lightSleepMinutes;
  final double? awakeMinutes;
  final double? timeInBedMinutes;
  final DateTime? sleepOnset;
  final DateTime? wakeTime;

  const _SleepDayAggregate({
    this.totalSleepMinutes,
    this.deepSleepMinutes,
    this.remSleepMinutes,
    this.lightSleepMinutes,
    this.awakeMinutes,
    this.timeInBedMinutes,
    this.sleepOnset,
    this.wakeTime,
  });
}
