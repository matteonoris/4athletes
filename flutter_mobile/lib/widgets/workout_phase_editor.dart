import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/exercises.dart';
import '../data/workout_catalog.dart';
import '../models/training_activity_models.dart';
import '../models/workout_creation_models.dart';
import '../providers/app_state.dart';
import '../utils/strength_pr_utils.dart';

class WorkoutPhaseEditor extends StatelessWidget {
  final List<WorkoutPhaseDraft> phases;
  final String structureMode;
  final String editorKind;
  final String activityCategory;
  final List<String> suggestedExercises;
  final ValueChanged<List<WorkoutPhaseDraft>> onChanged;

  const WorkoutPhaseEditor({
    super.key,
    required this.phases,
    required this.structureMode,
    required this.editorKind,
    required this.activityCategory,
    required this.suggestedExercises,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final visiblePhases = structureMode == WorkoutStructureMode.simple
        ? phases.where((phase) => phase.type == TrainingPhase.main).toList()
        : phases;
    return Column(
      children: visiblePhases.map((phase) {
        final index = phases.indexOf(phase);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _phaseCard(context, phase, index),
        );
      }).toList(),
    );
  }

  Widget _phaseCard(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
  ) {
    final optional = phase.type != TrainingPhase.main;
    final primaryIsExercise = editorKind != WorkoutEditorKind.endurance;
    final speedTracking = activityCategory == ActivityCategory.speedAgility;
    final primaryIsConditioning = editorKind == WorkoutEditorKind.circuit &&
        phase.type == TrainingPhase.main;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _phaseIcon(phase.type),
                    size: 20,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TrainingPhase.label(phase.type),
                        style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        optional ? 'Opzionale' : 'Obbligatorio',
                        style: TextStyle(
                          color: AppTheme.textMediumEmphasis,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (optional)
                  Switch(
                    value: phase.isEnabled,
                    onChanged: (value) => _replacePhase(
                      phaseIndex,
                      phase.copyWith(isEnabled: value),
                    ),
                  ),
              ],
            ),
          ),
          if (phase.isEnabled) ...[
            Divider(height: 1, color: AppTheme.divider),
            if (phase.blocks.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  primaryIsExercise
                      ? speedTracking
                          ? 'Seleziona il primo drill dal catalogo.'
                          : 'Seleziona il primo esercizio dal catalogo.'
                      : 'Aggiungi il primo segmento della sessione.',
                  style: TextStyle(color: AppTheme.textMediumEmphasis),
                ),
              ),
            ...phase.blocks.asMap().entries.map(
                  (entry) => _blockRow(
                    context,
                    phase,
                    phaseIndex,
                    entry.value,
                    entry.key,
                  ),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: ValueKey('add_block_${phase.type}'),
                      onPressed: () => primaryIsConditioning
                          ? _addExerciseToConditioningBlock(
                              context,
                              phase,
                              phaseIndex,
                            )
                          : primaryIsExercise
                              ? _addExercise(context, phase, phaseIndex)
                              : _addGenericBlock(
                                  context,
                                  phase,
                                  phaseIndex,
                                  WorkoutBlockKind.sport,
                                ),
                      icon: Icon(
                        primaryIsExercise
                            ? Icons.add_circle_outline
                            : Icons.add_road,
                        size: 18,
                      ),
                      label: Text(primaryIsExercise
                          ? primaryIsConditioning
                              ? 'Aggiungi al blocco principale'
                              : speedTracking
                                  ? 'Aggiungi drill'
                                  : 'Aggiungi esercizio'
                          : 'Aggiungi segmento'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () =>
                        _chooseOtherBlock(context, phase, phaseIndex),
                    icon: const Icon(Icons.more_horiz, size: 18),
                    label: const Text('Altro'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _blockRow(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
    WorkoutBlockDraft block,
    int blockIndex,
  ) {
    final isExercise = _isExercise(block);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        children: [
          ListTile(
            key: ValueKey('workout_block_${block.id}'),
            contentPadding: const EdgeInsets.only(left: 12, right: 4),
            leading: Icon(
              _isSpeedExercise(block) ? Icons.speed : _blockIcon(block.kind),
              color: AppTheme.secondary,
            ),
            title: Text(
              block.title,
              style: TextStyle(
                color: AppTheme.textHighEmphasis,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _blockSummary(block),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 11,
              ),
            ),
            onTap: () => _editBlock(
              context,
              phase,
              phaseIndex,
              block,
              blockIndex,
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppTheme.textMediumEmphasis),
              onSelected: (action) => _blockAction(
                phase,
                phaseIndex,
                block,
                blockIndex,
                action,
              ),
              itemBuilder: (_) => [
                if (blockIndex > 0)
                  const PopupMenuItem(value: 'up', child: Text('Sposta su')),
                if (blockIndex < phase.blocks.length - 1)
                  const PopupMenuItem(value: 'down', child: Text('Sposta giu')),
                const PopupMenuItem(value: 'duplicate', child: Text('Duplica')),
                const PopupMenuItem(value: 'delete', child: Text('Elimina')),
              ],
            ),
          ),
          if (isExercise && _setsForBlock(block).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _compactSets(
                context,
                phase,
                phaseIndex,
                block,
                blockIndex,
                _setsForBlock(block),
              ),
            ),
          if (block.kind == WorkoutBlockKind.circuit ||
              (editorKind == WorkoutEditorKind.circuit &&
                  block.kind == WorkoutBlockKind.interval)) ...[
            Divider(height: 1, color: AppTheme.divider),
            if (block.children.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Text(
                  'Nessun esercizio nel blocco.',
                  style: TextStyle(color: AppTheme.textMediumEmphasis),
                ),
              ),
            ...block.children.asMap().entries.map(
                  (entry) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    title: Text(entry.value.title),
                    subtitle: Text(_blockSummary(entry.value)),
                    onTap: () => _editCircuitExercise(
                      context,
                      phase,
                      phaseIndex,
                      block,
                      blockIndex,
                      entry.key,
                    ),
                    trailing: IconButton(
                      tooltip: 'Rimuovi esercizio',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeCircuitExercise(
                        phase,
                        phaseIndex,
                        block,
                        blockIndex,
                        entry.key,
                      ),
                    ),
                  ),
                ),
            TextButton.icon(
              onPressed: () => _addCircuitExercise(
                context,
                phase,
                phaseIndex,
                block,
                blockIndex,
              ),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Aggiungi esercizio al blocco'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _compactSets(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
    WorkoutBlockDraft block,
    int blockIndex,
    List<Map<String, dynamic>> sets,
  ) {
    if (_isSpeedExercise(block)) {
      return _compactSpeedTrials(
        context,
        phase,
        phaseIndex,
        block,
        blockIndex,
        sets,
      );
    }
    const headerStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );
    return Column(
      children: [
        DefaultTextStyle(
          style: headerStyle.copyWith(color: AppTheme.textLowEmphasis),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 28, 5),
            child: Row(
              children: [
                SizedBox(width: 42, child: Text('SERIE')),
                SizedBox(width: 58, child: Text('KG')),
                SizedBox(width: 50, child: Text('REP')),
                SizedBox(width: 46, child: Text('RPE')),
                Expanded(child: Text('DETTAGLI')),
              ],
            ),
          ),
        ),
        ...sets.asMap().entries.map((entry) {
          final set = entry.value;
          final kg = _displayNumber(set['kg']);
          final reps = _displayNumber(set['reps']);
          final rpe = _displayNumber(set['rpe']);
          final details = _compactSetDetails(set);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: AppTheme.subtleFill,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: ValueKey('workout_set_${block.id}_${entry.key}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _editSingleSet(
                  context,
                  phase,
                  phaseIndex,
                  block,
                  blockIndex,
                  entry.key,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 58, child: Text(kg.isEmpty ? '—' : kg)),
                      SizedBox(
                        width: 50,
                        child: Text(reps.isEmpty ? '—' : reps),
                      ),
                      SizedBox(width: 46, child: Text(rpe.isEmpty ? '—' : rpe)),
                      Expanded(
                        child: Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textMediumEmphasis,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppTheme.textLowEmphasis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _compactSpeedTrials(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
    WorkoutBlockDraft block,
    int blockIndex,
    List<Map<String, dynamic>> trials,
  ) {
    const headerStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.4,
    );
    return Column(
      children: [
        DefaultTextStyle(
          style: headerStyle.copyWith(color: AppTheme.textLowEmphasis),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 28, 5),
            child: Row(
              children: [
                SizedBox(width: 42, child: Text('PROVA')),
                SizedBox(width: 64, child: Text('DIST. M')),
                SizedBox(width: 68, child: Text('TEMPO S')),
                Expanded(child: Text('RECUPERO')),
              ],
            ),
          ),
        ),
        ...trials.asMap().entries.map((entry) {
          final trial = entry.value;
          final distance = _displayNumber(trial['distanceMeters']);
          final time = _displayNumber(trial['timeSeconds']);
          final rest = _displayNumber(trial['restSeconds']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: AppTheme.subtleFill,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: ValueKey('workout_set_${block.id}_${entry.key}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _editSingleSet(
                  context,
                  phase,
                  phaseIndex,
                  block,
                  blockIndex,
                  entry.key,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 64, child: Text(distance)),
                      SizedBox(
                          width: 68, child: Text(time.isEmpty ? '—' : time)),
                      Expanded(
                        child: Text(
                          rest.isEmpty ? '—' : '$rest s',
                          style: TextStyle(
                            color: AppTheme.textMediumEmphasis,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppTheme.textLowEmphasis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _compactSetDetails(Map<String, dynamic> set) {
    final details = <String>[];
    final rir = _displayNumber(set['rir']);
    final rest = _displayNumber(set['restSeconds']);
    final side = set['side']?.toString() ?? TrainingSide.none;
    if (rir.isNotEmpty) details.add('RIR $rir');
    if (rest.isNotEmpty) details.add('${rest}s rec');
    if (side != TrainingSide.none) details.add(_sideLabel(side));
    return details.isEmpty ? 'Modifica' : details.join(' · ');
  }

  Future<void> _editSingleSet(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
    WorkoutBlockDraft block,
    int blockIndex,
    int setIndex,
  ) async {
    if (_isSpeedExercise(block)) {
      await _editSingleSpeedTrial(
        context,
        phase,
        phaseIndex,
        block,
        blockIndex,
        setIndex,
      );
      return;
    }
    final sets = _setsForBlock(block)
        .map((set) => Map<String, dynamic>.from(set))
        .toList();
    if (setIndex < 0 || setIndex >= sets.length) return;
    final editedSet = Map<String, dynamic>.from(sets[setIndex]);
    final exerciseId = block.fields['exerciseId']?.toString() ?? '';
    final appState = context.read<AppState>();
    final oneRepMax = exerciseId.isEmpty
        ? 0.0
        : currentOneRepMaxForExercise(
            exerciseId,
            appState.prLogs,
            profileOneRepMax: appState.userProfile?.oneRepMax,
          );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final kg = _asDouble(editedSet['kg']);
          final percent =
              oneRepMax > 0 && kg > 0 ? (kg / oneRepMax) * 100 : null;
          return AlertDialog(
            backgroundColor: AppTheme.card,
            title: Text('${block.title} · Serie ${setIndex + 1}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          '${block.id}_${setIndex}_single_kg',
                          editedSet['kg'],
                          'kg',
                          (value) => setDialogState(
                            () => editedSet['kg'] = value,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numberField(
                          '${block.id}_${setIndex}_single_reps',
                          editedSet['reps'],
                          'Ripetizioni',
                          (value) => setDialogState(
                            () => editedSet['reps'] = value?.round(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (oneRepMax > 0) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        percent == null
                            ? 'Ultimo massimale: ${_displayNumber(oneRepMax)} kg'
                            : '${percent.toStringAsFixed(1)}% del massimale (${_displayNumber(oneRepMax)} kg)',
                        style: TextStyle(
                          color: percent == null
                              ? AppTheme.textMediumEmphasis
                              : AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          '${block.id}_${setIndex}_single_rpe',
                          editedSet['rpe'],
                          'RPE',
                          (value) => setDialogState(
                            () => editedSet['rpe'] = value,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _numberField(
                          '${block.id}_${setIndex}_single_rir',
                          editedSet['rir'],
                          'RIR',
                          (value) => setDialogState(
                            () => editedSet['rir'] = value?.round(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _numberField(
                          '${block.id}_${setIndex}_single_rest',
                          editedSet['restSeconds'],
                          'Rec. s',
                          (value) => setDialogState(
                            () => editedSet['restSeconds'] = value?.round(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('${block.id}_${setIndex}_single_side'),
                    initialValue:
                        editedSet['side']?.toString() ?? TrainingSide.none,
                    decoration: const InputDecoration(labelText: 'Lato'),
                    items: const [
                      DropdownMenuItem(
                        value: TrainingSide.none,
                        child: Text('—'),
                      ),
                      DropdownMenuItem(
                        value: TrainingSide.both,
                        child: Text('Entrambi'),
                      ),
                      DropdownMenuItem(
                        value: TrainingSide.right,
                        child: Text('Destra'),
                      ),
                      DropdownMenuItem(
                        value: TrainingSide.left,
                        child: Text('Sinistra'),
                      ),
                      DropdownMenuItem(
                        value: TrainingSide.alternating,
                        child: Text('Alternato'),
                      ),
                    ],
                    onChanged: (value) => editedSet['side'] = value,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                key: const ValueKey('save_single_set_button'),
                onPressed: () {
                  final load = _asDouble(editedSet['kg']);
                  if (oneRepMax > 0 && load > 0) {
                    editedSet['percent1RM'] = (load / oneRepMax) * 100;
                  } else {
                    editedSet.remove('percent1RM');
                  }
                  Navigator.pop(dialogContext, editedSet);
                },
                child: const Text('Salva serie'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null) return;

    result['setNumber'] = setIndex + 1;
    sets[setIndex] = result;
    final fields = Map<String, dynamic>.from(block.fields)..['sets'] = sets;
    final blocks = phase.blocks.map((item) => item.copyWith()).toList();
    blocks[blockIndex] = block.copyWith(fields: fields);
    _replacePhase(phaseIndex, phase.copyWith(blocks: blocks));
  }

  Future<void> _editSingleSpeedTrial(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
    WorkoutBlockDraft block,
    int blockIndex,
    int trialIndex,
  ) async {
    final trials = _setsForBlock(block)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (trialIndex < 0 || trialIndex >= trials.length) return;
    final trial = Map<String, dynamic>.from(trials[trialIndex]);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('${block.title} · Prova ${trialIndex + 1}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      '${block.id}_${trialIndex}_single_distance',
                      trial['distanceMeters'],
                      'Distanza (m)',
                      (value) => trial['distanceMeters'] = value,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _numberField(
                      '${block.id}_${trialIndex}_single_time',
                      trial['timeSeconds'],
                      'Tempo (s)',
                      (value) => trial['timeSeconds'] = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      '${block.id}_${trialIndex}_single_rest',
                      trial['restSeconds'],
                      'Recupero (s)',
                      (value) => trial['restSeconds'] = value?.round(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _numberField(
                      '${block.id}_${trialIndex}_single_intensity',
                      trial['intensityPercent'],
                      'Intensita %',
                      (value) => trial['intensityPercent'] = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: trial['startType']?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'Tipo di partenza / segnale',
                ),
                onChanged: (value) => trial['startType'] = value.trim(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: trial['side']?.toString() ?? TrainingSide.none,
                decoration:
                    const InputDecoration(labelText: 'Lato / direzione'),
                items: const [
                  DropdownMenuItem(value: TrainingSide.none, child: Text('—')),
                  DropdownMenuItem(
                      value: TrainingSide.both, child: Text('Entrambi')),
                  DropdownMenuItem(
                      value: TrainingSide.right, child: Text('Destra')),
                  DropdownMenuItem(
                      value: TrainingSide.left, child: Text('Sinistra')),
                  DropdownMenuItem(
                      value: TrainingSide.alternating,
                      child: Text('Alternato')),
                ],
                onChanged: (value) => trial['side'] = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            key: const ValueKey('save_single_set_button'),
            onPressed: () => Navigator.pop(dialogContext, trial),
            child: const Text('Salva prova'),
          ),
        ],
      ),
    );
    if (result == null) return;
    result['setNumber'] = trialIndex + 1;
    _cleanEmptySpeedValues(result);
    trials[trialIndex] = result;
    final fields = Map<String, dynamic>.from(block.fields)..['sets'] = trials;
    final blocks = phase.blocks.map((item) => item.copyWith()).toList();
    blocks[blockIndex] = block.copyWith(fields: fields);
    _replacePhase(phaseIndex, phase.copyWith(blocks: blocks));
  }

  static String _sideLabel(String side) => switch (side) {
        TrainingSide.both => 'Entrambi',
        TrainingSide.right => 'DX',
        TrainingSide.left => 'SX',
        TrainingSide.alternating => 'Alternato',
        _ => '—',
      };

  Future<void> _addExercise(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
  ) async {
    final exercise = await _pickExercise(context, phase.type);
    if (exercise == null || !context.mounted) return;
    final block = _newExerciseBlock(exercise, phase.blocks.length);
    final edited = await _showExerciseDialog(context, block);
    if (edited == null) return;
    _replacePhase(
      phaseIndex,
      phase.copyWith(blocks: [...phase.blocks, edited]),
    );
  }

  Future<ExerciseDef?> _pickExercise(
    BuildContext context,
    String phaseType,
  ) async {
    final categories = _mainExerciseCategories();
    var available = exerciseDatabase.where((exercise) {
      return exerciseMatchesTrainingPhase(
        exercise,
        phase: phaseType,
        mainPhaseCategories: categories,
      );
    }).toList();
    if (available.isEmpty) available = exerciseDatabase.toList();
    return showModalBottomSheet<ExerciseDef>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      builder: (_) => _ExercisePickerSheet(
        exercises: available,
        suggestedExercises: suggestedExercises,
      ),
    );
  }

  Set<String> _mainExerciseCategories() {
    return switch (activityCategory) {
      ActivityCategory.strength => const {ActivityCategory.strength},
      ActivityCategory.plyometrics => const {ActivityCategory.plyometrics},
      ActivityCategory.speedAgility => const {ActivityCategory.speedAgility},
      ActivityCategory.endurance => const {ActivityCategory.endurance},
      ActivityCategory.mobility => const {ActivityCategory.mobility},
      ActivityCategory.core => const {ActivityCategory.core},
      _ => const <String>{},
    };
  }

  WorkoutBlockDraft _newExerciseBlock(ExerciseDef exercise, int order) {
    final isStrength =
        exercise.resolvedActivityCategory == ActivityCategory.strength;
    final isPlyometric =
        exercise.resolvedActivityCategory == ActivityCategory.plyometrics;
    final isSpeed = exercise.usesSpeedAgilityTracking;
    final speedTrials = exercise.defaultTrials ?? 4;
    final count = isStrength || isPlyometric ? 3 : 1;
    final defaultReps = isPlyometric ? 5 : (isStrength ? 8 : null);
    return WorkoutBlockDraft(
      id: 'exercise_${DateTime.now().microsecondsSinceEpoch}',
      kind: WorkoutBlockKind.exerciseSets,
      title: exercise.name,
      order: order,
      fields: {
        'exerciseId': exercise.id,
        'targetMuscle': exercise.targetMuscle,
        'equipmentCategory': exercise.category,
        'activityCategory': exercise.resolvedActivityCategory,
        if (isSpeed) 'trackingMode': ActivityCategory.speedAgility,
        if (isSpeed) 'speedGroup': exercise.speedGroup,
        'isCustom': false,
        'sets': List.generate(
          isSpeed ? speedTrials : count,
          (index) => {
            'setNumber': index + 1,
            if (!isSpeed) 'kg': null,
            if (!isSpeed) 'reps': defaultReps,
            if (!isSpeed) 'rpe': null,
            if (!isSpeed) 'rir': null,
            if (isSpeed) 'distanceMeters': exercise.defaultDistanceMeters,
            if (isSpeed) 'timeSeconds': null,
            if (isSpeed) 'intensityPercent': null,
            if (isSpeed) 'startType': null,
            'restSeconds': isSpeed
                ? exercise.defaultRestSeconds
                : (isStrength ? 120 : null),
            'side': TrainingSide.none,
          },
        ),
      },
    );
  }

  Future<WorkoutBlockDraft?> _showExerciseDialog(
    BuildContext context,
    WorkoutBlockDraft block,
  ) async {
    if (_isSpeedExercise(block)) {
      return _showSpeedExerciseDialog(context, block);
    }
    final exerciseId = block.fields['exerciseId']?.toString() ?? '';
    final appState = context.read<AppState>();
    final oneRepMax = exerciseId.isEmpty
        ? 0.0
        : currentOneRepMaxForExercise(
            exerciseId,
            appState.prLogs,
            profileOneRepMax: appState.userProfile?.oneRepMax,
          );
    final notes = TextEditingController(
      text: block.fields['notes']?.toString() ?? '',
    );
    final equipment = TextEditingController(
      text: block.fields['equipment']?.toString() ?? '',
    );
    final variant = TextEditingController(
      text: block.fields['variant']?.toString() ?? '',
    );
    final sets = _setsForBlock(block)
        .map((set) => Map<String, dynamic>.from(set))
        .toList();
    var showAdvanced = false;
    final result = await showDialog<WorkoutBlockDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
          title: Row(
            children: [
              const Icon(Icons.fitness_center, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(block.title)),
              IconButton(
                tooltip: 'Chiudi',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((block.fields['targetMuscle']?.toString() ?? '')
                      .isNotEmpty)
                    Text(
                      '${block.fields['targetMuscle']} · ${block.fields['equipmentCategory'] ?? ''}',
                      style: TextStyle(
                        color: AppTheme.textMediumEmphasis,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'SERIE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'KG',
                          style: TextStyle(
                            color: AppTheme.textMediumEmphasis,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'RIPETIZIONI',
                          style: TextStyle(
                            color: AppTheme.textMediumEmphasis,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...sets.asMap().entries.map(
                        (entry) => _setEditorRow(
                          block.id,
                          entry.key,
                          entry.value,
                          showAdvanced,
                          oneRepMax: oneRepMax,
                          onLoadChanged: () => setDialogState(() {}),
                          onRemove: sets.length == 1
                              ? null
                              : () => setDialogState(() {
                                    sets.removeAt(entry.key);
                                    _renumberSets(sets);
                                  }),
                        ),
                      ),
                  TextButton.icon(
                    onPressed: () => setDialogState(() {
                      final copy = sets.isEmpty
                          ? <String, dynamic>{}
                          : Map<String, dynamic>.from(sets.last);
                      copy['setNumber'] = sets.length + 1;
                      sets.add(copy);
                    }),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Aggiungi serie'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setDialogState(
                        () => showAdvanced = !showAdvanced,
                      ),
                      icon: Icon(showAdvanced ? Icons.expand_less : Icons.tune),
                      label: Text(showAdvanced
                          ? 'Nascondi opzioni'
                          : 'RPE, RIR, recupero e lato'),
                    ),
                  ),
                  if (showAdvanced) ...[
                    TextField(
                      controller: equipment,
                      decoration:
                          const InputDecoration(labelText: 'Attrezzatura'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: variant,
                      decoration: const InputDecoration(labelText: 'Variante'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration:
                        const InputDecoration(labelText: 'Note esercizio'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              key: const ValueKey('save_block_button'),
              onPressed: () {
                for (final set in sets) {
                  final kg = _asDouble(set['kg']);
                  if (oneRepMax > 0 && kg > 0) {
                    set['percent1RM'] = (kg / oneRepMax) * 100;
                  } else {
                    set.remove('percent1RM');
                  }
                }
                final fields = Map<String, dynamic>.from(block.fields)
                  ..['sets'] = sets
                  ..remove('reps')
                  ..remove('loadKg');
                _putOrRemove(fields, 'notes', notes.text);
                _putOrRemove(fields, 'equipment', equipment.text);
                _putOrRemove(fields, 'variant', variant.text);
                Navigator.pop(
                  dialogContext,
                  block.copyWith(fields: fields),
                );
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    notes.dispose();
    equipment.dispose();
    variant.dispose();
    return result;
  }

  Future<WorkoutBlockDraft?> _showSpeedExerciseDialog(
    BuildContext context,
    WorkoutBlockDraft block,
  ) async {
    final notes = TextEditingController(
      text: block.fields['notes']?.toString() ?? '',
    );
    final equipment = TextEditingController(
      text: block.fields['equipment']?.toString() ?? '',
    );
    final surface = TextEditingController(
      text: block.fields['surface']?.toString() ?? '',
    );
    final trials = _setsForBlock(block)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    var showAdvanced = false;
    final result = await showDialog<WorkoutBlockDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
          title: Row(
            children: [
              const Icon(Icons.speed, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(block.title)),
              IconButton(
                tooltip: 'Chiudi',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.fields['speedGroup']?.toString() ??
                        'Velocità e agilità',
                    style: TextStyle(
                      color: AppTheme.textMediumEmphasis,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ogni riga e una prova: registra distanza e, se disponibile, il tempo.',
                    style: TextStyle(
                      color: AppTheme.textMediumEmphasis,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(
                        width: 42,
                        child: Text(
                          'PROVA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'DISTANZA (M)',
                          style: TextStyle(
                            color: AppTheme.textMediumEmphasis,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'TEMPO (S)',
                          style: TextStyle(
                            color: AppTheme.textMediumEmphasis,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...trials.asMap().entries.map(
                        (entry) => _speedTrialEditorRow(
                          block.id,
                          entry.key,
                          entry.value,
                          showAdvanced,
                          onRemove: trials.length == 1
                              ? null
                              : () => setDialogState(() {
                                    trials.removeAt(entry.key);
                                    _renumberSets(trials);
                                  }),
                        ),
                      ),
                  TextButton.icon(
                    onPressed: () => setDialogState(() {
                      final copy = trials.isEmpty
                          ? <String, dynamic>{}
                          : Map<String, dynamic>.from(trials.last);
                      copy['setNumber'] = trials.length + 1;
                      copy['timeSeconds'] = null;
                      trials.add(copy);
                    }),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Aggiungi prova'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setDialogState(
                        () => showAdvanced = !showAdvanced,
                      ),
                      icon: Icon(showAdvanced ? Icons.expand_less : Icons.tune),
                      label: Text(
                        showAdvanced
                            ? 'Nascondi opzioni'
                            : 'Recupero, intensita, partenza e lato',
                      ),
                    ),
                  ),
                  if (showAdvanced) ...[
                    TextField(
                      controller: surface,
                      decoration:
                          const InputDecoration(labelText: 'Superficie'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: equipment,
                      decoration:
                          const InputDecoration(labelText: 'Attrezzatura'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Note drill'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              key: const ValueKey('save_block_button'),
              onPressed: () {
                for (final trial in trials) {
                  _cleanEmptySpeedValues(trial);
                }
                final fields = Map<String, dynamic>.from(block.fields)
                  ..['sets'] = trials
                  ..['activityCategory'] = ActivityCategory.speedAgility
                  ..['trackingMode'] = ActivityCategory.speedAgility
                  ..remove('reps')
                  ..remove('loadKg')
                  ..remove('recoverySeconds');
                _putOrRemove(fields, 'notes', notes.text);
                _putOrRemove(fields, 'equipment', equipment.text);
                _putOrRemove(fields, 'surface', surface.text);
                Navigator.pop(
                  dialogContext,
                  block.copyWith(fields: fields),
                );
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    notes.dispose();
    equipment.dispose();
    surface.dispose();
    return result;
  }

  Widget _speedTrialEditorRow(
    String blockId,
    int index,
    Map<String, dynamic> trial,
    bool showAdvanced, {
    VoidCallback? onRemove,
  }) {
    return Container(
      key: ValueKey('${blockId}_trial_$index'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: _numberField(
                  '${blockId}_${index}_distance',
                  trial['distanceMeters'],
                  'm',
                  (value) => trial['distanceMeters'] = value,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _numberField(
                  '${blockId}_${index}_time',
                  trial['timeSeconds'],
                  'secondi',
                  (value) => trial['timeSeconds'] = value,
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  tooltip: 'Rimuovi prova',
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline, size: 19),
                ),
              ),
            ],
          ),
          if (showAdvanced) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _numberField(
                    '${blockId}_${index}_rest',
                    trial['restSeconds'],
                    'Rec. s',
                    (value) => trial['restSeconds'] = value?.round(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(
                    '${blockId}_${index}_intensity',
                    trial['intensityPercent'],
                    'Intensita %',
                    (value) => trial['intensityPercent'] = value,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('${blockId}_${index}_start_type'),
              initialValue: trial['startType']?.toString() ?? '',
              decoration:
                  const InputDecoration(labelText: 'Partenza / segnale'),
              onChanged: (value) => trial['startType'] = value.trim(),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('${blockId}_${index}_speed_side'),
              initialValue: trial['side']?.toString() ?? TrainingSide.none,
              decoration: const InputDecoration(labelText: 'Lato / direzione'),
              items: const [
                DropdownMenuItem(value: TrainingSide.none, child: Text('—')),
                DropdownMenuItem(
                    value: TrainingSide.both, child: Text('Entrambi')),
                DropdownMenuItem(
                    value: TrainingSide.right, child: Text('Destra')),
                DropdownMenuItem(
                    value: TrainingSide.left, child: Text('Sinistra')),
                DropdownMenuItem(
                    value: TrainingSide.alternating, child: Text('Alternato')),
              ],
              onChanged: (value) => trial['side'] = value,
            ),
          ],
        ],
      ),
    );
  }

  Widget _setEditorRow(
    String blockId,
    int index,
    Map<String, dynamic> set,
    bool showAdvanced, {
    required double oneRepMax,
    required VoidCallback onLoadChanged,
    VoidCallback? onRemove,
  }) {
    final kg = _asDouble(set['kg']);
    final percent = oneRepMax > 0 && kg > 0 ? (kg / oneRepMax) * 100 : null;
    return Container(
      key: ValueKey('${blockId}_set_$index'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: _numberField(
                  '${blockId}_${index}_kg',
                  set['kg'],
                  'kg',
                  (value) {
                    set['kg'] = value;
                    if (oneRepMax > 0 && (value ?? 0) > 0) {
                      set['percent1RM'] = (value!.toDouble() / oneRepMax) * 100;
                    } else {
                      set.remove('percent1RM');
                    }
                    onLoadChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _numberField(
                  '${blockId}_${index}_reps',
                  set['reps'],
                  'rep',
                  (value) => set['reps'] = value?.round(),
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  tooltip: 'Rimuovi serie',
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline, size: 19),
                ),
              ),
            ],
          ),
          if (oneRepMax > 0) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                percent == null
                    ? 'Ultimo massimale: ${_displayNumber(oneRepMax)} kg'
                    : 'Ultimo massimale: ${_displayNumber(oneRepMax)} kg · ${percent.toStringAsFixed(1)}%',
                key: ValueKey('${blockId}_${index}_percent_1rm'),
                style: TextStyle(
                  color: percent == null
                      ? AppTheme.textMediumEmphasis
                      : AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (showAdvanced) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _numberField(
                    '${blockId}_${index}_rpe',
                    set['rpe'],
                    'RPE',
                    (value) => set['rpe'] = value,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(
                    '${blockId}_${index}_rir',
                    set['rir'],
                    'RIR',
                    (value) => set['rir'] = value?.round(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(
                    '${blockId}_${index}_rest',
                    set['restSeconds'],
                    'Rec. s',
                    (value) => set['restSeconds'] = value?.round(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('${blockId}_${index}_side'),
              initialValue: set['side']?.toString() ?? TrainingSide.none,
              decoration: const InputDecoration(labelText: 'Lato'),
              items: const [
                DropdownMenuItem(value: TrainingSide.none, child: Text('—')),
                DropdownMenuItem(
                    value: TrainingSide.both, child: Text('Entrambi')),
                DropdownMenuItem(
                    value: TrainingSide.right, child: Text('Destra')),
                DropdownMenuItem(
                    value: TrainingSide.left, child: Text('Sinistra')),
                DropdownMenuItem(
                    value: TrainingSide.alternating, child: Text('Alternato')),
              ],
              onChanged: (value) => set['side'] = value,
            ),
          ],
        ],
      ),
    );
  }

  Widget _numberField(
    String keyValue,
    dynamic value,
    String label,
    ValueChanged<num?> onChanged,
  ) {
    return TextFormField(
      key: ValueKey(keyValue),
      initialValue: _displayNumber(value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      ),
      onChanged: (raw) =>
          onChanged(num.tryParse(raw.trim().replaceAll(',', '.'))),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  Future<void> _chooseOtherBlock(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
  ) async {
    final kinds = <String>[
      if (editorKind == WorkoutEditorKind.endurance)
        WorkoutBlockKind.exerciseSets,
      WorkoutBlockKind.sport,
      WorkoutBlockKind.interval,
      WorkoutBlockKind.circuit,
      WorkoutBlockKind.timed,
      WorkoutBlockKind.recovery,
      WorkoutBlockKind.note,
    ];
    final kind = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Aggiungi altro contenuto'),
              subtitle: Text('Usa questi blocchi solo quando servono.'),
            ),
            ...kinds.map(
              (kind) => ListTile(
                leading: Icon(_blockIcon(kind), color: AppTheme.primary),
                title: Text(_conciseKindLabel(kind)),
                onTap: () => Navigator.pop(sheetContext, kind),
              ),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !context.mounted) return;
    if (kind == WorkoutBlockKind.exerciseSets) {
      await _addExercise(context, phase, phaseIndex);
      return;
    }
    await _addGenericBlock(context, phase, phaseIndex, kind);
  }

  Future<void> _addGenericBlock(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
    String kind,
  ) async {
    final block = WorkoutBlockDraft(
      id: 'block_${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      title: _defaultTitle(kind),
      order: phase.blocks.length,
      fields: _defaultFields(kind),
    );
    final edited = await _showGenericBlockDialog(context, block);
    if (edited == null) return;
    _replacePhase(
      phaseIndex,
      phase.copyWith(blocks: [...phase.blocks, edited]),
    );
  }

  Future<void> _editBlock(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
    WorkoutBlockDraft block,
    int blockIndex,
  ) async {
    final editFuture = _isExercise(block)
        ? _showExerciseDialog(context, block)
        : _showGenericBlockDialog(context, block);
    final edited = await editFuture;
    if (edited == null) return;
    final blocks = phase.blocks.map((item) => item.copyWith()).toList();
    blocks[blockIndex] = edited.copyWith(order: blockIndex);
    _replacePhase(phaseIndex, phase.copyWith(blocks: blocks));
  }

  Future<WorkoutBlockDraft?> _showGenericBlockDialog(
    BuildContext context,
    WorkoutBlockDraft block,
  ) async {
    final title = TextEditingController(text: block.title);
    final notes = TextEditingController(
      text: block.fields['notes']?.toString() ?? '',
    );
    final visibleFields = _visibleFields(block.kind)
        .where(
          (field) =>
              editorKind != WorkoutEditorKind.circuit ||
              block.fields.containsKey(field.$1),
        )
        .toList();
    final controllers = <String, TextEditingController>{};
    for (final field in visibleFields) {
      controllers[field.$1] = TextEditingController(
        text: block.fields[field.$1]?.toString() ?? '',
      );
    }
    var showAdvanced = false;
    final result = await showDialog<WorkoutBlockDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: Text(_conciseKindLabel(block.kind)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nome *'),
                ),
                const SizedBox(height: 12),
                ...visibleFields
                    .where((field) => !field.$3 || showAdvanced)
                    .map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: controllers[field.$1],
                          keyboardType: field.$2
                              ? const TextInputType.numberWithOptions(
                                  decimal: true,
                                )
                              : TextInputType.text,
                          decoration: InputDecoration(labelText: field.$4),
                        ),
                      ),
                    ),
                if (visibleFields.any((field) => field.$3))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setDialogState(() => showAdvanced = !showAdvanced),
                      icon: Icon(showAdvanced ? Icons.expand_less : Icons.tune),
                      label: Text(
                          showAdvanced ? 'Nascondi opzioni' : 'Altre opzioni'),
                    ),
                  ),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              key: const ValueKey('save_block_button'),
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                final fields = Map<String, dynamic>.from(block.fields);
                for (final field in visibleFields) {
                  final raw = controllers[field.$1]?.text.trim() ?? '';
                  if (raw.isEmpty) {
                    fields.remove(field.$1);
                  } else {
                    fields[field.$1] = field.$2
                        ? num.tryParse(raw.replaceAll(',', '.')) ?? raw
                        : raw;
                  }
                }
                _putOrRemove(fields, 'notes', notes.text);
                Navigator.pop(
                  dialogContext,
                  block.copyWith(title: title.text.trim(), fields: fields),
                );
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    notes.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _addExerciseToConditioningBlock(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
  ) async {
    final blockIndex = phase.blocks.indexWhere(
      (block) =>
          block.kind == WorkoutBlockKind.circuit ||
          block.kind == WorkoutBlockKind.interval,
    );
    if (blockIndex < 0) {
      await _addGenericBlock(
        context,
        phase,
        phaseIndex,
        WorkoutBlockKind.circuit,
      );
      return;
    }
    await _addCircuitExercise(
      context,
      phase,
      phaseIndex,
      phase.blocks[blockIndex],
      blockIndex,
    );
  }

  Future<void> _addCircuitExercise(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
    WorkoutBlockDraft circuit,
    int blockIndex,
  ) async {
    final exercise = await _pickExercise(context, phase.type);
    if (exercise == null || !context.mounted) return;
    final child = _newExerciseBlock(exercise, circuit.children.length);
    final edited = await _showExerciseDialog(context, child);
    if (edited == null) return;
    final blocks = phase.blocks.map((item) => item.copyWith()).toList();
    blocks[blockIndex] = circuit.copyWith(
      children: [...circuit.children, edited],
    );
    _replacePhase(phaseIndex, phase.copyWith(blocks: blocks));
  }

  Future<void> _editCircuitExercise(
    BuildContext context,
    WorkoutPhaseDraft phase,
    int phaseIndex,
    WorkoutBlockDraft circuit,
    int blockIndex,
    int childIndex,
  ) async {
    final edited =
        await _showExerciseDialog(context, circuit.children[childIndex]);
    if (edited == null) return;
    final children = circuit.children.map((item) => item.copyWith()).toList();
    children[childIndex] = edited.copyWith(order: childIndex);
    final blocks = phase.blocks.map((item) => item.copyWith()).toList();
    blocks[blockIndex] = circuit.copyWith(children: children);
    _replacePhase(phaseIndex, phase.copyWith(blocks: blocks));
  }

  void _removeCircuitExercise(
    WorkoutPhaseDraft phase,
    int phaseIndex,
    WorkoutBlockDraft circuit,
    int blockIndex,
    int childIndex,
  ) {
    final children = circuit.children.map((item) => item.copyWith()).toList()
      ..removeAt(childIndex);
    final ordered = children
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(order: entry.key))
        .toList();
    final blocks = phase.blocks.map((item) => item.copyWith()).toList();
    blocks[blockIndex] = circuit.copyWith(children: ordered);
    _replacePhase(phaseIndex, phase.copyWith(blocks: blocks));
  }

  void _blockAction(
    WorkoutPhaseDraft phase,
    int phaseIndex,
    WorkoutBlockDraft block,
    int blockIndex,
    String action,
  ) {
    final blocks = phase.blocks.map((item) => item.copyWith()).toList();
    switch (action) {
      case 'up':
        final item = blocks.removeAt(blockIndex);
        blocks.insert(blockIndex - 1, item);
      case 'down':
        final item = blocks.removeAt(blockIndex);
        blocks.insert(blockIndex + 1, item);
      case 'duplicate':
        blocks.insert(
          blockIndex + 1,
          block.copyWith(
            id: '${block.id}_copy_${DateTime.now().microsecondsSinceEpoch}',
          ),
        );
      case 'delete':
        blocks.removeAt(blockIndex);
    }
    final ordered = blocks
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(order: entry.key))
        .toList();
    _replacePhase(phaseIndex, phase.copyWith(blocks: ordered));
  }

  void _replacePhase(int index, WorkoutPhaseDraft phase) {
    final updated = phases.map((item) => item.copyWith()).toList();
    updated[index] = phase;
    onChanged(updated);
  }

  static List<Map<String, dynamic>> _setsForBlock(WorkoutBlockDraft block) {
    final raw = block.fields['sets'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map(
            (set) => set.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
          .toList();
    }
    final count = raw is num ? raw.round().clamp(1, 100) : 1;
    return List.generate(
      count,
      (index) => {
        'setNumber': index + 1,
        'kg': block.fields['loadKg'],
        'reps': block.fields['reps'],
        'rpe': block.fields['rpe'],
        'rir': block.fields['rir'],
        'restSeconds': block.fields['recoverySeconds'],
        'side': block.fields['side'] ?? TrainingSide.none,
      },
    );
  }

  static void _renumberSets(List<Map<String, dynamic>> sets) {
    for (var index = 0; index < sets.length; index++) {
      sets[index]['setNumber'] = index + 1;
    }
  }

  static void _putOrRemove(
    Map<String, dynamic> target,
    String key,
    String value,
  ) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      target.remove(key);
    } else {
      target[key] = normalized;
    }
  }

  static void _cleanEmptySpeedValues(Map<String, dynamic> trial) {
    for (final key in const [
      'distanceMeters',
      'timeSeconds',
      'restSeconds',
      'intensityPercent',
      'startType',
    ]) {
      final value = trial[key];
      if (value == null || value.toString().trim().isEmpty) {
        trial.remove(key);
      }
    }
  }

  static bool _isExercise(WorkoutBlockDraft block) =>
      block.kind == WorkoutBlockKind.exercise ||
      block.kind == WorkoutBlockKind.exerciseSets;

  static bool _isSpeedExercise(WorkoutBlockDraft block) {
    if (block.fields['trackingMode'] == ActivityCategory.speedAgility ||
        block.fields['activityCategory'] == ActivityCategory.speedAgility) {
      return true;
    }
    final exerciseId = block.fields['exerciseId']?.toString();
    if (exerciseId == null || exerciseId.isEmpty) return false;
    return exerciseDatabase.any(
      (exercise) =>
          exercise.id == exerciseId && exercise.usesSpeedAgilityTracking,
    );
  }

  static List<(String, bool, bool, String)> _visibleFields(String kind) {
    return switch (kind) {
      WorkoutBlockKind.interval => const [
          ('rounds', true, false, 'Ripetute'),
          ('series', true, false, 'Serie'),
          (
            'timeLimitSeconds',
            true,
            false,
            'Durata lavoro principale (secondi)'
          ),
          ('workSeconds', true, false, 'Lavoro (secondi)'),
          ('recoverySeconds', true, false, 'Recupero (secondi)'),
          ('distanceMeters', true, true, 'Distanza per ripetuta (m)'),
          ('targetPace', false, true, 'Passo / ritmo obiettivo'),
          ('targetZone', false, true, 'Zona obiettivo'),
        ],
      WorkoutBlockKind.circuit => const [
          ('rounds', true, false, 'Round'),
          (
            'timeLimitSeconds',
            true,
            false,
            'Durata lavoro principale (secondi)'
          ),
          ('repsPerExercise', true, false, 'Ripetizioni per esercizio'),
          ('workSeconds', true, false, 'Lavoro per stazione (10-60 secondi)'),
          (
            'stationRecoverySeconds',
            true,
            false,
            'Cambio / recupero stazione (10-60 secondi)'
          ),
          ('recoverySeconds', true, false, 'Recupero tra round (secondi)'),
        ],
      WorkoutBlockKind.sport => const [
          ('durationSeconds', true, false, 'Durata (secondi)'),
          ('distanceMeters', true, false, 'Distanza (m)'),
          ('targetPace', false, true, 'Passo / velocita'),
          ('targetZone', false, true, 'Zona obiettivo'),
          ('elevationMeters', true, true, 'Dislivello (m)'),
          ('cadence', true, true, 'Cadenza'),
          ('powerWatts', true, true, 'Potenza (W)'),
        ],
      WorkoutBlockKind.timed || WorkoutBlockKind.recovery => const [
          ('durationSeconds', true, false, 'Durata (secondi)'),
        ],
      _ => const [],
    };
  }

  static Map<String, dynamic> _defaultFields(String kind) => switch (kind) {
        WorkoutBlockKind.interval => const {
            'rounds': 4,
            'workSeconds': 240,
            'recoverySeconds': 180,
          },
        WorkoutBlockKind.circuit => const {
            'rounds': 4,
            'recoverySeconds': 60,
          },
        WorkoutBlockKind.sport => const {'durationSeconds': 3600},
        WorkoutBlockKind.timed || WorkoutBlockKind.recovery => const {
            'durationSeconds': 60,
          },
        WorkoutBlockKind.note => const {'notes': ''},
        _ => const {},
      };

  String _defaultTitle(String kind) => switch (kind) {
        WorkoutBlockKind.sport => 'Attivita continua',
        WorkoutBlockKind.interval => 'Intervalli',
        WorkoutBlockKind.circuit => 'Circuito',
        WorkoutBlockKind.timed => 'Blocco a tempo',
        WorkoutBlockKind.recovery => 'Recupero',
        WorkoutBlockKind.note => 'Nota',
        _ => WorkoutBlockKind.label(kind),
      };

  static String _conciseKindLabel(String kind) => switch (kind) {
        WorkoutBlockKind.exerciseSets => 'Esercizio dal catalogo',
        WorkoutBlockKind.sport => 'Attivita continua',
        WorkoutBlockKind.interval => 'Intervalli',
        WorkoutBlockKind.circuit => 'Circuito',
        WorkoutBlockKind.timed => 'Blocco a tempo',
        WorkoutBlockKind.recovery => 'Recupero',
        WorkoutBlockKind.note => 'Nota',
        _ => WorkoutBlockKind.label(kind),
      };

  static String _blockSummary(WorkoutBlockDraft block) {
    if (_isExercise(block)) {
      final sets = _setsForBlock(block);
      if (_isSpeedExercise(block)) {
        final completed = sets.where((trial) {
          return trial['distanceMeters'] != null ||
              trial['timeSeconds'] != null;
        }).length;
        return '${sets.length} prove${completed == 0 ? '' : ' · $completed compilate'}';
      }
      final completed = sets.where((set) {
        return set['kg'] != null || set['reps'] != null;
      }).length;
      return '${sets.length} serie${completed == 0 ? '' : ' · $completed compilate'}';
    }
    final parts = <String>[];
    void add(String key, String suffix) {
      final value = block.fields[key];
      if (value != null && value.toString().isNotEmpty) {
        parts.add('$value$suffix');
      }
    }

    add('rounds', ' round');
    add('series', ' serie');
    add('timeLimitSeconds', ' s totali');
    add('durationSeconds', ' s');
    add('repsPerExercise', ' rep/esercizio');
    add('workSeconds', ' s lavoro');
    add('stationRecoverySeconds', ' s cambio');
    add('distanceMeters', ' m');
    add('recoverySeconds', ' s recupero');
    if (block.children.isNotEmpty) {
      parts.add('${block.children.length} esercizi');
    }
    return parts.isEmpty ? _conciseKindLabel(block.kind) : parts.join(' · ');
  }

  static String _displayNumber(dynamic value) {
    if (value == null) return '';
    if (value is num && value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toString();
  }

  static String _exerciseAliases(ExerciseDef exercise) {
    final text = '${exercise.id} ${exercise.name}'.toLowerCase();
    return [
      if (text.contains('bench')) 'panca',
      if (text.contains('deadlift')) 'stacco',
      if (text.contains('pull-up') || text.contains('pullup')) 'trazioni',
      if (text.contains('row')) 'rematore',
      if (text.contains('lunge')) 'affondo affondi',
      if (text.contains('leg press')) 'pressa',
      if (text.contains('overhead press')) 'lento avanti military press',
      exercise.speedGroup ?? '',
      ...exercise.aliases,
    ].join(' ');
  }

  static IconData _phaseIcon(String phase) => switch (phase) {
        TrainingPhase.warmup => Icons.local_fire_department_outlined,
        TrainingPhase.cooldown => Icons.air,
        _ => Icons.fitness_center,
      };

  static IconData _blockIcon(String kind) => switch (kind) {
        WorkoutBlockKind.exercise ||
        WorkoutBlockKind.exerciseSets =>
          Icons.fitness_center,
        WorkoutBlockKind.sport => Icons.directions_run,
        WorkoutBlockKind.interval => Icons.repeat,
        WorkoutBlockKind.circuit => Icons.sync,
        WorkoutBlockKind.timed => Icons.timer_outlined,
        WorkoutBlockKind.recovery => Icons.hourglass_bottom,
        WorkoutBlockKind.note => Icons.notes,
        _ => Icons.add_box_outlined,
      };
}

class _ExercisePickerSheet extends StatefulWidget {
  final List<ExerciseDef> exercises;
  final List<String> suggestedExercises;

  const _ExercisePickerSheet({
    required this.exercises,
    required this.suggestedExercises,
  });

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isSuggested(String name) {
    final value = name.toLowerCase();
    return widget.suggestedExercises.any((suggestion) {
      final query = suggestion.toLowerCase();
      return value.contains(query) || query.contains(value);
    });
  }

  List<ExerciseDef> get _filteredExercises {
    final normalized = _query.trim().toLowerCase();
    final filtered = widget.exercises.where((exercise) {
      final searchText = [
        exercise.id,
        exercise.name,
        exercise.targetMuscle,
        exercise.category,
        WorkoutPhaseEditor._exerciseAliases(exercise),
      ].join(' ').toLowerCase();
      return normalized.isEmpty || searchText.contains(normalized);
    }).toList();
    filtered.sort((a, b) {
      final aSuggested = _isSuggested(a.name);
      final bSuggested = _isSuggested(b.name);
      if (aSuggested != bSuggested) return aSuggested ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredExercises;
    final speedCatalogue = widget.exercises.isNotEmpty &&
        widget.exercises.every((item) => item.usesSpeedAgilityTracking);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    speedCatalogue ? 'Seleziona drill' : 'Seleziona esercizio',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Il nome proviene dal catalogo e viene salvato con un ID stabile.',
                    style: TextStyle(
                      color: AppTheme.textMediumEmphasis,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Cerca nome, tipologia o attrezzatura',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Nessun esercizio trovato',
                        style: TextStyle(color: AppTheme.textMediumEmphasis),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppTheme.divider),
                      itemBuilder: (_, index) {
                        final exercise = filtered[index];
                        return ListTile(
                          leading: Icon(
                            exercise.usesSpeedAgilityTracking
                                ? Icons.speed
                                : Icons.fitness_center,
                            color: AppTheme.primary,
                          ),
                          title: Text(exercise.name),
                          subtitle: Text(
                            '${exercise.speedGroup ?? exercise.targetMuscle} · ${exercise.category}',
                          ),
                          trailing: _isSuggested(exercise.name)
                              ? const Icon(Icons.star_outline, size: 18)
                              : null,
                          onTap: () => Navigator.pop(context, exercise),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
