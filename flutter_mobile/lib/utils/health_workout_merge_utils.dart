import 'dart:math';

import '../models/models.dart';
import '../services/health_import_normalizer.dart';

class HealthWorkoutMergeUtils {
  static const Duration startTimeMergeTolerance = Duration(minutes: 10);

  static TrainingSession? bestOverlapMergeCandidate(
    List<TrainingSession> sessions,
    TrainingSession imported,
  ) {
    final importedRange = _sessionDateTimeRange(imported);
    if (importedRange == null) return null;

    TrainingSession? best;
    var bestOverlapSeconds = 0;
    var bestStartDeltaSeconds = 1 << 30;
    var bestStartsNear = false;

    for (final existing in sessions) {
      if (existing.id == imported.id) continue;

      final existingRange = _sessionDateTimeRange(existing);
      if (existingRange == null) continue;

      final overlapSeconds = _overlapSeconds(importedRange, existingRange);
      final startDeltaSeconds = _startDeltaSeconds(
        importedRange,
        existingRange,
      );
      final startsNear = startDeltaSeconds <= startTimeMergeTolerance.inSeconds;
      if (!_canMergeHealthImportIntoExisting(
        existing,
        imported,
        overlapSeconds: overlapSeconds,
        startDeltaSeconds: startDeltaSeconds,
        existingRange: existingRange,
        importedRange: importedRange,
      )) {
        continue;
      }

      if (best == null ||
          (startsNear && !bestStartsNear) ||
          (startsNear == bestStartsNear &&
              overlapSeconds > bestOverlapSeconds) ||
          (startsNear == bestStartsNear &&
              overlapSeconds == bestOverlapSeconds &&
              startDeltaSeconds < bestStartDeltaSeconds)) {
        best = existing;
        bestOverlapSeconds = overlapSeconds;
        bestStartDeltaSeconds = startDeltaSeconds;
        bestStartsNear = startsNear;
      }
    }

    return best;
  }

  static TrainingSession mergeImportedSession(
    TrainingSession existing,
    TrainingSession imported,
  ) {
    final existingRange = _sessionDateTimeRange(existing);
    final importedRange = _sessionDateTimeRange(imported);
    final mergedRange = existing.details?['duration_user_overridden'] == true
        ? existingRange
        : _longestRange(existingRange, importedRange);

    final preservedDetails = Map<String, dynamic>.from(existing.details ?? {});
    preservedDetails.removeWhere((key, _) => _healthManagedKeys.contains(key));
    preservedDetails.addAll(imported.details ?? {});

    final merged = TrainingSession(
      id: existing.id,
      sportId: _mergedSportId(existing.sportId, imported.sportId),
      date: mergedRange?.date ?? imported.date,
      startTime: mergedRange != null
          ? _formatSessionClock(mergedRange.start)
          : imported.startTime,
      endTime: mergedRange != null
          ? _formatSessionClock(mergedRange.end)
          : imported.endTime,
      duration: mergedRange != null
          ? _roundedMinutesString(mergedRange.durationSeconds)
          : imported.duration,
      effort: existing.effort,
      eventId: existing.eventId,
      details: preservedDetails,
    );
    return normalizeSessionHealthDetails(merged);
  }

  static TrainingSession normalizeSessionHealthDetails(
    TrainingSession session,
  ) {
    final details = session.details;
    if (details == null) return session;
    if (details['source'] != 'health_sync' && details['external_id'] == null) {
      return session;
    }

    final range = _sessionDateTimeRange(session);
    if (range == null) return session;

    final normalizedDetails = Map<String, dynamic>.from(details);
    _syncDurationDetailsToRange(normalizedDetails, range);
    _syncHeartRateDetailsToRange(normalizedDetails, range);

    return TrainingSession(
      id: session.id,
      sportId: session.sportId,
      date: session.date,
      startTime: session.startTime,
      endTime: session.endTime,
      duration: session.duration,
      effort: session.effort,
      eventId: session.eventId,
      details: normalizedDetails,
    );
  }

  static bool _canMergeHealthImportIntoExisting(
    TrainingSession existing,
    TrainingSession imported, {
    required int overlapSeconds,
    required int startDeltaSeconds,
    required _SessionDateTimeRange existingRange,
    required _SessionDateTimeRange importedRange,
  }) {
    final details = existing.details ?? const <String, dynamic>{};
    if (!_sameSportFamily(existing.sportId, imported.sportId)) return false;

    if (startDeltaSeconds <= startTimeMergeTolerance.inSeconds) return true;

    if (overlapSeconds <= 0) return false;

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
    return _sportFamily(a) == _sportFamily(b);
  }

  static String _mergedSportId(String existingSportId, String importedSportId) {
    if (_sportFamily(existingSportId) != _sportFamily(importedSportId)) {
      return importedSportId;
    }

    if (_sportFamily(importedSportId) == 'snow') {
      final existingCanonical = _canonicalSnowSportId(existingSportId);
      final importedCanonical = _canonicalSnowSportId(importedSportId);
      if (existingCanonical == 'alpine_skiing' &&
          importedCanonical == 'alpine_skiing') {
        return 'alpine_skiing';
      }
    }

    return importedSportId;
  }

  static String _sportFamily(String sportId) {
    final normalized = _normalizeSportId(sportId);
    if (normalized.contains('running') ||
        normalized == 'marathon' ||
        normalized == 'track_field' ||
        normalized == 'track_and_field') {
      return 'running';
    }
    if (normalized.contains('cycling') || normalized == 'spinning') {
      return 'cycling';
    }
    if (normalized == 'walking' || normalized == 'hiking') return 'walking';
    if (normalized == 'swimming') return 'swimming';
    if (normalized == 'rowing' || normalized == 'rowing_machine') {
      return 'rowing';
    }
    if (normalized == 'cross_country_skiing' || normalized == 'xc_skiing') {
      return 'nordic_ski';
    }
    if (_canonicalSnowSportId(normalized) != normalized ||
        normalized == 'alpine_skiing' ||
        normalized == 'snowboarding') {
      return 'snow';
    }
    return normalized;
  }

  static String _canonicalSnowSportId(String sportId) {
    final normalized = _normalizeSportId(sportId);
    if (normalized == 'alpine_skiing' ||
        normalized == 'alpine_ski' ||
        normalized == 'downhill_skiing' ||
        normalized == 'downhill_ski' ||
        normalized == 'skiing' ||
        normalized == 'ski' ||
        normalized == 'snow_sports' ||
        normalized == 'snow_sport' ||
        normalized == 'snowsports') {
      return 'alpine_skiing';
    }
    return normalized;
  }

  static String _normalizeSportId(String sportId) {
    return sportId.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
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

  static int _startDeltaSeconds(
    _SessionDateTimeRange a,
    _SessionDateTimeRange b,
  ) {
    return a.start.difference(b.start).inSeconds.abs();
  }

  static _SessionDateTimeRange? _longestRange(
    _SessionDateTimeRange? existing,
    _SessionDateTimeRange? imported,
  ) {
    if (existing == null) return imported;
    if (imported == null) return existing;
    return imported.durationSeconds >= existing.durationSeconds
        ? imported
        : existing;
  }

  static String _formatSessionClock(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  static String _roundedMinutesString(int seconds) {
    if (seconds <= 0) return '0';
    return max(1, (seconds / 60).round()).toString();
  }

  static void _syncDurationDetailsToRange(
    Map<String, dynamic> details,
    _SessionDateTimeRange range,
  ) {
    final totalSeconds = range.durationSeconds;
    final totalMinutes = max(1, (totalSeconds / 60).round());
    details['total_duration_seconds'] = totalSeconds;
    details['total_duration_minutes'] = totalMinutes;
    details['total_duration'] = totalMinutes.toString();
    details['duration_source'] =
        details['duration_user_overridden'] == true ? 'manual' : 'merged';

    final activeSeconds = _asInt(details['active_duration_seconds']);
    if (activeSeconds != null && activeSeconds > totalSeconds) {
      final activeMinutes = max(1, (totalSeconds / 60).round());
      details['active_duration_seconds'] = totalSeconds;
      details['active_duration_minutes'] = activeMinutes;
      details['active_duration'] = activeMinutes.toString();
    }
  }

  static void _syncHeartRateDetailsToRange(
    Map<String, dynamic> details,
    _SessionDateTimeRange range,
  ) {
    final sourceSamples = _parseHeartRateSamples(
      details['hr_samples_full'] ?? details['hr_samples'],
    );
    if (sourceSamples.isEmpty) return;

    final rangedSamples = sourceSamples
        .where((sample) =>
            !sample.time.isBefore(range.start) &&
            !sample.time.isAfter(range.end))
        .toList();

    if (rangedSamples.length == sourceSamples.length &&
        details['hr_samples_full'] == null) {
      return;
    }

    if (rangedSamples.length < sourceSamples.length &&
        details['hr_samples_full'] == null) {
      details['hr_samples_full'] =
          HealthImportNormalizer.serializeHeartRateSamples(sourceSamples);
    }

    details['hr_samples'] =
        HealthImportNormalizer.serializeHeartRateSamples(rangedSamples);
    details['hr_sample_count'] = rangedSamples.length;

    if (rangedSamples.isEmpty) {
      details.remove('avg_hr');
      details.remove('max_hr');
      details.remove('hr_zones');
      details.remove('hr_zones_seconds');
      details.remove('dominant_hr_zone');
      details['hr_coverage_seconds'] = 0;
      details['hr_coverage_minutes'] = 0;
      details['hr_reliable'] = false;
      return;
    }

    final activeSeconds = min(
      _asInt(details['active_duration_seconds']) ?? range.durationSeconds,
      range.durationSeconds,
    );
    final metrics = HealthImportNormalizer.calculateHeartRateMetrics(
      samples: rangedSamples,
      zones: _parseZoneBoundaries(details['hr_zone_boundaries']),
      workoutStart: range.start,
      workoutEnd: range.end,
    );
    final reliable =
        HealthImportNormalizer.isReliableHeartRate(metrics, activeSeconds);

    details['hr_reliable'] = reliable;
    details['hr_coverage_seconds'] = metrics.coverageSeconds;
    details['hr_coverage_minutes'] =
        max(0, (metrics.coverageSeconds / 60).round());
    if (metrics.averageHeartRate != null) {
      details['avg_hr'] = metrics.averageHeartRate;
    }
    if (metrics.maxHeartRate != null) {
      details['max_hr'] = metrics.maxHeartRate;
    }
    if (metrics.zoneSeconds.any((seconds) => seconds > 0)) {
      details['hr_zones_seconds'] =
          metrics.zoneSeconds.map((seconds) => seconds.round()).toList();
      details['hr_zones'] = HealthImportNormalizer.zoneMinutesFromSeconds(
        zoneSeconds: metrics.zoneSeconds,
        activeDurationSeconds: activeSeconds,
        coveredSeconds: metrics.coverageSeconds,
      );
      details['dominant_hr_zone'] =
          HealthImportNormalizer.dominantZoneIndex(metrics.zoneSeconds);
    }
  }

  static List<HeartRateSample> _parseHeartRateSamples(dynamic value) {
    if (value is! List) return [];

    final samples = <HeartRateSample>[];
    for (final item in value) {
      if (item is! Map) continue;
      final timeMs = _asInt(item['time']);
      final bpm = _asDouble(item['bpm']);
      if (timeMs == null || bpm == null) continue;
      samples.add(HeartRateSample(
        DateTime.fromMillisecondsSinceEpoch(timeMs),
        bpm,
      ));
    }
    return HealthImportNormalizer.cleanHeartRateSamples(samples);
  }

  static List<Map<String, int>> _parseZoneBoundaries(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((zone) {
          final min = _asInt(zone['min']);
          final max = _asInt(zone['max']);
          if (min == null || max == null) return null;
          return {'min': min, 'max': max};
        })
        .whereType<Map<String, int>>()
        .toList();
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
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
    'hr_samples_full',
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

  int get durationSeconds => end.difference(start).inSeconds;

  String get date => start.toIso8601String().split('T').first;
}
