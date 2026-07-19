import 'dart:math' as math;

class HrvEngine {
  static const double minRrIntervalMs = 300;
  static const double maxRrIntervalMs = 2000;
  static const double maxSuccessiveVariation = 0.20;
  static const int minValidIntervals = 30;
  static const int minAdjacentPairs = 20;
  static const double maxArtifactFraction = 0.10;
  static const int minCalibrationNights = 7;

  /// Returns physiologically plausible intervals that pass the quotient
  /// filter. This compatibility helper intentionally returns values only;
  /// [processNightlyHrv] retains source indexes as well, so RMSSD never joins
  /// intervals that were not adjacent in the original heartbeat series.
  static List<double> cleanRRIntervals(List<double> rrIntervals) {
    return _analyzeRRIntervals(rrIntervals).cleanedIntervals;
  }

  /// Calculates RMSSD for a known contiguous series of clean NN intervals.
  static double calculateRMSSD(List<double> cleanRR) {
    if (cleanRR.length < 2) return 0;
    var sumOfSquaredDifferences = 0.0;
    var pairCount = 0;
    for (var i = 1; i < cleanRR.length; i++) {
      final previous = cleanRR[i - 1];
      final current = cleanRR[i];
      if (!previous.isFinite || !current.isFinite) continue;
      final difference = current - previous;
      sumOfSquaredDifferences += difference * difference;
      pairCount++;
    }
    if (pairCount == 0) return 0;
    return math.sqrt(sumOfSquaredDifferences / pairCount);
  }

  static Map<String, dynamic> processNightlyHrv({
    required List<double> rawRRIntervals,
    required String deviceSource,
    required List<Map<String, dynamic>> historicalData,
    String? measurementDate,
  }) {
    final analysis = _analyzeRRIntervals(rawRRIntervals);
    final qualityWarnings = <String>[];
    if (analysis.rawCount < minValidIntervals) {
      qualityWarnings.add('hrv_insufficient_raw_intervals');
    }
    if (analysis.validCount < minValidIntervals) {
      qualityWarnings.add('hrv_insufficient_valid_intervals');
    }
    if (analysis.adjacentPairCount < minAdjacentPairs) {
      qualityWarnings.add('hrv_insufficient_adjacent_pairs');
    }
    if (analysis.artifactFraction > maxArtifactFraction) {
      qualityWarnings.add('hrv_excessive_artifact_fraction');
    }

    final nightRmssd = analysis.rmssd;
    if (!nightRmssd.isFinite || nightRmssd <= 0) {
      qualityWarnings.add('hrv_non_positive_rmssd');
    }
    final qualityPassed = qualityWarnings.isEmpty;
    final qualityDetails = <String, dynamic>{
      'quality_passed': qualityPassed,
      'quality_warnings': qualityWarnings,
      'raw_interval_count': analysis.rawCount,
      'valid_interval_count': analysis.validCount,
      'adjacent_pair_count': analysis.adjacentPairCount,
      'artifact_count': analysis.artifactCount,
      'artifact_fraction': analysis.artifactFraction,
    };

    if (!qualityPassed) {
      return {
        'rmssd': 0.0,
        'device_source': deviceSource,
        'measurement_date': measurementDate,
        'needs_calibration': true,
        'rolling_7d': null,
        'rolling_30d': null,
        'rolling_180d': null,
        'rolling_365d': null,
        ...qualityDetails,
      };
    }

    final deviceHistoryRows = historicalData.where((row) {
      final value = row['rmssd'];
      return row['device_source'] == deviceSource &&
          (measurementDate == null ||
              row['date']?.toString() != measurementDate) &&
          value is num &&
          value.isFinite &&
          value > 0;
    }).toList(growable: false)
      ..sort(
        (a, b) => (a['date']?.toString() ?? '')
            .compareTo(b['date']?.toString() ?? ''),
      );
    final recentData = deviceHistoryRows
        .map((row) => (row['rmssd'] as num).toDouble())
        .toList(growable: true)
      ..add(nightRmssd);

    return {
      'rmssd': nightRmssd,
      'device_source': deviceSource,
      'measurement_date': measurementDate,
      'needs_calibration': recentData.length < minCalibrationNights,
      'rolling_7d': _geometricRollingMean(recentData, 7),
      'rolling_30d': _geometricRollingMean(recentData, 30),
      'rolling_180d': _geometricRollingMean(recentData, 180),
      'rolling_365d': _geometricRollingMean(recentData, 365),
      'rolling_method': 'geometric_mean',
      ...qualityDetails,
    };
  }

  static _RrAnalysis _analyzeRRIntervals(List<double> rrIntervals) {
    final cleaned = <double>[];
    final acceptedIndexes = <int>[];
    double? previousAccepted;
    int? previousAcceptedIndex;
    var artifactCount = 0;
    var adjacentPairCount = 0;
    var sumSquaredAdjacentDifferences = 0.0;

    for (var index = 0; index < rrIntervals.length; index++) {
      final current = rrIntervals[index];
      var accepted = current.isFinite &&
          current >= minRrIntervalMs &&
          current <= maxRrIntervalMs;
      if (accepted && previousAccepted != null) {
        final variation = (current - previousAccepted).abs() / previousAccepted;
        accepted = variation <= maxSuccessiveVariation;
      }

      if (!accepted) {
        artifactCount++;
        continue;
      }

      cleaned.add(current);
      acceptedIndexes.add(index);
      if (previousAccepted != null && previousAcceptedIndex == index - 1) {
        final difference = current - previousAccepted;
        sumSquaredAdjacentDifferences += difference * difference;
        adjacentPairCount++;
      }
      previousAccepted = current;
      previousAcceptedIndex = index;
    }

    final rmssd = adjacentPairCount == 0
        ? 0.0
        : math.sqrt(sumSquaredAdjacentDifferences / adjacentPairCount);
    return _RrAnalysis(
      cleanedIntervals: cleaned,
      acceptedIndexes: acceptedIndexes,
      rawCount: rrIntervals.length,
      artifactCount: artifactCount,
      adjacentPairCount: adjacentPairCount,
      rmssd: rmssd,
    );
  }

  static double? _geometricRollingMean(List<double> values, int window) {
    if (window <= 0 || values.length < window) return null;
    final recent = values.sublist(values.length - window);
    if (recent.any((value) => !value.isFinite || value <= 0)) return null;
    final meanLog =
        recent.map(math.log).reduce((a, b) => a + b) / recent.length;
    return math.exp(meanLog);
  }
}

class _RrAnalysis {
  final List<double> cleanedIntervals;
  final List<int> acceptedIndexes;
  final int rawCount;
  final int artifactCount;
  final int adjacentPairCount;
  final double rmssd;

  const _RrAnalysis({
    required this.cleanedIntervals,
    required this.acceptedIndexes,
    required this.rawCount,
    required this.artifactCount,
    required this.adjacentPairCount,
    required this.rmssd,
  });

  int get validCount => cleanedIntervals.length;

  double get artifactFraction => rawCount == 0 ? 1 : artifactCount / rawCount;
}
