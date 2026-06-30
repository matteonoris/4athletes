// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../data/exercises.dart';
import '../models/models.dart';
import '../models/training_activity_models.dart';
import '../providers/app_state.dart';
import '../services/training_activity_service.dart';
import '../utils/coach_training_utils.dart';
import '../widgets/custom_card.dart';

class CoachEventDetailsScreen extends StatefulWidget {
  final CalendarEvent? event;
  final Team? selectedTeam;
  final DateTime? initialDate;
  final bool isSkiWorkout;

  const CoachEventDetailsScreen({
    super.key,
    this.event,
    this.selectedTeam,
    this.initialDate,
    this.isSkiWorkout = true,
  });

  @override
  State<CoachEventDetailsScreen> createState() =>
      _CoachEventDetailsScreenState();
}

class _BlockDraft {
  final String id;
  final String name;
  final TextEditingController lapsCtrl;
  final TextEditingController metricCtrl;

  _BlockDraft({
    required this.id,
    required this.name,
    String laps = '',
    String metric = '',
  })  : lapsCtrl = TextEditingController(text: laps),
        metricCtrl = TextEditingController(text: metric);

  Map<String, dynamic> toTrackJson(String specialty) => {
        'id': id,
        'name': name,
        'specialty': specialty,
        'laps': lapsCtrl.text,
        'gates': metricCtrl.text,
        'changes': metricCtrl.text,
      };

  Map<String, dynamic> toTrainingJson(String specialty) => {
        'id': id,
        'name': name,
        'specialty': specialty,
        'laps': lapsCtrl.text,
        'references': metricCtrl.text,
        'changes': metricCtrl.text,
      };

  void dispose() {
    lapsCtrl.dispose();
    metricCtrl.dispose();
  }
}

class _SkiSpecialtyDraft {
  String specialty;
  final TextEditingController freeLapsCtrl;
  final TextEditingController freeChangesCtrl;
  final List<_BlockDraft> tracks;
  final List<_BlockDraft> trainingBlocks;

  _SkiSpecialtyDraft({
    required this.specialty,
    String freeLaps = '',
    String freeChanges = '',
    List<_BlockDraft>? tracks,
    List<_BlockDraft>? trainingBlocks,
  })  : freeLapsCtrl = TextEditingController(text: freeLaps),
        freeChangesCtrl = TextEditingController(text: freeChanges),
        tracks = tracks ?? [],
        trainingBlocks = trainingBlocks ?? [];

  void dispose() {
    freeLapsCtrl.dispose();
    freeChangesCtrl.dispose();
    for (final track in tracks) {
      track.dispose();
    }
    for (final block in trainingBlocks) {
      block.dispose();
    }
  }
}

class _CoachEventDetailsScreenState extends State<CoachEventDetailsScreen> {
  final _trainingActivityService = const TrainingActivityService();

  static const _snowOptions = [
    'Dura/Ghiacciata',
    'Compatta',
    'Morbida',
    'Primaverile',
    'Fresca',
  ];
  static const _weatherOptions = [
    'Sole',
    'Nuvolo',
    'Nevicata',
    'Nebbia',
    'Vento',
  ];

  late TextEditingController _titleCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _snowCtrl;
  late TextEditingController _weatherCtrl;
  late TextEditingController _drylandSpecialtyCtrl;

  String _eventStatus = CoachTrainingUtils.statusPlanned;
  String _eventType = 'training';
  String _sportCategory = 'ski';
  int _qualityRating = 3;
  bool _chronoEnabled = false;
  bool _isLoadingAthletes = false;
  bool _isSaving = false;
  String _searchQuery = '';
  String _drylandCategory = ActivityCategory.athleticPrep;
  String _exerciseSearch = '';
  String _equipmentFilter = 'all';

  final List<Team> _selectedTeams = [];
  final List<Map<String, dynamic>> _athletes = [];
  final List<_SkiSpecialtyDraft> _skiDrafts = [];
  final List<Map<String, dynamic>> _strengthExercises = [];
  final List<Map<String, dynamic>> _plyometricExercises = [];
  final List<Map<String, dynamic>> _speedDrills = [];
  final List<Map<String, dynamic>> _circuits = [];
  final Map<String, dynamic> _endurance = {};

  bool get _isExistingCompleted =>
      widget.event?.status == CoachTrainingUtils.statusCompleted;

  bool get _isSki => _sportCategory == 'ski';
  bool get _isExerciseCategory =>
      _drylandCategory == ActivityCategory.strength ||
      _drylandCategory == ActivityCategory.mobility ||
      _drylandCategory == ActivityCategory.core;
  bool get _usesDurationSets =>
      _drylandCategory == ActivityCategory.mobility ||
      _drylandCategory == ActivityCategory.core;
  bool get _isPlyometrics => _drylandCategory == ActivityCategory.plyometrics;
  bool get _isSpeed => _drylandCategory == ActivityCategory.speedAgility;
  bool get _isCircuit => _drylandCategory == ActivityCategory.circuit;
  bool get _isEndurance => _drylandCategory == ActivityCategory.endurance;
  bool get _isAthleticPrep =>
      _sportCategory == 'dryland' &&
      _drylandCategory == ActivityCategory.athleticPrep;
  bool get _showTechnical =>
      _isSki && _eventStatus == CoachTrainingUtils.statusCompleted;

  bool get _hasEnded {
    final date = DateTime.tryParse(_dateCtrl.text);
    final end = _parseTime(_endCtrl.text);
    if (date == null) return false;
    final endDateTime =
        DateTime(date.year, date.month, date.day, end.hour, end.minute);
    return DateTime.now().isAfter(endDateTime);
  }

  bool get _canComplete => _hasEnded || _isExistingCompleted;

  List<Map<String, dynamic>> get _invitedAthletes =>
      _athletes.where((a) => a['isInvited'] == true).toList();

  List<Map<String, dynamic>> get _presentAthletes =>
      _invitedAthletes.where(CoachTrainingUtils.isAttendeePresent).toList();

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final tech = event?.technicalDetails ?? {};

    _eventStatus = event?.status ?? CoachTrainingUtils.statusPlanned;
    _eventType = event?.type == 'race' ? 'race' : 'training';
    _sportCategory =
        event?.sportCategory ?? (widget.isSkiWorkout ? 'ski' : 'dryland');
    _qualityRating = CoachTrainingUtils.asInt(
      tech['qualityRating'],
      fallback: 3,
    );

    final initialDate = event?.date ??
        (widget.initialDate ?? DateTime.now())
            .toIso8601String()
            .split('T')
            .first;
    _titleCtrl = TextEditingController(text: event?.title ?? 'Allenamento');
    _dateCtrl = TextEditingController(text: initialDate);
    _startCtrl = TextEditingController(text: event?.startTime ?? '09:00');
    _endCtrl = TextEditingController(text: event?.endTime ?? '12:00');
    _locationCtrl =
        TextEditingController(text: event?.location ?? 'Pista/Palestra');
    _notesCtrl = TextEditingController(text: event?.notes ?? '');
    _snowCtrl =
        TextEditingController(text: tech['snowCondition'] ?? 'Compatta');
    _weatherCtrl =
        TextEditingController(text: tech['weatherCondition'] ?? 'Sole');
    _drylandSpecialtyCtrl = TextEditingController(
      text: event?.drylandSpecialty ?? 'Preparazione atletica',
    );

    final chrono = tech['chrono'];
    if (chrono is Map) {
      _chronoEnabled = chrono['enabled'] == true;
    }

    _loadSkiDrafts(tech);
    _loadDrylandPlan(tech);
    _loadSelectedTeams();
    if (_selectedTeams.isNotEmpty) {
      _fetchAthletesForSelectedTeams();
    } else {
      _loadEventAttendeesWithoutTeam();
    }
  }

  void _loadSkiDrafts(Map<String, dynamic> tech) {
    if (!_isSki) return;

    final specialties = (widget.event == null
            ? <String>[widget.isSkiWorkout ? 'SL' : 'CL']
            : CoachTrainingUtils.specialtiesFromDetails(tech))
        .where(CoachTrainingUtils.specialties.contains)
        .take(2)
        .toList();
    if (specialties.isEmpty) specialties.add('SL');

    final freeBySpecialty =
        CoachTrainingUtils.freeSkiingBySpecialtyFromDetails(tech);
    final tracks = CoachTrainingUtils.tracksFromDetails(tech);
    final trainingBlocks = CoachTrainingUtils.trainingBlocksFromDetails(tech);
    final primarySpecialty = specialties.first;

    for (final specialty in specialties) {
      final free = freeBySpecialty[specialty] ??
          (specialties.length == 1
              ? CoachTrainingUtils.freeSkiingFromDetails(tech)
              : const <String, dynamic>{});
      final draft = _SkiSpecialtyDraft(
        specialty: specialty,
        freeLaps: free['laps']?.toString() ?? '',
        freeChanges: free['changes']?.toString() ?? '',
      );

      for (var i = 0; i < tracks.length && draft.tracks.length < 3; i++) {
        final track = tracks[i];
        final trackSpecialty = CoachTrainingUtils.normalizeSpecialty(
          track['specialty']?.toString() ?? primarySpecialty,
        );
        if (trackSpecialty != specialty) continue;
        draft.tracks.add(_BlockDraft(
          id: track['id']?.toString() ??
              _blockIdForDraft(draft, 'track', draft.tracks.length + 1),
          name: track['name']?.toString() ??
              'Tracciato ${draft.tracks.length + 1}',
          laps: track['laps']?.toString() ?? '',
          metric: (track['gates'] ?? track['changes'])?.toString() ?? '',
        ));
      }

      for (var i = 0; i < trainingBlocks.length; i++) {
        final block = trainingBlocks[i];
        final blockSpecialty = CoachTrainingUtils.normalizeSpecialty(
          block['specialty']?.toString() ?? primarySpecialty,
        );
        if (blockSpecialty != specialty) continue;
        draft.trainingBlocks.add(_BlockDraft(
          id: block['id']?.toString() ??
              _blockIdForDraft(
                draft,
                'training',
                draft.trainingBlocks.length + 1,
              ),
          name: block['name']?.toString() ?? 'Addestramento',
          laps: block['laps']?.toString() ?? '',
          metric: (block['references'] ?? block['changes'])?.toString() ?? '',
        ));
      }

      _skiDrafts.add(draft);
    }

    if (_skiDrafts.length == 1 && tech['gatedSkiing'] is Map) {
      final gated = tech['gatedSkiing'] as Map;
      final draft = _skiDrafts.first;
      if (draft.tracks.isEmpty) {
        draft.tracks.add(_BlockDraft(
          id: _blockIdForDraft(draft, 'track', 1),
          name: 'Tracciato 1',
          laps: gated['laps']?.toString() ?? '',
          metric: (gated['gates'] ?? gated['changes'])?.toString() ?? '',
        ));
      }
    }
  }

  void _loadDrylandPlan(Map<String, dynamic> tech) {
    if (_isSki) return;
    final planned = tech['plannedDrylandSession'];
    if (planned is! Map) return;

    final category = planned['category']?.toString();
    if (category != null && category.isNotEmpty) {
      _drylandCategory = ActivityCategory.athleticPrep;
      _drylandSpecialtyCtrl.text = _categoryLabel(_drylandCategory);
    }

    final blocks = planned['blocks'];
    if (blocks is! List) return;
    _loadDrylandBlocks(
      blocks
          .whereType<Map>()
          .map(
              (item) => TrainingBlock.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  void _loadDrylandBlocks(List<TrainingBlock> blocks) {
    _strengthExercises.clear();
    _plyometricExercises.clear();
    _speedDrills.clear();
    _circuits.clear();
    _endurance.clear();

    for (final block in blocks) {
      final phase = _phaseFromBlock(block);
      if (block.exercises.isNotEmpty) {
        _strengthExercises.addAll(
          block.exercises.map((entry) => {
                ...entry.toJson(),
                'phase': phase,
              }),
        );
      } else if (block.type == TrainingBlockType.plyometrics) {
        _strengthExercises.addAll(block.plyometrics.map((entry) => {
              'exerciseId': entry.type,
              'name': entry.exerciseName,
              'equipment': null,
              'unilateralMode': entry.unilateralMode,
              'sets': entry.sets
                  .map((set) => {
                        'setNumber': set.setNumber,
                        'reps': set.reps ?? set.contacts,
                        'durationSeconds': null,
                        'restSeconds': set.restSeconds,
                        'notes': set.notes,
                        'side': set.side,
                      })
                  .toList(),
              'phase': phase,
            }));
      } else if (block.type == TrainingBlockType.speedAgility) {
        _strengthExercises.addAll(block.drills.map((drill) => {
              'exerciseId': drill.type,
              'name': drill.name,
              'equipment':
                  drill.equipment.isEmpty ? null : drill.equipment.join(', '),
              'unilateralMode': UnilateralMode.bilateral,
              'sets': List.generate(
                drill.sets ?? 1,
                (index) => {
                  'setNumber': index + 1,
                  'reps': drill.reps,
                  'durationSeconds': drill.timeSeconds?.round(),
                  'restSeconds': drill.restSeconds,
                  'side': TrainingSide.none,
                },
              ),
              'phase': phase,
            }));
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
      }
    }
  }

  List<TrainingBlock> _buildDrylandBlocks() {
    if (_isAthleticPrep) {
      final blocks = <TrainingBlock>[];
      for (final phase in TrainingPhase.ordered) {
        final phaseExercises = _strengthExercises
            .where((item) => _phaseFromExerciseMap(item) == phase)
            .toList();
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final exercise in phaseExercises) {
          final type = _exerciseBlockTypeForExercise(exercise);
          grouped.putIfAbsent(type, () => []).add(exercise);
        }
        for (final entry in grouped.entries) {
          blocks.add(TrainingBlock(
            id: '${phase}_${entry.key}_${blocks.length + 1}',
            type: entry.key,
            name: TrainingPhase.label(phase),
            exercises: entry.value
                .map((item) => ExerciseEntry.fromJson(item))
                .toList(),
            metrics: {'phase': phase},
          ));
        }
      }
      if (blocks.isEmpty && _notesCtrl.text.trim().isNotEmpty) {
        blocks.add(TrainingBlock(
          id: 'note_1',
          type: TrainingBlockType.note,
          name: TrainingPhase.label(TrainingPhase.main),
          metrics: const {'phase': TrainingPhase.main},
          notes: _notesCtrl.text.trim(),
        ));
      }
      return blocks;
    }

    final blocks = <TrainingBlock>[];
    if (_strengthExercises.isNotEmpty) {
      blocks.add(TrainingBlock(
        id: '${_exerciseBlockType()}_1',
        type: _exerciseBlockType(),
        name: _categoryLabel(_drylandCategory),
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
    if (_endurance.isNotEmpty) {
      blocks.add(TrainingBlock(
        id: 'endurance_1',
        type: TrainingBlockType.endurance,
        name: 'Resistenza',
        endurance: EnduranceMetrics.fromJson({
          ..._endurance,
          'durationSeconds': _calculateEventDurationMinutes() * 60,
        }),
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
        name: _categoryLabel(_drylandCategory),
        notes: _notesCtrl.text.trim(),
      ));
    }
    return blocks;
  }

  Map<String, dynamic> _buildPlannedDrylandSession() {
    final blocks = _buildDrylandBlocks();
    final activity = _buildDrylandActivity(
      id: widget.event?.id ?? 'planned_dryland',
      source: ActivitySource.coach,
      status: _eventStatus == CoachTrainingUtils.statusCancelled
          ? ActivityStatus.cancelled
          : ActivityStatus.planned,
      blocks: blocks,
    );
    return activity.toJson();
  }

  TrainingActivity _buildDrylandActivity({
    required String id,
    required String source,
    required String status,
    required List<TrainingBlock> blocks,
  }) {
    final appState = Provider.of<AppState>(context, listen: false);
    return TrainingActivity(
      id: id,
      coachId: appState.userId,
      teamId: _selectedTeams.isEmpty ? null : _selectedTeams.first.id,
      teamIds: _selectedTeams.map((team) => team.id).toList(),
      source: source,
      status: status,
      category: _drylandCategory,
      sportType: _isAthleticPrep
          ? 'athletic_prep'
          : 'dryland_${_drylandCategory.replaceAll('_', '-')}',
      title: _titleCtrl.text.trim().isEmpty
          ? _categoryLabel(_drylandCategory)
          : _titleCtrl.text.trim(),
      date: _dateCtrl.text,
      startTime: _startCtrl.text,
      endTime: _endCtrl.text,
      duration: _calculateEventDurationMinutes().toString(),
      location: _locationCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      createdByCoach: true,
      linkedCoachEventId: widget.event?.id,
      blocks: blocks,
    );
  }

  int _calculateEventDurationMinutes() {
    final start = _parseClockMinutes(_startCtrl.text);
    final end = _parseClockMinutes(_endCtrl.text);
    if (start == null || end == null) return 60;
    var minutes = end - start;
    if (minutes <= 0) minutes += 24 * 60;
    return minutes;
  }

  int? _parseClockMinutes(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  void _loadSelectedTeams() {
    final appState = Provider.of<AppState>(context, listen: false);
    final selectedTeam = widget.selectedTeam;
    if (selectedTeam != null) {
      _selectedTeams.add(selectedTeam);
      return;
    }

    final event = widget.event;
    if (event != null) {
      final teamIds = CoachTrainingUtils.teamIdsForEvent(event);
      for (final id in teamIds) {
        try {
          final team = appState.teams.firstWhere((t) => t.id == id);
          if (!_selectedTeams.any((t) => t.id == team.id)) {
            _selectedTeams.add(team);
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _fetchAthletesForSelectedTeams() async {
    setState(() => _isLoadingAthletes = true);
    try {
      final existingById = {
        for (final athlete in _athletes) athlete['id']?.toString(): athlete
      };
      final eventAttendees = widget.event?.attendees ?? [];
      final loaded = <Map<String, dynamic>>[];
      final seenIds = <String>{};
      final supabase = Supabase.instance.client;

      for (final team in _selectedTeams) {
        final data = await supabase
            .from('profiles')
            .select('id, first_name, last_name, email, team_id, role')
            .eq('team_id', team.id)
            .eq('role', 'athlete');

        for (final row in data as List) {
          final id = row['id']?.toString();
          if (id == null || id.isEmpty || seenIds.contains(id)) continue;
          seenIds.add(id);

          final first = row['first_name']?.toString() ?? '';
          final last = row['last_name']?.toString() ?? '';
          final fullName = '$first $last'.trim();
          final name = fullName.isNotEmpty
              ? fullName
              : (row['email']?.toString() ?? 'Atleta');

          final fromEvent =
              eventAttendees.cast<Map<String, dynamic>?>().firstWhere(
                    (a) => a != null && (a['id'] == id || a['name'] == name),
                    orElse: () => null,
                  );
          final existing = existingById[id];
          loaded.add(_athleteFromProfile(
            id: id,
            name: name,
            teamId: team.id,
            teamName: team.name,
            source: existing ?? fromEvent,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _athletes
            ..clear()
            ..addAll(loaded);
          _isLoadingAthletes = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching athletes for selected teams: $e');
      if (mounted) {
        setState(() => _isLoadingAthletes = false);
      }
    }
  }

  Map<String, dynamic> _athleteFromProfile({
    required String id,
    required String name,
    required String teamId,
    required String teamName,
    Map<String, dynamic>? source,
  }) {
    final status =
        source == null ? null : CoachTrainingUtils.attendeeStatus(source);
    return {
      'id': id,
      'name': name,
      'teamId': teamId,
      'teamName': teamName,
      'isInvited': source != null || false,
      'attendanceStatus': status,
      'isPresent': source == null ? null : source['isPresent'],
      'invitedAt': source?['invitedAt'],
      'respondedAt': source?['respondedAt'],
      'laps': source?['laps'],
      'freeLaps': source?['freeLaps'],
      'freeChanges': source?['freeChanges'],
      'freeLapsBySpecialty': source?['freeLapsBySpecialty'],
      'freeChangesBySpecialty': source?['freeChangesBySpecialty'],
      'trainingLaps': source?['trainingLaps'],
      'trackLaps': source?['trackLaps'],
      'trackGates': source?['trackGates'],
      'trainingBlockLaps': source?['trainingBlockLaps'],
      'trainingBlockReferences': source?['trainingBlockReferences'],
      'rpe': source?['rpe'],
      'pain': source?['pain'],
      'chronoNotes': source?['chronoNotes'],
      'athleteNotes': source?['athleteNotes'],
      'actualDrylandDetails': source?['actualDrylandDetails'],
      'modifiedByAthlete': source?['modifiedByAthlete'] == true,
      'modifiedAt': source?['modifiedAt'],
    };
  }

  void _loadEventAttendeesWithoutTeam() {
    final attendees = widget.event?.attendees ?? [];
    _athletes
      ..clear()
      ..addAll(attendees.map((a) {
        return {
          ...a,
          'teamId': a['teamId'] ?? '',
          'teamName': a['teamName'] ?? 'Team',
          'isInvited': true,
          'attendanceStatus': CoachTrainingUtils.attendeeStatus(a),
        };
      }));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _dateCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _snowCtrl.dispose();
    _weatherCtrl.dispose();
    _drylandSpecialtyCtrl.dispose();
    for (final draft in _skiDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(widget.event == null ? 'Nuovo Allenamento' : 'Allenamento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.event != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            _buildStatusSection(),
            const SizedBox(height: 16),
            _buildInfoSection(),
            const SizedBox(height: 16),
            if (!_isSki) ...[
              _buildDrylandPlanSection(),
              const SizedBox(height: 16),
            ],
            _buildTeamSection(),
            const SizedBox(height: 16),
            _buildAthletesSection(),
            const SizedBox(height: 16),
            if (_invitedAthletes.isNotEmpty) ...[
              _buildAttendanceSection(),
              const SizedBox(height: 16),
            ],
            if (_showTechnical) ...[
              _buildTechnicalSection(),
              const SizedBox(height: 16),
              _buildAthleteDataSection(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _confirmAndSave,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_isSaving ? 'Salvataggio...' : 'Salva Allenamento'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
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

  Widget _buildStatusSection() {
    return _sectionCard(
      title: 'Stato allenamento',
      icon: Icons.flag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _statusButton(
                  label: 'Pianificato',
                  status: CoachTrainingUtils.statusPlanned,
                  disabled: _isExistingCompleted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusButton(
                  label: 'Completato',
                  status: CoachTrainingUtils.statusCompleted,
                  disabled: !_canComplete,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusButton(
                  label: 'Annullato',
                  status: CoachTrainingUtils.statusCancelled,
                ),
              ),
            ],
          ),
          if (!_canComplete)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Gli allenamenti futuri partono come pianificati. Potrai completarli dopo l orario di fine.',
                style:
                    TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return _sectionCard(
      title: 'Info',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _segmentedControl(
            values: const {'training': 'Training', 'race': 'Race'},
            selected: _eventType,
            onSelected: (value) => setState(() => _eventType = value),
          ),
          const SizedBox(height: 18),
          if (_isSki) ...[
            _buildSpecialtySelector(),
            const SizedBox(height: 18),
          ],
          _input('Titolo', _titleCtrl),
          const SizedBox(height: 14),
          _input(
            'Data',
            _dateCtrl,
            icon: Icons.calendar_today_outlined,
            onTap: _pickDate,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _input(
                  'Inizio',
                  _startCtrl,
                  icon: Icons.access_time,
                  onTap: () => _pickTime(_startCtrl),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _input(
                  'Fine',
                  _endCtrl,
                  icon: Icons.access_time_filled,
                  onTap: () => _pickTime(_endCtrl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _input('Luogo', _locationCtrl, icon: Icons.location_on_outlined),
        ],
      ),
    );
  }

  Widget _buildSpecialtySelector() {
    if (_skiDrafts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'SPECIALITA',
                style: TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                if (_skiDrafts.length > 1) {
                  final removed = _skiDrafts.removeLast();
                  removed.dispose();
                } else {
                  _skiDrafts.add(_SkiSpecialtyDraft(
                    specialty: _firstAvailableSpecialty(),
                  ));
                }
              }),
              icon: Icon(
                _skiDrafts.length > 1 ? Icons.remove : Icons.add,
                size: 18,
              ),
              label: Text(
                _skiDrafts.length > 1 ? 'Rimuovi seconda' : 'Doppia specialita',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _specialtyChoiceGroup(_skiDrafts.first),
        if (_skiDrafts.length > 1) ...[
          const SizedBox(height: 12),
          Text(
            'SECONDA SPECIALITA',
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          _specialtyChoiceGroup(_skiDrafts[1]),
        ],
      ],
    );
  }

  Widget _specialtyChoiceGroup(_SkiSpecialtyDraft draft) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CoachTrainingUtils.specialties.map((specialty) {
        final selected = specialty == draft.specialty;
        final usedByOther = _skiDrafts
            .any((item) => item != draft && item.specialty == specialty);
        return ChoiceChip(
          label: Text(CoachTrainingUtils.specialtyLabel(specialty)),
          selected: selected,
          onSelected: usedByOther
              ? null
              : (_) => setState(() => _setDraftSpecialty(draft, specialty)),
          selectedColor: AppTheme.primary,
          disabledColor: AppTheme.subtleFill.withValues(alpha: 0.4),
          backgroundColor: AppTheme.background,
          labelStyle: TextStyle(
            color: selected
                ? Colors.white
                : usedByOther
                    ? AppTheme.textMediumEmphasis.withValues(alpha: 0.45)
                    : AppTheme.textMediumEmphasis,
            fontWeight: FontWeight.bold,
          ),
          side: BorderSide(
            color: selected ? AppTheme.primary : AppTheme.subtleFill,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDrylandPlanSection() {
    final blocks = _buildDrylandBlocks();
    final exerciseCount = _strengthExercises.length;

    return _sectionCard(
      title: 'Programma preparazione',
      icon: Icons.fitness_center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _drylandTemplateRow(),
          const SizedBox(height: 16),
          if (blocks.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _drylandMetricBadge('Esercizi', exerciseCount.toString()),
                _drylandMetricBadge('Parti', '${blocks.length} blocchi'),
              ],
            ),
            const SizedBox(height: 16),
          ],
          for (final phase in TrainingPhase.ordered) ...[
            _athleticPrepPhaseEditor(phase),
            if (phase != TrainingPhase.ordered.last) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _athleticPrepPhaseEditor(String phase) {
    final exercises = _strengthExercises
        .asMap()
        .entries
        .where((entry) => _phaseFromExerciseMap(entry.value) == phase)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _drylandPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TrainingPhase.label(phase),
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (value) => setState(() => _exerciseSearch = value),
            style: TextStyle(color: AppTheme.textHighEmphasis),
            decoration: InputDecoration(
              hintText: 'Cerca esercizio',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              'all',
              'barbell',
              'dumbbell',
              'machine',
              'cable',
              'bodyweight',
              'kettlebell',
              'band',
            ].map((equipment) {
              final selected = _equipmentFilter == equipment;
              return ChoiceChip(
                label: Text(equipment == 'all' ? 'Tutti' : equipment),
                selected: selected,
                onSelected: (_) => setState(() => _equipmentFilter = equipment),
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.background,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppTheme.textMediumEmphasis,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          _exercisePicker(phase),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _createCustomStrengthExercise(phase: phase),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Crea esercizio personalizzato'),
          ),
          if (exercises.isEmpty)
            Text(
              'Aggiungi esercizi dal database unico.',
              style: TextStyle(color: AppTheme.textMediumEmphasis),
            )
          else
            ...exercises.map(
              (entry) => _strengthExerciseCard(entry.key, entry.value),
            ),
        ],
      ),
    );
  }

  Widget _drylandTemplateRow() {
    return Selector<AppState, List<WorkoutTemplate>>(
      selector: (_, state) => state.workoutTemplates
          .where((template) =>
              template.category == ActivityCategory.athleticPrep ||
              template.category == ActivityCategory.strength ||
              template.category == ActivityCategory.plyometrics ||
              template.category == ActivityCategory.speedAgility ||
              template.category == ActivityCategory.mobility ||
              template.category == ActivityCategory.core ||
              template.category == ActivityCategory.circuit)
          .toList(growable: false),
      builder: (context, templates, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TEMPLATE',
                  style: TextStyle(
                    color: AppTheme.textMediumEmphasis,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _saveDrylandTemplate,
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('Salva'),
              ),
            ],
          ),
          if (templates.isEmpty)
            Text(
              'Nessun template per questa categoria.',
              style:
                  TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12),
            )
          else
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return ActionChip(
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(template.name),
                    onPressed: () => _applyDrylandTemplate(template),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: templates.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _drylandMetricBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: AppTheme.textHighEmphasis,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _coachStrengthEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (value) => setState(() => _exerciseSearch = value),
          style: TextStyle(color: AppTheme.textHighEmphasis),
          decoration: InputDecoration(
            hintText: 'Cerca esercizio',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: AppTheme.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            'all',
            'barbell',
            'dumbbell',
            'machine',
            'cable',
            'bodyweight',
            'kettlebell',
            'band',
          ].map((equipment) {
            final selected = _equipmentFilter == equipment;
            return ChoiceChip(
              label: Text(equipment == 'all' ? 'Tutti' : equipment),
              selected: selected,
              onSelected: (_) => setState(() => _equipmentFilter = equipment),
              selectedColor: AppTheme.primary,
              backgroundColor: AppTheme.background,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.textMediumEmphasis,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _exercisePicker(),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _createCustomStrengthExercise,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Crea esercizio personalizzato'),
        ),
        const SizedBox(height: 12),
        if (_strengthExercises.isEmpty)
          Text(
            'Aggiungi esercizi o applica un template.',
            style: TextStyle(color: AppTheme.textMediumEmphasis),
          )
        else
          ..._strengthExercises.asMap().entries.map(
                (entry) => _strengthExerciseCard(entry.key, entry.value),
              ),
      ],
    );
  }

  Widget _exercisePicker([String phase = TrainingPhase.main]) {
    final query = _exerciseSearch.trim().toLowerCase();
    final filtered = exerciseDatabase.where((exercise) {
      final matchesQuery = query.isEmpty ||
          exercise.name.toLowerCase().contains(query) ||
          exercise.targetMuscle.toLowerCase().contains(query);
      final matchesEquipment =
          _equipmentFilter == 'all' || exercise.category == _equipmentFilter;
      final activityFilter = _exerciseActivityFilter();
      final matchesActivity = activityFilter == 'all' ||
          exercise.resolvedActivityCategory == activityFilter;
      return matchesQuery && matchesEquipment && matchesActivity;
    }).take(8);

    return Column(
      children: filtered.map((exercise) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(exercise.name,
              style: TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold)),
          subtitle: Text('${exercise.targetMuscle} - ${exercise.category}',
              style: TextStyle(color: AppTheme.textMediumEmphasis)),
          trailing: IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primary),
            onPressed: () => _addStrengthExercise(
              exercise.id,
              exercise.name,
              equipment: exercise.category,
              phase: phase,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _strengthExerciseCard(int index, Map<String, dynamic> exercise) {
    final sets = (exercise['sets'] as List).cast<Map<String, dynamic>>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _drylandPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exercise['name']?.toString() ?? '',
                  style: TextStyle(
                    color: AppTheme.textHighEmphasis,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
              _modeChip(exercise, UnilateralMode.bilateral, 'Bilat.'),
              _modeChip(exercise, UnilateralMode.right, 'Dx'),
              _modeChip(exercise, UnilateralMode.left, 'Sx'),
            ],
          ),
          const SizedBox(height: 10),
          ...sets.asMap().entries.map(
                (entry) => _strengthSetRow(index, entry.key, entry.value),
              ),
          TextButton.icon(
            onPressed: () => setState(() {
              sets.add({
                'setNumber': sets.length + 1,
                'kg': 0,
                'reps': 0,
                'durationSeconds': null,
                'percent1RM': null,
                'rpe': null,
                'rir': null,
                'restSeconds': 120,
                'tempo': '',
                'side': exercise['unilateralMode'] == UnilateralMode.right
                    ? TrainingSide.right
                    : exercise['unilateralMode'] == UnilateralMode.left
                        ? TrainingSide.left
                        : TrainingSide.none,
              });
            }),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi serie'),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(
    Map<String, dynamic> exercise,
    String mode,
    String label,
  ) {
    final selected = exercise['unilateralMode'] == mode;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => exercise['unilateralMode'] = mode),
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.background,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.textMediumEmphasis,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _strengthSetRow(
    int exerciseIndex,
    int setIndex,
    Map<String, dynamic> set,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${setIndex + 1}',
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: _inlineNumber('kg', set['kg'], (v) => set['kg'] = v),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _inlineNumber('reps', set['reps'], (v) => set['reps'] = v),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _inlineNumber('sec', set['durationSeconds'],
                (v) => set['durationSeconds'] = v),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _inlineNumber(
                'rec', set['restSeconds'], (v) => set['restSeconds'] = v),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.error, size: 18),
            onPressed: () => setState(() {
              final sets = (_strengthExercises[exerciseIndex]['sets'] as List);
              sets.removeAt(setIndex);
            }),
          ),
        ],
      ),
    );
  }

  Widget _coachPlyometricsEditor() {
    return Column(
      children: [
        if (_plyometricExercises.isEmpty)
          Text(
            'Aggiungi un esercizio pliometrico.',
            style: TextStyle(color: AppTheme.textMediumEmphasis),
          )
        else
          ..._plyometricExercises.asMap().entries.map(
                (entry) => _plyometricCard(entry.key, entry.value),
              ),
        TextButton.icon(
          onPressed: () => setState(() {
            _plyometricExercises.add({
              'exerciseName': 'Drop jump',
              'type': 'drop_jump',
              'sets': [
                {'setNumber': 1, 'reps': 5, 'contacts': 5}
              ],
            });
          }),
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi pliometria'),
        ),
      ],
    );
  }

  Widget _plyometricCard(int index, Map<String, dynamic> entry) {
    final sets = (entry['sets'] as List).cast<Map<String, dynamic>>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _drylandPanelDecoration(),
      child: Column(
        children: [
          TextFormField(
            initialValue: entry['exerciseName']?.toString() ?? '',
            onChanged: (value) => entry['exerciseName'] = value,
            style: TextStyle(color: AppTheme.textHighEmphasis),
            decoration: const InputDecoration(labelText: 'Esercizio'),
          ),
          const SizedBox(height: 8),
          ...sets.asMap().entries.map((setEntry) {
            final set = setEntry.value;
            return Row(
              children: [
                Expanded(
                  child: _inlineNumber(
                      'reps', set['reps'], (v) => set['reps'] = v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _inlineNumber(
                      'contatti', set['contacts'], (v) => set['contacts'] = v),
                ),
              ],
            );
          }),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() {
                  sets.add({
                    'setNumber': sets.length + 1,
                    'reps': 5,
                    'contacts': 5,
                  });
                }),
                icon: const Icon(Icons.add),
                label: const Text('Serie'),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                onPressed: () =>
                    setState(() => _plyometricExercises.removeAt(index)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _coachSpeedEditor() {
    return Column(
      children: [
        if (_speedDrills.isEmpty)
          Text(
            'Aggiungi un drill velocità/agilità.',
            style: TextStyle(color: AppTheme.textMediumEmphasis),
          )
        else
          ..._speedDrills.asMap().entries.map(
                (entry) => _speedCard(entry.key, entry.value),
              ),
        TextButton.icon(
          onPressed: () => setState(() {
            _speedDrills.add({
              'name': 'Sprint',
              'type': 'sprint',
              'sets': 4,
              'reps': 1,
              'distanceM': 20,
              'restSeconds': 120,
            });
          }),
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi drill'),
        ),
      ],
    );
  }

  Widget _speedCard(int index, Map<String, dynamic> drill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _drylandPanelDecoration(),
      child: Column(
        children: [
          TextFormField(
            initialValue: drill['name']?.toString() ?? '',
            onChanged: (value) => drill['name'] = value,
            style: TextStyle(color: AppTheme.textHighEmphasis),
            decoration: const InputDecoration(labelText: 'Drill'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _inlineNumber(
                    'serie', drill['sets'], (v) => drill['sets'] = v),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _inlineNumber(
                    'reps', drill['reps'], (v) => drill['reps'] = v),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _inlineNumber(
                    'metri', drill['distanceM'], (v) => drill['distanceM'] = v),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: () => setState(() => _speedDrills.removeAt(index)),
            ),
          )
        ],
      ),
    );
  }

  Widget _coachEnduranceEditor() {
    _endurance.putIfAbsent(
      'durationSeconds',
      () => _calculateEventDurationMinutes() * 60,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _drylandPanelDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _inlineNumber('km', _endurance['distanceKm'],
                    (v) => _endurance['distanceKm'] = v),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _inlineNumber(
                    'Z2-Z3 min',
                    ((_endurance['zone23Seconds'] ?? 0) as num) / 60,
                    (v) => _endurance['zone23Seconds'] = (v * 60).round()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _inlineNumber(
                    'Z4-Z5 min',
                    ((_endurance['zone45Seconds'] ?? 0) as num) / 60,
                    (v) => _endurance['zone45Seconds'] = (v * 60).round()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coachCircuitEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _circuitPresetButton(
                '4x4 norvegese', () => _addCircuit('norwegian_4x4')),
            _circuitPresetButton(
                'Corsa intervallata', () => _addCircuit('interval_running')),
            _circuitPresetButton(
                'HIIT custom', () => _addCircuit('hiit_custom')),
          ],
        ),
        const SizedBox(height: 12),
        if (_circuits.isEmpty)
          Text(
            'Aggiungi un circuito o scegli un preset.',
            style: TextStyle(color: AppTheme.textMediumEmphasis),
          )
        else
          ..._circuits.asMap().entries.map(
                (entry) => _coachCircuitCard(entry.key, entry.value),
              ),
      ],
    );
  }

  Widget _circuitPresetButton(String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 16),
      label: Text(label),
    );
  }

  void _addCircuit(String type) {
    setState(() => _circuits.add(_circuitPreset(type)));
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

  Widget _coachCircuitCard(int index, Map<String, dynamic> circuit) {
    final intervals = (circuit['intervals'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        <Map<String, dynamic>>[];
    circuit['intervals'] = intervals;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _drylandPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _inlineText(
                  'Nome',
                  circuit['name']?.toString() ?? '',
                  (v) => circuit['name'] = v,
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
                child: _inlineNumber('round', circuit['rounds'],
                    (v) => circuit['rounds'] = v.round()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _inlineNumber('lavoro s', circuit['workSeconds'],
                    (v) => circuit['workSeconds'] = v.round()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _inlineNumber('rec s', circuit['restSeconds'],
                    (v) => circuit['restSeconds'] = v.round()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _inlineText(
            'Intensità',
            circuit['intensity']?.toString() ?? '',
            (v) => circuit['intensity'] = v,
          ),
          const SizedBox(height: 10),
          if (intervals.isNotEmpty)
            ...intervals.asMap().entries.map(
                  (entry) => _coachIntervalRow(
                    intervals,
                    entry.key,
                    entry.value,
                  ),
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

  Widget _coachIntervalRow(
    List<Map<String, dynamic>> intervals,
    int index,
    Map<String, dynamic> interval,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _inlineText(
              'Intervallo',
              interval['name']?.toString() ?? '',
              (v) => interval['name'] = v,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _inlineNumber('lav s', interval['workSeconds'],
                (v) => interval['workSeconds'] = v.round()),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _inlineNumber('rec s', interval['restSeconds'],
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

  Widget _inlineText(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return TextFormField(
      initialValue: value,
      style: TextStyle(color: AppTheme.textHighEmphasis, fontSize: 12),
      decoration: InputDecoration(labelText: label),
      onChanged: (raw) => setState(() => onChanged(raw)),
    );
  }

  Widget _inlineNumber(
    String label,
    dynamic value,
    ValueChanged<double> onChanged,
  ) {
    return TextFormField(
      initialValue: value == null ? '' : value.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      style: TextStyle(color: AppTheme.textHighEmphasis, fontSize: 12),
      decoration: InputDecoration(labelText: label),
      onChanged: (raw) {
        final parsed = double.tryParse(raw.replaceAll(',', '.')) ?? 0;
        setState(() => onChanged(parsed));
      },
    );
  }

  BoxDecoration _drylandPanelDecoration() {
    return BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.subtleBorder),
    );
  }

  String _categoryLabel(String category) {
    switch (category) {
      case ActivityCategory.athleticPrep:
        return 'Preparazione atletica';
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
      default:
        return 'Altro';
    }
  }

  String _exerciseBlockType() {
    if (_drylandCategory == ActivityCategory.mobility) {
      return TrainingBlockType.mobility;
    }
    if (_drylandCategory == ActivityCategory.core) {
      return TrainingBlockType.core;
    }
    return TrainingBlockType.strength;
  }

  String _phaseFromBlock(TrainingBlock block) {
    return TrainingPhase.normalize(block.metrics['phase']);
  }

  String _phaseFromExerciseMap(Map<String, dynamic> exercise) {
    return TrainingPhase.normalize(exercise['phase']);
  }

  String _exerciseBlockTypeForExercise(Map<String, dynamic> exercise) {
    final exerciseId = exercise['exerciseId']?.toString();
    final name = exercise['name']?.toString();
    ExerciseDef? definition;
    for (final item in exerciseDatabase) {
      if ((exerciseId != null && item.id == exerciseId) ||
          (name != null && item.name == name)) {
        definition = item;
        break;
      }
    }
    final category = definition?.resolvedActivityCategory;
    switch (category) {
      case ActivityCategory.mobility:
        return TrainingBlockType.mobility;
      case ActivityCategory.core:
        return TrainingBlockType.core;
      case ActivityCategory.plyometrics:
        return TrainingBlockType.plyometrics;
      case ActivityCategory.speedAgility:
        return TrainingBlockType.speedAgility;
      default:
        return TrainingBlockType.strength;
    }
  }

  bool _usesDurationSetsForExercise(Map<String, dynamic> exercise) {
    final type = _exerciseBlockTypeForExercise(exercise);
    return type == TrainingBlockType.mobility || type == TrainingBlockType.core;
  }

  String _exerciseActivityFilter() {
    if (_isAthleticPrep) return 'all';
    if (_drylandCategory == ActivityCategory.mobility) {
      return ActivityCategory.mobility;
    }
    if (_drylandCategory == ActivityCategory.core) return ActivityCategory.core;
    return ActivityCategory.strength;
  }

  void _applyDrylandTemplate(WorkoutTemplate template) {
    setState(() {
      _drylandCategory = ActivityCategory.athleticPrep;
      _drylandSpecialtyCtrl.text = _categoryLabel(_drylandCategory);
      _loadDrylandBlocks(template.blocks);
      if (_titleCtrl.text.trim().isEmpty ||
          _titleCtrl.text.trim() == 'Allenamento') {
        _titleCtrl.text = template.name;
      }
    });
  }

  Future<void> _saveDrylandTemplate() async {
    final blocks = _buildDrylandBlocks();
    if (blocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aggiungi almeno un blocco alla scheda.')),
      );
      return;
    }

    final fallbackName = _titleCtrl.text.trim().isEmpty
        ? _categoryLabel(_drylandCategory)
        : _titleCtrl.text.trim();
    final templateName = await _askTemplateName(fallbackName);
    if (templateName == null || !mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final appState = Provider.of<AppState>(context, listen: false);
    final activity = _buildDrylandActivity(
      id: 'template_source',
      source: ActivitySource.coach,
      status: ActivityStatus.planned,
      blocks: blocks,
    );
    final template = _trainingActivityService.saveActivityAsTemplate(
      activity,
      templateId: DateTime.now().millisecondsSinceEpoch.toString(),
      name: templateName,
      ownerType: TemplateOwnerType.coach,
      ownerId: appState.userId,
      teamId: _selectedTeams.isEmpty
          ? appState.userProfile?.teamId
          : _selectedTeams.first.id,
      createdBy: appState.userId,
    );
    await appState.saveWorkoutTemplate(template);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template salvato.')),
    );
  }

  Future<String?> _askTemplateName(String initialName) async {
    final nameCtrl = TextEditingController(text: initialName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Salva template',
          style: TextStyle(
              color: AppTheme.textHighEmphasis, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameCtrl,
          style: TextStyle(color: AppTheme.textHighEmphasis),
          decoration: const InputDecoration(labelText: 'Nome template'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              Navigator.pop(dialogContext, name.isEmpty ? initialName : name);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    return result;
  }

  void _addStrengthExercise(
    String id,
    String name, {
    String? equipment,
    bool isCustom = false,
    String phase = TrainingPhase.main,
  }) {
    setState(() {
      _strengthExercises.add({
        'exerciseId': id,
        'name': name,
        'equipment': equipment,
        'unilateralMode': UnilateralMode.bilateral,
        'phase': phase,
        'sets': [
          {
            'setNumber': 1,
            'kg': 0,
            'reps': 0,
            'durationSeconds': null,
            'percent1RM': null,
            'rpe': null,
            'rir': null,
            'restSeconds': 120,
            'tempo': '',
            'side': TrainingSide.none,
          }
        ],
        'isCustom': isCustom,
      });
      _exerciseSearch = '';
    });
  }

  Future<void> _createCustomStrengthExercise({
    String phase = TrainingPhase.main,
  }) async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Esercizio custom',
          style: TextStyle(
              color: AppTheme.textHighEmphasis, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameCtrl,
          style: TextStyle(color: AppTheme.textHighEmphasis),
          decoration: const InputDecoration(labelText: 'Nome esercizio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      _addStrengthExercise(
        'custom_${DateTime.now().millisecondsSinceEpoch}',
        nameCtrl.text.trim(),
        equipment: 'custom',
        isCustom: true,
        phase: phase,
      );
    }
    nameCtrl.dispose();
  }

  Widget _buildTeamSection() {
    final teams = Provider.of<AppState>(context, listen: false).teams;
    return _sectionCard(
      title: 'Team',
      icon: Icons.groups_outlined,
      child: teams.isEmpty
          ? Text(
              'Nessun team disponibile.',
              style: TextStyle(color: AppTheme.textMediumEmphasis),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: teams.map((team) {
                final selected = _selectedTeams.any((t) => t.id == team.id);
                return FilterChip(
                  label: Text(team.name),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      if (selected) {
                        _selectedTeams.removeWhere((t) => t.id == team.id);
                      } else {
                        _selectedTeams.add(team);
                      }
                    });
                    _fetchAthletesForSelectedTeams();
                  },
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.background,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color:
                        selected ? Colors.white : AppTheme.textMediumEmphasis,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(
                    color: selected ? AppTheme.primary : AppTheme.subtleFill,
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildAthletesSection() {
    final filtered = _athletes.where((athlete) {
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return athlete['name'].toString().toLowerCase().contains(query);
    }).toList();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final athlete in filtered) {
      final key = athlete['teamName']?.toString() ?? 'Team';
      grouped.putIfAbsent(key, () => []).add(athlete);
    }

    return _sectionCard(
      title: 'Atleti convocati',
      icon: Icons.people_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchInput(),
          const SizedBox(height: 14),
          if (_isLoadingAthletes)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else if (_selectedTeams.isEmpty)
            Text(
              'Seleziona almeno un team per caricare gli atleti.',
              style: TextStyle(color: AppTheme.textMediumEmphasis),
            )
          else if (filtered.isEmpty)
            Text(
              'Nessun atleta trovato nei team selezionati.',
              style: TextStyle(color: AppTheme.textMediumEmphasis),
            )
          else
            ...grouped.entries.expand((entry) {
              return [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.textMediumEmphasis,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                ...entry.value.map((athlete) => _athleteInviteRow(athlete)),
              ];
            }),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection() {
    return _sectionCard(
      title: 'Presenze',
      icon: Icons.fact_check_outlined,
      child: Column(
        children: _invitedAthletes.map((athlete) {
          final index = _athletes.indexOf(athlete);
          final status = CoachTrainingUtils.attendeeStatus(athlete);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.subtleBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        athlete['name']?.toString() ?? 'Atleta',
                        style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (athlete['modifiedByAthlete'] == true)
                      _smallBadge(
                          'Modificato dall\'atleta', AppTheme.secondary),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _attendanceButton(
                      index,
                      status,
                      CoachTrainingUtils.attendancePending,
                      'In attesa',
                    ),
                    const SizedBox(width: 8),
                    _attendanceButton(
                      index,
                      status,
                      CoachTrainingUtils.attendancePresent,
                      'Presente',
                    ),
                    const SizedBox(width: 8),
                    _attendanceButton(
                      index,
                      status,
                      CoachTrainingUtils.attendanceAbsent,
                      'Assente',
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTechnicalSection() {
    return _sectionCard(
      title: 'Dettagli tecnici',
      icon: Icons.tune,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _input(
                  'Neve',
                  _snowCtrl,
                  icon: Icons.arrow_drop_down,
                  onTap: () => _showOptions('Neve', _snowOptions, _snowCtrl),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _input(
                  'Meteo',
                  _weatherCtrl,
                  icon: Icons.arrow_drop_down,
                  onTap: () =>
                      _showOptions('Meteo', _weatherOptions, _weatherCtrl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _qualityPicker(),
          const SizedBox(height: 16),
          ..._skiDrafts.map((draft) {
            final index = _skiDrafts.indexOf(draft);
            return _skiSpecialtyTechnicalSection(draft, index);
          }),
          if (_skiDrafts.any((draft) => draft.specialty != 'CL')) ...[
            SwitchListTile(
              value: _chronoEnabled,
              onChanged: (value) => setState(() => _chronoEnabled = value),
              title: Text(
                'Crono',
                style: TextStyle(
                    color: AppTheme.textHighEmphasis,
                    fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Abilita dati cronometrati personali.',
                style: TextStyle(color: AppTheme.textMediumEmphasis),
              ),
              activeThumbColor: AppTheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 16),
          _notesInput(),
        ],
      ),
    );
  }

  Widget _skiSpecialtyTechnicalSection(
    _SkiSpecialtyDraft draft,
    int draftIndex,
  ) {
    final label = CoachTrainingUtils.specialtyLabel(draft.specialty);
    return Padding(
      padding:
          EdgeInsets.only(bottom: draftIndex == _skiDrafts.length - 1 ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  'Specialita ${draftIndex + 1} - $label',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _technicalBlockCard(
            title: '$label - Campo libero',
            subtitle:
                'Totale cambi: ${_total(draft.freeLapsCtrl, draft.freeChangesCtrl)}',
            icon: Icons.show_chart,
            color: AppTheme.secondary,
            lapsCtrl: draft.freeLapsCtrl,
            metricCtrl: draft.freeChangesCtrl,
            metricLabel: 'Cambi/giro',
          ),
          if (draft.specialty != 'CL') ...[
            const SizedBox(height: 14),
            ...draft.tracks.map((track) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _technicalBlockCard(
                  title: '$label - ${track.name}',
                  subtitle:
                      'Totale passaggi: ${_total(track.lapsCtrl, track.metricCtrl)}',
                  icon: Icons.bolt,
                  color: AppTheme.primary,
                  lapsCtrl: track.lapsCtrl,
                  metricCtrl: track.metricCtrl,
                  metricLabel: 'Porte/giro',
                  onRemove: () => setState(() {
                    draft.tracks.remove(track);
                    track.dispose();
                  }),
                ),
              );
            }),
            if (draft.tracks.length < 3)
              TextButton.icon(
                onPressed: () => _addTrack(draft),
                icon: const Icon(Icons.add),
                label: Text('Aggiungi tracciato $label'),
              ),
            const SizedBox(height: 8),
            ...draft.trainingBlocks.map((block) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _technicalBlockCard(
                  title: '$label - ${block.name}',
                  subtitle:
                      'Totale cambi: ${_total(block.lapsCtrl, block.metricCtrl)}',
                  icon: Icons.alt_route,
                  color: Colors.orange,
                  lapsCtrl: block.lapsCtrl,
                  metricCtrl: block.metricCtrl,
                  metricLabel: 'Riferimenti/giro',
                  onRemove: () => setState(() {
                    draft.trainingBlocks.remove(block);
                    block.dispose();
                  }),
                ),
              );
            }),
            TextButton.icon(
              onPressed: draft.trainingBlocks.isEmpty
                  ? () => _addTrainingBlock(draft)
                  : null,
              icon: const Icon(Icons.add),
              label: Text('Aggiungi addestramento $label'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAthleteDataSection() {
    return _sectionCard(
      title: 'Dati per atleta',
      icon: Icons.person_search_outlined,
      child: _presentAthletes.isEmpty
          ? Text(
              'Nessun atleta presente. Imposta le presenze per copiare i dati tecnici.',
              style: TextStyle(color: AppTheme.textMediumEmphasis),
            )
          : Column(
              children: _presentAthletes.map((athlete) {
                final index = _athletes.indexOf(athlete);
                final summary = _summaryForAthlete(athlete);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.subtleBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              athlete['name']?.toString() ?? 'Atleta',
                              style: TextStyle(
                                color: AppTheme.textHighEmphasis,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (athlete['modifiedByAthlete'] == true)
                            _smallBadge(
                                'Modificato dall\'atleta', AppTheme.secondary),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppTheme.primary),
                            onPressed: () => _showAthleteDataSheet(index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metricBadge('CL giri', summary.freeLaps),
                          _metricBadge(
                              'CL cambi', summary.freeDirectionChanges),
                          if (summary.polePassesBySpecialty.length > 1)
                            ...summary.polePassesBySpecialty.entries.map(
                              (entry) => _metricBadge(
                                  'Pali ${entry.key}', entry.value),
                            )
                          else ...[
                            _metricBadge('Pali giri', summary.poleLaps),
                            _metricBadge('Passaggi', summary.polePasses),
                          ],
                          _metricBadge('Add. giri', summary.trainingLaps),
                          if (summary
                                  .trainingDirectionChangesBySpecialty.length >
                              1)
                            ...summary
                                .trainingDirectionChangesBySpecialty.entries
                                .map(
                              (entry) => _metricBadge(
                                  'Add. ${entry.key}', entry.value),
                            )
                          else
                            _metricBadge(
                                'Add. cambi', summary.trainingDirectionChanges),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _statusButton({
    required String label,
    required String status,
    bool disabled = false,
  }) {
    final selected = _eventStatus == status;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: GestureDetector(
        onTap: disabled
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() => _eventStatus = status);
              },
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.subtleFill,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textMediumEmphasis,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _segmentedControl({
    required Map<String, String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: values.entries.map((entry) {
          final isSelected = entry.key == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textMediumEmphasis,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppTheme.textMediumEmphasis,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.subtleBorder),
          ),
          child: TextField(
            controller: controller,
            readOnly: onTap != null,
            onTap: onTap,
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              suffixIcon: icon == null
                  ? null
                  : Icon(icon, color: AppTheme.textMediumEmphasis, size: 20),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 42, minHeight: 42),
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchInput() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(color: AppTheme.textHighEmphasis),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: AppTheme.textMediumEmphasis),
          hintText: 'Cerca atleta...',
          hintStyle: TextStyle(color: AppTheme.textMediumEmphasis),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _athleteInviteRow(Map<String, dynamic> athlete) {
    final invited = athlete['isInvited'] == true;
    final status = invited
        ? CoachTrainingUtils.attendeeStatus(athlete)
        : CoachTrainingUtils.attendancePending;
    return GestureDetector(
      onTap: () => _toggleInvite(athlete),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: invited
              ? AppTheme.primary.withValues(alpha: 0.12)
              : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: invited
                ? AppTheme.primary.withValues(alpha: 0.45)
                : AppTheme.subtleFill,
          ),
        ),
        child: Row(
          children: [
            Icon(
              invited ? Icons.check_box : Icons.check_box_outline_blank,
              color: invited ? AppTheme.primary : AppTheme.textMediumEmphasis,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    athlete['name']?.toString() ?? 'Atleta',
                    style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (invited)
                    Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceButton(
    int index,
    String current,
    String status,
    String label,
  ) {
    final selected = current == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setAthleteStatus(index, status),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: selected ? _statusColor(status) : AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _statusColor(status) : AppTheme.subtleFill,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textMediumEmphasis,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _qualityPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUALITÀ ALLENAMENTO',
          style: TextStyle(
            color: AppTheme.textMediumEmphasis,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(5, (index) {
            final value = index + 1;
            final selected = _qualityRating == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _qualityRating = value),
                child: Container(
                  height: 42,
                  margin: EdgeInsets.only(right: index == 4 ? 0 : 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.subtleFill,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$value',
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppTheme.textMediumEmphasis,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _technicalBlockCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required TextEditingController lapsCtrl,
    required TextEditingController metricCtrl,
    required String metricLabel,
    VoidCallback? onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textMediumEmphasis,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.error),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _smallNumberInput('Giri', lapsCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _smallNumberInput(metricLabel, metricCtrl)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallNumberInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppTheme.textMediumEmphasis,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _notesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTE COACH',
          style: TextStyle(
            color: AppTheme.textMediumEmphasis,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.subtleBorder),
          ),
          child: TextField(
            controller: _notesCtrl,
            maxLines: 4,
            style: TextStyle(color: AppTheme.textHighEmphasis),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
              hintText: 'Note tecniche, contesto, osservazioni...',
              hintStyle: TextStyle(color: AppTheme.textMediumEmphasis),
            ),
          ),
        ),
      ],
    );
  }

  Widget _smallBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _metricBadge(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: AppTheme.textHighEmphasis,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _toggleInvite(Map<String, dynamic> athlete) {
    setState(() {
      final invited = athlete['isInvited'] == true;
      athlete['isInvited'] = !invited;
      if (!invited) {
        final status = _eventStatus == CoachTrainingUtils.statusCompleted
            ? CoachTrainingUtils.attendancePresent
            : CoachTrainingUtils.attendancePending;
        athlete['attendanceStatus'] = status;
        athlete['isPresent'] =
            status == CoachTrainingUtils.attendancePresent ? true : null;
        athlete['invitedAt'] ??= DateTime.now().toIso8601String();
      } else {
        athlete['attendanceStatus'] = null;
        athlete['isPresent'] = null;
      }
    });
  }

  void _setAthleteStatus(int index, String status) {
    if (index < 0 || index >= _athletes.length) return;
    setState(() {
      final athlete = _athletes[index];
      athlete['isInvited'] = true;
      athlete['attendanceStatus'] = status;
      if (status == CoachTrainingUtils.attendancePresent) {
        athlete['isPresent'] = true;
      } else if (status == CoachTrainingUtils.attendanceAbsent) {
        athlete['isPresent'] = false;
      } else {
        athlete['isPresent'] = null;
      }
    });
  }

  void _addTrack(_SkiSpecialtyDraft draft) {
    if (draft.tracks.length >= 3) return;
    setState(() {
      final number = draft.tracks.length + 1;
      draft.tracks.add(_BlockDraft(
        id: _blockIdForDraft(draft, 'track', number),
        name: 'Tracciato $number',
      ));
    });
  }

  void _addTrainingBlock(_SkiSpecialtyDraft draft) {
    setState(() {
      draft.trainingBlocks.add(_BlockDraft(
        id: _blockIdForDraft(
            draft, 'training', draft.trainingBlocks.length + 1),
        name: 'Addestramento',
      ));
    });
  }

  int _total(TextEditingController a, TextEditingController b) {
    return CoachTrainingUtils.asInt(a.text) * CoachTrainingUtils.asInt(b.text);
  }

  String _blockIdForDraft(
    _SkiSpecialtyDraft draft,
    String type,
    int number,
  ) {
    final draftIndex = _skiDrafts.indexOf(draft);
    final prefix = draftIndex >= 0 ? 's${draftIndex + 1}' : draft.specialty;
    return '${prefix}_${type}_$number';
  }

  String _firstAvailableSpecialty() {
    final preferred = CoachTrainingUtils.specialties
        .where((specialty) => specialty != 'CL')
        .toList();
    for (final specialty in preferred) {
      if (!_skiDrafts.any((draft) => draft.specialty == specialty)) {
        return specialty;
      }
    }
    for (final specialty in CoachTrainingUtils.specialties) {
      if (!_skiDrafts.any((draft) => draft.specialty == specialty)) {
        return specialty;
      }
    }
    return 'GS';
  }

  void _setDraftSpecialty(_SkiSpecialtyDraft draft, String specialty) {
    if (_skiDrafts
        .any((item) => item != draft && item.specialty == specialty)) {
      return;
    }
    draft.specialty = specialty;
    if (specialty == 'CL') {
      for (final track in draft.tracks) {
        track.dispose();
      }
      for (final block in draft.trainingBlocks) {
        block.dispose();
      }
      draft.tracks.clear();
      draft.trainingBlocks.clear();
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case CoachTrainingUtils.attendancePresent:
        return 'Presente';
      case CoachTrainingUtils.attendanceAbsent:
        return 'Assente';
      default:
        return 'In attesa';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case CoachTrainingUtils.attendancePresent:
        return AppTheme.success;
      case CoachTrainingUtils.attendanceAbsent:
        return AppTheme.error;
      default:
        return AppTheme.primary;
    }
  }

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    final current = DateTime.tryParse(_dateCtrl.text) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null) {
      setState(() => _dateCtrl.text = date.toIso8601String().split('T').first);
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    HapticFeedback.lightImpact();
    final time = await showTimePicker(
      context: context,
      initialTime: _parseTime(controller.text),
    );
    if (time != null) {
      setState(() {
        controller.text =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      });
    }
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

  void _showOptions(
    String title,
    List<String> options,
    TextEditingController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textHighEmphasis,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((option) {
                    final selected = controller.text == option;
                    return ChoiceChip(
                      label: Text(option),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => controller.text = option);
                        Navigator.pop(context);
                      },
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.background,
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppTheme.textMediumEmphasis,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _buildTechnicalDetails() {
    if (!_isSki) {
      return {
        'technicalVersion': 2,
        'teamIds': _selectedTeams.map((team) => team.id).toList(),
        'plannedDrylandSession': _buildPlannedDrylandSession(),
      };
    }

    final activeDrafts = _skiDrafts;
    if (activeDrafts.isEmpty) {
      return {
        'technicalVersion': 3,
        'teamIds': _selectedTeams.map((team) => team.id).toList(),
        'qualityRating': _qualityRating,
        'snowCondition': _snowCtrl.text,
        'weatherCondition': _weatherCtrl.text,
        'specialties': ['SL'],
        'freeSkiing': {'specialty': 'SL', 'laps': '', 'changes': ''},
        'freeSkiingBySpecialty': {
          'SL': {'specialty': 'SL', 'laps': '', 'changes': ''},
        },
        'chrono': {'enabled': _chronoEnabled},
      };
    }
    final freeBySpecialty = {
      for (final draft in activeDrafts)
        draft.specialty: {
          'specialty': draft.specialty,
          'laps': draft.freeLapsCtrl.text,
          'changes': draft.freeChangesCtrl.text,
        },
    };
    final tracks = <Map<String, dynamic>>[
      for (final draft in activeDrafts)
        if (draft.specialty != 'CL')
          ...draft.tracks.map((track) => track.toTrackJson(draft.specialty)),
    ];
    final trainingBlocks = <Map<String, dynamic>>[
      for (final draft in activeDrafts)
        if (draft.specialty != 'CL')
          ...draft.trainingBlocks.map(
            (block) => block.toTrainingJson(draft.specialty),
          ),
    ];
    final firstFree = freeBySpecialty.values.first;

    final details = <String, dynamic>{
      'technicalVersion': 3,
      'teamIds': _selectedTeams.map((team) => team.id).toList(),
      'qualityRating': _qualityRating,
      'snowCondition': _snowCtrl.text,
      'weatherCondition': _weatherCtrl.text,
      'specialties': activeDrafts.map((draft) => draft.specialty).toList(),
      'freeSkiingBySpecialty': freeBySpecialty,
      'freeSkiing': firstFree,
      if (tracks.isNotEmpty) 'tracks': tracks,
      if (tracks.isNotEmpty)
        'gatedSkiing': {
          'laps': tracks.fold<int>(
            0,
            (sum, track) => sum + CoachTrainingUtils.asInt(track['laps']),
          ),
          'changes': tracks.isEmpty
              ? 0
              : CoachTrainingUtils.asInt(tracks.first['gates']),
        },
      if (trainingBlocks.isNotEmpty) 'trainingBlocks': trainingBlocks,
      'chrono': {'enabled': _chronoEnabled},
    };
    return details;
  }

  List<Map<String, dynamic>> _buildAttendeesPayload() {
    return _invitedAthletes.map((athlete) {
      final status = CoachTrainingUtils.attendeeStatus(athlete);
      return CoachTrainingUtils.normalizeAttendee({
        'id': athlete['id'],
        'name': athlete['name'],
        'teamId': athlete['teamId'],
        'teamName': athlete['teamName'],
        'attendanceStatus': status,
        'isPresent': athlete['isPresent'],
        'invitedAt': athlete['invitedAt'] ?? DateTime.now().toIso8601String(),
        'respondedAt': athlete['respondedAt'],
        'laps': athlete['laps'],
        'freeLaps': athlete['freeLaps'],
        'freeChanges': athlete['freeChanges'],
        'freeLapsBySpecialty': athlete['freeLapsBySpecialty'],
        'freeChangesBySpecialty': athlete['freeChangesBySpecialty'],
        'trainingLaps': athlete['trainingLaps'],
        'trackLaps': athlete['trackLaps'],
        'trackGates': athlete['trackGates'],
        'trainingBlockLaps': athlete['trainingBlockLaps'],
        'trainingBlockReferences': athlete['trainingBlockReferences'],
        'rpe': athlete['rpe'],
        'pain': athlete['pain'],
        'chronoNotes': athlete['chronoNotes'],
        'athleteNotes': athlete['athleteNotes'],
        'actualDrylandDetails': athlete['actualDrylandDetails'],
        'modifiedByAthlete': athlete['modifiedByAthlete'] == true,
        'modifiedAt': athlete['modifiedAt'],
      });
    }).toList();
  }

  CalendarEvent _draftEventForSummary() {
    return CalendarEvent(
      id: widget.event?.id ?? 'draft',
      teamId: _selectedTeams.isEmpty ? '' : _selectedTeams.first.id,
      type: _eventType,
      title: _titleCtrl.text,
      date: _dateCtrl.text,
      startTime: _startCtrl.text,
      endTime: _endCtrl.text,
      location: _locationCtrl.text,
      notes: _notesCtrl.text,
      sportCategory: _sportCategory,
      drylandSpecialty: _drylandSpecialtyCtrl.text,
      technicalDetails: _buildTechnicalDetails(),
      attendees: _buildAttendeesPayload(),
      status: _eventStatus,
    );
  }

  TrainingVolumeSummary _summaryForAthlete(Map<String, dynamic> athlete) {
    return CoachTrainingUtils.volumeFromEventAttendee(
      _draftEventForSummary(),
      athlete,
    );
  }

  Future<void> _showAthleteDataSheet(int index) async {
    if (index < 0 || index >= _athletes.length) return;
    final athlete = _athletes[index];
    final freeLapsBySpecialty = athlete['freeLapsBySpecialty'] is Map
        ? Map<String, dynamic>.from(athlete['freeLapsBySpecialty'])
        : <String, dynamic>{};
    final freeCtrls = <String, TextEditingController>{};
    for (final draft in _skiDrafts) {
      final useLegacyFallback = _skiDrafts.length == 1;
      freeCtrls[draft.specialty] = TextEditingController(
        text: (freeLapsBySpecialty[draft.specialty] ??
                (useLegacyFallback ? athlete['freeLaps'] : null) ??
                draft.freeLapsCtrl.text)
            .toString(),
      );
    }
    final rpeCtrl =
        TextEditingController(text: athlete['rpe']?.toString() ?? '');
    final painCtrl =
        TextEditingController(text: athlete['pain']?.toString() ?? '');
    final chronoCtrl =
        TextEditingController(text: athlete['chronoNotes']?.toString() ?? '');
    final notesCtrl =
        TextEditingController(text: athlete['athleteNotes']?.toString() ?? '');
    final trackCtrls = <String, TextEditingController>{};
    final trackLaps = athlete['trackLaps'] is Map
        ? Map<String, dynamic>.from(athlete['trackLaps'])
        : <String, dynamic>{};
    for (final draft in _skiDrafts) {
      for (final track in draft.tracks) {
        trackCtrls[track.id] = TextEditingController(
          text: (trackLaps[track.id] ?? track.lapsCtrl.text).toString(),
        );
      }
    }
    final trainingCtrls = <String, TextEditingController>{};
    final trainingLaps = athlete['trainingBlockLaps'] is Map
        ? Map<String, dynamic>.from(athlete['trainingBlockLaps'])
        : <String, dynamic>{};
    for (final draft in _skiDrafts) {
      for (final block in draft.trainingBlocks) {
        trainingCtrls[block.id] = TextEditingController(
          text: (trainingLaps[block.id] ?? block.lapsCtrl.text).toString(),
        );
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    athlete['name']?.toString() ?? 'Atleta',
                    style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final draft in _skiDrafts)
                    _sheetNumberInput(
                      'Giri campo libero ${draft.specialty}',
                      freeCtrls[draft.specialty]!,
                    ),
                  for (final draft in _skiDrafts)
                    ...draft.tracks.map((track) => _sheetNumberInput(
                          'Giri ${draft.specialty} ${track.name.toLowerCase()}',
                          trackCtrls[track.id]!,
                        )),
                  for (final draft in _skiDrafts)
                    ...draft.trainingBlocks.map((block) => _sheetNumberInput(
                          'Giri addestramento ${draft.specialty}',
                          trainingCtrls[block.id]!,
                        )),
                  _sheetNumberInput('RPE', rpeCtrl),
                  _sheetTextInput('Dolore', painCtrl),
                  if (_chronoEnabled) _sheetTextInput('Crono', chronoCtrl),
                  _sheetTextInput('Note atleta', notesCtrl, maxLines: 3),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          final freeBySpecialty = {
                            for (final entry in freeCtrls.entries)
                              entry.key:
                                  CoachTrainingUtils.asInt(entry.value.text),
                          };
                          if (freeBySpecialty.isNotEmpty) {
                            athlete['freeLapsBySpecialty'] = freeBySpecialty;
                            athlete['freeLaps'] = freeBySpecialty.values.first;
                          }
                          if (trackCtrls.isNotEmpty) {
                            athlete['trackLaps'] = {
                              for (final entry in trackCtrls.entries)
                                entry.key:
                                    CoachTrainingUtils.asInt(entry.value.text),
                            };
                            athlete['laps'] = CoachTrainingUtils.asInt(
                              trackCtrls.values.first.text,
                            );
                          }
                          if (trainingCtrls.isNotEmpty) {
                            athlete['trainingBlockLaps'] = {
                              for (final entry in trainingCtrls.entries)
                                entry.key:
                                    CoachTrainingUtils.asInt(entry.value.text),
                            };
                            athlete['trainingLaps'] = CoachTrainingUtils.asInt(
                              trainingCtrls.values.first.text,
                            );
                          }
                          athlete['rpe'] =
                              CoachTrainingUtils.asInt(rpeCtrl.text);
                          athlete['pain'] = painCtrl.text;
                          athlete['chronoNotes'] = chronoCtrl.text;
                          athlete['athleteNotes'] = notesCtrl.text;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Salva dati atleta'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    for (final controller in freeCtrls.values) {
      controller.dispose();
    }
    rpeCtrl.dispose();
    painCtrl.dispose();
    chronoCtrl.dispose();
    notesCtrl.dispose();
    for (final controller in trackCtrls.values) {
      controller.dispose();
    }
    for (final controller in trainingCtrls.values) {
      controller.dispose();
    }
  }

  Widget _sheetNumberInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _smallNumberInput(label, controller),
    );
  }

  Widget _sheetTextInput(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: TextStyle(color: AppTheme.textHighEmphasis),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSave() async {
    if (_selectedTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un team.')),
      );
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un titolo.')),
      );
      return;
    }
    if (_eventStatus == CoachTrainingUtils.statusCompleted && !_canComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puoi completare solo allenamenti già terminati.'),
        ),
      );
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    final confirmed = await _showSaveConfirmation();
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isSaving = true);
    final event = CalendarEvent(
      id: widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      teamId: _selectedTeams.first.id,
      type: _eventType,
      title: _titleCtrl.text.trim(),
      date: _dateCtrl.text,
      startTime: _startCtrl.text,
      endTime: _endCtrl.text,
      location: _locationCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      sportCategory: _sportCategory,
      drylandSpecialty: _drylandSpecialtyCtrl.text.trim(),
      technicalDetails: _buildTechnicalDetails(),
      attendees: _buildAttendeesPayload(),
      status: _eventStatus,
    );

    await appState.saveCoachEvent(event);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_eventStatus == CoachTrainingUtils.statusCompleted
            ? 'Allenamento completato e sincronizzato.'
            : 'Allenamento salvato.'),
        backgroundColor: AppTheme.primary,
      ),
    );
    Navigator.pop(context);
  }

  Future<bool?> _showSaveConfirmation() {
    final teamCount = _selectedTeams.length;
    final invitedCount = _invitedAthletes.length;
    final presentCount = _presentAthletes.length;
    late final String message;
    if (_eventStatus == CoachTrainingUtils.statusCompleted) {
      message =
          'Stai creando dati tecnici per $presentCount atleti presenti. I dati verranno copiati sugli atleti presenti. Gli atleti potranno modificare i propri dati personali.';
    } else if (_eventStatus == CoachTrainingUtils.statusCancelled) {
      message =
          'L allenamento verra segnato come annullato. Gli atleti riceveranno l aggiornamento.';
    } else {
      message =
          'Stai creando un allenamento per $teamCount team e $invitedCount atleti convocati. Gli atleti riceveranno una richiesta di presenza.';
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Conferma salvataggio',
          style: TextStyle(
              color: AppTheme.textHighEmphasis, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: TextStyle(color: AppTheme.textMediumEmphasis),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final event = widget.event;
    if (event == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Elimina evento',
          style: TextStyle(
              color: AppTheme.textHighEmphasis, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Vuoi eliminare questo allenamento?',
          style: TextStyle(color: AppTheme.textMediumEmphasis),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Elimina',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Provider.of<AppState>(context, listen: false).deleteCoachEvent(event.id);
      Navigator.pop(context);
    }
  }
}
