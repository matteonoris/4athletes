import 'package:flutter_mobile/services/daily_strain_persistence_service.dart';
import 'package:flutter_mobile/utils/metrics_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payload include score, raw loads, methods e coverage', () {
    const result = DailyStrainResult(
      score: 76,
      status: StrainScoreStatus.ok,
      confidence: 0.91,
      components: {
        'cardioScore': 80.0,
        'rpeScore': 70.0,
        'externalMechanicalScore': 75.0,
        'totalDurationMinutes': 90.0,
        'sessionCount': 2,
        'sportMix': {'running': 1, 'strength': 1},
        'rawLoads': {
          'cardioLoadAU': 220.0,
          'rpeLoadAU': 620.0,
          'externalMechanicalLoadAU': 100.0,
        },
        'methods': {'cardioMethod': 'hr_time_series'},
        'coverage': {'heartRateCoverage': 0.8, 'baselineValidDays': 21},
      },
      warnings: ['heart_rate_coverage_partial'],
    );

    final payload = buildDailyStrainScorePayload(
      athleteId: '00000000-0000-0000-0000-000000000001',
      date: '2026-06-12',
      result: result,
      algorithmVersion: 'test-version',
    );

    expect(payload['athlete_id'], '00000000-0000-0000-0000-000000000001');
    expect(payload['date'], '2026-06-12');
    expect(payload['score'], 76);
    expect(payload['status'], 'OK');
    expect(payload['cardio_load_au'], 220);
    expect(payload['session_count'], 2);
    expect(payload['sport_mix']['running'], 1);
    expect(payload['methods']['cardioMethod'], 'hr_time_series');
    expect(payload['coverage']['heartRateCoverage'], 0.8);
    expect(payload['warnings'], ['heart_rate_coverage_partial']);
    expect(payload['algorithm_version'], 'test-version');
  });

  test('upsert usa athlete_id,date e sostituisce stessa data nel fake store',
      () async {
    final supabase = _FakeSupabase();
    final first = {
      'athlete_id': 'athlete-1',
      'date': '2026-06-12',
      'score': 40,
    };
    final second = {
      'athlete_id': 'athlete-1',
      'date': '2026-06-12',
      'score': 65,
    };

    await upsertDailyStrainScore(supabase: supabase, payload: first);
    await upsertDailyStrainScore(supabase: supabase, payload: second);

    expect(supabase.tableName, 'daily_strain_scores');
    expect(supabase.onConflict, 'athlete_id,date');
    expect(supabase.rows.length, 1);
    expect(supabase.rows.single['score'], 65);
  });

  test('localDateKey usa la data locale fornita dall app', () {
    expect(localDateKey(DateTime(2026, 6, 12, 23, 30)), '2026-06-12');
  });
}

class _FakeSupabase {
  final rows = <Map<String, dynamic>>[];
  String? tableName;
  String? onConflict;

  _FakeTable from(String table) {
    tableName = table;
    return _FakeTable(this);
  }
}

class _FakeTable {
  final _FakeSupabase supabase;

  _FakeTable(this.supabase);

  Future<void> upsert(
    Map<String, dynamic> payload, {
    required String onConflict,
  }) async {
    supabase.onConflict = onConflict;
    final index = supabase.rows.indexWhere((row) {
      return row['athlete_id'] == payload['athlete_id'] &&
          row['date'] == payload['date'];
    });
    if (index >= 0) {
      supabase.rows[index] = Map<String, dynamic>.from(payload);
    } else {
      supabase.rows.add(Map<String, dynamic>.from(payload));
    }
  }
}
