import 'dart:math' as math;

class HealthImportNormalizer {
  static const int minReliableHrSamples = 5;
  static const double minReliableHrCoverageRatio = 0.50;
  static const int maxContinuousHrGapSeconds = 300;
  static const int maxWorkoutEdgeHrGapSeconds = 60;

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
      zoneSeconds[zoneIndexForBpm(current.bpm, zones)] += gap;
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
    final byTimestamp = <int, List<double>>{};
    for (final sample in rawSamples) {
      if (sample.bpm < 35 || sample.bpm > 235) continue;
      byTimestamp
          .putIfAbsent(sample.time.millisecondsSinceEpoch, () => <double>[])
          .add(sample.bpm);
    }

    final samples = byTimestamp.entries.map((entry) {
      final values = entry.value;
      final avg = values.reduce((a, b) => a + b) / values.length;
      return HeartRateSample(
        DateTime.fromMillisecondsSinceEpoch(entry.key),
        avg,
      );
    }).toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    if (samples.length < 3) return samples;

    final cleaned = <HeartRateSample>[];
    for (var i = 0; i < samples.length; i++) {
      if (i == 0 || i == samples.length - 1) {
        cleaned.add(samples[i]);
        continue;
      }

      final windowStart = math.max(0, i - 2);
      final windowEnd = math.min(samples.length - 1, i + 2);
      final window = samples
          .sublist(windowStart, windowEnd + 1)
          .map((sample) => sample.bpm)
          .toList()
        ..sort();
      final median = window[window.length ~/ 2];
      final previous = samples[i - 1].bpm;
      final current = samples[i].bpm;
      final next = samples[i + 1].bpm;
      final neighborsStable = (previous - next).abs() <= 25;
      final isolatedSpike = neighborsStable &&
          (current - median).abs() > 45 &&
          (current - previous).abs() > 45 &&
          (current - next).abs() > 45;
      if (!isolatedSpike) cleaned.add(samples[i]);
    }

    return cleaned;
  }

  static List<Map<String, dynamic>> serializeHeartRateSamples(
    List<HeartRateSample> samples,
  ) {
    return samples
        .map((sample) => {
              'time': sample.time.millisecondsSinceEpoch,
              'bpm': sample.bpm.round(),
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
    if (bpm < zones.first['min']!) return 0;

    for (var i = zones.length - 1; i >= 0; i--) {
      final min = zones[i]['min']!;
      final max = zones[i]['max']!;
      final isLast = i == zones.length - 1;
      if (bpm >= min && (isLast || bpm < max)) return i + 1;
    }

    return zones.length;
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
