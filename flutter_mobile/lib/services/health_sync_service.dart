import 'dart:io' show Platform;
import 'package:health/health.dart';
import '../models/models.dart';
import '../utils/metrics_engine.dart';

class HealthSyncResult {
  final double sleepScore;
  final double? recoveryScore;
  final Map<String, double> dailyMetrics;
  final Map<String, List<double>> historicalMetrics;
  final List<Map<String, dynamic>> localSleepHistory;
  HealthSyncResult(this.sleepScore, this.recoveryScore, this.dailyMetrics, this.historicalMetrics, this.localSleepHistory);
}

class HealthSyncService {
  final Health _health = Health();
  final AthleteMetricsEngine _metricsEngine = AthleteMetricsEngine();

  Future<HealthSyncResult> fetchAndCalculateScores(bool isLutealPhase, List<BodyMetricLog> bodyLogs, [DateTime? targetDate]) async {
    // Definizione dei tipi di dati da richiedere per le misurazioni orarie/giornaliere (es. sonno)
    final types = [
      if (Platform.isIOS) HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_DEEP,
    ];

    // Verifica permessi
    bool? hasPermissions = await _health.hasPermissions(types);
    if (hasPermissions == null || !hasPermissions) {
      bool authorized = await _health.requestAuthorization(types);
      if (!authorized) {
        throw Exception('Permessi per l\'app Salute (Health Connect / Apple Health) negati o non configurati. Verifica di aver fornito l\'accesso.');
      }
    }

    final target = targetDate ?? DateTime.now();
    final now = DateTime(target.year, target.month, target.day, 23, 59, 59);
    final monthAgo = now.subtract(const Duration(days: 30));
    
    final targetStart = DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 6));
    final targetEnd = now;

    // Estrazione dati storici SONNO
    List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
      startTime: monthAgo,
      endTime: now,
      types: types,
    );

    // Dati odierni SONNO
    List<HealthDataPoint> todayData = await _health.getHealthDataFromTypes(
      startTime: targetStart,
      endTime: targetEnd,
      types: types,
    );

    // Helper per estrarre history e today dai bodyLogs
    List<double> _extractHistory(String type) {
      var filtered = bodyLogs.where((l) => l.type == type && DateTime.parse(l.date).isAfter(monthAgo) && DateTime.parse(l.date).isBefore(now.add(const Duration(days: 1)))).toList();
      filtered.sort((a, b) => a.date.compareTo(b.date));
      return filtered.map((e) => e.value).toList();
    }

    double? _getTodayVal(String type) {
      String dateStr = target.toIso8601String().split('T')[0];
      var point = bodyLogs.where((l) => l.type == type && l.date == dateStr).lastOrNull;
      if (point != null) return point.value;
      
      // Se non esiste un record con la data esatta di oggi, usiamo l'ultimo valore disponibile
      // Questo allinea la Readiness con Analytics, coprendo i casi in cui Zepp registra i dati del sonno nel giorno precedente.
      var latestLogs = bodyLogs.where((l) => l.type == type).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return latestLogs.lastOrNull?.value;
    }

    // --- AGGREGAZIONE DATI STORICI ---
    List<double> rhrHistory = _extractHistory('resting_hr');
    List<double> tempHistory = _extractHistory('temp');
    List<double> hrvHistory = _extractHistory('hrv');
    List<double> respHistory = _extractHistory('resp');
    List<double> spo2History = _extractHistory('spo2');

    // --- AGGREGAZIONE DATI ODIERNI ---
    double? rhrToday = _getTodayVal('resting_hr');
    double? tempToday = _getTodayVal('temp');
    double? hrvToday = _getTodayVal('hrv');
    double? respToday = _getTodayVal('resp');
    double? spo2Today = _getTodayVal('spo2');

    // --- CALCOLO SONNO ODIERNO ---
    double totalSleepTime = _sumSleepMinutes(todayData, [HealthDataType.SLEEP_ASLEEP]);
    if (totalSleepTime == 0) {
      totalSleepTime = _sumSleepMinutes(todayData, [HealthDataType.SLEEP_LIGHT, HealthDataType.SLEEP_DEEP, HealthDataType.SLEEP_REM]);
      if (totalSleepTime == 0) totalSleepTime = 420; // fallback 7h
    }
    
    double deepSleepTime = _sumSleepMinutes(todayData, [HealthDataType.SLEEP_DEEP]);
    if (deepSleepTime == 0) deepSleepTime = 90; // fallback

    double remSleepTime = _sumSleepMinutes(todayData, [HealthDataType.SLEEP_REM]);
    if (remSleepTime == 0) remSleepTime = 90; // fallback

    double timeInBed = _sumSleepMinutes(todayData, [HealthDataType.SLEEP_IN_BED]);
    if (timeInBed == 0) timeInBed = 480; // fallback 8h

    DateTime sleepOnset = DateTime.now().subtract(const Duration(hours: 8));
    var sleepPoints = todayData.where((d) => [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED, HealthDataType.SLEEP_LIGHT, HealthDataType.SLEEP_DEEP, HealthDataType.SLEEP_REM].contains(d.type)).toList();
    if (sleepPoints.isNotEmpty) {
      sleepPoints.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
      sleepOnset = sleepPoints.first.dateFrom;
    }

    DateTime avgSleepOnset = _calculateAverageSleepOnset(healthData, target);

    double diffMinutes = sleepOnset.difference(avgSleepOnset).inSeconds.abs() / 60.0;
    double circadianScore = 100.0;
    if (diffMinutes > 30.0) {
      double extraMinutes = diffMinutes - 30.0;
      double penalties = (extraMinutes ~/ 30) * 15.0;
      circadianScore = 100.0 - penalties;
      if (circadianScore < 0.0) circadianScore = 0.0;
    }

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

    double? recoveryScore = _metricsEngine.calculateRecoveryScore(
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
      if (rhrToday != null) 'rhr': rhrToday,
      if (tempToday != null) 'temp': tempToday,
      if (hrvToday != null) 'hrv': hrvToday,
      if (respToday != null) 'resp': respToday,
      if (spo2Today != null) 'spo2': spo2Today,
      'totalSleep': totalSleepTime,
      'deepSleep': deepSleepTime,
      'remSleep': remSleepTime,
      'sleepRegularity': circadianScore,
    };

    Map<String, List<double>> historicalMetrics = {
      'rhr': rhrHistory,
      'temp': tempHistory,
      'hrv': hrvHistory,
      'resp': respHistory,
      'spo2': spo2History,
    };

    List<Map<String, dynamic>> localSleepHistory = _extractLocalSleepHistory(healthData, target);

    return HealthSyncResult(sleepScore, recoveryScore, dailyMetrics, historicalMetrics, localSleepHistory);
  }

  // --- Helper Functions per estrarre i dati grezzi ---

  List<double> _extractDailyAverages(List<HealthDataPoint> data, HealthDataType type, {int? startHour, int? endHour}) {
    var filtered = data.where((d) {
      if (d.type != type) return false;
      if (startHour != null && endHour != null) {
        final hour = d.dateFrom.hour;
        if (hour < startHour || hour > endHour) return false;
      }
      return true;
    }).toList();
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

  double _getTodayAverage(List<HealthDataPoint> data, HealthDataType type, double fallback, {int? startHour, int? endHour, DateTime? targetDate}) {
    var filtered = data.where((d) {
      if (d.type != type) return false;
      if (startHour != null && endHour != null) {
        final hour = d.dateFrom.hour;
        if (hour < startHour || hour > endHour) return false;
      }
      // Il filtro targetDate è stato rimosso per consentire l'inclusione dei dati 
      // della notte (prima di mezzanotte) catturati nel range originario.
      return true;
    }).toList();
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

  DateTime _calculateAverageSleepOnset(List<HealthDataPoint> data, DateTime target) {
    var sleepTypes = [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED, HealthDataType.SLEEP_LIGHT, HealthDataType.SLEEP_DEEP, HealthDataType.SLEEP_REM];
    var sleepData = data.where((d) => sleepTypes.contains(d.type)).toList();
    
    if (sleepData.isEmpty) {
      return target.subtract(const Duration(hours: 8, minutes: 15));
    }

    int totalMinutesFromMidnight = 0;
    int count = 0;

    for (int i = 1; i <= 7; i++) {
      DateTime day = target.subtract(Duration(days: i));
      DateTime start = DateTime(day.year, day.month, day.day).subtract(const Duration(hours: 6));
      DateTime end = DateTime(day.year, day.month, day.day, 23, 59, 59);

      var dayPoints = sleepData.where((d) => d.dateFrom.isAfter(start) && d.dateFrom.isBefore(end)).toList();
      if (dayPoints.isNotEmpty) {
        dayPoints.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
        DateTime onset = dayPoints.first.dateFrom;
        
        // Normalize time: e.g. 23:00 -> 1380, 01:00 -> 1500
        int minutes = onset.hour * 60 + onset.minute;
        if (onset.hour < 12) {
          minutes += 24 * 60;
        }
        totalMinutesFromMidnight += minutes;
        count++;
      }
    }

    if (count == 0) {
      return target.subtract(const Duration(hours: 8, minutes: 15));
    }

    int avgMinutes = totalMinutesFromMidnight ~/ count;
    int avgHour = (avgMinutes ~/ 60) % 24;
    int avgMinute = avgMinutes % 60;
    
    DateTime baseDate = target;
    if (avgHour >= 12) {
       baseDate = target.subtract(const Duration(days: 1));
    }
    return DateTime(baseDate.year, baseDate.month, baseDate.day, avgHour, avgMinute);
  }

  List<Map<String, dynamic>> _extractLocalSleepHistory(List<HealthDataPoint> data, DateTime target) {
    var sleepTypes = [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED, HealthDataType.SLEEP_LIGHT, HealthDataType.SLEEP_DEEP, HealthDataType.SLEEP_REM];
    var sleepData = data.where((d) => sleepTypes.contains(d.type)).toList();
    
    List<Map<String, dynamic>> history = [];

    for (int i = 0; i < 30; i++) {
      DateTime day = target.subtract(Duration(days: i));
      DateTime start = DateTime(day.year, day.month, day.day).subtract(const Duration(hours: 6));
      DateTime end = DateTime(day.year, day.month, day.day, 23, 59, 59);

      var dayPoints = sleepData.where((d) => d.dateFrom.isAfter(start) && d.dateFrom.isBefore(end)).toList();
      if (dayPoints.isNotEmpty) {
        dayPoints.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
        
        DateTime onset = dayPoints.first.dateFrom;
        
        // Find latest wake time
        var sortedByEnd = List<HealthDataPoint>.from(dayPoints);
        sortedByEnd.sort((a, b) => b.dateTo.compareTo(a.dateTo));
        DateTime wakeTime = sortedByEnd.first.dateTo;

        double totalSleepTime = _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_ASLEEP]);
        if (totalSleepTime == 0) {
          totalSleepTime = _sumSleepMinutes(dayPoints, [HealthDataType.SLEEP_LIGHT, HealthDataType.SLEEP_DEEP, HealthDataType.SLEEP_REM]);
        }

        history.add({
          'date': day.toIso8601String().split('T')[0],
          'bedTime': onset.toIso8601String(),
          'wakeTime': wakeTime.toIso8601String(),
          'totalSleepMinutes': totalSleepTime,
        });
      }
    }
    
    return history;
  }
}


