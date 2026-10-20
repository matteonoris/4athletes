import 'dart:async';

import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/services/daily_steps_service.dart';
import 'package:flutter_mobile/services/health_read_guard.dart';
import 'package:flutter_mobile/utils/scoring/scoring_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 10, 18);
  final now = DateTime(2026, 10, 19, 12);
  Future<DailyStepsSnapshot?> fetch(_Steps source,
          [List<WorkoutSessionInput> sessions = const []]) =>
      withHealthReadConsent(
          () => true,
          () => DailyStepsService(source: source)
              .fetchDay(date, sessions, now: now));

  test('aggregates the day once when there are no workouts', () async {
    final source = _Steps([12000]);
    final result = await fetch(source);
    expect(result!.totalSteps, 12000);
    expect(result.outsideWorkoutSteps, 12000);
    expect(source.intervals.single.start, date);
    expect(source.intervals.single.end, DateTime(2026, 10, 19));
  });

  test('queries only the complement of merged overlapping workouts', () async {
    final source = _Steps([15000, 2000, 3000]);
    final result = await fetch(source, [
      _workout('a', '10:00', '11:00'),
      _workout('b', '10:30', '12:00'),
    ]);
    expect(result!.outsideWorkoutSteps, 5000);
    expect(source.intervals, hasLength(3));
    expect(source.intervals[1].end, DateTime(2026, 10, 18, 10));
    expect(source.intervals[2].start, DateTime(2026, 10, 18, 12));
  });

  test('a workout from yesterday crossing midnight is excluded', () async {
    final source = _Steps([9000, 8000]);
    await fetch(
        source, [_workout('night', '23:00', '01:00', date: '2026-10-17')]);
    expect(source.intervals[1].start, DateTime(2026, 10, 18, 1));
  });

  test('unknown workout times retain the total without inventing outside steps',
      () async {
    final source = _Steps([12000]);
    final result = await fetch(source, [_workout('unknown', null, null)]);
    expect(result!.totalSteps, 12000);
    expect(result.outsideWorkoutSteps, isNull);
    expect(source.intervals, hasLength(1));
  });

  test('today ends at observation time, not at a future midnight', () async {
    final source = _Steps([5000]);
    final result = await withHealthReadConsent(() => true,
        () => DailyStepsService(source: source).fetchDay(now, [], now: now));
    expect(result!.observedUntil, now);
    expect(source.intervals.single.end, now);
    expect(result.forSessions([]).isPartialDay, isTrue);
  });

  test('missing permission does not query counts or create a zero', () async {
    final source = _Steps([0])..permission = false;
    expect(await fetch(source), isNull);
    expect(source.intervals, isEmpty);
  });

  test('observed zero differs from missing and invalid aggregate', () async {
    expect((await fetch(_Steps([0])))!.totalSteps, 0);
    for (final value in [null, -1, 200001]) {
      expect(await fetch(_Steps([value])), isNull);
    }
  });

  test('a failed outside-workout query does not use total steps as a fallback',
      () async {
    final result =
        await fetch(_Steps([10000, null]), [_workout('run', '10:00', '11:00')]);
    expect(result!.totalSteps, 10000);
    expect(result.outsideWorkoutSteps, isNull);
  });

  test('without consent there are no platform calls', () async {
    final source = _Steps([10000]);
    expect(await DailyStepsService(source: source).fetchDay(date, [], now: now),
        isNull);
    expect(source.configurations, 0);
  });

  test('revocation/account change while awaiting counts discards the result',
      () async {
    var allowed = true;
    final pending = Completer<int?>();
    final source = _Steps([])..pending = pending;
    final read = withHealthReadConsent(() => allowed,
        () => DailyStepsService(source: source).fetchDay(date, [], now: now));
    await source.started.future;
    allowed = false;
    pending.complete(10000);
    expect(await read, isNull);
  });

  test(
      'snapshot metadata survives reload and detects changed workout intervals',
      () async {
    final workouts = [_workout('run', '10:00', '11:00')];
    final snapshot = (await fetch(_Steps([12000, 3000, 5000]), workouts))!;
    final restored = DailyStepsSnapshot.fromLog(
        BodyMetricLog.fromJson(snapshot.toLog().toJson()))!;
    expect(restored.forSessions(workouts).outsideWorkoutSteps, 8000);
    final changed = restored.forSessions([_workout('run', '09:00', '11:00')]);
    expect(changed.totalSteps, 12000);
    expect(changed.outsideWorkoutSteps, isNull);
    expect(changed.unavailableReason, 'daily_steps_workouts_changed');
  });

  test('interval rounding cannot make outside count exceed the daily count',
      () async {
    final result =
        await fetch(_Steps([100, 70, 70]), [_workout('run', '10:00', '11:00')]);
    expect(result!.outsideWorkoutSteps, 100);
  });
}

WorkoutSessionInput _workout(String id, String? start, String? end,
        {String date = '2026-10-18'}) =>
    WorkoutSessionInput(
        id: id,
        athleteId: 'athlete',
        date: date,
        startTime: start,
        endTime: end,
        sportType: 'running',
        durationMinutes: 60);

class _Steps implements DailyStepsSource {
  _Steps(this.values);
  final List<int?> values;
  final intervals = <StepInterval>[];
  final started = Completer<void>();
  Completer<int?>? pending;
  bool? permission = true;
  int configurations = 0;
  @override
  String get name => 'synthetic';
  @override
  Future<void> configure() async {
    configurations++;
  }

  @override
  Future<bool?> hasReadPermission() async => permission;
  @override
  Future<int?> count(DateTime start, DateTime end) {
    intervals.add(StepInterval(start, end));
    if (!started.isCompleted) started.complete();
    return pending?.future ?? Future.value(values.removeAt(0));
  }
}
