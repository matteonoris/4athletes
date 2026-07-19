import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/utils/metrics_engine.dart';
import 'package:flutter_mobile/utils/strain_session_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = AthleteStrainProfile(
    athleteId: 'athlete-v2',
    maxHeartRateBpm: 190,
    restingHeartRateEstimateBpm: 50,
    bodyMassKg: 72,
  );

  group('strain v2 heart-rate inputs', () {
    test('mapper distingue Z0-Z5 Health dal formato legacy a cinque zone', () {
      final structured = workoutSessionInputFromTrainingSession(
        _trainingSession(
          details: const {
            'source': 'health_sync',
            'hr_zones_seconds': [600, 60, 120, 180, 240, 300],
          },
        ),
        athleteId: 'athlete-v2',
      );
      final legacy = workoutSessionInputFromTrainingSession(
        _trainingSession(
          id: 'legacy',
          details: const {
            'source': 'health_sync',
            'hr_zones_seconds': [60, 120, 180, 240, 300],
          },
        ),
        athleteId: 'athlete-v2',
      );

      expect(structured.heartRateZones!.belowZone1Minutes, 10);
      expect(structured.heartRateZones!.z1Minutes, 1);
      expect(structured.heartRateZones!.z2Minutes, 2);
      expect(structured.heartRateZones!.z3Minutes, 3);
      expect(structured.heartRateZones!.z4Minutes, 4);
      expect(structured.heartRateZones!.z5Minutes, 5);

      expect(legacy.heartRateZones!.belowZone1Minutes, isNull);
      expect(legacy.heartRateZones!.z1Minutes, 1);
      expect(legacy.heartRateZones!.z2Minutes, 2);
      expect(legacy.heartRateZones!.z3Minutes, 3);
      expect(legacy.heartRateZones!.z4Minutes, 4);
      expect(legacy.heartRateZones!.z5Minutes, 5);
    });

    test('Z0 contribuisce alla coverage e il carico parziale viene estrapolato',
        () {
      final result = calculateSessionStrain(
        _workout(
          durationMinutes: 60,
          heartRateZones: const HeartRateZones(
            belowZone1Minutes: 30,
            z1Minutes: 15,
          ),
        ),
        profile,
      );

      expect(result.cardioMethod, 'hr_zones');
      expect(result.heartRateCoverage, closeTo(0.75, 1e-12));
      expect(result.cardioLoadAU, closeTo(20, 1e-9));
      expect(result.warnings, contains('heart_rate_load_extrapolated'));
    });

    test('la vera Z5 importata non viene scartata', () {
      final input = workoutSessionInputFromTrainingSession(
        _trainingSession(
          duration: '30',
          details: const {
            'source': 'health_sync',
            'hr_zones_seconds': [0, 0, 0, 0, 0, 1800],
          },
        ),
        athleteId: 'athlete-v2',
      );

      final result = calculateSessionStrain(input, profile);

      expect(input.heartRateZones!.z5Minutes, 30);
      expect(result.heartRateCoverage, 1);
      expect(result.cardioLoadAU, 150);
    });

    test('zone individualizzate adeguate hanno precedenza sulla time-series',
        () {
      final result = calculateSessionStrain(
        _workout(
          durationMinutes: 60,
          heartRateZones: const HeartRateZones(z1Minutes: 60),
          heartRateSamples: _hrSamples(minutes: 60, bpm: 180),
        ),
        profile,
      );

      expect(result.cardioMethod, 'hr_zones');
      expect(result.cardioLoadAU, 60);
    });

    test('estrapolazione time-series e limitata al fattore configurato', () {
      final samples = _hrSamples(minutes: 18, bpm: 150);
      final complete = calculateSessionStrain(
        _workout(durationMinutes: 18, heartRateSamples: samples),
        profile,
      );
      final partial = calculateSessionStrain(
        _workout(durationMinutes: 60, heartRateSamples: samples),
        profile,
      );

      expect(partial.heartRateCoverage, closeTo(0.30, 1e-12));
      expect(
        partial.cardioLoadAU,
        closeTo(complete.cardioLoadAU! * 2, 1e-9),
      );
      expect(partial.warnings, contains('heart_rate_load_extrapolated'));
      expect(
        partial.warnings,
        contains('heart_rate_load_extrapolation_capped'),
      );
    });

    test('se HRmax di seduta supera il profilo di oltre 3 bpm avvisa', () {
      final stale = calculateSessionStrain(
        _workout(avgHeartRateBpm: 150, maxHeartRateBpm: 194),
        profile,
      );
      final withinTolerance = calculateSessionStrain(
        _workout(
          id: 'within-tolerance',
          avgHeartRateBpm: 150,
          maxHeartRateBpm: 193,
        ),
        profile,
      );

      expect(stale.warnings, contains('profile_max_heart_rate_outdated'));
      expect(
        withinTolerance.warnings,
        isNot(contains('profile_max_heart_rate_outdated')),
      );
    });
  });

  group('strain v2 independent load dimensions', () {
    test('RPE non viene duplicato in cardio o carico esterno', () {
      final easy = calculateSessionStrain(
        _workout(sportType: 'weightlifting', rpe: 2),
        profile,
      );
      final hard = calculateSessionStrain(
        _workout(id: 'hard', sportType: 'weightlifting', rpe: 10),
        profile,
      );

      expect(easy.cardioLoadAU, isNull);
      expect(hard.cardioLoadAU, isNull);
      expect(easy.rpeLoadAU, 120);
      expect(hard.rpeLoadAU, 600);
      expect(
        easy.externalMechanicalLoadAU,
        hard.externalMechanicalLoadAU,
      );
      expect(easy.warnings, contains('cardio_load_unavailable'));
      expect(easy.warnings, contains('external_load_estimated_from_duration'));
    });

    test('ciclismo con potenza usa lavoro meccanico in kJ', () {
      final highVariability = calculateSessionStrain(
        _workout(
          sportType: 'cycling',
          powerWattsAvg: 200,
          normalizedPowerWatts: 400,
        ),
        profile,
      );
      final lowVariability = calculateSessionStrain(
        _workout(
          id: 'low-variability',
          sportType: 'cycling',
          powerWattsAvg: 200,
          normalizedPowerWatts: 210,
        ),
        profile,
      );

      expect(highVariability.externalMechanicalMethod, 'cycling_work_kj');
      expect(highVariability.externalMechanicalLoadAU, closeTo(720, 1e-9));
      expect(
        lowVariability.externalMechanicalLoadAU,
        highVariability.externalMechanicalLoadAU,
      );
    });

    test('score multi-sessione usa la durata effettiva come peso', () {
      final result = calculateDailyStrain(
        '2026-06-12',
        [
          _workout(
            id: 'long-run',
            sportType: 'running',
            durationMinutes: 90,
            rpe: 6,
            avgHeartRateBpm: 150,
            distanceMeters: 15000,
          ),
          _workout(
            id: 'short-strength',
            sportType: 'weightlifting',
            durationMinutes: 10,
            rpe: 6,
            avgHeartRateBpm: 150,
          ),
        ],
        profile,
        _history(),
      );

      final cardio = result.components['cardioScore'] as double;
      final rpe = result.components['rpeScore'] as double;
      final external = result.components['externalMechanicalScore'] as double;
      final endurance =
          defaultAlgorithmConfig.strainScore.componentWeights['endurance']!;
      final strength =
          defaultAlgorithmConfig.strainScore.componentWeights['strength']!;
      final enduranceScore = cardio * endurance.cardio +
          rpe * endurance.rpe +
          external * endurance.externalMechanical;
      final strengthScore = cardio * strength.cardio +
          rpe * strength.rpe +
          external * strength.externalMechanical;
      final expected = (enduranceScore * 90 + strengthScore * 10) / 100;

      expect(result.score, closeTo(expected, 1e-9));
    });

    test('baseline conta separatamente i giorni validi per componente', () {
      final history = _historyWithoutCardio();
      final withoutCardioToday = calculateDailyStrain(
        '2026-06-12',
        [_workout(sportType: 'weightlifting')],
        profile,
        history,
      );
      final withCardioToday = calculateDailyStrain(
        '2026-06-12',
        [
          _workout(
            id: 'strength-with-hr',
            sportType: 'weightlifting',
            avgHeartRateBpm: 150,
          ),
        ],
        profile,
        history,
      );

      final withoutCardioCoverage = Map<String, dynamic>.from(
        withoutCardioToday.components['coverage'] as Map,
      );
      final withoutCardioCounts = Map<String, dynamic>.from(
        withoutCardioCoverage['baselineValidDaysByComponent'] as Map,
      );
      expect(withoutCardioCoverage['baselineValidDays'], 28);
      expect(withoutCardioCounts['cardio'], 0);
      expect(withoutCardioCounts['rpe'], 28);
      expect(withoutCardioCounts['externalMechanical'], 28);
      expect(
        withoutCardioToday.warnings,
        isNot(contains('strain_baseline_calibration_phase')),
      );
      expect(
        withoutCardioToday.warnings,
        isNot(contains('strain_baseline_partial')),
      );

      final withCardioCoverage = Map<String, dynamic>.from(
        withCardioToday.components['coverage'] as Map,
      );
      expect(withCardioCoverage['baselineValidDays'], 0);
      expect(
        withCardioToday.warnings,
        contains('strain_baseline_calibration_phase'),
      );
    });
  });
}

TrainingSession _trainingSession({
  String id = 'health-session',
  String duration = '60',
  Map<String, dynamic>? details,
}) {
  return TrainingSession(
    id: id,
    sportId: 'running',
    date: '2026-06-12',
    startTime: '08:00',
    endTime: '09:00',
    duration: duration,
    effort: 5,
    details: details,
  );
}

WorkoutSessionInput _workout({
  String id = 'session-v2',
  String sportType = 'running',
  double durationMinutes = 60,
  double? rpe = 6,
  List<HeartRateSample>? heartRateSamples,
  HeartRateZones? heartRateZones,
  double? avgHeartRateBpm,
  double? maxHeartRateBpm,
  double? distanceMeters,
  double? powerWattsAvg,
  double? normalizedPowerWatts,
}) {
  return WorkoutSessionInput(
    id: id,
    athleteId: 'athlete-v2',
    date: '2026-06-12',
    sportType: sportType,
    durationMinutes: durationMinutes,
    rpe: rpe,
    heartRateSamples: heartRateSamples,
    heartRateZones: heartRateZones,
    avgHeartRateBpm: avgHeartRateBpm,
    maxHeartRateBpm: maxHeartRateBpm,
    distanceMeters: distanceMeters,
    powerWattsAvg: powerWattsAvg,
    normalizedPowerWatts: normalizedPowerWatts,
  );
}

List<HeartRateSample> _hrSamples({
  required int minutes,
  required double bpm,
}) {
  final start = DateTime(2026, 6, 12, 8);
  return List.generate(minutes + 1, (index) {
    return HeartRateSample(
      timestamp: start.add(Duration(minutes: index)).toIso8601String(),
      bpm: bpm,
    );
  });
}

List<HistoricalDailyStrainLoad> _history() {
  return List.generate(30, (index) {
    final date = DateTime(2026, 6, 12).subtract(Duration(days: 30 - index));
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

List<HistoricalDailyStrainLoad> _historyWithoutCardio() {
  return List.generate(28, (index) {
    final date = DateTime(2026, 6, 12).subtract(Duration(days: 28 - index));
    return HistoricalDailyStrainLoad(
      date: date.toIso8601String().split('T').first,
      rpeLoadAU: 300 + index.toDouble(),
      externalMechanicalLoadAU: 60 + index.toDouble(),
      totalDurationMinutes: 60,
      sessionCount: 1,
    );
  });
}
