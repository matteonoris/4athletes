import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/workout_catalog.dart';
import '../models/training_activity_models.dart';
import '../models/workout_creation_models.dart';

class RunningWorkoutEditor extends StatelessWidget {
  final List<WorkoutPhaseDraft> phases;
  final String mode;
  final bool isPlanned;
  final ValueChanged<List<WorkoutPhaseDraft>> onChanged;

  const RunningWorkoutEditor({
    super.key,
    required this.phases,
    required this.mode,
    required this.isPlanned,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: TrainingPhase.ordered.map((type) {
        final phase = phases.where((item) => item.type == type).firstOrNull ??
            WorkoutPhaseDraft(
              type: type,
              isEnabled: type == TrainingPhase.main,
            );
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _phaseCard(context, phase),
        );
      }).toList(),
    );
  }

  Widget _phaseCard(BuildContext context, WorkoutPhaseDraft phase) {
    final optional = phase.type != TrainingPhase.main;
    final isIntervalMain = phase.type == TrainingPhase.main &&
        mode == RunningWorkoutMode.intervals;
    return Container(
      key: ValueKey('running_phase_${phase.type}'),
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
                Icon(_phaseIcon(phase.type), color: AppTheme.primary),
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
                    key: ValueKey('running_phase_switch_${phase.type}'),
                    value: phase.isEnabled,
                    onChanged: (enabled) => _replacePhase(
                      phase.copyWith(isEnabled: enabled),
                    ),
                  ),
              ],
            ),
          ),
          if (phase.isEnabled) ...[
            Divider(height: 1, color: AppTheme.divider),
            if (isIntervalMain)
              _intervalEditor(context, phase)
            else
              _simplePhaseEditor(phase),
          ],
        ],
      ),
    );
  }

  Widget _simplePhaseEditor(WorkoutPhaseDraft phase) {
    final block = phase.blocks.firstOrNull;
    final fields = block?.fields ?? const <String, dynamic>{};
    final durationSeconds = _asDouble(fields['durationSeconds']);
    final distanceMeters = _asDouble(fields['distanceMeters']);
    final notes = fields['notes']?.toString() ?? '';
    final notesLabel =
        phase.type == TrainingPhase.main && mode == RunningWorkoutMode.fartlek
            ? 'Descrivi le variazioni *'
            : 'Descrizione / note';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('running_${phase.type}_duration'),
                  initialValue: durationSeconds == null
                      ? ''
                      : _displayNumber(durationSeconds / 60),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Durata (min)',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  onChanged: (raw) => _updateSimplePhase(
                    phase,
                    'durationSeconds',
                    _parseDouble(raw) == null ? null : _parseDouble(raw)! * 60,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  key: ValueKey('running_${phase.type}_distance'),
                  initialValue: distanceMeters == null
                      ? ''
                      : _displayNumber(distanceMeters / 1000),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Distanza (km)',
                    prefixIcon: Icon(Icons.route_outlined),
                  ),
                  onChanged: (raw) => _updateSimplePhase(
                    phase,
                    'distanceMeters',
                    _parseDouble(raw) == null
                        ? null
                        : _parseDouble(raw)! * 1000,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('running_${phase.type}_notes'),
            initialValue: notes,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: notesLabel,
              alignLabelWithHint: true,
            ),
            onChanged: (value) => _updateSimplePhase(
              phase,
              'notes',
              value.trim().isEmpty ? null : value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _intervalEditor(BuildContext context, WorkoutPhaseDraft phase) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (phase.blocks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
              child: Text(
                'Aggiungi uno o più blocchi. Ogni blocco usa lo stesso tipo di ripetuta e recupero.',
                style: TextStyle(color: AppTheme.textMediumEmphasis),
              ),
            ),
          ...phase.blocks.asMap().entries.map(
                (entry) => _intervalCard(
                  context,
                  phase,
                  entry.value,
                  entry.key,
                ),
              ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: const ValueKey('add_running_interval_block'),
            onPressed: () => _addInterval(context, phase),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi blocco di ripetute'),
          ),
          TextButton.icon(
            key: const ValueKey('running_interval_presets'),
            onPressed: () => _choosePreset(context, phase),
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('Usa un preset'),
          ),
        ],
      ),
    );
  }

  Widget _intervalCard(
    BuildContext context,
    WorkoutPhaseDraft phase,
    WorkoutBlockDraft block,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: ListTile(
        key: ValueKey('running_interval_${block.id}'),
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
          child: Text('${index + 1}'),
        ),
        title: Text(
          block.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(_intervalSummary(block)),
        onTap: () => _editInterval(context, phase, block, index),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _intervalAction(phase, index, action),
          itemBuilder: (_) => [
            if (index > 0)
              const PopupMenuItem(value: 'up', child: Text('Sposta su')),
            if (index < phase.blocks.length - 1)
              const PopupMenuItem(value: 'down', child: Text('Sposta giù')),
            const PopupMenuItem(value: 'duplicate', child: Text('Duplica')),
            const PopupMenuItem(value: 'delete', child: Text('Elimina')),
          ],
        ),
      ),
    );
  }

  Future<void> _addInterval(
    BuildContext context,
    WorkoutPhaseDraft phase, {
    WorkoutProtocolDefinition? preset,
  }) async {
    final fields = Map<String, dynamic>.from(preset?.defaults ??
        const {
          'workUnit': 'distance',
          'repetitions': 1,
          'series': 1,
          'repRecoveryUnit': 'time',
        });
    final block = WorkoutBlockDraft(
      id: 'running_interval_${DateTime.now().microsecondsSinceEpoch}',
      kind: WorkoutBlockKind.interval,
      title: preset?.name ?? 'Blocco di ripetute',
      order: phase.blocks.length,
      fields: fields,
    );
    final edited = await _showIntervalDialog(context, block);
    if (edited == null) return;
    _replacePhase(phase.copyWith(blocks: [...phase.blocks, edited]));
  }

  Future<void> _editInterval(
    BuildContext context,
    WorkoutPhaseDraft phase,
    WorkoutBlockDraft block,
    int index,
  ) async {
    final edited = await _showIntervalDialog(context, block);
    if (edited == null) return;
    final blocks = phase.blocks.map((item) => item.copyWith()).toList();
    blocks[index] = edited.copyWith(order: index);
    _replacePhase(phase.copyWith(blocks: blocks));
  }

  Future<void> _choosePreset(
    BuildContext context,
    WorkoutPhaseDraft phase,
  ) async {
    final presets = WorkoutCatalog.protocolsFor(
      'running',
      RunningWorkoutMode.intervals,
    );
    final selected = await showModalBottomSheet<WorkoutProtocolDefinition>(
      context: context,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Preset ripetute'),
              subtitle: Text('I valori restano sempre modificabili.'),
            ),
            ...presets.map(
              (preset) => ListTile(
                leading: const Icon(Icons.repeat, color: AppTheme.primary),
                title: Text(preset.name),
                subtitle: Text(preset.description),
                onTap: () => Navigator.pop(sheetContext, preset),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && context.mounted) {
      await _addInterval(context, phase, preset: selected);
    }
  }

  Future<WorkoutBlockDraft?> _showIntervalDialog(
    BuildContext context,
    WorkoutBlockDraft block,
  ) async {
    final fields = Map<String, dynamic>.from(block.fields);
    final notesController = TextEditingController(
      text: fields['notes']?.toString() ?? '',
    );
    final paceKey =
        isPlanned ? 'targetPaceSecondsPerKm' : 'averagePaceSecondsPerKm';
    final paceController = TextEditingController(
      text: _formatPace(_asInt(fields[paceKey])),
    );
    final result = await showDialog<WorkoutBlockDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final workUnit = fields['workUnit']?.toString() ?? 'distance';
          final recoveryUnit = fields['repRecoveryUnit']?.toString() ?? 'time';
          final series = _asInt(fields['series']) ?? 1;
          return AlertDialog(
            backgroundColor: AppTheme.card,
            title: const Text('Blocco di ripetute'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _DialogLabel('TIPO DI LAVORO'),
                  SegmentedButton<String>(
                    key: const ValueKey('running_interval_work_unit'),
                    segments: const [
                      ButtonSegment(
                        value: 'distance',
                        label: Text('Distanza'),
                      ),
                      ButtonSegment(value: 'time', label: Text('Tempo')),
                    ],
                    selected: {workUnit},
                    onSelectionChanged: (selection) => setDialogState(() {
                      fields['workUnit'] = selection.first;
                      fields.remove('workSeconds');
                      fields.remove('workDistanceMeters');
                    }),
                  ),
                  const SizedBox(height: 12),
                  _numberField(
                    keyValue: 'running_interval_work_value_$workUnit',
                    value: workUnit == 'distance'
                        ? fields['workDistanceMeters']
                        : fields['workSeconds'],
                    label: workUnit == 'distance'
                        ? 'Distanza per ripetuta (m)'
                        : 'Durata per ripetuta (s)',
                    onChanged: (value) => fields[workUnit == 'distance'
                        ? 'workDistanceMeters'
                        : 'workSeconds'] = value,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          keyValue: 'running_interval_repetitions',
                          value: fields['repetitions'],
                          label: 'Ripetizioni',
                          integer: true,
                          onChanged: (value) => setDialogState(
                            () => fields['repetitions'] = value,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numberField(
                          keyValue: 'running_interval_series',
                          value: fields['series'],
                          label: 'Serie',
                          integer: true,
                          onChanged: (value) => setDialogState(
                            () => fields['series'] = value,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _DialogLabel('RECUPERO TRA RIPETUTE'),
                  SegmentedButton<String>(
                    key: const ValueKey('running_interval_recovery_unit'),
                    segments: const [
                      ButtonSegment(value: 'time', label: Text('Tempo')),
                      ButtonSegment(
                        value: 'distance',
                        label: Text('Distanza'),
                      ),
                    ],
                    selected: {recoveryUnit},
                    onSelectionChanged: (selection) => setDialogState(() {
                      fields['repRecoveryUnit'] = selection.first;
                      fields.remove('repRecoverySeconds');
                      fields.remove('repRecoveryMeters');
                    }),
                  ),
                  const SizedBox(height: 12),
                  _numberField(
                    keyValue: 'running_interval_recovery_value_$recoveryUnit',
                    value: recoveryUnit == 'distance'
                        ? fields['repRecoveryMeters']
                        : fields['repRecoverySeconds'],
                    label: recoveryUnit == 'distance'
                        ? 'Recupero (m)'
                        : 'Recupero (s)',
                    onChanged: (value) => fields[recoveryUnit == 'distance'
                        ? 'repRecoveryMeters'
                        : 'repRecoverySeconds'] = value,
                  ),
                  const SizedBox(height: 12),
                  _recoveryStyleField(
                    value: fields['repRecoveryStyle']?.toString(),
                    label: 'Tipo recupero',
                    onChanged: (value) => fields['repRecoveryStyle'] = value,
                  ),
                  if (series > 1) ...[
                    const SizedBox(height: 18),
                    const _DialogLabel('PAUSA TRA SERIE'),
                    _numberField(
                      keyValue: 'running_interval_series_recovery',
                      value: fields['seriesRecoverySeconds'],
                      label: 'Pausa tra serie (s)',
                      onChanged: (value) =>
                          fields['seriesRecoverySeconds'] = value,
                    ),
                    const SizedBox(height: 12),
                    _recoveryStyleField(
                      value: fields['seriesRecoveryStyle']?.toString(),
                      label: 'Tipo pausa',
                      onChanged: (value) =>
                          fields['seriesRecoveryStyle'] = value,
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextField(
                    key: const ValueKey('running_interval_pace'),
                    controller: paceController,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: isPlanned
                          ? 'Passo obiettivo (min/km)'
                          : 'Passo medio del blocco (min/km)',
                      hintText: '4:30',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      alignLabelWithHint: true,
                    ),
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
                key: const ValueKey('save_running_interval'),
                onPressed: () {
                  _putOrRemove(fields, 'notes', notesController.text);
                  final pace = _parsePace(paceController.text);
                  if (pace == null) {
                    fields.remove(paceKey);
                  } else {
                    fields[paceKey] = pace;
                  }
                  fields.removeWhere((_, value) => value == null);
                  Navigator.pop(
                    dialogContext,
                    block.copyWith(
                      title: _generatedIntervalTitle(fields),
                      fields: fields,
                    ),
                  );
                },
                child: const Text('Salva blocco'),
              ),
            ],
          );
        },
      ),
    );
    notesController.dispose();
    paceController.dispose();
    return result;
  }

  Widget _numberField({
    required String keyValue,
    required dynamic value,
    required String label,
    required ValueChanged<num?> onChanged,
    bool integer = false,
  }) {
    return TextFormField(
      key: ValueKey(keyValue),
      initialValue: _displayNumber(value),
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      decoration: InputDecoration(labelText: label),
      onChanged: (raw) {
        final parsed = _parseDouble(raw);
        onChanged(integer ? parsed?.round() : parsed);
      },
    );
  }

  Widget _recoveryStyleField({
    required String? value,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value ?? 'unspecified',
      decoration: InputDecoration(labelText: label),
      items: const [
        DropdownMenuItem(
          value: 'unspecified',
          child: Text('Non specificato'),
        ),
        DropdownMenuItem(value: 'active', child: Text('Attivo')),
        DropdownMenuItem(value: 'passive', child: Text('Passivo')),
      ],
      onChanged: (next) => onChanged(next == 'unspecified' ? null : next),
    );
  }

  void _intervalAction(
    WorkoutPhaseDraft phase,
    int index,
    String action,
  ) {
    final blocks = phase.blocks.map((item) => item.copyWith()).toList();
    switch (action) {
      case 'up':
        final block = blocks.removeAt(index);
        blocks.insert(index - 1, block);
      case 'down':
        final block = blocks.removeAt(index);
        blocks.insert(index + 1, block);
      case 'duplicate':
        blocks.insert(
          index + 1,
          blocks[index].copyWith(
            id: '${blocks[index].id}_${DateTime.now().microsecondsSinceEpoch}',
          ),
        );
      case 'delete':
        blocks.removeAt(index);
    }
    _replacePhase(
      phase.copyWith(
        blocks: blocks
            .asMap()
            .entries
            .map((entry) => entry.value.copyWith(order: entry.key))
            .toList(),
      ),
    );
  }

  void _updateSimplePhase(
    WorkoutPhaseDraft phase,
    String key,
    dynamic value,
  ) {
    final existing = phase.blocks.firstOrNull;
    final fields = Map<String, dynamic>.from(existing?.fields ?? const {});
    if (value == null || (value is String && value.trim().isEmpty)) {
      fields.remove(key);
    } else {
      fields[key] = value;
    }
    final block = WorkoutBlockDraft(
      id: existing?.id ?? 'running_phase_${phase.type}',
      kind: WorkoutBlockKind.sport,
      title: TrainingPhase.label(phase.type),
      order: 0,
      fields: fields,
    );
    _replacePhase(phase.copyWith(blocks: [block]));
  }

  void _replacePhase(WorkoutPhaseDraft replacement) {
    final updated = phases.map((phase) => phase.copyWith()).toList();
    final index = updated.indexWhere((phase) => phase.type == replacement.type);
    if (index < 0) {
      updated.add(replacement);
    } else {
      updated[index] = replacement;
    }
    onChanged(updated);
  }

  static String _generatedIntervalTitle(Map<String, dynamic> fields) {
    final reps = _asInt(fields['repetitions']);
    final series = _asInt(fields['series']);
    final workUnit = fields['workUnit']?.toString();
    final value = workUnit == 'distance'
        ? _displayNumber(fields['workDistanceMeters'])
        : _formatSeconds(_asDouble(fields['workSeconds']));
    final unit = workUnit == 'distance' ? 'm' : '';
    final work = [
      if (reps != null) '$reps ×',
      if (value.isNotEmpty) '$value$unit',
    ].join(' ');
    if (work.isEmpty) return 'Blocco di ripetute';
    return series != null && series > 1 ? '$series serie · $work' : work;
  }

  static String _intervalSummary(WorkoutBlockDraft block) {
    final fields = block.fields;
    final parts = <String>[];
    final recoveryUnit = fields['repRecoveryUnit']?.toString();
    final recovery = recoveryUnit == 'distance'
        ? '${_displayNumber(fields['repRecoveryMeters'])} m recupero'
        : '${_formatSeconds(_asDouble(fields['repRecoverySeconds']))} recupero';
    if (!recovery.startsWith(' recupero')) parts.add(recovery);
    final seriesRecovery = _asDouble(fields['seriesRecoverySeconds']);
    if (seriesRecovery != null && seriesRecovery > 0) {
      parts.add('${_formatSeconds(seriesRecovery)} tra serie');
    }
    final pace = _asInt(
      fields['targetPaceSecondsPerKm'] ?? fields['averagePaceSecondsPerKm'],
    );
    if (pace != null) parts.add('${_formatPace(pace)} /km');
    return parts.isEmpty
        ? 'Tocca per completare i dettagli'
        : parts.join(' · ');
  }

  static String _formatSeconds(double? raw) {
    if (raw == null || raw <= 0) return '';
    final seconds = raw.round();
    if (seconds < 60) return '$seconds s';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return rest == 0
        ? '$minutes min'
        : '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  static String _formatPace(int? pace) {
    if (pace == null || pace <= 0) return '';
    return '${pace ~/ 60}:${(pace % 60).toString().padLeft(2, '0')}';
  }

  static int? _parsePace(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null || seconds < 0 || seconds > 59) {
      return null;
    }
    return minutes * 60 + seconds;
  }

  static double? _parseDouble(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _displayNumber(dynamic value) {
    if (value == null) return '';
    if (value is num && value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toString();
  }

  static void _putOrRemove(
    Map<String, dynamic> target,
    String key,
    String value,
  ) {
    if (value.trim().isEmpty) {
      target.remove(key);
    } else {
      target[key] = value.trim();
    }
  }

  static IconData _phaseIcon(String type) => switch (type) {
        TrainingPhase.warmup => Icons.local_fire_department_outlined,
        TrainingPhase.cooldown => Icons.air,
        _ => Icons.directions_run,
      };
}

class _DialogLabel extends StatelessWidget {
  final String text;

  const _DialogLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.textMediumEmphasis,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
