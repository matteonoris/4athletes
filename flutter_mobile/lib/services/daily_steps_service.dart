import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:health/health.dart';

import '../models/models.dart';
import '../utils/scoring/scoring_types.dart';
import 'health_read_guard.dart';

/// Uses the platform aggregate, rather than summing phone/watch raw records.
abstract class DailyStepsSource {
  String get name;
  Future<void> configure();
  Future<bool?> hasReadPermission();
  Future<int?> count(DateTime start, DateTime end);
}

class _PlatformStepsSource implements DailyStepsSource {
  final Health _health = Health();
  @override
  String get name => Platform.isIOS ? 'apple_health' : 'health_connect';
  @override
  Future<void> configure() => _health.configure();
  @override
  Future<bool?> hasReadPermission() => Platform.isIOS
      // HealthKit deliberately does not disclose read authorization.
      ? Future.value(null)
      : _health.hasPermissions([HealthDataType.STEPS],
          permissions: [HealthDataAccess.READ]);
  @override
  Future<int?> count(DateTime start, DateTime end) async {
    final value = await _health.getTotalStepsInInterval(start, end);
    // HealthKit's empty result also represents denied read access.
    return Platform.isIOS && value == 0 ? null : value;
  }
}

class StepInterval {
  final DateTime start;
  final DateTime end;
  const StepInterval(this.start, this.end);
}

class DailyStepsPlan {
  final DateTime start;
  final DateTime end;
  final List<StepInterval> outsideWorkouts;
  final bool hasUnknownWorkoutTimes;
  final String exclusionKey;

  DailyStepsPlan._(this.start, this.end, this.outsideWorkouts,
      this.hasUnknownWorkoutTimes, this.exclusionKey);

  factory DailyStepsPlan.forDay(DateTime date, DateTime observedUntil,
      Iterable<WorkoutSessionInput> sessions) {
    final local = date.toLocal();
    final start = DateTime(local.year, local.month, local.day);
    final nextDay = DateTime(local.year, local.month, local.day + 1);
    final end = observedUntil.isBefore(nextDay) ? observedUntil : nextDay;
    final intervals = <StepInterval>[];
    final unknown = <String>[];
    final dateKey = _dateKey(start);
    for (final session in sessions) {
      final sessionStart = _sessionTime(session.date, session.startTime);
      var sessionEnd = _sessionTime(session.date, session.endTime);
      if (sessionStart == null || sessionEnd == null) {
        if (session.date == dateKey) unknown.add(session.id);
        continue;
      }
      if (!sessionEnd.isAfter(sessionStart)) {
        // Clock-only end times may cross midnight; full timestamps may not.
        if (_clock.hasMatch(session.endTime ?? '') &&
            sessionEnd.isBefore(sessionStart)) {
          sessionEnd = DateTime(
              sessionEnd.year,
              sessionEnd.month,
              sessionEnd.day + 1,
              sessionEnd.hour,
              sessionEnd.minute,
              sessionEnd.second);
        } else {
          if (session.date == dateKey) unknown.add(session.id);
          continue;
        }
      }
      if (!sessionEnd.isAfter(start) || !sessionStart.isBefore(end)) continue;
      intervals.add(StepInterval(
          sessionStart.isBefore(start) ? start : sessionStart,
          sessionEnd.isAfter(end) ? end : sessionEnd));
    }
    intervals.sort((a, b) => a.start.compareTo(b.start));
    final merged = <StepInterval>[];
    for (final interval in intervals) {
      if (merged.isNotEmpty && !interval.start.isAfter(merged.last.end)) {
        final previous = merged.removeLast();
        merged.add(StepInterval(previous.start,
            interval.end.isAfter(previous.end) ? interval.end : previous.end));
      } else {
        merged.add(interval);
      }
    }
    final gaps = <StepInterval>[];
    var cursor = start;
    for (final interval in merged) {
      if (interval.start.isAfter(cursor)) {
        gaps.add(StepInterval(cursor, interval.start));
      }
      cursor = interval.end;
    }
    if (end.isAfter(cursor)) gaps.add(StepInterval(cursor, end));
    unknown.sort();
    final key = sha256
        .convert(utf8.encode(jsonEncode({
          'excluded': [
            for (final i in merged)
              [i.start.millisecondsSinceEpoch, i.end.millisecondsSinceEpoch]
          ],
          'unknown': unknown,
        })))
        .toString();
    return DailyStepsPlan._(start, end, gaps, unknown.isNotEmpty, key);
  }
}

class DailyStepsSnapshot {
  final String date;
  final int totalSteps;
  final int? outsideWorkoutSteps;
  final String source;
  final DateTime observedUntil;
  final String exclusionKey;

  const DailyStepsSnapshot(
      {required this.date,
      required this.totalSteps,
      required this.outsideWorkoutSteps,
      required this.source,
      required this.observedUntil,
      required this.exclusionKey});

  BodyMetricLog toLog() => BodyMetricLog(
          id: 'daily_steps_$date',
          date: date,
          type: 'daily_steps',
          value: totalSteps.toDouble(),
          metadata: {
            'schema_version': 1,
            'source': source,
            'outside_workout_steps': outsideWorkoutSteps,
            'observed_until': observedUntil.toUtc().toIso8601String(),
            'exclusion_key': exclusionKey,
          });

  static DailyStepsSnapshot? fromLog(BodyMetricLog? log) {
    if (log == null ||
        log.type != 'daily_steps' ||
        !log.value.isFinite ||
        log.value < 0 ||
        log.value > 200000 ||
        log.metadata['schema_version'] != 1) {
      return null;
    }
    final observed =
        DateTime.tryParse(log.metadata['observed_until']?.toString() ?? '');
    final day = DateTime.tryParse(log.date);
    final outside = log.metadata['outside_workout_steps'];
    if (observed == null ||
        day == null ||
        observed.isBefore(DateTime(day.year, day.month, day.day)) ||
        observed.isAfter(DateTime(day.year, day.month, day.day + 1)) ||
        (outside != null &&
            (outside is! num ||
                !outside.isFinite ||
                outside < 0 ||
                outside > log.value))) {
      return null;
    }
    return DailyStepsSnapshot(
        date: log.date,
        totalSteps: log.value.round(),
        outsideWorkoutSteps: (outside as num?)?.round(),
        source: log.metadata['source']?.toString() ?? 'unknown',
        observedUntil: observed.toLocal(),
        exclusionKey: log.metadata['exclusion_key']?.toString() ?? '');
  }

  DailyMovementInput forSessions(Iterable<WorkoutSessionInput> sessions) {
    final day = DateTime.parse(date);
    final plan = DailyStepsPlan.forDay(day, observedUntil, sessions);
    final unchanged = plan.exclusionKey == exclusionKey;
    return DailyMovementInput(
        totalSteps: totalSteps,
        outsideWorkoutSteps: unchanged ? outsideWorkoutSteps : null,
        isPartialDay:
            observedUntil.isBefore(DateTime(day.year, day.month, day.day + 1)),
        unavailableReason: !unchanged
            ? 'daily_steps_workouts_changed'
            : outsideWorkoutSteps == null
                ? 'daily_steps_exclusion_unavailable'
                : null);
  }
}

class DailyStepsService {
  final DailyStepsSource _source;
  DailyStepsService({DailyStepsSource? source})
      : _source = source ?? _PlatformStepsSource();

  Future<DailyStepsSnapshot?> fetchDay(
      DateTime date, Iterable<WorkoutSessionInput> sessions,
      {DateTime? now}) async {
    if (!healthReadAllowed) return null;
    final observed = now ?? DateTime.now();
    final local = date.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(observed.year, observed.month, observed.day);
    // Avoid the default Health Connect history boundary without extra access.
    if (day.isAfter(today) ||
        day.isBefore(DateTime(today.year, today.month, today.day - 28))) {
      return null;
    }
    final plan = DailyStepsPlan.forDay(day, observed, sessions);
    if (!plan.end.isAfter(plan.start)) return null;
    try {
      await _source.configure();
      if (!healthReadAllowed) return null;
      final permission = await _source.hasReadPermission();
      if (!healthReadAllowed || permission == false) return null;
      final total = await _source.count(plan.start, plan.end);
      if (!healthReadAllowed || total == null || total < 0 || total > 200000) {
        return null;
      }
      int? outside;
      if (!plan.hasUnknownWorkoutTimes) {
        if (plan.outsideWorkouts.length == 1 &&
            plan.outsideWorkouts.single.start == plan.start &&
            plan.outsideWorkouts.single.end == plan.end) {
          outside = total;
        } else {
          outside = 0;
          for (final interval in plan.outsideWorkouts) {
            if (!healthReadAllowed) return null;
            final count = await _source.count(interval.start, interval.end);
            if (!healthReadAllowed) return null;
            if (count == null || count < 0 || count > 200000) {
              outside = null;
              break;
            }
            outside = outside! + count;
          }
          // Independent interval aggregates can differ slightly by rounding.
          if (outside != null) outside = math.min(total, outside);
        }
      }
      return healthReadAllowed
          ? DailyStepsSnapshot(
              date: _dateKey(day),
              totalSteps: total,
              outsideWorkoutSteps: outside,
              source: _source.name,
              observedUntil: plan.end,
              exclusionKey: plan.exclusionKey)
          : null;
    } catch (_) {
      // An unavailable/denied source must not become an observed zero.
      return null;
    }
  }
}

final _clock = RegExp(r'^\d{2}:\d{2}(:\d{2})?$');
DateTime? _sessionTime(String date, String? value) {
  if (value == null) return null;
  if (_clock.hasMatch(value)) {
    final day = DateTime.tryParse(date);
    final parts = value.split(':').map(int.parse).toList();
    if (day == null ||
        parts[0] > 23 ||
        parts[1] > 59 ||
        (parts.length > 2 && parts[2] > 59)) {
      return null;
    }
    return DateTime(day.year, day.month, day.day, parts[0], parts[1],
        parts.length > 2 ? parts[2] : 0);
  }
  return DateTime.tryParse(value)?.toLocal();
}

String _dateKey(DateTime date) => date.toIso8601String().split('T').first;
