import 'dart:math';

import '../models/models.dart';

class HealthWorkoutMergeUtils {
  static TrainingSession? bestOverlapMergeCandidate(
    List<TrainingSession> sessions,
    TrainingSession imported,
  ) {
    final importedRange = _sessionDateTimeRange(imported);
    if (importedRange == null) return null;

    TrainingSession? best;
    var bestOverlapSeconds = 0;

    for (final existing in sessions) {
      if (existing.id == imported.id) continue;

      final existingRange = _sessionDateTimeRange(existing);
      if (existingRange == null) continue;

      final overlapSeconds = _overlapSeconds(importedRange, existingRange);
      if (overlapSeconds <= 0) continue;
      if (!_canMergeHealthImportIntoExisting(
        existing,
        imported,
        overlapSeconds: overlapSeconds,
        existingRange: existingRange,
        importedRange: importedRange,
      )) {
        continue;
      }

      if (overlapSeconds > bestOverlapSeconds) {
        best = existing;
        bestOverlapSeconds = overlapSeconds;
      }
    }

    return best;
  }

  static TrainingSession mergeImportedSession(
    TrainingSession existing,
    TrainingSession imported,
  ) {
    final preservedDetails = Map<String, dynamic>.from(existing.details ?? {});
    preservedDetails.removeWhere((key, _) => _healthManagedKeys.contains(key));
    preservedDetails.addAll(imported.details ?? {});

    return TrainingSession(
      id: existing.id,
      sportId: imported.sportId,
      date: imported.date,
      startTime: imported.startTime,
      endTime: imported.endTime,
      duration: imported.duration,
      effort: existing.effort,
      eventId: existing.eventId,
      details: preservedDetails,
    );
  }

  static bool _canMergeHealthImportIntoExisting(
    TrainingSession existing,
    TrainingSession imported, {
    required int overlapSeconds,
    required _SessionDateTimeRange existingRange,
    required _SessionDateTimeRange importedRange,
  }) {
    final details = existing.details ?? const <String, dynamic>{};
    final importedSeconds =
        importedRange.end.difference(importedRange.start).inSeconds;
    final existingSeconds =
        existingRange.end.difference(existingRange.start).inSeconds;
    final shorterSeconds = min(importedSeconds, existingSeconds);
    final standardMinimumOverlapSeconds =
        min(20 * 60, (shorterSeconds * 0.60).round());

    if (details['source'] == 'health_sync') {
      return overlapSeconds >= standardMinimumOverlapSeconds;
    }

    if (!_sameSportFamily(existing.sportId, imported.sportId)) return false;

    if (!_hasStructuredDrylandDetails(details)) {
      return overlapSeconds >= standardMinimumOverlapSeconds;
    }

    // Strength/dryland sessions created in-app carry athlete-authored sets and
    // blocks. Merge them only when the time overlap is strong, then preserve
    // those authored details while importing the wearable timing/HR metrics.
    final structuredMinimumOverlapSeconds =
        min(45 * 60, (shorterSeconds * 0.70).round());
    return overlapSeconds >= structuredMinimumOverlapSeconds;
  }

  static bool _hasStructuredDrylandDetails(Map<String, dynamic> details) {
    if (details['activityDomain'] == 'dryland') return true;
    if (details['blocks'] is List) return true;
    if (details['exercises'] is List) return true;
    return false;
  }

  static bool _sameSportFamily(String a, String b) {
    String family(String sportId) {
      if (sportId.contains('running') ||
          sportId == 'marathon' ||
          sportId == 'track_field') {
        return 'running';
      }
      if (sportId.contains('cycling') || sportId == 'spinning') {
        return 'cycling';
      }
      if (sportId == 'walking' || sportId == 'hiking') return 'walking';
      if (sportId == 'swimming') return 'swimming';
      if (sportId == 'rowing') return 'rowing';
      if (sportId == 'cross_country_skiing') return 'nordic_ski';
      if (sportId == 'alpine_skiing' || sportId == 'snowboarding') {
        return 'snow';
      }
      return sportId;
    }

    return family(a) == family(b);
  }

  static _SessionDateTimeRange? _sessionDateTimeRange(
    TrainingSession session,
  ) {
    try {
      final start = DateTime.parse(
          '${session.date}T${_normalizeSessionClock(session.startTime)}');
      var end = DateTime.parse(
          '${session.date}T${_normalizeSessionClock(session.endTime)}');
      if (!end.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      }
      return _SessionDateTimeRange(start, end);
    } catch (_) {
      return null;
    }
  }

  static String _normalizeSessionClock(String time) {
    final parts = time.trim().split(':');
    if (parts.isEmpty || parts[0].isEmpty) return '00:00:00';
    if (parts.length == 1) return '${parts[0].padLeft(2, '0')}:00:00';
    if (parts.length == 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}:00';
    }
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}:${parts[2].padLeft(2, '0')}';
  }

  static int _overlapSeconds(
    _SessionDateTimeRange a,
    _SessionDateTimeRange b,
  ) {
    final start = a.start.isAfter(b.start) ? a.start : b.start;
    final end = a.end.isBefore(b.end) ? a.end : b.end;
    if (!end.isAfter(start)) return 0;
    return end.difference(start).inSeconds;
  }

  static const Set<String> _healthManagedKeys = {
    'source',
    'health_import_version',
    'source_name',
    'source_id',
    'external_id',
    'total_duration',
    'total_duration_minutes',
    'total_duration_seconds',
    'active_duration',
    'active_duration_minutes',
    'active_duration_seconds',
    'moving_duration_seconds',
    'duration_source',
    'distance',
    'distance_meters',
    'pace',
    'avg_pace_sec_per_km',
    'speed',
    'avg_speed_kmh',
    'calories',
    'energy_total_kcal',
    'elevation',
    'elevation_meters',
    'elevation_source',
    'avg_hr',
    'avgHeartRate',
    'max_hr',
    'maxHeartRate',
    'hr_reliable',
    'hr_samples',
    'hr_sample_count',
    'hr_coverage_seconds',
    'hr_coverage_minutes',
    'hr_zones',
    'hr_zones_seconds',
    'hr_zone_boundaries',
    'dominant_hr_zone',
    'merged_source_workout_ids',
    'source_part_count',
  };
}

class _SessionDateTimeRange {
  final DateTime start;
  final DateTime end;

  const _SessionDateTimeRange(this.start, this.end);
}
