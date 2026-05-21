import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import 'coach_event_details_screen.dart';
import 'coach_athlete_detail_screen.dart';
import 'activity_select.dart';
import 'profile_screen.dart';
import 'teams_screen.dart';


class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _CoachHomeView(),
    const _CoachReportView(),
    const _CoachTrainingView(),
    const TeamsScreen(),
    const ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });
  }



  void _showTeamSelectionIfNeeded(BuildContext context, {required bool isSkiWorkout}) {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun team disponibile. Crea o unisciti a un team prima.')),
      );
      return;
    }
    if (appState.teams.length > 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Seleziona Team', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: appState.teams.map((t) => ListTile(
              title: Text(t.name, style: const TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textMediumEmphasis),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(ctx);
                Widget dest = isSkiWorkout 
                    ? CoachEventDetailsScreen(selectedTeam: t) 
                    : const ActivitySelectScreen();
                Navigator.push(context, MaterialPageRoute(builder: (_) => dest));
              }
            )).toList(),
          ),
        ),
      );
    } else {
      final t = appState.teams.first;
      Widget dest = isSkiWorkout 
          ? CoachEventDetailsScreen(selectedTeam: t) 
          : const ActivitySelectScreen();
      Navigator.push(context, MaterialPageRoute(builder: (_) => dest));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.background,
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppTheme.background,
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textMediumEmphasis,
          onTap: _onTabTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.content_paste_outlined),
              activeIcon: Icon(Icons.content_paste),
              label: 'Report',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'Allenamenti',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: 'Team',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profilo',
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          showModalBottomSheet(
            context: context,
            backgroundColor: AppTheme.card,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 24),
                    const Text('Aggiungi al Calendario', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    ListTile(
                      leading: const CircleAvatar(backgroundColor: AppTheme.primary, child: Icon(Icons.ac_unit, color: Colors.white)),
                      title: const Text('Allenamento Sci', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Crea evento in pista (Slalom, Gigante...)', style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12)),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                        _showTeamSelectionIfNeeded(context, isSkiWorkout: true);
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFFFF7A00), child: Icon(Icons.fitness_center, color: Colors.white)),
                      title: const Text('Preparazione Atletica', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Scegli dal database (Forza, Corsa, ecc.)', style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12)),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                        _showTeamSelectionIfNeeded(context, isSkiWorkout: false);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}

// ----------------------------------------------------
// 1. HOME VIEW
// ----------------------------------------------------
class _CoachHomeView extends StatefulWidget {
  const _CoachHomeView();

  @override
  State<_CoachHomeView> createState() => _CoachHomeViewState();
}

class _CoachHomeViewState extends State<_CoachHomeView> {
  bool _isWeekView = true;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  final List<String> _months = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
  ];

  final List<String> _weekDays = ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'];

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    // Filter events for selected day
    final dailyEvents = appState.coachEvents.where((e) {
      final eventDate = DateTime.tryParse(e.date);
      if (eventDate == null) return false;
      return eventDate.year == _selectedDay.year &&
             eventDate.month == _selectedDay.month &&
             eventDate.day == _selectedDay.day;
    }).toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('WELCOME COACH', style: TextStyle(color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                CircleAvatar(backgroundColor: AppTheme.card, child: const Icon(Icons.person_outline, color: Colors.white)),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Calendario', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Container(
                      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _isWeekView = true);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: _isWeekView ? AppTheme.primary : AppTheme.card, borderRadius: BorderRadius.circular(12)),
                              child: Text('Settimana', style: TextStyle(color: _isWeekView ? Colors.white : AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _isWeekView = false);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: !_isWeekView ? AppTheme.primary : AppTheme.card, borderRadius: BorderRadius.circular(12)),
                              child: Text('Mese', style: TextStyle(color: !_isWeekView ? Colors.white : AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.chevron_left, color: AppTheme.textMediumEmphasis),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (_isWeekView) {
                                  _focusedDay = _focusedDay.subtract(const Duration(days: 7));
                                } else {
                                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                                }
                              });
                            },
                          ),
                          Text(
                            '${_months[_focusedDay.month - 1]} ${_focusedDay.year}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.chevron_right, color: AppTheme.textMediumEmphasis),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (_isWeekView) {
                                  _focusedDay = _focusedDay.add(const Duration(days: 7));
                                } else {
                                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _isWeekView ? _buildWeekView(appState) : _buildMonthView(appState),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.calendar_today_outlined, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Programma di Oggi', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(8)),
                      child: Text('${dailyEvents.length} Eventi', style: const TextStyle(color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (dailyEvents.isEmpty)
                  _buildNoEventsPlaceholder()
                else
                  ...dailyEvents.map((e) => _buildEventCard(context, e)).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoEventsPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy, color: AppTheme.textMediumEmphasis.withValues(alpha: 0.5), size: 48),
          const SizedBox(height: 16),
          const Text(
            'Nessun evento in programma',
            style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Usa il tasto + per aggiungere un allenamento',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, CalendarEvent event) {
    final presentCount = event.attendees?.where((a) => a['isPresent'] == true).length ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CoachEventDetailsScreen(event: event)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${event.startTime} - ${event.endTime}', style: const TextStyle(color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Alpine Elite Squad', style: TextStyle(color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const Icon(Icons.chevron_right, color: AppTheme.textMediumEmphasis, size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppTheme.textMediumEmphasis, size: 16),
                      const SizedBox(width: 4),
                      Text(event.location ?? 'No location', style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 13)),
                      const SizedBox(width: 16),
                      const Icon(Icons.people_outline, color: AppTheme.textMediumEmphasis, size: 16),
                      const SizedBox(width: 4),
                      Text('$presentCount Presenti', style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 20,
              bottom: 20,
              width: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView(AppState appState) {
    // Find Monday of the focused week
    final monday = _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final day = monday.add(Duration(days: index));
        final hasEvents = appState.coachEvents.any((e) {
          final eventDate = DateTime.tryParse(e.date);
          return eventDate?.year == day.year && eventDate?.month == day.month && eventDate?.day == day.day;
        });
        return _buildInteractiveDay(_weekDays[index], day, hasEvents: hasEvents);
      }),
    );
  }

  Widget _buildMonthView(AppState appState) {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    
    // Calculate leading empty spaces to align days (starting Monday)
    int leadingDays = firstDayOfMonth.weekday - 1;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _weekDays.map((d) => SizedBox(
            width: 32,
            child: Text(d, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 10, fontWeight: FontWeight.bold))
          )).toList(),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 0.8,
          ),
          itemCount: leadingDays + lastDayOfMonth.day,
          itemBuilder: (context, index) {
            if (index < leadingDays) return const SizedBox.shrink();
            
            final dayNumber = index - leadingDays + 1;
            final date = DateTime(_focusedDay.year, _focusedDay.month, dayNumber);
            
            final hasEvents = appState.coachEvents.any((e) {
              final eventDate = DateTime.tryParse(e.date);
              return eventDate?.year == date.year && eventDate?.month == date.month && eventDate?.day == date.day;
            });

            return _buildInteractiveDay('', date, compact: true, hasEvents: hasEvents);
          },
        ),
      ],
    );
  }

  Widget _buildInteractiveDay(String label, DateTime date, {bool compact = false, bool hasEvents = false}) {
    bool isSelected = date.year == _selectedDay.year &&
                     date.month == _selectedDay.month &&
                     date.day == _selectedDay.day;
    
    bool isToday = date.year == DateTime.now().year &&
                   date.month == DateTime.now().month &&
                   date.day == DateTime.now().day;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedDay = date;
          _focusedDay = date;
        });
      },
      child: Column(
        children: [
          if (label.isNotEmpty) ...[
            Text(label, style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
          ],
          Container(
            width: compact ? 34 : 40,
            height: compact ? 44 : 52,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.primary : (isToday ? AppTheme.primary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date.day.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : (isToday ? AppTheme.primary : Colors.white),
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 14 : 16
                  )
                ),
                if (hasEvents) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 4, 
                    height: 4, 
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : AppTheme.primary, 
                      shape: BoxShape.circle
                    )
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 2. REPORT VIEW
// ----------------------------------------------------
class _CoachReportView extends StatefulWidget {
  const _CoachReportView();

  @override
  State<_CoachReportView> createState() => _CoachReportViewState();
}

class _CoachReportViewState extends State<_CoachReportView> {
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _athletes = [];

  @override
  void initState() {
    super.initState();
    _loadAthletes();
  }

  Future<void> _loadAthletes() async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Carica tutti gli atleti
      final profilesData = await supabase
          .from('profiles')
          .select('id, first_name, last_name, role')
          .eq('role', 'athlete');

      // 2. Carica tutti gli eventi sci (con la lista presenze)
      final eventsData = await supabase
          .from('calendar_events')
          .select('id, attendees');
      final totalSkiEvents = (eventsData as List).length;

      // 3. Carica le sessioni di preparazione atletica (escludendo sci)
      final sessionsData = await supabase
          .from('training_sessions')
          .select('user_id, sport_id, duration')
          .neq('sport_id', 'alpine_skiing');

      if (mounted) {
        setState(() {
          _athletes = (profilesData as List).map((p) {
            final athleteId = p['id'] as String;
            final name = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
            final initial = ((p['first_name'] as String? ?? 'A').isNotEmpty
                ? (p['first_name'] as String)[0]
                : 'A').toUpperCase();

            // Calcola % presenze sci
            int skiPresences = 0;
            for (final event in eventsData) {
              final attendees = event['attendees'] as List? ?? [];
              final found = attendees.any((a) =>
                  a['id'] == athleteId ||
                  a['name'] == name);
              if (found) skiPresences++;
            }
            final presencePercent = totalSkiEvents > 0
                ? (skiPresences / totalSkiEvents * 100).round()
                : 0;

            // Calcola ore di preparazione atletica
            int totalMinutes = 0;
            for (final session in sessionsData as List) {
              if (session['user_id'] == athleteId) {
                final durationStr = session['duration']?.toString() ?? '0';
                totalMinutes += int.tryParse(durationStr) ?? 0;
              }
            }
            final prepHours = (totalMinutes / 60).ceil();

            return {
              'id': athleteId,
              'name': name,
              'initial': initial,
              'presencePercent': presencePercent,
              'prepHours': prepHours,
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          const Text('Report Atleti', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ATLETI TOTALI', style: TextStyle(color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(_athletes.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.people, color: AppTheme.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Cerca atleta...',
                      hintStyle: TextStyle(color: AppTheme.textMediumEmphasis),
                      prefixIcon: Icon(Icons.search, color: AppTheme.textMediumEmphasis),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Row(
            children: const [
              Icon(Icons.people_outline, color: AppTheme.textMediumEmphasis, size: 16),
              SizedBox(width: 8),
              Text('LISTA ATLETI', style: TextStyle(color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          else if (_athletes.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
              child: const Center(
                child: Text('Nessun atleta trovato', style: TextStyle(color: AppTheme.textMediumEmphasis)),
              ),
            )
          else
            ..._buildFilteredAthleteList(),
        ],
      ),
    );
  }

  List<Widget> _buildFilteredAthleteList() {
    var filtered = _athletes.where((a) {
      return a['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return filtered.map((a) {
      return _buildAthleteItem(
        context,
        a['initial'] as String,
        a['name'] as String,
        a['id'] as String,
        a['presencePercent'] as int,
        a['prepHours'] as int,
      );
    }).toList();
  }

  Widget _buildAthleteItem(
    BuildContext context,
    String initial,
    String name,
    String athleteId,
    int presencePercent,
    int prepHours,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => CoachAthleteDetailScreen(
          athleteName: name,
          initial: initial,
          athleteId: athleteId,
        )));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.background,
              radius: 22,
              child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.fitness_center, color: AppTheme.textMediumEmphasis, size: 12),
                      const SizedBox(width: 4),
                      Text('${prepHours}h Extra',
                          style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.textMediumEmphasis.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('$presencePercent% Presenza',
                          style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('${prepHours}h',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppTheme.textMediumEmphasis, size: 20),
          ],
        ),
      ),
    );
  }
}


// ----------------------------------------------------
// 3. TRAINING VIEW (Lista Eventi)
// ----------------------------------------------------
class _CoachTrainingView extends StatelessWidget {
  const _CoachTrainingView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          const Text('Tutti gli Allenamenti', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12)),
                  child: const TextField(
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Cerca per titolo, team...',
                      hintStyle: TextStyle(color: AppTheme.textMediumEmphasis),
                      prefixIcon: Icon(Icons.search, color: AppTheme.textMediumEmphasis),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.tune, color: AppTheme.textMediumEmphasis),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CoachEventDetailsScreen()));
            },
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
                                child: const Text('2026-04-18', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                child: const Text('SL', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                          const Text('COMPLETATO', style: TextStyle(color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Technical Slalom Drills', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.people_outline, color: AppTheme.textMediumEmphasis, size: 16),
                                  const SizedBox(width: 4),
                                  const Text('Alpine Elite Squad', style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, color: AppTheme.textMediumEmphasis, size: 16),
                                  const SizedBox(width: 4),
                                  const Text('Main Slope', style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                            child: const Text('09:00 - 11:00', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 16,
                  bottom: 16,
                  width: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
