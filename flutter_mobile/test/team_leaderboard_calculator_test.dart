import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/services/team_leaderboard_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = TeamLeaderboardCalculator();
  const athleteId = 'athlete-1';
  final athlete = <String, dynamic>{
    'id': athleteId,
    'first_name': 'Test',
    'last_name': 'Athlete',
    'skill_level': 'Junior',
  };

  test('il filtro predefinito e le unita restano nell ordine previsto', () {
    expect(
      TeamLeaderboardMetric.values.first,
      TeamLeaderboardMetric.hoursOutsideAlpineSki,
    );
    expect(TeamLeaderboardMetric.hoursOutsideAlpineSki.unit, 'h');
    expect(TeamLeaderboardMetric.totalDirectionChanges.unit, '');
    expect(TeamLeaderboardMetric.strengthVolumeKg.unit, 'kg');
    expect(TeamLeaderboardMetric.enduranceSessions.unit, 'sess');
  });

  test('carica tutte le pagine oltre il limite Supabase di 1000 righe',
      () async {
    final source = List<int>.generate(1085, (index) => index);
    final requestedRanges = <(int, int)>[];

    final result = await TeamLeaderboardPagination.fetchAll<int>(
      pageSize: 500,
      fetchPage: (from, to) async {
        requestedRanges.add((from, to));
        if (from >= source.length) return [];
        final endExclusive = (to + 1).clamp(0, source.length);
        return source.sublist(from, endExclusive);
      },
    );

    expect(result, source);
    expect(
      requestedRanges,
      [(0, 499), (500, 999), (1000, 1499)],
    );
  });

  test('ultimi 7 giorni include esattamente oggi e i sei giorni precedenti',
      () {
    final period = TeamLeaderboardPeriod.forRange(
      TeamLeaderboardTimeRange.last7Days,
      DateTime(2026, 7, 26, 18),
    );

    expect(period.start, DateTime(2026, 7, 20));
    expect(period.endExclusive, DateTime(2026, 7, 27));
    expect(period.contains(DateTime(2026, 7, 20)), isTrue);
    expect(period.contains(DateTime(2026, 7, 26, 23, 59)), isTrue);
    expect(period.contains(DateTime(2026, 7, 19)), isFalse);
    expect(period.contains(DateTime(2026, 7, 27)), isFalse);
  });

  test('mese e stagione hanno confini inclusivi corretti', () {
    final month = TeamLeaderboardPeriod.forRange(
      TeamLeaderboardTimeRange.thisMonth,
      DateTime(2026, 7, 26),
    );
    final winterSeason = TeamLeaderboardPeriod.forRange(
      TeamLeaderboardTimeRange.thisSeason,
      DateTime(2026, 2, 10),
    );
    final summerSeason = TeamLeaderboardPeriod.forRange(
      TeamLeaderboardTimeRange.thisSeason,
      DateTime(2026, 7, 26),
    );

    expect(month.start, DateTime(2026, 7, 1));
    expect(month.endExclusive, DateTime(2026, 7, 27));
    expect(winterSeason.start, DateTime(2025, 5, 1));
    expect(summerSeason.start, DateTime(2026, 5, 1));
  });

  test(
      'Ore somma sessioni atleta e coach completate fuori sci ed esclude '
      'annullate, pianificate, future e fuori intervallo', () {
    final stats = calculator.calculate(
      athletes: [athlete],
      sessions: [
        _entry(
          athleteId,
          date: '2026-07-26',
          duration: '60',
          sportId: 'dryland_strength',
          status: ActivityStatus.completed,
          source: ActivitySource.athlete,
        ),
        _entry(
          athleteId,
          date: '2026-07-20',
          duration: '01:30:00',
          sportId: 'running',
          status: ActivityStatus.completed,
          source: ActivitySource.coach,
          eventId: 'coach-event',
        ),
        _entry(
          athleteId,
          date: '2026-07-19',
          duration: '120',
          sportId: 'running',
        ),
        _entry(
          athleteId,
          date: '2026-07-27',
          duration: '120',
          sportId: 'running',
        ),
        _entry(
          athleteId,
          date: '2026-07-26',
          duration: '120',
          sportId: 'running',
          status: ActivityStatus.planned,
        ),
        _entry(
          athleteId,
          date: '2026-07-26',
          duration: '120',
          sportId: 'running',
          status: ActivityStatus.cancelled,
        ),
        _entry(
          athleteId,
          date: '2026-07-26',
          duration: '120',
          sportId: 'alpine_skiing',
        ),
      ],
      timeRange: TeamLeaderboardTimeRange.last7Days,
      referenceDate: DateTime(2026, 7, 26),
    ).single;

    expect(
      stats.valueFor(TeamLeaderboardMetric.hoursOutsideAlpineSki),
      closeTo(2.5, 0.0001),
    );
  });

  test('tutti i filtri aggregano i payload legacy e strutturati corretti', () {
    final stats = calculator.calculate(
      athletes: [athlete],
      sessions: [
        _entry(
          athleteId,
          date: '2026-07-24',
          duration: '120',
          sportId: 'snow_sports',
          details: {
            'status': ActivityStatus.completed,
            'specialties': ['SL', 'GS', 'SG', 'DH', 'SX'],
            'freeSkiingBySpecialty': {
              'SL': {'laps': 2, 'changes': 10},
            },
            'tracks': [
              {'specialty': 'SL', 'laps': 3, 'gates': 20},
              {'specialty': 'GS', 'laps': 2, 'gates': 30},
              {'specialty': 'SG', 'laps': 1, 'gates': 40},
              {'specialty': 'DH', 'laps': 1, 'gates': 35},
              {'specialty': 'SX', 'laps': 2, 'gates': 15},
            ],
            'trainingBlocks': [
              {'specialty': 'SX', 'laps': 2, 'references': 8},
            ],
          },
        ),
        _entry(
          athleteId,
          date: '2026-07-24',
          duration: '60',
          sportId: 'dryland_strength',
          details: {
            'status': ActivityStatus.completed,
            'activityCategory': ActivityCategory.strength,
            'blocks': [
              {
                'id': 'strength',
                'type': TrainingBlockType.strength,
                'name': 'Squat',
                'exercises': [
                  {
                    'exerciseId': 'squat',
                    'name': 'Squat',
                    'sets': [
                      {'setNumber': 1, 'kg': 100, 'reps': 5},
                    ],
                  },
                ],
              },
            ],
          },
        ),
        _entry(
          athleteId,
          date: '2026-07-24',
          duration: '30',
          sportId: 'dryland_plyometrics',
          details: {
            'status': ActivityStatus.completed,
            'activityCategory': ActivityCategory.plyometrics,
            'blocks': [
              {
                'id': 'plyo-v3',
                'type': TrainingBlockType.strength,
                'name': 'Jumps',
                'metrics': {
                  'sets': [
                    {'contacts': 7},
                    {'reps': 5},
                  ],
                },
                'exercises': [
                  {
                    'exerciseId': 'jumps',
                    'name': 'Jumps',
                    'sets': [
                      {'setNumber': 1, 'reps': 12},
                    ],
                  },
                ],
              },
            ],
          },
        ),
        _entry(
          athleteId,
          date: '2026-07-24',
          duration: '45',
          sportId: 'running',
          details: {
            'status': ActivityStatus.completed,
            'activityCategory': ActivityCategory.sport,
            'hr_zones_seconds': [0, 0, 600, 900, 300, 60],
            'blocks': <Map<String, dynamic>>[],
          },
        ),
        _entry(
          athleteId,
          date: '2026-07-24',
          duration: '30',
          sportId: 'running',
          details: {
            'status': ActivityStatus.completed,
            'activityCategory': ActivityCategory.sport,
            'blocks': [
              {
                'id': 'interval',
                'type': TrainingBlockType.endurance,
                'name': 'Intervals',
                'metrics': {'blockKind': 'interval'},
              },
            ],
          },
        ),
      ],
      timeRange: TeamLeaderboardTimeRange.last7Days,
      referenceDate: DateTime(2026, 7, 26),
    ).single;

    expect(
      stats.valueFor(TeamLeaderboardMetric.hoursOutsideAlpineSki),
      closeTo(2.75, 0.0001),
    );
    expect(
      stats.valueFor(TeamLeaderboardMetric.totalDirectionChanges),
      36,
    );
    expect(stats.valueFor(TeamLeaderboardMetric.slPolePasses), 60);
    expect(stats.valueFor(TeamLeaderboardMetric.gsPolePasses), 60);
    expect(stats.valueFor(TeamLeaderboardMetric.sgPolePasses), 40);
    expect(stats.valueFor(TeamLeaderboardMetric.dhPolePasses), 35);
    expect(stats.valueFor(TeamLeaderboardMetric.sxPolePasses), 30);
    expect(
      stats.valueFor(TeamLeaderboardMetric.enduranceHours),
      closeTo(1.25, 0.0001),
    );
    expect(
      stats.valueFor(TeamLeaderboardMetric.zone23Hours),
      closeTo(1500 / 3600, 0.0001),
    );
    expect(
      stats.valueFor(TeamLeaderboardMetric.zone45Hours),
      closeTo(360 / 3600, 0.0001),
    );
    expect(stats.valueFor(TeamLeaderboardMetric.strengthVolumeKg), 500);
    expect(stats.valueFor(TeamLeaderboardMetric.plyometricContacts), 12);
    expect(stats.valueFor(TeamLeaderboardMetric.strengthSessions), 1);
    expect(stats.valueFor(TeamLeaderboardMetric.enduranceSessions), 2);
  });

  test('la durata usa i dati effettivi o gli orari quando il campo e vuoto',
      () {
    final stats = calculator.calculate(
      athletes: [athlete],
      sessions: [
        _entry(
          athleteId,
          date: '2026-07-26',
          duration: '0',
          startTime: '22:30',
          endTime: '00:00',
          sportId: 'running',
          details: {
            'status': ActivityStatus.completed,
            'activityCategory': ActivityCategory.sport,
          },
        ),
        _entry(
          athleteId,
          date: '2026-07-26',
          duration: '0',
          sportId: 'dryland_strength',
          details: {
            'status': ActivityStatus.completed,
            'actual': {'durationMinutes': 45},
          },
        ),
      ],
      timeRange: TeamLeaderboardTimeRange.last7Days,
      referenceDate: DateTime(2026, 7, 26),
    ).single;

    expect(
      stats.valueFor(TeamLeaderboardMetric.hoursOutsideAlpineSki),
      closeTo(2.25, 0.0001),
    );
    expect(
      stats.valueFor(TeamLeaderboardMetric.enduranceHours),
      closeTo(1.5, 0.0001),
    );
  });

  test('un import Health di forza non diventa una seduta di resistenza', () {
    final stats = calculator.calculate(
      athletes: [athlete],
      sessions: [
        _entry(
          athleteId,
          date: '2026-07-26',
          duration: '60',
          sportId: 'weightlifting',
          details: {
            'source': 'health_sync',
            'exercises': [
              {
                'exerciseId': 'squat',
                'name': 'Squat',
                'sets': [
                  {'setNumber': 1, 'kg': 80, 'reps': 5},
                ],
              },
            ],
          },
        ),
      ],
      timeRange: TeamLeaderboardTimeRange.last7Days,
      referenceDate: DateTime(2026, 7, 26),
    ).single;

    expect(
      stats.valueFor(TeamLeaderboardMetric.hoursOutsideAlpineSki),
      1,
    );
    expect(stats.valueFor(TeamLeaderboardMetric.strengthVolumeKg), 400);
    expect(stats.valueFor(TeamLeaderboardMetric.strengthSessions), 1);
    expect(stats.valueFor(TeamLeaderboardMetric.enduranceHours), 0);
    expect(stats.valueFor(TeamLeaderboardMetric.enduranceSessions), 0);
  });
}

TeamLeaderboardSession _entry(
  String athleteId, {
  required String date,
  required String duration,
  required String sportId,
  String startTime = '10:00',
  String endTime = '11:00',
  String? status,
  String? source,
  String? eventId,
  Map<String, dynamic>? details,
}) {
  return TeamLeaderboardSession(
    athleteId: athleteId,
    session: TrainingSession(
      id: '$athleteId-$date-$sportId-${eventId ?? source ?? 'manual'}',
      sportId: sportId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      duration: duration,
      effort: 5,
      eventId: eventId,
      details: {
        ...?details,
        if (status != null) 'status': status,
        if (source != null) 'source': source,
      },
    ),
  );
}
