import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'add_training_screen.dart';

class SportActivity {
  final String id;
  final String name;
  final String category;
  final IconData icon;

  const SportActivity(this.id, this.name, this.category, this.icon);
}

class ActivitySelectScreen extends StatefulWidget {
  final bool isPicker;

  const ActivitySelectScreen({super.key, this.isPicker = false});

  @override
  State<ActivitySelectScreen> createState() => _ActivitySelectScreenState();
}

class _ActivitySelectScreenState extends State<ActivitySelectScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'ALL';

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

  List<SportActivity> get _filteredActivities {
    return allActivities.where((act) {
      final matchesSearch =
          act.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat =
          _selectedCategory == 'ALL' || act.category == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1217),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF0D1217),
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('SELECT YOUR ACTIVITY',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF161A20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF222831), width: 1.5),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search 60+ sports...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(),
                      color: Colors.grey, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // Categories List
          Container(
            height: 48,
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFF1A1E24), width: 1)),
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
                          color: isSelected
                              ? const Color(0xFF1A9DF0)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Activities List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredActivities.length,
              itemBuilder: (context, index) {
                final act = _filteredActivities[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: const Color(0xFF222831),
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        if (widget.isPicker) {
                          Navigator.pop(context, act);
                        } else {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => AddTrainingScreen(
                                      sportId: act.id, sportName: act.name)));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A313C),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:
                                  Icon(act.icon, color: Colors.grey, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    act.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    act.category,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      letterSpacing: 1.0,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
