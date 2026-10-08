import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/exercises.dart';
import '../models/workout_document_import.dart';
import '../services/workout_document_service.dart';
import '../utils/exercise_catalog_matcher.dart';
import '../utils/workout_document_parser.dart';
import '../widgets/exercise_catalog_picker.dart';

class WorkoutDocumentImportScreen extends StatefulWidget {
  final WorkoutDocumentService? service;
  const WorkoutDocumentImportScreen({super.key, this.service});

  @override
  State<WorkoutDocumentImportScreen> createState() =>
      _WorkoutDocumentImportScreenState();
}

class _WorkoutDocumentImportScreenState
    extends State<WorkoutDocumentImportScreen> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _entries = <_ReviewExercise>[];
  bool _busy = false;
  String? _error;
  WorkoutDocumentImport? _document;

  @override
  void dispose() {
    _text.dispose();
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _setDocument(WorkoutDocumentImport document) {
    for (final entry in _entries) {
      entry.dispose();
    }
    _entries.clear();
    _entries.addAll(document.exercises.map(_ReviewExercise.new));
    _document = document;
    _text.text = document.text;
  }

  Future<void> _read(WorkoutDocumentSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final document =
          await (widget.service ?? WorkoutDocumentService()).read(source);
      if (!mounted || document == null) return;
      setState(() => _setDocument(document));
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _error = switch (error.code) {
              'camera_access_denied' ||
              'photo_access_denied' =>
                'Consenti l’accesso nelle impostazioni del telefono oppure scegli un PDF.',
              'READ_FAILED' => error.message ??
                  'Documento non leggibile. Prova un altro file.',
              _ =>
                'Non è stato possibile leggere il file. Riprova con una foto nitida o un PDF non protetto.',
            });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Lettura non disponibile. Riprova dall’app aggiornata su Android o iPhone.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _confirm() {
    final valid = _form.currentState!.validate();
    // Collapsed advanced fields are not mounted in the Form.
    final invalid = _entries.where((entry) => entry.selected).any((entry) =>
        entry.fields.entries.any(
            (field) => entry.validate(field.key, field.value.text) != null));
    if (!valid || invalid) {
      setState(() => _error =
          'Controlla i valori degli esercizi selezionati, anche nei dettagli.');
      return;
    }
    final selected = _entries.where((entry) => entry.selected).toList();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    Navigator.pop(context, [
      for (var i = 0; i < selected.length; i++)
        selected[i].exercise.toBlock(id: 'document_${stamp}_$i', order: i),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final count = _entries.where((entry) => entry.selected).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Importa esercizi')),
      bottomNavigationBar: _entries.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton.icon(
                key: const ValueKey('confirm_document_import'),
                onPressed: _busy || count == 0 ? null : _confirm,
                icon: const Icon(Icons.playlist_add),
                label: Text(
                    'Aggiungi $count ${count == 1 ? 'esercizio' : 'esercizi'}'),
              ),
            ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
                'Fotografa la scheda del preparatore oppure scegli un’immagine o un PDF.'),
            const SizedBox(height: 8),
            Text(
                'Il documento viene letto sul telefono. Massimo 15 MB e 6 pagine PDF.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final item in const [
                (
                  WorkoutDocumentSource.camera,
                  Icons.camera_alt_outlined,
                  'Scatta foto'
                ),
                (
                  WorkoutDocumentSource.gallery,
                  Icons.photo_library_outlined,
                  'Galleria'
                ),
                (
                  WorkoutDocumentSource.pdf,
                  Icons.picture_as_pdf_outlined,
                  'Scegli PDF'
                ),
              ])
                OutlinedButton.icon(
                    onPressed: _busy ? null : () => _read(item.$1),
                    icon: Icon(item.$2),
                    label: Text(item.$3)),
            ]),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Lettura del documento in corso…')
                ]),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (_document != null) ...[
              const SizedBox(height: 16),
              Text('Controlla prima di aggiungere',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                  'La scheda descrive un programma: seleziona solo gli esercizi di questa sessione e correggi i valori con quelli effettivamente svolti. Nessun esercizio viene salvato automaticamente.'),
              const SizedBox(height: 12),
              if (_entries.isEmpty)
                const Text(
                    'Nessun esercizio riconosciuto con certezza. Puoi correggere il testo qui sotto usando, ad esempio, “Squat 3 x 10 40 kg rec 90s”.'),
              if (_document!.unparsedLines.isNotEmpty)
                Text(
                    '${_document!.unparsedLines.length} righe non trasformate in esercizi: controlla il testo completo, comprese intestazioni e note.'),
              ExpansionTile(
                title: const Text('Testo letto dal documento'),
                tilePadding: EdgeInsets.zero,
                children: [
                  TextField(
                      controller: _text,
                      minLines: 4,
                      maxLines: 12,
                      decoration: const InputDecoration(
                          labelText: 'Testo correggibile')),
                  TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _setDocument(
                                    WorkoutDocumentParser.parse(_text.text));
                              }),
                      child: const Text('Ricrea anteprima dal testo')),
                ],
              ),
              for (var i = 0; i < _entries.length; i++)
                _exerciseCard(_entries[i], i),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _exerciseCard(_ReviewExercise entry, int index) {
    return Card(
      key: ObjectKey(entry),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${index + 1}. ${entry.original.name}'),
            subtitle: const Text('Aggiungi alla sessione'),
            value: entry.selected,
            onChanged: _busy
                ? null
                : (value) => setState(() => entry.selected = value ?? false),
          ),
          if (entry.selected) ...[
            if (entry.original.warnings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(entry.original.warnings.join('\n'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary)),
              ),
            _field(entry, 'name', 'Esercizio'),
            _catalogLink(entry, index),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _field(entry, 'series', 'Serie')),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(entry, 'reps', 'Ripetizioni',
                      hint: '10 oppure 12/10/8')),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _field(entry, 'kg', 'Carico (kg)')),
              const SizedBox(width: 12),
              Expanded(child: _field(entry, 'rest', 'Recupero (s)')),
            ]),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Durata, distanza e altri dati'),
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: _field(entry, 'duration', 'Durata/serie (s)')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _field(entry, 'distance', 'Distanza/serie (m)')),
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _field(entry, 'rpe', 'RPE (0–10)')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(entry, 'rir', 'RIR')),
                  ]),
                  const SizedBox(height: 12),
                  _field(entry, 'notes', 'Note / prescrizione originale'),
                  const SizedBox(height: 8),
                ]),
            Text(entry.original.sourceText,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ]),
      ),
    );
  }

  Widget _catalogLink(_ReviewExercise entry, int index) {
    final catalog = entry.catalog;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          catalog == null
              ? 'Esercizio personalizzato: collega una voce per usare storico e massimali.'
              : 'Collegato a: ${catalog.name}',
          key: ValueKey('import_${index}_catalog_status'),
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (catalog == null &&
            entry.useCatalog &&
            entry.suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Possibili corrispondenze'),
          Wrap(spacing: 8, children: [
            for (final suggestion in entry.suggestions)
              ActionChip(
                key: ValueKey('import_${index}_suggest_${suggestion.id}'),
                label: Text(suggestion.name),
                onPressed: _busy
                    ? null
                    : () => setState(() => entry.choose(suggestion)),
              ),
          ]),
        ],
        Wrap(spacing: 8, children: [
          TextButton.icon(
            key: ValueKey('import_${index}_catalog_pick'),
            onPressed: _busy
                ? null
                : () async {
                    final exercise = await showModalBottomSheet<ExerciseDef>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => ExerciseCatalogPicker(
                        initialQuery: entry.fields['name']!.text,
                        selectedId: catalog?.id,
                      ),
                    );
                    if (!mounted || exercise == null) return;
                    setState(() => entry.choose(exercise));
                  },
            icon: const Icon(Icons.search),
            label: Text(
                catalog == null ? 'Cerca nel catalogo' : 'Cambia esercizio'),
          ),
          if (entry.useCatalog &&
              (catalog != null || entry.suggestions.isNotEmpty))
            TextButton(
              key: ValueKey('import_${index}_catalog_custom'),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        entry.useCatalog = false;
                        entry.catalog = null;
                      }),
              child: const Text('Mantieni personalizzato'),
            ),
        ]),
      ]),
    );
  }

  Widget _field(_ReviewExercise entry, String key, String label,
      {String? hint}) {
    return TextFormField(
      key: ValueKey('import_${_entries.indexOf(entry)}_$key'),
      controller: entry.fields[key],
      enabled: !_busy,
      minLines: key == 'notes' ? 2 : 1,
      maxLines: key == 'notes' ? 4 : 1,
      keyboardType: ['name', 'notes', 'reps'].contains(key)
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, hintText: hint),
      onChanged: key == 'name' ? (_) => setState(entry.rematch) : null,
      validator: (value) => entry.validate(key, value ?? ''),
    );
  }
}

class _ReviewExercise {
  final ImportedWorkoutExercise original;
  final Map<String, TextEditingController> fields;
  bool selected = true;
  ExerciseDef? catalog;
  bool useCatalog = true;
  List<ExerciseDef> suggestions = [];
  _ReviewExercise(this.original)
      : fields = {
          'name': TextEditingController(text: original.name),
          'series': TextEditingController(text: _display(original.series)),
          'reps': TextEditingController(text: original.repetitions.join('/')),
          'kg': TextEditingController(text: _display(original.kg)),
          'rest': TextEditingController(text: _display(original.restSeconds)),
          'duration':
              TextEditingController(text: _display(original.durationSeconds)),
          'distance':
              TextEditingController(text: _display(original.distanceMeters)),
          'rpe': TextEditingController(text: _display(original.rpe)),
          'rir': TextEditingController(text: _display(original.rir)),
          'notes': TextEditingController(text: original.notes),
        } {
    useCatalog = original.useCatalog;
    catalog = original.catalogExercise;
    _suggest();
  }

  void _suggest() {
    suggestions = catalog == null && useCatalog && _value('name').isNotEmpty
        ? ExerciseCatalogMatcher.search(_value('name'), limit: 3)
        : [];
  }

  void rematch() {
    useCatalog = true;
    catalog = ExerciseCatalogMatcher.match(_value('name'));
    _suggest();
  }

  void choose(ExerciseDef exercise) {
    catalog = exercise;
    useCatalog = true;
    fields['name']!.text = exercise.name;
    suggestions = [];
  }

  static String _display(num? value) => value == null
      ? ''
      : value == value.roundToDouble()
          ? '${value.toInt()}'
          : '$value';
  String _value(String key) => fields[key]!.text.trim();
  double? _number(String key) =>
      double.tryParse(_value(key).replaceAll(',', '.'));
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
  }

  String? validate(String key, String value) {
    if (!selected) return null;
    value = value.trim();
    if (key == 'name') return value.isEmpty ? 'Inserisci il nome' : null;
    if (key == 'notes') return null;
    if (key == 'reps') {
      if (value.isEmpty) return null;
      final reps = value.split('/').map((v) => int.tryParse(v.trim())).toList();
      if (reps.any((v) => v == null || v < 1 || v > 1000)) {
        return 'Usa 10 o 12/10/8';
      }
      if (reps.length > 1 && reps.length != _number('series')) {
        return 'Un valore per serie';
      }
      return null;
    }
    if (value.isEmpty) return key == 'series' ? 'Indica le serie' : null;
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null || !number.isFinite || number < 0) {
      return 'Valore non valido';
    }
    if (['series', 'rest', 'rir'].contains(key) &&
        number != number.roundToDouble()) {
      return 'Usa un intero';
    }
    if (key == 'series' && (number < 1 || number > 50)) {
      return 'Da 1 a 50 serie';
    }
    if (key == 'rpe' && number > 10) return 'Da 0 a 10';
    if (number > 100000) return 'Valore troppo alto';
    return null;
  }

  ImportedWorkoutExercise get exercise => ImportedWorkoutExercise(
        name: _value('name'),
        exerciseId: catalog?.id,
        useCatalog: useCatalog,
        series: _number('series')!.toInt(),
        repetitions: _value('reps').isEmpty
            ? []
            : _value('reps')
                .split('/')
                .map((v) => int.parse(v.trim()))
                .toList(),
        kg: _number('kg'),
        restSeconds: _number('rest')?.toInt(),
        durationSeconds: _number('duration'),
        distanceMeters: _number('distance'),
        rpe: _number('rpe'),
        rir: _number('rir')?.toInt(),
        notes: _value('notes'),
        sourceText: original.sourceText,
      );
}
