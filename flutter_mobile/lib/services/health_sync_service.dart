import 'dart:io' show Platform;
import 'package:health/health.dart';
import '../utils/metrics_engine.dart';

class HealthSyncResult {
  final double sleepScore;
  final double recoveryScore;
  final Map<String, double> dailyMetrics;
  final Map<String, List<double>> historicalMetrics;
  HealthSyncResult(this.sleepScore, this.recoveryScore, this.dailyMetrics, this.historicalMetrics);
}

class HealthSyncService {
  final Health _health = Health();
  final AthleteMetricsEngine _metricsEngine = AthleteMetricsEngine();

  Future<HealthSyncResult> fetchAndCalculateScores(bool isLutealPhase, [DateTime? targetDate]) async {
    // Definizione dei tipi di dati da richiedere
    final hrvType = Platform.isIOS ? HealthDataType.HEART_RATE_VARIABILITY_SDNN : HealthDataType.HEART_RATE_VARIABILITY_RMSSD;
    
    final types = [
      hrvType,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.BODY_TEMPERATURE,
      if (Platform.isIOS) HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.RESPIRATORY_RATE,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.WEIGHT,
    ];

    // Verifica permessi
    bool? hasPermissions = await _health.hasPermissions(types);
    if (hasPermissions == null || !hasPermissions) {
      bool authorized = await _health.requestAuthorization(types);
      if (!authorized) {
        throw Exception('Permessi per l\'app Salute (Health Connect / Apple Health) negati o non configurati. Verifica di aver fornito l\'accesso.');
      }
    }

    // targetDate calcolato per le ore serali del giorno target (per prendere i dati del giorno)
    final now = targetDate != null 
        ? DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59) 
        : DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));
    
    // Per i dati odierni (ultime 24h rispetto al target) prendiamo dalle 12:00 del giorno precedente alle 12:00 del target
    // o semplicemente le 24 ore precedenti al target.
    final targetStart = DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 12));
    final targetEnd = targetStart.add(const Duration(hours: 24));

    // Estrazione dati storici
    List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
      startTime: monthAgo,
      endTime: now,
      types: types,
    );

    // Dati odierni (ultime 24h)
    List<HealthDataPoint> todayData = await _health.getHealthDataFromTypes(
      startTime: targetStart,
      endTime: targetEnd,
      types: types,
    );

    // --- AGGREGAZIONE DATI STORICI ---
    List<double> rhrHistory = _extractDailyAverages(healthData, HealthDataType.RESTING_HEART_RATE);
    List<double> tempHistory = _extractDailyAverages(healthData, HealthDataType.BODY_TEMPERATURE);
    List<double> hrvHistory = _extractDailyAverages(healthData, hrvType);
    List<double> respHistory = _extractDailyAverages(healthData, HealthDataType.RESPIRATORY_RATE);
    List<double> spo2History = _extractDailyAverages(healthData, HealthDataType.BLOOD_OXYGEN);

    // I dati storici vengono passati direttamente all'algoritmo senza alterazioni o mock.

    // --- AGGREGAZIONE DATI ODIERNI ---
    double rhrToday = _getTodayAverage(todayData, HealthDataType.RESTING_HEART_RATE, 45.0);
    double tempToday = _getTodayAverage(todayData, HealthDataType.BODY_TEMPERATURE, 36.5);
    double hrvToday = _getTodayAverage(todayData, hrvType, 85.0);
    double respToday = _getTodayAverage(todayData, HealthDataType.RESPIRATORY_RATE, 14.0);
    double spo2Today = _getTodayAverage(todayData, HealthDataType.BLOOD_OXYGEN, 98.0);

    // --- CALCOLO SONNO ODIERNO ---
    double totalSleepTime = _sumSleepMinutes(todayData, [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_DEEP, HealthDataType.SLEEP_REM]);
    if (totalSleepTime == 0) totalSleepTime = 420; // fallback 7h
    
    double deepSleepTime = _sumSleepMinutes(todayData, [HealthDataType.SLEEP_DEEP]);
    if (deepSleepTime == 0) deepSleepTime = 90; // fallback

    double remSleepTime = _sumSleepMinutes(todayData, [HealthDataType.SLEEP_REM]);
    if (remSleepTime == 0) remSleepTime = 90; // fallback

    double timeInBed = _sumSleepMinutes(todayData, [HealthDataType.SLEEP_IN_BED]);
    if (timeInBed == 0) timeInBed = 480; // fallback 8h

    DateTime sleepOnset = DateTime.now().subtract(const Duration(hours: 8)); // Mock orrore, da calcolare iterando sui log
    DateTime avgSleepOnset = DateTime.now().subtract(const Duration(hours: 8, minutes: 15));

    // Calcolo Scores tramite il Motore
    double sleepScore = _metricsEngine.calculateSleepScore(
      totalSleepTime: totalSleepTime,
      targetSleepTime: 480, // 8 ore
      deepSleepTime: deepSleepTime,
      remSleepTime: remSleepTime,
      timeInBed: timeInBed,
      sleepOnsetTime: sleepOnset,
      avgSleepOnsetTime: avgSleepOnset,
    );

    double recoveryScore = _metricsEngine.calculateRecoveryScore(
      isLutealPhase: isLutealPhase,
      rhrToday: rhrToday,
      rhrHistory: rhrHistory,
      tempToday: tempToday,
      tempHistory: tempHistory,
      hrvToday: hrvToday,
      hrvHistory: hrvHistory,
      sleepScore: sleepScore,
      respToday: respToday,
      respHistory: respHistory,
      spo2Today: spo2Today,
      spo2History: spo2History,
    );

    Map<String, double> dailyMetrics = {
      'rhr': rhrToday,
      'temp': tempToday,
      'hrv': hrvToday,
      'resp': respToday,
      'spo2': spo2Today,
      'totalSleep': totalSleepTime,
      'deepSleep': deepSleepTime,
      'remSleep': remSleepTime,
    };

    Map<String, List<double>> historicalMetrics = {
      'rhr': rhrHistory,
      'temp': tempHistory,
      'hrv': hrvHistory,
      'resp': respHistory,
      'spo2': spo2History,
    };

    return HealthSyncResult(sleepScore, recoveryScore, dailyMetrics, historicalMetrics);
  }

  // --- Helper Functions per estrarre i dati grezzi ---

  List<double> _extractDailyAverages(List<HealthDataPoint> data, HealthDataType type) {
    var filtered = data.where((d) => d.type == type).toList();
    if (filtered.isEmpty) return [];

    // Raggruppamento per giorno
    Map<String, List<double>> dailyMap = {};
    for (var point in filtered) {
      String dayKey = "\${point.dateFrom.year}-\${point.dateFrom.month}-\${point.dateFrom.day}";
      double val = double.tryParse(point.value.toString()) ?? 0.0;
      if (val > 0) {
        if (!dailyMap.containsKey(dayKey)) dailyMap[dayKey] = [];
        dailyMap[dayKey]!.add(val);
      }
    }

    // Media per ogni giorno
    List<double> dailyAverages = [];
    for (var entries in dailyMap.values) {
      double sum = entries.reduce((a, b) => a + b);
      dailyAverages.add(sum / entries.length);
    }
    return dailyAverages;
  }

  double _getTodayAverage(List<HealthDataPoint> data, HealthDataType type, double fallback) {
    var filtered = data.where((d) => d.type == type).toList();
    if (filtered.isEmpty) return fallback;
    
    double sum = 0.0;
    int count = 0;
    for (var point in filtered) {
      double val = double.tryParse(point.value.toString()) ?? 0.0;
      if (val > 0) {
        sum += val;
        count++;
      }
    }
    return count > 0 ? (sum / count) : fallback;
  }

  double _sumSleepMinutes(List<HealthDataPoint> data, List<HealthDataType> types) {
    var filtered = data.where((d) => types.contains(d.type)).toList();
    if (filtered.isEmpty) return 0.0;

    double totalMinutes = 0.0;
    for (var point in filtered) {
      totalMinutes += point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
    }
    return totalMinutes;
  }
}
