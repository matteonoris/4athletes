import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
// sports.dart removed
import '../data/exercises.dart';
import '../utils/strength_pr_utils.dart';
import '../widgets/custom_card.dart';

class _SkiBlockDraft {
  final String id;
  final String name;
  String laps;
  String metric;

  _SkiBlockDraft({
    required this.id,
    required this.name,
    this.laps = '',
    this.metric = '',
  });

  Map<String, dynamic> toTrackJson() => {
        'id': id,
        'name': name,
        'laps': laps,
        'gates': metric,
        'changes': metric,
      };

  Map<String, dynamic> toTrainingJson() => {
        'id': id,
        'name': name,
        'laps': laps,
        'references': metric,
        'changes': metric,
      };
}

class AddTrainingScreen extends StatefulWidget {
  final String sportId;
  final String sportName;
  final TrainingSession? initialSession;

  const AddTrainingScreen({
    super.key,
    required this.sportId,
    required this.sportName,
    this.initialSession,
  });

  @override
  State<AddTrainingScreen> createState() => _AddTrainingScreenState();
}

class _AddTrainingScreenState extends State<AddTrainingScreen> {
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  double _effort = 5.0;

  // Pain Monitoring
  List<String> _painZones = [];
  String _otherPain = '';

  // Sport Specific States
  // Skiing
  final List<String> _specialties = [];
  List<Map<String, String>> _chronoLaps = [];
  String _freeSkiingChanges = '';
  String _freeSkiingLaps = '';
  final List<_SkiBlockDraft> _tracks = [];
  final List<_SkiBlockDraft> _trainingBlocks = [];
  String _snowCondition = '';
  String _weatherCondition = '';

  // Running
  // Endurance
  String _enduranceDistance = '';
  String _endurancePace = '';
  String _enduranceAvgHr = '';
  String _enduranceMaxHr = '';
  String _enduranceElevation = '';
  String _enduranceCadence = '';
  String _enduranceSurface = '';

  // Football
  // String _fbType = 'training'; // match or training
  // String _fbGoals = '';
  // String _fbAssists = '';
  // String _fbResult = '';
  // String _fbOpponent = '';
  // String _fbPosition = '';

  // Tennis
  // String _tennisType = 'practice';
  // String _tennisResult = '';
  // String _tennisScore = '';
  // String _tennisSurface = '';
  // String _tennisOpponent = '';
  // String _tennisAces = '';

  // Cycling
  // String _cycType = 'road';
  // String _cycDistance = '';
  // String _cycAvgSpeed = '';
  // String _cycPower = '';
  // String _cycCadence = '';
  // String _cycElevation = '';
  // String _cycAvgHr = '';

  // Strength / Stretching / Athletic
  final List<Map<String, dynamic>> _wlExercises = [];
  final List<Map<String, dynamic>> _stretchExercises = [];
  final List<Map<String, dynamic>> _athleticExercises = [];

  bool _showExercisePicker = false;
  String _exerciseSearch = '';
  String _exerciseCategoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    final init = widget.initialSession;
    _date = init != null ? DateTime.parse(init.date) : DateTime.now();
    _startTime = init != null
        ? _parseTime(init.startTime)
        : const TimeOfDay(hour: 9, minute: 0);
    _endTime = init != null
        ? _parseTime(init.endTime)
        : const TimeOfDay(hour: 10, minute: 30);
    _effort = (init?.effort.toDouble() ?? 5.0).clamp(0.0, 10.0);

    if (init?.details != null && init!.details!['painZones'] != null) {
      _painZones = List<String>.from(init.details!['painZones']);
      final other = _painZones.firstWhere((z) => z.startsWith('Altro:'),
          orElse: () => '');
      if (other.isNotEmpty) {
        _otherPain = other.replaceFirst('Altro: ', '');
        _painZones[_painZones.indexOf(other)] = 'Altro';
      }
    }

    if (init?.details != null) {
      final d = init!.details!;
      _enduranceDistance =
          d['distance']?.toString().replaceAll(' km', '') ?? '';
      _endurancePace = d['pace']
              ?.toString()
              .replaceAll(' /km', '')
              .replaceAll(' km/h', '') ??
          '';
      _enduranceAvgHr =
          d['avgHeartRate']?.toString().replaceAll(' bpm', '') ?? '';
      _enduranceMaxHr =
          d['maxHeartRate']?.toString().replaceAll(' bpm', '') ?? '';
      _enduranceElevation =
          d['elevation']?.toString().replaceAll(' m', '') ?? '';
      _enduranceCadence = d['cadence']
              ?.toString()
              .replaceAll(' spm', '')
              .replaceAll(' rpm', '') ??
          '';
      _enduranceSurface = d['surface']?.toString() ?? '';

      if (init.sportId == 'alpine_skiing') {
        if (d['chronoLaps'] != null) {
          _chronoLaps = List<Map<String, String>>.from((d['chronoLaps'] as List)
              .map((x) => Map<String, String>.from(x)));
        }
        if (d['specialties'] != null) {
          _specialties.addAll(List<String>.from(d['specialties']));
        }
        if (d['freeSkiing'] != null) {
          _freeSkiingLaps = d['freeSkiing']['laps']?.toString() ?? '';
          _freeSkiingChanges = d['freeSkiing']['changes']?.toString() ?? '';
        }
        _loadSkiBlocks(d);
      }

      // Restore weightlifting / powerlifting / crossfit / bodybuilding exercises
      if (d['exercises'] != null) {
        final exList = d['exercises'] as List<dynamic>;
        for (var ex in exList) {
          final exMap = Map<String, dynamic>.from(ex as Map);
          // Normalize sets: ensure each set has proper num types
          if (exMap['sets'] != null) {
            exMap['sets'] = (exMap['sets'] as List<dynamic>).map((s) {
              final setMap = Map<String, dynamic>.from(s as Map);
              return {
                'kg': (setMap['kg'] as num?)?.toDouble() ?? 0.0,
                'reps': (setMap['reps'] as num?)?.toInt() ?? 0,
              };
            }).toList();
          } else {
            exMap['sets'] = [];
          }
          _wlExercises.add(exMap);
        }
      }
    }
  }

  TimeOfDay _parseTime(String time) {
    if (time.isEmpty) return TimeOfDay.now();
    final parts = time.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0);
    }
    return TimeOfDay.now();
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  double _oneRepMaxForExercise(AppState appState, String exerciseId) {
    return currentOneRepMaxForExercise(
      exerciseId,
      appState.prLogs,
      profileOneRepMax: appState.userProfile?.oneRepMax,
    );
  }

  Map<String, dynamic> _newWeightliftingSet(List<dynamic> sets) {
    if (sets.isEmpty) return {'kg': 0.0, 'reps': 0};

    final previous = Map<String, dynamic>.from(sets.last as Map);
    return {
      'kg': (previous['kg'] as num?)?.toDouble() ?? 0.0,
      'reps': (previous['reps'] as num?)?.toInt() ?? 0,
    };
  }

  void _loadSkiBlocks(Map<String, dynamic> details) {
    final tracks = details['tracks'];
    if (tracks is List) {
      for (var i = 0; i < tracks.length && i < 3; i++) {
        final track = tracks[i];
        if (track is! Map) continue;
        _tracks.add(_SkiBlockDraft(
          id: track['id']?.toString() ?? 'track_${i + 1}',
          name: track['name']?.toString() ?? 'Tracciato ${i + 1}',
          laps: track['laps']?.toString() ?? '',
          metric: (track['gates'] ?? track['changes'])?.toString() ?? '',
        ));
      }
    } else if (details['gatedSkiing'] is Map) {
      final gated = details['gatedSkiing'] as Map;
      _tracks.add(_SkiBlockDraft(
        id: 'track_1',
        name: 'Tracciato 1',
        laps: gated['laps']?.toString() ?? '',
        metric: (gated['gates'] ?? gated['changes'])?.toString() ?? '',
      ));
    }

    final blocks = details['trainingBlocks'];
    if (blocks is List) {
      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];
        if (block is! Map) continue;
        _trainingBlocks.add(_SkiBlockDraft(
          id: block['id']?.toString() ?? 'training_${i + 1}',
          name: block['name']?.toString() ?? 'Addestramento',
          laps: block['laps']?.toString() ?? '',
          metric: (block['references'] ?? block['changes'])?.toString() ?? '',
        ));
      }
    } else if (details['addestramento'] is Map) {
      final block = details['addestramento'] as Map;
      _trainingBlocks.add(_SkiBlockDraft(
        id: 'training_1',
        name: 'Addestramento',
        laps: block['laps']?.toString() ?? '',
        metric: (block['references'] ?? block['changes'])?.toString() ?? '',
      ));
    }
  }

  int _calculateDuration() {
    final start = _startTime.hour * 60 + _startTime.minute;
    final end = _endTime.hour * 60 + _endTime.minute;
    int diff = end - start;
    if (diff < 0) diff += 24 * 60;
    return diff;
  }

  void _saveSession() {
    final duration = _calculateDuration();
    final isSkiing = widget.sportId == 'alpine_skiing';
    // ignore unused sport type booleans — kept for future section expansion
    // ignore: unused_local_variable
    final isRunning =
        widget.sportId.contains('running') || widget.sportId == 'track_field';
    // ignore: unused_local_variable
    final isWeightlifting = [
      'weightlifting',
      'powerlifting',
      'crossfit',
      'bodybuilding'
    ].contains(widget.sportId);
    // ignore: unused_local_variable
    final isFootball =
        ['soccer', 'am_football', 'rugby'].contains(widget.sportId);
    // ignore: unused_local_variable
    final isTennis =
        ['tennis', 'padel', 'pickleball', 'squash'].contains(widget.sportId);
    // ignore: unused_local_variable
    final isCycling =
        widget.sportId.contains('cycling') || widget.sportId == 'spinning';
    // ignore: unused_local_variable
    final isStretching =
        ['stretching', 'yoga', 'pilates'].contains(widget.sportId);
    // ignore: unused_local_variable
    final isAthletic = [
      'athletic_prep',
      'other',
      'hyperarch',
      'tendon_isometrics'
    ].contains(widget.sportId);

    final enduranceSports = [
      'running',
      'cycling',
      'marathon',
      'triathlon',
      'rowing',
      'hiking',
      'walking',
      'trail_running',
      'cross_country_skiing',
      'swimming',
      'spinning'
    ];
    final isEndurance = enduranceSports.contains(widget.sportId) ||
        widget.sportId.contains('running') ||
        widget.sportId.contains('cycling');

    // Map raw pain zones back
    final formattedPainZones =
        _painZones.map((z) => z == 'Altro' ? 'Altro: $_otherPain' : z).toList();

    final tracks = isSkiing && !_specialties.contains('CL')
        ? _tracks.map((track) => track.toTrackJson()).toList()
        : <Map<String, dynamic>>[];
    final trainingBlocks = isSkiing && !_specialties.contains('CL')
        ? _trainingBlocks.map((block) => block.toTrainingJson()).toList()
        : <Map<String, dynamic>>[];
    final gatedLaps = tracks.fold<int>(
      0,
      (sum, track) =>
          sum + (int.tryParse(track['laps']?.toString() ?? '') ?? 0),
    );
    final gatedChanges = tracks.isEmpty
        ? 0
        : (int.tryParse(tracks.first['gates']?.toString() ?? '') ?? 0);

    // Map details
    final details = <String, dynamic>{
      if (widget.initialSession?.details != null)
        ...widget.initialSession!.details!,
      'painZones': formattedPainZones,
      if (isSkiing) 'specialties': _specialties,
      if (isSkiing)
        'freeSkiing': {'changes': _freeSkiingChanges, 'laps': _freeSkiingLaps},
      if (isSkiing && tracks.isNotEmpty) 'tracks': tracks,
      if (isSkiing && tracks.isNotEmpty)
        'gatedSkiing': {
          'changes': gatedChanges,
          'laps': gatedLaps,
        },
      if (isSkiing && trainingBlocks.isNotEmpty)
        'trainingBlocks': trainingBlocks,
      if (isSkiing) 'snowCondition': _snowCondition,
      if (isSkiing) 'weatherCondition': _weatherCondition,
      if (isSkiing && _chronoLaps.isNotEmpty) 'chronoLaps': _chronoLaps,
      if (isEndurance)
        'distance':
            _enduranceDistance.isNotEmpty ? '$_enduranceDistance km' : null,
      if (isEndurance)
        'pace': _endurancePace.isNotEmpty
            ? '$_endurancePace ${isRunning ? "/km" : "km/h"}'
            : null,
      if (isEndurance)
        'avgHeartRate':
            _enduranceAvgHr.isNotEmpty ? '$_enduranceAvgHr bpm' : null,
      if (isEndurance)
        'maxHeartRate':
            _enduranceMaxHr.isNotEmpty ? '$_enduranceMaxHr bpm' : null,
      if (isEndurance)
        'elevation':
            _enduranceElevation.isNotEmpty ? '$_enduranceElevation m' : null,
      if (isEndurance)
        'cadence': _enduranceCadence.isNotEmpty
            ? '$_enduranceCadence ${isRunning ? "spm" : "rpm"}'
            : null,
      if (isEndurance)
        'surface': _enduranceSurface.isNotEmpty ? _enduranceSurface : null,
      // Weightlifting / powerlifting / crossfit / bodybuilding exercises
      if (isWeightlifting && _wlExercises.isNotEmpty) 'exercises': _wlExercises,
      // Athletic prep / stretching exercises
      if (isAthletic && _athleticExercises.isNotEmpty)
        'exercises': _athleticExercises,
      if (isStretching && _stretchExercises.isNotEmpty)
        'exercises': _stretchExercises,
    };

    // Remove null values so we don't accidentally overwrite with nulls
    details.removeWhere((key, value) => value == null);
    if (isSkiing) {
      if (tracks.isEmpty) {
        details.remove('tracks');
        details.remove('gatedSkiing');
      }
      if (trainingBlocks.isEmpty) {
        details.remove('trainingBlocks');
        details.remove('addestramento');
      }
    }

    final session = TrainingSession(
      id: widget.initialSession?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      eventId: widget.initialSession?.eventId,
      date: _date.toIso8601String().split('T')[0],
      sportId: widget.sportId,
      duration: duration.toString(),
      effort: _effort.toInt(),
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      details: details,
    );

    Provider.of<AppState>(context, listen: false).addSession(session);
    // Pop all the way back to the Home screen
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _addTrack() {
    if (_tracks.length >= 3) return;
    setState(() {
      final number = _tracks.length + 1;
      _tracks.add(_SkiBlockDraft(
        id: 'track_$number',
        name: 'Tracciato $number',
      ));
    });
  }

  void _addTrainingBlock() {
    setState(() {
      _trainingBlocks.add(_SkiBlockDraft(
        id: 'training_1',
        name: 'Addestramento',
      ));
    });
  }

  int _skiBlockTotal(_SkiBlockDraft block) {
    return (int.tryParse(block.laps) ?? 0) * (int.tryParse(block.metric) ?? 0);
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'barbell':
        return 'Bilanciere';
      case 'dumbbell':
        return 'Manubri';
      case 'cable':
        return 'Cavi';
      case 'machine':
        return 'Macchinario';
      case 'bodyweight':
        return 'Corpo Libero';
      case 'kettlebell':
        return 'Kettlebell';
      case 'band':
        return 'Elastico';
      default:
        return cat;
    }
  }

  void _prefillWithLastSession() {
    final appState = Provider.of<AppState>(context, listen: false);
    // Find the most recent session for this sport that has exercises
    final lastSessionIndex = appState.sessions.indexWhere(
      (s) =>
          s.sportId == widget.sportId &&
          s.details != null &&
          s.details!['exercises'] != null,
    );

    if (lastSessionIndex != -1) {
      final lastSession = appState.sessions[lastSessionIndex];
      final d = lastSession.details!;
      if (d['exercises'] != null) {
        final exList = d['exercises'] as List<dynamic>;
        setState(() {
          final isAthletic = [
            'athletic_prep',
            'other',
            'hyperarch',
            'tendon_isometrics'
          ].contains(widget.sportId);
          final isStretching =
              ['stretching', 'yoga', 'pilates'].contains(widget.sportId);

          if (isAthletic) {
            _athleticExercises.clear();
          } else if (isStretching) {
            _stretchExercises.clear();
          } else {
            _wlExercises.clear();
          }

          for (var ex in exList) {
            final exMap = Map<String, dynamic>.from(ex as Map);
            if (exMap['sets'] != null) {
              exMap['sets'] = (exMap['sets'] as List<dynamic>).map((s) {
                final setMap = Map<String, dynamic>.from(s as Map);
                return {
                  'kg': (setMap['kg'] as num?)?.toDouble() ?? 0.0,
                  'reps': (setMap['reps'] as num?)?.toInt() ?? 0,
                };
              }).toList();
            } else {
              exMap['sets'] = [];
            }

            if (isAthletic) {
              _athleticExercises.add(exMap);
            } else if (isStretching) {
              _stretchExercises.add(exMap);
            } else {
              _wlExercises.add(exMap);
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Scheda precompilata con l'ultimo allenamento!")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Nessun allenamento precedente trovato per questo sport.')),
      );
    }
  }

  Widget _buildField(String label, String value, Function(String) onChanged,
      {Key? key, TextInputType type = TextInputType.text, String suffix = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMediumEmphasis)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.subtleBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: key,
                  initialValue: value,
                  keyboardType: type,
                  onChanged: onChanged,
                  style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
              if (suffix.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(suffix,
                      style: TextStyle(
                          color: AppTheme.textMediumEmphasis, fontSize: 12)),
                )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChips(String label, List<String> options, String selected,
      Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMediumEmphasis)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSel = selected == opt;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onSelect(opt);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSel
                      ? AppTheme.secondary.withValues(alpha: 0.2)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isSel ? AppTheme.secondary : AppTheme.subtleFill),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSel
                        ? AppTheme.secondary
                        : AppTheme.textMediumEmphasis,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSkiBlockCard({
    required _SkiBlockDraft block,
    required String metricLabel,
    required String totalLabel,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.alt_route, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.name,
                      style: TextStyle(
                        color: AppTheme.textHighEmphasis,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '$totalLabel: ${_skiBlockTotal(block)}',
                      style: TextStyle(
                        color: AppTheme.textMediumEmphasis,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppTheme.textMediumEmphasis,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  'GIRI TOTALI',
                  block.laps,
                  (v) => setState(() => block.laps = v),
                  key: ValueKey('${block.id}_laps'),
                  type: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  metricLabel,
                  block.metric,
                  (v) => setState(() => block.metric = v),
                  key: ValueKey('${block.id}_metric'),
                  type: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // sport parameter provided directly by widget

    final isSkiing = widget.sportId == 'alpine_skiing';
    final enduranceSports = [
      'running',
      'cycling',
      'marathon',
      'triathlon',
      'rowing',
      'hiking',
      'walking',
      'trail_running',
      'cross_country_skiing',
      'swimming',
      'spinning'
    ];
    final isRunning =
        widget.sportId.contains('running') || widget.sportId == 'track_field';
    final isEndurance = enduranceSports.contains(widget.sportId) ||
        widget.sportId.contains('running') ||
        widget.sportId.contains('cycling');
    final isWeightlifting = [
      'weightlifting',
      'powerlifting',
      'crossfit',
      'bodybuilding'
    ].contains(widget.sportId);
    final isStretching =
        ['stretching', 'yoga', 'pilates'].contains(widget.sportId);
    final isAthletic = [
      'athletic_prep',
      'other',
      'hyperarch',
      'tendon_isometrics'
    ].contains(widget.sportId);

    // Dynamic Effort Color based on React logic
    Color effortColor;
    if (_effort <= 3) {
      effortColor = Colors.green;
    } else if (_effort <= 7)
      effortColor = Colors.orange;
    else
      effortColor = Colors.red;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.initialSession != null ? 'Modifica ' : 'Aggiungi ',
                style: const TextStyle(fontSize: 16)),
            Text(widget.sportName,
                style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(
                left: 16, right: 16, top: 16, bottom: 100),
            children: [
              // Date & Time
              CustomCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today,
                          color: AppTheme.primary),
                      title: const Text('Data', style: TextStyle(fontSize: 14)),
                      trailing: Text(
                        "${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate:
                              DateTime.now().add(const Duration(days: 30)),
                        );
                        if (d != null) setState(() => _date = d);
                      },
                    ),
                    Divider(color: AppTheme.divider, height: 1),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            leading: const Icon(Icons.access_time,
                                color: AppTheme.primary),
                            title: const Text('Inizio',
                                style: TextStyle(fontSize: 12)),
                            subtitle: Text(_formatTime(_startTime),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final t = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (t != null) setState(() => _startTime = t);
                            },
                          ),
                        ),
                        Container(
                            width: 1, height: 40, color: AppTheme.divider),
                        Expanded(
                          child: ListTile(
                            leading: const Icon(Icons.access_time_filled,
                                color: AppTheme.primary),
                            title: const Text('Fine',
                                style: TextStyle(fontSize: 12)),
                            subtitle: Text(_formatTime(_endTime),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final t = await showTimePicker(
                                context: context,
                                initialTime: _endTime,
                              );
                              if (t != null) setState(() => _endTime = t);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ================= SPORT SPECIFIC SECTIONS ================= //

              if (isEndurance) ...[
                const Text('Dettagli Resistenza',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _buildField('DISTANZA', _enduranceDistance,
                            (v) => setState(() => _enduranceDistance = v),
                            type: TextInputType.number, suffix: 'km')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildField(
                            isRunning ? 'PASSO MEDIO' : 'VELOCITÀ MEDIA',
                            _endurancePace,
                            (v) => setState(() => _endurancePace = v),
                            suffix: isRunning ? '/km' : 'km/h')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _buildField('FC MEDIA', _enduranceAvgHr,
                            (v) => setState(() => _enduranceAvgHr = v),
                            type: TextInputType.number, suffix: 'bpm')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildField('FC MAX', _enduranceMaxHr,
                            (v) => setState(() => _enduranceMaxHr = v),
                            type: TextInputType.number, suffix: 'bpm')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _buildField('DISLIVELLO', _enduranceElevation,
                            (v) => setState(() => _enduranceElevation = v),
                            type: TextInputType.number, suffix: 'm')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildField(
                            isRunning ? 'CADENZA' : 'CADENZA MEDIA',
                            _enduranceCadence,
                            (v) => setState(() => _enduranceCadence = v),
                            type: TextInputType.number,
                            suffix: isRunning ? 'spm' : 'rpm')),
                  ],
                ),
                const SizedBox(height: 12),
                _buildChoiceChips(
                    'SUPERFICIE / TERRENO',
                    [
                      'Asfalto',
                      'Sterrato',
                      'Misto',
                      'Pista',
                      'Tapis Roulant',
                      'Sentiero',
                      'Indoor'
                    ],
                    _enduranceSurface,
                    (v) => setState(() => _enduranceSurface = v)),
                const SizedBox(height: 24),
              ],

              if (isSkiing) ...[
                const Text('Dettagli Sci',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildChoiceChips('SPECIALITÀ', ['SL', 'GS', 'SG', 'DH', 'CL'],
                    _specialties.isEmpty ? '' : _specialties[0], (v) {
                  setState(() {
                    _specialties.clear();
                    _specialties.add(v);
                    if (v == 'CL') {
                      _tracks.clear();
                      _trainingBlocks.clear();
                    }
                  });
                }),
                const SizedBox(height: 16),
                Text('Campo Libero',
                    style: TextStyle(
                        color: AppTheme.textHighEmphasis,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _buildField('GIRI TOTALI', _freeSkiingLaps,
                            (v) => setState(() => _freeSkiingLaps = v),
                            type: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildField('CAMBI PER GIRO', _freeSkiingChanges,
                            (v) => setState(() => _freeSkiingChanges = v),
                            type: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_specialties.contains('CL')) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tracciati',
                          style: TextStyle(
                              color: AppTheme.textHighEmphasis,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      if (_tracks.length < 3)
                        TextButton.icon(
                          onPressed: _addTrack,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('AGGIUNGI',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._tracks.map((track) => _buildSkiBlockCard(
                        block: track,
                        metricLabel: 'PORTE/GIRO',
                        totalLabel: 'Totale passaggi',
                        color: AppTheme.primary,
                        onRemove: () => setState(() => _tracks.remove(track)),
                      )),
                  if (_tracks.isEmpty)
                    GestureDetector(
                      onTap: _addTrack,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.subtleBorder),
                        ),
                        child: const Center(
                          child: Text('+ AGGIUNGI TRACCIATO',
                              style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Addestramento',
                          style: TextStyle(
                              color: AppTheme.textHighEmphasis,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      TextButton.icon(
                        onPressed:
                            _trainingBlocks.isEmpty ? _addTrainingBlock : null,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('AGGIUNGI',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._trainingBlocks.map((block) => _buildSkiBlockCard(
                        block: block,
                        metricLabel: 'RIFERIMENTI/GIRO',
                        totalLabel: 'Totale cambi',
                        color: Colors.orange,
                        onRemove: () =>
                            setState(() => _trainingBlocks.remove(block)),
                      )),
                  if (_trainingBlocks.isEmpty)
                    GestureDetector(
                      onTap: _addTrainingBlock,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.subtleBorder),
                        ),
                        child: const Center(
                          child: Text('+ AGGIUNGI ADDESTRAMENTO',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                _buildChoiceChips(
                    'NEVE',
                    [
                      'Dura/Ghiacciata',
                      'Compatta',
                      'Morbida',
                      'Primaverile',
                      'Fresca'
                    ],
                    _snowCondition,
                    (v) => setState(() => _snowCondition = v)),
                const SizedBox(height: 12),
                _buildChoiceChips(
                    'METEO',
                    ['Sole', 'Nuvolo', 'Nevicata', 'Nebbia', 'Vento'],
                    _weatherCondition,
                    (v) => setState(() => _weatherCondition = v)),
                const SizedBox(height: 24),
              ],

              if (isWeightlifting || isAthletic || isStretching) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Esercizi',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _prefillWithLastSession,
                          icon: const Icon(Icons.history, size: 16),
                          label: const Text('PRECOMPILA',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _showExercisePicker = true),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('AGGIUNGI',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 12),
                if (_wlExercises.isEmpty &&
                    _athleticExercises.isEmpty &&
                    _stretchExercises.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(16)),
                    child: Center(
                        child: Text(
                            'Nessun esercizio aggiunto. Clicca Aggiungi per iniziare.',
                            style:
                                TextStyle(color: AppTheme.textMediumEmphasis),
                            textAlign: TextAlign.center)),
                  ),
                if (_wlExercises.isNotEmpty)
                  ..._wlExercises.asMap().entries.map((entry) {
                    int exIdx = entry.key;
                    var ex = entry.value;
                    List<dynamic> sets = ex['sets'] ?? [];
                    final appState = Provider.of<AppState>(context);
                    final double maxLoad =
                        _oneRepMaxForExercise(appState, ex['id'].toString());

                    return CustomCard(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.subtleFill,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(ex['name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (exIdx > 0)
                                      IconButton(
                                        icon: Icon(Icons.keyboard_arrow_up,
                                            size: 20,
                                            color: AppTheme.textMediumEmphasis),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          setState(() {
                                            final item =
                                                _wlExercises.removeAt(exIdx);
                                            _wlExercises.insert(
                                                exIdx - 1, item);
                                          });
                                        },
                                      ),
                                    if (exIdx < _wlExercises.length - 1)
                                      IconButton(
                                        icon: Icon(Icons.keyboard_arrow_down,
                                            size: 20,
                                            color: AppTheme.textMediumEmphasis),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          setState(() {
                                            final item =
                                                _wlExercises.removeAt(exIdx);
                                            _wlExercises.insert(
                                                exIdx + 1, item);
                                          });
                                        },
                                      ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          size: 20,
                                          color: AppTheme.textMediumEmphasis),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => setState(
                                          () => _wlExercises.removeAt(exIdx)),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                        width: 32,
                                        child: Text('SET',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: AppTheme
                                                    .textMediumEmphasis))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text('KG (LOAD)',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: AppTheme
                                                    .textMediumEmphasis))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text('REPS',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: AppTheme
                                                    .textMediumEmphasis))),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                        width: 40,
                                        child: Text('% 1RM',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: AppTheme
                                                    .textMediumEmphasis))),
                                    const SizedBox(width: 32),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...sets.asMap().entries.map((setEntry) {
                                  int setIdx = setEntry.key;
                                  var setMap = setEntry.value;
                                  double load =
                                      (setMap['kg'] as num).toDouble();
                                  String pctStr = '-';
                                  if (maxLoad > 0 && load > 0) {
                                    pctStr =
                                        '${((load / maxLoad) * 100).toStringAsFixed(0)}%';
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6),
                                            decoration: BoxDecoration(
                                                color: AppTheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(4)),
                                            child: Text('${setIdx + 1}',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SizedBox(
                                            height: 36,
                                            child: TextFormField(
                                              initialValue: setMap['kg'] > 0
                                                  ? setMap['kg'].toString()
                                                  : '',
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold),
                                              decoration: InputDecoration(
                                                contentPadding: EdgeInsets.zero,
                                                filled: true,
                                                fillColor: AppTheme.surface,
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    borderSide:
                                                        BorderSide.none),
                                              ),
                                              onChanged: (v) {
                                                double newKg = double.tryParse(
                                                        v.replaceAll(
                                                            ',', '.')) ??
                                                    0;
                                                setState(() {
                                                  _wlExercises[exIdx]['sets']
                                                      [setIdx]['kg'] = newKg;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SizedBox(
                                            height: 36,
                                            child: TextFormField(
                                              initialValue: setMap['reps'] > 0
                                                  ? setMap['reps'].toString()
                                                  : '',
                                              keyboardType:
                                                  TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold),
                                              decoration: InputDecoration(
                                                contentPadding: EdgeInsets.zero,
                                                filled: true,
                                                fillColor: AppTheme.surface,
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    borderSide:
                                                        BorderSide.none),
                                              ),
                                              onChanged: (v) {
                                                int newReps =
                                                    int.tryParse(v) ?? 0;
                                                setState(() {
                                                  _wlExercises[exIdx]['sets']
                                                          [setIdx]['reps'] =
                                                      newReps;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 40,
                                          child: Text(pctStr,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme
                                                      .textMediumEmphasis)),
                                        ),
                                        SizedBox(
                                          width: 32,
                                          child: IconButton(
                                            icon: Icon(Icons.close,
                                                size: 16,
                                                color: AppTheme
                                                    .textMediumEmphasis),
                                            onPressed: () {
                                              setState(() {
                                                _wlExercises[exIdx]['sets']
                                                    .removeAt(setIdx);
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _wlExercises[exIdx]['sets']
                                          .add(_newWeightliftingSet(sets));
                                    });
                                  },
                                  child: Text('+ Add Set',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMediumEmphasis)),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 24),
              ],

              // ================= CHRONO & MATERIALS (SKIING ONLY) ================= //
              if (widget.sportId == 'alpine_skiing') ...[
                Row(
                  children: [
                    Text('CRONOMETRO & MATERIALI',
                        style: TextStyle(
                            color: AppTheme.textMediumEmphasis,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.2)),
                    const Spacer(),
                    Icon(PhosphorIconsRegular.timer,
                        size: 16, color: AppTheme.textMediumEmphasis),
                  ],
                ),
                const SizedBox(height: 12),
                ..._chronoLaps.asMap().entries.map((e) {
                  final idx = e.key;
                  final lap = e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('GIRO ${idx + 1}',
                                style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            GestureDetector(
                              onTap: () {
                                setState(() => _chronoLaps.removeAt(idx));
                              },
                              child: Icon(Icons.delete_outline,
                                  size: 18, color: AppTheme.textMediumEmphasis),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('TEMPO',
                                      style: TextStyle(
                                          color: AppTheme.textMediumEmphasis,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextFormField(
                                      initialValue: lap['time'],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      style: TextStyle(
                                          color: AppTheme.textHighEmphasis,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'es. 45.2',
                                        hintStyle: TextStyle(
                                            color: AppTheme.textMediumEmphasis),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (v) {
                                        setState(() => lap['time'] = v);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('MATERIALE USATO',
                                      style: TextStyle(
                                          color: AppTheme.textMediumEmphasis,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextFormField(
                                      initialValue: lap['material'],
                                      style: TextStyle(
                                          color: AppTheme.textHighEmphasis,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'es. Sci Gara 1',
                                        hintStyle: TextStyle(
                                            color: AppTheme.textMediumEmphasis),
                                        prefixIcon: Icon(
                                            PhosphorIconsRegular.package,
                                            size: 16,
                                            color: AppTheme.textMediumEmphasis),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (v) {
                                        setState(() => lap['material'] = v);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _chronoLaps.add({'time': '', 'material': ''});
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.subtleBorder),
                    ),
                    child: const Center(
                      child: Text('+ AGGIUNGI GIRO CRONO',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // ================= PAIN & RPE SECTIONS ================= //

              const Text('Monitoraggio Dolore',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    ['Nessuno', 'Schiena', 'Ginocchio', 'Altro'].map((zone) {
                  final isSel = _painZones.contains(zone);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        if (zone == 'Nessuno') {
                          _painZones.clear();
                          _painZones.add('Nessuno');
                        } else {
                          _painZones.remove('Nessuno');
                          if (isSel) {
                            _painZones.remove(zone);
                          } else {
                            _painZones.add(zone);
                          }
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppTheme.error.withValues(alpha: 0.2)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                isSel ? AppTheme.error : AppTheme.subtleFill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSel)
                            const Icon(Icons.local_hospital,
                                size: 14, color: AppTheme.error),
                          if (isSel) const SizedBox(width: 6),
                          Text(
                            zone,
                            style: TextStyle(
                                color: isSel
                                    ? AppTheme.error
                                    : AppTheme.textMediumEmphasis,
                                fontWeight:
                                    isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_painZones.contains('Altro')) ...[
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _otherPain = v),
                  decoration: InputDecoration(
                    hintText: 'Specifica dove fa male...',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('RPE (Sforzo Percepito)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    _effort.toInt().toString(),
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: effortColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: effortColor,
                  thumbColor: effortColor,
                  inactiveTrackColor: AppTheme.subtleFill,
                  trackHeight: 8,
                ),
                child: Slider(
                  value: _effort,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  onChanged: (v) => setState(() => _effort = v),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0 - Nessuno Sforzo',
                      style: TextStyle(
                          color: AppTheme.textMediumEmphasis, fontSize: 12)),
                  Text('10 - Massimale',
                      style: TextStyle(
                          color: AppTheme.textMediumEmphasis, fontSize: 12)),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),

          if (_showExercisePicker)
            Container(
              color: Colors.black.withValues(alpha: 0.85),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.subtleFill,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Seleziona Esercizio',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => setState(() {
                                  _showExercisePicker = false;
                                  _exerciseSearch = '';
                                  _exerciseCategoryFilter = 'all';
                                }),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Cerca esercizio o muscolo...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 12),
                              filled: true,
                              fillColor: AppTheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (v) =>
                                setState(() => _exerciseSearch = v),
                          ),
                        ),
                        // Category filter chips
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              ...[
                                ('all', 'Tutti', Icons.grid_view_rounded),
                                ('barbell', 'Bilanciere', Icons.fitness_center),
                                (
                                  'dumbbell',
                                  'Manubri',
                                  Icons.sports_gymnastics
                                ),
                                ('cable', 'Cavi', Icons.cable),
                                ('machine', 'Macchinari', Icons.settings),
                                (
                                  'bodyweight',
                                  'Corpo Libero',
                                  Icons.accessibility_new
                                ),
                                (
                                  'kettlebell',
                                  'Kettlebell',
                                  Icons.sports_handball
                                ),
                                ('band', 'Elastici', Icons.lens_blur),
                              ].map((item) {
                                final isActive =
                                    _exerciseCategoryFilter == item.$1;
                                return GestureDetector(
                                  onTap: () => setState(
                                      () => _exerciseCategoryFilter = item.$1),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppTheme.secondary
                                              .withValues(alpha: 0.2)
                                          : AppTheme.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isActive
                                            ? AppTheme.secondary
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(item.$3,
                                            size: 12,
                                            color: isActive
                                                ? AppTheme.secondary
                                                : AppTheme.textMediumEmphasis),
                                        const SizedBox(width: 4),
                                        Text(
                                          item.$2,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isActive
                                                ? AppTheme.secondary
                                                : AppTheme.textMediumEmphasis,
                                            fontWeight: isActive
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Exercise list
                        Builder(builder: (context) {
                          final filtered = exerciseDatabase.where((ex) {
                            final q = _exerciseSearch.toLowerCase();
                            final matchesSearch = q.isEmpty ||
                                ex.name.toLowerCase().contains(q) ||
                                ex.targetMuscle.toLowerCase().contains(q);
                            final matchesCat =
                                _exerciseCategoryFilter == 'all' ||
                                    ex.category == _exerciseCategoryFilter;
                            return matchesSearch && matchesCat;
                          }).toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                child: Text(
                                  '${filtered.length} esercizi',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMediumEmphasis),
                                ),
                              ),
                              SizedBox(
                                height: 280,
                                child: ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, i) {
                                    final ex = filtered[i];
                                    return ListTile(
                                      dense: true,
                                      title: Text(ex.name,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                          '${ex.targetMuscle}  •  ${_categoryLabel(ex.category)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppTheme.textMediumEmphasis)),
                                      trailing: const Icon(Icons.add_circle,
                                          color: AppTheme.secondary, size: 22),
                                      onTap: () {
                                        setState(() {
                                          _wlExercises.add({
                                            'name': ex.name,
                                            'id': ex.id,
                                            'sets': [
                                              {'kg': 0.0, 'reps': 0}
                                            ]
                                          });
                                          _showExercisePicker = false;
                                          _exerciseSearch = '';
                                          _exerciseCategoryFilter = 'all';
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Bottom sticky Save Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.background,
                    AppTheme.background.withValues(alpha: 0.0)
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveSession,
                    child: const Text('SALVA ALLENAMENTO'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
