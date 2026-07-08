import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/monthly_team_report_models.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/services/monthly_team_report_calculator.dart';
import 'package:flutter_mobile/services/monthly_team_report_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it');
  });

  const calculator = MonthlyTeamReportCalculator();

  test('distingue programmato e fuori programma con volumi sci', () {
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: const [
        TeamReportAthleteProfile(
            id: 'athlete_1', firstName: 'Ada', lastName: 'Rossi'),
      ],
      events: [
        _event(
          id: 'event_ski',
          sportCategory: 'ski',
          attendees: [
            {'id': 'athlete_1', 'attendanceStatus': 'present'}
          ],
        ),
      ],
      sessions: [
        _session(
          athleteId: 'athlete_1',
          id: 'ski_programmed',
          sportId: 'alpine_skiing',
          duration: '01:00:00',
          eventId: 'event_ski',
          details: _skiDetails(),
        ),
        _session(
          athleteId: 'athlete_1',
          id: 'ski_extra',
          sportId: 'alpine_skiing',
          duration: '00:30:00',
          details: _skiDetails(),
        ),
      ],
    );

    final athlete = report.athletes.single;
    expect(athlete.skiPresence, 1);
    expect(athlete.scheduledSkiHours, 1);
    expect(athlete.outOfProgramSkiHours, 0.5);
    expect(athlete.clDirectionChanges, 40);
    expect(athlete.slDirectionChanges, 120);
    expect(athlete.addestramentoDirectionChanges, 16);
    expect(athlete.totalDirectionChanges, 176);
  });

  test('calcola presenza partial come 0.5', () {
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: const [
        TeamReportAthleteProfile(
            id: 'athlete_1', firstName: 'Ada', lastName: 'Rossi'),
      ],
      events: [
        _event(
          id: 'event_dryland',
          sportCategory: 'dryland',
          attendees: [
            {'id': 'athlete_1', 'attendanceStatus': 'partial'}
          ],
        ),
      ],
      sessions: const [],
    );

    expect(report.athletes.single.athleticPresence, 0.5);
  });

  test('usa evento coach completato come fallback se manca la sessione', () {
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: const [
        TeamReportAthleteProfile(
          id: 'athlete_1',
          firstName: 'Ada',
          lastName: 'Rossi',
        ),
      ],
      events: [
        _event(
          id: 'event_ski',
          sportCategory: 'ski',
          attendees: [
            {
              'id': 'athlete_1',
              'attendanceStatus': 'present',
              'freeLaps': 2,
            }
          ],
        ),
      ],
      sessions: const [],
    );

    final athlete = report.athletes.single;
    expect(athlete.hasAnyData, isTrue);
    expect(athlete.scheduledSkiHours, 1);
  });

  test('nessuna sessione programmata produce presenza non disponibile', () {
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: const [
        TeamReportAthleteProfile(
            id: 'athlete_1', firstName: 'Ada', lastName: 'Rossi'),
      ],
      events: const [],
      sessions: const [],
    );

    expect(report.athletes.single.skiPresence, isNull);
    expect(report.athletes.single.athleticPresence, isNull);
  });

  test('calcola volume forza, drill e metri resistenza', () {
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: const [
        TeamReportAthleteProfile(
            id: 'athlete_1', firstName: 'Ada', lastName: 'Rossi'),
      ],
      events: const [],
      sessions: [
        _session(
          athleteId: 'athlete_1',
          id: 'dryland_1',
          sportId: 'athletic_prep',
          duration: '01:15:00',
          details: {
            'schemaVersion': 2,
            'activityDomain': 'dryland',
            'activityCategory': ActivityCategory.athleticPrep,
            'status': ActivityStatus.completed,
            'blocks': [
              {
                'id': 'strength_1',
                'type': TrainingBlockType.strength,
                'name': 'Forza',
                'exercises': [
                  {
                    'exerciseId': 'back_squat',
                    'name': 'Back Squat',
                    'sets': [
                      {'setNumber': 1, 'kg': 100, 'reps': 5},
                      {'setNumber': 2, 'kg': 80, 'reps': 4},
                    ],
                  }
                ],
              },
              {
                'id': 'speed_1',
                'type': TrainingBlockType.speedAgility,
                'name': 'Agilita',
                'drills': [
                  {'name': 'Navetta', 'sets': 2, 'reps': 3}
                ],
              },
              {
                'id': 'endurance_1',
                'type': TrainingBlockType.endurance,
                'name': 'Corsa',
                'endurance': {
                  'durationSeconds': 900,
                  'distanceKm': 2.5,
                },
              },
            ],
          },
        ),
      ],
    );

    final athlete = report.athletes.single;
    expect(athlete.totalAthleticHours, 1.25);
    expect(athlete.strengthVolumeKg, 820);
    expect(athlete.strengthSets, 2);
    expect(athlete.drillCount, 1);
    expect(athlete.enduranceMeters, 2500);
  });

  test('genera alert per dati mancanti e asimmetria salto', () {
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: const [
        TeamReportAthleteProfile(
            id: 'athlete_1', firstName: 'Ada', lastName: 'Rossi'),
        TeamReportAthleteProfile(
            id: 'athlete_2', firstName: 'Luca', lastName: 'Bianchi'),
      ],
      events: const [],
      sessions: [
        _session(
          athleteId: 'athlete_1',
          id: 'ski_without_details',
          sportId: 'alpine_skiing',
          duration: '00:00:00',
        ),
      ],
      jumpLogs: const [
        TeamReportMetricLog(
          athleteId: 'athlete_1',
          date: '2026-06-10',
          type: 'single_leg_left',
          value: 40,
        ),
        TeamReportMetricLog(
          athleteId: 'athlete_1',
          date: '2026-06-10',
          type: 'single_leg_right',
          value: 34,
        ),
      ],
    );

    final athlete = report.athletes.first;
    expect(
        athlete.alerts.map((alert) => alert.type), contains('incomplete_data'));
    expect(
        athlete.alerts.map((alert) => alert.type), contains('jump_asymmetry'));
    expect(report.summary.incompleteDataCount, greaterThan(0));
  });

  test('calcola delta rispetto al mese precedente', () {
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: const [
        TeamReportAthleteProfile(
            id: 'athlete_1', firstName: 'Ada', lastName: 'Rossi'),
      ],
      events: const [],
      sessions: [
        _session(
          athleteId: 'athlete_1',
          id: 'current',
          sportId: 'alpine_skiing',
          date: '2026-06-02',
          duration: '01:00:00',
          details: _skiDetails(),
        ),
        _session(
          athleteId: 'athlete_1',
          id: 'previous',
          sportId: 'alpine_skiing',
          date: '2026-05-02',
          duration: '00:30:00',
          details: _skiDetails(),
        ),
      ],
      jumpLogs: const [
        TeamReportMetricLog(
          athleteId: 'athlete_1',
          date: '2026-05-10',
          type: 'cm_jump',
          value: 35,
        ),
        TeamReportMetricLog(
          athleteId: 'athlete_1',
          date: '2026-06-10',
          type: 'cm_jump',
          value: 40,
        ),
      ],
    );

    final athlete = report.athletes.single;
    expect(athlete.deltas['ski_hours']!.current, 1);
    expect(athlete.deltas['ski_hours']!.previous, 0.5);
    expect(athlete.deltas['cmj']!.absoluteDelta, 5);
  });

  test('genera un PDF non vuoto', () async {
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: const [
        TeamReportAthleteProfile(
            id: 'athlete_1', firstName: 'Ada', lastName: 'Rossi'),
      ],
      events: const [],
      sessions: [
        _session(
          athleteId: 'athlete_1',
          id: 'current',
          sportId: 'alpine_skiing',
          date: '2026-06-02',
          duration: '01:00:00',
          details: _skiDetails(),
        ),
      ],
    );

    const service = MonthlyTeamReportPdfService();
    final bytes = await service.buildPdf(report);

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}

Team _team() {
  return Team(
    id: 'team_1',
    name: 'Team Test',
    members: 1,
    category: 'Ski',
    image: '',
    inviteCode: 'TEST',
  );
}

CalendarEvent _event({
  required String id,
  required String sportCategory,
  List<Map<String, dynamic>> attendees = const [],
}) {
  return CalendarEvent(
    id: id,
    teamId: 'team_1',
    type: 'training',
    title: 'Allenamento',
    date: '2026-06-05',
    startTime: '09:00',
    endTime: '10:00',
    sportCategory: sportCategory,
    status: 'completed',
    attendees: attendees,
  );
}

TeamReportSession _session({
  required String athleteId,
  required String id,
  required String sportId,
  String date = '2026-06-05',
  String duration = '01:00:00',
  String? eventId,
  Map<String, dynamic>? details,
}) {
  return TeamReportSession(
    athleteId: athleteId,
    session: TrainingSession(
      id: id,
      sportId: sportId,
      date: date,
      startTime: '09:00',
      endTime: '10:00',
      duration: duration,
      effort: 5,
      eventId: eventId,
      details: details,
    ),
  );
}

Map<String, dynamic> _skiDetails() {
  return {
    'specialties': ['SL'],
    'freeSkiing': {'laps': 2, 'changes': 10},
    'tracks': [
      {'id': 'track_1', 'specialty': 'SL', 'laps': 2, 'gates': 30},
    ],
    'trainingBlocks': [
      {'id': 'training_1', 'specialty': 'SL', 'laps': 1, 'references': 8},
    ],
  };
}
