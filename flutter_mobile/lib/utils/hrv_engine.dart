import 'dart:math' as math;

class HrvEngine {
  /// 1. PIPELINE DI PULIZIA ARTEFATTI (Quotient Filter)
  static List<double> cleanRRIntervals(List<double> rrIntervals) {
    if (rrIntervals.isEmpty) return [];

    List<double> cleaned = [];
    double? previousRR;

    for (int i = 0; i < rrIntervals.length; i++) {
      double currentRR = rrIntervals[i];

      // A. Scarta valori impossibili per atleti a riposo (es. HR > 200 o < 40 se non Elite estremi)
      // 300 ms = 200 bpm | 1500 ms = 40 bpm.
      if (currentRR < 300 || currentRR > 1500) continue;

      // B. Quotient Filter (Variazione > 20% rispetto al battito precedente)
      if (previousRR != null) {
        double variation = (currentRR - previousRR).abs() / previousRR;
        if (variation > 0.20) continue; 
      }

      cleaned.add(currentRR);
      previousRR = currentRR;
    }

    return cleaned;
  }

  /// 2. STANDARDIZZAZIONE METRICA (Calcolo RMSSD)
  static double calculateRMSSD(List<double> cleanRR) {
    if (cleanRR.length < 2) return 0.0;

    double sumOfSquaredDifferences = 0.0;
    for (int i = 1; i < cleanRR.length; i++) {
      double difference = cleanRR[i] - cleanRR[i - 1];
      sumOfSquaredDifferences += (difference * difference);
    }

    double meanSquaredDifference = sumOfSquaredDifferences / (cleanRR.length - 1);
    return math.sqrt(meanSquaredDifference);
  }

  /// 3. AGGREGAZIONE NOTTURNA E GESTIONE BASELINE
  static Map<String, dynamic> processNightlyHrv({
    required List<double> rawRRIntervals,
    required String deviceSource,
    required List<Map<String, dynamic>> historicalData, // I record estratti dal DB
  }) {
    // Pipeline
    final cleanedRR = cleanRRIntervals(rawRRIntervals);
    final nightRmssd = calculateRMSSD(cleanedRR);

    if (nightRmssd == 0.0) {
      return {
        'rmssd': 0.0,
        'device_source': deviceSource,
        'needs_calibration': true,
      };
    }

    // Filtro contesto storico: analizzo solo i dati provenienti DALLO STESSO HARDWARE
    final deviceHistory = historicalData
        .where((h) => h['device_source'] == deviceSource)
        .map((h) => h['rmssd'] as double)
        .toList();

    bool needsCalibration = true;
    double? rolling7d;
    double? rolling30d;
    double? rolling180d;
    double? rolling365d;

    // Se abbiamo almeno 4 giorni di dati per questo specifico device, togliamo il flag di calibrazione
    if (deviceHistory.length >= 4) {
      needsCalibration = false;
      
      // Creiamo la serie temporale includendo l'ultima notte
      final recentData = List<double>.from(deviceHistory)..add(nightRmssd);
      
      // Media Mobile a 7 Giorni (1 Settimana)
      final last7 = recentData.reversed.take(7).toList();
      rolling7d = last7.reduce((a, b) => a + b) / last7.length;

      // Media Mobile a 30 Giorni (1 Mese)
      if (recentData.length >= 30) {
        final last30 = recentData.reversed.take(30).toList();
        rolling30d = last30.reduce((a, b) => a + b) / last30.length;
      }

      // Media Mobile a 180 Giorni (6 Mesi)
      if (recentData.length >= 180) {
        final last180 = recentData.reversed.take(180).toList();
        rolling180d = last180.reduce((a, b) => a + b) / last180.length;
      }
      
      // Media Mobile a 365 Giorni (1 Anno)
      if (recentData.length >= 365) {
        final last365 = recentData.reversed.take(365).toList();
        rolling365d = last365.reduce((a, b) => a + b) / last365.length;
      }
    }

    return {
      'rmssd': nightRmssd,
      'device_source': deviceSource,
      'needs_calibration': needsCalibration,
      'rolling_7d': rolling7d,
      'rolling_30d': rolling30d,
      'rolling_180d': rolling180d,
      'rolling_365d': rolling365d,
    };
  }
}
