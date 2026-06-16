import '../models/models.dart';
import 'scoring/scoring_types.dart';

WorkoutSessionInput workoutSessionInputFromTrainingSession(
  TrainingSession session, {
  required String athleteId,
}) {
  final details = session.details ?? const <String, dynamic>{};
  return WorkoutSessionInput(
    id: session.id,
    athleteId: athleteId,
    date: session.date,
    startTime: session.startTime,
    endTime: session.endTime,
    sportType: session.sportId,
    durationMinutes: _durationMinutes(session, details),
    rpe: _sessionRpe(session, details),
    heartRateSamples: _heartRateSamples(details['hr_samples']),
    heartRateZones: _heartRateZones(details['hr_zones_seconds']) ??
        _heartRateZonesFromMinutes(details['hr_zones']),
    avgHeartRateBpm: _asDouble(details['avg_hr'] ?? details['avgHeartRate']),
    maxHeartRateBpm: _asDouble(details['max_hr'] ?? details['maxHeartRate']),
    activeEnergyKcal:
        _asDouble(details['energy_total_kcal'] ?? details['calories']),
    distanceMeters: _distanceMeters(details),
    elevationGainMeters:
        _asDouble(details['elevation_gain_meters'] ?? details['elevationGain']),
    elevationLossMeters: _asDouble(
      details['elevation_loss_meters'] ??
          details['elevationLossMeters'] ??
          details['vertical_drop_meters'],
    ),
    powerWattsAvg: _asDouble(details['powerWattsAvg'] ?? details['avgPower']),
    normalizedPowerWatts: _asDouble(
      details['normalizedPowerWatts'] ?? details['normalized_power_watts'],
    ),
    steps: _asDouble(details['steps']),
    runCount: _runCount(details),
  );
}

double? _sessionRpe(TrainingSession session, Map<String, dynamic> details) {
  final explicitRpe = _asDouble(details['rpe']);
  if (explicitRpe != null && explicitRpe > 0) return explicitRpe;

  if (details['source'] == 'health_sync') return null;
  if (session.effort <= 0) return null;
  return session.effort.toDouble();
}

List<WorkoutSessionInput> workoutInputsFromTrainingSessions(
  Iterable<TrainingSession> sessions, {
  required String athleteId,
}) {
  return sessions
      .map((session) => workoutSessionInputFromTrainingSession(
            session,
            athleteId: athleteId,
          ))
      .toList(growable: false);
}

double _durationMinutes(TrainingSession session, Map<String, dynamic> details) {
  return _asDouble(details['active_duration_minutes']) ??
      _asDouble(details['active_duration']) ??
      _asDouble(details['duration_minutes']) ??
      _asDouble(details['total_duration_minutes']) ??
      _parseDuration(session.duration);
}

double _parseDuration(String value) {
  final text = value.trim();
  if (text.isEmpty) return 0;
  final direct = double.tryParse(text.replaceAll(',', '.'));
  if (direct != null) return direct;

  final parts = text.split(':').map((part) => int.tryParse(part)).toList();
  if (parts.any((part) => part == null)) return 0;
  if (parts.length == 2) return parts[0]! * 60 + parts[1]!.toDouble();
  if (parts.length == 3) {
    return parts[0]! * 60 + parts[1]! + parts[2]! / 60;
  }
  return 0;
}

List<HeartRateSample>? _heartRateSamples(dynamic value) {
  if (value is! List) return null;
  final samples = <HeartRateSample>[];
  for (final item in value) {
    if (item is! Map) continue;
    final bpm = _asDouble(item['bpm']);
    final rawTime = item['timestamp'] ?? item['time'];
    if (bpm == null || rawTime == null) continue;
    final timestamp = rawTime is num
        ? DateTime.fromMillisecondsSinceEpoch(rawTime.round()).toIso8601String()
        : rawTime.toString();
    samples.add(HeartRateSample(timestamp: timestamp, bpm: bpm));
  }
  return samples.isEmpty ? null : samples;
}

HeartRateZones? _heartRateZones(dynamic value) {
  if (value is! List || value.isEmpty) return null;
  final zones = value.map(_asDouble).toList();
  return HeartRateZones(
    z1Minutes: zones.isNotEmpty && zones[0] != null ? zones[0]! / 60 : null,
    z2Minutes: zones.length > 1 && zones[1] != null ? zones[1]! / 60 : null,
    z3Minutes: zones.length > 2 && zones[2] != null ? zones[2]! / 60 : null,
    z4Minutes: zones.length > 3 && zones[3] != null ? zones[3]! / 60 : null,
    z5Minutes: zones.length > 4 && zones[4] != null ? zones[4]! / 60 : null,
  );
}

HeartRateZones? _heartRateZonesFromMinutes(dynamic value) {
  if (value is! List || value.isEmpty) return null;
  final zones = value.map(_asDouble).toList();
  return HeartRateZones(
    z1Minutes: zones.isNotEmpty ? zones[0] : null,
    z2Minutes: zones.length > 1 ? zones[1] : null,
    z3Minutes: zones.length > 2 ? zones[2] : null,
    z4Minutes: zones.length > 3 ? zones[3] : null,
    z5Minutes: zones.length > 4 ? zones[4] : null,
  );
}

double? _distanceMeters(Map<String, dynamic> details) {
  final explicit = _asDouble(details['distance_meters']);
  if (explicit != null) return explicit;
  final raw = details['distance'];
  if (raw == null) return null;
  final value = _asDouble(raw.toString().replaceAll('km', '').trim());
  return value == null ? null : value * 1000;
}

double? _runCount(Map<String, dynamic> details) {
  final explicit = _asDouble(details['runCount'] ?? details['runs']);
  if (explicit != null) return explicit;

  final gated = details['gatedSkiing'];
  if (gated is Map) {
    final laps = _asDouble(gated['laps']);
    if (laps != null) return laps;
  }

  final tracks = details['tracks'];
  if (tracks is List) {
    var total = 0.0;
    for (final track in tracks) {
      if (track is Map) total += _asDouble(track['laps']) ?? 0;
    }
    if (total > 0) return total;
  }
  return null;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final match = RegExp(r'-?\d+([.,]\d+)?').firstMatch(value.toString());
  if (match == null) return null;
  return double.tryParse(match.group(0)!.replaceAll(',', '.'));
}
