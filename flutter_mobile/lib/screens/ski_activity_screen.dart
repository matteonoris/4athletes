import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../models/training_activity_models.dart';
import '../providers/app_state.dart';
import '../utils/coach_training_utils.dart';
import '../widgets/custom_card.dart';

class _SkiBlockDraft {
  final String id;
  final String name;
  final TextEditingController lapsCtrl;
  final TextEditingController metricCtrl;
  final FocusNode lapsFocus = FocusNode();
  final FocusNode metricFocus = FocusNode();

  _SkiBlockDraft({
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
        'laps': CoachTrainingUtils.asNonNegativeInt(lapsCtrl.text),
        'gates': CoachTrainingUtils.asNonNegativeInt(metricCtrl.text),
        'changes': CoachTrainingUtils.asNonNegativeInt(metricCtrl.text),
      };

  Map<String, dynamic> toTrainingJson(String specialty) => {
        'id': id,
        'name': name,
        'specialty': specialty,
        'laps': CoachTrainingUtils.asNonNegativeInt(lapsCtrl.text),
        'references': CoachTrainingUtils.asNonNegativeInt(metricCtrl.text),
        'changes': CoachTrainingUtils.asNonNegativeInt(metricCtrl.text),
      };

  void dispose() {
    lapsCtrl.dispose();
    metricCtrl.dispose();
    lapsFocus.dispose();
    metricFocus.dispose();
  }
}

class _SkiSpecialtyDraft {
  String specialty;
  final TextEditingController freeLapsCtrl;
  final TextEditingController freeChangesCtrl;
  final FocusNode freeLapsFocus = FocusNode();
  final FocusNode freeChangesFocus = FocusNode();
  final List<_SkiBlockDraft> tracks;
  final List<_SkiBlockDraft> trainingBlocks;

  _SkiSpecialtyDraft({
    required this.specialty,
    String freeLaps = '',
    String freeChanges = '',
    List<_SkiBlockDraft>? tracks,
    List<_SkiBlockDraft>? trainingBlocks,
  })  : freeLapsCtrl = TextEditingController(text: freeLaps),
        freeChangesCtrl = TextEditingController(text: freeChanges),
        tracks = tracks ?? [],
        trainingBlocks = trainingBlocks ?? [];

  void dispose() {
    freeLapsCtrl.dispose();
    freeChangesCtrl.dispose();
    freeLapsFocus.dispose();
    freeChangesFocus.dispose();
    for (final track in tracks) {
      track.dispose();
    }
    for (final block in trainingBlocks) {
      block.dispose();
    }
  }
}

class SkiActivityScreen extends StatefulWidget {
  final TrainingSession? initialSession;
  final DateTime? initialDate;

  const SkiActivityScreen({
    super.key,
    this.initialSession,
    this.initialDate,
  });

  @override
  State<SkiActivityScreen> createState() => _SkiActivityScreenState();
}

class _SkiActivityScreenState extends State<SkiActivityScreen> {
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

  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String _snowCondition = 'Compatta';
  String _weatherCondition = 'Sole';
  int _qualityRating = 3;
  double _rpe = 5;
  bool _chronoEnabled = false;
  bool _isSaving = false;

  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _chronoCtrl = TextEditingController();
  final _painCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_SkiSpecialtyDraft> _skiDrafts = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSession;
    final details = _mergedDetails(initial?.details);
    _date = initial == null
        ? (widget.initialDate ?? DateTime.now())
        : DateTime.tryParse(initial.date) ?? DateTime.now();
    _startTime = initial == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : _parseTime(initial.startTime);
    _endTime = initial == null
        ? const TimeOfDay(hour: 12, minute: 0)
        : _parseTime(initial.endTime);
    _rpe = (initial?.effort.toDouble() ??
            CoachTrainingUtils.asInt(details['rpe'], fallback: 5).toDouble())
        .clamp(0, 10);

    _titleCtrl.text =
        details['title']?.toString() ?? 'Allenamento Alpine Skiing';
    _locationCtrl.text = details['location']?.toString() ?? '';
    _snowCondition =
        details['snowCondition']?.toString().trim().isNotEmpty == true
            ? details['snowCondition'].toString()
            : 'Compatta';
    _weatherCondition =
        details['weatherCondition']?.toString().trim().isNotEmpty == true
            ? details['weatherCondition'].toString()
            : 'Sole';
    _qualityRating = CoachTrainingUtils.asInt(
      details['qualityRating'],
      fallback: 3,
    ).clamp(1, 5);
    _painCtrl.text = details['pain']?.toString() ?? '';
    _notesCtrl.text =
        (details['athleteNotes'] ?? details['notes'])?.toString() ?? '';
    _chronoCtrl.text = details['chronoNotes']?.toString() ?? '';
    final chrono = CoachTrainingUtils.chronoFromDetails(details);
    _chronoEnabled =
        chrono['enabled'] == true || _chronoCtrl.text.trim().isNotEmpty;
    _loadSkiDrafts(details);
  }

  Map<String, dynamic> _mergedDetails(Map<String, dynamic>? raw) {
    final root = Map<String, dynamic>.from(raw ?? const {});
    final nested = root['technicalDetails'];
    if (nested is! Map) return root;
    return {
      ...Map<String, dynamic>.from(nested),
      ...root,
    };
  }

  void _loadSkiDrafts(Map<String, dynamic> details) {
    final specialties = (widget.initialSession == null
            ? <String>['SL']
            : CoachTrainingUtils.specialtiesFromDetails(details))
        .where(CoachTrainingUtils.specialties.contains)
        .take(2)
        .toList();
    if (specialties.isEmpty) specialties.add('SL');

    final primarySpecialty = specialties.first;
    final freeBySpecialty =
        CoachTrainingUtils.freeSkiingBySpecialtyFromDetails(details);
    final tracks = CoachTrainingUtils.tracksFromDetails(details);
    final trainingBlocks =
        CoachTrainingUtils.trainingBlocksFromDetails(details);

    for (final specialty in specialties) {
      final free = freeBySpecialty[specialty] ??
          (specialties.length == 1
              ? CoachTrainingUtils.freeSkiingFromDetails(details)
              : const <String, dynamic>{});
      final draft = _SkiSpecialtyDraft(
        specialty: specialty,
        freeLaps: free['laps']?.toString() ?? '',
        freeChanges: free['changes']?.toString() ?? '',
      );

      for (final track in tracks) {
        if (draft.tracks.length >= 3) break;
        final nextTrackNumber = draft.tracks.length + 1;
        final trackSpecialty = CoachTrainingUtils.normalizeSpecialty(
          track['specialty']?.toString() ?? primarySpecialty,
        );
        if (trackSpecialty != specialty) continue;
        draft.tracks.add(_SkiBlockDraft(
          id: track['id']?.toString() ??
              _blockId(draft, 'track', nextTrackNumber),
          name: track['name']?.toString() ?? 'Tracciato $nextTrackNumber',
          laps: track['laps']?.toString() ?? '',
          metric: (track['gates'] ?? track['changes'])?.toString() ?? '',
        ));
      }

      for (final block in trainingBlocks) {
        if (draft.trainingBlocks.isNotEmpty) break;
        final blockSpecialty = CoachTrainingUtils.normalizeSpecialty(
          block['specialty']?.toString() ?? primarySpecialty,
        );
        if (blockSpecialty != specialty) continue;
        draft.trainingBlocks.add(_SkiBlockDraft(
          id: block['id']?.toString() ??
              _blockId(draft, 'training', draft.trainingBlocks.length + 1),
          name: block['name']?.toString() ?? 'Addestramento',
          laps: block['laps']?.toString() ?? '',
          metric: (block['references'] ?? block['changes'])?.toString() ?? '',
        ));
      }
      _skiDrafts.add(draft);
    }

    if (_skiDrafts.length == 1 &&
        _skiDrafts.first.specialty != 'CL' &&
        _skiDrafts.first.tracks.isEmpty &&
        details['gatedSkiing'] is Map) {
      final gated = details['gatedSkiing'] as Map;
      _skiDrafts.first.tracks.add(_SkiBlockDraft(
        id: _blockId(_skiDrafts.first, 'track', 1),
        name: 'Tracciato 1',
        laps: gated['laps']?.toString() ?? '',
        metric: (gated['gates'] ?? gated['changes'])?.toString() ?? '',
      ));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _chronoCtrl.dispose();
    _painCtrl.dispose();
    _notesCtrl.dispose();
    for (final draft in _skiDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return TimeOfDay.now();
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _durationMinutes() {
    final start = _startTime.hour * 60 + _startTime.minute;
    final end = _endTime.hour * 60 + _endTime.minute;
    var diff = end - start;
    if (diff < 0) diff += 24 * 60;
    return diff;
  }

  int _intValue(TextEditingController controller) {
    return CoachTrainingUtils.asNonNegativeInt(controller.text);
  }

  String _blockId(
    _SkiSpecialtyDraft draft,
    String type,
    int number,
  ) {
    final index = _skiDrafts.indexOf(draft);
    final draftNumber = index + 1;
    final prefix = index < 0 ? draft.specialty.toLowerCase() : 's$draftNumber';
    return '$prefix' '_$type' '_$number';
  }

  Map<String, dynamic> _details() {
    final previousDetails =
        Map<String, dynamic>.from(widget.initialSession?.details ?? const {});
    final freeBySpecialty = <String, Map<String, dynamic>>{
      for (final draft in _skiDrafts)
        draft.specialty: {
          'specialty': draft.specialty,
          'laps': _intValue(draft.freeLapsCtrl),
          'changes': _intValue(draft.freeChangesCtrl),
        },
    };
    final tracks = <Map<String, dynamic>>[
      for (final draft in _skiDrafts)
        if (draft.specialty != 'CL')
          ...draft.tracks.map((track) => track.toTrackJson(draft.specialty)),
    ];
    final trainingBlocks = <Map<String, dynamic>>[
      for (final draft in _skiDrafts)
        if (draft.specialty != 'CL')
          ...draft.trainingBlocks
              .map((block) => block.toTrainingJson(draft.specialty)),
    ];
    final specialties =
        _skiDrafts.map((draft) => draft.specialty).toList(growable: false);
    final firstFree = freeBySpecialty.values.first;

    final technicalDetails = <String, dynamic>{
      'technicalVersion': 3,
      'qualityRating': _qualityRating,
      'snowCondition': _snowCondition,
      'weatherCondition': _weatherCondition,
      'specialties': specialties,
      'freeSkiingBySpecialty': freeBySpecialty,
      'freeSkiing': firstFree,
      if (tracks.isNotEmpty) 'tracks': tracks,
      if (tracks.isNotEmpty)
        'gatedSkiing': {
          'laps': tracks.fold<int>(
            0,
            (sum, track) =>
                sum + CoachTrainingUtils.asNonNegativeInt(track['laps']),
          ),
          'changes': CoachTrainingUtils.asNonNegativeInt(
            tracks.first['gates'],
          ),
        },
      if (trainingBlocks.isNotEmpty) 'trainingBlocks': trainingBlocks,
      'chrono': {'enabled': _chronoEnabled},
    };

    final details = <String, dynamic>{
      ...previousDetails,
      'skiSchemaVersion': 3,
      'activityDomain': 'sport',
      'activityCategory': ActivityCategory.sport,
      'status': ActivityStatus.completed,
      'source': previousDetails['source'] ?? ActivitySource.athlete,
      'title': _titleCtrl.text.trim().isEmpty
          ? 'Allenamento Alpine Skiing'
          : _titleCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'specialty': specialties.first,
      'specialties': specialties,
      'qualityRating': _qualityRating,
      'snowCondition': _snowCondition,
      'weatherCondition': _weatherCondition,
      'technicalDetails': technicalDetails,
      'freeSkiingBySpecialty': freeBySpecialty,
      'freeSkiing': firstFree,
      if (tracks.isNotEmpty) 'tracks': tracks,
      if (tracks.isNotEmpty) 'gatedSkiing': technicalDetails['gatedSkiing'],
      if (trainingBlocks.isNotEmpty) 'trainingBlocks': trainingBlocks,
      'chrono': {'enabled': _chronoEnabled},
      if (_chronoEnabled && _chronoCtrl.text.trim().isNotEmpty)
        'chronoNotes': _chronoCtrl.text.trim(),
      'rpe': _rpe.round(),
      'pain': _painCtrl.text.trim(),
      'athleteNotes': _notesCtrl.text.trim(),
    }..removeWhere((_, value) => value is String && value.trim().isEmpty);
    if (tracks.isEmpty) {
      details.remove('tracks');
      details.remove('gatedSkiing');
    }
    if (trainingBlocks.isEmpty) {
      details.remove('trainingBlocks');
      details.remove('addestramento');
    }
    if (!_chronoEnabled || _chronoCtrl.text.trim().isEmpty) {
      details.remove('chronoNotes');
    }
    details['volumeSummary'] =
        CoachTrainingUtils.volumeFromDetails(details).toJson();
    return details;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    final session = TrainingSession(
      id: widget.initialSession?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      sportId: 'alpine_skiing',
      date: _date.toIso8601String().split('T').first,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      duration: _durationMinutes().toString(),
      effort: _rpe.round(),
      eventId: widget.initialSession?.eventId,
      details: _details(),
    );
    try {
      await context.read<AppState>().addSession(
            session,
            rethrowErrors: true,
          );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile salvare l allenamento. Riprova.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _delete() async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Elimina allenamento',
          style: TextStyle(
            color: AppTheme.textHighEmphasis,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Sei sicuro di voler eliminare questo allenamento?',
          style: TextStyle(color: AppTheme.textMediumEmphasis),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Elimina',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    final id = widget.initialSession?.id;
    if (confirm != true || id == null || !mounted) return;
    await context.read<AppState>().deleteSession(id);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  KeyboardActionsConfig _keyboardActionsConfig() {
    KeyboardActionsItem action(FocusNode node) {
      return KeyboardActionsItem(
        focusNode: node,
        toolbarButtons: [
          (node) => TextButton(
                onPressed: node.unfocus,
                child: const Text(
                  'Fatto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
        ],
      );
    }

    final actions = <KeyboardActionsItem>[];
    for (final draft in _skiDrafts) {
      actions.add(action(draft.freeLapsFocus));
      actions.add(action(draft.freeChangesFocus));
      for (final track in draft.tracks) {
        actions.add(action(track.lapsFocus));
        actions.add(action(track.metricFocus));
      }
      for (final block in draft.trainingBlocks) {
        actions.add(action(block.lapsFocus));
        actions.add(action(block.metricFocus));
      }
    }
    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
      keyboardBarColor: AppTheme.card,
      actions: actions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.initialSession == null
            ? 'Aggiungi Alpine Skiing'
            : 'Modifica Alpine Skiing'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.initialSession != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              tooltip: 'Elimina allenamento',
              onPressed: _delete,
            ),
        ],
      ),
      body: KeyboardActions(
        config: _keyboardActionsConfig(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            _overviewCard(),
            const SizedBox(height: 16),
            _conditionsCard(),
            const SizedBox(height: 16),
            _technicalCard(),
            const SizedBox(height: 16),
            _personalCard(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            key: const ValueKey('ski_save_button'),
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_isSaving ? 'Salvataggio...' : 'Salva allenamento'),
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

  Widget _overviewCard() {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.downhill_skiing, color: AppTheme.secondary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Alpine Skiing',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _specialtySelector(),
          const SizedBox(height: 18),
          _textInput(
            'Titolo allenamento',
            _titleCtrl,
            Icons.edit_outlined,
            key: const ValueKey('ski_training_title'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dateField()),
              const SizedBox(width: 8),
              Expanded(child: _timeField('Inizio', _startTime, true)),
              const SizedBox(width: 8),
              Expanded(child: _timeField('Fine', _endTime, false)),
            ],
          ),
          const SizedBox(height: 12),
          _textInput('Luogo', _locationCtrl, Icons.location_on_outlined),
        ],
      ),
    );
  }

  Widget _specialtySelector() {
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
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('ski_double_specialty'),
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
              fontSize: 11,
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

  String _firstAvailableSpecialty() {
    const preferred = ['GS', 'SL', 'SG', 'DH', 'SX', 'CL'];
    return preferred.firstWhere(
      (specialty) => !_skiDrafts.any((draft) => draft.specialty == specialty),
      orElse: () => 'GS',
    );
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

  Widget _conditionsCard() {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.cloud_outlined, 'Condizioni'),
          const SizedBox(height: 14),
          _choiceRow(
            'Neve',
            _snowOptions,
            _snowCondition,
            (value) => setState(() => _snowCondition = value),
          ),
          const SizedBox(height: 14),
          _choiceRow(
            'Meteo',
            _weatherOptions,
            _weatherCondition,
            (value) => setState(() => _weatherCondition = value),
          ),
          const SizedBox(height: 16),
          _qualityPicker(),
        ],
      ),
    );
  }

  Widget _qualityPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUALITA ALLENAMENTO',
          style: TextStyle(
            color: AppTheme.textMediumEmphasis,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          key: const ValueKey('ski_quality_picker'),
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

  Widget _technicalCard() {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.tune, 'Dettagli tecnici'),
          const SizedBox(height: 16),
          for (var i = 0; i < _skiDrafts.length; i++)
            _specialtyTechnicalSection(_skiDrafts[i], i),
          if (_skiDrafts.any((draft) => draft.specialty != 'CL')) ...[
            SwitchListTile(
              key: const ValueKey('ski_chrono_switch'),
              value: _chronoEnabled,
              onChanged: (value) => setState(() => _chronoEnabled = value),
              title: Text(
                'Crono',
                style: TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Abilita i dati cronometrati personali.',
                style: TextStyle(color: AppTheme.textMediumEmphasis),
              ),
              activeThumbColor: AppTheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }

  Widget _specialtyTechnicalSection(
    _SkiSpecialtyDraft draft,
    int draftIndex,
  ) {
    final label = CoachTrainingUtils.specialtyLabel(draft.specialty);
    final specialtyNumber = draftIndex + 1;
    return Padding(
      padding:
          EdgeInsets.only(bottom: draftIndex == _skiDrafts.length - 1 ? 0 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge(
            'Specialita $specialtyNumber - $label',
            AppTheme.primary,
          ),
          const SizedBox(height: 12),
          _volumeBlock(
            title: '$label - Campo libero',
            firstLabel: 'Giri',
            first: draft.freeLapsCtrl,
            firstFocus: draft.freeLapsFocus,
            secondLabel: 'Cambi/giro',
            second: draft.freeChangesCtrl,
            secondFocus: draft.freeChangesFocus,
            totalLabel: 'cambi',
          ),
          if (draft.specialty != 'CL') ...[
            for (final track in draft.tracks)
              _volumeBlock(
                title: _blockTitle(label, track.name),
                firstLabel: 'Giri',
                first: track.lapsCtrl,
                firstFocus: track.lapsFocus,
                secondLabel: 'Porte/giro',
                second: track.metricCtrl,
                secondFocus: track.metricFocus,
                totalLabel: 'passaggi',
                onRemove: () => setState(() {
                  draft.tracks.remove(track);
                  track.dispose();
                }),
              ),
            if (draft.tracks.length < 3)
              TextButton.icon(
                key: _specialtyKey('ski_add_track', draft.specialty),
                onPressed: () => _addTrack(draft),
                icon: const Icon(Icons.add),
                label: Text('Aggiungi tracciato $label'),
              ),
            const SizedBox(height: 8),
            for (final block in draft.trainingBlocks)
              _volumeBlock(
                title: _blockTitle(label, block.name),
                firstLabel: 'Giri',
                first: block.lapsCtrl,
                firstFocus: block.lapsFocus,
                secondLabel: 'Riferimenti/giro',
                second: block.metricCtrl,
                secondFocus: block.metricFocus,
                totalLabel: 'cambi',
                onRemove: () => setState(() {
                  draft.trainingBlocks.remove(block);
                  block.dispose();
                }),
              ),
            TextButton.icon(
              key: _specialtyKey('ski_add_training', draft.specialty),
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

  void _addTrack(_SkiSpecialtyDraft draft) {
    if (draft.tracks.length >= 3) return;
    setState(() {
      final number = draft.tracks.length + 1;
      draft.tracks.add(_SkiBlockDraft(
        id: _blockId(draft, 'track', number),
        name: 'Tracciato $number',
      ));
    });
  }

  void _addTrainingBlock(_SkiSpecialtyDraft draft) {
    if (draft.trainingBlocks.isNotEmpty) return;
    setState(() {
      draft.trainingBlocks.add(_SkiBlockDraft(
        id: _blockId(draft, 'training', 1),
        name: 'Addestramento',
      ));
    });
  }

  String _blockTitle(String specialty, String name) => '$specialty - $name';

  ValueKey<String> _specialtyKey(String prefix, String specialty) {
    return ValueKey<String>('$prefix' '_$specialty');
  }

  Widget _personalCard() {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.person_outline, 'Dati personali'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'RPE',
                  style: TextStyle(
                    color: AppTheme.textMediumEmphasis,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _badge(_rpe.round().toString(), AppTheme.primary),
            ],
          ),
          Slider(
            value: _rpe,
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (value) => setState(() => _rpe = value),
          ),
          _textInput('Dolore', _painCtrl, Icons.healing_outlined),
          if (_chronoEnabled) ...[
            const SizedBox(height: 12),
            _textInput(
              'Crono personale / note tempi',
              _chronoCtrl,
              Icons.timer_outlined,
            ),
          ],
          const SizedBox(height: 12),
          _textInput('Note personali', _notesCtrl, Icons.notes, maxLines: 3),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppTheme.textHighEmphasis,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _volumeBlock({
    required String title,
    required String firstLabel,
    required TextEditingController first,
    required FocusNode firstFocus,
    required String secondLabel,
    required TextEditingController second,
    required FocusNode secondFocus,
    required String totalLabel,
    VoidCallback? onRemove,
  }) {
    final total = _intValue(first) * _intValue(second);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
                  title,
                  style: TextStyle(
                    color: AppTheme.textHighEmphasis,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Rimuovi',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _numberInput(firstLabel, first, firstFocus)),
              const SizedBox(width: 10),
              Expanded(child: _numberInput(secondLabel, second, secondFocus)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Totale $totalLabel: $total',
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField() {
    return _tapField(
      'Data',
      _date.toIso8601String().split('T').first,
      Icons.calendar_today_outlined,
      () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 730)),
        );
        if (selected != null) setState(() => _date = selected);
      },
    );
  }

  Widget _timeField(String label, TimeOfDay value, bool isStart) {
    return _tapField(label, _formatTime(value), Icons.access_time, () async {
      final selected =
          await showTimePicker(context: context, initialTime: value);
      if (selected == null) return;
      setState(() {
        if (isStart) {
          _startTime = selected;
        } else {
          _endTime = selected;
        }
      });
    });
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
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.subtleBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textHighEmphasis,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textInput(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    Key? key,
  }) {
    return TextField(
      key: key,
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: AppTheme.textHighEmphasis),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _numberInput(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
  ) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        color: AppTheme.textHighEmphasis,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _choiceRow(
    String label,
    List<String> values,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textMediumEmphasis,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) {
            final isSelected = selected == value;
            return ChoiceChip(
              label: Text(value),
              selected: isSelected,
              onSelected: (_) => onSelected(value),
              selectedColor: AppTheme.primary,
              backgroundColor: AppTheme.background,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textMediumEmphasis,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
