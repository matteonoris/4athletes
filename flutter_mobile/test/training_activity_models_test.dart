import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/services/training_activity_service.dart';
import 'package:flutter_mobile/utils/training_metrics_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainingActivity strengthActivity({
    String status = ActivityStatus.completed,
    List<ExerciseEntry>? exercises,
  }) {
    return TrainingActivity(
      id: 'activity_1',
      athleteId: 'athlete_1',
      source: ActivitySource.athlete,
      status: status,
      category: ActivityCategory.strength,
      sportType: 'weightlifting',
      title: 'Strength',
      date: '2026-06-01',
      startTime: '09:00',
      endTime: '10:00',
      duration: '60',
      blocks: [
        TrainingBlock(
          id: 'strength_1',
          type: TrainingBlockType.strength,
          name: 'Strength',
          exercises: exercises ??
              const [
                ExerciseEntry(
                  exerciseId: 'back_squat',
                  name: 'Back Squat',
                  sets: [
                    StrengthSet(setNumber: 1, kg: 100, reps: 5),
                    StrengthSet(setNumber: 2, kg: 110, reps: 3),
                  ],
                ),
              ],
        ),
      ],
    );
  }

  test('calcola volume forza kg', () {
    final summary = TrainingMetricsUtils.strengthSummary([
      strengthActivity(),
    ]);

    expect(summary.totalSets, 2);
    expect(summary.totalReps, 8);
    expect(summary.volumeKg, 830);
    expect(summary.maxLoadByExercise['back_squat'], 110);
  });

  test('somma esercizi unilaterali come righe separate destra e sinistra', () {
    final summary = TrainingMetricsUtils.strengthSummary([
      strengthActivity(
        exercises: const [
          ExerciseEntry(
            exerciseId: 'single_leg_rdl',
            name: 'Single-Leg RDL',
            unilateralMode: UnilateralMode.right,
            sets: [
              StrengthSet(
                setNumber: 1,
                kg: 30,
                reps: 8,
                side: TrainingSide.right,
              ),
            ],
          ),
          ExerciseEntry(
            exerciseId: 'single_leg_rdl',
            name: 'Single-Leg RDL',
            unilateralMode: UnilateralMode.left,
            sets: [
              StrengthSet(
                setNumber: 1,
                kg: 28,
                reps: 8,
                side: TrainingSide.left,
              ),
            ],
          ),
        ],
      ),
    ]);

    expect(summary.totalSets, 2);
    expect(summary.totalReps, 16);
    expect(summary.volumeKg, 464);
  });

  test('calcola contatti pliometrici con fallback reps', () {
    const activity = TrainingActivity(
      id: 'plyo_1',
      athleteId: 'athlete_1',
      source: ActivitySource.athlete,
      status: ActivityStatus.completed,
      category: ActivityCategory.plyometrics,
      title: 'Plyo',
      date: '2026-06-01',
      startTime: '10:00',
      endTime: '10:30',
      duration: '30',
      blocks: [
        TrainingBlock(
          id: 'plyo_block',
          type: TrainingBlockType.plyometrics,
          name: 'Plyometrics',
          plyometrics: [
            PlyometricEntry(
              exerciseName: 'Hurdle Hops',
              type: 'hurdle_hops',
              sets: [
                PlyometricSet(setNumber: 1, reps: 5),
                PlyometricSet(setNumber: 2, reps: 5, contacts: 8),
              ],
            ),
          ],
        ),
      ],
    );

    final summary = TrainingMetricsUtils.plyometricSummary([activity]);

    expect(summary.totalSets, 2);
    expect(summary.totalReps, 10);
    expect(summary.totalContacts, 13);
  });

  test('calcola zone cardio endurance da dati importati', () {
    final session = TrainingSession(
      id: 'run_1',
      sportId: 'running',
      date: '2026-06-02',
      startTime: '07:00',
      endTime: '08:00',
      duration: '60',
      effort: 5,
      details: const {
        'source': 'health_sync',
        'active_duration_seconds': 3600,
        'distance_meters': 10000,
        'hr_zones_seconds': [0, 300, 1200, 900, 600, 600],
      },
    );

    final summary =
        TrainingMetricsUtils.enduranceSummaryFromSessions([session]);

    expect(summary.durationSeconds, 3600);
    expect(summary.distanceKm, 10);
    expect(summary.zone23Seconds, 2100);
    expect(summary.zone45Seconds, 1200);
  });

  test('usa template come copia senza modificare originale', () {
    const service = TrainingActivityService();
    final original = strengthActivity();
    final template = service.saveActivityAsTemplate(
      original,
      templateId: 'template_1',
      name: 'Lower Body',
      ownerType: TemplateOwnerType.athlete,
      ownerId: 'athlete_1',
      createdBy: 'athlete_1',
      now: DateTime(2026, 6, 1),
    );

    final generated = service.instantiateTemplate(
      template,
      activityId: 'activity_copy',
      athleteId: 'athlete_1',
      date: '2026-06-03',
      startTime: '09:00',
      endTime: '10:00',
      duration: '60',
    );

    generated.blocks.first.exercises.first.sets.add(
      const StrengthSet(setNumber: 3, kg: 120, reps: 1),
    );

    expect(template.blocks.first.exercises.first.sets.length, 2);
    expect(generated.blocks.first.exercises.first.sets.length, 3);
  });

  test('marca attivita coach modificata dall atleta', () {
    const service = TrainingActivityService();
    final event = CalendarEvent(
      id: 'event_1',
      teamId: 'team_1',
      type: 'training',
      title: 'Forza coach',
      date: '2026-06-01',
      startTime: '09:00',
      endTime: '10:00',
      sportCategory: 'dryland',
      drylandSpecialty: 'strength',
      status: ActivityStatus.completed,
      technicalDetails: {
        'plannedDrylandSession': strengthActivity().toJson(),
      },
    );
    final details = service.buildCoachDrylandSessionDetails(event, {
      'id': 'athlete_1',
      'attendanceStatus': AttendanceStatus.present,
      'modifiedByAthlete': true,
      'actualDrylandDetails': strengthActivity()
          .copyWith(
            id: 'actual_1',
            athleteModified: true,
          )
          .toJson(),
    });

    expect(details['from_calendar'], isTrue);
    expect(details['createdByCoach'], isTrue);
    expect(details['athleteModified'], isTrue);
    expect(details['blocks'], isA<List>());
  });

  test('esclude attivita cancelled dalle statistiche', () {
    final summary = TrainingMetricsUtils.strengthSummary([
      strengthActivity(status: ActivityStatus.completed),
      strengthActivity(status: ActivityStatus.cancelled),
    ]);

    expect(summary.totalSets, 2);
    expect(summary.volumeKg, 830);
  });
}
