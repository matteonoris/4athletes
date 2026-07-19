import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../data/workout_catalog.dart';
import '../models/models.dart';
import '../models/training_activity_models.dart';
import '../models/workout_creation_models.dart';
import '../providers/app_state.dart';
import '../services/training_activity_service.dart';
import '../services/workout_draft_service.dart';
import '../widgets/running_workout_editor.dart';
import '../widgets/workout_phase_editor.dart';

class WorkoutFlowScreen extends StatefulWidget {
  final WorkoutActivityDefinition activity;
  final WorkoutModeDefinition? initialMode;
  final WorkoutProtocolDefinition? initialProtocol;
  final WorkoutTemplate? initialTemplate;
  final TrainingSession? initialImport;
  final WorkoutDraft? initialDraft;
  final String? existingSessionId;
  final TrainingSession? initialSession;
  final Team? coachTeam;
  final DateTime? initialDate;
  final List<WorkoutParticipant>? initialCoachParticipants;

  const WorkoutFlowScreen({
    super.key,
    required this.activity,
    this.initialMode,
    this.initialProtocol,
    this.initialTemplate,
    this.initialImport,
    this.initialDraft,
    this.existingSessionId,
    this.initialSession,
    this.coachTeam,
    this.initialDate,
    this.initialCoachParticipants,
  });

  @override
  State<WorkoutFlowScreen> createState() => _WorkoutFlowScreenState();
}

class _WorkoutFlowScreenState extends State<WorkoutFlowScreen> {
  late WorkoutDraft _draft;
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;
  WorkoutDraftStore? _draftStore;
  TrainingSession? _selectedImport;
  bool _restoredDraft = false;
  bool _dirty = false;
  bool _saving = false;
  bool _saveAsTemplate = false;
  final bool _preferImportedTiming = true;
  String? _editingTemplateId;
  List<WorkoutParticipant> _availableCoachParticipants = const [];
  bool _loadingCoachParticipants = false;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _draft = widget.initialDraft ??
        WorkoutDraftFactory.create(
          activity: widget.activity,
          userId: appState.userId,
          creatorRole: appState.userProfile?.role ?? 'athlete',
          mode: widget.initialMode,
          protocol: widget.initialProtocol,
        );
    if (widget.initialImport != null &&
        RunningWorkoutMode.isRunningSportId(widget.activity.id)) {
      _draft = WorkoutDraftFactory.applyRunningImport(
        _draft,
        widget.initialImport!,
      );
    }
    if (widget.initialTemplate != null) {
      _draft = _applyTemplateToDraft(_draft, widget.initialTemplate!);
    }
    if (widget.coachTeam != null) {
      final initialDate = widget.initialDate;
      _draft = _draft.copyWith(
        creatorRole: 'coach',
        teamId: widget.coachTeam!.id,
        status: ActivityStatus.planned,
        source: WorkoutDataSource.planned,
        date: initialDate == null
            ? _draft.date
            : DateTime(initialDate.year, initialDate.month, initialDate.day),
        participants: widget.initialCoachParticipants,
      );
      _availableCoachParticipants = widget.initialCoachParticipants ?? const [];
    }
    _selectedImport = widget.initialImport ??
        (widget.initialDraft?.externalLink != null
            ? widget.initialSession
            : null);
    _createControllers();
    _loadLocalDraft();
    _loadCoachParticipants();
  }

  void _createControllers() {
    _titleController = TextEditingController(text: _draft.title);
    _locationController = TextEditingController(text: _draft.location ?? '');
    _notesController = TextEditingController(text: _draft.notes ?? '');
  }

  void _syncControllersFromDraft() {
    _titleController.text = _draft.title;
    _locationController.text = _draft.location ?? '';
    _notesController.text = _draft.notes ?? '';
  }

  Future<void> _loadLocalDraft() async {
    final userId = context.read<AppState>().userId;
    final preferences = await SharedPreferences.getInstance();
    final store = WorkoutDraftStore(preferences);
    final restored =
        widget.existingSessionId == null ? store.load(userId) : null;
    if (!mounted) return;
    setState(() {
      _draftStore = store;
      if (restored != null && restored.activityId == widget.activity.id) {
        _draft = widget.coachTeam == null
            ? restored
            : restored.copyWith(
                creatorRole: 'coach',
                teamId: widget.coachTeam!.id,
                source: WorkoutDataSource.planned,
              );
        _restoredDraft = true;
        _dirty = true;
        _syncControllersFromDraft();
      }
    });
  }

  Future<void> _loadCoachParticipants() async {
    final team = widget.coachTeam;
    if (team == null || widget.initialCoachParticipants != null) return;
    setState(() => _loadingCoachParticipants = true);
    final profiles =
        await context.read<AppState>().loadAthletesForTeam(team.id);
    if (!mounted) return;
    final available = profiles
        .map(
          (profile) => WorkoutParticipant(
            athleteId: profile['id']?.toString() ?? '',
            name: profile['name']?.toString() ?? 'Atleta',
          ),
        )
        .where((participant) => participant.athleteId.isNotEmpty)
        .toList();
    final selectedIds =
        _draft.participants.map((participant) => participant.athleteId).toSet();
    setState(() {
      _availableCoachParticipants = available;
      _loadingCoachParticipants = false;
      if (_draft.participants.isEmpty) {
        _draft = _draft.copyWith(participants: available);
      } else {
        _draft = _draft.copyWith(
          participants: available
              .where(
                  (participant) => selectedIds.contains(participant.athleteId))
              .toList(),
        );
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateDraft(WorkoutDraft Function(WorkoutDraft current) update) {
    setState(() {
      _draft = update(_draft).copyWith(updatedAt: DateTime.now());
      _dirty = true;
    });
    final store = _draftStore;
    if (store != null) {
      store.save(context.read<AppState>().userId, _draft);
    }
  }

  bool get _isRunning => RunningWorkoutMode.isRunningSportId(_draft.activityId);

  WorkoutDraft _draftWithFormValues() {
    final duration = _draft.effectiveDurationMinutes;
    return _draft.copyWith(
      title: _titleController.text.trim(),
      location: _locationController.text.trim(),
      clearLocation: _locationController.text.trim().isEmpty,
      notes: _notesController.text.trim(),
      clearNotes: _notesController.text.trim().isEmpty,
      plannedDurationMinutes: _draft.isPlanned ? duration : null,
      actualDurationMinutes: _draft.isPlanned ? null : duration,
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty || _saving) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Uscire senza salvare?'),
            content: const Text(
              'La bozza resta salvata su questo dispositivo e potrai riprenderla in seguito.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Continua a modificare'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Esci'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _confirmDiscard() && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingSessionId == null
                    ? 'Nuovo allenamento'
                    : 'Modifica allenamento',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                widget.coachTeam == null
                    ? widget.activity.name
                    : '${widget.activity.name} · ${widget.coachTeam!.name}',
                style: TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_restoredDraft)
              Container(
                width: double.infinity,
                color: AppTheme.selectedSoftFill,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Text(
                  'Bozza locale ripristinata',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('workout_single_page'),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _generalStep(),
                    _formDivider(),
                    _structureStep(),
                    if (!_isRunning ||
                        _draft.structureMode ==
                            WorkoutStructureMode.phased) ...[
                      _formDivider(),
                      _contentStep(),
                    ],
                    const SizedBox(height: 8),
                    _saveOptions(),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    key: const ValueKey('save_workout_button'),
                    onPressed: _saving ? null : _validateAndSave,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Salva allenamento'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Divider(color: AppTheme.divider),
      );

  Widget _generalStep() {
    final modes = widget.activity.modes;
    final selectedMode =
        modes.where((mode) => mode.id == _draft.activityMode).firstOrNull;
    final protocols = _isRunning
        ? const <WorkoutProtocolDefinition>[]
        : WorkoutCatalog.protocolsFor(
            widget.activity.id,
            _draft.activityMode,
          );
    final isCoach = widget.coachTeam != null ||
        context.read<AppState>().userProfile?.role == 'coach';
    return Column(
      key: const ValueKey('general_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _activityHeader(),
        if (modes.isNotEmpty) ...[
          const SizedBox(height: 22),
          _sectionLabel('MODALITA'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: modes
                .map(
                  (mode) => ChoiceChip(
                    label: Text(mode.name),
                    selected: _draft.activityMode == mode.id,
                    onSelected: (_) => _changeActivityMode(mode),
                  ),
                )
                .toList(),
          ),
          if (selectedMode != null) ...[
            const SizedBox(height: 10),
            Container(
              key: const ValueKey('selected_mode_description'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.subtleFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                selectedMode.description,
                style: TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
        if (protocols.isNotEmpty) ...[
          const SizedBox(height: 22),
          _sectionLabel('PROTOCOLLO'),
          ...protocols.map(
            (protocol) => ListTile(
              selected: _draft.protocolId == protocol.id,
              leading: Icon(
                _draft.protocolId == protocol.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: _draft.protocolId == protocol.id
                    ? AppTheme.primary
                    : AppTheme.textLowEmphasis,
              ),
              title: Text(protocol.name),
              subtitle: Text(protocol.description),
              onTap: () => _selectProtocol(protocol),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        const SizedBox(height: 22),
        TextField(
          key: const ValueKey('workout_title_field'),
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _markFormDirty(),
          decoration: const InputDecoration(
            labelText: 'Nome allenamento *',
            prefixIcon: Icon(Icons.edit_outlined),
          ),
        ),
        const SizedBox(height: 12),
        if (isCoach)
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: ActivityStatus.planned,
                label: Text('Pianificato'),
                icon: Icon(Icons.event_outlined),
              ),
              ButtonSegment(
                value: ActivityStatus.completed,
                label: Text('Completato'),
                icon: Icon(Icons.check_circle_outline),
              ),
            ],
            selected: {_draft.status},
            onSelectionChanged: (selection) => _updateDraft(
              (draft) => draft.copyWith(status: selection.first),
            ),
          ),
        if (isCoach) const SizedBox(height: 12),
        if (widget.coachTeam != null) ...[
          _coachParticipantsCard(),
          const SizedBox(height: 12),
        ],
        _dateTimeCard(),
        const SizedBox(height: 12),
        TextField(
          controller: _locationController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _markFormDirty(),
          decoration: const InputDecoration(
            labelText: 'Luogo',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _markFormDirty(),
          decoration: const InputDecoration(
            labelText: 'Note',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.notes),
          ),
        ),
        if (_isRunning) ...[
          const SizedBox(height: 18),
          _runningMetricsCard(),
        ],
        const SizedBox(height: 18),
        _templatePicker(),
      ],
    );
  }

  Widget _coachParticipantsCard() {
    final team = widget.coachTeam!;
    final selectedIds =
        _draft.participants.map((participant) => participant.athleteId).toSet();
    return Container(
      key: const ValueKey('coach_participants_card'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.groups_outlined, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        selectedIds.length == 1
                            ? '1 atleta selezionato'
                            : '${selectedIds.length} atleti selezionati',
                        style: TextStyle(
                          color: AppTheme.textMediumEmphasis,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_availableCoachParticipants.isNotEmpty)
                  TextButton(
                    onPressed: () => _updateDraft(
                      (draft) => draft.copyWith(
                        participants: selectedIds.length ==
                                _availableCoachParticipants.length
                            ? const []
                            : List<WorkoutParticipant>.from(
                                _availableCoachParticipants,
                              ),
                      ),
                    ),
                    child: Text(
                      selectedIds.length == _availableCoachParticipants.length
                          ? 'Nessuno'
                          : 'Tutti',
                    ),
                  ),
              ],
            ),
          ),
          if (_loadingCoachParticipants)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_availableCoachParticipants.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                'Nessun atleta disponibile in questo team.',
                style: TextStyle(color: AppTheme.textMediumEmphasis),
              ),
            )
          else
            ..._availableCoachParticipants.map((participant) {
              final selected = selectedIds.contains(participant.athleteId);
              return CheckboxListTile(
                key: ValueKey('coach_participant_${participant.athleteId}'),
                value: selected,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(participant.name ?? 'Atleta'),
                onChanged: (checked) => _updateDraft((draft) {
                  final participants =
                      List<WorkoutParticipant>.from(draft.participants);
                  participants.removeWhere(
                    (item) => item.athleteId == participant.athleteId,
                  );
                  if (checked == true) participants.add(participant);
                  return draft.copyWith(participants: participants);
                }),
              );
            }),
        ],
      ),
    );
  }

  Widget _runningMetricsCard() {
    final details = Map<String, dynamic>.from(
      _selectedImport?.details ?? const <String, dynamic>{},
    );
    final imported = _selectedImport != null ||
        _draft.runningSummary?.source == RunningMetricSource.imported;
    if (imported) {
      final summary = _draft.runningSummary;
      final rows = <_SummaryRow>[];
      final source = details['source_name']?.toString().trim();
      rows.add(_SummaryRow(
        Icons.sync,
        'Sorgente',
        source == null || source.isEmpty ? 'App Salute' : source,
      ));
      _addImportedMetric(
        rows,
        Icons.timer_outlined,
        'Durata attiva',
        _minutesMetric(
          details['active_duration_minutes'] ??
              details['active_duration'] ??
              _selectedImport?.duration,
        ),
      );
      _addImportedMetric(
        rows,
        Icons.schedule_outlined,
        'Durata totale',
        _minutesMetric(
          details['total_duration_minutes'] ?? details['total_duration'],
        ),
      );
      _addImportedMetric(
        rows,
        Icons.route_outlined,
        'Distanza',
        _distanceMetric(
          details['distance_meters'] ?? summary?.distanceMeters,
          fallback: details['distance'],
        ),
      );
      _addImportedMetric(
        rows,
        Icons.speed_outlined,
        'Passo medio',
        _paceMetric(
          details['avg_pace_sec_per_km'] ?? summary?.avgPaceSecondsPerKm,
          fallback: details['pace'],
        ),
      );
      _addImportedMetric(
        rows,
        Icons.bolt_outlined,
        'Velocita media',
        _speedMetric(
          details['avg_speed_kmh'] ?? summary?.avgSpeedKmh,
          fallback: details['speed'],
        ),
      );
      _addImportedMetric(
        rows,
        Icons.local_fire_department_outlined,
        'Calorie',
        _unitMetric(
          details['energy_total_kcal'] ?? details['calories'],
          'kcal',
        ),
      );
      _addImportedMetric(
        rows,
        Icons.terrain_outlined,
        'Dislivello',
        _unitMetric(
          details['elevation_meters'],
          'm',
          fallback: details['elevation'],
        ),
      );
      _addImportedMetric(
        rows,
        Icons.directions_run_outlined,
        'Cadenza',
        _unitMetric(
          details['avg_cadence_spm'] ?? details['cadence'],
          'spm',
        ),
      );
      if (details['hr_reliable'] == true) {
        _addImportedMetric(
          rows,
          Icons.favorite_outline,
          'Frequenza cardiaca media',
          _unitMetric(details['avg_hr'], 'bpm'),
        );
        _addImportedMetric(
          rows,
          Icons.favorite,
          'Frequenza cardiaca massima',
          _unitMetric(details['max_hr'], 'bpm'),
        );
      }
      final laps = details['imported_laps'] ??
          details['imported_segments'] ??
          details['laps'] ??
          details['segments'];
      if (laps is List && laps.isNotEmpty) {
        rows.add(_SummaryRow(
          Icons.flag_outlined,
          'Giri / segmenti',
          '${laps.length}',
        ));
      }
      return Column(
        key: const ValueKey('running_imported_metrics'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('DATI IMPORTATI'),
          const SizedBox(height: 8),
          _summaryCard(rows),
          const SizedBox(height: 8),
          Text(
            'Le metriche della sorgente non sono modificabili. Note, RPE e struttura restano tuoi.',
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    final summary = (_draft.runningSummary ?? const RunningSummaryDraft())
        .derivedForDuration(_draft.effectiveDurationMinutes * 60);
    return Column(
      key: const ValueKey('running_manual_metrics'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('DATI DELLA CORSA'),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('running_distance_field'),
          initialValue: summary.distanceMeters == null
              ? ''
              : _compactNumber(summary.distanceMeters! / 1000),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Distanza totale (km, opzionale)',
            prefixIcon: Icon(Icons.route_outlined),
          ),
          onChanged: (raw) {
            final parsed = double.tryParse(raw.replaceAll(',', '.'));
            _updateDraft(
              (draft) => draft.copyWith(
                runningSummary: RunningSummaryDraft(
                  distanceMeters: parsed == null ? null : parsed * 1000,
                  source: RunningMetricSource.manual,
                ),
              ),
            );
          },
        ),
        if (summary.hasDistance) ...[
          const SizedBox(height: 10),
          _summaryCard([
            _SummaryRow(
              Icons.speed_outlined,
              'Passo medio calcolato',
              _formatPace(summary.avgPaceSecondsPerKm!),
            ),
            _SummaryRow(
              Icons.bolt_outlined,
              'Velocita media calcolata',
              '${summary.avgSpeedKmh!.toStringAsFixed(2)} km/h',
            ),
          ]),
        ],
        const SizedBox(height: 8),
        Text(
          'Passo e velocita usano la durata compresa tra ora di inizio e fine.',
          style: TextStyle(
            color: AppTheme.textMediumEmphasis,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _structureStep() {
    return Column(
      key: const ValueKey('structure_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Quanto vuoi dettagliare la sessione?',
          _isRunning
              ? 'La scheda semplice contiene solo i totali. La scheda completa aggiunge le fasi.'
              : 'Scegli il livello di dettaglio della sessione.',
        ),
        const SizedBox(height: 18),
        _structureOption(
          value: WorkoutStructureMode.simple,
          title: 'Scheda semplice',
          description: _isRunning
              ? 'Metriche complessive, senza fasi o segmenti.'
              : 'Solo lavoro principale o registrazione generale.',
          icon: Icons.short_text,
        ),
        const SizedBox(height: 12),
        _structureOption(
          value: WorkoutStructureMode.phased,
          title: 'Scheda completa',
          description:
              'Riscaldamento, lavoro principale e defaticamento. Le fasi esterne sono opzionali.',
          icon: Icons.view_agenda_outlined,
        ),
      ],
    );
  }

  Widget _contentStep() {
    if (_isRunning) {
      return Column(
        key: const ValueKey('content_step'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Costruisci la corsa',
            _draft.activityMode == RunningWorkoutMode.intervals
                ? 'Organizza il lavoro principale in blocchi omogenei di ripetute.'
                : 'Riscaldamento e defaticamento sono opzionali. Compila il lavoro principale.',
          ),
          const SizedBox(height: 16),
          RunningWorkoutEditor(
            phases: _draft.phases,
            mode: _draft.activityMode ?? RunningWorkoutMode.free,
            isPlanned: _draft.isPlanned,
            onChanged: (phases) => _updateDraft(
              (draft) => draft.copyWith(phases: phases),
            ),
          ),
        ],
      );
    }
    return Column(
      key: const ValueKey('content_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Costruisci le fasi',
          _draft.editorKind == WorkoutEditorKind.endurance
              ? 'Aggiungi i segmenti della sessione. Intervalli e recuperi restano disponibili in Altro.'
              : _draft.activityCategory == ActivityCategory.speedAgility
                  ? 'Seleziona un drill e registra ogni prova con distanza, tempo e recupero.'
                  : 'Seleziona gli esercizi dal catalogo e compila peso e ripetizioni per ogni singola serie.',
        ),
        const SizedBox(height: 16),
        WorkoutPhaseEditor(
          phases: _draft.phases,
          structureMode: _draft.structureMode,
          editorKind: _draft.editorKind,
          activityCategory: _draft.activityCategory,
          suggestedExercises: widget.activity.suggestedExercises,
          onChanged: (phases) => _updateDraft((draft) {
            final updated = draft.copyWith(phases: phases);
            return draft.activityId == 'conditioning_hiit'
                ? WorkoutDraftFactory.syncConditioningPhases(updated)
                : updated;
          }),
        ),
      ],
    );
  }

  Widget _saveOptions() {
    return Column(
      key: const ValueKey('save_options'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedImport != null)
          _summaryCard([
            _SummaryRow(
              Icons.merge,
              'Merge',
              _selectedImport!.details?['source_name']?.toString() ?? 'Health',
            ),
          ]),
        if (_selectedImport != null) const SizedBox(height: 8),
        SwitchListTile(
          key: const ValueKey('save_as_template_switch'),
          value: _saveAsTemplate,
          onChanged: (value) => setState(() => _saveAsTemplate = value),
          contentPadding: EdgeInsets.zero,
          title: const Text('Salva anche come template'),
          subtitle: const Text(
              'Data, ora, luogo e partecipanti non saranno richiesti.'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Dopo il salvataggio vedrai subito il riepilogo completo dell’allenamento.',
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _sessionRpeCard(),
      ],
    );
  }

  Widget _sessionRpeCard() {
    final rpe = _draft.sessionRpe;
    final description = switch (rpe) {
      <= 2 => 'Molto leggero',
      <= 4 => 'Leggero',
      <= 6 => 'Moderato',
      <= 8 => 'Intenso',
      _ => 'Massimale',
    };
    return Container(
      key: const ValueKey('session_rpe_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_outlined, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RPE sessione',
                      style: TextStyle(
                        color: AppTheme.textHighEmphasis,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Sforzo complessivo percepito',
                      style: TextStyle(
                        color: AppTheme.textMediumEmphasis,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$rpe/10',
                key: const ValueKey('session_rpe_value'),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('session_rpe_slider'),
            value: rpe.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$rpe',
            onChanged: (value) => _updateDraft(
              (draft) => draft.copyWith(sessionRpe: value.round()),
            ),
          ),
          Center(
            child: Text(
              description,
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _validateAndSave() async {
    _draft = _draftWithFormValues();
    final errors = _draft.validateForStep(4);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errors.first), backgroundColor: AppTheme.error),
      );
      return;
    }
    await _draftStore?.save(context.read<AppState>().userId, _draft);
    await _save();
  }

  Future<void> _save() async {
    if (_saving) return;
    final draft = _draftWithFormValues();
    if (widget.coachTeam != null && draft.participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona almeno un atleta.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final appState = context.read<AppState>();
      late final TrainingSession session;
      if (widget.coachTeam != null) {
        final event = CoachWorkoutEventFactory.create(
          draft: draft,
          team: widget.coachTeam!,
          coachId: appState.userId,
        );
        await appState.saveCoachEvent(event, rethrowErrors: true);
        session = CoachWorkoutEventFactory.previewSession(
          event: event,
          draft: draft,
        );
      } else {
        if (_selectedImport != null) {
          session = WorkoutExternalMergeService.merge(
            draft,
            _selectedImport!,
            preferImportedTiming: _preferImportedTiming,
            targetSessionId: widget.existingSessionId,
          );
        } else if (widget.initialSession != null &&
            draft.externalLink != null) {
          session = WorkoutExternalMergeService.updateLinkedWorkout(
            draft,
            widget.initialSession!,
          );
        } else {
          final generated = draft.toTrainingSession(
            sessionId: widget.existingSessionId,
          );
          session = widget.initialSession == null
              ? generated
              : WorkoutDraftFactory.preserveOriginalMetadata(
                  generated,
                  widget.initialSession!,
                );
        }
        await appState.addSession(session, rethrowErrors: true);
        if (widget.existingSessionId != null &&
            _selectedImport != null &&
            _selectedImport!.id != widget.existingSessionId) {
          await appState.deleteSession(_selectedImport!.id);
        }
      }
      if (_saveAsTemplate) {
        final activity = TrainingActivity.fromTrainingSession(
          session,
          athleteId: appState.userId,
          title: draft.title,
        );
        final template = const TrainingActivityService().saveActivityAsTemplate(
          activity,
          templateId: _editingTemplateId ??
              'template_${DateTime.now().microsecondsSinceEpoch}',
          name: draft.title,
          ownerType: appState.userProfile?.role == 'coach'
              ? TemplateOwnerType.coach
              : TemplateOwnerType.athlete,
          ownerId: appState.userId,
          createdBy: appState.userId,
          activityMode: draft.activityMode,
          protocolId: draft.protocolId,
          structureMode: draft.structureMode,
          plannedDurationMinutes: draft.plannedDurationMinutes,
        );
        await appState.saveWorkoutTemplate(template);
      }
      await _draftStore?.clear(appState.userId);
      _dirty = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allenamento salvato.'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, session);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Salvataggio non riuscito: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _activityHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(widget.activity.icon, color: AppTheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.activity.name,
                style: TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.activity.description,
                style: TextStyle(color: AppTheme.textMediumEmphasis),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateTimeCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined,
                color: AppTheme.primary),
            title: const Text('Data'),
            trailing: Text(DateFormat('dd/MM/yyyy').format(_draft.date)),
            onTap: _pickDate,
          ),
          Divider(height: 1, color: AppTheme.divider),
          ListTile(
            leading: const Icon(Icons.schedule, color: AppTheme.primary),
            title: const Text('Ora di inizio'),
            trailing: Text(_draft.effectiveStartTime),
            onTap: () => _pickTime(isEnd: false),
          ),
          Divider(height: 1, color: AppTheme.divider),
          ListTile(
            key: const ValueKey('workout_end_time'),
            leading:
                const Icon(Icons.schedule_outlined, color: AppTheme.primary),
            title: const Text('Ora di fine'),
            trailing: Text(_draft.effectiveEndTime),
            onTap: () => _pickTime(isEnd: true),
          ),
          if (_draft.activityId == 'conditioning_hiit') ...[
            Divider(height: 1, color: AppTheme.divider),
            ListTile(
              leading:
                  const Icon(Icons.timer_outlined, color: AppTheme.primary),
              title: const Text('Durata totale'),
              subtitle: Text(
                _conditioningDurationSummary(),
                style: TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontSize: 12,
                ),
              ),
              trailing: Text(
                '${_draft.effectiveDurationMinutes.clamp(10, 60)} min',
                key: const ValueKey('conditioning_duration_value'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Slider(
                key: const ValueKey('conditioning_duration_slider'),
                value: _draft.effectiveDurationMinutes.clamp(10, 60).toDouble(),
                min: 10,
                max: 60,
                divisions: 10,
                label: '${_draft.effectiveDurationMinutes.clamp(10, 60)} min',
                onChanged: (value) => _updateDraft(
                  (draft) => WorkoutDraftFactory.setConditioningDuration(
                    draft,
                    value.round(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _conditioningDurationSummary() {
    if (_draft.structureMode != WorkoutStructureMode.phased) {
      return 'Tutto il tempo va al lavoro principale';
    }
    final warmup = _phaseMinutes(TrainingPhase.warmup);
    final cooldown = _phaseMinutes(TrainingPhase.cooldown);
    final main = WorkoutDraftFactory.conditioningMainMinutes(_draft);
    return 'Riscaldamento $warmup min · lavoro $main min · defaticamento $cooldown min';
  }

  int _phaseMinutes(String type) {
    final phase = _draft.phases
        .where((phase) => phase.type == type && phase.isEnabled)
        .firstOrNull;
    if (phase == null) return 0;
    final seconds = phase.blocks.fold<int>(0, (sum, block) {
      final value = block.fields['durationSeconds'];
      return sum + (value is num ? value.round() : 0);
    });
    return (seconds / 60).round();
  }

  Widget _structureOption({
    required String value,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final selected = _draft.structureMode == value;
    return InkWell(
      key: ValueKey('structure_$value'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => _changeStructure(value),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? AppTheme.selectedSoftFill : AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.subtleBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                    selected ? AppTheme.primary : AppTheme.textMediumEmphasis),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: TextStyle(
                          color: AppTheme.textMediumEmphasis, fontSize: 12)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppTheme.primary : AppTheme.textLowEmphasis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _templatePicker() {
    final templates = context.watch<AppState>().workoutTemplates.where(
          (template) =>
              template.category == widget.activity.category ||
              template.sportType == widget.activity.id,
        );
    if (templates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PARTI DA UN TEMPLATE'),
        ...templates.take(5).map(
              (template) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bookmark_outline),
                title: Text(template.name),
                subtitle: Text('${template.blocks.length} blocchi'),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Azioni template',
                  onSelected: (action) => _templateAction(template, action),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'apply', child: Text('Applica')),
                    PopupMenuItem(value: 'edit', child: Text('Modifica')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplica')),
                    PopupMenuItem(value: 'delete', child: Text('Elimina')),
                  ],
                ),
                onTap: () {
                  _updateDraft(
                      (draft) => _applyTemplateToDraft(draft, template));
                  _syncControllersFromDraft();
                },
              ),
            ),
      ],
    );
  }

  Future<void> _templateAction(
    WorkoutTemplate template,
    String action,
  ) async {
    final appState = context.read<AppState>();
    switch (action) {
      case 'apply':
        _updateDraft((draft) => _applyTemplateToDraft(draft, template));
        _syncControllersFromDraft();
      case 'edit':
        _updateDraft((draft) => _applyTemplateToDraft(draft, template));
        setState(() {
          _editingTemplateId = template.id;
          _saveAsTemplate = true;
        });
        _syncControllersFromDraft();
      case 'duplicate':
        final now = DateTime.now();
        final copy = WorkoutTemplate(
          id: 'template_${now.microsecondsSinceEpoch}',
          name: '${template.name} (copia)',
          description: template.description,
          ownerType: appState.userProfile?.role == 'coach'
              ? TemplateOwnerType.coach
              : TemplateOwnerType.athlete,
          ownerId: appState.userId,
          teamId: template.teamId,
          category: template.category,
          sportType: template.sportType,
          activityMode: template.activityMode,
          protocolId: template.protocolId,
          structureMode: template.structureMode,
          plannedDurationMinutes: template.plannedDurationMinutes,
          visibility: template.visibility,
          blocks: template.blocks.map((block) => block.deepCopy()).toList(),
          createdBy: appState.userId,
          createdAt: now,
          updatedAt: now,
        );
        await appState.saveWorkoutTemplate(copy);
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminare il template?'),
            content: Text(
              'Il template "${template.name}" non sara piu disponibile. Gli allenamenti creati in precedenza non cambieranno.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await appState.archiveWorkoutTemplate(template.id);
        }
    }
  }

  Widget _summaryCard(List<_SummaryRow> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Icon(row.icon,
                        size: 19, color: AppTheme.textMediumEmphasis),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(row.label,
                          style: TextStyle(color: AppTheme.textMediumEmphasis)),
                    ),
                    Flexible(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _draft.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('it'),
    );
    if (date != null) _updateDraft((draft) => draft.copyWith(date: date));
  }

  Future<void> _pickTime({required bool isEnd}) async {
    final current = isEnd ? _draft.effectiveEndTime : _draft.effectiveStartTime;
    final parts = current.split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );
    if (time == null) return;
    final value =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    _updateDraft((draft) {
      final start = isEnd ? draft.effectiveStartTime : value;
      final end = isEnd ? value : draft.effectiveEndTime;
      final duration = _minutesBetween(start, end);
      final updated = draft.isPlanned
          ? draft.copyWith(
              plannedStartTime: isEnd ? draft.plannedStartTime : value,
              plannedEndTime: isEnd ? value : draft.plannedEndTime,
              plannedDurationMinutes: duration,
            )
          : draft.copyWith(
              plannedStartTime: isEnd ? draft.plannedStartTime : value,
              actualStartTime: isEnd ? draft.actualStartTime : value,
              actualEndTime: isEnd ? value : draft.actualEndTime,
              actualDurationMinutes: duration,
            );
      return draft.activityId == 'conditioning_hiit'
          ? WorkoutDraftFactory.syncConditioningPhases(updated)
          : updated;
    });
  }

  Future<void> _changeActivityMode(WorkoutModeDefinition mode) async {
    if (_draft.activityMode == mode.id) return;
    if (!_isRunning) {
      _updateDraft(
        (draft) => draft.activityId == 'conditioning_hiit'
            ? WorkoutDraftFactory.configureConditioningMode(draft, mode.id)
            : draft.copyWith(activityMode: mode.id),
      );
      return;
    }

    final main = _draft.phases
        .where((phase) => phase.type == TrainingPhase.main)
        .firstOrNull;
    if (main != null && main.blocks.isNotEmpty) {
      final confirmed = await _confirmRunningReset(
        title: 'Cambiare modalita?',
        message:
            'Il lavoro principale non e compatibile con la nuova modalita e verra rimosso. Riscaldamento e defaticamento resteranno invariati.',
        confirmLabel: 'Cambia modalita',
      );
      if (!confirmed || !mounted) return;
    }

    _updateDraft((draft) {
      final phases = draft.phases.map((phase) {
        if (phase.type != TrainingPhase.main) return phase;
        return phase.copyWith(isEnabled: true, blocks: const []);
      }).toList();
      return draft.copyWith(
        activityMode: mode.id,
        clearLegacyActivityMode: true,
        clearProtocol: true,
        phases: phases,
      );
    });
  }

  Future<void> _changeStructure(String value) async {
    if (_draft.structureMode == value) return;
    if (_isRunning) {
      if (value == WorkoutStructureMode.simple &&
          _draft.phases.any((phase) => phase.blocks.isNotEmpty)) {
        final confirmed = await _confirmRunningReset(
          title: 'Passare alla scheda semplice?',
          message:
              'Riscaldamento, lavoro principale e defaticamento verranno rimossi. Le metriche complessive resteranno disponibili.',
          confirmLabel: 'Usa scheda semplice',
        );
        if (!confirmed || !mounted) return;
      }
      _updateDraft(
        (draft) => draft.copyWith(
          structureMode: value,
          phases: value == WorkoutStructureMode.simple
              ? _emptyRunningPhases()
              : draft.phases.map((phase) {
                  if (phase.type == TrainingPhase.main) {
                    return phase.copyWith(isEnabled: true);
                  }
                  return phase;
                }).toList(),
        ),
      );
      return;
    }

    _updateDraft((draft) {
      final phases = draft.phases.map((phase) {
        if (phase.type == TrainingPhase.main) return phase;
        return phase.copyWith(
          isEnabled:
              value == WorkoutStructureMode.phased ? phase.isEnabled : false,
        );
      }).toList();
      final updated = draft.copyWith(
        structureMode: value,
        phases: phases,
      );
      return draft.activityId == 'conditioning_hiit'
          ? WorkoutDraftFactory.syncConditioningPhases(updated)
          : updated;
    });
  }

  Future<bool> _confirmRunningReset({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  List<WorkoutPhaseDraft> _emptyRunningPhases() => const [
        WorkoutPhaseDraft(
          type: TrainingPhase.warmup,
          isEnabled: false,
        ),
        WorkoutPhaseDraft(
          type: TrainingPhase.main,
        ),
        WorkoutPhaseDraft(
          type: TrainingPhase.cooldown,
          isEnabled: false,
        ),
      ];

  void _addImportedMetric(
    List<_SummaryRow> rows,
    IconData icon,
    String label,
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) return;
    rows.add(_SummaryRow(icon, label, value));
  }

  String? _minutesMetric(dynamic value) {
    if (value == null) return null;
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value.toString().replaceAll(',', '.'));
    if (number == null || number <= 0) return null;
    return '${_compactNumber(number)} min';
  }

  String? _distanceMetric(dynamic value, {dynamic fallback}) {
    final meters = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
    if (meters != null && meters > 0) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    final text = fallback?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _paceMetric(dynamic value, {dynamic fallback}) {
    final seconds =
        value is num ? value.round() : int.tryParse(value?.toString() ?? '');
    if (seconds != null && seconds > 0) return _formatPace(seconds);
    final text = fallback?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _speedMetric(dynamic value, {dynamic fallback}) {
    final speed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
    if (speed != null && speed > 0) {
      return '${speed.toStringAsFixed(2)} km/h';
    }
    final text = fallback?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _unitMetric(dynamic value, String unit, {dynamic fallback}) {
    if (value != null) {
      if (value is num && value > 0) {
        return '${_compactNumber(value.toDouble())} $unit';
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return RegExp('[a-zA-Z]').hasMatch(text) ? text : '$text $unit';
      }
    }
    final text = fallback?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _formatPace(int secondsPerKm) {
    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')} min/km";
  }

  String _compactNumber(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(
          RegExp(r'\.$'),
          '',
        );
  }

  void _selectProtocol(WorkoutProtocolDefinition protocol) {
    _updateDraft((draft) {
      final phases = draft.phases.map((phase) {
        if (phase.type != TrainingPhase.main || phase.blocks.isEmpty) {
          return phase;
        }
        final blocks = phase.blocks.map((block) => block.copyWith()).toList();
        blocks[0] = blocks.first.copyWith(
          kind: WorkoutBlockKind.interval,
          title: protocol.name,
          fields: Map<String, dynamic>.from(protocol.defaults),
        );
        return phase.copyWith(blocks: blocks);
      }).toList();
      return draft.copyWith(
        protocolId: protocol.id,
        protocolName: protocol.name,
        title: draft.title == widget.activity.name ||
                draft.title == _draft.protocolName
            ? protocol.name
            : draft.title,
        phases: phases,
      );
    });
    _titleController.text = _draft.title;
  }

  WorkoutDraft _applyTemplateToDraft(
    WorkoutDraft draft,
    WorkoutTemplate template,
  ) {
    final grouped = <String, List<WorkoutBlockDraft>>{
      TrainingPhase.warmup: [],
      TrainingPhase.main: [],
      TrainingPhase.cooldown: [],
    };
    for (final block in template.blocks) {
      final phase = TrainingPhase.normalize(block.metrics['phase']);
      final kind = block.metrics['blockKind']?.toString() ??
          switch (block.type) {
            TrainingBlockType.strength => WorkoutBlockKind.exerciseSets,
            TrainingBlockType.endurance => WorkoutBlockKind.sport,
            TrainingBlockType.circuit => WorkoutBlockKind.circuit,
            _ => WorkoutBlockKind.note,
          };
      grouped[phase]!.add(WorkoutBlockDraft(
        id: '${block.id}_copy_${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        title: block.name,
        order: grouped[phase]!.length,
        fields: {
          ...block.metrics,
          if (block.notes != null) 'notes': block.notes,
          if (block.exercises.isNotEmpty) ...{
            'exerciseId': block.exercises.first.exerciseId,
            'equipment': block.exercises.first.equipment,
            'variant': block.exercises.first.variant,
            'side': block.exercises.first.unilateralMode,
            'sets':
                block.exercises.first.sets.map((set) => set.toJson()).toList(),
            'recoverySeconds':
                block.exercises.first.sets.firstOrNull?.restSeconds,
          },
        }..removeWhere((_, value) => value == null),
      ));
    }
    final hasPhases = grouped[TrainingPhase.warmup]!.isNotEmpty ||
        grouped[TrainingPhase.cooldown]!.isNotEmpty;
    return draft.copyWith(
      title: template.name,
      activityId: template.sportType ?? draft.activityId,
      activityCategory: template.category,
      structureMode:
          hasPhases ? WorkoutStructureMode.phased : WorkoutStructureMode.simple,
      phases: TrainingPhase.ordered
          .map(
            (type) => WorkoutPhaseDraft(
              type: type,
              isEnabled:
                  type == TrainingPhase.main || grouped[type]!.isNotEmpty,
              blocks: grouped[type]!,
            ),
          )
          .toList(),
    );
  }

  void _markFormDirty() {
    _dirty = true;
    _draft = _draftWithFormValues();
    final store = _draftStore;
    if (store != null) {
      store.save(context.read<AppState>().userId, _draft);
    }
  }

  static int _minutesBetween(String start, String end) {
    int value(String clock) {
      final parts = clock.split(':');
      return (int.tryParse(parts.first) ?? 0) * 60 +
          (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
    }

    final startMinutes = value(start);
    final endMinutes = value(end);
    if (startMinutes == endMinutes) return 0;
    return endMinutes > startMinutes
        ? endMinutes - startMinutes
        : (24 * 60 - startMinutes) + endMinutes;
  }

  static Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.textMediumEmphasis,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  static Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppTheme.textHighEmphasis,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(color: AppTheme.textMediumEmphasis, height: 1.35),
        ),
      ],
    );
  }
}

class _SummaryRow {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow(this.icon, this.label, this.value);
}
