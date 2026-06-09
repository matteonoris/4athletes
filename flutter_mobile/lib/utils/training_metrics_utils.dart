import '../models/models.dart';
import '../models/training_activity_models.dart';
import 'time_utils.dart';

class StrengthMetricsSummary {
  final int totalSets;
  final int totalReps;
  final double volumeKg;
  final double? averagePercent1RM;
  final Map<String, double> maxLoadByExercise;

  const StrengthMetricsSummary({
    this.totalSets = 0,
    this.totalReps = 0,
    this.volumeKg = 0,
    this.averagePercent1RM,
    this.maxLoadByExercise = const {},
  });
}

class PlyometricMetricsSummary {
  final int totalContacts;
  final int totalSets;
  final int totalReps;

  const PlyometricMetricsSummary({
    this.totalContacts = 0,
    this.totalSets = 0,
    this.totalReps = 0,
  });
}

class SpeedAgilityMetricsSummary {
  final int drillCount;
  final int totalSets;
  final int totalReps;

  const SpeedAgilityMetricsSummary({
    this.drillCount = 0,
    this.totalSets = 0,
    this.totalReps = 0,
  });
}

class EnduranceMetricsSummary {
  final int durationSeconds;
  final double distanceKm;
  final int zone23Seconds;
  final int zone45Seconds;

  const EnduranceMetricsSummary({
    this.durationSeconds = 0,
    this.distanceKm = 0,
    this.zone23Seconds = 0,
    this.zone45Seconds = 0,
  });
}

class ExtraSkiMetricsSummary {
  final int totalExtraSkiSeconds;
  final int weeklyZone23Seconds;
  final int weeklyZone45Seconds;

  const ExtraSkiMetricsSummary({
    this.totalExtraSkiSeconds = 0,
    this.weeklyZone23Seconds = 0,
    this.weeklyZone45Seconds = 0,
  });

  double get totalExtraSkiHours => totalExtraSkiSeconds / 3600;

  double get weeklyZone23Hours => weeklyZone23Seconds / 3600;

  double get weeklyZone45Hours => weeklyZone45Seconds / 3600;
}

class TrainingMetricsUtils {
  static StrengthMetricsSummary strengthSummary(
    Iterable<TrainingActivity> activities,
  ) {
    var totalSets = 0;
    var totalReps = 0;
    var volumeKg = 0.0;
    var percentTotal = 0.0;
    var percentCount = 0;
    final maxLoadByExercise = <String, double>{};

    for (final activity in _activeActivities(activities)) {
      for (final block in activity.blocks) {
        if (block.type != TrainingBlockType.strength) continue;
        for (final exercise in block.exercises) {
          for (final set in exercise.sets) {
            final kg = set.kg ?? 0;
            final reps = set.reps ?? 0;
            if (kg <= 0 && reps <= 0) continue;
            totalSets++;
            totalReps += reps;
            volumeKg += set.volumeKg;
            if (set.percent1RM != null) {
              percentTotal += set.percent1RM!;
              percentCount++;
            }
            if (kg > 0) {
              final key = exercise.exerciseId.isNotEmpty
                  ? exercise.exerciseId
                  : exercise.name;
              final previous = maxLoadByExercise[key] ?? 0;
              if (kg > previous) maxLoadByExercise[key] = kg;
            }
          }
        }
      }
    }

    return StrengthMetricsSummary(
      totalSets: totalSets,
      totalReps: totalReps,
      volumeKg: volumeKg,
      averagePercent1RM: percentCount == 0 ? null : percentTotal / percentCount,
      maxLoadByExercise: maxLoadByExercise,
    );
  }

  static PlyometricMetricsSummary plyometricSummary(
    Iterable<TrainingActivity> activities,
  ) {
    var totalContacts = 0;
    var totalSets = 0;
    var totalReps = 0;

    for (final activity in _activeActivities(activities)) {
      for (final block in activity.blocks) {
        if (block.type != TrainingBlockType.plyometrics) continue;
        for (final entry in block.plyometrics) {
          totalSets += entry.sets.length;
          totalReps += entry.totalReps;
          totalContacts += entry.totalContacts;
        }
      }
    }

    return PlyometricMetricsSummary(
      totalContacts: totalContacts,
      totalSets: totalSets,
      totalReps: totalReps,
    );
  }

  static SpeedAgilityMetricsSummary speedAgilitySummary(
    Iterable<TrainingActivity> activities,
  ) {
    var drillCount = 0;
    var totalSets = 0;
    var totalReps = 0;

    for (final activity in _activeActivities(activities)) {
      for (final block in activity.blocks) {
        if (block.type != TrainingBlockType.speedAgility) continue;
        for (final drill in block.drills) {
          drillCount++;
          totalSets += drill.sets ?? 0;
          totalReps += (drill.sets ?? 1) * (drill.reps ?? 0);
        }
      }
    }

    return SpeedAgilityMetricsSummary(
      drillCount: drillCount,
      totalSets: totalSets,
      totalReps: totalReps,
    );
  }

  static EnduranceMetricsSummary enduranceSummary(
    Iterable<TrainingActivity> activities,
  ) {
    var durationSeconds = 0;
    var distanceKm = 0.0;
    var zone23Seconds = 0;
    var zone45Seconds = 0;

    for (final activity in _activeActivities(activities)) {
      for (final block in activity.blocks) {
        if (block.type != TrainingBlockType.endurance) continue;
        final endurance = block.endurance;
        if (endurance == null) continue;
        durationSeconds += endurance.durationSeconds ??
            TimeUtils.parseDurationToMinutes(activity.duration) * 60;
        distanceKm += endurance.distanceKm ?? 0;
        zone23Seconds += endurance.zone23Seconds;
        zone45Seconds += endurance.zone45Seconds;
      }
    }

    return EnduranceMetricsSummary(
      durationSeconds: durationSeconds,
      distanceKm: distanceKm,
      zone23Seconds: zone23Seconds,
      zone45Seconds: zone45Seconds,
    );
  }

  static ExtraSkiMetricsSummary extraSkiSummaryFromSessions(
    Iterable<TrainingSession> sessions, {
    DateTime? weekAnchor,
  }) {
    final anchor = weekAnchor ?? DateTime.now();
    final weekStart = _startOfWeek(anchor);
    final weekEnd = weekStart.add(const Duration(days: 7));
    var totalExtraSkiSeconds = 0;
    var weeklyZone23Seconds = 0;
    var weeklyZone45Seconds = 0;

    for (final session in sessions) {
      if (_isSkiSport(session.sportId)) continue;
      final durationSeconds =
          TimeUtils.parseDurationToMinutes(session.duration) * 60;
      totalExtraSkiSeconds += durationSeconds;

      final date = DateTime.tryParse(session.date);
      if (date == null || date.isBefore(weekStart) || !date.isBefore(weekEnd)) {
        continue;
      }

      final activity = TrainingActivity.fromTrainingSession(session);
      final endurance = enduranceSummary([activity]);
      weeklyZone23Seconds += endurance.zone23Seconds;
      weeklyZone45Seconds += endurance.zone45Seconds;
    }

    return ExtraSkiMetricsSummary(
      totalExtraSkiSeconds: totalExtraSkiSeconds,
      weeklyZone23Seconds: weeklyZone23Seconds,
      weeklyZone45Seconds: weeklyZone45Seconds,
    );
  }

  static StrengthMetricsSummary strengthSummaryFromSessions(
    Iterable<TrainingSession> sessions,
  ) {
    return strengthSummary(
      sessions.map((session) => TrainingActivity.fromTrainingSession(session)),
    );
  }

  static EnduranceMetricsSummary enduranceSummaryFromSessions(
    Iterable<TrainingSession> sessions,
  ) {
    return enduranceSummary(
      sessions.map((session) => TrainingActivity.fromTrainingSession(session)),
    );
  }

  static Iterable<TrainingActivity> _activeActivities(
    Iterable<TrainingActivity> activities,
  ) {
    return activities.where(
      (activity) => activity.status != ActivityStatus.cancelled,
    );
  }

  static bool _isSkiSport(String sportId) {
    return sportId == 'alpine_skiing' ||
        sportId == 'ski' ||
        sportId == 'skiing' ||
        sportId == 'snowboarding';
  }

  static DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }
}
