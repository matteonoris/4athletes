import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'coach_athlete_detail_screen.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class TeamDetailScreen extends StatefulWidget {
  final Team team;

  const TeamDetailScreen({super.key, required this.team});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  String _timeFilter = 'Last 7 Days';
  String _categoryFilter = 'Ore';
  bool _showFilters = true;

  final List<Map<String, dynamic>> _teamAthletes = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _rawTeammates = [];
  List<Map<String, dynamic>> _rawSessions = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboardData();
  }

  Future<void> _loadLeaderboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final athletesResponse = await supabase
          .from('profiles')
          .select()
          .eq('team_id', widget.team.id)
          .eq('role', 'athlete');

      final List<Map<String, dynamic>> athletes = List<Map<String, dynamic>>.from(athletesResponse);

      List<Map<String, dynamic>> sessions = [];
      if (athletes.isNotEmpty) {
        final athleteIds = athletes.map((a) => a['id'] as String).toList();
        final sessionsResponse = await supabase
            .from('training_sessions')
            .select()
            .inFilter('user_id', athleteIds);
        sessions = List<Map<String, dynamic>>.from(sessionsResponse);
      }

      setState(() {
        _rawTeammates = athletes;
        _rawSessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading leaderboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  DateTime _getFilterStartDate() {
    final now = DateTime.now();
    if (_timeFilter == 'Last 7 Days') {
      return now.subtract(const Duration(days: 7));
    } else if (_timeFilter == 'This Month') {
      return DateTime(now.year, now.month, 1);
    } else { // This Season
      return DateTime(now.year - (now.month < 5 ? 1 : 0), 5, 1);
    }
  }

  double _parseDurationToHours(String duration) {
    if (duration.isEmpty) return 0.0;
    try {
      if (duration.contains('h')) {
        // e.g. "1h 30m"
        final parts = duration.split('h');
        double hours = double.parse(parts[0].replaceAll(RegExp(r'[^0-9.]'), ''));
        double mins = 0.0;
        if (parts.length > 1 && parts[1].isNotEmpty) {
          String minStr = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
          if (minStr.isNotEmpty) {
            mins = double.parse(minStr);
          }
        }
        return hours + (mins / 60.0);
      } else if (duration.contains(':')) {
        final parts = duration.split(':');
        if (parts.length >= 2) {
          return double.parse(parts[0]) + (double.parse(parts[1]) / 60.0);
        }
      } else if (duration.toLowerCase().contains('min') || duration.toLowerCase().contains('m')) {
        String numStr = duration.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.parse(numStr) / 60.0;
      } else {
        String numStr = duration.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.parse(numStr) / 60.0; // Assume minutes if no unit is provided
      }
    } catch (_) {}
    return 0.0;
  }

  void _generateTeamData() {
    _teamAthletes.clear();
    final startDate = _getFilterStartDate();

    for (var athlete in _rawTeammates) {
      final athleteId = athlete['id'];
      double oreFuoriSci = 0.0;
      int cambiTotale = 0;
      int cambiSL = 0;
      int cambiGS = 0;
      int cambiSG = 0;
      int cambiDH = 0;

      final athleteSessions = _rawSessions.where((s) => s['user_id'] == athleteId);

      for (var session in athleteSessions) {
        final dateStr = session['date'] ?? '';
        DateTime? sessionDate = DateTime.tryParse(dateStr);
        if (sessionDate == null || sessionDate.isBefore(startDate)) continue;

        final sportId = session['sport_id'] ?? '';
        bool isAlpineSkiing = sportId == 'alpine_skiing' || sportId == 'skiing' || sportId == 'snowboarding';
        final durationStr = session['duration']?.toString() ?? '0';
        final details = session['details'] as Map<String, dynamic>?;

        if (!isAlpineSkiing) {
          oreFuoriSci += _parseDurationToHours(durationStr);
        } else {
          int cambia = 0;
          if (details != null && details['gatedSkiing'] != null) {
            int ch = int.tryParse(details['gatedSkiing']['changes'].toString()) ?? 0;
            int laps = int.tryParse(details['gatedSkiing']['laps'].toString()) ?? 1;
            cambia = ch * laps;
          }

          cambiTotale += cambia;

          if (details != null && details['specialties'] != null) {
            List<dynamic> specs = details['specialties'];
            for (var s in specs) {
              String specStr = s.toString().toUpperCase();
              if (specStr.contains('SL')) cambiSL += cambia;
              if (specStr.contains('GS')) cambiGS += cambia;
              if (specStr.contains('SG')) cambiSG += cambia;
              if (specStr.contains('DH')) cambiDH += cambia;
            }
          }
        }
      }

      _teamAthletes.add({
        'id': athleteId,
        'name': '${athlete['first_name'] ?? ''} ${athlete['last_name'] ?? ''}'.trim(),
        'avatar': athlete['avatar_url'] ?? '',
        'subtitle': athlete['skill_level'] ?? 'Athlete',
        'Ore': oreFuoriSci,
        'Tot. Dir': cambiTotale.toDouble(),
        'Cambi SL': cambiSL.toDouble(),
        'Cambi GS': cambiGS.toDouble(),
        'Cambi SG': cambiSG.toDouble(),
        'Cambi DH': cambiDH.toDouble(),
      });
    }
  }

  double _getCategoryValue(Map<String, dynamic> athlete, String category) {
    return (athlete[category] ?? 0.0).toDouble();
  }

  String _getCategoryUnit(String category) {
    if (category.contains('Ore')) return 'h';
    if (category.contains('Sessioni')) return 'sess';
    return '';
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('Ore')) return PhosphorIcons.clock();
    if (category.contains('Tot. Dir')) return PhosphorIcons.waveSine();
    if (category.contains('Cambi SL')) return PhosphorIcons.lightning();
    if (category.contains('Cambi GS')) return PhosphorIcons.snowflake();
    return PhosphorIcons.trendUp();
  }

  void _shareCode() {
    // ignore: deprecated_member_use
    Share.share(
        'Unisciti al mio team su 4Athletes! Usa il codice: ${widget.team.inviteCode}');
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.team.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Codice copiato negli appunti!'),
          behavior: SnackBarBehavior.floating),
    );
  }


  double _getTotalValue() {
    double total = 0;
    for (var a in _teamAthletes) {
      total += _getCategoryValue(a, _categoryFilter);
    }
    return total;
  }

  void _confirmLeaveTeam(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2126),
        title: const Text('Abbandona Team', style: TextStyle(color: Colors.white)),
        content: const Text('Sei sicuro di voler abbandonare questo team?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await Provider.of<AppState>(context, listen: false).leaveTeam(widget.team.id);
                if (mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore durante l\'uscita dal team')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sì', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveAthlete(BuildContext context, String athleteId, String athleteName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2126),
        title: const Text('Rimuovi Atleta', style: TextStyle(color: Colors.white)),
        content: Text('Sei sicuro di voler rimuovere $athleteName da questo team?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await Provider.of<AppState>(context, listen: false).removeAthleteFromTeam(athleteId, widget.team.id);
                _loadLeaderboardData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore durante la rimozione')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sì', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAthlete = Provider.of<AppState>(context).userProfile?.role == 'athlete';
    final isCoach = Provider.of<AppState>(context).userProfile?.role == 'coach';

    _generateTeamData();

    final sortedAthletes = List<Map<String, dynamic>>.from(_teamAthletes);
    sortedAthletes.sort((a, b) {
      double valA = _getCategoryValue(a, _categoryFilter);
      double valB = _getCategoryValue(b, _categoryFilter);
      return valB.compareTo(valA);
    });

    double maxValue = sortedAthletes.isEmpty
        ? 1
        : _getCategoryValue(sortedAthletes.first, _categoryFilter);
    if (maxValue <= 0) maxValue = 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1217), // Deep dark background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(widget.team.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 18)),
            const SizedBox(height: 2),
            Text('${_isLoading ? widget.team.members : sortedAthletes.length} MEMBERS',
                style: const TextStyle(
                    color: Color(0xFF1A9DF0),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 1.2)),
          ],
        ),
        centerTitle: true,
        actions: [
          if (isAthlete)
            IconButton(
              icon: Icon(PhosphorIcons.signOut(), color: Colors.redAccent),
              onPressed: () => _confirmLeaveTeam(context),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // "INVITA MEMBRI" Card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1E1E), // Dark Green Base
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF16322C), width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('INVITA MEMBRI',
                            style: TextStyle(
                                color: Color(0xFF6B8B88),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _copyCode,
                          child: Row(
                            children: [
                              Text(widget.team.inviteCode,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      color: Colors.white)),
                              const SizedBox(width: 8),
                              Icon(PhosphorIcons.copy(),
                                  size: 18, color: Colors.white70),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _shareCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text('INVIA LINK',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),
          ),

          // FILTRI Row 1 (Button, Dropdown, Total)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showFilters = !_showFilters),
                    icon: Icon(_showFilters ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: Colors.white),
                    label: const Text('FILTRI',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _showFilters ? const Color(0xFF1A9DF0) : Colors.transparent,
                      side: BorderSide(color: const Color(0xFF1A9DF0)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (String value) {
                      setState(() {
                        _timeFilter = value;
                      });
                    },
                    color: const Color(0xFF1E2126),
                    itemBuilder: (BuildContext context) {
                      return ['Last 7 Days', 'This Month', 'This Season']
                          .map((String choice) {
                        return PopupMenuItem<String>(
                          value: choice,
                          child: Text(
                            choice,
                            style: TextStyle(
                              color: _timeFilter == choice ? const Color(0xFF1A9DF0) : Colors.white,
                              fontWeight: _timeFilter == choice ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList();
                    },
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(PhosphorIcons.clock(),
                              size: 16, color: const Color(0xFF1A9DF0)),
                          const SizedBox(width: 8),
                          Text(_timeFilter,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.white)),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('TOTAL',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(_getTotalValue().toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A9DF0))),
                          const SizedBox(width: 2),
                          Text(_getCategoryUnit(_categoryFilter),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),

          if (_showFilters) ...[
            // I filtri di tempo temporizzati nel popup
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    'Ore',
                    'Tot. Dir',
                    'Cambi SL',
                    'Cambi GS',
                    'Cambi SG',
                    'Cambi DH'
                  ].map((cat) {
                    bool isSelected = _categoryFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () => setState(() => _categoryFilter = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1A9DF0)
                                : Colors.transparent,
                            border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1A9DF0)
                                    : Colors.grey.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(_getCategoryIcon(cat),
                                  size: 14,
                                  color: isSelected ? Colors.white : Colors.grey),
                              const SizedBox(width: 6),
                              Text(cat,
                                  style: TextStyle(
                                    color:
                                        isSelected ? Colors.white : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          // LEADERBOARD HEADERS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 24, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('RANK & ATHLETE',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  Text('VOLUME',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                ],
              ),
            ),
          ),

          // LEADERBOARD ITEMS
          _isLoading
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1A9DF0),
                      ),
                    ),
                  ),
                )
              : sortedAthletes.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60, horizontal: 16),
                        child: Center(
                          child: Text(
                            'Nessun atleta in questo team.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final athlete = sortedAthletes[index];
                          double val = _getCategoryValue(athlete, _categoryFilter);
                          bool isFirst = index == 0;

                          return GestureDetector(
                            onTap: () {
                              if (isCoach) {
                                HapticFeedback.lightImpact();
                                String name = athlete['name'] ?? 'Atleta';
                                String initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CoachAthleteDetailScreen(
                                      athleteName: name,
                                      initial: initial,
                                      athleteId: athlete['id'],
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C2229),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Stack(
                              children: [
                                // Highlight on left for #1
                                if (isFirst) ...[
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                        width: 3,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF1A9DF0),
                                          borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                              bottomLeft: Radius.circular(16)),
                                        )),
                                  ),
                                ],
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      // Rank / Trophy
                                      SizedBox(
                                        width: 28,
                                        child: Center(
                                          child: index == 0
                                              ? const Icon(Icons.emoji_events_outlined,
                                                  color: Color(0xFFFFD700), size: 24)
                                              : Text('${index + 1}',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w900,
                                                      color: index == 1
                                                          ? Colors.white
                                                          : (index == 2
                                                              ? const Color(0xFFCD7F32)
                                                              : const Color(
                                                                  0xFF424750)))),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Avatar
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2A313C),
                                          borderRadius: BorderRadius.circular(12),
                                          image: athlete['avatar']?.isNotEmpty == true
                                              ? DecorationImage(
                                                  image: NetworkImage(athlete['avatar']),
                                                  fit: BoxFit.cover)
                                              : null,
                                        ),
                                        child: athlete['avatar']?.isEmpty == true
                                            ? Center(
                                                child: Text(
                                                    athlete['name'] != null && athlete['name'].isNotEmpty
                                                        ? athlete['name'][0]
                                                        : 'A',
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white)))
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      // Profile Info and Progress Bar
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(athlete['name'],
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontSize: 14)),
                                            const SizedBox(height: 2),
                                            Text(athlete['subtitle'] ?? 'Athlete',
                                                style: const TextStyle(
                                                    color: Colors.grey, fontSize: 11)),
                                            const SizedBox(height: 8),
                                            LayoutBuilder(
                                                builder: (context, constraints) {
                                              double percentage = val / maxValue;
                                              if (percentage > 1.0) percentage = 1.0;
                                              return Stack(
                                                children: [
                                                  Container(
                                                    height: 4,
                                                    width: constraints.maxWidth,
                                                    decoration: BoxDecoration(
                                                        color: const Color(0xFF2A313C),
                                                        borderRadius:
                                                            BorderRadius.circular(2)),
                                                  ),
                                                  Container(
                                                    height: 4,
                                                    width:
                                                        constraints.maxWidth * percentage,
                                                    decoration: BoxDecoration(
                                                        color: isFirst
                                                            ? const Color(0xFF1A9DF0)
                                                            : const Color(0xFF4A5565),
                                                        borderRadius:
                                                            BorderRadius.circular(2)),
                                                  ),
                                                ],
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Value
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(val.toStringAsFixed(1),
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                  color: isFirst
                                                      ? const Color(0xFF1A9DF0)
                                                      : Colors.white)),
                                          const SizedBox(width: 2),
                                          Text(_getCategoryUnit(_categoryFilter),
                                              style: const TextStyle(
                                                  fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                      if (isCoach) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(PhosphorIcons.userMinus(), color: Colors.redAccent, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _confirmRemoveAthlete(context, athlete['id'], athlete['name']),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ));
                        },
                        childCount: sortedAthletes.length,
                      ),
                    ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
