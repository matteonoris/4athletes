import 'package:flutter_mobile/models/workout_creation_models.dart';
import 'package:flutter_mobile/utils/workout_document_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uppercase units preserve minutes and kilometres', () {
    final exercise = WorkoutDocumentParser.parse(
      'Corsa 3 serie distanza 1 KM durata 2 MIN REC 2 MIN',
    ).exercises.single;
    expect(exercise.distanceMeters, 1000);
    expect(exercise.durationSeconds, 120);
    expect(exercise.restSeconds, 120);
  });
  test('compound times and variable loads remain unambiguous', () {
    final exercises = WorkoutDocumentParser.parse(
            'Plank 3x1\'30"\nPanca 3x8 40/45/50kg\nSquat 3x8+8 rec 60-90s')
        .exercises;
    expect(exercises[0].durationSeconds, 90);
    expect(exercises[1].kg, isNull);
    expect(exercises[1].warnings, isNotEmpty);
    expect(exercises[2].repetitions, isEmpty);
    expect(exercises[2].restSeconds, isNull);
  });
  test('extracts series, reps, decimal load, rest and effort without defaults',
      () {
    final result = WorkoutDocumentParser.parse(
        'Squat 3 x 10 42,5 kg rec 1\'30" RPE 7,5 RIR 2');
    final exercise = result.exercises.single;
    expect(exercise.name, 'Squat');
    expect(exercise.series, 3);
    expect(exercise.repetitions, [10]);
    expect(exercise.kg, 42.5);
    expect(exercise.restSeconds, 90);
    expect(exercise.rpe, 7.5);
    expect(exercise.rir, 2);
    final block = exercise.toBlock(id: 'test', order: 1);
    expect(block.isCompleted, false);
    expect((block.fields['sets'] as List).length, 3);
    expect((block.fields['sets'] as List).last['reps'], 10);
    expect(WorkoutBlockDraft.fromJson(block.toJson()).fields, block.fields);
  });

  test('preserves different repetitions for each set', () {
    final exercise =
        WorkoutDocumentParser.parse('Panca 3x12/10/8 60kg').exercises.single;
    final sets = exercise.toBlock(id: 'panca', order: 0).fields['sets'] as List;
    expect(sets.map((set) => set['reps']), [12, 10, 8]);
  });

  test('does not choose a repetition range or convert percentage to kg', () {
    final exercise =
        WorkoutDocumentParser.parse('Squat 4x8-12 70% 1RM').exercises.single;
    expect(exercise.repetitions, isEmpty);
    expect(exercise.kg, isNull);
    expect(exercise.warnings.length, greaterThanOrEqualTo(2));
    expect(exercise.notes, contains('70%'));
  });

  test('timed and distance repetitions do not become strength reps', () {
    final exercises = WorkoutDocumentParser.parse(
            'Plank 3 x 30" rec 20s\nSprint 4x200m rec 2min')
        .exercises;
    expect(exercises[0].durationSeconds, 30);
    expect(exercises[0].repetitions, isEmpty);
    expect(exercises[0].restSeconds, 20);
    expect(exercises[1].distanceMeters, 200);
    expect(exercises[1].restSeconds, 120);
  });

  test('Italian and English labelled prescriptions', () {
    final exercises = WorkoutDocumentParser.parse(
            'Affondi 3 serie 12 ripetizioni 16 kg\nRow sets: 4 reps: 8 rest 60')
        .exercises;
    expect(exercises[0].repetitions, [12]);
    expect(exercises[1].series, 4);
    expect(exercises[1].repetitions, [8]);
    expect(exercises[1].restSeconds, 60);
  });

  test('reads table with headers, including different column order', () {
    final exercise = WorkoutDocumentParser.parse(
            'Esercizio\tRipetizioni\tSerie\tPeso\tRecupero\nPanca piana\t10\t3\t40\t90')
        .exercises
        .single;
    expect(exercise.name, 'Panca piana');
    expect(exercise.series, 3);
    expect(exercise.repetitions, [10]);
    expect(exercise.kg, 40);
    expect(exercise.restSeconds, 90);
  });

  test('single-space table and timed column', () {
    final exercise = WorkoutDocumentParser.parse(
            'Esercizio Serie Durata Recupero\nPlank 3 30 60')
        .exercises
        .single;
    expect(exercise.durationSeconds, 30);
    expect(exercise.restSeconds, 60);
    expect(exercise.repetitions, isEmpty);
  });

  test('does not misalign incomplete tables', () {
    final result = WorkoutDocumentParser.parse(
        'Esercizio\tSerie\tRipetizioni\tPeso\tRecupero\nSquat\t3\t10\t60');
    expect(result.exercises, isEmpty);
    expect(result.unparsedLines, ['Squat\t3\t10\t60']);
  });

  test('restores table rows from column-ordered OCR geometry', () {
    Map<String, dynamic> span(String text, int x, int y) =>
        {'text': text, 'left': x, 'top': y, 'height': 20};
    final text = WorkoutDocumentParser.textFromPages([
      [
        span('Squat', 0, 100),
        span('Plank', 0, 140),
        span('3x10', 180, 102),
        span('3x30"', 180, 138)
      ],
    ]);
    expect(WorkoutDocumentParser.parse(text).exercises.map((e) => e.name),
        ['Squat', 'Plank']);
  });

  test('joins name and prescription split across adjacent lines', () {
    final result = WorkoutDocumentParser.parse('Scheda A\nSquat\n3x10 60kg');
    expect(result.exercises.single.name, 'Squat');
    expect(result.unparsedLines, ['Scheda A']);
  });

  test('does not infer missing load or sets from unrelated numbers', () {
    final result = WorkoutDocumentParser.parse(
        'Giorno 2\nSquat 3x10\nTelefono 3331234567\nCircuito 3x10');
    expect(result.exercises.length, 1);
    expect(result.exercises.single.kg, isNull);
    expect(result.exercises.single.restSeconds, isNull);
    expect(result.unparsedLines.length, 3);
  });

  test('invalid sets and inconsistent progressions require review', () {
    final exercises =
        WorkoutDocumentParser.parse('Squat 999x10\nPanca 4x12/10/8').exercises;
    expect(exercises.first.series, isNull);
    expect(() => exercises.first.toBlock(id: 'a', order: 0), throwsStateError);
    expect(exercises.last.repetitions, isEmpty);
  });

  test('exact catalog matches only; custom names keep original prescription',
      () {
    final exercise =
        WorkoutDocumentParser.parse('Squat speciale del coach 3x10')
            .exercises
            .single;
    final block = exercise.toBlock(id: 'custom', order: 0);
    expect(block.fields['isCustom'], true);
    expect(block.fields['exerciseId'], isNull);
    expect(block.fields['sourceText'], exercise.sourceText);
  });
}
