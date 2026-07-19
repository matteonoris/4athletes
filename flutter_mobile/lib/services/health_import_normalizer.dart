import 'dart:math' as math;

class HealthImportNormalizer {
  static const int minReliableHrSamples = 5;
  static const double minReliableHrCoverageRatio = 0.50;
  static const int maxContinuousHrGapSeconds = 300;
  static const int maxWorkoutEdgeHrGapSeconds = 60;
  static const int heartRateZoneCalculationVersion = 2;

  static HeartRateMetrics calculateHeartRateMetrics({
    required List<HeartRateSample> samples,
    required List<Map<String, int>> zones,
    DateTime? workoutStart,
    DateTime? workoutEnd,
  }) {
    if (samples.isEmpty) return HeartRateMetrics.empty();

    final ordered = [...samples]..sort((a, b) => a.time.compareTo(b.time));
    final zoneSeconds = List<double>.filled(6, 0);
    double weightedTotal = 0;
    int coveredSeconds = 0;

    void addInterval({
      required double zoneBpm,
      required double averageBpm,
      required int seconds,
      int maxGapSeconds = maxContinuousHrGapSeconds,
    }) {
      if (seconds <= 0 || seconds > maxGapSeconds) return;
      weightedTotal += averageBpm * seconds;
      coveredSeconds += seconds;
      zoneSeconds[zoneIndexForBpm(zoneBpm, zones)] += seconds;
    }

    if (workoutStart != null && ordered.first.time.isAfter(workoutStart)) {
      addInterval(
        zoneBpm: ordered.first.bpm,
        averageBpm: ordered.first.bpm,
        seconds: ordered.first.time.difference(workoutStart).inSeconds,
        maxGapSeconds: maxWorkoutEdgeHrGapSeconds,
      );
    }

    for (var i = 0; i < ordered.length - 1; i++) {
      final current = ordered[i];
      final next = ordered[i + 1];
      final gap = next.time.difference(current.time).inSeconds;
      if (gap <= 0 || gap > maxContinuousHrGapSeconds) continue;

      final intervalHr = (current.bpm + next.bpm) / 2;
      weightedTotal += intervalHr * gap;
      coveredSeconds += gap;
      for (final segment in splitHeartRateInterval(
        startBpm: current.bpm,
        endBpm: next.bpm,
        zones: zones,
      )) {
        zoneSeconds[segment.zoneIndex] +=
            gap * (segment.endFraction - segment.startFraction);
      }
    }

    if (workoutEnd != null && workoutEnd.isAfter(ordered.last.time)) {
      addInterval(
        zoneBpm: ordered.last.bpm,
        averageBpm: ordered.last.bpm,
        seconds: workoutEnd.difference(ordered.last.time).inSeconds,
        maxGapSeconds: maxWorkoutEdgeHrGapSeconds,
      );
    }

    final values = ordered.map((sample) => sample.bpm).toList();
    final average = coveredSeconds > 0
        ? (weightedTotal / coveredSeconds).round()
        : (values.reduce((a, b) => a + b) / values.length).round();

    return HeartRateMetrics(
      averageHeartRate: average,
      maxHeartRate: values.reduce(math.max).round(),
      zoneSeconds: zoneSeconds,
      coverageSeconds: coveredSeconds,
      sampleCount: ordered.length,
      samples: ordered,
    );
  }

  static List<HeartRateSample> cleanHeartRateSamples(
    List<HeartRateSample> rawSamples,
  ) {
    // Health Connect already validates heart-rate samples to the platform's
    // legal 1-300 bpm range. Preserve every legal provider sample so brief,
    // real workout peaks are not mistaken for outliers and the chart, maximum,
    // average and zone totals all describe the same source series.
    final samples = rawSamples
        .where((sample) =>
            sample.bpm.isFinite && sample.bpm >= 1 && sample.bpm <= 300)
        .toList();
    samples.sort((a, b) => a.time.compareTo(b.time));
    return samples;
  }

  static List<Map<String, dynamic>> serializeHeartRateSamples(
    List<HeartRateSample> samples,
  ) {
    return samples
        .map((sample) => {
              'time': sample.time.millisecondsSinceEpoch,
              'bpm': sample.bpm,
            })
        .toList();
  }

  static bool isReliableHeartRate(
    HeartRateMetrics metrics,
    int activeDurationSeconds,
  ) {
    if (metrics.sampleCount < minReliableHrSamples) return false;
    if (activeDurationSeconds <= 0) return false;
    return metrics.coverageSeconds / activeDurationSeconds >=
        minReliableHrCoverageRatio;
  }

  static int dominantZoneIndex(List<double> zoneSeconds) {
    if (zoneSeconds.isEmpty) return 0;
    var bestIndex = 0;
    for (var i = 1; i < zoneSeconds.length; i++) {
      if (zoneSeconds[i] > zoneSeconds[bestIndex]) bestIndex = i;
    }
    return bestIndex;
  }

  static int zoneIndexForBpm(double bpm, List<Map<String, int>> zones) {
    if (zones.isEmpty) return 0;
    // The lower bounds are the unambiguous source of truth. Third-party apps
    // commonly export inclusive ranges (for example Z4 156-175, Z5 176+),
    // while older 4athletes defaults stored adjacent half-open ranges. Using
    // the next zone's minimum supports both representations and, importantly,
    // never sends a value that falls in a custom-range gap straight to Z5.
    for (var i = zones.length - 1; i >= 0; i--) {
      final min = zones[i]['min'];
      if (min != null && bpm >= min) return i + 1;
    }
    return 0;
  }

  static List<HeartRateZoneSegment> splitHeartRateInterval({
    required double startBpm,
    required double endBpm,
    required List<Map<String, int>> zones,
  }) {
    if (startBpm == endBpm || zones.isEmpty) {
      return [
        HeartRateZoneSegment(
          startFraction: 0,
          endFraction: 1,
          startBpm: startBpm,
          endBpm: endBpm,
          zoneIndex: zoneIndexForBpm(startBpm, zones),
        ),
      ];
    }

    final cuts = <double>[0, 1];
    final delta = endBpm - startBpm;
    for (final zone in zones) {
      final threshold = zone['min'];
      if (threshold == null) continue;
      final fraction = (threshold - startBpm) / delta;
      if (fraction > 0 && fraction < 1) cuts.add(fraction);
    }
    cuts.sort();

    final uniqueCuts = <double>[];
    for (final cut in cuts) {
      if (uniqueCuts.isEmpty || (cut - uniqueCuts.last).abs() > 0.0000001) {
        uniqueCuts.add(cut);
      }
    }

    final segments = <HeartRateZoneSegment>[];
    for (var i = 0; i < uniqueCuts.length - 1; i++) {
      final from = uniqueCuts[i];
      final to = uniqueCuts[i + 1];
      final midpoint = (from + to) / 2;
      final midpointBpm = startBpm + delta * midpoint;
      segments.add(HeartRateZoneSegment(
        startFraction: from,
        endFraction: to,
        startBpm: startBpm + delta * from,
        endBpm: startBpm + delta * to,
        zoneIndex: zoneIndexForBpm(midpointBpm, zones),
      ));
    }
    return segments;
  }

  static List<int> roundedZoneSeconds(
    List<double> zoneSeconds, {
    int? targetSeconds,
  }) {
    if (zoneSeconds.isEmpty) return const [];
    final target = targetSeconds ??
        zoneSeconds.fold<double>(0, (sum, value) => sum + value).round();
    final rounded = zoneSeconds.map((seconds) => seconds.floor()).toList();
    var remainder = target - rounded.fold<int>(0, (sum, value) => sum + value);
    final order = List<int>.generate(zoneSeconds.length, (index) => index)
      ..sort((a, b) {
        final fractionA = zoneSeconds[a] - zoneSeconds[a].floor();
        final fractionB = zoneSeconds[b] - zoneSeconds[b].floor();
        return fractionB.compareTo(fractionA);
      });

    for (final index in order) {
      if (remainder <= 0) break;
      rounded[index]++;
      remainder--;
    }
    return rounded;
  }

  static List<Map<String, int>> resolveHeartRateZones({
    required String mode,
    required List<Map<String, int>>? customZones,
    required int maxHeartRate,
    int restingHeartRate = 50,
  }) {
    if (mode == 'custom' && _hasValidCustomZoneThresholds(customZones)) {
      return customZones!.map((zone) => Map<String, int>.from(zone)).toList();
    }

    final safeMax = maxHeartRate > restingHeartRate
        ? maxHeartRate
        : math.max(190, restingHeartRate + 1);
    final reserve = safeMax - restingHeartRate;
    final minimums = [
      (reserve * 0.50 + restingHeartRate).round(),
      (reserve * 0.60 + restingHeartRate).round(),
      (reserve * 0.70 + restingHeartRate).round(),
      (reserve * 0.80 + restingHeartRate).round(),
      (reserve * 0.90 + restingHeartRate).round(),
    ];
    return List.generate(5, (index) {
      final max = index < 4 ? minimums[index + 1] - 1 : safeMax;
      return {'min': minimums[index], 'max': max};
    });
  }

  static bool hasSameZoneThresholds(
    dynamic storedZones,
    List<Map<String, int>> expectedZones,
  ) {
    if (storedZones is! List || storedZones.length < expectedZones.length) {
      return false;
    }
    for (var i = 0; i < expectedZones.length; i++) {
      final stored = storedZones[i];
      if (stored is! Map || stored['min'] != expectedZones[i]['min']) {
        return false;
      }
    }
    return true;
  }

  static bool _hasValidCustomZoneThresholds(
    List<Map<String, int>>? zones,
  ) {
    if (zones == null || zones.length != 5) return false;
    int? previousMin;
    for (final zone in zones) {
      final min = zone['min'];
      final max = zone['max'];
      if (min == null || max == null || min >= max) return false;
      if (previousMin != null && min <= previousMin) return false;
      previousMin = min;
    }
    return true;
  }

  static List<int> zoneMinutesFromSeconds({
    required List<double> zoneSeconds,
    required int activeDurationSeconds,
    required int coveredSeconds,
  }) {
    final observedSeconds =
        zoneSeconds.fold<double>(0, (sum, value) => sum + value);
    if (observedSeconds <= 0) return List<int>.filled(zoneSeconds.length, 0);

    final shouldScaleToActiveDuration =
        coveredSeconds >= math.max(120, (activeDurationSeconds * 0.50).round());
    final targetSeconds = shouldScaleToActiveDuration
        ? activeDurationSeconds
        : observedSeconds.round();
    final targetMinutes = math.max(1, (targetSeconds / 60).round());

    final rawMinutes = zoneSeconds
        .map((seconds) => (seconds / observedSeconds) * targetMinutes)
        .toList();
    final rounded = rawMinutes.map((minutes) => minutes.floor()).toList();
    var remainder =
        targetMinutes - rounded.fold<int>(0, (sum, value) => sum + value);

    final order = List<int>.generate(rawMinutes.length, (index) => index)
      ..sort((a, b) {
        final fractionA = rawMinutes[a] - rawMinutes[a].floor();
        final fractionB = rawMinutes[b] - rawMinutes[b].floor();
        return fractionB.compareTo(fractionA);
      });

    for (final index in order) {
      if (remainder <= 0) break;
      rounded[index]++;
      remainder--;
    }

    return rounded;
  }

  static int deriveMovingDurationSeconds({
    required int elapsedSeconds,
    required int distanceCoverageSeconds,
    required int heartRateCoverageSeconds,
    required bool hasDistance,
  }) {
    if (elapsedSeconds <= 0) return 0;

    if (hasDistance &&
        distanceCoverageSeconds >= math.min(60, elapsedSeconds) &&
        distanceCoverageSeconds <= elapsedSeconds) {
      return math.max(1, distanceCoverageSeconds);
    }

    final minimumUsefulHrCoverage =
        math.max(120, (elapsedSeconds * 0.35).round());
    if (heartRateCoverageSeconds >= minimumUsefulHrCoverage &&
        heartRateCoverageSeconds <= elapsedSeconds) {
      return math.max(1, heartRateCoverageSeconds);
    }

    return elapsedSeconds;
  }
}

class HeartRateSample {
  final DateTime time;
  final double bpm;

  const HeartRateSample(this.time, this.bpm);
}

class HeartRateZoneSegment {
  final double startFraction;
  final double endFraction;
  final double startBpm;
  final double endBpm;
  final int zoneIndex;

  const HeartRateZoneSegment({
    required this.startFraction,
    required this.endFraction,
    required this.startBpm,
    required this.endBpm,
    required this.zoneIndex,
  });
}

class HeartRateMetrics {
  final int? averageHeartRate;
  final int? maxHeartRate;
  final List<double> zoneSeconds;
  final int coverageSeconds;
  final int sampleCount;
  final List<HeartRateSample> samples;

  const HeartRateMetrics({
    required this.averageHeartRate,
    required this.maxHeartRate,
    required this.zoneSeconds,
    required this.coverageSeconds,
    required this.sampleCount,
    required this.samples,
  });

  factory HeartRateMetrics.empty() {
    return HeartRateMetrics(
      averageHeartRate: null,
      maxHeartRate: null,
      zoneSeconds: List<double>.filled(6, 0),
      coverageSeconds: 0,
      sampleCount: 0,
      samples: const [],
    );
  }
}
