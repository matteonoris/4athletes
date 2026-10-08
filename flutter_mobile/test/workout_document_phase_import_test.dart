import 'package:flutter/material.dart';
import 'package:flutter_mobile/data/workout_catalog.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/models/workout_creation_models.dart';
import 'package:flutter_mobile/screens/workout_document_import_screen.dart';
import 'package:flutter_mobile/utils/workout_document_parser.dart';
import 'package:flutter_mobile/widgets/workout_phase_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final circuit in [false, true]) {
    testWidgets(
        'imports append without replacing ${circuit ? 'circuit children' : 'existing exercises'}',
        (tester) async {
      const existing = WorkoutBlockDraft(
          id: 'existing',
          kind: WorkoutBlockKind.exerciseSets,
          title: 'Esistente',
          order: 0);
      var phases = [
        WorkoutPhaseDraft(type: TrainingPhase.main, blocks: [
          if (circuit)
            const WorkoutBlockDraft(
                id: 'circuit',
                kind: WorkoutBlockKind.circuit,
                title: 'Circuito',
                order: 0,
                children: [existing])
          else
            existing,
        ])
      ];
      var changes = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: StatefulBuilder(
        builder: (context, setState) => WorkoutPhaseEditor(
          phases: phases,
          structureMode: WorkoutStructureMode.simple,
          editorKind:
              circuit ? WorkoutEditorKind.circuit : WorkoutEditorKind.strength,
          activityCategory: ActivityCategory.strength,
          suggestedExercises: const [],
          onChanged: (value) => setState(() {
            changes++;
            phases = value;
          }),
        ),
      )))));
      await tester.tap(find.byKey(const ValueKey('import_document_main')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(WorkoutDocumentImportScreen)))
          .pop();
      await tester.pumpAndSettle();
      expect(changes, 0);
      await tester.tap(find.byKey(const ValueKey('import_document_main')));
      await tester.pumpAndSettle();
      final imported = WorkoutDocumentParser.parse('Squat 3x10')
          .exercises
          .single
          .toBlock(id: 'imported', order: 0);
      Navigator.of(tester.element(find.byType(WorkoutDocumentImportScreen)))
          .pop([imported]);
      await tester.pumpAndSettle();
      final blocks =
          circuit ? phases.single.blocks.single.children : phases.single.blocks;
      expect(blocks.map((b) => b.id), ['existing', 'imported']);
      expect(blocks.map((b) => b.order), [0, 1]);
      expect(changes, 1);
    });
  }
}
