import 'dart:math' as math;

import 'algorithm_config.dart';
import 'math_helpers.dart';
import 'scoring_types.dart';
import 'strain_sport_mapping.dart';

class StrainPercentileAnchors {
  final double p50;
  final double p90;
  final double p95;
  final int validDays;
  final double baselineConfidence;

  const StrainPercentileAnchors({
    required this.p50,
    required this.p90,
    required this.p95,
    required this.validDays,
    required this.baselineConfidence,
  });
}

class _ComponentLoads {
  final double? cardio;
  final double? rpe;
  final double? externalMechanical;

  const _ComponentLoads({
    this.cardio,
    this.rpe,
    this.externalMechanical,
  });
}

class _ComponentScores {
  final double? cardio;
  final double? rpe;
  final double? externalMechanical;
  final double baselineConfidence;
  final int baselineValidDays;
  final int cardioBaselineValidDays;
  final int rpeBaselineValidDays;
  final int externalMechanicalBaselineValidDays;

  const _ComponentScores({
    this.cardio,
    this.rpe,
    this.externalMechanical,
    required this.baselineConfidence,
    required this.baselineValidDays,
    required this.cardioBaselineValidDays,
    required this.rpeBaselineValidDays,
    required this.externalMechanicalBaselineValidDays,
  });
}

SessionStrainResult calculateSessionStrain(
  WorkoutSessionInput session,
  AthleteStrainProfile profile, {
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final strainConfig = config.strainScore;
  final warnings = <String>[];
  final category = mapSportTypeToStrainCategory(session.sportType);
  if (category == StrainSportCategory.unknown) {
    warnings.add('unknown_sport_type');
  }

  final duration = math.max(config.confidence.min, session.durationMinutes);
  if (duration <= config.confidence.min) {
    return SessionStrainResult(
      sessionId: session.id,
      sportCategory: category,
      durationMinutes: duration,
      heartRateCoverage: config.confidence.min,
      confidence: config.confidence.min,
      warnings: const ['invalid_session_duration'],
    );
  }

  final maxHr = _maxHeartRate(profile, strainConfig);
  final restingHr = _restingHeartRate(profile, maxHr, strainConfig);
  final profileMaxHr = profile.maxHeartRateBpm;
  if (isFiniteNumber(profileMaxHr) &&
      isFiniteNumber(session.maxHeartRateBpm) &&
      session.maxHeartRateBpm! > profileMaxHr! + 3) {
    warnings.add('profile_max_heart_rate_outdated');
  }
  final cardio = _calculateCardioLoad(
    session,
    duration,
    maxHr,
    restingHr,
    config,
    warnings,
  );
  final rpe = _calculateRpeLoad(session, duration, warnings);
  final external = _calculateExternalMechanicalLoad(
    session,
    category,
    duration,
    config,
    warnings,
  );

  final heartRateQuality =
      cardio.heartRateCoverage >= strainConfig.minHrCoverageForFullConfidence
          ? config.confidence.max
          : cardio.heartRateCoverage >= strainConfig.minHrCoverageToUseSamples
              ? strainConfig.partialHrConfidenceMultiplier
              : strainConfig.lowHrQualityScore;
  final rpeAvailability =
      isFiniteNumber(rpe.value) ? config.confidence.max : config.confidence.min;
  final sportKnown = category == StrainSportCategory.unknown
      ? strainConfig.missingComponentConfidenceMultiplier
      : config.confidence.max;
  final externalProxy = external.usedEstimatedIntensity
      ? strainConfig.missingComponentConfidenceMultiplier
      : config.confidence.max;

  final confidence = clampDouble(
    0.30 * heartRateQuality +
        0.25 * rpeAvailability +
        0.20 * sportKnown +
        0.15 * config.confidence.max +
        0.10 * externalProxy,
    config.confidence.min,
    config.confidence.max,
  );

  return SessionStrainResult(
    sessionId: session.id,
    sportCategory: category,
    durationMinutes: duration,
    cardioLoadAU: cardio.value,
    rpeLoadAU: rpe.value,
    externalMechanicalLoadAU: external.value,
    heartRateCoverage: cardio.heartRateCoverage,
    cardioMethod: cardio.method,
    rpeMethod: rpe.method,
    externalMechanicalMethod: external.method,
    confidence: confidence,
    warnings: uniqueWarnings(warnings),
  );
}

DailyStrainResult calculateDailyStrain(
  String date,
  List<WorkoutSessionInput> sessions,
  AthleteStrainProfile profile,
  List<HistoricalDailyStrainLoad> historicalLoads, {
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final daySessions =
      sessions.where((session) => session.date == date).toList();
  if (daySessions.isEmpty) {
    return DailyStrainResult(
      score: config.score.min,
      status: StrainScoreStatus.noTraining,
      confidence: config.strainScore.noTrainingConfidence,
      components: const {
        'totalDurationMinutes': 0.0,
        'sessionCount': 0,
        'sportMix': <String, int>{},
        'rawLoads': <String, double>{},
        'methods': <String, String>{},
        'coverage': <String, double>{},
      },
      warnings: const [],
    );
  }

  final sessionResults = daySessions
      .map((session) => calculateSessionStrain(
            session,
            profile,
            config: config,
          ))
      .toList(growable: false);
  final warnings = <String>[
    for (final result in sessionResults) ...result.warnings,
  ];

  final loads = _aggregateLoads(sessionResults);
  final scores = _normalizeDailyLoads(loads, historicalLoads, config, warnings);
  final totalDuration = daySessions.fold<double>(
    config.confidence.min,
    (sum, session) =>
        sum + math.max(config.confidence.min, session.durationMinutes),
  );
  final sportMix = <String, int>{};
  for (final result in sessionResults) {
    sportMix.update(result.sportCategory.code, (count) => count + 1,
        ifAbsent: () => 1);
  }

  final weightedScore = _combineSessionWeightedScores(
    sessionResults,
    scores,
    config,
    warnings,
  );
  if (weightedScore == null) {
    return DailyStrainResult(
      score: null,
      status: StrainScoreStatus.insufficientData,
      confidence: config.confidence.min,
      components: _dailyComponents(
        scores: scores,
        loads: loads,
        totalDuration: totalDuration,
        sessionResults: sessionResults,
        sportMix: sportMix,
      ),
      warnings: uniqueWarnings(warnings),
    );
  }

  final missingComponentCount = [
    scores.cardio,
    scores.rpe,
    scores.externalMechanical,
  ].where((value) => !isFiniteNumber(value)).length;
  final avgSessionConfidence = sessionResults.fold<double>(
        config.confidence.min,
        (sum, result) => sum + result.confidence,
      ) /
      sessionResults.length;
  final confidence = clampDouble(
        0.30 * _averageHeartRateCoverageQuality(sessionResults, config) +
            0.25 * _rpeAvailability(daySessions, config) +
            0.20 * _sportKnownConfidence(sessionResults, config) +
            0.15 * scores.baselineConfidence +
            0.10 * avgSessionConfidence,
        config.confidence.min,
        config.confidence.max,
      ) *
      math.pow(
        config.strainScore.missingComponentConfidenceMultiplier,
        missingComponentCount,
      );

  final status =
      scores.baselineValidDays < config.strainScore.minPersonalBaselineDays
          ? StrainScoreStatus.calibrationPhase
          : confidence < 0.80 || warnings.isNotEmpty
              ? StrainScoreStatus.partialData
              : StrainScoreStatus.ok;

  return DailyStrainResult(
    score: clampDouble(weightedScore, config.score.min, config.score.max),
    status: status,
    confidence:
        clampDouble(confidence, config.confidence.min, config.confidence.max),
    components: _dailyComponents(
      scores: scores,
      loads: loads,
      totalDuration: totalDuration,
      sessionResults: sessionResults,
      sportMix: sportMix,
    ),
    warnings: uniqueWarnings(warnings),
  );
}

HistoricalDailyStrainLoad calculateHistoricalDailyStrainLoad(
  String date,
  List<WorkoutSessionInput> sessions,
  AthleteStrainProfile profile, {
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final sessionResults = sessions
      .where((session) => session.date == date)
      .map((session) => calculateSessionStrain(
            session,
            profile,
            config: config,
          ))
      .toList(growable: false);
  final loads = _aggregateLoads(sessionResults);
  final totalDuration = sessions
      .where((session) => session.date == date)
      .fold<double>(0, (sum, session) => sum + session.durationMinutes);
  return HistoricalDailyStrainLoad(
    date: date,
    cardioLoadAU: loads.cardio,
    rpeLoadAU: loads.rpe,
    externalMechanicalLoadAU: loads.externalMechanical,
    totalDurationMinutes: totalDuration,
    sessionCount: sessionResults.length,
  );
}

StrainPercentileAnchors calculateStrainAnchors(
  List<num?> values,
  StrainComponentAnchors absoluteAnchors, {
  required int validDays,
  required AlgorithmConfig config,
}) {
  final strainConfig = config.strainScore;
  var personalP50 = percentile(values, 0.50);
  var personalP90 = percentile(values, 0.90);
  var personalP95 = percentile(values, 0.95);

  final personalWeight = validDays < strainConfig.minPersonalBaselineDays
      ? config.confidence.min
      : clampDouble(
          validDays / strainConfig.fullPersonalBaselineDays,
          config.confidence.min,
          config.confidence.max,
        );
  final anchorWeight = config.confidence.max - personalWeight;

  final p50 = (personalP50 ?? absoluteAnchors.p50) * personalWeight +
      absoluteAnchors.p50 * anchorWeight;
  var p90 = (personalP90 ?? absoluteAnchors.p90) * personalWeight +
      absoluteAnchors.p90 * anchorWeight;
  var p95 = (personalP95 ?? absoluteAnchors.p95) * personalWeight +
      absoluteAnchors.p95 * anchorWeight;

  final minGap = math.max(
    strainConfig.minPercentileGapAbsolute,
    p50 * strainConfig.minPercentileGapRatio,
  );
  if (p90 - p50 < minGap) p90 = p50 + minGap;
  if (p95 - p90 < minGap) p95 = p90 + minGap;

  final baselineConfidence = validDays >= strainConfig.fullPersonalBaselineDays
      ? config.confidence.max
      : validDays >= strainConfig.minPersonalBaselineDays
          ? strainConfig.partialBaselineConfidence
          : strainConfig.coldStartBaselineConfidence;

  return StrainPercentileAnchors(
    p50: p50,
    p90: p90,
    p95: p95,
    validDays: validDays,
    baselineConfidence: baselineConfidence,
  );
}

double normalizeLoadToScore(double? load, StrainPercentileAnchors anchors) {
  if (!isFiniteNumber(load) || load! <= 0) return 0;
  if (load <= anchors.p50) {
    return clampDouble((load / anchors.p50) * 50, 0, 50);
  }
  if (load <= anchors.p90) {
    return 50 + (load - anchors.p50) / (anchors.p90 - anchors.p50) * 35;
  }
  if (load <= anchors.p95) {
    return 85 + (load - anchors.p90) / (anchors.p95 - anchors.p90) * 10;
  }
  return clampDouble(
    95 + 5 * (1 - math.exp(-(load - anchors.p95) / anchors.p95)),
    0,
    100,
  );
}

_ComponentScores _normalizeDailyLoads(
  _ComponentLoads loads,
  List<HistoricalDailyStrainLoad> history,
  AlgorithmConfig config,
  List<String> warnings,
) {
  final window = history.takeLast(config.strainScore.historyWindowDays);
  final cardioValidDays =
      window.where((day) => isFiniteNumber(day.cardioLoadAU)).length;
  final rpeValidDays =
      window.where((day) => isFiniteNumber(day.rpeLoadAU)).length;
  final externalMechanicalValidDays = window
      .where((day) => isFiniteNumber(day.externalMechanicalLoadAU))
      .length;
  final availableValidDays = <int>[
    if (isFiniteNumber(loads.cardio)) cardioValidDays,
    if (isFiniteNumber(loads.rpe)) rpeValidDays,
    if (isFiniteNumber(loads.externalMechanical)) externalMechanicalValidDays,
  ];
  final baselineValidDays =
      availableValidDays.isEmpty ? 0 : availableValidDays.reduce(math.min);
  if (availableValidDays.isNotEmpty &&
      baselineValidDays < config.strainScore.minPersonalBaselineDays) {
    warnings.add('strain_baseline_calibration_phase');
  } else if (availableValidDays.isNotEmpty &&
      baselineValidDays < config.strainScore.fullPersonalBaselineDays) {
    warnings.add('strain_baseline_partial');
  }

  final cardioAnchors = calculateStrainAnchors(
    window.map((day) => day.cardioLoadAU).toList(),
    config.strainScore.absoluteAnchors.cardio,
    validDays: cardioValidDays,
    config: config,
  );
  final rpeAnchors = calculateStrainAnchors(
    window.map((day) => day.rpeLoadAU).toList(),
    config.strainScore.absoluteAnchors.rpe,
    validDays: rpeValidDays,
    config: config,
  );
  final externalAnchors = calculateStrainAnchors(
    window.map((day) => day.externalMechanicalLoadAU).toList(),
    config.strainScore.absoluteAnchors.externalMechanical,
    validDays: externalMechanicalValidDays,
    config: config,
  );
  final availableBaselineConfidences = <double>[
    if (isFiniteNumber(loads.cardio)) cardioAnchors.baselineConfidence,
    if (isFiniteNumber(loads.rpe)) rpeAnchors.baselineConfidence,
    if (isFiniteNumber(loads.externalMechanical))
      externalAnchors.baselineConfidence,
  ];

  return _ComponentScores(
    cardio: isFiniteNumber(loads.cardio)
        ? normalizeLoadToScore(loads.cardio, cardioAnchors)
        : null,
    rpe: isFiniteNumber(loads.rpe)
        ? normalizeLoadToScore(loads.rpe, rpeAnchors)
        : null,
    externalMechanical: isFiniteNumber(loads.externalMechanical)
        ? normalizeLoadToScore(loads.externalMechanical, externalAnchors)
        : null,
    baselineConfidence: availableBaselineConfidences.isEmpty
        ? config.strainScore.coldStartBaselineConfidence
        : availableBaselineConfidences.reduce(math.min),
    baselineValidDays: baselineValidDays,
    cardioBaselineValidDays: cardioValidDays,
    rpeBaselineValidDays: rpeValidDays,
    externalMechanicalBaselineValidDays: externalMechanicalValidDays,
  );
}

_ComponentLoads _aggregateLoads(List<SessionStrainResult> sessions) {
  double? sumFinite(Iterable<double?> values) {
    final finite = values.where(isFiniteNumber).map((value) => value!);
    if (finite.isEmpty) return null;
    return finite.fold<double>(0, (sum, value) => sum + value);
  }

  return _ComponentLoads(
    cardio: sumFinite(sessions.map((session) => session.cardioLoadAU)),
    rpe: sumFinite(sessions.map((session) => session.rpeLoadAU)),
    externalMechanical:
        sumFinite(sessions.map((session) => session.externalMechanicalLoadAU)),
  );
}

double? _combineSessionWeightedScores(
  List<SessionStrainResult> sessions,
  _ComponentScores scores,
  AlgorithmConfig config,
  List<String> warnings,
) {
  final availableScores = {
    'cardio': scores.cardio,
    'rpe': scores.rpe,
    'externalMechanical': scores.externalMechanical,
  };
  if (availableScores.values.every((value) => !isFiniteNumber(value))) {
    warnings.add('strain_components_unavailable');
    return null;
  }

  var total = 0.0;
  var totalDuration = 0.0;
  for (final session in sessions) {
    final weights = _weightsForCategory(session.sportCategory, config);
    final availableWeight = [
      if (isFiniteNumber(scores.cardio)) weights.cardio,
      if (isFiniteNumber(scores.rpe)) weights.rpe,
      if (isFiniteNumber(scores.externalMechanical)) weights.externalMechanical,
    ].fold<double>(0, (sum, value) => sum + value);
    if (availableWeight <= 0) continue;

    if (!isFiniteNumber(scores.cardio)) {
      warnings.add('cardio_component_missing');
    }
    if (!isFiniteNumber(scores.rpe)) warnings.add('rpe_component_missing');
    if (!isFiniteNumber(scores.externalMechanical)) {
      warnings.add('external_mechanical_component_missing');
    }

    var sessionScore = 0.0;
    if (isFiniteNumber(scores.cardio)) {
      sessionScore += scores.cardio! * weights.cardio / availableWeight;
    }
    if (isFiniteNumber(scores.rpe)) {
      sessionScore += scores.rpe! * weights.rpe / availableWeight;
    }
    if (isFiniteNumber(scores.externalMechanical)) {
      sessionScore += scores.externalMechanical! *
          weights.externalMechanical /
          availableWeight;
    }

    if (session.sportCategory == StrainSportCategory.mobility) {
      sessionScore = math.min(sessionScore, 35);
    }

    final durationWeight = math.max(
      config.confidence.min,
      session.durationMinutes,
    );
    if (durationWeight <= config.confidence.min) continue;
    total += sessionScore * durationWeight;
    totalDuration += durationWeight;
  }

  if (totalDuration <= 0) return null;
  return total / totalDuration;
}

StrainComponentWeights _weightsForCategory(
  StrainSportCategory category,
  AlgorithmConfig config,
) {
  final weights = config.strainScore.componentWeights;
  if (category == StrainSportCategory.mobility) return weights['mobility']!;
  if (category == StrainSportCategory.strength) return weights['strength']!;
  if (category == StrainSportCategory.sprint ||
      category == StrainSportCategory.plyometrics) {
    return weights['sprint_plyometrics']!;
  }
  if (category == StrainSportCategory.alpineSkiingTraining) {
    return weights['alpine_skiing_training']!;
  }
  if (category == StrainSportCategory.alpineSkiingRace) {
    return weights['alpine_skiing_race']!;
  }
  if (category == StrainSportCategory.football ||
      category == StrainSportCategory.teamSport) {
    return weights['team_sport']!;
  }
  if (isEnduranceStrainCategory(category)) return weights['endurance']!;
  return weights['default']!;
}

_CardioLoad _calculateCardioLoad(
  WorkoutSessionInput session,
  double duration,
  double maxHr,
  double restingHr,
  AlgorithmConfig config,
  List<String> warnings,
) {
  final sampleLoad = _cardioLoadFromSamples(
    session.heartRateSamples,
    duration,
    maxHr,
    restingHr,
    config,
  );
  final zones = session.heartRateZones;
  if (zones != null && zones.hasAny) {
    final coverage = _zoneCoverage(zones, duration);
    if (coverage >= config.strainScore.minHrCoverageToUseSamples) {
      if ((session.heartRateSamples ?? const []).isNotEmpty &&
          sampleLoad.heartRateCoverage <
              config.strainScore.minHrCoverageToUseSamples) {
        warnings.add('heart_rate_coverage_low');
      }
      if (coverage < config.strainScore.minHrCoverageForFullConfidence) {
        warnings.add('heart_rate_coverage_partial');
      }
      final multipliers = config.strainScore.cardioZoneMultipliers;
      final observedLoad = _nonNegative(zones.z1Minutes) * multipliers['z1']! +
          _nonNegative(zones.z2Minutes) * multipliers['z2']! +
          _nonNegative(zones.z3Minutes) * multipliers['z3']! +
          _nonNegative(zones.z4Minutes) * multipliers['z4']! +
          _nonNegative(zones.z5Minutes) * multipliers['z5']!;
      return _extrapolatePartialHeartRateLoad(
        _CardioLoad(
          value: observedLoad,
          method: 'hr_zones',
          heartRateCoverage: coverage,
        ),
        config,
        warnings,
      );
    }
    if (coverage > 0) warnings.add('heart_rate_zones_coverage_low');
  }

  if (sampleLoad.heartRateCoverage >=
      config.strainScore.minHrCoverageToUseSamples) {
    if (sampleLoad.heartRateCoverage <
        config.strainScore.minHrCoverageForFullConfidence) {
      warnings.add('heart_rate_coverage_partial');
    }
    return _extrapolatePartialHeartRateLoad(
      sampleLoad,
      config,
      warnings,
    );
  }
  if ((session.heartRateSamples ?? const []).isNotEmpty) {
    warnings.add('heart_rate_coverage_low');
  }

  if (isFiniteNumber(session.avgHeartRateBpm)) {
    final hrr = _hrr(session.avgHeartRateBpm!, maxHr, restingHr);
    warnings.add('cardio_load_estimated_from_average_hr');
    return _CardioLoad(
      value: duration * hrr * math.exp(config.strainScore.cardioExponent * hrr),
      method: 'average_hr',
      heartRateCoverage: config.confidence.min,
    );
  }

  warnings.add('cardio_load_unavailable');
  return _CardioLoad(
    value: null,
    method: null,
    heartRateCoverage: config.confidence.min,
  );
}

_CardioLoad _extrapolatePartialHeartRateLoad(
  _CardioLoad load,
  AlgorithmConfig config,
  List<String> warnings,
) {
  final value = load.value;
  final coverage = load.heartRateCoverage;
  if (!isFiniteNumber(value) || coverage <= 0 || coverage >= 1) return load;

  final uncappedFactor = 1 / coverage;
  final factor = math.min(
    uncappedFactor,
    config.strainScore.maxPartialHrExtrapolationFactor,
  );
  if (factor <= 1) return load;

  warnings.add('heart_rate_load_extrapolated');
  if (factor < uncappedFactor) {
    warnings.add('heart_rate_load_extrapolation_capped');
  }
  return _CardioLoad(
    value: value! * factor,
    method: load.method,
    heartRateCoverage: coverage,
  );
}

_CardioLoad _cardioLoadFromSamples(
  List<HeartRateSample>? samples,
  double duration,
  double maxHr,
  double restingHr,
  AlgorithmConfig config,
) {
  if (samples == null || samples.length < 2 || duration <= 0) {
    return const _CardioLoad(
      value: null,
      method: null,
      heartRateCoverage: 0,
    );
  }

  final parsed = samples
      .map((sample) {
        final time = DateTime.tryParse(sample.timestamp);
        if (time == null || !sample.bpm.isFinite) return null;
        if (sample.bpm < 35 || sample.bpm > 235) return null;
        return MapEntry(time, sample.bpm);
      })
      .whereType<MapEntry<DateTime, double>>()
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  if (parsed.length < 2) {
    return const _CardioLoad(value: null, method: null, heartRateCoverage: 0);
  }

  var coveredMinutes = 0.0;
  var load = 0.0;
  for (var i = 0; i < parsed.length - 1; i++) {
    final gapSeconds = parsed[i + 1].key.difference(parsed[i].key).inSeconds;
    if (gapSeconds <= 0 || gapSeconds > 300) continue;
    final minutes = gapSeconds / 60;
    final bpm = (parsed[i].value + parsed[i + 1].value) / 2;
    final hrr = _hrr(bpm, maxHr, restingHr);
    load += minutes * hrr * math.exp(config.strainScore.cardioExponent * hrr);
    coveredMinutes += minutes;
  }

  if (coveredMinutes <= 0) {
    return const _CardioLoad(value: null, method: null, heartRateCoverage: 0);
  }

  return _CardioLoad(
    value: load,
    method: 'hr_time_series',
    heartRateCoverage: clampDouble(coveredMinutes / duration, 0, 1),
  );
}

_RpeLoad _calculateRpeLoad(
  WorkoutSessionInput session,
  double duration,
  List<String> warnings,
) {
  final rpe = _clampedRpe(session.rpe);
  if (!isFiniteNumber(rpe)) {
    warnings.add('rpe_missing');
    return const _RpeLoad(value: null, method: null);
  }
  return _RpeLoad(value: duration * rpe!, method: 'duration_x_rpe');
}

_ExternalLoad _calculateExternalMechanicalLoad(
  WorkoutSessionInput session,
  StrainSportCategory category,
  double duration,
  AlgorithmConfig config,
  List<String> warnings,
) {
  final multiplier = config.strainScore.sportImpactMultipliers[category.code] ??
      config.strainScore.sportImpactMultipliers['unknown']!;
  final distanceKm = _nonNegative(session.distanceMeters) / 1000;
  final elevationGain = _nonNegative(session.elevationGainMeters);
  final elevationLoss = _nonNegative(session.elevationLossMeters);
  final steps = _nonNegative(session.steps);
  final runCount = _nonNegative(session.runCount);

  _ExternalLoad measured(double value, String method) => _ExternalLoad(
        value: value,
        method: method,
        usedEstimatedIntensity: false,
      );

  _ExternalLoad estimatedFromDuration() {
    warnings.add('external_load_estimated_from_duration');
    if (category == StrainSportCategory.alpineSkiingTraining ||
        category == StrainSportCategory.alpineSkiingRace) {
      warnings.add('ski_external_load_estimated_from_duration');
    }
    var value = duration * multiplier;
    if (category == StrainSportCategory.mobility) {
      value = math.min(value, 20);
    }
    return _ExternalLoad(
      value: value,
      method: '${category.code}_duration_exposure_estimate',
      usedEstimatedIntensity: true,
    );
  }

  switch (category) {
    case StrainSportCategory.running:
      if (distanceKm > 0 || elevationGain > 0) {
        return measured(
          (distanceKm * 10 + elevationGain * 0.03) * multiplier,
          'running_distance_elevation',
        );
      }
      if (steps > 0) {
        return measured(steps * 0.001 * multiplier, 'running_steps');
      }
      return estimatedFromDuration();
    case StrainSportCategory.cycling:
      if (isFiniteNumber(session.powerWattsAvg) && session.powerWattsAvg! > 0) {
        final workKj = session.powerWattsAvg! * duration * 60 / 1000;
        return measured(workKj, 'cycling_work_kj');
      }
      if (distanceKm > 0 || elevationGain > 0) {
        return measured(
          (distanceKm * 0.5 + elevationGain * 0.02) * multiplier,
          'cycling_distance_elevation',
        );
      }
      return estimatedFromDuration();
    case StrainSportCategory.swimming:
      if (distanceKm > 0) {
        return measured(
          distanceKm * 5 * multiplier,
          'swimming_distance',
        );
      }
      return estimatedFromDuration();
    case StrainSportCategory.strength:
      return estimatedFromDuration();
    case StrainSportCategory.sprint:
    case StrainSportCategory.plyometrics:
      if (distanceKm > 0) {
        return measured(
          distanceKm * 10 * multiplier,
          '${category.code}_distance',
        );
      }
      if (steps > 0) {
        return measured(
          steps * 0.001 * multiplier,
          '${category.code}_steps',
        );
      }
      return estimatedFromDuration();
    case StrainSportCategory.football:
    case StrainSportCategory.teamSport:
      if (distanceKm > 0) {
        return measured(
          distanceKm * 8 * multiplier,
          '${category.code}_distance',
        );
      }
      if (steps > 0) {
        return measured(
          steps * 0.001 * multiplier,
          '${category.code}_steps',
        );
      }
      return estimatedFromDuration();
    case StrainSportCategory.alpineSkiingTraining:
    case StrainSportCategory.alpineSkiingRace:
      if (elevationLoss > 0 || runCount > 0) {
        return measured(
          (elevationLoss * 0.04 + runCount * 8) * multiplier,
          '${category.code}_vertical_runs',
        );
      }
      return estimatedFromDuration();
    case StrainSportCategory.mobility:
      return estimatedFromDuration();
    case StrainSportCategory.enduranceGeneric:
    case StrainSportCategory.unknown:
      if (distanceKm > 0 || elevationGain > 0) {
        return measured(
          (distanceKm * 2 + elevationGain * 0.01) * multiplier,
          '${category.code}_distance_elevation',
        );
      }
      if (steps > 0) {
        return measured(
          steps * 0.001 * multiplier,
          '${category.code}_steps',
        );
      }
      return estimatedFromDuration();
  }
}

Map<String, dynamic> _dailyComponents({
  required _ComponentScores scores,
  required _ComponentLoads loads,
  required double totalDuration,
  required List<SessionStrainResult> sessionResults,
  required Map<String, int> sportMix,
}) {
  final bestMethod = <String, String>{};
  String? firstMethod(Iterable<String?> methods) {
    return methods.firstWhere((method) => method != null, orElse: () => null);
  }

  final cardioMethod = firstMethod(sessionResults.map((s) => s.cardioMethod));
  final rpeMethod = firstMethod(sessionResults.map((s) => s.rpeMethod));
  final externalMethod =
      firstMethod(sessionResults.map((s) => s.externalMechanicalMethod));
  if (cardioMethod != null) bestMethod['cardioMethod'] = cardioMethod;
  if (rpeMethod != null) bestMethod['rpeMethod'] = rpeMethod;
  if (externalMethod != null) {
    bestMethod['externalMechanicalMethod'] = externalMethod;
  }

  return {
    if (scores.cardio != null) 'cardioScore': scores.cardio,
    if (scores.rpe != null) 'rpeScore': scores.rpe,
    if (scores.externalMechanical != null)
      'externalMechanicalScore': scores.externalMechanical,
    'totalDurationMinutes': totalDuration,
    'sessionCount': sessionResults.length,
    'sportMix': sportMix,
    'rawLoads': {
      if (loads.cardio != null) 'cardioLoadAU': loads.cardio,
      if (loads.rpe != null) 'rpeLoadAU': loads.rpe,
      if (loads.externalMechanical != null)
        'externalMechanicalLoadAU': loads.externalMechanical,
    },
    'methods': bestMethod,
    'coverage': {
      'heartRateCoverage': sessionResults.isEmpty
          ? 0
          : sessionResults.fold<double>(
                0,
                (sum, result) => sum + result.heartRateCoverage,
              ) /
              sessionResults.length,
      'baselineValidDays': scores.baselineValidDays,
      'baselineValidDaysByComponent': {
        'cardio': scores.cardioBaselineValidDays,
        'rpe': scores.rpeBaselineValidDays,
        'externalMechanical': scores.externalMechanicalBaselineValidDays,
      },
    },
  };
}

double _averageHeartRateCoverageQuality(
  List<SessionStrainResult> sessions,
  AlgorithmConfig config,
) {
  if (sessions.isEmpty) return config.confidence.min;
  return sessions
          .map((session) => session.heartRateCoverage >=
                  config.strainScore.minHrCoverageForFullConfidence
              ? 1.0
              : session.heartRateCoverage >=
                      config.strainScore.minHrCoverageToUseSamples
                  ? config.strainScore.partialHrConfidenceMultiplier
                  : config.strainScore.lowHrQualityScore)
          .reduce((a, b) => a + b) /
      sessions.length;
}

double _rpeAvailability(
  List<WorkoutSessionInput> sessions,
  AlgorithmConfig config,
) {
  if (sessions.isEmpty) return config.confidence.min;
  return sessions
          .where((session) => isFiniteNumber(_clampedRpe(session.rpe)))
          .length /
      sessions.length;
}

double _sportKnownConfidence(
  List<SessionStrainResult> sessions,
  AlgorithmConfig config,
) {
  if (sessions.isEmpty) return config.confidence.min;
  return sessions
          .where(
              (session) => session.sportCategory != StrainSportCategory.unknown)
          .length /
      sessions.length;
}

double _maxHeartRate(
  AthleteStrainProfile profile,
  StrainScoreConfig config,
) {
  final value = profile.maxHeartRateBpm;
  if (value != null && value.isFinite && value > 80 && value <= 240) {
    return value;
  }
  return config.defaultMaxHeartRateBpm;
}

double _restingHeartRate(
  AthleteStrainProfile profile,
  double maxHr,
  StrainScoreConfig config,
) {
  final value = profile.restingHeartRateEstimateBpm;
  if (value != null && value.isFinite && value >= 30 && value < maxHr) {
    return value;
  }
  return config.defaultRestingHeartRateEstimateBpm;
}

double _hrr(double bpm, double maxHr, double restingHr) {
  final reserve = maxHr - restingHr;
  if (reserve <= 0) return 0;
  return clampDouble((bpm - restingHr) / reserve, 0, 1);
}

double? _clampedRpe(double? rpe) {
  if (!isFiniteNumber(rpe)) return null;
  return clampDouble(rpe!, 0, 10);
}

double _zoneCoverage(HeartRateZones zones, double duration) {
  if (duration <= 0) return 0;
  final zoneMinutes = _nonNegative(zones.belowZone1Minutes) +
      _nonNegative(zones.z1Minutes) +
      _nonNegative(zones.z2Minutes) +
      _nonNegative(zones.z3Minutes) +
      _nonNegative(zones.z4Minutes) +
      _nonNegative(zones.z5Minutes);
  return clampDouble(zoneMinutes / duration, 0, 1);
}

double _nonNegative(double? value) {
  if (!isFiniteNumber(value)) return 0;
  return math.max(0, value!);
}

class _CardioLoad {
  final double? value;
  final String? method;
  final double heartRateCoverage;

  const _CardioLoad({
    required this.value,
    required this.method,
    required this.heartRateCoverage,
  });
}

class _RpeLoad {
  final double? value;
  final String? method;

  const _RpeLoad({
    required this.value,
    required this.method,
  });
}

class _ExternalLoad {
  final double value;
  final String method;
  final bool usedEstimatedIntensity;

  const _ExternalLoad({
    required this.value,
    required this.method,
    required this.usedEstimatedIntensity,
  });
}

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int count) {
    if (count <= 0) return const [];
    if (length <= count) return List<T>.from(this);
    return sublist(length - count);
  }
}
