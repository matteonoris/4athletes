import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../models/training_activity_models.dart';
import '../providers/app_state.dart';
import '../services/training_activity_service.dart';
import '../utils/coach_training_utils.dart';
import '../utils/training_metrics_utils.dart';
import '../widgets/custom_card.dart';
import 'dryland_activity_screen.dart';

class AthleteEventScreen extends StatefulWidget {
  final CalendarEvent event;

  const AthleteEventScreen({super.key, required this.event});

  @override
  State<AthleteEventScreen> createState() => _AthleteEventScreenState();
}

class _AthleteEventScreenState extends State<AthleteEventScreen> {
  static const List<String> _painOptions = [
    'Nessuno',
    'Schiena',
    'Ginocchio',
    'Altro',
  ];

  bool _isLoading = false;
  Map<String, dynamic>? _attendee;

  late TextEditingController _freeLapsCtrl;
  late TextEditingController _painCtrl;
  late TextEditingController _chronoCtrl;
  late TextEditingController _notesCtrl;

  final Map<String, TextEditingController> _trackLapsCtrls = {};
  final Map<String, TextEditingController> _trainingLapsCtrls = {};

  int _rpeValue = 0;
  String _painSelection = 'Nessuno';

  String get _status => widget.event.status;
  bool get _isCancelled => _status == CoachTrainingUtils.statusCancelled;
  bool get _isCompleted => _status == CoachTrainingUtils.statusCompleted;
  bool get _isPlanned => _status == CoachTrainingUtils.statusPlanned;
  bool get _isSki => widget.event.sportCategory == 'ski';

  bool get _isPresent =>
      _attendee != null && CoachTrainingUtils.isAttendeePresent(_attendee!);

  bool get _canEditPersonal => _isCompleted && _isPresent && _isSki;
  bool get _canEditDryland => _isCompleted && _isPresent && !_isSki;

  @override
  void initState() {
    super.initState();
    _attendee = _findCurrentAttendee();
    final tech = widget.event.technicalDetails ?? {};
    final free = CoachTrainingUtils.freeSkiingFromDetails(tech);
    final rawPain = (_attendee?['pain'] ?? '').toString().trim();

    _freeLapsCtrl = TextEditingController(
      text: (_attendee?['freeLaps'] ?? free['laps'] ?? '').toString(),
    );
    _rpeValue = CoachTrainingUtils.asNonNegativeInt(_attendee?['rpe'])
        .clamp(0, 10)
        .toInt();
    _painSelection = _painOptions.contains(rawPain) || rawPain.isEmpty
        ? (rawPain.isEmpty ? 'Nessuno' : rawPain)
        : 'Altro';
    _painCtrl = TextEditingController(
      text: _painSelection == 'Altro' ? rawPain : '',
    );
    _chronoCtrl = TextEditingController(
      text: _attendee?['chronoNotes']?.toString() ?? '',
    );
    _notesCtrl = TextEditingController(
      text: _attendee?['athleteNotes']?.toString() ?? '',
    );

    _initTrackControllers(tech);
    _initTrainingControllers(tech);
  }

  Map<String, dynamic>? _findCurrentAttendee() {
    final appState = Provider.of<AppState>(context, listen: false);
    final athleteName =
        '${appState.userProfile?.firstName ?? ''} ${appState.userProfile?.lastName ?? ''}'
            .trim();
    final attendees = widget.event.attendees ?? [];
    final attendee = attendees.cast<Map<String, dynamic>?>().firstWhere(
          (a) =>
              a != null &&
              (a['id'] == appState.userId ||
                  a['id'] == appState.userProfile?.email ||
                  (athleteName.isNotEmpty && a['name'] == athleteName)),
          orElse: () => null,
        );
    return attendee == null ? null : Map<String, dynamic>.from(attendee);
  }

  void _initTrackControllers(Map<String, dynamic> tech) {
    final trackLaps = _attendee?['trackLaps'] is Map
        ? Map<String, dynamic>.from(_attendee!['trackLaps'])
        : <String, dynamic>{};
    final tracks = _eventTracks();
    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      final id = track['id']?.toString() ?? 'track_${i + 1}';
      _trackLapsCtrls[id] = TextEditingController(
        text: (trackLaps[id] ?? _attendee?['laps'] ?? track['laps'] ?? '')
            .toString(),
      );
    }
  }

  void _initTrainingControllers(Map<String, dynamic> tech) {
    final trainingLaps = _attendee?['trainingBlockLaps'] is Map
        ? Map<String, dynamic>.from(_attendee!['trainingBlockLaps'])
        : <String, dynamic>{};
    final blocks = _eventTrainingBlocks();
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final id = block['id']?.toString() ?? 'training_${i + 1}';
      _trainingLapsCtrls[id] = TextEditingController(
        text: (trainingLaps[id] ??
                _attendee?['trainingLaps'] ??
                block['laps'] ??
                '')
            .toString(),
      );
    }
  }

  @override
  void dispose() {
    _freeLapsCtrl.dispose();
    _painCtrl.dispose();
    _chronoCtrl.dispose();
    _notesCtrl.dispose();
    for (final controller in _trackLapsCtrls.values) {
      controller.dispose();
    }
    for (final controller in _trainingLapsCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _canEditPersonal
              ? 'Personalizza allenamento'
              : 'Dettaglio Allenamento',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _eventInfoCard(),
          const SizedBox(height: 16),
          if (_isCancelled)
            _noticeCard(
              icon: Icons.cancel_outlined,
              color: AppTheme.error,
              title: 'Allenamento annullato',
              body: 'Questo allenamento non genera statistiche.',
            )
          else if (_isPlanned)
            _rsvpCard()
          else if (_canEditPersonal) ...[
            _summaryCard(),
            const SizedBox(height: 16),
            _technicalDetailsCard(),
            const SizedBox(height: 16),
            _conditionsCard(),
            const SizedBox(height: 16),
            _volumeEditorCard(),
            const SizedBox(height: 16),
            _personalEditorCard(),
          ] else if (_canEditDryland) ...[
            _drylandCoachCard(),
          ] else if (_isCompleted)
            _noticeCard(
              icon: Icons.lock_outline,
              color: AppTheme.textMediumEmphasis,
              title: 'Allenamento completato',
              body:
                  'Puoi modificare i dati personali solo se risulti presente.',
            ),
        ],
      ),
      bottomNavigationBar: _canEditPersonal
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePersonalData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Salva modifiche',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _eventInfoCard() {
    final specialty = CoachTrainingUtils.eventSpecialty(widget.event);
    final modified = _attendee?['modifiedByAthlete'] == true;
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
                  'Allenamento coach',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _statusBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _compactBadge('Creato dal coach', AppTheme.secondary),
              if (modified) _compactBadge('Modificato da te', AppTheme.success),
            ],
          ),
          const SizedBox(height: 18),
          _detailRow(Icons.downhill_skiing, 'Specialita', specialty),
          _detailRow(Icons.calendar_today_outlined, 'Data', widget.event.date),
          _detailRow(
            Icons.access_time,
            'Orario',
            '${widget.event.startTime} - ${widget.event.endTime}',
          ),
          _detailRow(Icons.timer_outlined, 'Durata', _durationLabel()),
          _detailRow(
            Icons.location_on_outlined,
            'Luogo',
            widget.event.location ?? '',
          ),
          if ((widget.event.notes ?? '').isNotEmpty)
            _detailRow(Icons.notes, 'Note coach', widget.event.notes ?? ''),
        ],
      ),
    );
  }

  Widget _rsvpCard() {
    final status = _attendee == null
        ? CoachTrainingUtils.attendancePending
        : CoachTrainingUtils.attendeeStatus(_attendee!);
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conferma presenza',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _rsvpButton(
                  label: 'Presente',
                  selected: status == CoachTrainingUtils.attendancePresent,
                  color: AppTheme.success,
                  onTap: () => _handleRSVP(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _rsvpButton(
                  label: 'Assente',
                  selected: status == CoachTrainingUtils.attendanceAbsent,
                  color: AppTheme.error,
                  onTap: () => _handleRSVP(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final summary = CoachTrainingUtils.volumeFromEventAttendee(
      widget.event,
      _currentAttendeeDraft(),
    );
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riepilogo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _summaryLine('Campo libero',
              '${summary.freeLaps} giri · ${summary.freeDirectionChanges} cambi'),
          _summaryLine('Pali',
              '${summary.poleLaps} giri · ${summary.polePasses} passaggi'),
          _summaryLine('Addestramento',
              '${summary.trainingLaps} giri · ${summary.trainingDirectionChanges} cambi'),
        ],
      ),
    );
  }

  Widget _drylandCoachCard() {
    final session = _drylandInitialSession();
    final activity = TrainingActivity.fromTrainingSession(
      session,
      title: widget.event.title,
    );
    final strength = TrainingMetricsUtils.strengthSummary([activity]);
    final plyo = TrainingMetricsUtils.plyometricSummary([activity]);
    final speed = TrainingMetricsUtils.speedAgilitySummary([activity]);
    final endurance = TrainingMetricsUtils.enduranceSummary([activity]);
    final modified = _attendee?['modifiedByAthlete'] == true ||
        _attendee?['actualDrylandDetails'] != null;

    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center, color: AppTheme.secondary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Scheda atletica',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (modified) _compactBadge('Modificata', AppTheme.success),
            ],
          ),
          const SizedBox(height: 14),
          _plainRow('Categoria', _drylandCategoryLabel(activity.category)),
          _plainRow('Blocchi', activity.blocks.length.toString()),
          if (strength.totalSets > 0)
            _plainRow(
              'Forza',
              '${strength.totalSets} serie · ${strength.volumeKg.round()} kg',
            ),
          if (plyo.totalContacts > 0)
            _plainRow(
              'Pliometria',
              '${plyo.totalContacts} contatti · ${plyo.totalSets} serie',
            ),
          if (speed.drillCount > 0)
            _plainRow(
              'Velocita/agilita',
              '${speed.drillCount} drill · ${speed.totalSets} serie',
            ),
          if (endurance.durationSeconds > 0 || endurance.distanceKm > 0)
            _plainRow(
              'Resistenza',
              '${(endurance.durationSeconds / 60).round()} min · ${endurance.distanceKm.toStringAsFixed(1)} km',
            ),
          if ((widget.event.notes ?? '').trim().isNotEmpty)
            _plainRow('Note coach', widget.event.notes!.trim()),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openDrylandEditor,
              icon: const Icon(Icons.edit_note),
              label: const Text('Personalizza scheda'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _technicalDetailsCard() {
    final details = CoachTrainingUtils.buildSessionDetailsForAttendee(
      widget.event,
      _currentAttendeeDraft(),
    );
    final free = CoachTrainingUtils.freeSkiingFromDetails(details);
    final tracks = CoachTrainingUtils.tracksFromDetails(details);
    final trainingBlocks =
        CoachTrainingUtils.trainingBlocksFromDetails(details);
    final chrono = CoachTrainingUtils.chronoFromDetails(details);

    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dettagli tecnici',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (free.isNotEmpty)
            _technicalBlock(
              'Campo libero',
              [
                '${CoachTrainingUtils.asNonNegativeInt(free['laps'])} giri',
                '${CoachTrainingUtils.asNonNegativeInt(free['changes'])} cambi/giro',
                '${CoachTrainingUtils.asNonNegativeInt(free['laps']) * CoachTrainingUtils.asNonNegativeInt(free['changes'])} cambi totali',
              ],
            ),
          for (var i = 0; i < tracks.length; i++)
            _technicalBlock(
              'Pali / Tracciato ${i + 1}',
              [
                '${CoachTrainingUtils.asNonNegativeInt(tracks[i]['laps'])} giri',
                '${_trackGates(tracks[i])} porte/giro',
                '${CoachTrainingUtils.asNonNegativeInt(tracks[i]['laps']) * _trackGates(tracks[i])} passaggi',
              ],
            ),
          for (final block in trainingBlocks)
            _technicalBlock(
              'Addestramento',
              [
                '${CoachTrainingUtils.asNonNegativeInt(block['laps'])} giri',
                '${_blockReferences(block)} riferimenti/giro',
                '${CoachTrainingUtils.asNonNegativeInt(block['laps']) * _blockReferences(block)} cambi',
              ],
            ),
          if (chrono['enabled'] == true || _chronoCtrl.text.trim().isNotEmpty)
            _technicalBlock(
              'Crono',
              [
                _chronoCtrl.text.trim().isEmpty
                    ? 'Nessun crono inserito'
                    : _chronoCtrl.text.trim(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _conditionsCard() {
    final tech = widget.event.technicalDetails ?? {};
    final snow = tech['snowCondition']?.toString();
    final weather = tech['weatherCondition']?.toString();
    final quality = tech['qualityRating'];
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Condizioni',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _plainRow('Neve', snow?.isEmpty == false ? snow! : 'Non inserita'),
          _plainRow(
              'Meteo', weather?.isEmpty == false ? weather! : 'Non inserito'),
          _plainRow(
            'Qualita',
            quality == null
                ? 'Non inserita'
                : '${CoachTrainingUtils.asNonNegativeInt(quality)}/5',
          ),
        ],
      ),
    );
  }

  Widget _volumeEditorCard() {
    final tech = widget.event.technicalDetails ?? {};
    final free = CoachTrainingUtils.freeSkiingFromDetails(tech);
    final tracks = _eventTracks();
    final trainingBlocks = _eventTrainingBlocks();

    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Volume svolto',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Puoi modificare solo i giri fatti. I valori per giro restano quelli del coach.',
            style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (free.isNotEmpty)
            _volumeBlock(
              title: 'Campo libero',
              controller: _freeLapsCtrl,
              readOnlyLabel: 'Cambi/giro',
              readOnlyValue:
                  CoachTrainingUtils.asNonNegativeInt(free['changes']),
              totalLabel: 'Cambi totali',
              totalValue:
                  CoachTrainingUtils.asNonNegativeInt(_freeLapsCtrl.text) *
                      CoachTrainingUtils.asNonNegativeInt(free['changes']),
            ),
          for (var i = 0; i < tracks.length; i++)
            _volumeBlock(
              title: 'Pali / Tracciato ${i + 1}',
              controller: _trackLapsCtrls[
                  tracks[i]['id']?.toString() ?? 'track_${i + 1}']!,
              readOnlyLabel: 'Porte/giro',
              readOnlyValue: _trackGates(tracks[i]),
              totalLabel: 'Passaggi',
              totalValue: CoachTrainingUtils.asNonNegativeInt(
                    _trackLapsCtrls[
                            tracks[i]['id']?.toString() ?? 'track_${i + 1}']!
                        .text,
                  ) *
                  _trackGates(tracks[i]),
            ),
          for (var i = 0; i < trainingBlocks.length; i++)
            _volumeBlock(
              title: 'Addestramento',
              controller: _trainingLapsCtrls[
                  trainingBlocks[i]['id']?.toString() ?? 'training_${i + 1}']!,
              readOnlyLabel: 'Riferimenti/giro',
              readOnlyValue: _blockReferences(trainingBlocks[i]),
              totalLabel: 'Cambi addestramento',
              totalValue: CoachTrainingUtils.asNonNegativeInt(
                    _trainingLapsCtrls[trainingBlocks[i]['id']?.toString() ??
                            'training_${i + 1}']!
                        .text,
                  ) *
                  _blockReferences(trainingBlocks[i]),
            ),
        ],
      ),
    );
  }

  Widget _personalEditorCard() {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dati personali',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          _rpeSlider(),
          const SizedBox(height: 12),
          _painSelector(),
          if (widget.event.technicalDetails?['chrono']?['enabled'] == true)
            _textInput('Crono', _chronoCtrl),
          _textInput('Note personali', _notesCtrl, maxLines: 3),
        ],
      ),
    );
  }

  Widget _volumeBlock({
    required String title,
    required TextEditingController controller,
    required String readOnlyLabel,
    required int readOnlyValue,
    required String totalLabel,
    required int totalValue,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _numberInput('Giri fatti', controller),
          _plainRow(readOnlyLabel, readOnlyValue.toString()),
          _plainRow(totalLabel, totalValue.toString()),
        ],
      ),
    );
  }

  Widget _rpeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'RPE',
                style: TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '$_rpeValue/10',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          min: 0,
          max: 10,
          divisions: 10,
          value: _rpeValue.toDouble(),
          activeColor: AppTheme.primary,
          inactiveColor: Colors.white.withValues(alpha: 0.12),
          label: _rpeValue.toString(),
          onChanged: (value) => setState(() => _rpeValue = value.round()),
        ),
      ],
    );
  }

  Widget _painSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DOLORE',
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _painOptions.map((option) {
              final selected = _painSelection == option;
              return ChoiceChip(
                label: Text(option),
                selected: selected,
                selectedColor: AppTheme.primary.withValues(alpha: 0.22),
                backgroundColor: AppTheme.background,
                labelStyle: TextStyle(
                  color: selected ? AppTheme.primary : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                side: BorderSide(
                  color: selected
                      ? AppTheme.primary
                      : Colors.white.withValues(alpha: 0.08),
                ),
                onSelected: (_) {
                  setState(() {
                    _painSelection = option;
                    if (option != 'Altro') _painCtrl.clear();
                  });
                },
              );
            }).toList(),
          ),
          if (_painSelection == 'Altro') ...[
            const SizedBox(height: 10),
            _textInput('Dettaglio dolore', _painCtrl),
          ],
        ],
      ),
    );
  }

  Widget _noticeCard({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      borderColor: color.withValues(alpha: 0.35),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppTheme.textMediumEmphasis,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textMediumEmphasis,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plainRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String title, String value) {
    return _plainRow(title, value);
  }

  Widget _technicalBlock(String title, List<String> rows) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                row,
                style: const TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    late final String label;
    late final Color color;
    if (_isCancelled) {
      label = 'Annullato';
      color = AppTheme.error;
    } else if (_isCompleted) {
      label = 'Completato';
      color = AppTheme.success;
    } else {
      label = 'Pianificato';
      color = AppTheme.primary;
    }
    return _compactBadge(label, color);
  }

  Widget _compactBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _rsvpButton({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textInput(
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
            style: const TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
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

  List<Map<String, dynamic>> _eventTracks() {
    final tech = widget.event.technicalDetails ?? {};
    final tracks = CoachTrainingUtils.tracksFromDetails(tech);
    if (tracks.isNotEmpty) return tracks;
    final gated = tech['gatedSkiing'];
    if (gated is Map) {
      return [
        {
          'id': 'track_1',
          'laps': gated['laps'],
          'gates': gated['gates'] ?? gated['changes'],
        }
      ];
    }
    return [];
  }

  List<Map<String, dynamic>> _eventTrainingBlocks() {
    return CoachTrainingUtils.trainingBlocksFromDetails(
      widget.event.technicalDetails,
    );
  }

  int _trackGates(Map<String, dynamic> track) {
    return CoachTrainingUtils.asNonNegativeInt(
      track['gates'],
      fallback: CoachTrainingUtils.asNonNegativeInt(track['changes']),
    );
  }

  int _blockReferences(Map<String, dynamic> block) {
    return CoachTrainingUtils.asNonNegativeInt(
      block['references'],
      fallback: CoachTrainingUtils.asNonNegativeInt(block['changes']),
    );
  }

  String _painValueForSave() {
    if (_painSelection == 'Altro') {
      final custom = _painCtrl.text.trim();
      return custom.isEmpty ? 'Altro' : custom;
    }
    return _painSelection;
  }

  TrainingSession _drylandInitialSession() {
    final appState = Provider.of<AppState>(context, listen: false);
    final existing = appState.sessions.cast<TrainingSession?>().firstWhere(
          (session) =>
              session != null &&
              session.eventId == widget.event.id &&
              session.sportId != 'alpine_skiing',
          orElse: () => null,
        );
    if (existing != null) return existing;

    final attendee = {
      ...?_attendee,
      'rpe': _rpeValue,
      'pain': _painValueForSave(),
      'athleteNotes': _notesCtrl.text.trim(),
    };
    final details = const TrainingActivityService()
        .buildCoachDrylandSessionDetails(widget.event, attendee);
    return TrainingSession(
      id: 'new_session',
      sportId: _drylandSportId(),
      date: widget.event.date,
      startTime: widget.event.startTime,
      endTime: widget.event.endTime,
      duration: _durationMinutes().toString(),
      effort: _rpeValue == 0 ? 5 : _rpeValue,
      eventId: widget.event.id,
      details: details,
    );
  }

  String _drylandSportId() {
    final specialty = widget.event.drylandSpecialty?.trim();
    if (specialty == null || specialty.isEmpty) return 'dryland';
    return 'dryland_${specialty.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
  }

  String _drylandCategoryLabel(String category) {
    switch (category) {
      case ActivityCategory.strength:
        return 'Forza';
      case ActivityCategory.plyometrics:
        return 'Pliometria';
      case ActivityCategory.speedAgility:
        return 'Velocita/agilita';
      case ActivityCategory.endurance:
        return 'Resistenza';
      case ActivityCategory.mobility:
        return 'Mobilita';
      case ActivityCategory.core:
        return 'Core';
      case ActivityCategory.circuit:
        return 'Circuito';
      case ActivityCategory.sport:
        return 'Sport';
      case ActivityCategory.test:
        return 'Test';
      default:
        return 'Altro';
    }
  }

  int _durationMinutes() {
    final start = _parseClock(widget.event.startTime);
    final end = _parseClock(widget.event.endTime);
    if (start == null || end == null) return 60;
    var minutes = end - start;
    if (minutes <= 0) minutes += 24 * 60;
    return minutes;
  }

  Future<void> _openDrylandEditor() async {
    final session = _drylandInitialSession();
    final category = session.details?['activityCategory']?.toString() ??
        ActivityCategory.other;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrylandActivityScreen(
          category: category,
          title: widget.event.title,
          initialSession: session,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _attendee = _findCurrentAttendee();
    });
  }

  Map<String, dynamic> _currentAttendeeDraft() {
    final trackLaps = {
      for (final entry in _trackLapsCtrls.entries)
        entry.key: CoachTrainingUtils.asNonNegativeInt(entry.value.text),
    };
    final trainingBlockLaps = {
      for (final entry in _trainingLapsCtrls.entries)
        entry.key: CoachTrainingUtils.asNonNegativeInt(entry.value.text),
    };
    return {
      ...?_attendee,
      'attendanceStatus': CoachTrainingUtils.attendancePresent,
      'isPresent': true,
      'freeLaps': CoachTrainingUtils.asNonNegativeInt(_freeLapsCtrl.text),
      if (trackLaps.isNotEmpty) 'trackLaps': trackLaps,
      if (trackLaps.isNotEmpty) 'laps': trackLaps.values.first,
      if (trainingBlockLaps.isNotEmpty) 'trainingBlockLaps': trainingBlockLaps,
      if (trainingBlockLaps.isNotEmpty)
        'trainingLaps': trainingBlockLaps.values.first,
      'rpe': _rpeValue,
      'pain': _painValueForSave(),
      'chronoNotes': _chronoCtrl.text.trim(),
      'athleteNotes': _notesCtrl.text.trim(),
    };
  }

  String _durationLabel() {
    final start = _parseClock(widget.event.startTime);
    final end = _parseClock(widget.event.endTime);
    if (start == null || end == null) return '';
    var minutes = end - start;
    if (minutes < 0) minutes += 24 * 60;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h 00m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  int? _parseClock(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  Future<void> _handleRSVP(bool isPresent) async {
    setState(() => _isLoading = true);
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.updateAthleteAttendance(widget.event, isPresent);
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(isPresent ? 'Presenza confermata.' : 'Assenza registrata.'),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _savePersonalData() async {
    setState(() => _isLoading = true);
    final appState = Provider.of<AppState>(context, listen: false);
    final trackLaps = {
      for (final entry in _trackLapsCtrls.entries)
        entry.key: CoachTrainingUtils.asNonNegativeInt(entry.value.text),
    };
    final trainingBlockLaps = {
      for (final entry in _trainingLapsCtrls.entries)
        entry.key: CoachTrainingUtils.asNonNegativeInt(entry.value.text),
    };
    await appState.updateAthleteEventDetails(
      widget.event,
      freeLaps: CoachTrainingUtils.asNonNegativeInt(_freeLapsCtrl.text),
      laps: trackLaps.isEmpty ? null : trackLaps.values.first,
      trackLaps: trackLaps.isEmpty ? null : trackLaps,
      trainingLaps:
          trainingBlockLaps.isEmpty ? null : trainingBlockLaps.values.first,
      trainingBlockLaps: trainingBlockLaps.isEmpty ? null : trainingBlockLaps,
      rpe: _rpeValue,
      pain: _painValueForSave(),
      chronoNotes: _chronoCtrl.text.trim(),
      athleteNotes: _notesCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Modifiche salvate.')),
    );
    Navigator.pop(context);
  }
}
