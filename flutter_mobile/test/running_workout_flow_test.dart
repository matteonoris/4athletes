import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/data/workout_catalog.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/models/workout_creation_models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/workout_flow_screen.dart';
import 'package:flutter_mobile/services/workout_draft_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://placeholder.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbmUifQ.placeholder',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
      );
    }
  });

  WorkoutBlockDraft intervalBlock(
    String id, {
    String workUnit = 'time',
    int repetitions = 4,
    int series = 1,
  }) {
    return WorkoutBlockDraft(
      id: id,
      kind: WorkoutBlockKind.interval,
      title: '4 x 4 min',
      order: 0,
      fields: {
        'workUnit': workUnit,
        if (workUnit == 'time') 'workSeconds': 240,
        if (workUnit == 'distance') 'workDistanceMeters': 1000,
        'repetitions': repetitions,
        'series': series,
        'repRecoveryUnit': 'time',
        'repRecoverySeconds': 180,
        if (series > 1) 'seriesRecoverySeconds': 300,
        'repRecoveryStyle': 'active',
      },
    );
  }

  List<WorkoutPhaseDraft> runningPhases(
    String mode, {
    bool withOuterPhases = false,
  }) {
    final main = mode == RunningWorkoutMode.intervals
        ? intervalBlock('interval_1')
        : WorkoutBlockDraft(
            id: 'main_1',
            kind: WorkoutBlockKind.sport,
            title: 'Lavoro principale',
            order: 0,
            fields: {
              if (mode == RunningWorkoutMode.fartlek)
                'notes': 'Variazioni 1 minuto forte e 2 minuti facili'
              else
                'distanceMeters': 8000,
            },
          );
    return [
      WorkoutPhaseDraft(
        type: TrainingPhase.warmup,
        isEnabled: withOuterPhases,
        blocks: withOuterPhases
            ? const [
                WorkoutBlockDraft(
                  id: 'warmup_1',
                  kind: WorkoutBlockKind.sport,
                  title: 'Riscaldamento',
                  order: 0,
                  fields: {'notes': 'Mobilita e corsa facile'},
                ),
              ]
            : const [],
      ),
      WorkoutPhaseDraft(type: TrainingPhase.main, blocks: [main]),
      const WorkoutPhaseDraft(
        type: TrainingPhase.cooldown,
        isEnabled: false,
      ),
    ];
  }

  WorkoutDraft runningDraft({
    String activityId = 'road_running',
    String mode = RunningWorkoutMode.free,
    String structure = WorkoutStructureMode.simple,
    String status = ActivityStatus.completed,
    List<WorkoutPhaseDraft>? phases,
  }) {
    return WorkoutDraft(
      id: 'running_draft',
      createdByUserId: 'user_1',
      creatorRole: status == ActivityStatus.planned ? 'coach' : 'athlete',
      title: 'Corsa del mattino',
      date: DateTime(2026, 7, 16),
      plannedStartTime: '09:00',
      plannedEndTime: '10:00',
      actualStartTime: '09:00',
      actualEndTime: '10:00',
      activityId: activityId,
      activityName: 'Corsa su strada',
      activityCategory: ActivityCategory.sport,
      editorKind: WorkoutEditorKind.endurance,
      activityMode: mode,
      status: status,
      structureMode: structure,
      source: status == ActivityStatus.planned
          ? WorkoutDataSource.planned
          : WorkoutDataSource.manual,
      runningSummary: const RunningSummaryDraft(distanceMeters: 12000),
      phases: phases ?? runningPhases(mode),
      updatedAt: DateTime(2026, 7, 16),
    );
  }

  Future<void> pumpRunningFlow(
    WidgetTester tester, {
    required WorkoutDraft draft,
    ThemeMode themeMode = ThemeMode.light,
    TrainingSession? imported,
  }) async {
    SharedPreferences.setMockInitialValues({});
    AppTheme.setThemeMode(
      themeMode == ThemeMode.dark ? AppTheme.darkMode : AppTheme.lightMode,
      platformBrightness:
          themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
    );
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: WorkoutFlowScreen(
            key: UniqueKey(),
            activity: WorkoutCatalog.byId(draft.activityId),
            initialDraft: draft,
            initialImport: imported,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('modello corsa v4', () {
    test('deriva passo e velocita e salva le chiavi canoniche', () {
      final workout = runningDraft();
      final summary = workout.runningSummary!.derivedForDuration(3600);
      final session = workout.toTrainingSession();

      expect(summary.avgPaceSecondsPerKm, 300);
      expect(summary.avgSpeedKmh, 12);
      expect(session.details?['schemaVersion'], 4);
      expect(session.details?['distance_meters'], 12000);
      expect(session.details?['avg_pace_sec_per_km'], 300);
      expect(session.details?['pace'], '5:00 min/km');
      expect(session.details?['avg_speed_kmh'], 12);
      expect(
        (session.details?['workoutDraft'] as Map)['runningSummary'],
        isA<Map>(),
      );
    });

    test('distanza manuale e opzionale ma deve essere positiva', () {
      final withoutDistance = runningDraft().copyWith(
        runningSummary: const RunningSummaryDraft(),
      );
      final invalidDistance = runningDraft().copyWith(
        runningSummary: const RunningSummaryDraft(distanceMeters: -1),
      );

      expect(withoutDistance.validateForStep(4), isEmpty);
      expect(
        invalidDistance.validateForStep(4),
        contains('La distanza deve essere maggiore di zero.'),
      );
    });

    test('scheda semplice ignora fasi e blocchi incompatibili', () {
      final simple = runningDraft().copyWith(
        phases: const [
          WorkoutPhaseDraft(type: TrainingPhase.main, blocks: []),
        ],
      );

      expect(simple.validateForStep(4), isEmpty);
      expect(simple.toTrainingSession().details?['blocks'], isEmpty);
      expect(
        (simple.toTrainingSession().details?['actual'] as Map)['phases'],
        isEmpty,
      );
    });

    test('valida piu blocchi e recuperi tra ripetute e serie', () {
      final valid = runningDraft(
        mode: RunningWorkoutMode.intervals,
        structure: WorkoutStructureMode.phased,
        phases: [
          const WorkoutPhaseDraft(
            type: TrainingPhase.warmup,
            isEnabled: false,
          ),
          WorkoutPhaseDraft(
            type: TrainingPhase.main,
            blocks: [
              intervalBlock('time', series: 2),
              intervalBlock('distance', workUnit: 'distance'),
            ],
          ),
          const WorkoutPhaseDraft(
            type: TrainingPhase.cooldown,
            isEnabled: false,
          ),
        ],
      );
      final invalidFields = Map<String, dynamic>.from(
        valid.phases[1].blocks.first.fields,
      )..remove('seriesRecoverySeconds');
      final invalid = valid.copyWith(
        phases: [
          valid.phases[0],
          valid.phases[1].copyWith(
            blocks: [
              valid.phases[1].blocks.first.copyWith(fields: invalidFields),
            ],
          ),
          valid.phases[2],
        ],
      );

      expect(valid.validateForStep(4), isEmpty);
      expect(
        invalid.validateForStep(4),
        contains('Inserisci la pausa tra le serie.'),
      );
    });

    test('mappa modalita legacy e conserva il vecchio id', () {
      for (final oldMode in const [
        'continuous',
        'zone_2',
        'tempo',
        'hill',
        'test',
        'custom',
      ]) {
        final restored = WorkoutDraft.fromJson({
          ...runningDraft().toJson(),
          'activityMode': oldMode,
        });
        expect(restored.activityMode, RunningWorkoutMode.free);
        expect(restored.legacyActivityMode, oldMode);
      }

      final intervalLegacy = WorkoutDraft.fromJson({
        ...runningDraft().toJson(),
        'activityMode': 'continuous',
        'phases': [
          WorkoutPhaseDraft(
            type: TrainingPhase.main,
            blocks: [intervalBlock('legacy')],
          ).toJson(),
        ],
      });
      expect(intervalLegacy.activityMode, RunningWorkoutMode.intervals);
      expect(intervalLegacy.legacyActivityMode, 'continuous');
    });

    test('preset secondari espongono solo i tre protocolli previsti', () {
      final presets = WorkoutCatalog.protocolsFor(
        'running',
        RunningWorkoutMode.intervals,
      );

      expect(
        presets.map((preset) => preset.id),
        ['norwegian_4x4', '30_30', '4x8_minutes'],
      );
      expect(presets.first.defaults['workUnit'], 'time');
      expect(presets.first.defaults['repRecoverySeconds'], 180);
      expect(presets[1].defaults['repetitions'], isNull);
      expect(presets.last.defaults['repRecoverySeconds'], isNull);
    });

    test('tutta la famiglia corsa usa le stesse tre modalita', () {
      for (final id in const [
        'running',
        'road_running',
        'trail_running',
        'running_treadmill',
        'track_field',
      ]) {
        final activity = WorkoutCatalog.byId(id);
        expect(
          activity.modes.map((mode) => mode.id),
          RunningWorkoutMode.values,
        );
        expect(activity.editorKind, WorkoutEditorKind.endurance);
      }
    });
  });

  group('import corsa', () {
    TrainingSession imported({
      String title = 'Morning run',
      Map<String, dynamic> details = const {},
    }) {
      return TrainingSession(
        id: 'health_run_1',
        sportId: 'road_running',
        date: '2026-07-16',
        startTime: '07:00',
        endTime: '08:00',
        duration: '60',
        effort: 5,
        details: {
          'source': 'health_sync',
          'source_name': 'Health Connect',
          'external_id': 'run_1',
          'title': title,
          ...details,
        },
      );
    }

    test('deduce prudentemente ripetute, Fartlek e fallback libero', () {
      expect(
        WorkoutDraftFactory.inferRunningMode(
            imported(title: 'Fartlek collinare')),
        RunningWorkoutMode.fartlek,
      );
      expect(
        WorkoutDraftFactory.inferRunningMode(
          imported(
            details: const {
              'imported_segments': [
                {'type': 'work'},
                {'type': 'recovery'},
              ],
            },
          ),
        ),
        RunningWorkoutMode.intervals,
      );
      expect(
        WorkoutDraftFactory.inferRunningMode(imported()),
        RunningWorkoutMode.free,
      );
    });

    test('applica totali importati senza creare ripetute dai giri', () {
      final session = imported(details: const {
        'distance_meters': 10000,
        'avg_pace_sec_per_km': 330,
        'avg_speed_kmh': 10.91,
        'avg_cadence_spm': 172,
        'imported_laps': [
          {'distanceMeters': 1000}
        ],
      });
      final applied = WorkoutDraftFactory.applyRunningImport(
        runningDraft(),
        session,
      );

      expect(applied.runningSummary?.source, RunningMetricSource.imported);
      expect(applied.runningSummary?.distanceMeters, 10000);
      expect(applied.runningSummary?.avgPaceSecondsPerKm, 330);
      expect(applied.activityMode, RunningWorkoutMode.free);
      expect(applied.structureMode, WorkoutStructureMode.simple);
      expect(applied.phases.expand((phase) => phase.blocks), isEmpty);
    });

    test('merge conserva note RPE struttura e aggiunge cadenza e giri', () {
      final manual = runningDraft(
        mode: RunningWorkoutMode.intervals,
        structure: WorkoutStructureMode.phased,
      ).copyWith(notes: 'Nota atleta', sessionRpe: 8);
      final merged = WorkoutExternalMergeService.merge(
        manual,
        imported(details: const {
          'distance_meters': 10000,
          'avg_pace_sec_per_km': 330,
          'avg_cadence_spm': 172,
          'imported_laps': [
            {'distanceMeters': 1000}
          ],
          'hr_reliable': false,
        }),
      );

      expect(merged.details?['notes'], 'Nota atleta');
      expect(merged.effort, 8);
      expect(merged.details?['blocks'], isNotEmpty);
      expect(merged.details?['avg_cadence_spm'], 172);
      expect(merged.details?['imported_laps'], hasLength(1));
      expect(merged.details?['hr_reliable'], isFalse);
    });
  });

  group('interfaccia corsa', () {
    testWidgets('modalita e schede sono leggibili in tema chiaro e scuro',
        (tester) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final mode in RunningWorkoutMode.values) {
          for (final structure in [
            WorkoutStructureMode.simple,
            WorkoutStructureMode.phased,
          ]) {
            await pumpRunningFlow(
              tester,
              draft: runningDraft(
                mode: mode,
                structure: structure,
                phases: runningPhases(mode),
              ),
              themeMode: theme,
            );

            expect(find.textContaining('Aggiungi segmento'), findsNothing);
            expect(
              find.byKey(const ValueKey('running_manual_metrics')),
              findsOneWidget,
            );
            if (structure == WorkoutStructureMode.simple) {
              expect(find.byKey(const ValueKey('content_step')), findsNothing);
            } else {
              expect(
                  find.byKey(const ValueKey('content_step')), findsOneWidget);
              expect(
                find.byKey(const ValueKey('running_phase_main')),
                findsOneWidget,
              );
              expect(
                find.byKey(const ValueKey('add_running_interval_block')),
                mode == RunningWorkoutMode.intervals
                    ? findsOneWidget
                    : findsNothing,
              );
            }
          }
        }
      }
    });

    testWidgets('mostra conferme prima di eliminare lavoro o fasi',
        (tester) async {
      await pumpRunningFlow(
        tester,
        draft: runningDraft(
          structure: WorkoutStructureMode.phased,
          phases: runningPhases(
            RunningWorkoutMode.free,
            withOuterPhases: true,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Fartlek'));
      await tester.pumpAndSettle();
      expect(find.text('Cambiare modalita?'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('structure_simple')),
      );
      await tester.tap(find.byKey(const ValueKey('structure_simple')));
      await tester.pumpAndSettle();
      expect(find.text('Passare alla scheda semplice?'), findsOneWidget);
      await tester.tap(find.text('Usa scheda semplice'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('content_step')), findsNothing);
    });

    testWidgets('distingue passo obiettivo coach e passo medio atleta',
        (tester) async {
      await pumpRunningFlow(
        tester,
        draft: runningDraft(
          mode: RunningWorkoutMode.intervals,
          structure: WorkoutStructureMode.phased,
          status: ActivityStatus.planned,
          phases: const [
            WorkoutPhaseDraft(
              type: TrainingPhase.warmup,
              isEnabled: false,
            ),
            WorkoutPhaseDraft(type: TrainingPhase.main),
            WorkoutPhaseDraft(
              type: TrainingPhase.cooldown,
              isEnabled: false,
            ),
          ],
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('add_running_interval_block')),
      );
      await tester.tap(
        find.byKey(const ValueKey('add_running_interval_block')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Passo obiettivo (min/km)'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      await pumpRunningFlow(
        tester,
        draft: runningDraft(
          mode: RunningWorkoutMode.intervals,
          structure: WorkoutStructureMode.phased,
          phases: const [
            WorkoutPhaseDraft(
              type: TrainingPhase.warmup,
              isEnabled: false,
            ),
            WorkoutPhaseDraft(type: TrainingPhase.main),
            WorkoutPhaseDraft(
              type: TrainingPhase.cooldown,
              isEnabled: false,
            ),
          ],
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('add_running_interval_block')),
      );
      await tester.tap(
        find.byKey(const ValueKey('add_running_interval_block')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Passo medio del blocco (min/km)'), findsOneWidget);
    });

    testWidgets(
        'riepilogo import nasconde battiti inaffidabili e campi manuali',
        (tester) async {
      final imported = TrainingSession(
        id: 'health_run_widget',
        sportId: 'road_running',
        date: '2026-07-16',
        startTime: '07:00',
        endTime: '08:00',
        duration: '60',
        effort: 5,
        details: const {
          'source': 'health_sync',
          'source_name': 'Garmin',
          'distance_meters': 10000,
          'avg_pace_sec_per_km': 360,
          'avg_speed_kmh': 10,
          'energy_total_kcal': 650,
          'elevation_meters': 120,
          'avg_cadence_spm': 170,
          'hr_reliable': false,
          'avg_hr': 150,
          'imported_laps': [
            {'distanceMeters': 1000},
            {'distanceMeters': 1000},
          ],
        },
      );
      await pumpRunningFlow(
        tester,
        draft: runningDraft(),
        imported: imported,
      );

      expect(
        find.byKey(const ValueKey('running_imported_metrics')),
        findsOneWidget,
      );
      expect(
          find.byKey(const ValueKey('running_distance_field')), findsNothing);
      expect(find.text('Garmin'), findsWidgets);
      expect(find.text('Cadenza'), findsOneWidget);
      expect(find.text('Giri / segmenti'), findsOneWidget);
      expect(find.textContaining('Frequenza cardiaca'), findsNothing);
    });
  });
}
