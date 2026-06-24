import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/exercises.dart';
import '../models/models.dart';
import '../models/training_activity_models.dart';
import '../providers/app_state.dart';
import '../services/training_activity_service.dart';
import '../utils/strength_pr_utils.dart';
import '../widgets/custom_card.dart';

class DrylandActivityScreen extends StatefulWidget {
  final String category;
  final String title;
  final TrainingSession? initialSession;
  final WorkoutTemplate? initialTemplate;

  const DrylandActivityScreen({
    super.key,
    required this.category,
    required this.title,
    this.initialSession,
    this.initialTemplate,
  });

  @override
  State<DrylandActivityScreen> createState() => _DrylandActivityScreenState();
}

class _DrylandActivityScreenState extends State<DrylandActivityScreen> {
  final _activityService = const TrainingActivityService();
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String _category;
  late String _title;

  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _painCtrl = TextEditingController();
  double _rpe = 5;

  final List<Map<String, dynamic>> _strengthExercises = [];
  final List<Map<String, dynamic>> _plyometricExercises = [];
  final List<Map<String, dynamic>> _speedDrills = [];
  final List<Map<String, dynamic>> _circuits = [];
  final Map<String, dynamic> _endurance = {};
  String _exerciseSearch = '';
  String _equipmentFilter = 'all';

  bool get _isExerciseCategory =>
      _category == ActivityCategory.strength ||
      _category == ActivityCategory.mobility ||
      _category == ActivityCategory.core;
  bool get _usesDurationSets =>
      _category == ActivityCategory.mobility ||
      _category == ActivityCategory.core;
  bool get _isPlyometrics => _category == ActivityCategory.plyometrics;
  bool get _isSpeed => _category == ActivityCategory.speedAgility;
  bool get _isCircuit => _category == ActivityCategory.circuit;
  bool get _isEndurance =>
      _category == ActivityCategory.endurance ||
      _category == ActivityCategory.sport;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _title = widget.title;
    final initial = widget.initialSession;
    _date = initial != null ? DateTime.parse(initial.date) : DateTime.now();
    _startTime = initial != null
        ? _parseTime(initial.startTime)
        : const TimeOfDay(hour: 9, minute: 0);
    _endTime = initial != null
        ? _parseTime(initial.endTime)
        : const TimeOfDay(hour: 10, minute: 0);
    _rpe = (initial?.effort.toDouble() ?? 5).clamp(0, 10);

    if (initial != null) {
      _loadFromActivity(TrainingActivity.fromTrainingSession(initial));
    } else if (widget.initialTemplate != null) {
      _applyTemplate(widget.initialTemplate!);
    } else if (_isEndurance) {
      _endurance['durationSeconds'] = _calculateDuration() * 60;
    }
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _painCtrl.dispose();
    super.dispose();
  }

  void _loadFromActivity(TrainingActivity activity) {
    _category = activity.category;
    _title = activity.title;
    _locationCtrl.text = activity.location ?? '';
    _notesCtrl.text = activity.notes ?? '';
    _painCtrl.text = activity.pain ?? '';
    _rpe = (activity.rpe ?? 5).toDouble().clamp(0, 10);
    _loadBlocks(activity.blocks);
  }

  void _loadBlocks(List<TrainingBlock> blocks) {
    _strengthExercises.clear();
    _plyometricExercises.clear();
    _speedDrills.clear();
    _circuits.clear();
    _endurance.clear();
    for (final block in blocks) {
      if (block.type == TrainingBlockType.strength ||
          block.type == TrainingBlockType.mobility ||
          block.type == TrainingBlockType.core) {
        _strengthExercises.addAll(
          block.exercises.map((entry) => entry.toJson()),
        );
      } else if (block.type == TrainingBlockType.plyometrics) {
        _plyometricExercises.addAll(
          block.plyometrics.map((entry) => entry.toJson()),
        );
      } else if (block.type == TrainingBlockType.speedAgility) {
        _speedDrills.addAll(block.drills.map((entry) => entry.toJson()));
      } else if (block.type == TrainingBlockType.circuit) {
        final circuits = block.metrics['circuits'];
        if (circuits is List) {
          _circuits.addAll(
            circuits
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item)),
          );
        }
      } else if (block.type == TrainingBlockType.endurance &&
          block.endurance != null) {
        _endurance.addAll(block.endurance!.toJson());
      } else if ((block.notes ?? '').isNotEmpty) {
        _notesCtrl.text = block.notes!;
      }
    }
  }

  void _applyTemplate(WorkoutTemplate template) {
    setState(() {
      _category = template.category;
      _title = template.name;
      _loadBlocks(template.blocks);
    });
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return TimeOfDay.now();
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0.0;
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }

  double _oneRepMaxForExercise(AppState appState, String exerciseId) {
    return currentOneRepMaxForExercise(
      exerciseId,
      appState.prLogs,
      profileOneRepMax: appState.userProfile?.oneRepMax,
    );
  }

  double? _percent1RMForSet(
    AppState appState,
    String exerciseId,
    Map<String, dynamic> set,
  ) {
    final load = _asDouble(set['kg']);
    final maxLoad = _oneRepMaxForExercise(appState, exerciseId);
    if (load <= 0 || maxLoad <= 0) return null;
    return (load / maxLoad) * 100;
  }

  void _syncSetPercent1RM(
    AppState appState,
    String exerciseId,
    Map<String, dynamic> set,
  ) {
    set['percent1RM'] = _percent1RMForSet(appState, exerciseId, set);
  }

  void _syncAllPercent1RM(AppState appState) {
    for (final exercise in _strengthExercises) {
      final exerciseId = exercise['exerciseId']?.toString() ?? '';
      final sets = exercise['sets'];
      if (exerciseId.isEmpty || sets is! List) continue;
      for (var i = 0; i < sets.length; i++) {
        final set = sets[i];
        if (set is Map<String, dynamic>) {
          _syncSetPercent1RM(appState, exerciseId, set);
        } else if (set is Map) {
          final normalized = Map<String, dynamic>.from(set);
          _syncSetPercent1RM(appState, exerciseId, normalized);
          sets[i] = normalized;
        }
      }
    }
  }

  int _calculateDuration() {
    final start = _startTime.hour * 60 + _startTime.minute;
    final end = _endTime.hour * 60 + _endTime.minute;
    var diff = end - start;
    if (diff < 0) diff += 24 * 60;
    return diff;
  }

  String _sportIdForCategory() {
    switch (_category) {
      case ActivityCategory.strength:
        return 'weightlifting';
      case ActivityCategory.plyometrics:
        return 'dryland_plyometrics';
      case ActivityCategory.speedAgility:
        return 'dryland_speed_agility';
      case ActivityCategory.endurance:
        return 'running';
      case ActivityCategory.mobility:
        return 'stretching';
      case ActivityCategory.core:
        return 'dryland_core';
      case ActivityCategory.circuit:
        return 'dryland_circuit';
      case ActivityCategory.test:
        return 'dryland_test';
      default:
        return 'athletic_prep';
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case ActivityCategory.strength:
        return 'Forza';
      case ActivityCategory.plyometrics:
        return 'Pliometria';
      case ActivityCategory.speedAgility:
        return 'Velocità / Agilità';
      case ActivityCategory.endurance:
        return 'Resistenza';
      case ActivityCategory.mobility:
        return 'Mobilita';
      case ActivityCategory.core:
        return 'Core';
      case ActivityCategory.circuit:
        return 'Circuito';
      case ActivityCategory.test:
        return 'Test';
      case ActivityCategory.sport:
        return 'Sport';
      default:
        return 'Altro';
    }
  }

  String _exerciseBlockType() {
    if (_category == ActivityCategory.mobility) {
      return TrainingBlockType.mobility;
    }
    if (_category == ActivityCategory.core) {
      return TrainingBlockType.core;
    }
    return TrainingBlockType.strength;
  }

  String _exerciseActivityFilter() {
    if (_category == ActivityCategory.mobility) {
      return ActivityCategory.mobility;
    }
    if (_category == ActivityCategory.core) {
      return ActivityCategory.core;
    }
    return ActivityCategory.strength;
  }

  Map<String, dynamic> _newStrengthSet(
    List<Map<String, dynamic>> sets,
    Map<String, dynamic> exercise,
  ) {
    final side = exercise['unilateralMode'] == UnilateralMode.right
        ? TrainingSide.right
        : exercise['unilateralMode'] == UnilateralMode.left
            ? TrainingSide.left
            : TrainingSide.none;

    if (sets.isEmpty) {
      return {
        'setNumber': 1,
        'kg': null,
        'reps': null,
        'durationSeconds': _usesDurationSets ? 30 : null,
        'side': side,
      };
    }

    return Map<String, dynamic>.from(sets.last)
      ..['setNumber'] = sets.length + 1
      ..['side'] = side;
  }

  TrainingActivity _buildActivity({String? id}) {
    final appState = Provider.of<AppState>(context, listen: false);
    _syncAllPercent1RM(appState);

    final blocks = <TrainingBlock>[];
    if (_strengthExercises.isNotEmpty) {
      blocks.add(TrainingBlock(
        id: '${_exerciseBlockType()}_1',
        type: _exerciseBlockType(),
        name: _categoryLabel(_category),
        exercises: _strengthExercises
            .map((item) => ExerciseEntry.fromJson(item))
            .toList(),
      ));
    }
    if (_plyometricExercises.isNotEmpty) {
      blocks.add(TrainingBlock(
        id: 'plyometrics_1',
        type: TrainingBlockType.plyometrics,
        name: 'Pliometria',
        plyometrics: _plyometricExercises
            .map((item) => PlyometricEntry.fromJson(item))
            .toList(),
      ));
    }
    if (_speedDrills.isNotEmpty) {
      blocks.add(TrainingBlock(
        id: 'speed_agility_1',
        type: TrainingBlockType.speedAgility,
        name: 'Velocità / Agilità',
        drills: _speedDrills
            .map((item) => SpeedAgilityDrill.fromJson(item))
            .toList(),
      ));
    }
    if (_isEndurance && _endurance.isNotEmpty) {
      _endurance['durationSeconds'] = _calculateDuration() * 60;
      blocks.add(TrainingBlock(
        id: 'endurance_1',
        type: TrainingBlockType.endurance,
        name: 'Resistenza',
        endurance: EnduranceMetrics.fromJson(_endurance),
      ));
    }
    if (_circuits.isNotEmpty) {
      blocks.add(TrainingBlock(
        id: 'circuit_1',
        type: TrainingBlockType.circuit,
        name: 'Circuito',
        metrics: {'circuits': _circuits},
      ));
    }
    if (blocks.isEmpty && _notesCtrl.text.trim().isNotEmpty) {
      blocks.add(TrainingBlock(
        id: 'note_1',
        type: TrainingBlockType.note,
        name: _categoryLabel(_category),
        notes: _notesCtrl.text.trim(),
      ));
    }

    return TrainingActivity(
      id: id ??
          widget.initialSession?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      athleteId: appState.userId,
      source: ActivitySource.athlete,
      status: ActivityStatus.completed,
      category: _category,
      sportType: _sportIdForCategory(),
      title: _title,
      date: _date.toIso8601String().split('T').first,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      duration: _calculateDuration().toString(),
      location: _locationCtrl.text.trim(),
      rpe: _rpe.round(),
      pain: _painCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      athleteModified: widget.initialSession?.details?['from_calendar'] == true,
      createdByCoach: widget.initialSession?.details?['from_calendar'] == true,
      linkedCoachEventId: widget.initialSession?.eventId,
      blocks: blocks,
    );
  }

  Future<void> _saveSession() async {
    final activity = _buildActivity();
    final session = TrainingSession(
      id: widget.initialSession?.id ?? 'new_session',
      sportId: activity.sportType ?? _sportIdForCategory(),
      date: activity.date,
      startTime: activity.startTime,
      endTime: activity.endTime,
      duration: activity.duration,
      effort: activity.rpe ?? 5,
      eventId: activity.linkedCoachEventId,
      details:
          activity.toSessionDetails(existing: widget.initialSession?.details),
    );
    await Provider.of<AppState>(context, listen: false).addSession(session);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _saveTemplate() async {
    final nameCtrl = TextEditingController(text: _title);
    final appState = Provider.of<AppState>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Salva template',
            style: TextStyle(
                color: AppTheme.textHighEmphasis, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          style: TextStyle(color: AppTheme.textHighEmphasis),
          decoration: const InputDecoration(labelText: 'Nome template'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      nameCtrl.dispose();
      return;
    }
    final template = _activityService.saveActivityAsTemplate(
      _buildActivity(id: 'template_source'),
      templateId: DateTime.now().millisecondsSinceEpoch.toString(),
      name: nameCtrl.text.trim().isEmpty ? _title : nameCtrl.text.trim(),
      ownerType: appState.userProfile?.role == 'coach'
          ? TemplateOwnerType.coach
          : TemplateOwnerType.athlete,
      ownerId: appState.userId,
      teamId: appState.userProfile?.teamId,
      createdBy: appState.userId,
    );
    nameCtrl.dispose();
    await appState.saveWorkoutTemplate(template);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template salvato.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.initialSession == null
            ? 'Aggiungi ${_categoryLabel(_category)}'
            : 'Personalizza ${_categoryLabel(_category)}'),
        actions: [
          IconButton(
            tooltip: 'Salva come template',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _saveTemplate,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          _timeSection(),
          const SizedBox(height: 16),
          _templateSection(),
          const SizedBox(height: 16),
          if (_isExerciseCategory)
            _strengthSection()
          else if (_isPlyometrics)
            _plyometricsSection()
          else if (_isSpeed)
            _speedSection()
          else if (_isCircuit)
            _circuitSection()
          else if (_isEndurance)
            _enduranceSection()
          else
            _notesOnlySection(),
          const SizedBox(height: 16),
          _personalSection(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _saveSession,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Salva attività'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.background,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeSection() {
    return _section(
      title: 'Data e orario',
      icon: Icons.calendar_today_outlined,
      child: Column(
        children: [
          _textInput(
            'Titolo',
            initialValue: _title,
            onChanged: (v) => _title = v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _tapField(
                  'Data',
                  _date.toIso8601String().split('T').first,
                  Icons.calendar_today_outlined,
                  () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (date != null) setState(() => _date = date);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tapField('Inizio', _formatTime(_startTime),
                    Icons.access_time, () => _pickTime(true)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tapField('Fine', _formatTime(_endTime),
                    Icons.access_time_filled, () => _pickTime(false)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _textInput(
            'Luogo',
            controller: _locationCtrl,
            icon: Icons.location_on_outlined,
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(bool isStart) async {
    HapticFeedback.lightImpact();
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (selected == null) return;
    setState(() {
      if (isStart) {
        _startTime = selected;
      } else {
        _endTime = selected;
      }
    });
  }

  Widget _templateSection() {
    return Selector<AppState, List<WorkoutTemplate>>(
      selector: (_, state) => state.workoutTemplates
          .where((template) => template.category == _category)
          .toList(growable: false),
      builder: (context, templates, _) => _section(
        title: 'Template',
        icon: Icons.bookmark_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (templates.isEmpty)
              Text(
                'Nessun template per questa categoria.',
                style: TextStyle(color: AppTheme.textMediumEmphasis),
              )
            else
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    return ActionChip(
                      avatar: const Icon(Icons.bookmark_outline, size: 16),
                      label: Text(template.name),
                      onPressed: () => _applyTemplate(template),
                      backgroundColor: AppTheme.surface,
                      labelStyle: TextStyle(color: AppTheme.textHighEmphasis),
                      side: BorderSide(color: AppTheme.subtleBorder),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: templates.length,
                ),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _saveTemplate,
              icon: const Icon(Icons.add),
              label: const Text('Salva questa scheda come template'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strengthSection() {
    return _section(
      title: 'Esercizi',
      icon: Icons.fitness_center,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _exerciseSearch = value),
                  style: TextStyle(color: AppTheme.textHighEmphasis),
                  decoration: const InputDecoration(
                    hintText: 'Cerca esercizio',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _equipmentFilter,
                dropdownColor: AppTheme.card,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tutti')),
                  DropdownMenuItem(value: 'barbell', child: Text('Bilanciere')),
                  DropdownMenuItem(value: 'dumbbell', child: Text('Manubri')),
                  DropdownMenuItem(value: 'cable', child: Text('Cavi')),
                  DropdownMenuItem(value: 'machine', child: Text('Macchina')),
                  DropdownMenuItem(value: 'bodyweight', child: Text('Corpo')),
                  DropdownMenuItem(
                      value: 'kettlebell', child: Text('Kettlebell')),
                  DropdownMenuItem(value: 'band', child: Text('Elastico')),
                ],
                onChanged: (value) =>
                    setState(() => _equipmentFilter = value ?? 'all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _exercisePicker(),
          const SizedBox(height: 12),
          if (_strengthExercises.isEmpty)
            _empty('Aggiungi un esercizio o usa un template.')
          else
            ..._strengthExercises.asMap().entries.map(
                  (entry) => _strengthExerciseCard(entry.key, entry.value),
                ),
          OutlinedButton.icon(
            onPressed: _createCustomExercise,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Crea esercizio personalizzato'),
          ),
        ],
      ),
    );
  }

  Widget _exercisePicker() {
    final query = _exerciseSearch.trim().toLowerCase();
    final filtered = exerciseDatabase
        .where((exercise) {
          final searchMatch = query.isEmpty ||
              exercise.name.toLowerCase().contains(query) ||
              exercise.targetMuscle.toLowerCase().contains(query);
          final equipmentMatch = _equipmentFilter == 'all' ||
              exercise.category == _equipmentFilter;
          final activityMatch =
              exercise.resolvedActivityCategory == _exerciseActivityFilter();
          return searchMatch && equipmentMatch && activityMatch;
        })
        .take(6)
        .toList();
    if (query.isEmpty && _equipmentFilter == 'all') {
      return const SizedBox();
    }
    return Column(
      children: filtered.map((exercise) {
        return ListTile(
          dense: true,
          title: Text(exercise.name,
              style: TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold)),
          subtitle: Text('${exercise.targetMuscle} - ${exercise.category}',
              style: TextStyle(color: AppTheme.textMediumEmphasis)),
          trailing: const Icon(Icons.add, color: AppTheme.primary),
          onTap: () => _addStrengthExercise(
            exercise.id,
            exercise.name,
            equipment: exercise.category,
          ),
        );
      }).toList(),
    );
  }

  void _addStrengthExercise(
    String id,
    String name, {
    String? equipment,
    bool isCustom = false,
  }) {
    setState(() {
      _strengthExercises.add({
        'exerciseId': id,
        'name': name,
        'equipment': equipment,
        'unilateralMode': UnilateralMode.bilateral,
        'isCustom': isCustom,
        if (isCustom)
          'createdByAthleteId':
              Provider.of<AppState>(context, listen: false).userId,
        'sets': [
          {
            'setNumber': 1,
            'kg': null,
            'reps': null,
            'durationSeconds': _usesDurationSets ? 30 : null,
            'side': TrainingSide.none,
          }
        ],
      });
      _exerciseSearch = '';
    });
  }

  Future<void> _createCustomExercise() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Esercizio personalizzato',
            style: TextStyle(
                color: AppTheme.textHighEmphasis, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: AppTheme.textHighEmphasis),
          decoration: const InputDecoration(labelText: 'Nome esercizio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    _addStrengthExercise(
      'custom_${DateTime.now().millisecondsSinceEpoch}',
      name,
      isCustom: true,
    );
  }

  Widget _strengthExerciseCard(int index, Map<String, dynamic> exercise) {
    final sets = (exercise['sets'] as List).cast<Map<String, dynamic>>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(exercise['name']?.toString() ?? '',
                    style: TextStyle(
                        color: AppTheme.textHighEmphasis,
                        fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                onPressed: () =>
                    setState(() => _strengthExercises.removeAt(index)),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Bilaterale'),
                selected:
                    exercise['unilateralMode'] == UnilateralMode.bilateral,
                onSelected: (_) => setState(() =>
                    exercise['unilateralMode'] = UnilateralMode.bilateral),
              ),
              ChoiceChip(
                label: const Text('Destra'),
                selected: exercise['unilateralMode'] == UnilateralMode.right,
                onSelected: (_) => setState(
                    () => exercise['unilateralMode'] = UnilateralMode.right),
              ),
              ChoiceChip(
                label: const Text('Sinistra'),
                selected: exercise['unilateralMode'] == UnilateralMode.left,
                onSelected: (_) => setState(
                    () => exercise['unilateralMode'] = UnilateralMode.left),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...sets.asMap().entries.map((entry) {
            final setIndex = entry.key;
            final set = entry.value;
            return _strengthSetRow(index, setIndex, set);
          }),
          TextButton.icon(
            onPressed: () => setState(() {
              sets.add(_newStrengthSet(sets, exercise));
            }),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi set'),
          ),
        ],
      ),
    );
  }

  Widget _strengthSetRow(
      int exerciseIndex, int setIndex, Map<String, dynamic> set) {
    final appState = Provider.of<AppState>(context);
    final exercise = _strengthExercises[exerciseIndex];
    final exerciseId = exercise['exerciseId']?.toString() ?? '';
    final percent1RM = exerciseId.isEmpty
        ? null
        : _percent1RMForSet(appState, exerciseId, set);

    String fieldValue(String key) {
      final value = set[key];
      if (value == null || value == 0) return '';
      return value.toString();
    }

    Widget numberField(
      String label,
      String key, {
      bool decimal = true,
      String? suffixText,
    }) {
      return TextFormField(
        initialValue: fieldValue(key),
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            decimal ? RegExp(r'[0-9,.]') : RegExp(r'[0-9]'),
          ),
        ],
        textAlign: TextAlign.center,
        cursorColor: AppTheme.primary,
        style: TextStyle(
          color: AppTheme.textHighEmphasis,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
          isDense: true,
          filled: true,
          fillColor: AppTheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.subtleBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
        onChanged: (value) {
          final normalized = value.replaceAll(',', '.');
          setState(() {
            if (normalized.isEmpty) {
              set[key] = null;
            } else {
              set[key] = decimal
                  ? double.tryParse(normalized)
                  : int.tryParse(normalized);
            }
            if (key == 'kg' && exerciseId.isNotEmpty) {
              _syncSetPercent1RM(appState, exerciseId, set);
            }
          });
        },
      );
    }

    Widget calculatedPercentField() {
      final value = percent1RM == null ? '' : percent1RM.toStringAsFixed(0);
      return TextFormField(
        key: ValueKey('percent1rm_${exerciseIndex}_${setIndex}_$value'),
        initialValue: value,
        readOnly: true,
        enableInteractiveSelection: false,
        textAlign: TextAlign.center,
        cursorColor: AppTheme.primary,
        style: TextStyle(
          color: percent1RM == null
              ? AppTheme.textMediumEmphasis
              : AppTheme.textHighEmphasis,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: '% 1RM',
          suffixText: percent1RM == null ? null : '%',
          isDense: true,
          filled: true,
          fillColor: AppTheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.subtleBorder),
          ),
        ),
      );
    }

    Widget tempoField() {
      return TextFormField(
        initialValue: set['tempo']?.toString() ?? '',
        textAlign: TextAlign.center,
        cursorColor: AppTheme.primary,
        style: TextStyle(
          color: AppTheme.textHighEmphasis,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: 'Tempo',
          hintText: '4-0-1-0',
          isDense: true,
          filled: true,
          fillColor: AppTheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.subtleBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
        onChanged: (value) =>
            set['tempo'] = value.trim().isEmpty ? null : value,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.subtleFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.subtleBorder),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text('Set ${setIndex + 1}',
                    style: TextStyle(
                        color: AppTheme.textMediumEmphasis,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 18, color: AppTheme.textMediumEmphasis),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () => setState(() {
                    final sets =
                        (_strengthExercises[exerciseIndex]['sets'] as List);
                    sets.removeAt(setIndex);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: numberField('Peso', 'kg', suffixText: 'kg'),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: numberField('Reps', 'reps', decimal: false),
                    ),
                    if (_usesDurationSets)
                      SizedBox(
                        width: fieldWidth,
                        child: numberField('Tenuta', 'durationSeconds',
                            decimal: false, suffixText: 's'),
                      ),
                    SizedBox(
                      width: fieldWidth,
                      child: calculatedPercentField(),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: numberField('RPE', 'rpe'),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: numberField('RIR', 'rir', decimal: false),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: numberField('Rec', 'restSeconds',
                          decimal: false, suffixText: 's'),
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: tempoField(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _plyometricsSection() {
    return _section(
      title: 'Esercizi pliometrici',
      icon: Icons.bolt,
      child: Column(
        children: [
          if (_plyometricExercises.isEmpty)
            _empty('Aggiungi un esercizio pliometrico.'),
          ..._plyometricExercises.asMap().entries.map(
                (entry) => _plyometricCard(entry.key, entry.value),
              ),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _plyometricExercises.add({
                'exerciseName': 'Drop jump',
                'type': 'drop_jump',
                'direction': 'vertical',
                'unilateralMode': UnilateralMode.bilateral,
                'sets': [
                  {
                    'setNumber': 1,
                    'reps': 5,
                    'contacts': 5,
                    'side': TrainingSide.both
                  }
                ],
              });
            }),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi pliometria'),
          ),
        ],
      ),
    );
  }

  Widget _plyometricCard(int index, Map<String, dynamic> entry) {
    final sets = (entry['sets'] as List).cast<Map<String, dynamic>>();
    final totalContacts = sets.fold<int>(0, (sum, set) {
      return sum + ((set['contacts'] ?? set['reps'] ?? 0) as num).round();
    });
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: entry['type']?.toString() ?? 'drop_jump',
                  dropdownColor: AppTheme.card,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                        value: 'vertical_jumps',
                        child: Text('Balzi verticali')),
                    DropdownMenuItem(
                        value: 'horizontal_jumps',
                        child: Text('Balzi orizzontali')),
                    DropdownMenuItem(
                        value: 'lateral_jumps', child: Text('Balzi laterali')),
                    DropdownMenuItem(
                        value: 'drop_jump', child: Text('Drop jump')),
                    DropdownMenuItem(
                        value: 'hurdle_hops', child: Text('Hurdle hops')),
                    DropdownMenuItem(
                        value: 'pogo_jumps', child: Text('Pogo jumps')),
                    DropdownMenuItem(
                        value: 'skater_jumps', child: Text('Skater jumps')),
                    DropdownMenuItem(
                        value: 'single_leg_jumps',
                        child: Text('Salti monopodalici')),
                    DropdownMenuItem(
                        value: 'double_leg_jumps',
                        child: Text('Salti bipodalici')),
                    DropdownMenuItem(value: 'cmj', child: Text('CMJ')),
                    DropdownMenuItem(
                        value: 'squat_jump', child: Text('Squat jump')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom')),
                  ],
                  onChanged: (value) => setState(() => entry['type'] = value),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                onPressed: () =>
                    setState(() => _plyometricExercises.removeAt(index)),
              ),
            ],
          ),
          _textInput('Nome',
              initialValue: entry['exerciseName']?.toString() ?? '',
              onChanged: (v) => entry['exerciseName'] = v),
          const SizedBox(height: 8),
          ...sets.asMap().entries.map((setEntry) {
            final set = setEntry.value;
            return Row(
              children: [
                Expanded(
                    child: _inlineNumber('Reps', set['reps'], (v) {
                  set['reps'] = v;
                  set['contacts'] ??= v;
                  setState(() {});
                })),
                const SizedBox(width: 8),
                Expanded(
                    child: _inlineNumber('Contatti', set['contacts'],
                        (v) => setState(() => set['contacts'] = v))),
                const SizedBox(width: 8),
                Expanded(
                    child: _inlineNumber('Altezza cm', set['heightCm'],
                        (v) => set['heightCm'] = v)),
                const SizedBox(width: 8),
                Expanded(
                    child: _inlineNumber('Distanza m', set['distanceM'],
                        (v) => set['distanceM'] = v)),
              ],
            );
          }),
          const SizedBox(height: 8),
          _summaryPill('Contatti totali: $totalContacts'),
          TextButton.icon(
            onPressed: () => setState(() => sets.add({
                  'setNumber': sets.length + 1,
                  'reps': 5,
                  'contacts': 5,
                  'side': TrainingSide.both,
                })),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi set'),
          ),
        ],
      ),
    );
  }

  Widget _speedSection() {
    return _section(
      title: 'Drill',
      icon: Icons.speed,
      child: Column(
        children: [
          if (_speedDrills.isEmpty) _empty('Aggiungi un drill.'),
          ..._speedDrills.asMap().entries.map(
                (entry) => _speedCard(entry.key, entry.value),
              ),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _speedDrills.add({
                'name': 'Scatti',
                'type': 'sprint',
                'sets': 6,
                'reps': 1,
              });
            }),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi drill'),
          ),
        ],
      ),
    );
  }

  Widget _speedCard(int index, Map<String, dynamic> drill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: drill['type']?.toString() ?? 'sprint',
                  dropdownColor: AppTheme.card,
                  decoration: const InputDecoration(labelText: 'Drill'),
                  items: const [
                    DropdownMenuItem(value: 'sprint', child: Text('Scatti')),
                    DropdownMenuItem(
                        value: 'acceleration', child: Text('Accelerazioni')),
                    DropdownMenuItem(
                        value: 'hill_sprint', child: Text('Sprint in salita')),
                    DropdownMenuItem(value: 'skip', child: Text('Skip')),
                    DropdownMenuItem(
                        value: 'butt_kicks', child: Text('Calciata')),
                    DropdownMenuItem(value: 'carioca', child: Text('Carioca')),
                    DropdownMenuItem(value: 'ladder', child: Text('Scaletta')),
                    DropdownMenuItem(value: 'hurdles', child: Text('Ostacoli')),
                    DropdownMenuItem(value: 'cones', child: Text('Coni')),
                    DropdownMenuItem(
                        value: 'change_of_direction',
                        child: Text('Cambi direzione')),
                    DropdownMenuItem(
                        value: 'alternate_bounds',
                        child: Text('Balzi alternati')),
                    DropdownMenuItem(
                        value: 'technical_drills',
                        child: Text('Andature tecniche')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom')),
                  ],
                  onChanged: (value) => setState(() => drill['type'] = value),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                onPressed: () => setState(() => _speedDrills.removeAt(index)),
              ),
            ],
          ),
          Row(children: [
            Expanded(
                child: _inlineNumber(
                    'Serie', drill['sets'], (v) => drill['sets'] = v)),
            const SizedBox(width: 8),
            Expanded(
                child: _inlineNumber(
                    'Reps', drill['reps'], (v) => drill['reps'] = v)),
            const SizedBox(width: 8),
            Expanded(
                child: _inlineNumber('Distanza m', drill['distanceM'],
                    (v) => drill['distanceM'] = v)),
            const SizedBox(width: 8),
            Expanded(
                child: _inlineNumber('Tempo s', drill['timeSeconds'],
                    (v) => drill['timeSeconds'] = v)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _textInput('Partenza',
                    initialValue: drill['startType']?.toString() ?? '',
                    onChanged: (v) => drill['startType'] = v)),
            const SizedBox(width: 8),
            Expanded(
                child: _textInput('Superficie',
                    initialValue: drill['surface']?.toString() ?? '',
                    onChanged: (v) => drill['surface'] = v)),
            const SizedBox(width: 8),
            Expanded(
                child: _textInput('Attrezzi',
                    initialValue:
                        (drill['equipment'] as List?)?.join(', ') ?? '',
                    onChanged: (v) => drill['equipment'] = v
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList())),
          ]),
        ],
      ),
    );
  }

  Widget _enduranceSection() {
    return _section(
      title: 'Resistenza',
      icon: Icons.directions_run,
      child: Column(
        children: [
          Row(children: [
            Expanded(
                child: _inlineNumber('Distanza km', _endurance['distanceKm'],
                    (v) => _endurance['distanceKm'] = v)),
            const SizedBox(width: 8),
            Expanded(
                child: _inlineNumber('Velocità km/h', _endurance['avgSpeed'],
                    (v) => _endurance['avgSpeed'] = v)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _textInput('Passo medio',
                    initialValue: _endurance['avgPace']?.toString() ?? '',
                    onChanged: (v) => _endurance['avgPace'] = v)),
            const SizedBox(width: 8),
            Expanded(
                child: _inlineNumber('FC media', _endurance['avgHr'],
                    (v) => _endurance['avgHr'] = v.round())),
            const SizedBox(width: 8),
            Expanded(
                child: _inlineNumber('FC max', _endurance['maxHr'],
                    (v) => _endurance['maxHr'] = v.round())),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _inlineNumber(
                    'Zona 2-3 min',
                    (_endurance['zone23Seconds'] ?? 0) / 60,
                    (v) => _endurance['zone23Seconds'] = (v * 60).round())),
            const SizedBox(width: 8),
            Expanded(
                child: _inlineNumber(
                    'Zona 4-5 min',
                    (_endurance['zone45Seconds'] ?? 0) / 60,
                    (v) => _endurance['zone45Seconds'] = (v * 60).round())),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _inlineNumber(
                    'Dislivello m',
                    _endurance['elevationGainM'],
                    (v) => _endurance['elevationGainM'] = v)),
            const SizedBox(width: 8),
            Expanded(
                child: _inlineNumber('Calorie', _endurance['calories'],
                    (v) => _endurance['calories'] = v.round())),
            const SizedBox(width: 8),
            Expanded(
                child: _textInput('Terreno',
                    initialValue: _endurance['surface']?.toString() ?? '',
                    onChanged: (v) => _endurance['surface'] = v)),
          ]),
        ],
      ),
    );
  }

  Widget _notesOnlySection() {
    return _section(
      title: _categoryLabel(_category),
      icon: Icons.notes,
      child: Text(
        'Usa note, dolore e RPE per salvare questa seduta. I blocchi specifici potranno essere aggiunti in seguito.',
        style: TextStyle(color: AppTheme.textMediumEmphasis),
      ),
    );
  }

  Widget _circuitSection() {
    return _section(
      title: 'Circuiti',
      icon: Icons.loop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _presetButton(
                  '4x4 norvegese', () => _addCircuit('norwegian_4x4')),
              _presetButton(
                  'Corsa intervallata', () => _addCircuit('interval_running')),
              _presetButton('HIIT custom', () => _addCircuit('hiit_custom')),
            ],
          ),
          const SizedBox(height: 12),
          if (_circuits.isEmpty)
            _empty('Aggiungi un circuito o scegli un preset.')
          else
            ..._circuits.asMap().entries.map(
                  (entry) => _circuitCard(entry.key, entry.value),
                ),
        ],
      ),
    );
  }

  Widget _presetButton(String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 16),
      label: Text(label),
    );
  }

  void _addCircuit(String type) {
    setState(() {
      _circuits.add(_circuitPreset(type));
    });
  }

  Map<String, dynamic> _circuitPreset(String type) {
    switch (type) {
      case 'norwegian_4x4':
        return {
          'type': type,
          'name': '4x4 metodo norvegese',
          'rounds': 4,
          'workSeconds': 240,
          'restSeconds': 180,
          'intensity': 'Z4-Z5',
          'intervals': <Map<String, dynamic>>[],
        };
      case 'interval_running':
        return {
          'type': type,
          'name': 'Corsa intervallata',
          'rounds': 6,
          'workSeconds': 60,
          'restSeconds': 60,
          'intensity': 'Medio/alto',
          'intervals': [
            {'name': 'Ripetuta', 'workSeconds': 60, 'restSeconds': 60},
            {'name': 'Recupero attivo', 'workSeconds': 30, 'restSeconds': 30},
          ],
        };
      default:
        return {
          'type': 'hiit_custom',
          'name': 'HIIT personalizzato',
          'rounds': 8,
          'workSeconds': 30,
          'restSeconds': 30,
          'intensity': 'Alta',
          'intervals': <Map<String, dynamic>>[],
        };
    }
  }

  Widget _circuitCard(int index, Map<String, dynamic> circuit) {
    final intervals = (circuit['intervals'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        <Map<String, dynamic>>[];
    circuit['intervals'] = intervals;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _textInput(
                  'Nome',
                  initialValue: circuit['name']?.toString() ?? '',
                  onChanged: (v) => circuit['name'] = v,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                onPressed: () => setState(() => _circuits.removeAt(index)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _inlineNumber('Round', circuit['rounds'],
                    (v) => circuit['rounds'] = v.round()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _inlineNumber('Lavoro s', circuit['workSeconds'],
                    (v) => circuit['workSeconds'] = v.round()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _inlineNumber('Rec s', circuit['restSeconds'],
                    (v) => circuit['restSeconds'] = v.round()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _textInput(
            'Intensità',
            initialValue: circuit['intensity']?.toString() ?? '',
            onChanged: (v) => circuit['intensity'] = v,
          ),
          const SizedBox(height: 12),
          if (intervals.isNotEmpty)
            ...intervals.asMap().entries.map(
                  (entry) => _intervalRow(intervals, entry.key, entry.value),
                ),
          TextButton.icon(
            onPressed: () => setState(() {
              intervals.add({
                'name': 'Intervallo ${intervals.length + 1}',
                'workSeconds': circuit['workSeconds'] ?? 30,
                'restSeconds': circuit['restSeconds'] ?? 30,
              });
            }),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi intervallo'),
          ),
        ],
      ),
    );
  }

  Widget _intervalRow(
    List<Map<String, dynamic>> intervals,
    int index,
    Map<String, dynamic> interval,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _textInput(
              'Intervallo',
              initialValue: interval['name']?.toString() ?? '',
              onChanged: (v) => interval['name'] = v,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _inlineNumber('Lav s', interval['workSeconds'],
                (v) => interval['workSeconds'] = v.round()),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _inlineNumber('Rec s', interval['restSeconds'],
                (v) => interval['restSeconds'] = v.round()),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.error, size: 18),
            onPressed: () => setState(() => intervals.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _personalSection() {
    return _section(
      title: 'Dati personali',
      icon: Icons.person_outline,
      child: Column(
        children: [
          Row(
            children: [
              Text('RPE',
                  style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${_rpe.round()}/10',
                  style: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _rpe,
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: AppTheme.primary,
            onChanged: (value) => setState(() => _rpe = value),
          ),
          _textInput('Dolore', controller: _painCtrl, icon: Icons.healing),
          const SizedBox(height: 12),
          _textInput('Note', controller: _notesCtrl, maxLines: 3),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _tapField(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _inputDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.textMediumEmphasis, size: 16),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: AppTheme.textMediumEmphasis, fontSize: 10)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: AppTheme.textHighEmphasis,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _textInput(
    String label, {
    TextEditingController? controller,
    String? initialValue,
    ValueChanged<String>? onChanged,
    IconData? icon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(color: AppTheme.textHighEmphasis),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
    );
  }

  Widget _inlineNumber(
      String label, dynamic value, ValueChanged<double> onChanged) {
    return TextFormField(
      initialValue: value == null || value == 0 ? '' : value.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
      ],
      style: TextStyle(color: AppTheme.textHighEmphasis, fontSize: 12),
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (text) {
        final parsed = double.tryParse(text.replaceAll(',', '.')) ?? 0;
        onChanged(parsed);
      },
    );
  }

  Widget _empty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.textMediumEmphasis),
      ),
    );
  }

  Widget _summaryPill(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
        ),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.primary, fontWeight: FontWeight.bold)),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.subtleBorder),
    );
  }

  BoxDecoration _inputDecoration() {
    return BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.subtleBorder),
    );
  }
}
