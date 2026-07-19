import 'dart:math' as math;

import 'package:flutter_mobile/utils/metrics_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const adult = AthleteProfile(
    athleteId: 'adult-athlete',
    ageYears: 25,
    timezone: 'Europe/Rome',
  );
  const adolescent = AthleteProfile(
    athleteId: 'adolescent-athlete',
    ageYears: 17,
    timezone: 'Europe/Rome',
  );

  group('Sleep need v2', () {
    test('observed baseline never lowers the age target', () {
      final adultHistory = List.generate(
        14,
        (index) => _day(index, totalSleepMinutes: 360),
      );
      final adolescentHistory = List.generate(
        14,
        (index) => _day(index, totalSleepMinutes: 480),
      );

      final adultBaseline = calculatePersonalBaseline(
        adultHistory,
        profile: adult,
      );
      final adolescentBaseline = calculatePersonalBaseline(
        adolescentHistory,
        profile: adolescent,
      );

      expect(adultBaseline.valueMinutes, 500);
      expect(adolescentBaseline.valueMinutes, 540);
      expect(adultBaseline.validNights, 14);
      expect(adolescentBaseline.validNights, 14);
    });

    test('75th percentile can raise but not lower the target', () {
      final history = List.generate(
        14,
        (index) => _day(index, totalSleepMinutes: 560),
      );

      final baseline = calculatePersonalBaseline(history, profile: adult);

      expect(baseline.valueMinutes, 560);
    });

    test('calibration counts valid nights rather than placeholder records', () {
      final history = List.generate(
        28,
        (index) => _day(
          index,
          totalSleepMinutes: index < 22 ? null : 480,
        ),
      );

      final baseline = calculatePersonalBaseline(history, profile: adult);
      final need = calculateDailySleepNeed(
        _day(28, totalSleepMinutes: 500),
        history,
        profile: adult,
      );

      expect(baseline.validNights, 6);
      expect(baseline.valueMinutes, 500);
      expect(
        need.warnings,
        contains('sleep_need_history_below_minimum_valid_nights'),
      );
    });

    test('nap sleep increases 24h actual but does not lower sleep need', () {
      final history = List.generate(
        14,
        (index) => _day(index, totalSleepMinutes: 500),
      );
      final napStart = DateTime(2026, 1, 15, 13);
      final withNap = _day(
        14,
        totalSleepMinutes: 440,
        naps: [
          Nap(
            startTimestamp: napStart,
            endTimestamp: napStart.add(const Duration(minutes: 60)),
            durationMinutes: 60,
          ),
        ],
      );
      final withoutNap = _day(14, totalSleepMinutes: 440);

      final needWithNap = calculateDailySleepNeed(
        withNap,
        history,
        profile: adult,
      );
      final needWithoutNap = calculateDailySleepNeed(
        withoutNap,
        history,
        profile: adult,
      );
      final scoreWithNap = calculateSleepScoreResult(
        adult,
        withNap,
        history,
        needWithNap,
      );
      final scoreWithoutNap = calculateSleepScoreResult(
        adult,
        withoutNap,
        history,
        needWithoutNap,
      );
      final durationWithNap =
          scoreWithNap.components['duration'] as Map<String, dynamic>;
      final durationWithoutNap =
          scoreWithoutNap.components['duration'] as Map<String, dynamic>;

      expect(needWithNap.valueMinutes, needWithoutNap.valueMinutes);
      expect(needWithNap.napsDeductionMinutes, 60);
      expect(durationWithNap['value'], 100);
      expect(durationWithNap['details']['totalSleep24hMinutes'], 500);
      expect(durationWithoutNap['value'], closeTo(88, 0.000001));
    });

    test('signed balance lets a recent surplus repay an older deficit', () {
      final history = [
        _day(0, totalSleepMinutes: 440),
        _day(1, totalSleepMinutes: 560),
      ];

      final balance = calculateSleepDebt(history, profile: adult);
      final need = calculateDailySleepNeed(
        _day(2, totalSleepMinutes: 500),
        history,
        profile: adult,
      );
      final expected = 60 * math.exp(-0.25) - 60;

      expect(balance.usedDays, 2);
      expect(balance.valueMinutes, closeTo(expected, 0.000001));
      expect(balance.valueMinutes, lessThan(0));
      expect(need.sleepDebtMinutes, closeTo(expected, 0.000001));
      expect(need.valueMinutes, 500);
    });

    test('scoring engine passes athlete age into sleep need', () {
      final history = List.generate(
        14,
        (index) => _day(index, totalSleepMinutes: 540),
      );

      final result = calculateRecoveryAndSleep(
        adolescent,
        _day(14, totalSleepMinutes: 540),
        history,
      );

      expect(result.dailySleepNeed.personalBaselineMinutes, 540);
    });
  });

  group('Sleep score v2', () {
    test('recent adequacy uses seven days and requires at least three', () {
      final twoHistoryDays = [
        _day(0, totalSleepMinutes: 500),
        _day(1, totalSleepMinutes: 500),
      ];
      final today = _day(2, totalSleepMinutes: 500);
      final need = calculateDailySleepNeed(
        today,
        twoHistoryDays,
        profile: adult,
      );
      final score = calculateSleepScoreResult(
        adult,
        today,
        twoHistoryDays,
        need,
      );
      final recent = score.components['recentAdequacy'] as Map<String, dynamic>;

      expect(recent['used'], isTrue);
      expect(recent['value'], 100);
      expect(recent['details']['validDayCount'], 3);
      expect(recent['details']['windowDays'], 7);

      final shortHistory = [_day(0, totalSleepMinutes: 500)];
      final shortNeed = calculateDailySleepNeed(
        _day(1, totalSleepMinutes: 500),
        shortHistory,
        profile: adult,
      );
      final shortScore = calculateSleepScoreResult(
        adult,
        _day(1, totalSleepMinutes: 500),
        shortHistory,
        shortNeed,
      );
      final unavailable =
          shortScore.components['recentAdequacy'] as Map<String, dynamic>;

      expect(unavailable['used'], isFalse);
      expect(
        unavailable['warning'],
        'recent_sleep_adequacy_insufficient_valid_days',
      );
    });

    test('recent adequacy excludes days older than its seven-day window', () {
      final history = List.generate(
        10,
        (index) => _day(
          index,
          totalSleepMinutes: index < 4 ? 200 : 500,
        ),
      );
      final today = _day(10, totalSleepMinutes: 500);
      final need = calculateDailySleepNeed(today, history, profile: adult);

      final score = calculateSleepScoreResult(
        adult,
        today,
        history,
        need,
      );
      final recent = score.components['recentAdequacy'] as Map<String, dynamic>;

      expect(recent['value'], 100);
      expect(recent['details']['validDayCount'], 7);
      expect(recent['details']['totalActualSleep24hMinutes'], 3500);
    });

    test('efficiency is normalized between configured floor and target', () {
      final targetEfficiencyDay = _day(
        0,
        totalSleepMinutes: 425,
        timeInBedMinutes: 500,
      );
      final floorEfficiencyDay = _day(
        0,
        totalSleepMinutes: 300,
        timeInBedMinutes: 500,
      );

      final targetScore = calculateSleepScoreResult(
        adult,
        targetEfficiencyDay,
        const [],
        _fixedNeed(500),
      );
      final floorScore = calculateSleepScoreResult(
        adult,
        floorEfficiencyDay,
        const [],
        _fixedNeed(500),
      );
      final targetComponent =
          targetScore.components['efficiency'] as Map<String, dynamic>;
      final floorComponent =
          floorScore.components['efficiency'] as Map<String, dynamic>;

      expect(targetComponent['value'], closeTo(100, 0.000001));
      expect(floorComponent['value'], closeTo(0, 0.000001));
      expect(targetComponent['details']['efficiencyTarget'], 0.85);
      expect(targetComponent['details']['efficiencyFloor'], 0.60);
    });

    test('architecture is informational and cannot alter the score', () {
      final history = List.generate(
        14,
        (index) => _day(index, totalSleepMinutes: 500),
      );
      final today = _day(
        14,
        totalSleepMinutes: 500,
        deepSleepMinutes: 100,
        remSleepMinutes: 100,
      );
      final alternateStages = _day(
        14,
        totalSleepMinutes: 500,
        deepSleepMinutes: 10,
        remSleepMinutes: 10,
      );
      final need = calculateDailySleepNeed(today, history, profile: adult);

      final score = calculateSleepScoreResult(
        adult,
        today,
        history,
        need,
      );
      final alternateScore = calculateSleepScoreResult(
        adult,
        alternateStages,
        history,
        need,
      );
      final architecture =
          score.components['architecture'] as Map<String, dynamic>;

      expect(score.score, closeTo(alternateScore.score!, 0.000001));
      expect(architecture['used'], isFalse);
      expect(architecture['informationalOnly'], isTrue);
      expect(architecture['weight'], 0);
    });

    test('regularity is limited to the configured fourteen-day window', () {
      final history = List.generate(
        20,
        (index) => _day(index, totalSleepMinutes: 500),
      );
      final today = _day(20, totalSleepMinutes: 500);
      final need = calculateDailySleepNeed(today, history, profile: adult);

      final score = calculateSleepScoreResult(
        adult,
        today,
        history,
        need,
      );
      final regularity =
          score.components['circadianRegularity'] as Map<String, dynamic>;

      expect(regularity['details']['windowNightCount'], 14);
      expect(regularity['details']['windowDays'], 14);
    });
  });
}

DailyWearableData _day(
  int offset, {
  required double? totalSleepMinutes,
  double? timeInBedMinutes,
  double? deepSleepMinutes = 100,
  double? remSleepMinutes = 100,
  List<Nap>? naps,
}) {
  final date = DateTime(2026, 1, 1).add(Duration(days: offset));
  final onset = DateTime(date.year, date.month, date.day, 23);
  return DailyWearableData(
    date: date.toIso8601String().split('T').first,
    totalSleepTimeMinutes: totalSleepMinutes,
    deepSleepMinutes: deepSleepMinutes,
    remSleepMinutes: remSleepMinutes,
    timeInBedMinutes: timeInBedMinutes ??
        (totalSleepMinutes == null ? null : totalSleepMinutes + 30),
    sleepOnsetTimestamp: onset,
    sleepWakeTimestamp: onset.add(const Duration(hours: 8)),
    naps: naps ?? const [],
  );
}

DailySleepNeedResult _fixedNeed(double valueMinutes) {
  return DailySleepNeedResult(
    valueMinutes: valueMinutes,
    personalBaselineMinutes: valueMinutes,
    sleepDebtMinutes: 0,
    dailyStrainAdjustmentMinutes: 0,
    napsDeductionMinutes: 0,
    confidence: 1,
    warnings: const [],
  );
}
