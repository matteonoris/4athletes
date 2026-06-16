import 'package:flutter_mobile/utils/metrics_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = AthleteStrainProfile(
    athleteId: 'athlete-1',
    maxHeartRateBpm: 190,
    restingHeartRateEstimateBpm: 50,
    bodyMassKg: 72,
  );

  test('giorno senza workout produce score 0 e NO_TRAINING', () {
    final result = calculateDailyStrain(
      '2026-06-12',
      const [],
      profile,
      _history(),
    );

    expect(result.score, 0);
    expect(result.status, StrainScoreStatus.noTraining);
  });

  test('HR time-series con coverage alto usa i campioni', () {
    final session = _session(
      heartRateSamples: _hrSamples(minutes: 58, bpm: 155),
      rpe: 7,
    );

    final result = calculateSessionStrain(session, profile);

    expect(result.cardioMethod, 'hr_time_series');
    expect(result.heartRateCoverage, greaterThan(0.90));
    expect(result.warnings, isNot(contains('heart_rate_coverage_partial')));
  });

  test('HR time-series con coverage basso preferisce fallback', () {
    final session = _session(
      heartRateSamples: _hrSamples(minutes: 10, bpm: 155),
      heartRateZones: const HeartRateZones(z2Minutes: 20, z3Minutes: 25),
      rpe: 6,
    );

    final result = calculateSessionStrain(session, profile);

    expect(result.cardioMethod, 'hr_zones');
    expect(result.warnings, contains('heart_rate_coverage_low'));
  });

  test('HR time-series non interpola gap lunghi tra campioni', () {
    final start = DateTime(2026, 6, 12, 8);
    final session = _session(
      heartRateSamples: [
        HeartRateSample(timestamp: start.toIso8601String(), bpm: 150),
        HeartRateSample(
          timestamp: start.add(const Duration(minutes: 20)).toIso8601String(),
          bpm: 150,
        ),
      ],
      rpe: 6,
    );

    final result = calculateSessionStrain(session, profile);

    expect(result.cardioMethod, 'rpe_fallback');
    expect(result.heartRateCoverage, 0);
    expect(result.warnings, contains('cardio_load_estimated_from_rpe'));
  });

  test('HR zones fallback calcola cardio load da zone', () {
    final session = _session(
      heartRateZones: const HeartRateZones(
        z1Minutes: 5,
        z2Minutes: 20,
        z3Minutes: 20,
        z4Minutes: 10,
        z5Minutes: 5,
      ),
    );

    final result = calculateSessionStrain(session, profile);

    expect(result.cardioMethod, 'hr_zones');
    expect(result.cardioLoadAU, 195);
  });

  test('RPE mancante esclude componente RPE', () {
    final result = calculateDailyStrain(
      '2026-06-12',
      [_session(rpe: null, avgHeartRateBpm: 145)],
      profile,
      _history(),
    );

    expect(result.score, isNotNull);
    expect(result.warnings, contains('rpe_missing'));
    expect(result.warnings, contains('rpe_component_missing'));
  });

  test('giorno con piu sessioni aggrega session count e sport mix', () {
    final result = calculateDailyStrain(
      '2026-06-12',
      [
        _session(id: 'run_1', sportType: 'running', rpe: 6),
        _session(id: 'gym_1', sportType: 'weightlifting', rpe: 8),
      ],
      profile,
      _history(),
    );

    expect(result.score, isNotNull);
    expect(result.components['sessionCount'], 2);
    expect(result.components['sportMix']['running'], 1);
    expect(result.components['sportMix']['strength'], 1);
  });

  test('sport unknown aggiunge warning', () {
    final result = calculateSessionStrain(
      _session(sportType: 'pickleball_unknown_variant'),
      profile,
    );

    expect(result.sportCategory, StrainSportCategory.unknown);
    expect(result.warnings, contains('unknown_sport_type'));
  });

  test('sport esistenti app sono mappati a categorie strain stabili', () {
    expect(
      mapSportTypeToStrainCategory('pickleball'),
      StrainSportCategory.teamSport,
    );
    expect(
        mapSportTypeToStrainCategory('padel'), StrainSportCategory.teamSport);
    expect(
        mapSportTypeToStrainCategory('dryland'), StrainSportCategory.strength);
    expect(
      mapSportTypeToStrainCategory('walking'),
      StrainSportCategory.enduranceGeneric,
    );
  });

  test('alpine skiing con elevationLoss e runCount usa volume ski', () {
    final result = calculateSessionStrain(
      _session(
        sportType: 'alpine_skiing',
        elevationLossMeters: 1200,
        runCount: 6,
        rpe: 7,
      ),
      profile,
    );

    expect(result.sportCategory, StrainSportCategory.alpineSkiingTraining);
    expect(result.externalMechanicalLoadAU, greaterThan(60));
    expect(
      result.warnings,
      isNot(contains('ski_external_load_estimated_from_duration')),
    );
  });

  test('alpine skiing senza elevationLoss/runCount usa durata', () {
    final result = calculateSessionStrain(
      _session(sportType: 'alpine_skiing', rpe: 7),
      profile,
    );

    expect(
      result.warnings,
      contains('ski_external_load_estimated_from_duration'),
    );
  });

  test('strength con RPE pesa RPE e mechanical', () {
    final result = calculateDailyStrain(
      '2026-06-12',
      [_session(sportType: 'weightlifting', rpe: 8)],
      profile,
      _history(),
    );

    expect(result.score, isNotNull);
    expect(result.components['sportMix']['strength'], 1);
  });

  test('mobility applica cap basso allo score', () {
    final result = calculateDailyStrain(
      '2026-06-12',
      [
        _session(
          sportType: 'mobility',
          durationMinutes: 240,
          rpe: 10,
          avgHeartRateBpm: 160,
        )
      ],
      profile,
      _history(),
    );

    expect(result.score, lessThanOrEqualTo(35));
  });

  test('percentili p50/p90/p95 rispettano min gap', () {
    final anchors = calculateStrainAnchors(
      const [100, 101, 102, 103, 104, 105, 106],
      const StrainComponentAnchors(p50: 90, p90: 260, p95: 360),
      validDays: 21,
      config: defaultAlgorithmConfig,
    );

    final minGap = defaultAlgorithmConfig.strainScore.minPercentileGapAbsolute;
    expect(anchors.p90 - anchors.p50, greaterThanOrEqualTo(minGap));
    expect(anchors.p95 - anchors.p90, greaterThanOrEqualTo(minGap));
  });

  test('cold start sotto 7 giorni usa calibration phase', () {
    final result = calculateDailyStrain(
      '2026-06-12',
      [_session()],
      profile,
      _history(days: 3),
    );

    expect(result.status, StrainScoreStatus.calibrationPhase);
    expect(result.warnings, contains('strain_baseline_calibration_phase'));
  });

  test('7-20 giorni usa blend personale e anchor', () {
    final anchors = calculateStrainAnchors(
      List<num>.filled(10, 1000),
      const StrainComponentAnchors(p50: 100, p90: 200, p95: 300),
      validDays: 10,
      config: defaultAlgorithmConfig,
    );

    expect(anchors.p50, greaterThan(100));
    expect(anchors.p50, lessThan(1000));
    expect(anchors.baselineConfidence, lessThan(1));
  });

  test('componente mancante rinormalizza i pesi disponibili', () {
    final result = calculateDailyStrain(
      '2026-06-12',
      [_session(rpe: null, avgHeartRateBpm: 150)],
      profile,
      _history(),
    );

    expect(result.score, isNotNull);
    expect(result.components['rpeScore'], isNull);
    expect(result.warnings, contains('rpe_component_missing'));
  });

  test('score finale clampato 0-100', () {
    final result = calculateDailyStrain(
      '2026-06-12',
      [
        _session(
          durationMinutes: 2000,
          distanceMeters: 200000,
          elevationGainMeters: 10000,
          rpe: 10,
          avgHeartRateBpm: 220,
        )
      ],
      profile,
      _history(),
    );

    expect(result.score, inInclusiveRange(0, 100));
  });

  test('Daily Sleep Need usa strain del giorno precedente con esponente 1.2',
      () {
    const today = DailyWearableData(
      date: '2026-06-12',
      totalSleepTimeMinutes: 480,
      previousDayStrainScore: 100,
    );

    final adjustment = calculateDailyStrainAdjustment(today);

    expect(
        adjustment, defaultAlgorithmConfig.sleepNeed.maxStrainSleepNeedMinutes);
  });
}

WorkoutSessionInput _session({
  String id = 'session_1',
  String sportType = 'running',
  double durationMinutes = 60,
  double? rpe = 6,
  List<HeartRateSample>? heartRateSamples,
  HeartRateZones? heartRateZones,
  double? avgHeartRateBpm,
  double? distanceMeters,
  double? elevationGainMeters,
  double? elevationLossMeters,
  double? runCount,
}) {
  return WorkoutSessionInput(
    id: id,
    athleteId: 'athlete-1',
    date: '2026-06-12',
    sportType: sportType,
    durationMinutes: durationMinutes,
    rpe: rpe,
    heartRateSamples: heartRateSamples,
    heartRateZones: heartRateZones,
    avgHeartRateBpm: avgHeartRateBpm,
    distanceMeters: distanceMeters,
    elevationGainMeters: elevationGainMeters,
    elevationLossMeters: elevationLossMeters,
    runCount: runCount,
  );
}

List<HeartRateSample> _hrSamples({required int minutes, required double bpm}) {
  final start = DateTime(2026, 6, 12, 8);
  return List<HeartRateSample>.generate(minutes + 1, (index) {
    return HeartRateSample(
      timestamp: start.add(Duration(minutes: index)).toIso8601String(),
      bpm: bpm,
    );
  });
}

List<HistoricalDailyStrainLoad> _history({int days = 30}) {
  return List<HistoricalDailyStrainLoad>.generate(days, (index) {
    final date = DateTime(2026, 6, 12).subtract(Duration(days: days - index));
    return HistoricalDailyStrainLoad(
      date: date.toIso8601String().split('T').first,
      cardioLoadAU: 120 + index.toDouble(),
      rpeLoadAU: 360 + index * 2,
      externalMechanicalLoadAU: 50 + index.toDouble(),
      totalDurationMinutes: 60,
      sessionCount: 1,
    );
  });
}
