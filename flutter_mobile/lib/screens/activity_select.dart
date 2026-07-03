import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/dryland_prep_types.dart';
import '../models/training_activity_models.dart';
import '../providers/app_state.dart';
import '../services/health_service.dart';
import 'add_training_screen.dart';
import 'dryland_activity_screen.dart';
import 'ski_activity_screen.dart';

class SportActivity {
  final String id;
  final String name;
  final String category;
  final IconData icon;

  const SportActivity(this.id, this.name, this.category, this.icon);
}

List<SportActivity> get selectableSportActivities =>
    _ActivitySelectScreenState.sportActivities;

class ActivitySelectScreen extends StatefulWidget {
  final bool isPicker;

  const ActivitySelectScreen({super.key, this.isPicker = false});

  @override
  State<ActivitySelectScreen> createState() => _ActivitySelectScreenState();
}

class _ActivitySelectScreenState extends State<ActivitySelectScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'ALL';
  bool _showAllSports = false;
  bool _isImportingHealthWorkouts = false;

  final List<String> _categories = [
    'ALL',
    'WINTER',
    'TEAM',
    'ENDURANCE',
    'FITNESS',
    'COMBAT',
    'RACQUET',
    'WATER',
    'SKILL'
  ];

  static final List<SportActivity> allActivities = [
    // WINTER
    SportActivity(
        'alpine_skiing', 'ALPINE SKIING', 'WINTER', PhosphorIcons.snowflake()),
    const SportActivity('cross_country_skiing', 'CROSS-COUNTRY SKIING',
        'WINTER', Icons.downhill_skiing),
    const SportActivity(
        'snowboarding', 'SNOWBOARDING', 'WINTER', Icons.snowboarding),
    const SportActivity(
        'ice_skating', 'ICE SKATING', 'WINTER', Icons.ice_skating),
    const SportActivity(
        'ice_hockey', 'ICE HOCKEY', 'WINTER', Icons.sports_hockey),
    const SportActivity(
        'bobsleigh', 'BOBSLEIGH / LUGE', 'WINTER', Icons.sledding),
    const SportActivity('curling', 'CURLING', 'WINTER', Icons.sports_cricket),

    // TEAM
    const SportActivity('american_football', 'AMERICAN FOOTBALL', 'TEAM',
        Icons.sports_football),
    const SportActivity('baseball', 'BASEBALL', 'TEAM', Icons.sports_baseball),
    const SportActivity(
        'basketball', 'BASKETBALL', 'TEAM', Icons.sports_basketball),
    const SportActivity(
        'calcio', 'CALCIO (SOCCER)', 'TEAM', Icons.sports_soccer),
    const SportActivity(
        'volleyball', 'VOLLEYBALL', 'TEAM', Icons.sports_volleyball),
    const SportActivity('rugby', 'RUGBY', 'TEAM', Icons.sports_rugby),
    const SportActivity('handball', 'HANDBALL', 'TEAM', Icons.sports_handball),
    const SportActivity('water_polo', 'WATER POLO', 'TEAM', Icons.water_drop),
    const SportActivity('cricket', 'CRICKET', 'TEAM', Icons.sports_cricket),
    const SportActivity(
        'field_hockey', 'FIELD HOCKEY', 'TEAM', Icons.sports_hockey),
    const SportActivity('lacrosse', 'LACROSSE', 'TEAM', Icons.sports_rugby),

    // ENDURANCE
    const SportActivity(
        'cycling', 'CYCLING', 'ENDURANCE', Icons.directions_bike),
    const SportActivity(
        'running', 'RUNNING', 'ENDURANCE', Icons.directions_run),
    const SportActivity(
        'marathon', 'MARATHON', 'ENDURANCE', Icons.directions_run),
    const SportActivity('triathlon', 'TRIATHLON', 'ENDURANCE', Icons.pool),
    const SportActivity('rowing', 'ROWING', 'ENDURANCE', Icons.rowing),
    const SportActivity('hiking', 'HIKING', 'ENDURANCE', Icons.hiking),
    const SportActivity(
        'walking', 'WALKING', 'ENDURANCE', Icons.directions_walk),
    const SportActivity(
        'trail_running', 'TRAIL RUNNING', 'ENDURANCE', Icons.directions_run),

    // FITNESS
    SportActivity('stretching', 'ALLUNGAMENTO (STRETCHING)', 'FITNESS',
        PhosphorIcons.arrowsOut()),
    SportActivity('athletic_prep', 'ATHLETIC PREP / OTHER', 'FITNESS',
        PhosphorIcons.lightning()),
    const SportActivity('hyperarch', 'HYPERARCH FASCIA TRAINING', 'FITNESS',
        Icons.fitness_center),
    const SportActivity(
        'lattacidemia', 'LATTACIDEMIA', 'FITNESS', Icons.science),
    const SportActivity('tendon_isometrics', 'ALLENAMENTO TENDINI', 'FITNESS',
        Icons.accessibility_new),
    const SportActivity(
        'weightlifting', 'WEIGHTLIFTING', 'FITNESS', Icons.fitness_center),
    const SportActivity(
        'crossfit', 'CROSSFIT', 'FITNESS', Icons.fitness_center),
    const SportActivity('yoga', 'YOGA', 'FITNESS', Icons.self_improvement),
    const SportActivity(
        'pilates', 'PILATES', 'FITNESS', Icons.self_improvement),
    const SportActivity(
        'gymnastics', 'GYMNASTICS', 'FITNESS', Icons.sports_gymnastics),
    const SportActivity(
        'aerobics', 'AEROBICS', 'FITNESS', Icons.accessibility_new),

    // COMBAT
    const SportActivity('boxing', 'BOXING', 'COMBAT', Icons.sports_mma),
    const SportActivity(
        'martial_arts', 'MARTIAL ARTS', 'COMBAT', Icons.sports_martial_arts),
    const SportActivity('wrestling', 'WRESTLING', 'COMBAT', Icons.sports_mma),
    const SportActivity('judo', 'JUDO', 'COMBAT', Icons.sports_martial_arts),
    const SportActivity(
        'karate', 'KARATE', 'COMBAT', Icons.sports_martial_arts),
    const SportActivity(
        'taekwondo', 'TAEKWONDO', 'COMBAT', Icons.sports_martial_arts),
    const SportActivity('fencing', 'FENCING', 'COMBAT', Icons.sports_kabaddi),
    const SportActivity(
        'kickboxing', 'KICKBOXING', 'COMBAT', Icons.sports_martial_arts),

    // RACQUET
    SportActivity('badminton', 'BADMINTON', 'RACQUET', PhosphorIcons.wind()),
    const SportActivity('tennis', 'TENNIS', 'RACQUET', Icons.sports_tennis),
    const SportActivity(
        'table_tennis', 'TABLE TENNIS', 'RACQUET', Icons.sports_tennis),
    const SportActivity('squash', 'SQUASH', 'RACQUET', Icons.sports_tennis),
    const SportActivity('padel', 'PADEL', 'RACQUET', Icons.sports_tennis),

    // WATER
    const SportActivity('swimming', 'SWIMMING', 'WATER', Icons.pool),
    const SportActivity('surfing', 'SURFING', 'WATER', Icons.surfing),
    const SportActivity('sailing', 'SAILING', 'WATER', Icons.sailing),
    const SportActivity(
        'scuba_diving', 'SCUBA DIVING', 'WATER', Icons.scuba_diving),
    const SportActivity(
        'spearfishing', 'PESCA SUBACQUEA', 'WATER', Icons.scuba_diving),
    const SportActivity(
        'kite_surfing', 'KITE SURFING', 'WATER', Icons.kitesurfing),
    const SportActivity('kayaking', 'KAYAKING', 'WATER', Icons.kayaking),
    const SportActivity(
        'water_skiing', 'WATER SKIING', 'WATER', Icons.water_drop),

    // SKILL
    SportActivity('archery', 'ARCHERY', 'SKILL', PhosphorIcons.target()),
    const SportActivity('golf', 'GOLF', 'SKILL', Icons.sports_golf),
    const SportActivity('bowling', 'BOWLING', 'SKILL', Icons.sports_golf),
    const SportActivity(
        'billiards', 'BILLIARDS / POOL', 'SKILL', Icons.sports_golf),
    SportActivity('darts', 'DARTS', 'SKILL', PhosphorIcons.target()),
    const SportActivity(
        'equestrian', 'EQUESTRIAN', 'SKILL', Icons.sports_score),
    SportActivity('shooting', 'SHOOTING', 'SKILL', PhosphorIcons.target()),
    const SportActivity(
        'skateboarding', 'SKATEBOARDING', 'SKILL', Icons.snowboarding),
  ];

  static final Set<String> _sportOnlyExcludedIds = {
    'athletic_prep',
    'weightlifting',
    'crossfit',
    'stretching',
    'yoga',
    'pilates',
    'hyperarch',
    'lattacidemia',
    'tendon_isometrics',
    'aerobics',
  };

  static List<SportActivity> get sportActivities => allActivities
      .where((activity) =>
          activity.category != 'FITNESS' &&
          !_sportOnlyExcludedIds.contains(activity.id))
      .toList();

  List<SportActivity> get _filteredActivities {
    return sportActivities.where((act) {
      final matchesSearch =
          act.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat =
          _selectedCategory == 'ALL' || act.category == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();
  }

  // ignore: unused_field
  static const List<_DrylandCategoryOption> _drylandCategories = [
    _DrylandCategoryOption(
      ActivityCategory.strength,
      'Forza',
      'Palestra, set, kg, reps, RPE',
      Icons.fitness_center,
      Color(0xFFFF8A3D),
    ),
    _DrylandCategoryOption(
      ActivityCategory.plyometrics,
      'Pliometria',
      'Balzi, contatti, direzioni',
      Icons.bolt,
      Color(0xFFFFC857),
    ),
    _DrylandCategoryOption(
      ActivityCategory.speedAgility,
      'Velocità / Agilità',
      'Sprint, drill, coni, ostacoli',
      Icons.speed,
      Color(0xFF43D9B8),
    ),
    _DrylandCategoryOption(
      ActivityCategory.mobility,
      'Mobilita',
      'Mobilita, stretching, yoga',
      Icons.self_improvement,
      Color(0xFFB084F5),
    ),
    _DrylandCategoryOption(
      ActivityCategory.core,
      'Core',
      'Addome, stabilita, tronco',
      Icons.accessibility_new,
      Color(0xFF7DD56F),
    ),
    _DrylandCategoryOption(
      ActivityCategory.circuit,
      'Circuito',
      'Blocchi misti e conditioning',
      Icons.loop,
      Color(0xFFEB6D8C),
    ),
  ];

  void _openDryland(DrylandPrepTypeOption option) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrylandActivityScreen(
          category: option.category,
          title: option.title,
          prepType: option.id,
          usesPhases: true,
        ),
      ),
    );
  }

  void _openSport(SportActivity activity) {
    if (widget.isPicker) {
      Navigator.pop(context, activity);
      return;
    }
    if (activity.id == 'alpine_skiing') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SkiActivityScreen()),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTrainingScreen(
          sportId: activity.id,
          sportName: activity.name,
        ),
      ),
    );
  }

  Future<void> _importHealthWorkouts() async {
    if (_isImportingHealthWorkouts) return;

    setState(() => _isImportingHealthWorkouts = true);
    try {
      final permission = await HealthService().requestPermissionsDetailed();
      if (!mounted) return;

      if (!permission.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(permission.message ??
                'Permessi salute non concessi. Controlla Apple Health o Health Connect.'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      await Provider.of<AppState>(context, listen: false)
          .syncHealthWorkouts(days: 7);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allenamenti esterni importati e aggiornati.'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import allenamenti non riuscito: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isImportingHealthWorkouts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final query = _searchQuery.trim().toLowerCase();
    final categoryResults = DrylandPrepTypes.options.where((item) {
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query);
    }).toList();
    final sportResults = _filteredActivities.where((activity) {
      if (query.isEmpty) return true;
      return activity.name.toLowerCase().contains(query) ||
          activity.category.toLowerCase().contains(query);
    }).toList();
    final recentSports = appState.sessions
        .map((session) => session.sportId)
        .toSet()
        .take(4)
        .map((id) => sportActivities.cast<SportActivity?>().firstWhere(
              (activity) => activity?.id == id,
              orElse: () => null,
            ))
        .whereType<SportActivity>()
        .toList();
    final favoriteSports = sportActivities
        .where((activity) =>
            ['running', 'cycling', 'hiking', 'calcio'].contains(activity.id))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _showAllSports
                ? Icons.close
                : PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
            color: AppTheme.textHighEmphasis,
            size: 20,
          ),
          onPressed: () {
            if (_showAllSports) {
              setState(() => _showAllSports = false);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(_showAllSports ? 'Sport' : 'Aggiungi attività',
            style: TextStyle(
                color: AppTheme.textHighEmphasis,
                fontSize: _showAllSports ? 16 : 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0)),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.subtleBorder, width: 1.5),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style:
                    TextStyle(color: AppTheme.textHighEmphasis, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _showAllSports
                      ? 'Cerca sport...'
                      : 'Cerca sport o preparazione...',
                  hintStyle: TextStyle(
                      color: AppTheme.textMediumEmphasis, fontSize: 14),
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(),
                      color: AppTheme.textMediumEmphasis, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          if (_showAllSports) _sportCategoryTabs(),
          Expanded(
            child: _showAllSports
                ? _sportList(sportResults)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      if (!widget.isPicker) ...[
                        _healthImportTile(),
                        const SizedBox(height: 18),
                      ],
                      if (query.isEmpty) ...[
                        _sectionTitle('Scegli area'),
                        _macroTile(
                          title: 'Sport',
                          subtitle: 'Hiking, calcio, corsa, tennis, bici',
                          icon: Icons.sports_outlined,
                          color: AppTheme.primary,
                          onTap: () => setState(() => _showAllSports = true),
                        ),
                        const SizedBox(height: 18),
                      ],
                      _sectionTitle('Preparazione atletica'),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.55,
                        children: categoryResults
                            .map((option) => _prepTile(option))
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      if (query.isNotEmpty) ...[
                        _sectionTitle('Sport'),
                        ...sportResults.take(20).map(_sportTile),
                      ] else ...[
                        if (recentSports.isNotEmpty) ...[
                          _sectionTitle('Sport recenti'),
                          _horizontalSports(recentSports),
                          const SizedBox(height: 18),
                        ],
                        _sectionTitle('Sport preferiti'),
                        _horizontalSports(favoriteSports),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _showAllSports = true),
                          icon: const Icon(Icons.search),
                          label: const Text('Mostra tutti gli sport'),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sportCategoryTabs() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 1)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? AppTheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textMediumEmphasis,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.textHighEmphasis,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _healthImportTile() {
    return InkWell(
      onTap: _isImportingHealthWorkouts ? null : _importHealthWorkouts,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isImportingHealthWorkouts
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  : const Icon(Icons.sync, color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Importa da app esterne',
                    style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Apple Health / Health Connect, con cardio e zone',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textMediumEmphasis,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
              color: AppTheme.textMediumEmphasis,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _horizontalSports(List<SportActivity> sports) {
    if (sports.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final sport = sports[index];
          return InkWell(
            onTap: () => _openSport(sport),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 128,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.subtleBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(sport.icon, color: AppTheme.primary, size: 22),
                  const Spacer(),
                  Text(
                    sport.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: sports.length,
      ),
    );
  }

  Widget _macroTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textMediumEmphasis,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
              color: AppTheme.textMediumEmphasis,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _prepTile(DrylandPrepTypeOption option) {
    return InkWell(
      onTap: () => _openDryland(option),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: option.color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(option.icon, color: option.color, size: 24),
            const Spacer(),
            Text(
              option.title,
              style: TextStyle(
                color: AppTheme.textHighEmphasis,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              option.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sportList(List<SportActivity> sports) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: sports.map(_sportTile).toList(),
    );
  }

  Widget _sportTile(SportActivity act) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openSport(act),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(act.icon, color: AppTheme.textMediumEmphasis),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        act.name,
                        style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        act.category,
                        style: TextStyle(
                          color: AppTheme.textMediumEmphasis,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrylandCategoryOption {
  final String category;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _DrylandCategoryOption(
    this.category,
    this.title,
    this.subtitle,
    this.icon,
    this.color,
  );
}
