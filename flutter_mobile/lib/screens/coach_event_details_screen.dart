import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_select.dart';

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
    this.isSkiWorkout = true
  });

  @override
  State<CoachEventDetailsScreen> createState() =>
      _CoachEventDetailsScreenState();
}

class _CoachEventDetailsScreenState extends State<CoachEventDetailsScreen>
    with SingleTickerProviderStateMixin {
  int _eventType = 0; // 0 for Training, 1 for Race
  String _searchQuery = '';
  String _selectedSpecialty = 'SL';
  String _sportCategory = 'ski'; // 'ski' or 'dryland'
  late TextEditingController _drylandSpecialtyCtrl;

  final List<String> _weatherOptions = [
    'Sereno',
    'Nuvoloso',
    'Nebbia',
    'Neve',
    'Pioggia'
  ];
  final List<String> _snowOptions = [
    'Ghiacciata',
    'Neve molle',
    'Grumi',
    'Primaverile',
    'Bagnata',
    'Artificiale'
  ];

  // State for interactive Athletes list
  List<Map<String, dynamic>> _athletes = [];
  bool _isLoadingAthletes = false;
  List<Team> _selectedTeams = [];

  // Text Controllers
  late TextEditingController _titleCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  late TextEditingController _locationCtrl;

  late TextEditingController _snowCtrl;
  late TextEditingController _weatherCtrl;

  late TextEditingController _freeCambiCtrl;
  late TextEditingController _freeGiriCtrl;

  late TextEditingController _paliPorteCtrl;
  late TextEditingController _paliGiriCtrl;

  void _loadEventAttendeesOnly() {
    final e = widget.event;
    if (e != null && e.attendees != null) {
      setState(() {
        _athletes = e.attendees!.map((a) => {
          'id': a['id'],
          'name': a['name'] ?? 'Atleta',
          'selected': a['isPresent'] ?? false,
          'laps': a['laps'] ?? 6,
        }).toList();
      });
    } else {
      setState(() {
        _athletes = [];
      });
    }
  }

  Future<void> _fetchAthletesForTeams(List<String> teamIds) async {
    setState(() {
      _isLoadingAthletes = true;
    });
    try {
      final supabase = Supabase.instance.client;
      final e = widget.event;
      final List<Map<String, dynamic>> loadedAthletes = [];

      for (var teamId in teamIds) {
        final data = await supabase
            .from('profiles')
            .select()
            .eq('team_id', teamId)
            .eq('role', 'athlete');

        for (var row in data) {
          final String athleteId = row['id'];
          if (loadedAthletes.any((a) => a['id'] == athleteId)) continue;
          
          final existing = _athletes.cast<Map<String,dynamic>?>().firstWhere((a) => a != null && a['id'] == athleteId, orElse: () => null);

          final String firstName = row['first_name'] ?? '';
          final String lastName = row['last_name'] ?? '';
          final String fullName = '$firstName $lastName'.trim();
          final String nameToShow = fullName.isNotEmpty ? fullName : (row['email'] ?? 'Atleta');

          if (existing != null) {
            loadedAthletes.add(existing);
          } else {
            Map<String, dynamic>? attendee;
            if (e != null && e.attendees != null) {
              try {
                attendee = e.attendees!.firstWhere((a) => a['id'] == athleteId || a['name'] == nameToShow);
              } catch (_) {
                attendee = null;
              }
            }

            loadedAthletes.add({
              'id': athleteId,
              'name': nameToShow,
              'selected': attendee != null ? (attendee['isPresent'] ?? false) : false,
              'laps': attendee != null ? (attendee['laps'] ?? 6) : 6,
            });
          }
        }
      }

      // Append any attendees from the event that are not in the team
      if (e != null && e.attendees != null) {
        for (var a in e.attendees!) {
          if (!loadedAthletes.any((la) => la['id'] == a['id'] || la['name'] == a['name'])) {
            loadedAthletes.add({
              'id': a['id'],
              'name': a['name'] ?? 'Atleta',
              'selected': a['isPresent'] ?? false,
              'laps': a['laps'] ?? 6,
            });
          }
        }
      }

      setState(() {
        _athletes = loadedAthletes;
        _isLoadingAthletes = false;
      });
    } catch (err) {
      debugPrint('Error fetching athletes: $err');
      setState(() {
        _isLoadingAthletes = false;
      });
      _loadEventAttendeesOnly();
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize properties from event or use defaults
    final e = widget.event;
    final t = widget.selectedTeam;
    _eventType = e?.type == 'race' ? 1 : 0;
    _sportCategory = e?.sportCategory ?? (widget.isSkiWorkout ? 'ski' : 'dryland');
    
    _titleCtrl =
        TextEditingController(text: e?.title ?? 'Allenamento');
    String dateValue = e?.date ?? (widget.initialDate?.toIso8601String().split('T').first ?? DateTime.now().toIso8601String().split('T').first);
    _dateCtrl = TextEditingController(text: dateValue);
    _startCtrl = TextEditingController(text: e?.startTime ?? '09:00');
    _endCtrl = TextEditingController(text: e?.endTime ?? '12:00');
    _locationCtrl = TextEditingController(text: e?.location ?? 'Pista/Palestra');
    _drylandSpecialtyCtrl = TextEditingController(text: e?.drylandSpecialty ?? '');

    var tech = e?.technicalDetails ?? {};
    _snowCtrl =
        TextEditingController(text: tech['snowCondition'] ?? 'Compatta/Dura');
    _weatherCtrl =
        TextEditingController(text: tech['weatherCondition'] ?? 'Sole');
    if (tech['specialties'] != null &&
        (tech['specialties'] as List).isNotEmpty) {
      _selectedSpecialty = tech['specialties'][0];
    }

    _freeGiriCtrl =
        TextEditingController(text: tech['freeSkiing']?['laps'] ?? '4');
    _freeCambiCtrl =
        TextEditingController(text: tech['freeSkiing']?['changes'] ?? '12');

    _paliGiriCtrl =
        TextEditingController(text: tech['gatedSkiing']?['laps'] ?? '6');
    _paliPorteCtrl =
        TextEditingController(text: tech['gatedSkiing']?['changes'] ?? '45');

    // Retrieve active appState
    final appState = Provider.of<AppState>(context, listen: false);

    // Determine the active team(s)
    if (t != null) {
      _selectedTeams = [t];
    } else if (e != null) {
      final ids = e.teamId.split(',');
      for (var id in ids) {
        try {
          final matchedTeam = appState.teams.firstWhere((team) => team.id == id.trim());
          if (!_selectedTeams.any((team) => team.id == matchedTeam.id)) {
            _selectedTeams.add(matchedTeam);
          }
        } catch (_) {}
      }
      if (_selectedTeams.isEmpty && appState.teams.isNotEmpty) {
        _selectedTeams = [appState.teams.first];
      }
    } else {
      if (appState.teams.isNotEmpty) {
        _selectedTeams = [appState.teams.first];
      }
    }

    // Fetch team athletes or fallback to event attendees
    if (_selectedTeams.isNotEmpty) {
      _fetchAthletesForTeams(_selectedTeams.map((t) => t.id).toList());
    } else {
      _loadEventAttendeesOnly();
    }
  }

  @override
  void dispose() {
    _drylandSpecialtyCtrl.dispose();
    _titleCtrl.dispose();
    _dateCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _locationCtrl.dispose();
    _snowCtrl.dispose();
    _weatherCtrl.dispose();
    _freeCambiCtrl.dispose();
    _freeGiriCtrl.dispose();
    _paliPorteCtrl.dispose();
    _paliGiriCtrl.dispose();
    super.dispose();
  }

  void _toggleAthlete(int index) {
    setState(() {
      _athletes[index]['selected'] = !_athletes[index]['selected'];
    });
  }

  void _toggleAll() {
    bool allSelected = _athletes.every((a) => a['selected']);
    setState(() {
      for (var a in _athletes) {
        a['selected'] = !allSelected;
      }
    });
  }

  void _saveEvent() {
    // Generate new event object
    final event = CalendarEvent(
      id: widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      teamId: _selectedTeams.isNotEmpty ? _selectedTeams.map((t) => t.id).join(',') : 't1',
      type: _eventType == 0 ? 'training' : 'race',
      title: _titleCtrl.text,
      date: _dateCtrl.text,
      startTime: _startCtrl.text,
      endTime: _endCtrl.text,
      location: _locationCtrl.text,
      sportCategory: _sportCategory,
      drylandSpecialty: _drylandSpecialtyCtrl.text,
      technicalDetails: {
        'snowCondition': _snowCtrl.text,
        'weatherCondition': _weatherCtrl.text,
        'specialties': [_selectedSpecialty],
        'freeSkiing': {
          'laps': _freeGiriCtrl.text,
          'changes': _freeCambiCtrl.text
        },
        'gatedSkiing': {
          'laps': _paliGiriCtrl.text,
          'changes': _paliPorteCtrl.text
        }
      },
      attendees: _athletes.where((a) => a['selected'] == true).map((a) {
        return {
          'id': a['id'] ?? a['name'],
          'name': a['name'],
          'isPresent': true,
          'laps': a['laps']
        };
      }).toList(),
    );

    // Save using provider
    Provider.of<AppState>(context, listen: false).saveCoachEvent(event);

    // Show success & leave
    final eventDate = DateTime.tryParse(event.date);
    final isFuture = eventDate != null && eventDate.isAfter(DateTime.now());

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isFuture
          ? 'Modifiche salvate e convocazioni inviate agli atleti!'
          : 'Modifiche salvate e sincronizzate con il team!'),
      backgroundColor: AppTheme.primary,
    ));
    Navigator.pop(context);
  }

  void _showOptionsPicker(
      String title, List<String> options, TextEditingController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: options.map((opt) {
                  bool isSelected = controller.text == opt;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        controller.text = opt;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppTheme.primary : AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : Colors.white.withOpacity(0.05)),
                      ),
                      child: Text(opt,
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textMediumEmphasis,
                              fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showLapsPicker(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('SELEZIONA GIRI',
                  style: TextStyle(
                      color: AppTheme.textMediumEmphasis,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Text(_athletes[index]['name'],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(15, (i) {
                  int val = i + 1;
                  bool isCurrent = _athletes[index]['laps'] == val;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _athletes[index]['laps'] = val;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color:
                            isCurrent ? AppTheme.primary : AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isCurrent
                                ? AppTheme.primary
                                : Colors.white.withOpacity(0.05)),
                      ),
                      child: Center(
                        child: Text('$val',
                            style: TextStyle(
                                color: isCurrent
                                    ? Colors.white
                                    : AppTheme.textMediumEmphasis,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  bool get _isPast {
    final eventDate = DateTime.tryParse(_dateCtrl.text) ?? DateTime.now();
    final today = DateTime.now();
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return eventDay.isBefore(todayDay);
  }

  bool get _isSki => _sportCategory == 'ski';
  bool get _showTech => _isSki && _isPast;

  @override
  Widget build(BuildContext context) {
    final numTabs = _showTech ? 3 : 2;
    return DefaultTabController(
      length: numTabs,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                  color: AppTheme.card, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _isPast ? 'Verifica Evento' : 'Programmazione Evento',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
          ),
          centerTitle: true,
          actions: [
            if (widget.event != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.card,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Elimina Evento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      content: const Text('Sei sicuro di voler eliminare questo evento?', style: TextStyle(color: AppTheme.textMediumEmphasis)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Annulla', style: TextStyle(color: AppTheme.textMediumEmphasis)),
                        ),
                        TextButton(
                          onPressed: () {
                            Provider.of<AppState>(context, listen: false).deleteCoachEvent(widget.event!.id);
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Evento eliminato'),
                              backgroundColor: AppTheme.primary,
                            ));
                          },
                          child: const Text('Elimina', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
          bottom: TabBar(
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textMediumEmphasis,
            tabs: [
              const Tab(icon: Icon(Icons.info_outline), text: 'INFO'),
              if (_showTech) const Tab(icon: Icon(Icons.show_chart), text: 'TECNICA'),
              const Tab(icon: Icon(Icons.people_outline), text: 'ATLETI'),
            ],
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard
          child: TabBarView(
            children: [
              _buildInfoTab(),
              if (_showTech) _buildTechnicalTab(),
              _buildAthletesTab(),
            ],
          ),
        ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: _saveEvent,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 20),
                SizedBox(width: 8),
                Text('Salva Modifiche',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_sportCategory == 'ski') ...[
          Container(
            decoration: BoxDecoration(
                color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _eventType = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _eventType == 0
                            ? AppTheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.show_chart,
                              color: _eventType == 0
                                  ? Colors.white
                                  : AppTheme.textMediumEmphasis,
                              size: 18),
                          const SizedBox(width: 8),
                          Text('Training',
                              style: TextStyle(
                                  color: _eventType == 0
                                      ? Colors.white
                                      : AppTheme.textMediumEmphasis,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _eventType = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _eventType == 1
                            ? const Color(0xFFFF7A00)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events_outlined,
                              color: _eventType == 1
                                  ? Colors.white
                                  : AppTheme.textMediumEmphasis,
                              size: 18),
                          const SizedBox(width: 8),
                          Text('Race',
                              style: TextStyle(
                                  color: _eventType == 1
                                      ? Colors.white
                                      : AppTheme.textMediumEmphasis,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (_sportCategory == 'ski') ...[
          const Text('SPECIALITÀ',
              style: TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Row(
            children: ['SL', 'GS', 'SG', 'DH'].map((s) {
              bool isSelected = _selectedSpecialty == s;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedSpecialty = s),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : Colors.white.withOpacity(0.05)),
                    ),
                    child: Center(
                        child: Text(s,
                            style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textMediumEmphasis,
                                fontWeight: FontWeight.bold))),
                  ),
                ),
              );
            }).toList(),
          ),
        ] else ...[
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final selectedSport = await Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const ActivitySelectScreen(isPicker: true))
              );
              if (selectedSport != null && selectedSport is SportActivity) {
                setState(() {
                  _drylandSpecialtyCtrl.text = selectedSport.name;
                });
              }
            },
            child: AbsorbPointer(
              child: _buildEditableInput('TIPO DI ALLENAMENTO', _drylandSpecialtyCtrl, Icons.arrow_drop_down)
            ),
          ),
        ],
        const SizedBox(height: 32),
        _buildEditableInput('TITOLO', _titleCtrl),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
                flex: 2,
                child: _buildEditableInput(
                    'DATA', _dateCtrl, Icons.calendar_today_outlined)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildEditableInput(
                    'ORARIO', _startCtrl, Icons.access_time)),
            const SizedBox(width: 16),
            Expanded(
                child:
                    _buildEditableInput('', _endCtrl, Icons.access_time, true)),
          ],
        ),
        const SizedBox(height: 24),
        _buildEditableInput('LUOGO', _locationCtrl),
      ],
    );
  }

  Widget _buildTechnicalTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    _showOptionsPicker('NEVE', _snowOptions, _snowCtrl),
                child: AbsorbPointer(
                    child: _buildEditableInput(
                        'NEVE', _snowCtrl, Icons.arrow_drop_down)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    _showOptionsPicker('METEO', _weatherOptions, _weatherCtrl),
                child: AbsorbPointer(
                    child: _buildEditableInput(
                        'METEO', _weatherCtrl, Icons.arrow_drop_down)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildTechnicalSection('CAMPO LIBERO', Colors.green, _freeGiriCtrl,
            'CAMBI/GIRO', _freeCambiCtrl, Icons.show_chart),
        const SizedBox(height: 24),
        _buildTechnicalSection('PALI (TRACCIATO)', AppTheme.primary,
            _paliGiriCtrl, 'PORTE/GIRO', _paliPorteCtrl, Icons.bolt),
      ],
    );
  }

  Widget _buildTechnicalSection(
      String title,
      Color accentColor,
      TextEditingController giriCtrl,
      String metricLabel,
      TextEditingController metricCtrl,
      IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSmallEditable('GIRI', giriCtrl),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildSmallEditable(metricLabel, metricCtrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallEditable(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            decoration: const InputDecoration(
                border: InputBorder.none, contentPadding: EdgeInsets.zero),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableInput(String label, TextEditingController controller,
      [IconData? suffixIcon, bool hideLabel = false]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideLabel) ...[
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
        ] else ...[
          const SizedBox(height: 23), // alignment placeholder
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 54, // Fixed height for consistency
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Center(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                suffixIcon: suffixIcon != null
                    ? Icon(suffixIcon,
                        color: AppTheme.textMediumEmphasis, size: 18)
                    : null,
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAthletesTab() {
    final appState = Provider.of<AppState>(context, listen: false);
    final availableTeams = appState.teams;

    if (_isLoadingAthletes) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    final filteredAthletes = _athletes
        .where(
            (a) => a['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    bool allSelected = filteredAthletes.isNotEmpty &&
        filteredAthletes.every((a) => a['selected']);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TEAM SELEZIONATI',
                      style: TextStyle(
                          color: AppTheme.textMediumEmphasis,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2)),
                  GestureDetector(
                    onTap: () => _showTeamPicker(availableTeams),
                    child: const Text('Modifica',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_selectedTeams.isEmpty)
                const Text('Nessun team selezionato', style: TextStyle(color: Colors.white))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedTeams.map((t) {
                    return Chip(
                      backgroundColor: AppTheme.background,
                      side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                      label: Text(t.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
                      onDeleted: () {
                        setState(() {
                          _selectedTeams.removeWhere((team) => team.id == t.id);
                        });
                        if (_selectedTeams.isNotEmpty) {
                          _fetchAthletesForTeams(_selectedTeams.map((tm) => tm.id).toList());
                        } else {
                          setState(() {
                            _athletes = [];
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        Container(
          height: 48,
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Cerca atleta...',
              hintStyle: TextStyle(color: AppTheme.textMediumEmphasis),
              prefixIcon:
                  Icon(Icons.search, color: AppTheme.textMediumEmphasis),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _toggleAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(
                    allSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: AppTheme.primary,
                    size: 20),
                const SizedBox(width: 8),
                Text(
                  allSelected ? 'DESELEZIONA TUTTI' : 'SELEZIONA TUTTI',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (filteredAthletes.isEmpty)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Nessun atleta trovato',
                      style: TextStyle(color: AppTheme.textMediumEmphasis))))
        else
          ...filteredAthletes.map((a) {
            int originalIndex = _athletes.indexOf(a);
            return _buildAthleteCheckRow(originalIndex);
          }),
      ],
    );
  }

  void _showTeamPicker(List<Team> teams) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seleziona Team',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: teams.map((team) {
                      bool isSelected = _selectedTeams.any((t) => t.id == team.id);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              _selectedTeams.removeWhere((t) => t.id == team.id);
                            } else {
                              _selectedTeams.add(team);
                            }
                          });
                          setState(() {});
                          if (_selectedTeams.isNotEmpty) {
                            _fetchAthletesForTeams(_selectedTeams.map((t) => t.id).toList());
                          } else {
                            setState(() {
                              _athletes = [];
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? AppTheme.primary : AppTheme.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : Colors.white.withOpacity(0.05)),
                          ),
                          child: Text(team.name,
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textMediumEmphasis,
                                  fontWeight: FontWeight.bold)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Conferma', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAthleteCheckRow(int index) {
    var athlete = _athletes[index];
    bool isSelected = athlete['selected'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected
                  ? AppTheme.primary.withOpacity(0.5)
                  : Colors.white.withOpacity(0.05))),
      child: InkWell(
        onTap: () => _toggleAthlete(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.textMediumEmphasis),
              const SizedBox(width: 16),
              Expanded(
                  child: Text(athlete['name'],
                      style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textMediumEmphasis,
                          fontWeight: FontWeight.bold,
                          fontSize: 16))),
              if (_showTech)
                Row(
                  children: [
                    const Text('GIRI',
                        style: TextStyle(
                            color: AppTheme.textMediumEmphasis,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showLapsPicker(index),
                      child: Container(
                        width: 40,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                            color: AppTheme.background,
                            border:
                                Border.all(color: Colors.white.withOpacity(0.05)),
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(
                            child: Text('${athlete['laps']}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
