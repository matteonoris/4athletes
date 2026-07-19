import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/services/athlete_monthly_recap_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = AthleteMonthlyRecapCalculator();

  test('aggrega volume, sedute, media e macroaree fino al giorno corrente', () {
    final recap = calculator.build(
      sessions: [
        _session(
          id: 'ski',
          sportId: 'alpine_skiing',
          date: '2026-07-01',
          duration: '02:00:00',
          details: _skiDetails(['SL']),
        ),
        _session(
          id: 'strength',
          sportId: 'dryland_strength',
          date: '2026-07-05',
          duration: '60',
          details: _completedDetails(ActivityCategory.strength),
        ),
        _session(
          id: 'recovery',
          sportId: 'yoga',
          date: '2026-07-10',
          duration: '30 min',
        ),
        _session(
          id: 'missing',
          sportId: 'other',
          date: '2026-07-12',
          duration: '0',
          startTime: '',
          endTime: '',
        ),
        _session(
          id: 'future-in-month',
          sportId: 'running',
          date: '2026-07-20',
          duration: '90',
        ),
      ],
      coachEvents: const [],
      selectedMonth: DateTime(2026, 7),
      now: DateTime(2026, 7, 16),
    );

    expect(recap.selected.totalMinutes, 210);
    expect(recap.selected.sessionCount, 4);
    expect(recap.selected.validDurationSessionCount, 3);
    expect(recap.selected.incompleteDurationCount, 1);
    expect(recap.selected.averageSessionMinutes, 70);
    expect(recap.selected.bucket(AthleteRecapMacro.ski).minutes, 120);
    expect(
      recap.selected.bucket(AthleteRecapMacro.preparation).minutes,
      60,
    );
    expect(
      recap.selected.bucket(AthleteRecapMacro.recoveryOther).minutes,
      30,
    );
    expect(
      recap.selected.bucket(AthleteRecapMacro.recoveryOther).sessionCount,
      2,
    );
  });

  test('confronta month-to-date e calcola la media dei tre mesi precedenti',
      () {
    final recap = calculator.build(
      sessions: [
        _session(id: 'apr-1', date: '2026-04-01', duration: '60'),
        _session(id: 'apr-20', date: '2026-04-20', duration: '600'),
        _session(id: 'may', date: '2026-05-01', duration: '120'),
        _session(id: 'jun', date: '2026-06-01', duration: '180'),
        _session(id: 'jul', date: '2026-07-01', duration: '240'),
      ],
      coachEvents: const [],
      selectedMonth: DateTime(2026, 7),
      now: DateTime(2026, 7, 16),
    );

    expect(recap.previous?.totalMinutes, 180);
    expect(recap.averageMonthCount, 3);
    expect(recap.average?.totalMinutes, 120);
    expect(recap.selected.throughDay, 16);
    expect(recap.previous?.throughDay, 16);
  });

  test('include eventi coach svolti senza duplicare quelli gia collegati', () {
    final recap = calculator.build(
      sessions: [
        _session(
          id: 'linked',
          date: '2026-06-02',
          duration: '60',
          eventId: 'event-linked',
        ),
        _session(
          id: 'planned',
          date: '2026-06-03',
          duration: '60',
          details: {'status': ActivityStatus.planned},
        ),
        _session(
          id: 'cancelled',
          date: '2026-06-04',
          duration: '60',
          details: {'status': ActivityStatus.cancelled},
        ),
      ],
      coachEvents: [
        _event(id: 'event-linked', date: '2026-06-02', present: true),
        _event(id: 'event-fallback', date: '2026-06-05', present: true),
        _event(id: 'event-absent', date: '2026-06-06', present: false),
      ],
      athleteId: 'athlete-1',
      selectedMonth: DateTime(2026, 6),
      now: DateTime(2026, 7, 16),
    );

    expect(recap.selected.sessionCount, 2);
    expect(recap.selected.totalMinutes, 150);
  });

  test('conta una sola volta una sessione merged e le sorgenti assorbite', () {
    final recap = calculator.build(
      sessions: [
        _session(
          id: 'canonical',
          date: '2026-06-01',
          duration: '120',
          details: {
            'workoutSource': 'merged',
            'merged_source_workout_ids': ['external-1'],
          },
        ),
        _session(
          id: 'raw-import',
          date: '2026-06-01',
          duration: '90',
          details: {
            'source': 'health_sync',
            'external_id': 'external-1',
          },
        ),
      ],
      coachEvents: const [],
      selectedMonth: DateTime(2026, 6),
      now: DateTime(2026, 7, 16),
    );

    expect(recap.selected.sessionCount, 1);
    expect(recap.selected.totalMinutes, 120);
  });

  test('mantiene gli sport endurance importati fuori dalla preparazione', () {
    final recap = calculator.build(
      sessions: [
        _session(
          id: 'road-run',
          sportId: 'road_running',
          date: '2026-06-08',
          duration: '75',
          details: {'source': 'health_sync'},
        ),
      ],
      coachEvents: const [],
      selectedMonth: DateTime(2026, 6),
      now: DateTime(2026, 7, 16),
    );

    expect(
      recap.selected.bucket(AthleteRecapMacro.otherSports).minutes,
      75,
    );
    expect(
      recap.selected.bucket(AthleteRecapMacro.preparation).minutes,
      0,
    );
  });

  test('mantiene ore sci aggregate e volume tecnico per doppia specialita', () {
    final recap = calculator.build(
      sessions: [
        _session(
          id: 'double-ski',
          sportId: 'alpine_skiing',
          date: '2026-06-10',
          duration: '120',
          details: {
            'specialties': ['SL', 'GS'],
            'freeSkiingBySpecialty': {
              'SL': {'laps': 2, 'changes': 5},
              'GS': {'laps': 1, 'changes': 4},
            },
            'tracks': [
              {'specialty': 'SL', 'laps': 3, 'gates': 20},
              {'specialty': 'GS', 'laps': 2, 'gates': 25},
            ],
            'trainingBlocks': [
              {'specialty': 'SL', 'laps': 2, 'changes': 8},
            ],
          },
        ),
      ],
      coachEvents: const [],
      selectedMonth: DateTime(2026, 6),
      now: DateTime(2026, 7, 16),
    );

    expect(recap.selected.bucket(AthleteRecapMacro.ski).minutes, 120);
    expect(recap.selected.skiSpecialties['SL']?.sessionCount, 1);
    expect(recap.selected.skiSpecialties['SL']?.technicalVolume, 86);
    expect(recap.selected.skiSpecialties['GS']?.sessionCount, 1);
    expect(recap.selected.skiSpecialties['GS']?.technicalVolume, 54);
  });

  test('usa orari come fallback e adatta il confronto ai mesi corti', () {
    final recap = calculator.build(
      sessions: [
        _session(
          id: 'feb',
          date: '2026-02-28',
          duration: 'invalid',
          startTime: '09:00',
          endTime: '10:30',
        ),
        _session(
          id: 'mar',
          date: '2026-03-31',
          duration: '60',
        ),
      ],
      coachEvents: const [],
      selectedMonth: DateTime(2026, 3),
      now: DateTime(2026, 3, 31),
    );

    expect(recap.selected.totalMinutes, 60);
    expect(recap.previous?.totalMinutes, 90);
    expect(recap.previous?.throughDay, 31);
  });
}

TrainingSession _session({
  required String id,
  String sportId = 'running',
  required String date,
  required String duration,
  String startTime = '09:00',
  String endTime = '10:00',
  String? eventId,
  Map<String, dynamic>? details,
}) {
  return TrainingSession(
    id: id,
    sportId: sportId,
    date: date,
    startTime: startTime,
    endTime: endTime,
    duration: duration,
    effort: 5,
    eventId: eventId,
    details: details,
  );
}

Map<String, dynamic> _completedDetails(String category) => {
      'status': ActivityStatus.completed,
      'activityDomain': 'dryland',
      'activityCategory': category,
    };

Map<String, dynamic> _skiDetails(List<String> specialties) => {
      'specialties': specialties,
      'tracks': [
        {'specialty': specialties.first, 'laps': 2, 'gates': 30},
      ],
    };

CalendarEvent _event({
  required String id,
  required String date,
  required bool present,
}) {
  return CalendarEvent(
    id: id,
    teamId: 'team-1',
    type: 'training',
    title: 'Allenamento sci',
    date: date,
    startTime: '09:00',
    endTime: '10:30',
    sportCategory: 'ski',
    status: 'completed',
    technicalDetails: {
      'specialties': ['SL'],
      'tracks': [
        {'specialty': 'SL', 'laps': 2, 'gates': 20},
      ],
    },
    attendees: [
      {
        'id': 'athlete-1',
        'attendanceStatus': present ? 'present' : 'absent',
        'isPresent': present,
      },
    ],
  );
}
