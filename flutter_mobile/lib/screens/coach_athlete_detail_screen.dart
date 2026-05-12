import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

class CoachAthleteDetailScreen extends StatefulWidget {
  final String athleteName;
  final String initial;
  final String athleteId; // Supabase UUID of the athlete

  const CoachAthleteDetailScreen({
    super.key,
    required this.athleteName,
    required this.initial,
    required this.athleteId,
  });

  @override
  State<CoachAthleteDetailScreen> createState() => _CoachAthleteDetailScreenState();
}

class _CoachAthleteDetailScreenState extends State<CoachAthleteDetailScreen> {
  List<TrainingSession>? _sessions;
  UserProfile? _athleteProfile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final results = await Future.wait([
        appState.loadSessionsForAthlete(widget.athleteId),
        appState.loadAthleteProfile(widget.athleteId),
      ]);
      if (mounted) {
        setState(() {
          _sessions = results[0] as List<TrainingSession>;
          _athleteProfile = results[1] as UserProfile?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore nel caricamento dei dati';
          _isLoading = false;
        });
      }
    }
  }

  String _sportLabel(String sportId) {
    const map = {
      'alpine_skiing': 'Sci Alpino',
      'weightlifting': 'Weightlifting',
      'powerlifting': 'Powerlifting',
      'crossfit': 'CrossFit',
      'bodybuilding': 'Bodybuilding',
      'running': 'Corsa',
      'trail_running': 'Trail Running',
      'cycling': 'Ciclismo',
      'swimming': 'Nuoto',
      'athletic_prep': 'Preparazione Atletica',
      'stretching': 'Stretching',
      'yoga': 'Yoga',
      'pilates': 'Pilates',
      'other': 'Altro',
    };
    return map[sportId] ?? sportId;
  }

  IconData _sportIcon(String sportId) {
    if (sportId == 'alpine_skiing' || sportId.contains('ski')) return Icons.ac_unit;
    if (['weightlifting', 'powerlifting', 'crossfit', 'bodybuilding'].contains(sportId)) return Icons.fitness_center;
    if (sportId.contains('running') || sportId == 'track_field') return Icons.directions_run;
    if (sportId.contains('cycling') || sportId == 'spinning') return Icons.directions_bike;
    if (sportId == 'swimming') return Icons.pool;
    if (['stretching', 'yoga', 'pilates'].contains(sportId)) return Icons.self_improvement;
    return Icons.sports;
  }

  Color _sportColor(String sportId) {
    if (sportId == 'alpine_skiing' || sportId.contains('ski')) return AppTheme.primary;
    if (['weightlifting', 'powerlifting', 'crossfit', 'bodybuilding'].contains(sportId)) return const Color(0xFFFF7A00);
    if (sportId.contains('running')) return Colors.green;
    if (sportId.contains('cycling')) return Colors.cyan;
    return AppTheme.secondary;
  }

  bool _isWeightlifting(String sportId) {
    return ['weightlifting', 'powerlifting', 'crossfit', 'bodybuilding', 'athletic_prep'].contains(sportId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppTheme.card, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
              child: Text(widget.initial,
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.athleteName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                if (_athleteProfile != null)
                  Text(
                    '${_athleteProfile!.weight.toStringAsFixed(0)} kg  •  ${_athleteProfile!.height.toStringAsFixed(0)} cm',
                    style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textMediumEmphasis),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: AppTheme.textMediumEmphasis)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: const Text('Riprova')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final sessions = _sessions ?? [];

    // Compute summary stats
    final totalSessions = sessions.length;
    final wlSessions = sessions.where((s) => _isWeightlifting(s.sportId)).toList();
    final oneRepMax = _athleteProfile?.oneRepMax;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary cards ──
          Row(
            children: [
              Expanded(child: _buildStatCard('SESSIONI', totalSessions.toString(), Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('FORZA', wlSessions.length.toString(), const Color(0xFFFF7A00))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('RPE MEDIO',
                  sessions.isEmpty ? '-' : (sessions.map((s) => s.effort).reduce((a, b) => a + b) / sessions.length).toStringAsFixed(1),
                  AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 24),

          // ── 1RM Massimali (from profile) ──
          if (oneRepMax != null && oneRepMax.isNotEmpty) ...[
            _buildSectionTitle(Icons.fitness_center, 'Massimali (1RM)', const Color(0xFFFF7A00)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: oneRepMax.entries.map((entry) {
                return _build1RMCard(entry.key, entry.value.toStringAsFixed(0));
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // ── Training Sessions History ──
          _buildSectionTitle(Icons.history, 'Storico Allenamenti', AppTheme.primary),
          const SizedBox(height: 12),

          if (sessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('Nessuna sessione registrata',
                    style: TextStyle(color: AppTheme.textMediumEmphasis)),
              ),
            )
          else
            ...sessions.map((session) => _buildSessionCard(session)),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.w900, fontSize: 22)),
        ],
      ),
    );
  }

  Widget _build1RMCard(String exerciseName, String weightKg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(exerciseName,
              style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Text(weightKg, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          const Text('kg', style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSessionCard(TrainingSession session) {
    final isWL = _isWeightlifting(session.sportId);
    final color = _sportColor(session.sportId);
    final exercises = session.details?['exercises'];
    final hasExercises = isWL && exercises != null && (exercises as List).isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: hasExercises
            ? ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_sportIcon(session.sportId), color: color, size: 20),
                ),
                title: Text(
                  _sportLabel(session.sportId),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${session.date}  •  ${session.startTime}–${session.endTime}  •  RPE ${session.effort}',
                    style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 11),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(exercises as List<dynamic>).length} esercizi',
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.expand_more, color: AppTheme.textMediumEmphasis, size: 20),
                  ],
                ),
                children: [
                  const Divider(color: Color(0x0DFFFFFF), height: 1),
                  _buildExerciseList(exercises),
                ],
              )
            : ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_sportIcon(session.sportId), color: color, size: 20),
                ),
                title: Text(
                  _sportLabel(session.sportId),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${session.date}  •  ${session.startTime}–${session.endTime}  •  RPE ${session.effort}',
                    style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 11),
                  ),
                ),
                trailing: _buildEffortBadge(session.effort),
              ),
      ),
    );
  }

  Widget _buildEffortBadge(int effort) {
    Color color;
    if (effort <= 3) color = Colors.green;
    else if (effort <= 7) color = Colors.orange;
    else color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('RPE $effort',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildExerciseList(List<dynamic> exercises) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: exercises.asMap().entries.map((entry) {
          final i = entry.key;
          final ex = entry.value as Map<String, dynamic>;
          final sets = ex['sets'] as List<dynamic>? ?? [];
          final name = ex['name'] as String? ?? 'Esercizio';

          return Container(
            margin: EdgeInsets.only(top: i > 0 ? 16 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exercise name header
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF7A00),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${sets.length} serie',
                      style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Sets table header
                if (sets.isNotEmpty) ...[
                  Row(
                    children: const [
                      SizedBox(width: 32, child: Text('SET', style: TextStyle(fontSize: 9, color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      SizedBox(width: 8),
                      Expanded(child: Text('KG', style: TextStyle(fontSize: 9, color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      SizedBox(width: 8),
                      Expanded(child: Text('REPS', style: TextStyle(fontSize: 9, color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      SizedBox(width: 8),
                      Expanded(child: Text('VOLUME', style: TextStyle(fontSize: 9, color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...sets.asMap().entries.map((setEntry) {
                    final si = setEntry.key;
                    final s = setEntry.value as Map<String, dynamic>;
                    final kg = (s['kg'] as num?)?.toDouble() ?? 0.0;
                    final reps = (s['reps'] as num?)?.toInt() ?? 0;
                    final volume = kg * reps;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${si + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              kg > 0 ? '${kg % 1 == 0 ? kg.toInt() : kg} kg' : '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFF7A00),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reps > 0 ? '$reps' : '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              volume > 0 ? '${volume.toStringAsFixed(0)} kg' : '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.textMediumEmphasis,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
