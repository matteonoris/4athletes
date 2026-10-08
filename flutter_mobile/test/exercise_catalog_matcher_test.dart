import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/workout_creation_models.dart';
import 'package:flutter_mobile/models/workout_document_import.dart';
import 'package:flutter_mobile/utils/exercise_catalog_matcher.dart';
import 'package:flutter_mobile/utils/strength_pr_utils.dart';
import 'package:flutter_mobile/utils/workout_document_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Italian synonyms and OCR punctuation resolve existing catalogue IDs',
      () {
    const names = {
      'Squat': 'back_squat',
      'BACK—SQUAT': 'back_squat',
      'Stacco da terra': 'deadlift',
      'Military press': 'ohp',
      ' PÁNCA   PIANA ': 'bp',
      'PancaPiana': 'bp',
      'Squat frontale': 'front_squat',
      'Stacco rumeno': 'rdl',
      'Panca piana con manubri': 'db_bp',
      'lat machine presa stretta': 'lat_pd_close',
    };
    for (final entry in names.entries) {
      expect(ExerciseCatalogMatcher.match(entry.key)?.id, entry.value,
          reason: entry.key);
    }
  });

  test('alternatives, unknown variants and shared aliases never auto-link', () {
    for (final name in [
      'Lat machine / Trazioni con zavorra',
      'Squat speciale del coach',
      'Squat con salto',
      'Sprint ABC',
      'Cable pull-through',
      ''
    ]) {
      expect(ExerciseCatalogMatcher.match(name), isNull, reason: name);
    }
    final suggestions =
        ExerciseCatalogMatcher.search('Lat machine / Trazioni con zavorra');
    expect(
        suggestions.map((e) => e.id), containsAll(['lat_pulldown', 'pullup']));
  });

  test('spelling mistakes suggest candidates without choosing an identity', () {
    expect(ExerciseCatalogMatcher.match('Sqaut'), isNull);
    expect(ExerciseCatalogMatcher.search('Sqaut').first.id, 'back_squat');
    expect(ExerciseCatalogMatcher.search('Militari press').first.id, 'ohp');
  });

  test('linked import retains values and the identity used by PR history', () {
    final imported =
        WorkoutDocumentParser.parse('Squat 3x8 60kg rec 90s RPE 7 RIR 2')
            .exercises
            .single;
    final block = WorkoutBlockDraft.fromJson(
        imported.toBlock(id: 'imported', order: 0).toJson());
    expect(block.title, 'Back Squat');
    expect(block.fields['exerciseId'], 'back_squat');
    expect(block.fields['equipmentCategory'], 'barbell');
    expect(block.fields['targetMuscle'], 'Quadricipiti');
    expect(block.fields['activityCategory'], 'strength');
    expect(block.fields['isCustom'], false);
    expect(block.fields['sourceText'], 'Squat 3x8 60kg rec 90s RPE 7 RIR 2');
    final sets = block.fields['sets'] as List;
    expect(sets, hasLength(3));
    expect(sets.first, {
      'setNumber': 1,
      'reps': 8,
      'kg': 60.0,
      'restSeconds': 90,
      'rpe': 7.0,
      'rir': 2
    });
    final maximum = currentOneRepMaxForExercise(block.fields['exerciseId'], [
      PRLog(
          id: 'squat_pr',
          exerciseId: 'back_squat',
          date: '2026-09-01',
          weight: 120),
      PRLog(id: 'bench_pr', exerciseId: 'bp', date: '2026-09-02', weight: 80),
    ]);
    expect(maximum, 120);
    expect((sets.first['kg'] as num) / maximum * 100, 50);
  });

  test('linked speed exercise uses trial tracking without inventing defaults',
      () {
    final block = WorkoutDocumentParser.parse('Wall drill 3x20s')
        .exercises
        .single
        .toBlock(id: 'speed', order: 0);
    expect(block.fields['exerciseId'], 'speed_wall_march');
    expect(block.fields['trackingMode'], 'speed_agility');
    expect(block.fields['speedGroup'], isNotEmpty);
    final sets = block.fields['sets'] as List;
    expect(sets, hasLength(3));
    expect(sets.first['timeSeconds'], 20);
    expect(sets.first['restSeconds'], isNull);
    expect(sets.first['distanceMeters'], isNull);
  });

  test('explicit selection wins, custom choice stays custom, invalid IDs fail',
      () {
    final linked = const ImportedWorkoutExercise(
            name: 'Lat / Trazioni',
            series: 4,
            repetitions: [6],
            sourceText: 'originale',
            exerciseId: 'lat_pulldown')
        .toBlock(id: 'linked', order: 0);
    expect(linked.fields['exerciseId'], 'lat_pulldown');
    expect(linked.fields['sourceText'], 'originale');
    final custom = const ImportedWorkoutExercise(
            name: 'Squat',
            series: 3,
            sourceText: 'originale',
            useCatalog: false)
        .toBlock(id: 'custom', order: 0);
    expect(custom.fields['isCustom'], true);
    expect(custom.fields['exerciseId'], isNull);
    expect(custom.title, 'Squat');
    expect(
        () => const ImportedWorkoutExercise(
                name: 'Squat', series: 3, sourceText: '', exerciseId: 'missing')
            .toBlock(id: 'bad', order: 0),
        throwsStateError);
  });
}
