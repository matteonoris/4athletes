import 'dart:math';

import 'package:flutter_mobile/models/workout_creation_models.dart';
import 'package:flutter_mobile/utils/workout_document_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/workout_table_spans.dart';

void main() {
  for (final scale in [.5, 1.0, 2.0]) {
    test('Canva table: wrapped cells, no headers, scale $scale', () {
      final spans = workoutTableSpans()
          .map((span) => {
                ...span,
                for (final key in ['left', 'top', 'width', 'height'])
                  key: (span[key] as num) * scale,
              })
          .toList()
        ..shuffle(Random(42));
      final text = WorkoutDocumentParser.textFromPages([spans]);
      final document = WorkoutDocumentParser.parse(text);
      expect(
          document.exercises.map((e) => e.name),
          [
            'Squat',
            'Stacco',
            'Cable pull-through',
            'Military press',
            'Lat machine / Trazioni con zavorra',
            'Panca Piana',
          ],
          reason: text);
      expect(document.exercises.map((e) => e.series), [5, 5, 4, 5, 4, 4]);
      expect(document.exercises.map((e) => e.repetitions.single),
          [3, 2, 8, 5, 6, 5]);
      expect(document.exercises[0].notes, contains('65-75% 1RM'));
      expect(document.exercises[1].notes, contains('65-80% 1RM'));
      expect(document.exercises[2].notes, contains('40-55% 1RM'));
      expect(document.exercises[3].notes, contains('65%-75% 1RM'));
      expect(
          document.exercises[4].notes, contains('10%-20% del peso corporeo'));
      for (final exercise in document.exercises) {
        expect(exercise.kg, isNull);
        expect(exercise.restSeconds, isNull);
        expect(
            exercise.notes, contains("Recupero tra le serie di 2'-3' minuti"));
        expect(exercise.notes, contains('il recupero dovrà essere completo)'));
        expect(exercise.warnings.join(' '), contains('Recupero variabile'));
        final block = exercise.toBlock(id: exercise.name, order: 0);
        final saved = WorkoutBlockDraft.fromJson(block.toJson());
        expect(saved.fields['notes'], exercise.notes);
        expect((saved.fields['sets'] as List).length, exercise.series);
        expect((saved.fields['sets'] as List).first['reps'],
            exercise.repetitions.single);
      }
      expect(document.unparsedLines, contains('6X3'));
      // The editable text must reproduce the same preview.
      expect(
          WorkoutDocumentParser.parse(document.text)
              .exercises
              .map((e) => e.name),
          document.exercises.map((e) => e.name));
    });
  }

  test('splits native observations that merge distant cells into one line', () {
    final spans = workoutTableSpans();
    final names = ['A', '5×3 (65-', 'Squat'];
    final words = names
        .map((text) => spans.firstWhere((s) => s['text'] == text))
        .toList();
    spans.removeWhere((s) => words.contains(s));
    spans.add({
      'text': 'A 5×3 (65- Squat',
      'left': 130,
      'top': 744,
      'width': 665,
      'height': 71,
      'words': words,
    });
    final result = WorkoutDocumentParser.parse(
        WorkoutDocumentParser.textFromPages([spans]));
    expect(result.exercises.length, 6);
    expect(result.exercises.first.name, 'Squat');
    expect(result.exercises.first.repetitions, [3]);
  });

  test('also reconstructs wrapped names to the left of the prescription', () {
    final spans = [
      {
        'text': 'Lat machine / Trazioni',
        'left': 0,
        'top': 100,
        'width': 180,
        'height': 20
      },
      {
        'text': 'con zavorra',
        'left': 20,
        'top': 130,
        'width': 140,
        'height': 20
      },
      {
        'text': '4x6 (70% 1RM)',
        'left': 230,
        'top': 114,
        'width': 140,
        'height': 20
      },
    ];
    final result = WorkoutDocumentParser.parse(
        WorkoutDocumentParser.textFromPages([spans]));
    expect(result.exercises.single.name, 'Lat machine / Trazioni con zavorra');
    expect(result.exercises.single.series, 4);
  });

  test(
      'a missing name never borrows a neighbouring exercise or bodyweight note',
      () {
    final spans = workoutTableSpans()
      ..removeWhere((span) => [
            'Military press',
            'Lat machine / Trazioni',
            'con zavorra'
          ].contains(span['text']));
    final result = WorkoutDocumentParser.parse(
        WorkoutDocumentParser.textFromPages([spans]));
    expect(result.exercises.map((e) => e.name),
        ['Squat', 'Stacco', 'Cable pull-through', 'Panca Piana']);
    expect(result.exercises.map((e) => e.repetitions.single), [3, 2, 8, 5]);
  });

  test('partial native word boxes retain the complete recognized line', () {
    final text = WorkoutDocumentParser.textFromPages([
      [
        {
          'text': 'Squat 3x10 40kg',
          'left': 0,
          'top': 100,
          'width': 300,
          'height': 20,
          'words': [
            {'text': 'Squat', 'left': 0, 'top': 100, 'width': 60, 'height': 20},
            {
              'text': '3x10',
              'left': 200,
              'top': 100,
              'width': 60,
              'height': 20
            },
          ],
        }
      ],
    ]);
    expect(WorkoutDocumentParser.parse(text).exercises.single.kg, 40);
  });

  test('plain text may have the prescription before the exercise', () {
    final result = WorkoutDocumentParser.parse(
        'A\t5×3 (65-75% 1RM)\tSquat\n5X2 (65-80% 1RM) Stacco');
    expect(result.exercises.map((e) => e.name), ['Squat', 'Stacco']);
    expect(result.exercises.map((e) => e.repetitions.single), [3, 2]);
  });

  test('shared rest is inherited, explicit rest wins, sections reset it', () {
    final result = WorkoutDocumentParser.parse(
        'Recupero tra le serie di 2 minuti\nSquat 3x5\nPanca 3x8 rec 60s\n'
        'Giorno B\nAffondi 3x10\n\nStacco 3x5');
    expect(result.exercises.map((e) => e.restSeconds), [120, 60, null, null]);
    expect(result.exercises[1].notes, isNot(contains('2 minuti')));
  });

  test('rest context does not leak between PDF pages', () {
    final text = WorkoutDocumentParser.textFromPages([
      [
        {'text': 'Recupero 90s', 'left': 0, 'top': 0, 'height': 20},
        {'text': 'Squat 3x5', 'left': 0, 'top': 40, 'height': 20},
      ],
      [
        {'text': 'Panca 3x8', 'left': 0, 'top': 40, 'height': 20}
      ],
    ]);
    expect(
        WorkoutDocumentParser.parse(text).exercises.map((e) => e.restSeconds),
        [90, null]);
  });
}
