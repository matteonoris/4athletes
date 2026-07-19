import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/monthly_team_report_models.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/services/monthly_team_report_calculator.dart';
import 'package:flutter_mobile/services/monthly_team_report_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('calcola presenza solo sulle sedute a cui atleta è invitato', () {
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: const [
        TeamReportAthleteProfile(
          id: 'athlete_1',
          firstName: 'Ada',
          lastName: 'Rossi',
        ),
        TeamReportAthleteProfile(
          id: 'athlete_2',
          firstName: 'Luca',
          lastName: 'Bianchi',
        ),
      ],
      events: [
        _event(
          id: 'ski_ada',
          sportCategory: 'ski',
          attendees: const [
            {'id': 'athlete_1', 'attendanceStatus': 'present'},
          ],
        ),
        _event(
          id: 'ski_luca',
          sportCategory: 'ski',
          attendees: const [
            {'id': 'athlete_2', 'attendanceStatus': 'absent'},
          ],
        ),
      ],
      sessions: const [],
    );

    expect(report.athletes[0].skiPresence, 1);
    expect(report.athletes[1].skiPresence, 0);
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

  test('deduplica più sessioni atleta collegate allo stesso evento', () {
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
          attendees: const [
            {'id': 'athlete_1', 'attendanceStatus': 'present'},
          ],
        ),
      ],
      sessions: [
        _session(
          athleteId: 'athlete_1',
          id: 'session_short',
          sportId: 'alpine_skiing',
          duration: '01:00:00',
          eventId: 'event_ski',
          details: const {
            'tracks': [
              {'specialty': 'SL', 'laps': 1, 'gates': 50},
            ],
          },
        ),
        _session(
          athleteId: 'athlete_1',
          id: 'session_complete',
          sportId: 'alpine_skiing',
          duration: '02:00:00',
          eventId: 'event_ski',
          details: const {
            'tracks': [
              {'specialty': 'SL', 'laps': 1, 'gates': 100},
            ],
          },
        ),
      ],
    );

    final athlete = report.athletes.single;
    expect(athlete.sessionCount, 1);
    expect(athlete.scheduledSkiHours, 2);
    expect(athlete.totalDirectionChanges, 100);
  });

  test('esclude le sessioni atleta ancora pianificate', () {
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
      events: const [],
      sessions: [
        _session(
          athleteId: 'athlete_1',
          id: 'planned',
          sportId: 'running',
          details: const {'status': ActivityStatus.planned},
        ),
      ],
    );

    expect(report.athletes.single.sessionCount, 0);
    expect(report.athletes.single.hasAnyData, isFalse);
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

  test('media i dati tecnici di preparazione escludendo quelli mancanti', () {
    final athletes = List.generate(
      3,
      (index) => TeamReportAthleteProfile(
        id: 'athlete_$index',
        firstName: 'Atleta',
        lastName: '$index',
      ),
    );
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: athletes,
      events: const [],
      sessions: [
        _session(
          athleteId: 'athlete_0',
          id: 'strength_100',
          sportId: 'dryland_strength',
          details: _strengthDetails(100),
        ),
        _session(
          athleteId: 'athlete_1',
          id: 'strength_300',
          sportId: 'dryland_strength',
          details: _strengthDetails(300),
        ),
        _session(
          athleteId: 'athlete_2',
          id: 'missing_details',
          sportId: 'dryland_strength',
        ),
      ],
    );

    expect(report.athletic.validAthleteCount, 3);
    expect(report.athletic.averageStrengthVolumeKg, 200);
    expect(report.athletic.strengthVolumeCoverage, 2);
    expect(report.athletic.averageStrengthSets, 1);
    expect(report.athletic.strengthSetsCoverage, 2);
    expect(report.athletic.drillCoverage, 0);
    expect(report.athletic.enduranceCoverage, 0);
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

  test('conta una sola volta ore coach e usa medie atleta', () {
    final athletes = List.generate(
      8,
      (index) => TeamReportAthleteProfile(
        id: 'athlete_$index',
        firstName: 'Atleta',
        lastName: '$index',
      ),
    );
    final attendees = athletes
        .map((athlete) => {
              'id': athlete.id,
              'attendanceStatus': 'present',
            })
        .toList();
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: athletes,
      events: [
        _event(
          id: 'prep_team',
          sportCategory: 'dryland',
          startTime: '09:00',
          endTime: '10:30',
          attendees: attendees,
        ),
      ],
      sessions: athletes
          .map(
            (athlete) => _session(
              athleteId: athlete.id,
              id: 'prep_${athlete.id}',
              sportId: 'athletic_prep',
              duration: '01:30:00',
              eventId: 'prep_team',
            ),
          )
          .toList(),
    );

    expect(report.coachWorkload.completedPreparationSessions, 1);
    expect(report.coachWorkload.completedPreparationHours, 1.5);
    expect(report.athletic.averageAthleteHours, 1.5);
    expect(report.athletic.validAthleteCount, 8);
  });

  test('media i passaggi sci senza sommare tutti gli atleti', () {
    final athletes = List.generate(
      3,
      (index) => TeamReportAthleteProfile(
        id: 'skier_$index',
        firstName: 'Sciatore',
        lastName: '$index',
      ),
    );
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: athletes,
      events: [
        _event(
          id: 'ski_team',
          sportCategory: 'ski',
          attendees: athletes
              .map((athlete) => {
                    'id': athlete.id,
                    'attendanceStatus': 'present',
                  })
              .toList(),
        ),
      ],
      sessions: athletes
          .map(
            (athlete) => _session(
              athleteId: athlete.id,
              id: 'ski_${athlete.id}',
              sportId: 'alpine_skiing',
              eventId: 'ski_team',
              details: const {
                'specialties': ['SL'],
                'tracks': [
                  {'id': 'sl', 'specialty': 'SL', 'laps': 1, 'gates': 100},
                ],
              },
            ),
          )
          .toList(),
    );

    expect(report.coachWorkload.completedSkiSessions, 1);
    expect(report.coachWorkload.completedSkiHours, 1);
    expect(report.ski.averageDirectionChanges, 100);
    expect(report.ski.averageDirectionChangesByDiscipline['SL'], 100);
    expect(report.ski.validAthleteCount, 3);
    expect(report.ski.skiActiveAthleteCount, 3);
  });

  test('esclude eventi pianificati da ore coach e presenza', () {
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
      sessions: const [],
      events: [
        _event(
          id: 'future',
          sportCategory: 'ski',
          status: 'planned',
          attendees: const [
            {'id': 'athlete_1', 'attendanceStatus': 'pending'},
          ],
        ),
      ],
    );

    expect(report.coachWorkload.completedSessionCount, 0);
    expect(report.athletes.single.skiPresence, isNull);
  });

  test('costruisce sette mesi e allinea il mese corrente allo stesso giorno',
      () {
    final sessions = <TeamReportSession>[];
    for (var offset = 0; offset < 7; offset++) {
      final month = DateTime(2026, 7 - offset);
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      sessions.addAll([
        _session(
          athleteId: 'athlete_1',
          id: 'early_$key',
          sportId: 'running',
          date: '$key-10',
        ),
        _session(
          athleteId: 'athlete_1',
          id: 'late_$key',
          sportId: 'running',
          date: '$key-20',
        ),
      ]);
    }
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 7),
      generatedAt: DateTime(2026, 7, 16),
      athletes: const [
        TeamReportAthleteProfile(
          id: 'athlete_1',
          firstName: 'Ada',
          lastName: 'Rossi',
        ),
      ],
      sessions: sessions,
      events: const [],
    );

    final athlete = report.athletes.single;
    expect(athlete.trend, hasLength(7));
    expect(athlete.trend.every((point) => point.throughDay == 16), isTrue);
    expect(athlete.trend.every((point) => point.sessionCount == 1), isTrue);
  });

  test('usa il mese intero quando il periodo selezionato è concluso', () {
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      generatedAt: DateTime(2026, 7, 16),
      athletes: const [
        TeamReportAthleteProfile(
          id: 'athlete_1',
          firstName: 'Ada',
          lastName: 'Rossi',
        ),
      ],
      sessions: [
        _session(
          athleteId: 'athlete_1',
          id: 'late_month',
          sportId: 'running',
          date: '2026-06-28',
        ),
      ],
      events: const [],
    );

    expect(report.athletes.single.trend.last.throughDay, isNull);
    expect(report.athletes.single.trend.last.sessionCount, 1);
  });

  test('attiva alert volume solo con almeno due mesi personali validi', () {
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: const [
        TeamReportAthleteProfile(
          id: 'stable_baseline',
          firstName: 'Ada',
          lastName: 'Rossi',
        ),
        TeamReportAthleteProfile(
          id: 'single_baseline',
          firstName: 'Luca',
          lastName: 'Bianchi',
        ),
      ],
      events: const [],
      sessions: [
        _session(
          athleteId: 'stable_baseline',
          id: 'stable_april',
          sportId: 'alpine_skiing',
          date: '2026-04-10',
          details: _skiDetailsWithGates(100),
        ),
        _session(
          athleteId: 'stable_baseline',
          id: 'stable_may',
          sportId: 'alpine_skiing',
          date: '2026-05-10',
          details: _skiDetailsWithGates(100),
        ),
        _session(
          athleteId: 'stable_baseline',
          id: 'stable_june',
          sportId: 'alpine_skiing',
          date: '2026-06-10',
          details: _skiDetailsWithGates(20),
        ),
        _session(
          athleteId: 'single_baseline',
          id: 'single_may',
          sportId: 'alpine_skiing',
          date: '2026-05-10',
          details: _skiDetailsWithGates(100),
        ),
        _session(
          athleteId: 'single_baseline',
          id: 'single_june',
          sportId: 'alpine_skiing',
          date: '2026-06-10',
          details: _skiDetailsWithGates(20),
        ),
      ],
    );

    final stable = report.athletes[0].alerts.map((alert) => alert.type);
    final single = report.athletes[1].alerts.map((alert) => alert.type);
    expect(stable, contains('low_ski_volume'));
    expect(single, isNot(contains('low_ski_volume')));
  });

  test('separa preparazione altri sport e recupero', () {
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
      events: const [],
      sessions: [
        _session(
          athleteId: 'athlete_1',
          id: 'strength',
          sportId: 'dryland_strength',
        ),
        _session(
          athleteId: 'athlete_1',
          id: 'run',
          sportId: 'running',
        ),
        _session(
          athleteId: 'athlete_1',
          id: 'yoga',
          sportId: 'yoga',
        ),
      ],
    );

    final hours = report.athletes.single.hoursByMacro;
    expect(hours[MonthlyTrainingMacro.preparation], 1);
    expect(hours[MonthlyTrainingMacro.otherSports], 1);
    expect(hours[MonthlyTrainingMacro.recoveryOther], 1);
  });

  test('classifica anche il carico coach con le macro condivise', () {
    final report = calculator.build(
      team: _team(),
      month: DateTime(2026, 6),
      athletes: const [],
      sessions: const [],
      events: [
        _event(id: 'prep', sportCategory: 'dryland'),
        _event(id: 'sport', sportCategory: 'running'),
        _event(id: 'recovery', sportCategory: 'yoga'),
      ],
    );

    expect(report.coachWorkload.completedPreparationSessions, 1);
    expect(report.coachWorkload.completedPreparationHours, 1);
    expect(report.coachWorkload.completedOtherSportSessions, 2);
    expect(report.coachWorkload.completedOtherSportHours, 2);
  });

  test('genera PDF con e senza schede individuali e caratteri accentati',
      () async {
    final report = calculator.build(
      team: Team(
        id: 'team_1',
        name: 'Sci Élite',
        members: 1,
        category: 'Ski',
        image: '',
        inviteCode: 'TEST',
      ),
      month: DateTime(2026, 6),
      athletes: const [
        TeamReportAthleteProfile(
            id: 'athlete_1', firstName: 'Nicolò', lastName: 'Rössler'),
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
    final compact = await service.buildPdf(
      report,
      includeIndividualSheets: false,
    );
    final complete = await service.buildPdf(
      report,
      includeIndividualSheets: true,
    );

    expect(compact.length, greaterThan(100));
    expect(complete.length, greaterThan(compact.length));
    expect(String.fromCharCodes(complete.take(4)), '%PDF');
  });

  test('mantiene SG DH e SX nel report mensile team e atleta', () {
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
      events: const [],
      sessions: [
        _session(
          athleteId: 'athlete_1',
          id: 'speed_disciplines',
          sportId: 'alpine_skiing',
          details: {
            'specialties': ['SG', 'DH'],
            'freeSkiingBySpecialty': {
              'SG': {'laps': 2, 'changes': 8},
              'DH': {'laps': 1, 'changes': 6},
            },
            'tracks': [
              {'id': 'sg_1', 'specialty': 'SG', 'laps': 3, 'gates': 25},
              {'id': 'dh_1', 'specialty': 'DH', 'laps': 2, 'gates': 20},
              {'id': 'sx_1', 'specialty': 'SX', 'laps': 4, 'gates': 6},
            ],
          },
        ),
      ],
    );

    final athlete = report.athletes.single;
    expect(athlete.sgDirectionChanges, 75);
    expect(athlete.dhDirectionChanges, 40);
    expect(athlete.sxDirectionChanges, 24);
    expect(report.ski.averageDirectionChangesByDiscipline['SG'], 75);
    expect(report.ski.averageDirectionChangesByDiscipline['DH'], 40);
    expect(report.ski.averageDirectionChangesByDiscipline['SX'], 24);
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
  String date = '2026-06-05',
  String startTime = '09:00',
  String endTime = '10:00',
  String status = 'completed',
  Map<String, dynamic>? technicalDetails,
}) {
  return CalendarEvent(
    id: id,
    teamId: 'team_1',
    type: 'training',
    title: 'Allenamento',
    date: date,
    startTime: startTime,
    endTime: endTime,
    sportCategory: sportCategory,
    status: status,
    technicalDetails: technicalDetails,
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

Map<String, dynamic> _strengthDetails(double kg) {
  return {
    'schemaVersion': 2,
    'activityDomain': 'dryland',
    'activityCategory': ActivityCategory.strength,
    'status': ActivityStatus.completed,
    'blocks': [
      {
        'id': 'strength',
        'type': TrainingBlockType.strength,
        'name': 'Forza',
        'exercises': [
          {
            'exerciseId': 'back_squat',
            'name': 'Back Squat',
            'sets': [
              {'setNumber': 1, 'kg': kg, 'reps': 1},
            ],
          },
        ],
      },
    ],
  };
}

Map<String, dynamic> _skiDetailsWithGates(int gates) {
  return {
    'specialties': ['SL'],
    'tracks': [
      {'id': 'sl', 'specialty': 'SL', 'laps': 1, 'gates': gates},
    ],
  };
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
