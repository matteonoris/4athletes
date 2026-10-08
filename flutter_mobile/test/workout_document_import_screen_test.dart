import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/workout_creation_models.dart';
import 'package:flutter_mobile/models/workout_document_import.dart';
import 'package:flutter_mobile/screens/workout_document_import_screen.dart';
import 'package:flutter_mobile/services/workout_document_service.dart';
import 'package:flutter_mobile/utils/workout_document_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/workout_table_spans.dart';

class FakeDocumentService extends WorkoutDocumentService {
  final String? text;
  final bool fail;
  FakeDocumentService(this.text, {this.fail = false});
  @override
  Future<WorkoutDocumentImport?> read(WorkoutDocumentSource source) async {
    if (fail) throw const FormatException('PDF non leggibile.');
    return text == null ? null : WorkoutDocumentParser.parse(text!);
  }
}

class TableDocumentService extends WorkoutDocumentService {
  @override
  Future<WorkoutDocumentImport?> read(WorkoutDocumentSource source) async =>
      WorkoutDocumentParser.parse(
          WorkoutDocumentParser.textFromPages([workoutTableSpans()]));
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        'catalog suggestions, edits and selection (${dark ? 'dark' : 'light'})',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      AppTheme.setThemeMode(dark ? AppTheme.darkMode : AppTheme.lightMode,
          platformBrightness: dark ? Brightness.dark : Brightness.light);
      List<WorkoutBlockDraft>? imported;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  child: const Text('Apri'),
                  onPressed: () async {
                    imported = await Navigator.of(context)
                        .push<List<WorkoutBlockDraft>>(
                      MaterialPageRoute(
                          builder: (_) => WorkoutDocumentImportScreen(
                                service: FakeDocumentService(
                                    'Sqaut 3x8 60kg rec 90s'),
                              )),
                    );
                  },
                ))),
      ));
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Galleria'));
      await tester.pumpAndSettle();
      final suggestion =
          find.byKey(const ValueKey('import_0_suggest_back_squat'));
      await tester.ensureVisible(suggestion);
      await tester.tap(suggestion);
      await tester.pumpAndSettle();
      expect(find.text('Collegato a: Back Squat'), findsOneWidget);
      final name = find.byKey(const ValueKey('import_0_name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Panca piana');
      await tester.pumpAndSettle();
      expect(find.text('Collegato a: Bench Press'), findsOneWidget);
      final pick = find.byKey(const ValueKey('import_0_catalog_pick'));
      await tester.ensureVisible(pick);
      await tester.tap(pick);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('import_catalog_search')),
          'panca piana con manubri');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('import_catalog_db_bp')));
      await tester.pumpAndSettle();
      expect(find.text('Collegato a: Dumbbell Bench Press'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm_document_import')));
      await tester.pumpAndSettle();
      expect(imported!.single.fields['exerciseId'], 'db_bp');
      expect(imported!.single.fields['equipmentCategory'], 'dumbbell');
      expect(imported!.single.fields['sourceText'], 'Sqaut 3x8 60kg rec 90s');
      expect(imported!.single.title, 'Dumbbell Bench Press');
      final sets = imported!.single.fields['sets'] as List;
      expect(sets, hasLength(3));
      expect(sets.first['reps'], 8);
      expect(sets.first['kg'], 60);
      expect(sets.first['restSeconds'], 90);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Canva table survives review and confirmation (${dark ? 'dark' : 'light'})',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      AppTheme.setThemeMode(dark ? AppTheme.darkMode : AppTheme.lightMode,
          platformBrightness: dark ? Brightness.dark : Brightness.light);
      List<WorkoutBlockDraft>? imported;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  child: const Text('Apri tabella'),
                  onPressed: () async {
                    imported = await Navigator.of(context)
                        .push<List<WorkoutBlockDraft>>(
                      MaterialPageRoute(
                          builder: (_) => WorkoutDocumentImportScreen(
                                service: TableDocumentService(),
                              )),
                    );
                  },
                ))),
      ));
      await tester.tap(find.text('Apri tabella'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Galleria'));
      await tester.pumpAndSettle();
      expect(find.text('Aggiungi 6 esercizi'), findsOneWidget);
      expect(
          tester
              .widget<TextFormField>(
                  find.byKey(const ValueKey('import_0_series')))
              .controller!
              .text,
          '5');
      expect(
          tester
              .widget<TextFormField>(
                  find.byKey(const ValueKey('import_0_reps')))
              .controller!
              .text,
          '3');
      expect(
          tester
              .widget<TextFormField>(find.byKey(const ValueKey('import_0_kg')))
              .controller!
              .text,
          '');
      await tester.tap(find.byKey(const ValueKey('confirm_document_import')));
      await tester.pumpAndSettle();
      expect(imported, hasLength(6));
      expect(imported!.map((e) => e.title), [
        'Back Squat',
        'Deadlift',
        'Cable pull-through',
        'Overhead Press (Barbell)',
        'Lat machine / Trazioni con zavorra',
        'Bench Press',
      ]);
      expect(imported!.map((e) => e.fields['exerciseId']),
          ['back_squat', 'deadlift', null, 'ohp', null, 'bp']);
      expect(imported!.map((e) => (e.fields['sets'] as List).length),
          [5, 5, 4, 5, 4, 4]);
      expect(imported!.first.fields['notes'], contains('65-75% 1RM'));
      expect(imported!.first.fields['notes'], contains("2'-3' minuti"));
      expect(
          imported![4].fields['notes'], contains('10%-20% del peso corporeo'));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'review, correction, selection and confirmation in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      AppTheme.setThemeMode(dark ? AppTheme.darkMode : AppTheme.lightMode,
          platformBrightness: dark ? Brightness.dark : Brightness.light);
      List<WorkoutBlockDraft>? imported;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  child: const Text('Apri'),
                  onPressed: () async {
                    imported = await Navigator.of(context)
                        .push<List<WorkoutBlockDraft>>(
                      MaterialPageRoute(
                          builder: (_) => WorkoutDocumentImportScreen(
                                service: FakeDocumentService(
                                    'Squat 3x10 50kg\nPlank 3x30"'),
                              )),
                    );
                  },
                ))),
      ));
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scegli PDF'));
      await tester.pumpAndSettle();
      expect(imported, isNull);
      expect(find.text('Aggiungi 2 esercizi'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('import_0_reps')));
      await tester.enterText(
          find.byKey(const ValueKey('import_0_reps')), '12/10/8');
      await tester.ensureVisible(find.byType(CheckboxListTile).last);
      await tester.tap(find.byType(CheckboxListTile).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm_document_import')));
      await tester.pumpAndSettle();
      expect(imported!.length, 1);
      expect(
          (imported!.single.fields['sets'] as List).map((set) => set['reps']),
          [12, 10, 8]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'renaming clears stale identity and choosing custom disables rematching',
      (tester) async {
    List<WorkoutBlockDraft>? imported;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  child: const Text('Apri'),
                  onPressed: () async => imported =
                      await Navigator.of(context).push<List<WorkoutBlockDraft>>(
                    MaterialPageRoute(
                        builder: (_) => WorkoutDocumentImportScreen(
                            service: FakeDocumentService('Squat 3x8'))),
                  ),
                )))));
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galleria'));
    await tester.pumpAndSettle();
    final name = find.byKey(const ValueKey('import_0_name'));
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Esercizio personale');
    await tester.pumpAndSettle();
    expect(find.text('Collegato a: Back Squat'), findsNothing);
    await tester.enterText(name, 'Squat');
    await tester.pumpAndSettle();
    final custom = find.byKey(const ValueKey('import_0_catalog_custom'));
    await tester.ensureVisible(custom);
    await tester.tap(custom);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_document_import')));
    await tester.pumpAndSettle();
    expect(imported!.single.fields['exerciseId'], isNull);
    expect(imported!.single.fields['isCustom'], true);
    expect(imported!.single.title, 'Squat');
  });

  testWidgets('invalid series cannot be confirmed and cancel never imports',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: WorkoutDocumentImportScreen(
            service: FakeDocumentService('Squat 999x10'))));
    await tester.tap(find.text('Galleria'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_document_import')));
    await tester.pumpAndSettle();
    expect(find.text('Indica le serie'), findsOneWidget);
    expect(find.text('Importa esercizi'), findsOneWidget);
  });

  testWidgets('cancelled picker and unreadable document have no confirm action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: WorkoutDocumentImportScreen(service: FakeDocumentService(null))));
    await tester.tap(find.text('Scegli PDF'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirm_document_import')), findsNothing);
    await tester.pumpWidget(MaterialApp(
        home: WorkoutDocumentImportScreen(
            key: UniqueKey(), service: FakeDocumentService(null, fail: true))));
    await tester.tap(find.text('Scegli PDF'));
    await tester.pumpAndSettle();
    expect(find.text('PDF non leggibile.'), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm_document_import')), findsNothing);
  });
}
