import 'package:flutter/material.dart';

import '../data/exercises.dart';
import '../utils/exercise_catalog_matcher.dart';

class ExerciseCatalogPicker extends StatefulWidget {
  final String initialQuery;
  final String? selectedId;
  const ExerciseCatalogPicker(
      {super.key, required this.initialQuery, this.selectedId});

  @override
  State<ExerciseCatalogPicker> createState() => _ExerciseCatalogPickerState();
}

class _ExerciseCatalogPickerState extends State<ExerciseCatalogPicker> {
  late final _search = TextEditingController(text: widget.initialQuery);
  late List<ExerciseDef> _results =
      ExerciseCatalogMatcher.search(widget.initialQuery);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .7,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Collega al catalogo',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('import_catalog_search'),
                    controller: _search,
                    decoration: InputDecoration(
                      labelText: 'Cerca esercizio',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: 'Mostra tutto il catalogo',
                        onPressed: () => setState(() {
                          _search.clear();
                          _results = ExerciseCatalogMatcher.search('');
                        }),
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                    onChanged: (value) => setState(
                        () => _results = ExerciseCatalogMatcher.search(value)),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                      child: _results.isEmpty
                          ? const Center(
                              child: Text(
                                  'Nessuna corrispondenza. Prova un altro nome o mostra tutto il catalogo.'))
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final exercise = _results[index];
                                return ListTile(
                                  key:
                                      ValueKey('import_catalog_${exercise.id}'),
                                  title: Text(exercise.name),
                                  subtitle: Text(exercise.targetMuscle),
                                  trailing: exercise.id == widget.selectedId
                                      ? const Icon(Icons.check)
                                      : null,
                                  onTap: () => Navigator.pop(context, exercise),
                                );
                              },
                            )),
                ]),
          ),
        ),
      );
}
