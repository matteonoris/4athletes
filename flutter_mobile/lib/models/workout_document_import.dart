import '../data/exercises.dart';
import '../utils/exercise_catalog_matcher.dart';
import 'workout_creation_models.dart';

/// Only values actually read (or explicitly corrected) belong in this draft.
class ImportedWorkoutExercise {
  final String name;
  final String? exerciseId;
  final bool useCatalog;
  final int? series;
  final List<int> repetitions;
  final double? kg;
  final int? restSeconds;
  final double? durationSeconds;
  final double? distanceMeters;
  final double? rpe;
  final int? rir;
  final String notes;
  final String sourceText;
  final List<String> warnings;

  const ImportedWorkoutExercise({
    required this.name,
    this.exerciseId,
    this.useCatalog = true,
    this.series,
    this.repetitions = const [],
    this.kg,
    this.restSeconds,
    this.durationSeconds,
    this.distanceMeters,
    this.rpe,
    this.rir,
    this.notes = '',
    required this.sourceText,
    this.warnings = const [],
  });

  ExerciseDef? get catalogExercise => !useCatalog
      ? null
      : exerciseId != null
          ? ExerciseCatalogMatcher.byId(exerciseId!)
          : ExerciseCatalogMatcher.match(name);

  WorkoutBlockDraft toBlock({required String id, required int order}) {
    if (name.trim().isEmpty ||
        series == null ||
        series! < 1 ||
        series! > 50 ||
        (repetitions.length > 1 && repetitions.length != series)) {
      throw StateError(
          'Controlla nome, serie e ripetizioni prima di importare.');
    }
    final catalog = catalogExercise;
    if (useCatalog && exerciseId != null && catalog == null) {
      throw StateError('Seleziona un esercizio presente nel catalogo.');
    }
    return WorkoutBlockDraft(
      id: id,
      kind: WorkoutBlockKind.exerciseSets,
      title: catalog?.name ?? name.trim(),
      order: order,
      fields: {
        if (catalog != null) 'exerciseId': catalog.id,
        if (catalog != null) 'targetMuscle': catalog.targetMuscle,
        if (catalog != null) 'equipmentCategory': catalog.category,
        if (catalog != null)
          'activityCategory': catalog.resolvedActivityCategory,
        if (catalog?.usesSpeedAgilityTracking == true)
          'trackingMode': 'speed_agility',
        if (catalog?.speedGroup != null) 'speedGroup': catalog!.speedGroup,
        'isCustom': catalog == null,
        'importSource': 'document_ocr',
        'sourceText': sourceText,
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
        'sets': List.generate(
            series!,
            (index) => <String, dynamic>{
                  'setNumber': index + 1,
                  if (repetitions.isNotEmpty)
                    'reps': repetitions.length == 1
                        ? repetitions.first
                        : repetitions[index],
                  if (kg != null) 'kg': kg,
                  if (restSeconds != null) 'restSeconds': restSeconds,
                  if (durationSeconds != null)
                    'durationSeconds': durationSeconds,
                  if (catalog?.usesSpeedAgilityTracking == true &&
                      durationSeconds != null)
                    'timeSeconds': durationSeconds,
                  if (distanceMeters != null) 'distanceMeters': distanceMeters,
                  if (rpe != null) 'rpe': rpe,
                  if (rir != null) 'rir': rir,
                }),
      },
    );
  }
}

class WorkoutDocumentImport {
  final String text;
  final List<ImportedWorkoutExercise> exercises;
  final List<String> unparsedLines;

  const WorkoutDocumentImport(
      {required this.text,
      required this.exercises,
      required this.unparsedLines});
}
