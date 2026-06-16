import '../utils/metrics_engine.dart';

String localDateKey(DateTime date) {
  final local = date.toLocal();
  return local.toIso8601String().split('T').first;
}

Map<String, dynamic> buildDailyStrainScorePayload({
  required String athleteId,
  required String date,
  required DailyStrainResult result,
  required String algorithmVersion,
}) {
  final components = result.components;
  final rawLoads = _map(components['rawLoads']);
  return {
    'athlete_id': athleteId,
    'date': date,
    'score': result.score,
    'status': result.statusCode,
    'confidence': result.confidence,
    'cardio_score': _asDouble(components['cardioScore']),
    'rpe_score': _asDouble(components['rpeScore']),
    'external_mechanical_score':
        _asDouble(components['externalMechanicalScore']),
    'cardio_load_au': _asDouble(rawLoads['cardioLoadAU']),
    'rpe_load_au': _asDouble(rawLoads['rpeLoadAU']),
    'external_mechanical_load_au':
        _asDouble(rawLoads['externalMechanicalLoadAU']),
    'total_duration_minutes':
        _asDouble(components['totalDurationMinutes']) ?? 0,
    'session_count': _asInt(components['sessionCount']) ?? 0,
    'sport_mix': _map(components['sportMix']),
    'methods': _map(components['methods']),
    'coverage': _map(components['coverage']),
    'warnings': result.warnings,
    'algorithm_version': algorithmVersion,
  };
}

Future<void> upsertDailyStrainScore({
  required dynamic supabase,
  required Map<String, dynamic> payload,
}) async {
  await supabase
      .from('daily_strain_scores')
      .upsert(payload, onConflict: 'athlete_id,date');
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return null;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return null;
}
