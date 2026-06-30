import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../utils/coach_training_utils.dart';
import '../utils/time_utils.dart';
import 'coach_event_details_screen.dart';
import 'coach_athlete_detail_screen.dart';
import 'coach_athletic_test_screen.dart';
import 'profile_screen.dart';
import 'teams_screen.dart';

class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
  int _currentIndex = 0;

  DateTime _selectedDay = DateTime.now();

  List<Widget> get _pages => [
        _CoachHomeView(
          selectedDay: _selectedDay,
          onDaySelected: (day) => setState(() => _selectedDay = day),
          onProfileTap: () => _onTabTapped(4),
        ),
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

  void _showTeamSelectionIfNeeded(BuildContext context,
      {required bool isSkiWorkout}) {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Nessun team disponibile. Crea o unisciti a un team prima.')),
      );
      return;
    }
    if (appState.teams.length > 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Seleziona Team',
              style: TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: appState.teams
                .map((t) => ListTile(
                    title: Text(t.name,
                        style: TextStyle(color: AppTheme.textHighEmphasis)),
                    trailing: Icon(Icons.arrow_forward_ios,
                        size: 16, color: AppTheme.textMediumEmphasis),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                      Widget dest = CoachEventDetailsScreen(
                          selectedTeam: t,
                          initialDate: _selectedDay,
                          isSkiWorkout: isSkiWorkout);
                      Navigator.push(
                          context, MaterialPageRoute(builder: (_) => dest));
                    }))
                .toList(),
          ),
        ),
      );
    } else {
      Widget dest = CoachEventDetailsScreen(
          selectedTeam: appState.teams.first,
          initialDate: _selectedDay,
          isSkiWorkout: isSkiWorkout);
      Navigator.push(context, MaterialPageRoute(builder: (_) => dest));
    }
  }

  void _showTeamSelectionForTest(
      BuildContext context, String testId, String testTitle, String category) {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Nessun team disponibile. Crea o unisciti a un team prima.')),
      );
      return;
    }

    void navigateToTest(Team t) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CoachAthleticTestScreen(
                    selectedTeam: t,
                    testId: testId,
                    testTitle: testTitle,
                    testCategory: category,
                  )));
    }

    if (appState.teams.length > 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Seleziona Team',
              style: TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: appState.teams
                .map((t) => ListTile(
                    title: Text(t.name,
                        style: TextStyle(color: AppTheme.textHighEmphasis)),
                    trailing: Icon(Icons.arrow_forward_ios,
                        size: 16, color: AppTheme.textMediumEmphasis),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                      navigateToTest(t);
                    }))
                .toList(),
          ),
        ),
      );
    } else {
      navigateToTest(appState.teams.first);
    }
  }

  void _showTestSelectionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppTheme.modalHandle,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  Text('Seleziona Test',
                      style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('SALTI',
                              style: TextStyle(
                                  color: AppTheme.textMediumEmphasis,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        _buildTestTile(ctx, 'Squat Jump', 'squat_jump', 'jump'),
                        _buildTestTile(ctx, 'CM Jump', 'cm_jump', 'jump'),
                        _buildTestTile(ctx, 'Drop Jump', 'drop_jump', 'jump'),
                        _buildTestTile(ctx, '45s Jump', '45s_jump', 'jump'),
                        _buildTestTile(ctx, 'Single Leg (Left)',
                            'single_leg_left', 'jump'),
                        _buildTestTile(ctx, 'Single Leg (Right)',
                            'single_leg_right', 'jump'),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('MASSIMALI E FORZA',
                              style: TextStyle(
                                  color: AppTheme.textMediumEmphasis,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        _buildTestTile(ctx, 'Back Squat', 'back_squat', 'pr'),
                        _buildTestTile(ctx, 'Deadlift', 'deadlift', 'pr'),
                        _buildTestTile(ctx, 'Bench Press', 'bp', 'pr'),
                        _buildTestTile(ctx, 'Clean & Jerk', 'clean_jerk', 'pr'),
                        _buildTestTile(
                            ctx, 'Trazioni Massime', 'pullups_max', 'reps'),
                        const SizedBox(height: 16),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('VELOCITÀ E AEROBICO',
                              style: TextStyle(
                                  color: AppTheme.textMediumEmphasis,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        _buildTestTile(
                            ctx, 'Scatto 20 m', 'sprint_20m', 'time'),
                        _buildTestTile(
                            ctx, 'Scatto 60 m', 'sprint_60m', 'time'),
                        _buildTestTile(
                            ctx, 'Test di Léger', 'leger', 'leger_test'),
                        const SizedBox(height: 16),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('EQUILIBRIO (Score)',
                              style: TextStyle(
                                  color: AppTheme.textMediumEmphasis,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        _buildTestTile(
                            ctx, 'Bipodale', 'balance_bipedal', 'score'),
                        _buildTestTile(
                            ctx, 'Monopodale SX', 'balance_single_l', 'score'),
                        _buildTestTile(
                            ctx, 'Monopodale DX', 'balance_single_r', 'score'),
                        const SizedBox(height: 16),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('CORE E RESISTENZA (Tempo)',
                              style: TextStyle(
                                  color: AppTheme.textMediumEmphasis,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        _buildTestTile(
                            ctx, 'Plank Frontale', 'plank_front', 'time'),
                        _buildTestTile(
                            ctx, 'Plank Laterale SX', 'plank_side_l', 'time'),
                        _buildTestTile(
                            ctx, 'Plank Laterale DX', 'plank_side_r', 'time'),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTestTile(
      BuildContext ctx, String title, String testId, String category) {
    return ListTile(
      title: Text(title, style: TextStyle(color: AppTheme.textHighEmphasis)),
      trailing: Icon(Icons.chevron_right, color: AppTheme.textMediumEmphasis),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(ctx);
        _showTeamSelectionForTest(context, testId, title, category);
      },
    );
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
          border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
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
              label: 'Plan',
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
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppTheme.card,
                  shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (ctx) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: AppTheme.modalHandle,
                                  borderRadius: BorderRadius.circular(2))),
                          const SizedBox(height: 24),
                          Text('Aggiungi al Calendario',
                              style: TextStyle(
                                  color: AppTheme.textHighEmphasis,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          ListTile(
                            leading: const CircleAvatar(
                                backgroundColor: AppTheme.primary,
                                child:
                                    Icon(Icons.ac_unit, color: Colors.white)),
                            title: Text('Allenamento Sci',
                                style: TextStyle(
                                    color: AppTheme.textHighEmphasis,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                'Crea evento in pista (Slalom, Gigante...)',
                                style: TextStyle(
                                    color: AppTheme.textMediumEmphasis,
                                    fontSize: 12)),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(ctx);
                              _showTeamSelectionIfNeeded(context,
                                  isSkiWorkout: true);
                            },
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFF7A00),
                                child: Icon(Icons.fitness_center,
                                    color: Colors.white)),
                            title: Text('Preparazione Atletica',
                                style: TextStyle(
                                    color: AppTheme.textHighEmphasis,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                'Scegli dal database (Forza, Corsa, ecc.)',
                                style: TextStyle(
                                    color: AppTheme.textMediumEmphasis,
                                    fontSize: 12)),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(ctx);
                              _showTeamSelectionIfNeeded(context,
                                  isSkiWorkout: false);
                            },
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const CircleAvatar(
                                backgroundColor: Colors.blueAccent,
                                child: Icon(Icons.speed, color: Colors.white)),
                            title: Text('Test Atletici',
                                style: TextStyle(
                                    color: AppTheme.textHighEmphasis,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                'Registra salti e massimali per gli atleti',
                                style: TextStyle(
                                    color: AppTheme.textMediumEmphasis,
                                    fontSize: 12)),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(ctx);
                              _showTestSelectionBottomSheet(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ----------------------------------------------------
// 1. HOME VIEW
// ----------------------------------------------------
class _CoachHomeView extends StatefulWidget {
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onProfileTap;

  const _CoachHomeView({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onProfileTap,
  });

  @override
  State<_CoachHomeView> createState() => _CoachHomeViewState();
}

class _CoachHomeViewState extends State<_CoachHomeView> {
  bool _isWeekView = true;
  DateTime _focusedDay = DateTime.now();

  final List<String> _months = [
    'Gennaio',
    'Febbraio',
    'Marzo',
    'Aprile',
    'Maggio',
    'Giugno',
    'Luglio',
    'Agosto',
    'Settembre',
    'Ottobre',
    'Novembre',
    'Dicembre'
  ];

  final List<String> _weekDays = [
    'LUN',
    'MAR',
    'MER',
    'GIO',
    'VEN',
    'SAB',
    'DOM'
  ];

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // Filter events for selected day
    final dailyEvents = appState.coachEvents.where((e) {
      final eventDate = DateTime.tryParse(e.date);
      if (eventDate == null) return false;
      return eventDate.year == widget.selectedDay.year &&
          eventDate.month == widget.selectedDay.month &&
          eventDate.day == widget.selectedDay.day;
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
                Text('WELCOME COACH',
                    style: TextStyle(
                        color: AppTheme.textMediumEmphasis,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
                Semantics(
                  button: true,
                  label: 'Apri profilo',
                  child: GestureDetector(
                    onTap: widget.onProfileTap,
                    child: CircleAvatar(
                      backgroundColor: AppTheme.card,
                      child: Icon(Icons.person_outline,
                          color: AppTheme.textMediumEmphasis),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: AppTheme.divider, height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Calendario',
                        style: TextStyle(
                            color: AppTheme.textHighEmphasis,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    Container(
                      decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.subtleBorder)),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _isWeekView = true);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                  color: _isWeekView
                                      ? AppTheme.primary
                                      : AppTheme.card,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('Settimana',
                                  style: TextStyle(
                                      color: _isWeekView
                                          ? Colors.white
                                          : AppTheme.textMediumEmphasis,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _isWeekView = false);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                  color: !_isWeekView
                                      ? AppTheme.primary
                                      : AppTheme.card,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('Mese',
                                  style: TextStyle(
                                      color: !_isWeekView
                                          ? Colors.white
                                          : AppTheme.textMediumEmphasis,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
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
                  decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.subtleBorder)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.chevron_left,
                                color: AppTheme.textMediumEmphasis),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (_isWeekView) {
                                  _focusedDay = _focusedDay
                                      .subtract(const Duration(days: 7));
                                } else {
                                  _focusedDay = DateTime(_focusedDay.year,
                                      _focusedDay.month - 1, 1);
                                }
                              });
                            },
                          ),
                          Text(
                              '${_months[_focusedDay.month - 1]} ${_focusedDay.year}',
                              style: TextStyle(
                                  color: AppTheme.textHighEmphasis,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.chevron_right,
                                color: AppTheme.textMediumEmphasis),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (_isWeekView) {
                                  _focusedDay =
                                      _focusedDay.add(const Duration(days: 7));
                                } else {
                                  _focusedDay = DateTime(_focusedDay.year,
                                      _focusedDay.month + 1, 1);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _isWeekView
                          ? _buildWeekView(appState)
                          : _buildMonthView(appState),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            color: AppTheme.primary, size: 20),
                        SizedBox(width: 8),
                        Text('Programma di Oggi',
                            style: TextStyle(
                                color: AppTheme.textHighEmphasis,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${dailyEvents.length} Eventi',
                          style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (dailyEvents.isEmpty)
                  _buildNoEventsPlaceholder()
                else
                  ...dailyEvents
                      .map((e) => _buildEventCard(context, e, appState))
                      .toList(),
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
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy,
              color: AppTheme.textMediumEmphasis.withValues(alpha: 0.5),
              size: 48),
          const SizedBox(height: 16),
          Text(
            'Nessun evento in programma',
            style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Usa il tasto + per aggiungere un allenamento',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
      BuildContext context, CalendarEvent event, AppState appState) {
    final presentCount =
        event.attendees?.where(CoachTrainingUtils.isAttendeePresent).length ??
            0;

    String teamName = 'Team';
    try {
      final ids = CoachTrainingUtils.teamIdsForEvent(event);
      final names = ids.map((id) {
        return appState.teams.firstWhere((t) => t.id == id.trim()).name;
      }).toList();
      if (names.isNotEmpty) teamName = names.join(', ');
    } catch (_) {}

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CoachEventDetailsScreen(event: event)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${event.startTime} - ${event.endTime}',
                          style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppTheme.subtleFill,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(teamName,
                              style: TextStyle(
                                  color: AppTheme.textMediumEmphasis,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(event.title,
                          style: TextStyle(
                              color: AppTheme.textHighEmphasis,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Icon(Icons.chevron_right,
                          color: AppTheme.textMediumEmphasis, size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          color: AppTheme.textMediumEmphasis, size: 16),
                      const SizedBox(width: 4),
                      Text(event.location ?? 'No location',
                          style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontSize: 13)),
                      const SizedBox(width: 16),
                      Icon(Icons.people_outline,
                          color: AppTheme.textMediumEmphasis, size: 16),
                      const SizedBox(width: 4),
                      Text('$presentCount Presenti',
                          style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontSize: 13)),
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
                  borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4)),
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
    final monday =
        _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final day = monday.add(Duration(days: index));
        final hasEvents = appState.coachEvents.any((e) {
          final eventDate = DateTime.tryParse(e.date);
          return eventDate?.year == day.year &&
              eventDate?.month == day.month &&
              eventDate?.day == day.day;
        });
        return _buildInteractiveDay(_weekDays[index], day,
            hasEvents: hasEvents);
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
          children: _weekDays
              .map((d) => SizedBox(
                  width: 32,
                  child: Text(d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textMediumEmphasis,
                          fontSize: 10,
                          fontWeight: FontWeight.bold))))
              .toList(),
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
            final date =
                DateTime(_focusedDay.year, _focusedDay.month, dayNumber);

            final hasEvents = appState.coachEvents.any((e) {
              final eventDate = DateTime.tryParse(e.date);
              return eventDate?.year == date.year &&
                  eventDate?.month == date.month &&
                  eventDate?.day == date.day;
            });

            return _buildInteractiveDay('', date,
                compact: true, hasEvents: hasEvents);
          },
        ),
      ],
    );
  }

  Widget _buildInteractiveDay(String label, DateTime date,
      {bool compact = false, bool hasEvents = false}) {
    bool isSelected = date.year == widget.selectedDay.year &&
        date.month == widget.selectedDay.month &&
        date.day == widget.selectedDay.day;

    bool isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _focusedDay = date;
        });
        widget.onDaySelected(date);
      },
      child: Column(
        children: [
          if (label.isNotEmpty) ...[
            Text(label,
                style: TextStyle(
                    color: AppTheme.textMediumEmphasis,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
          ],
          Container(
            width: compact ? 34 : 40,
            height: compact ? 44 : 52,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary
                    : (isToday
                        ? AppTheme.primary.withValues(alpha: 0.5)
                        : AppTheme.subtleBorder),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(date.day.toString(),
                    style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isToday
                                ? AppTheme.primary
                                : AppTheme.textHighEmphasis),
                        fontWeight: FontWeight.bold,
                        fontSize: compact ? 14 : 16)),
                if (hasEvents) ...[
                  const SizedBox(height: 4),
                  Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                          color: isSelected ? Colors.white : AppTheme.primary,
                          shape: BoxShape.circle)),
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
      final appState = Provider.of<AppState>(context, listen: false);
      final teamIds = appState.teams.map((team) => team.id).toList();

      if (teamIds.isEmpty) {
        if (mounted) {
          setState(() {
            _athletes = [];
            _isLoading = false;
          });
        }
        return;
      }

      final allEvents = appState.coachEvents.where((event) {
        final eventTeamIds = CoachTrainingUtils.teamIdsForEvent(event);
        return eventTeamIds.any(teamIds.contains);
      }).toList();

      // 1. Carica solo gli atleti dei team del coach
      final profilesData = await supabase
          .from('profiles')
          .select('id, first_name, last_name, role')
          .eq('role', 'athlete')
          .inFilter('team_id', teamIds);

      final athleteIds =
          (profilesData as List).map((p) => p['id'] as String).toList();

      final sessionsData = athleteIds.isEmpty
          ? <dynamic>[]
          : await supabase
              .from('training_sessions')
              .select('user_id, sport_id, duration')
              .neq('sport_id', 'alpine_skiing')
              .inFilter('user_id', athleteIds);

      if (mounted) {
        setState(() {
          _athletes = profilesData.map((p) {
            final athleteId = p['id'] as String;
            final name =
                '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
            final initial = ((p['first_name'] as String? ?? 'A').isNotEmpty
                    ? (p['first_name'] as String)[0]
                    : 'A')
                .toUpperCase();

            // Calcola % presenze sci
            final skiEvents =
                allEvents.where((e) => e.sportCategory == 'ski').toList();
            int skiPresences = 0;
            for (final event in skiEvents) {
              final attendees = event.attendees ?? [];
              final found = attendees.any((a) =>
                  (a['id'] == athleteId || a['name'] == name) &&
                  CoachTrainingUtils.isAttendeePresent(a));
              if (found) skiPresences++;
            }
            final skiPresencePercent = skiEvents.isNotEmpty
                ? (skiPresences / skiEvents.length * 100).round()
                : 0;

            // Calcola % presenze atletica
            final athleticEvents =
                allEvents.where((e) => e.sportCategory != 'ski').toList();
            int athleticPresences = 0;
            for (final event in athleticEvents) {
              final attendees = event.attendees ?? [];
              final found = attendees.any((a) =>
                  (a['id'] == athleteId || a['name'] == name) &&
                  CoachTrainingUtils.isAttendeePresent(a));
              if (found) athleticPresences++;
            }
            final athleticPresencePercent = athleticEvents.isNotEmpty
                ? (athleticPresences / athleticEvents.length * 100).round()
                : 0;

            // Calcola ore di preparazione atletica
            int totalMinutes = 0;
            for (final session in sessionsData) {
              if (session['user_id'] == athleteId) {
                totalMinutes +=
                    TimeUtils.parseDurationToMinutes(session['duration']);
              }
            }
            final prepHours = (totalMinutes / 60).ceil();

            return {
              'id': athleteId,
              'name': name,
              'initial': initial,
              'skiPresencePercent': skiPresencePercent,
              'athleticPresencePercent': athleticPresencePercent,
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
          Text('Report Atleti',
              style: TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ATLETI TOTALI',
                        style: TextStyle(
                            color: AppTheme.textMediumEmphasis,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(_athletes.length.toString(),
                        style: TextStyle(
                            color: AppTheme.textHighEmphasis,
                            fontSize: 32,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12)),
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
                  decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: AppTheme.textHighEmphasis),
                    decoration: InputDecoration(
                      hintText: 'Cerca atleta...',
                      hintStyle: TextStyle(color: AppTheme.textMediumEmphasis),
                      prefixIcon: Icon(Icons.search,
                          color: AppTheme.textMediumEmphasis),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.people_outline,
                  color: AppTheme.textMediumEmphasis, size: 16),
              SizedBox(width: 8),
              Text('LISTA ATLETI',
                  style: TextStyle(
                      color: AppTheme.textMediumEmphasis,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
          else if (_athletes.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: Text('Nessun atleta trovato',
                    style: TextStyle(color: AppTheme.textMediumEmphasis)),
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
      return a['name']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
    }).toList();

    return filtered.map((a) {
      return _buildAthleteItem(
        context,
        a['initial'] as String,
        a['name'] as String,
        a['id'] as String,
        a['skiPresencePercent'] as int,
        a['athleticPresencePercent'] as int,
        a['prepHours'] as int,
      );
    }).toList();
  }

  Widget _buildAthleteItem(
    BuildContext context,
    String initial,
    String name,
    String athleteId,
    int skiPresencePercent,
    int athleticPresencePercent,
    int prepHours,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CoachAthleteDetailScreen(
                      athleteName: name,
                      initial: initial,
                      athleteId: athleteId,
                    )));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.background,
              radius: 22,
              child: Text(initial,
                  style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.fitness_center,
                          color: AppTheme.textMediumEmphasis, size: 12),
                      const SizedBox(width: 4),
                      Text('${prepHours}h Extra',
                          style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.textMediumEmphasis
                              .withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            '$skiPresencePercent% Sci | $athleticPresencePercent% Atletica',
                            style: TextStyle(
                                color: AppTheme.textMediumEmphasis,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('${prepHours}h',
                style: TextStyle(
                    color: AppTheme.textHighEmphasis,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                color: AppTheme.textMediumEmphasis, size: 20),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 3. TRAINING VIEW (Lista Eventi)
// ----------------------------------------------------
class _CoachTrainingView extends StatefulWidget {
  const _CoachTrainingView();

  @override
  State<_CoachTrainingView> createState() => _CoachTrainingViewState();
}

class _CoachTrainingViewState extends State<_CoachTrainingView> {
  String _searchQuery = '';
  String _selectedFilter = 'Tutti';

  final List<String> _filters = [
    'Tutti',
    'Preparazione Atletica',
    'Allenamento Sci',
    'SL',
    'GS',
    'SG',
    'DH',
    'SX'
  ];

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.modalHandle,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text('Filtra Allenamenti',
                  style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 12,
                children: _filters.map((f) {
                  final isSelected = _selectedFilter == f;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedFilter = f);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppTheme.primary : AppTheme.subtleFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.subtleBorder),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textMediumEmphasis,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    final allEvents = List<CalendarEvent>.from(appState.coachEvents);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    allEvents.sort((a, b) {
      final dateA =
          DateTime.tryParse(a.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB =
          DateTime.tryParse(b.date) ?? DateTime.fromMillisecondsSinceEpoch(0);

      final isPastA = dateA.isBefore(today);
      final isPastB = dateB.isBefore(today);

      if (isPastA && !isPastB) return 1;
      if (!isPastA && isPastB) return -1;

      if (!isPastA && !isPastB) {
        return dateA.compareTo(dateB);
      } else {
        return dateB.compareTo(dateA);
      }
    });

    final filteredEvents = allEvents.where((e) {
      final q = _searchQuery.toLowerCase();
      final titleMatch = e.title.toLowerCase().contains(q);
      final locationMatch = (e.location ?? '').toLowerCase().contains(q);
      if (_searchQuery.isNotEmpty && !titleMatch && !locationMatch) {
        return false;
      }

      if (_selectedFilter == 'Tutti') return true;
      if (_selectedFilter == 'Preparazione Atletica')
        return e.sportCategory == 'dryland';
      if (_selectedFilter == 'Allenamento Sci') return e.sportCategory == 'ski';

      if (CoachTrainingUtils.specialties.contains(_selectedFilter)) {
        if (e.sportCategory != 'ski') return false;
        final specialties = e.technicalDetails?['specialties'] as List?;
        if (specialties != null && specialties.isNotEmpty) {
          return specialties.contains(_selectedFilter);
        }
        return false;
      }

      return true;
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          Text('Tutti gli Allenamenti',
              style: TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: AppTheme.textHighEmphasis),
                    decoration: InputDecoration(
                      hintText: 'Cerca per titolo, luogo...',
                      hintStyle: TextStyle(color: AppTheme.textMediumEmphasis),
                      prefixIcon: Icon(Icons.search,
                          color: AppTheme.textMediumEmphasis),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _showFilterModal,
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                      color: _selectedFilter != 'Tutti'
                          ? AppTheme.primary
                          : AppTheme.card,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.tune,
                      color: _selectedFilter != 'Tutti'
                          ? Colors.white
                          : AppTheme.textMediumEmphasis),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (filteredEvents.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Nessun allenamento trovato',
                    style: TextStyle(color: AppTheme.textMediumEmphasis)),
              ),
            )
          else
            ...filteredEvents
                .map((e) => _buildEventCard(context, e, appState))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildEventCard(
      BuildContext context, CalendarEvent event, AppState appState) {
    final eventTeamIds = CoachTrainingUtils.teamIdsForEvent(event);
    final teamName = eventTeamIds.isEmpty
        ? 'N/A'
        : eventTeamIds.map((id) {
            try {
              return appState.teams.firstWhere((t) => t.id == id).name;
            } catch (_) {
              return 'N/A';
            }
          }).join(', ');

    final eventDate = DateTime.tryParse(event.date);
    final isPast = eventDate != null &&
        eventDate.isBefore(DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day));

    final isSki = event.sportCategory == 'ski';
    String? specialty;
    if (isSki) {
      final specs =
          CoachTrainingUtils.specialtiesFromDetails(event.technicalDetails);
      if (specs.isNotEmpty) specialty = specs.join('+');
    } else {
      specialty = event.drylandSpecialty;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CoachEventDetailsScreen(event: event)));
      },
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppTheme.subtleFill,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(event.date,
                          style: TextStyle(
                              color: AppTheme.textHighEmphasis,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                    if (specialty != null && specialty.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                              color: isSki
                                  ? AppTheme.primary.withValues(alpha: 0.15)
                                  : const Color(0xFFFF7A00)
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            specialty.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TextStyle(
                                color: isSki
                                    ? AppTheme.primary
                                    : const Color(0xFFFF7A00),
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    const SizedBox(width: 8),
                    Text(isPast ? 'COMPLETATO' : 'PIANIFICATO',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isPast
                                ? AppTheme.textMediumEmphasis
                                : AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(event.title,
                    style: TextStyle(
                        color: AppTheme.textHighEmphasis,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people_outline,
                                  color: AppTheme.textMediumEmphasis, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(teamName,
                                    style: TextStyle(
                                        color: AppTheme.textMediumEmphasis,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  color: AppTheme.textMediumEmphasis, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(event.location ?? 'N/A',
                                    style: TextStyle(
                                        color: AppTheme.textMediumEmphasis,
                                        fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${event.startTime} - ${event.endTime}',
                          style: TextStyle(
                              color: AppTheme.textHighEmphasis,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 16,
            bottom: 32,
            width: 4,
            child: Container(
              decoration: BoxDecoration(
                color: isPast
                    ? AppTheme.textLowEmphasis.withValues(alpha: 0.6)
                    : AppTheme.primary,
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
