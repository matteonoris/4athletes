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

  double calculateRecoveryScore({
    required bool isLutealPhase,
    required double rhrToday,
    required List<double> rhrHistory,
    required double tempToday,
    required List<double> tempHistory,
    required double hrvToday,
    required List<double> hrvHistory,
    required double sleepScore,
    required double respToday,
    required List<double> respHistory,
    required double spo2Today,
    required List<double> spo2History,
  }) {
    // Controllo Cold Start
    int minHistory = [
      rhrHistory.length,
      tempHistory.length,
      hrvHistory.length,
      respHistory.length,
      spo2History.length
    ].reduce(math.min);

    if (minHistory < 4) {
      throw CalibrationPhaseException(
          'CALIBRATION_PHASE: Dati storici insufficienti ($minHistory giorni su 4 minimi).');
    }

    // Correzioni ormonali (Ciclo Mestruale)
    if (isLutealPhase) {
      rhrToday -= 2.0;
      tempToday -= 0.4;
      hrvToday *= 1.10;
    }

    // Calcolo Statistiche Storiche (Media, DevStd)
    _Stats rhrStats = _getStats(rhrHistory, 0.1);
    _Stats tempStats = _getStats(tempHistory, 0.1);
    _Stats respStats = _getStats(respHistory, 0.1);
    _Stats spo2Stats = _getStats(spo2History, 0.1);

    // HRV richiede Trasformazione Logaritmica
    double lnHrvToday = math.log(hrvToday);
    List<double> lnHrvHistory = hrvHistory.map((x) => math.log(x)).toList();
    _Stats lnHrvStats = _getStats(lnHrvHistory, 1.0);

    // --- CALCOLO Z-SCORE CON DIREZIONALITÀ ---
    
    // 1. HRV (35%) - Positiva
    double zHrv = (lnHrvToday - lnHrvStats.mean) / lnHrvStats.std;
    
    // 2. RHR (20%) - Inversa
    double zRhr = -((rhrToday - rhrStats.mean) / rhrStats.std);
    
    // 3. Temperatura (15%) - Inversa SOLO SE POSITIVA
    double zTempRaw = (tempToday - tempStats.mean) / tempStats.std;
    double zTemp = zTempRaw > 0 ? -zTempRaw : 0.0;
    
    // 4. Sleep Score (15%) - Mappatura da (0-100) a (-3, +3)
    double zSleep = (sleepScore / 100.0 * 6.0) - 3.0;
    
    // 5. Freq Respiratoria (10%) - Inversa
    double zResp = -((respToday - respStats.mean) / respStats.std);
    
    // 6. SpO2 (5%) - Positiva solo sui cali
    double zSpo2Raw = (spo2Today - spo2Stats.mean) / spo2Stats.std;
    double zSpo2 = zSpo2Raw < 0 ? zSpo2Raw : 0.0;
    
    // --- Z-TOTALE E TRASFORMAZIONE FINALE ---
    double zTotale = (zHrv * 0.35) +
        (zRhr * 0.20) +
        (zTemp * 0.15) +
        (zSleep * 0.15) +
        (zResp * 0.10) +
        (zSpo2 * 0.05);
        
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
