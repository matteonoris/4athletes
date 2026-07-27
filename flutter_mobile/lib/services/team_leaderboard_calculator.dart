import '../models/models.dart';
import '../models/training_activity_models.dart';
import '../utils/coach_training_utils.dart';
import '../utils/time_utils.dart';
import '../utils/training_metrics_utils.dart';

enum TeamLeaderboardTimeRange {
  last7Days('Last 7 Days'),
  thisMonth('This Month'),
  thisSeason('This Season');

  final String label;

  const TeamLeaderboardTimeRange(this.label);
}

enum TeamLeaderboardMetric {
  hoursOutsideAlpineSki('Ore', 'h'),
  totalDirectionChanges('Tot. Dir', ''),
  slPolePasses('Pass. SL', ''),
  gsPolePasses('Pass. GS', ''),
  sgPolePasses('Pass. SG', ''),
  dhPolePasses('Pass. DH', ''),
  sxPolePasses('Pass. SX', ''),
  enduranceHours('Ore Res.', 'h'),
  zone23Hours('Z2-3', 'h'),
  zone45Hours('Z4-5', 'h'),
  strengthVolumeKg('Vol. Kg', 'kg'),
  plyometricContacts('Contatti', ''),
  strengthSessions('Sed. Forza', 'sess'),
  enduranceSessions('Sed. End.', 'sess');

  final String label;
  final String unit;

  const TeamLeaderboardMetric(this.label, this.unit);
}

class TeamLeaderboardPeriod {
  final DateTime start;
  final DateTime endExclusive;

  const TeamLeaderboardPeriod({
    required this.start,
    required this.endExclusive,
  });

  factory TeamLeaderboardPeriod.forRange(
    TeamLeaderboardTimeRange range,
    DateTime referenceDate,
  ) {
    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final start = switch (range) {
      TeamLeaderboardTimeRange.last7Days =>
        today.subtract(const Duration(days: 6)),
      TeamLeaderboardTimeRange.thisMonth =>
        DateTime(today.year, today.month, 1),
      TeamLeaderboardTimeRange.thisSeason => DateTime(
          today.year - (today.month < DateTime.may ? 1 : 0),
          DateTime.may,
          1,
        ),
    };
    return TeamLeaderboardPeriod(
      start: start,
      endExclusive: today.add(const Duration(days: 1)),
    );
  }

  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(endExclusive);
}

class TeamLeaderboardAthleteStats {
  final String id;
  final String name;
  final String avatarUrl;
  final String subtitle;
  final Map<TeamLeaderboardMetric, double> _values;

  const TeamLeaderboardAthleteStats({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.subtitle,
    required Map<TeamLeaderboardMetric, double> values,
  }) : _values = values;

  double valueFor(TeamLeaderboardMetric metric) => _values[metric] ?? 0;
}

class TeamLeaderboardSession {
  final String athleteId;
  final TrainingSession session;

  const TeamLeaderboardSession({
    required this.athleteId,
    required this.session,
  });
}

typedef TeamLeaderboardPageFetcher<T> = Future<List<T>> Function(
  int from,
  int to,
);

class TeamLeaderboardPagination {
  const TeamLeaderboardPagination._();

  static Future<List<T>> fetchAll<T>({
    required TeamLeaderboardPageFetcher<T> fetchPage,
    int pageSize = 500,
  }) async {
    if (pageSize <= 0) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Must be positive');
    }
    final results = <T>[];
    var offset = 0;

    while (true) {
      final page = await fetchPage(offset, offset + pageSize - 1);
      results.addAll(page);
      if (page.length < pageSize) break;
      offset += page.length;
    }

    return results;
  }
}

class TeamLeaderboardCalculator {
  const TeamLeaderboardCalculator();

  static const _alpineSkiSportIds = {
    'alpine_skiing',
    'alpine_ski',
    'downhill_skiing',
    'downhill_ski',
    'ski',
    'skiing',
    'snow_sports',
    'snow_sport',
    'snowsports',
    'snowboarding',
  };

  static const _enduranceSportIds = {
    'running',
    'road_running',
    'trail_running',
    'running_treadmill',
    'track_field',
    'track_and_field',
    'marathon',
    'cycling',
    'road_cycling',
    'mountain_biking',
    'spinning',
    'swimming',
    'rowing',
    'hiking',
    'walking',
    'cross_country_skiing',
    'triathlon',
    'dryland_endurance',
    'mixed_cardio',
  };

  List<TeamLeaderboardAthleteStats> calculate({
    required Iterable<Map<String, dynamic>> athletes,
    required Iterable<TeamLeaderboardSession> sessions,
    required TeamLeaderboardTimeRange timeRange,
    DateTime? referenceDate,
  }) {
    final period = TeamLeaderboardPeriod.forRange(
      timeRange,
      referenceDate ?? DateTime.now(),
    );
    final sessionsByAthlete = <String, List<TrainingSession>>{};
    for (final entry in sessions) {
      if (entry.athleteId.isEmpty) continue;
      sessionsByAthlete
          .putIfAbsent(entry.athleteId, () => [])
          .add(entry.session);
    }

    return athletes.map((athlete) {
      final athleteId = athlete['id']?.toString() ?? '';
      final accumulator = _LeaderboardAccumulator();
      for (final session
          in sessionsByAthlete[athleteId] ?? const <TrainingSession>[]) {
        _addSession(accumulator, session, period);
      }

      final name =
          '${athlete['first_name'] ?? ''} ${athlete['last_name'] ?? ''}'.trim();
      return TeamLeaderboardAthleteStats(
        id: athleteId,
        name: name.isEmpty ? 'Atleta' : name,
        avatarUrl: athlete['avatar_url']?.toString() ?? '',
        subtitle: athlete['skill_level']?.toString() ?? 'Athlete',
        values: accumulator.values,
      );
    }).toList();
  }

  void _addSession(
    _LeaderboardAccumulator accumulator,
    TrainingSession session,
    TeamLeaderboardPeriod period,
  ) {
    final date = DateTime.tryParse(session.date);
    if (date == null || !period.contains(date)) return;

    final activity = TrainingActivity.fromTrainingSession(session);
    if (activity.status != ActivityStatus.completed) return;

    if (_isAlpineSkiing(session.sportId)) {
      final volume = CoachTrainingUtils.volumeFromDetails(session.details);
      accumulator.add(
        TeamLeaderboardMetric.totalDirectionChanges,
        volume.totalDirectionChanges.toDouble(),
      );
      accumulator.add(
        TeamLeaderboardMetric.slPolePasses,
        (volume.polePassesBySpecialty['SL'] ?? 0).toDouble(),
      );
      accumulator.add(
        TeamLeaderboardMetric.gsPolePasses,
        (volume.polePassesBySpecialty['GS'] ?? 0).toDouble(),
      );
      accumulator.add(
        TeamLeaderboardMetric.sgPolePasses,
        (volume.polePassesBySpecialty['SG'] ?? 0).toDouble(),
      );
      accumulator.add(
        TeamLeaderboardMetric.dhPolePasses,
        (volume.polePassesBySpecialty['DH'] ?? 0).toDouble(),
      );
      accumulator.add(
        TeamLeaderboardMetric.sxPolePasses,
        (volume.polePassesBySpecialty['SX'] ?? 0).toDouble(),
      );
      return;
    }

    final durationSeconds = _durationMinutes(session) * 60;
    accumulator.add(
      TeamLeaderboardMetric.hoursOutsideAlpineSki,
      durationSeconds / 3600,
    );

    final strength = activity.category == ActivityCategory.plyometrics
        ? const StrengthMetricsSummary()
        : TrainingMetricsUtils.strengthSummary([activity]);
    accumulator.add(
      TeamLeaderboardMetric.strengthVolumeKg,
      strength.volumeKg,
    );
    if (strength.totalSets > 0) {
      accumulator.add(TeamLeaderboardMetric.strengthSessions, 1);
    }

    final contacts = _plyometricContacts(activity);
    accumulator.add(
      TeamLeaderboardMetric.plyometricContacts,
      contacts.toDouble(),
    );

    final endurance = TrainingMetricsUtils.enduranceSummary([activity]);
    final isEnduranceSession = _isEnduranceSession(session, activity);
    var enduranceSeconds = endurance.durationSeconds;
    if (isEnduranceSession && enduranceSeconds <= 0) {
      enduranceSeconds = durationSeconds;
    }
    if (durationSeconds > 0 && enduranceSeconds > durationSeconds) {
      enduranceSeconds = durationSeconds;
    }

    var zone23Seconds = endurance.zone23Seconds;
    var zone45Seconds = endurance.zone45Seconds;
    if (isEnduranceSession &&
        zone23Seconds == 0 &&
        zone45Seconds == 0 &&
        session.details != null) {
      final fallback = EnduranceMetrics.fromSessionDetails(
        session.details!,
        durationSeconds: durationSeconds,
      );
      zone23Seconds = fallback.zone23Seconds;
      zone45Seconds = fallback.zone45Seconds;
    }

    accumulator.add(
      TeamLeaderboardMetric.enduranceHours,
      enduranceSeconds / 3600,
    );
    accumulator.add(
      TeamLeaderboardMetric.zone23Hours,
      zone23Seconds / 3600,
    );
    accumulator.add(
      TeamLeaderboardMetric.zone45Hours,
      zone45Seconds / 3600,
    );
    if (isEnduranceSession ||
        enduranceSeconds > 0 ||
        endurance.distanceKm > 0) {
      accumulator.add(TeamLeaderboardMetric.enduranceSessions, 1);
    }
  }

  int _plyometricContacts(TrainingActivity activity) {
    final structured =
        TrainingMetricsUtils.plyometricSummary([activity]).totalContacts;
    if (structured > 0 || activity.category != ActivityCategory.plyometrics) {
      return structured;
    }

    var contacts = 0;
    for (final block in activity.blocks) {
      final rawSets = block.metrics['sets'];
      if (rawSets is! List) continue;
      for (final rawSet in rawSets.whereType<Map>()) {
        contacts += _asNonNegativeInt(rawSet['contacts'] ?? rawSet['reps']);
      }
    }
    return contacts;
  }

  bool _isEnduranceSession(
    TrainingSession session,
    TrainingActivity activity,
  ) {
    final sportId = _normalizeSportId(session.sportId);
    final explicitCategory = session.details?['activityCategory']?.toString();
    if (explicitCategory == ActivityCategory.endurance) return true;
    if (_enduranceSportIds.contains(sportId) ||
        sportId.contains('running') ||
        sportId.contains('cycling') ||
        sportId.contains('endurance') ||
        sportId.contains('resistenza') ||
        sportId.contains('aerobic') ||
        sportId.contains('cardio')) {
      return true;
    }
    final source = session.details?['source']?.toString();
    if (source == 'health_sync' || source == ActivitySource.imported) {
      return false;
    }
    return activity.blocks.any(
      (block) =>
          block.type == TrainingBlockType.endurance &&
          block.endurance != null &&
          ((block.endurance!.durationSeconds ?? 0) > 0 ||
              (block.endurance!.distanceKm ?? 0) > 0 ||
              block.endurance!.zone23Seconds > 0 ||
              block.endurance!.zone45Seconds > 0),
    );
  }

  bool _isAlpineSkiing(String sportId) =>
      _alpineSkiSportIds.contains(_normalizeSportId(sportId));

  String _normalizeSportId(String sportId) =>
      sportId.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');

  int _durationMinutes(TrainingSession session) {
    final parsed = TimeUtils.parseDurationToMinutes(session.duration);
    if (parsed > 0) return parsed;

    final details = session.details ?? const <String, dynamic>{};
    final actual = details['actual'];
    final candidates = <dynamic>[
      details['actualDurationMinutes'],
      actual is Map ? actual['durationMinutes'] : null,
      details['total_duration_minutes'],
      details['active_duration_minutes'],
    ];
    for (final value in candidates) {
      final minutes =
          value is num ? value.round() : int.tryParse(value?.toString() ?? '');
      if (minutes != null && minutes > 0) return minutes;
    }

    final activeSeconds = details['active_duration_seconds'];
    final seconds = activeSeconds is num
        ? activeSeconds.round()
        : int.tryParse(activeSeconds?.toString() ?? '');
    if (seconds != null && seconds > 0) return (seconds / 60).round();

    return _clockDurationMinutes(session.startTime, session.endTime);
  }

  int _clockDurationMinutes(String startTime, String endTime) {
    int? parseClock(String value) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
      if (match == null) return null;
      final hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2)!);
      if (hour == null || minute == null || hour > 23 || minute > 59) {
        return null;
      }
      return hour * 60 + minute;
    }

    final start = parseClock(startTime);
    final end = parseClock(endTime);
    if (start == null || end == null || start == end) return 0;
    var duration = end - start;
    if (duration < 0) duration += 24 * 60;
    return duration;
  }

  int _asNonNegativeInt(dynamic value) {
    final parsed = value is num
        ? value.round()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    return parsed < 0 ? 0 : parsed;
  }
}

class _LeaderboardAccumulator {
  final Map<TeamLeaderboardMetric, double> values = {
    for (final metric in TeamLeaderboardMetric.values) metric: 0,
  };

  void add(TeamLeaderboardMetric metric, double value) {
    values[metric] = (values[metric] ?? 0) + value;
  }
}
