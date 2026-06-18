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

class SkiActivityScreen extends StatefulWidget {
  final TrainingSession? initialSession;

  const SkiActivityScreen({super.key, this.initialSession});

  @override
  State<SkiActivityScreen> createState() => _SkiActivityScreenState();
}

class _SkiActivityScreenState extends State<SkiActivityScreen> {
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String _specialty = 'CL';
  String _snowCondition = '';
  String _weatherCondition = '';
  double _rpe = 5;

  final _locationCtrl = TextEditingController();
  final _freeLapsCtrl = TextEditingController();
  final _freeChangesCtrl = TextEditingController();
  final _trackLapsCtrl = TextEditingController();
  final _trackGatesCtrl = TextEditingController();
  final _trainingLapsCtrl = TextEditingController();
  final _trainingRefsCtrl = TextEditingController();
  final _chronoCtrl = TextEditingController();
  final _painCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _freeLapsFocus = FocusNode();
  final _freeChangesFocus = FocusNode();
  final _trackLapsFocus = FocusNode();
  final _trackGatesFocus = FocusNode();
  final _trainingLapsFocus = FocusNode();
  final _trainingRefsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSession;
    _date = initial == null ? DateTime.now() : DateTime.parse(initial.date);
    _startTime = initial == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : _parseTime(initial.startTime);
    _endTime = initial == null
        ? const TimeOfDay(hour: 12, minute: 0)
        : _parseTime(initial.endTime);
    _rpe = (initial?.effort.toDouble() ?? 5).clamp(0, 10);

    final details = initial?.details ?? {};
    _specialty = CoachTrainingUtils.specialtyFromDetails(details);
    _locationCtrl.text = details['location']?.toString() ?? '';
    _snowCondition = details['snowCondition']?.toString() ?? '';
    _weatherCondition = details['weatherCondition']?.toString() ?? '';
    _painCtrl.text = details['pain']?.toString() ?? '';
    _notesCtrl.text =
        (details['athleteNotes'] ?? details['notes'])?.toString() ?? '';
    _chronoCtrl.text = details['chronoNotes']?.toString() ?? '';

    final free = CoachTrainingUtils.freeSkiingFromDetails(details);
    _freeLapsCtrl.text = (details['freeLaps'] ?? free['laps'] ?? '').toString();
    _freeChangesCtrl.text = (free['changes'] ?? '').toString();

    final tracks = CoachTrainingUtils.tracksFromDetails(details);
    if (tracks.isNotEmpty) {
      _trackLapsCtrl.text = (tracks.first['laps'] ?? '').toString();
      _trackGatesCtrl.text =
          (tracks.first['gates'] ?? tracks.first['changes'] ?? '').toString();
    } else {
      final gated = details['gatedSkiing'];
      if (gated is Map) {
        _trackLapsCtrl.text = (gated['laps'] ?? '').toString();
        _trackGatesCtrl.text = (gated['changes'] ?? '').toString();
      }
    }

    final trainingBlocks =
        CoachTrainingUtils.trainingBlocksFromDetails(details);
    if (trainingBlocks.isNotEmpty) {
      _trainingLapsCtrl.text = (trainingBlocks.first['laps'] ?? '').toString();
      _trainingRefsCtrl.text = (trainingBlocks.first['references'] ??
              trainingBlocks.first['changes'] ??
              '')
          .toString();
    }
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _freeLapsCtrl.dispose();
    _freeChangesCtrl.dispose();
    _trackLapsCtrl.dispose();
    _trackGatesCtrl.dispose();
    _trainingLapsCtrl.dispose();
    _trainingRefsCtrl.dispose();
    _chronoCtrl.dispose();
    _painCtrl.dispose();
    _notesCtrl.dispose();
    _freeLapsFocus.dispose();
    _freeChangesFocus.dispose();
    _trackLapsFocus.dispose();
    _trackGatesFocus.dispose();
    _trainingLapsFocus.dispose();
    _trainingRefsFocus.dispose();
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
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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

  Map<String, dynamic> _details() {
    final freeLaps = _intValue(_freeLapsCtrl);
    final freeChanges = _intValue(_freeChangesCtrl);
    final trackLaps = _intValue(_trackLapsCtrl);
    final trackGates = _intValue(_trackGatesCtrl);
    final trainingLaps = _intValue(_trainingLapsCtrl);
    final trainingRefs = _intValue(_trainingRefsCtrl);

    final technicalDetails = <String, dynamic>{
      'specialty': _specialty,
      'specialties': [_specialty],
      'snowCondition': _snowCondition,
      'weatherCondition': _weatherCondition,
      if (freeLaps > 0 || freeChanges > 0)
        'freeSkiing': {'laps': freeLaps, 'changes': freeChanges},
      if (trackLaps > 0 || trackGates > 0)
        'tracks': [
          {
            'id': 'track_1',
            'specialty': _specialty,
            'laps': trackLaps,
            'gates': trackGates,
          }
        ],
      if (trainingLaps > 0 || trainingRefs > 0)
        'trainingBlocks': [
          {
            'id': 'training_1',
            'name': 'Addestramento',
            'laps': trainingLaps,
            'references': trainingRefs,
          }
        ],
      if (_chronoCtrl.text.trim().isNotEmpty)
        'chrono': {'enabled': true, 'notes': _chronoCtrl.text.trim()},
    };

    return {
      'skiSchemaVersion': 2,
      'activityDomain': 'sport',
      'activityCategory': ActivityCategory.sport,
      'source': ActivitySource.athlete,
      'title': 'Alpine Skiing',
      'location': _locationCtrl.text.trim(),
      'specialty': _specialty,
      'specialties': [_specialty],
      'snowCondition': _snowCondition,
      'weatherCondition': _weatherCondition,
      'technicalDetails': technicalDetails,
      if (freeLaps > 0 || freeChanges > 0)
        'freeSkiing': {'laps': freeLaps, 'changes': freeChanges},
      if (freeLaps > 0) 'freeLaps': freeLaps,
      if (trackLaps > 0 || trackGates > 0)
        'tracks': [
          {
            'id': 'track_1',
            'specialty': _specialty,
            'laps': trackLaps,
            'gates': trackGates,
          }
        ],
      if (trackLaps > 0 || trackGates > 0)
        'gatedSkiing': {'laps': trackLaps, 'changes': trackGates},
      if (trainingLaps > 0 || trainingRefs > 0)
        'trainingBlocks': [
          {
            'id': 'training_1',
            'name': 'Addestramento',
            'laps': trainingLaps,
            'references': trainingRefs,
          }
        ],
      if (_chronoCtrl.text.trim().isNotEmpty)
        'chronoNotes': _chronoCtrl.text.trim(),
      'rpe': _rpe.round(),
      'pain': _painCtrl.text.trim(),
      'athleteNotes': _notesCtrl.text.trim(),
    }..removeWhere((_, value) {
        if (value == null) return true;
        if (value is String) return value.trim().isEmpty;
        return false;
      });
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
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
    await Provider.of<AppState>(context, listen: false).addSession(session);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _delete() async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Elimina Allenamento',
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
            child: Text(
              'Annulla',
              style: TextStyle(color: AppTheme.textMediumEmphasis),
            ),
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
    Provider.of<AppState>(context, listen: false).deleteSession(id);
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

    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
      keyboardBarColor: AppTheme.card,
      actions: [
        action(_freeLapsFocus),
        action(_freeChangesFocus),
        action(_trackLapsFocus),
        action(_trackGatesFocus),
        action(_trainingLapsFocus),
        action(_trainingRefsFocus),
      ],
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
            _technicalCard(),
            const SizedBox(height: 16),
            _conditionsCard(),
            const SizedBox(height: 16),
            _personalCard(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Salva allenamento'),
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
          Row(
            children: [
              const Icon(Icons.downhill_skiing, color: AppTheme.secondary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Alpine Skiing',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              _badge(_specialty, AppTheme.secondary),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CoachTrainingUtils.specialties.map((item) {
              final selected = _specialty == item;
              return ChoiceChip(
                label: Text(item),
                selected: selected,
                onSelected: (_) => setState(() => _specialty = item),
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.background,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppTheme.textMediumEmphasis,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
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

  Widget _technicalCard() {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dettagli tecnici',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          _volumeBlock(
            title: 'Campo libero',
            firstLabel: 'Giri',
            first: _freeLapsCtrl,
            secondLabel: 'Cambi/giro',
            second: _freeChangesCtrl,
          ),
          _volumeBlock(
            title: 'Pali',
            firstLabel: 'Giri',
            first: _trackLapsCtrl,
            secondLabel: 'Porte/giro',
            second: _trackGatesCtrl,
          ),
          _volumeBlock(
            title: 'Addestramento',
            firstLabel: 'Giri',
            first: _trainingLapsCtrl,
            secondLabel: 'Riferimenti/giro',
            second: _trainingRefsCtrl,
          ),
          _textInput('Crono / note tempi', _chronoCtrl, Icons.timer_outlined),
        ],
      ),
    );
  }

  Widget _conditionsCard() {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Condizioni',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 14),
          _choiceRow(
              'Neve',
              [
                'Dura',
                'Compatta',
                'Morbida',
                'Primaverile',
                'Fresca',
              ],
              _snowCondition,
              (value) => setState(() => _snowCondition = value)),
          const SizedBox(height: 12),
          _choiceRow(
              'Meteo',
              [
                'Sole',
                'Nuvolo',
                'Nevicata',
                'Nebbia',
                'Vento',
              ],
              _weatherCondition,
              (value) => setState(() => _weatherCondition = value)),
        ],
      ),
    );
  }

  Widget _personalCard() {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dati personali',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('RPE',
                    style: TextStyle(
                        color: AppTheme.textMediumEmphasis,
                        fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 12),
          _textInput('Note personali', _notesCtrl, Icons.notes, maxLines: 3),
        ],
      ),
    );
  }

  Widget _volumeBlock({
    required String title,
    required String firstLabel,
    required TextEditingController first,
    required String secondLabel,
    required TextEditingController second,
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
          Text(title,
              style: TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _numberInput(firstLabel, first, _focusNodeFor(first)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberInput(secondLabel, second, _focusNodeFor(second)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Totale: $total',
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
            Text(label,
                style: TextStyle(
                    color: AppTheme.textMediumEmphasis, fontSize: 11)),
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
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
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

  FocusNode _focusNodeFor(TextEditingController controller) {
    if (controller == _freeLapsCtrl) return _freeLapsFocus;
    if (controller == _freeChangesCtrl) return _freeChangesFocus;
    if (controller == _trackLapsCtrl) return _trackLapsFocus;
    if (controller == _trackGatesCtrl) return _trackGatesFocus;
    if (controller == _trainingLapsCtrl) return _trainingLapsFocus;
    return _trainingRefsFocus;
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
          color: AppTheme.textHighEmphasis, fontWeight: FontWeight.bold),
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
        Text(label,
            style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
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
