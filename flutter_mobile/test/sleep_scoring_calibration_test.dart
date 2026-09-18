import 'package:flutter_mobile/utils/metrics_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = AthleteProfile(
  athleteId: 'personal-sleep-test',
  ageYears: 25,
  timezone: 'UTC',
);
const _need = DailySleepNeedResult(
  valueMinutes: 500,
  personalBaselineMinutes: 500,
  sleepDebtMinutes: 0,
  dailyStrainAdjustmentMinutes: 0,
  napsDeductionMinutes: 0,
  confidence: 1,
  warnings: [],
);

void main() {
  group('Sleep calibration v2.1', () {
    test('short nights stay low despite perfect history and efficiency', () {
      final history = _history();
      final scores = <double>[];
      for (final (minutes, ceiling) in [
        (300.0, 40.0),
        (360.0, 58.0),
        (420.0, 78.0),
        (480.0, 100.0)
      ]) {
        final result =
            _score(_night(28, total: minutes, inBed: minutes), history);
        expect(result.score, lessThanOrEqualTo(ceiling + 1e-8));
        scores.add(result.score!);
      }
      expect(scores[0], lessThan(scores[1]));
      expect(scores[1], lessThan(scores[2]));
      expect(scores[2], lessThan(scores[3]));
      expect(scores.last, greaterThan(90));
    });

    test('duration is monotonic and bounded across the supported range', () {
      var previous = -1.0;
      for (var minutes = 125.0; minutes <= 720; minutes += 5) {
        final result = _score(_night(28, total: minutes), _history());
        expect(result.score, inInclusiveRange(0, 100));
        expect(result.score! + 1e-8, greaterThanOrEqualTo(previous));
        previous = result.score!;
      }
    });

    test('85 percent efficiency is not a perfect component', () {
      final normal = _score(_night(28, total: 425, inBed: 500), _history());
      final high = _score(_night(28, total: 475, inBed: 500), _history());
      expect(
          normal.components['efficiency']['value'], closeTo(71.42857, 0.0001));
      expect(high.components['efficiency']['value'], closeTo(100, 1e-8));
    });

    test('long nights do not erase short nights in recent adequacy', () {
      final history = [
        _night(25, total: 300),
        _night(26, total: 700),
        _night(27, total: 500),
      ];
      final result = _score(_night(28), history);
      expect(result.components['recentAdequacy']['value'], closeTo(82.5, 1e-8));
    });

    test('today duration is required even when historical components exist',
        () {
      final missing = DailyWearableData(
          date: '2026-01-29',
          sleepOnsetTimestamp: DateTime.utc(2026, 1, 28, 23));
      final result = _score(missing, _history());
      expect(result.score, isNull);
      expect(result.status, ScoreStatus.insufficientData);
      for (final invalid in [double.nan, double.infinity, -1.0]) {
        expect(
            _score(_night(28, total: invalid, deep: 1, rem: 1, light: 1),
                    _history())
                .score,
            isNull);
      }
    });

    test('a late night is not diluted by thirteen regular bedtimes', () {
      final regular = _score(_night(28), _history());
      final late = _score(_night(28, shiftMinutes: 120), _history());
      expect(regular.components['circadianRegularity']['value'], 100);
      expect(
          late.components['circadianRegularity']['value'], closeTo(40, 1e-8));
      expect(late.score, lessThan(regular.score!));
    });

    test('clock comparison is circular across midnight', () {
      final late = _score(_night(28, shiftMinutes: 75),
          List.generate(28, (index) => _night(index, shiftMinutes: 45)));
      expect(
          late.components['circadianRegularity']['value'], closeTo(100, 1e-8));
    });
  });

  group('Personal stages', () {
    test('the same stages are judged against each athlete own history', () {
      final today = _night(28, deep: 30, rem: 30);
      final usual = _score(today, _history(deep: 30, rem: 30));
      final reduced = _score(today, _history());
      expect(usual.components['architecturePenaltyPoints'], 0);
      expect(reduced.components['architecturePenaltyPoints'], 8);
      expect(usual.score! - reduced.score!, closeTo(8, 1e-8));
    });

    test('extra deep sleep cannot cancel a REM deficit and vice versa', () {
      final remDeficit = _score(_night(28, deep: 175, rem: 25), _history());
      final deepDeficit = _score(_night(28, deep: 25, rem: 175), _history());
      expect(remDeficit.components['architecturePenaltyPoints'], 4);
      expect(deepDeficit.components['architecturePenaltyPoints'], 4);
      expect(
          remDeficit.components['architecture']['details']['light']
              ['penaltyPoints'],
          0);
    });

    test('normal noise and a historical outlier do not change the score', () {
      final history = [..._history().take(27), _night(27, deep: 5, rem: 5)];
      final result = _score(_night(28, deep: 95, rem: 95), history);
      expect(result.components['architecturePenaltyPoints'], 0);
      expect(
          result.components['architecture']['details']['deep']
              ['baselineMedianMinutes'],
          100);
    });

    test('composition does not penalize duration twice', () {
      final result = _score(_night(28, total: 300), _history());
      expect(result.components['architecturePenaltyPoints'], 0);
      expect(
          result.components['architecture']['details']['deep']
              ['expectedMinutesForTonight'],
          60);
    });

    test('missing light is not inferred from unclassified sleep', () {
      final missing = _score(_night(28, stages: false), _history());
      final complete = _score(_night(28), _history());
      expect(missing.components['architecture']['used'], isFalse);
      expect(missing.score, complete.score);
      expect(missing.confidence, lessThan(complete.confidence));
    });

    test('incomplete, overlapping and nonfinite stages cannot penalize', () {
      for (final night in [
        _night(28, deep: 10, rem: 10, light: 10),
        _night(28, deep: 200, rem: 200, light: 200),
        _night(28, deep: double.nan),
        _night(28, rem: double.infinity, light: 100),
        _night(28, deep: -1),
      ]) {
        final result = _score(night, _history());
        expect(result.components['architecture']['used'], isFalse);
        expect(result.components['architecturePenaltyPoints'], 0);
        expect(result.score!.isFinite, isTrue);
      }
    });

    test('seven valid nights activate partial calibration; fourteen give full',
        () {
      final today = _night(28, deep: 5, rem: 5);
      final six = _score(today, _history().skip(22).toList());
      final seven = _score(today, _history().skip(21).toList());
      final fourteen = _score(today, _history().skip(14).toList());
      expect(six.components['architecture']['used'], isFalse);
      expect(seven.components['architecturePenaltyPoints'], 4);
      expect(fourteen.components['architecturePenaltyPoints'], 8);
    });

    test('new or unknown source cannot borrow another source baseline', () {
      for (final source in ['other-watch', null]) {
        final result =
            _score(_night(28, source: source, deep: 5, rem: 5), _history());
        expect(result.components['architecture']['used'], isFalse);
        expect(result.components['architecturePenaltyPoints'], 0);
      }
      final mixedHistory = [
        ..._history().take(14),
        ...List.generate(
            14, (index) => _night(index + 14, source: 'other-watch'))
      ];
      final result = _score(_night(28, deep: 5, rem: 5), mixedHistory);
      expect(
          result.components['architecture']['details']['validBaselineNights'],
          14);
    });
  });

  group('Sleep history integrity', () {
    test('ordering, duplicates, today and future do not alter scoring', () {
      final history = _history();
      final today = _night(28);
      final clean = calculateRecoveryAndSleep(_profile, today, history);
      final noisy = calculateRecoveryAndSleep(_profile, today, [
        ...history.reversed,
        ...history.take(5),
        _night(28, total: 600),
        _night(29, total: 700)
      ]);
      expect(noisy.sleepScore.score, closeTo(clean.sleepScore.score!, 1e-8));
      expect(noisy.sleepScore.confidence, clean.sleepScore.confidence);
      expect(
          noisy.dailySleepNeed.valueMinutes, clean.dailySleepNeed.valueMinutes);
    });

    test('duplicate nights and old data cannot satisfy stage calibration', () {
      final result = _score(
          _night(60), [..._history(), ...List.generate(14, (_) => _night(59))]);
      expect(result.components['architecture']['used'], isFalse);
      expect(
          result.components['architecture']['details']['validBaselineNights'],
          1);
      expect(result.components['recentAdequacy']['used'], isFalse);
    });

    test('sparse recent history uses calendar days, not the last seven records',
        () {
      final history = [_night(0), _night(1), _night(25)];
      final result = _score(_night(28), history);
      expect(
          result.components['recentAdequacy']['details']['validDayCount'], 2);
      expect(result.components['recentAdequacy']['used'], isFalse);
      final need = calculateDailySleepNeed(_night(28), [_night(0, total: 300)],
          profile: _profile);
      expect(need.sleepDebtMinutes, 0);
    });

    test('debt decays with elapsed calendar days across missing nights', () {
      final need = calculateDailySleepNeed(_night(28), [_night(25, total: 480)],
          profile: _profile);
      expect(need.sleepDebtMinutes, closeTo(12.130613, 0.00001));
    });

    test('short habitual sleep cannot normalize chronic restriction', () {
      final history = List.generate(28, (index) => _night(index, total: 360));
      final result =
          calculateRecoveryAndSleep(_profile, _night(28, total: 360), history);
      expect(result.dailySleepNeed.personalBaselineMinutes, 500);
      expect(result.sleepScore.score, lessThan(50));
    });
  });
}

ScoreResult _score(DailyWearableData today, HistoricalDailyData history) =>
    calculateSleepScoreResult(_profile, today, history, _need);

HistoricalDailyData _history({double deep = 100, double rem = 100}) =>
    List.generate(28, (index) => _night(index, deep: deep, rem: rem));

DailyWearableData _night(
  int offset, {
  double total = 500,
  double? deep,
  double? rem,
  double? light,
  double? inBed,
  bool stages = true,
  String? source = 'watch',
  int shiftMinutes = 0,
}) {
  final day = DateTime.utc(2026, 1, 1).add(Duration(days: offset));
  final onset = day
      .subtract(const Duration(hours: 1))
      .add(Duration(minutes: shiftMinutes));
  final deepMinutes = deep ?? total * 0.2;
  final remMinutes = rem ?? total * 0.2;
  return DailyWearableData(
    date: day.toIso8601String().split('T').first,
    totalSleepTimeMinutes: total,
    deepSleepMinutes: deepMinutes,
    remSleepMinutes: remMinutes,
    lightSleepMinutes:
        stages ? light ?? total - deepMinutes - remMinutes : null,
    sleepStageSource: source,
    timeInBedMinutes: inBed ?? total + 30,
    sleepOnsetTimestamp: onset,
    sleepWakeTimestamp: onset.add(const Duration(hours: 8)),
    naps: const [],
  );
}
