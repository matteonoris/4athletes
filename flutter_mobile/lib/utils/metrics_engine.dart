import 'dart:math' as math;

class CalibrationPhaseException implements Exception {
  final String message;
  CalibrationPhaseException(this.message);

  @override
  String toString() => "CalibrationPhaseException: $message";
}

class AthleteMetricsEngine {
  final double kSigmoid;

  AthleteMetricsEngine({this.kSigmoid = 1.5});

  double calculateSleepScore({
    required double totalSleepTime,
    required double targetSleepTime,
    required double deepSleepTime,
    required double remSleepTime,
    required double timeInBed,
    required DateTime sleepOnsetTime,
    required DateTime avgSleepOnsetTime,
  }) {
    // 1. Durata (40%)
    double durationScore = (totalSleepTime / targetSleepTime) * 100.0;
    durationScore = math.min(durationScore, 100.0);

    // 2. Architettura (25%)
    double archRatio = (deepSleepTime + remSleepTime) / totalSleepTime;
    double archScore;
    if (archRatio >= 0.40) {
      archScore = 100.0;
    } else {
      archScore = (archRatio / 0.40) * 100.0;
    }

    // 3. Regolarità Circadiana (20%)
    double diffMinutes = sleepOnsetTime.difference(avgSleepOnsetTime).inSeconds.abs() / 60.0;
    double circadianScore;
    if (diffMinutes <= 30.0) {
      circadianScore = 100.0;
    } else {
      double extraMinutes = diffMinutes - 30.0;
      double penalties = (extraMinutes ~/ 30) * 15.0; // Divisione intera
      circadianScore = math.max(0.0, 100.0 - penalties);
    }

    // 4. Efficienza (15%)
    double efficiencyScore = (totalSleepTime / timeInBed) * 100.0;
    efficiencyScore = math.min(efficiencyScore, 100.0);

    // Somma pesata finale
    return (durationScore * 0.40) +
           (archScore * 0.25) +
           (circadianScore * 0.20) +
           (efficiencyScore * 0.15);
  }

  _Stats _getStats(List<double> data, double minStd) {
    if (data.isEmpty) return _Stats(0.0, minStd);
    
    double mean = data.reduce((a, b) => a + b) / data.length;
    double variance = data.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / data.length;
    double std = math.sqrt(variance);
    
    if (std == 0.0) {
      std = minStd;
    }
    return _Stats(mean, std);
  }

  double? calculateRecoveryScore({
    required bool isLutealPhase,
    required double? rhrToday,
    required List<double> rhrHistory,
    required double? tempToday,
    required List<double> tempHistory,
    required double? hrvToday,
    required List<double> hrvHistory,
    required double sleepScore,
    required double? respToday,
    required List<double> respHistory,
    required double? spo2Today,
    required List<double> spo2History,
  }) {
    // Controllo Cold Start (richiediamo storia solo per HR e HRV)
    int minHistory = math.min(rhrHistory.length, hrvHistory.length);

    if (minHistory < 4) {
      return null;
    }

    // Correzioni ormonali (Ciclo Mestruale)
    if (isLutealPhase) {
      if (rhrToday != null) rhrToday -= 2.0;
      if (tempToday != null) tempToday -= 0.4;
      if (hrvToday != null) hrvToday *= 1.10;
    }

    // Calcolo Statistiche Storiche (Media, DevStd)
    _Stats rhrStats = _getStats(rhrHistory, 0.1);
    _Stats tempStats = tempHistory.isNotEmpty ? _getStats(tempHistory, 0.1) : _Stats(36.5, 0.1);
    _Stats respStats = respHistory.isNotEmpty ? _getStats(respHistory, 0.1) : _Stats(14.0, 0.1);
    _Stats spo2Stats = spo2History.isNotEmpty ? _getStats(spo2History, 0.1) : _Stats(98.0, 0.1);

    // HRV richiede Trasformazione Logaritmica
    double lnHrvToday = hrvToday != null ? math.log(hrvToday > 0 ? hrvToday : 1.0) : 0.0;
    List<double> lnHrvHistory = hrvHistory.map((x) => math.log(x > 0 ? x : 1.0)).toList();
    _Stats lnHrvStats = _getStats(lnHrvHistory, 1.0);

    // --- CALCOLO Z-SCORE CON DIREZIONALITÀ ---
    
    // Z-scores
    double zHrv = hrvToday != null ? (lnHrvToday - lnHrvStats.mean) / lnHrvStats.std : 0.0;
    double zRhr = rhrToday != null ? -((rhrToday - rhrStats.mean) / rhrStats.std) : 0.0;
    
    double zTempRaw = tempToday != null ? (tempToday - tempStats.mean) / tempStats.std : 0.0;
    double zTemp = (tempHistory.isNotEmpty && tempToday != null && zTempRaw > 0) ? -zTempRaw : 0.0;
    
    double zSleep = (sleepScore / 100.0 * 6.0) - 3.0;
    
    double zResp = (respHistory.isNotEmpty && respToday != null) ? -((respToday - respStats.mean) / respStats.std) : 0.0;
    
    double zSpo2Raw = spo2Today != null ? (spo2Today - spo2Stats.mean) / spo2Stats.std : 0.0;
    double zSpo2 = (spo2History.isNotEmpty && spo2Today != null && zSpo2Raw < 0) ? zSpo2Raw : 0.0;
    
    // --- Ponderazione Dinamica (Dynamic Rebalancing) ---
    double weightHrv = hrvToday != null ? 0.35 : 0.0;
    double weightRhr = rhrToday != null ? 0.20 : 0.0;
    double weightSleep = 0.15;
    double weightTemp = (tempHistory.isNotEmpty && tempToday != null) ? 0.15 : 0.0;
    double weightResp = (respHistory.isNotEmpty && respToday != null) ? 0.10 : 0.0;
    double weightSpo2 = (spo2History.isNotEmpty && spo2Today != null) ? 0.05 : 0.0;

    double totalWeight = weightHrv + weightRhr + weightSleep + weightTemp + weightResp + weightSpo2;
    if (totalWeight <= 0.0) return null;
    
    // Se non ci sono dati, totalWeight potrebbe essere inferiore a 1.0. 
    // Spalmiamo il peso proporzionalmente in modo che la somma sia 1.0
    double zTotale = ((zHrv * weightHrv) +
        (zRhr * weightRhr) +
        (zSleep * weightSleep) +
        (zTemp * weightTemp) +
        (zResp * weightResp) +
        (zSpo2 * weightSpo2)) / totalWeight;
        
    // Sigmoide
    double recoveryScore = 100.0 / (1.0 + math.exp(-kSigmoid * zTotale));
    return recoveryScore;
  }
}

class _Stats {
  final double mean;
  final double std;
  _Stats(this.mean, this.std);
}
