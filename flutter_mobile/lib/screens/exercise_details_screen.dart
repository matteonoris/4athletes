import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/custom_card.dart';
import '../widgets/primary_button.dart';

class ExerciseDetailsScreen extends StatefulWidget {
  final String exerciseId;

  const ExerciseDetailsScreen({super.key, required this.exerciseId});

  @override
  State<ExerciseDetailsScreen> createState() => _ExerciseDetailsScreenState();
}

class _ExerciseDetailsScreenState extends State<ExerciseDetailsScreen> {
  final _weightCtrl = TextEditingController();

  void _addPR() {
    if (_weightCtrl.text.isEmpty) return;
    final w = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    if (w != null) {
      final pr = PRLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        exerciseId: widget.exerciseId,
        date: DateTime.now().toIso8601String().split('T')[0],
        weight: w,
      );
      Provider.of<AppState>(context, listen: false).addPRLog(pr);
      _weightCtrl.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final prLogs = appState.prLogs
        .where((l) => l.exerciseId == widget.exerciseId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final currentMax =
        appState.userProfile?.oneRepMax?[widget.exerciseId] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseId.replaceAll('_', ' ').toUpperCase()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CustomCard(
            color: AppTheme.primary.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Massimale Attuale',
                    style: Theme.of(context).textTheme.titleLarge),
                Text('$currentMax kg',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: AppTheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          CustomCard(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'Nuovo PR (kg)...',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                PrimaryButton(text: 'Aggiungi', onPressed: _addPR),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Cronologia PR', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (prLogs.isEmpty)
            const Center(child: Text('Nessun PR registrato.'))
          else
            ...prLogs.map((log) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CustomCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(log.date,
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text('${log.weight} kg',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textHighEmphasis)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.error),
                          onPressed: () => appState.deletePRLog(log.id),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
