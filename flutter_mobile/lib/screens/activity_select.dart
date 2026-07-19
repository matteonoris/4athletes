import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/workout_catalog.dart';
import '../models/models.dart';
import '../models/training_activity_models.dart';
import '../providers/app_state.dart';
import '../services/health_service.dart';
import 'activity_details_screen.dart';
import 'ski_activity_screen.dart';
import 'workout_flow_screen.dart';

class SportActivity {
  final String id;
  final String name;
  final String category;
  final IconData icon;

  const SportActivity(this.id, this.name, this.category, this.icon);
}

List<SportActivity> get selectableSportActivities =>
    WorkoutCatalog.allActivities
        .where((activity) =>
            activity.section == WorkoutCatalogSection.sport &&
            activity.id != 'external_import')
        .map(
          (activity) => SportActivity(
            activity.id,
            activity.name,
            activity.category,
            activity.icon,
          ),
        )
        .toList(growable: false);

class ActivitySelectScreen extends StatefulWidget {
  final bool isPicker;
  final Team? coachTeam;
  final DateTime? initialDate;

  const ActivitySelectScreen({
    super.key,
    this.isPicker = false,
    this.coachTeam,
    this.initialDate,
  });

  @override
  State<ActivitySelectScreen> createState() => _ActivitySelectScreenState();
}

class _ActivitySelectScreenState extends State<ActivitySelectScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isImporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final query = _query.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPicker
            ? 'Scegli attivita'
            : widget.coachTeam == null
                ? 'Aggiungi allenamento'
                : 'Allenamento · ${widget.coachTeam!.name}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              key: const ValueKey('workout_activity_search'),
              controller: _searchController,
              autofocus: false,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cerca sport, attivita o protocollo',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Cancella ricerca',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Expanded(
            child: query.isEmpty
                ? _defaultList(appState)
                : _searchResults(appState, query),
          ),
        ],
      ),
    );
  }

  Widget _defaultList(AppState appState) {
    final preparation = WorkoutCatalog.allActivities
        .where((item) => item.section == WorkoutCatalogSection.preparation)
        .toList();
    final sports = WorkoutCatalog.allActivities
        .where((item) => item.section == WorkoutCatalogSection.sport)
        .toList();
    final other = WorkoutCatalog.allActivities
        .where((item) => item.section == WorkoutCatalogSection.other)
        .toList();

    final frequency = <String, int>{};
    for (final session in appState.sessions) {
      frequency.update(session.sportId, (count) => count + 1,
          ifAbsent: () => 1);
    }
    sports.sort((a, b) {
      final countComparison =
          (frequency[b.id] ?? 0).compareTo(frequency[a.id] ?? 0);
      return countComparison != 0 ? countComparison : a.name.compareTo(b.name);
    });

    return ListView(
      key: const ValueKey('workout_activity_vertical_list'),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
      children: [
        _sectionTitle('PREPARAZIONE ATLETICA'),
        ...preparation.map(_activityRow),
        const SizedBox(height: 18),
        _sectionTitle('SPORT'),
        ...sports.map(_activityRow),
        if (!widget.isPicker && widget.coachTeam == null) ...[
          const SizedBox(height: 18),
          _sectionTitle('ALTRE ATTIVITA'),
          ...other.map(_activityRow),
        ],
      ],
    );
  }

  Widget _searchResults(AppState appState, String query) {
    final results = <_SearchResult>[];
    for (final activity in WorkoutCatalog.allActivities) {
      if (activity.matches(query) &&
          (!widget.isPicker ||
              activity.section != WorkoutCatalogSection.other)) {
        results.add(_SearchResult.activity(activity));
      }
      for (final mode in activity.modes) {
        if (mode.matches(query)) {
          results.add(_SearchResult.mode(activity, mode));
        }
      }
    }
    for (final protocol in WorkoutCatalog.protocols) {
      if (protocol.matches(query)) {
        results.add(_SearchResult.protocol(protocol));
      }
    }
    if (!widget.isPicker) {
      for (final template in appState.workoutTemplates) {
        final text =
            '${template.name} ${template.description ?? ''}'.toLowerCase();
        if (text.contains(query.toLowerCase())) {
          results.add(_SearchResult.template(template));
        }
      }
    }

    final unique = <String, _SearchResult>{};
    for (final result in results) {
      unique.putIfAbsent(result.identity, () => result);
    }
    final values = unique.values.toList();
    if (values.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 44, color: AppTheme.textLowEmphasis),
              const SizedBox(height: 12),
              const Text(
                'Nessun risultato',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                'Prova con un altro sport, sinonimo, protocollo o template.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMediumEmphasis),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      key: const ValueKey('workout_search_results'),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
      children: [
        _sectionTitle('RISULTATI'),
        ...values.map(_searchResultRow),
      ],
    );
  }

  Widget _activityRow(WorkoutActivityDefinition activity) {
    return _fullWidthRow(
      key: ValueKey('activity_${activity.id}'),
      icon: activity.icon,
      title: activity.name,
      description: activity.description,
      onTap: () => _openActivity(activity),
    );
  }

  Widget _searchResultRow(_SearchResult result) {
    return _fullWidthRow(
      key: ValueKey('search_${result.identity}'),
      icon: result.icon,
      title: result.title,
      description: result.description,
      badge: result.badge,
      onTap: () => _openSearchResult(result),
    );
  }

  Widget _fullWidthRow({
    required Key key,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 23, color: AppTheme.primary),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: AppTheme.textHighEmphasis,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.secondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: AppTheme.secondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textMediumEmphasis,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right,
                    color: AppTheme.textLowEmphasis, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openActivity(WorkoutActivityDefinition activity) async {
    if (widget.isPicker) {
      Navigator.pop(
        context,
        SportActivity(
          activity.id,
          activity.name,
          activity.category,
          activity.icon,
        ),
      );
      return;
    }
    if (activity.id == 'external_import') {
      await _importAndChoose();
      return;
    }
    if (activity.id == 'alpine_skiing' && widget.coachTeam == null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => SkiActivityScreen(initialDate: widget.initialDate),
        ),
      );
      return;
    }
    await _openWorkoutFlow(activity: activity);
  }

  Future<void> _openSearchResult(_SearchResult result) async {
    if (result.template != null) {
      final activity = _activityForTemplate(result.template!);
      await _openWorkoutFlow(
        activity: activity,
        initialTemplate: result.template,
      );
      return;
    }
    if (result.protocol != null) {
      final protocol = result.protocol!;
      final activity = WorkoutCatalog.byId(protocol.activityId);
      final mode = activity.modes.firstWhere(
        (item) => item.id == protocol.modeId,
        orElse: () => WorkoutCatalog.runningModes
            .firstWhere((item) => item.id == 'intervals'),
      );
      await _openWorkoutFlow(
        activity: activity,
        initialMode: mode,
        initialProtocol: protocol,
      );
      return;
    }
    if (result.activity != null) {
      if (widget.isPicker || result.mode == null) {
        await _openActivity(result.activity!);
        return;
      }
      await _openWorkoutFlow(
        activity: result.activity!,
        initialMode: result.mode,
      );
    }
  }

  Future<void> _importAndChoose() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
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
      final appState = context.read<AppState>();
      await appState.syncHealthWorkouts(days: 14);
      if (!mounted) return;
      final imports = appState.sessions
          .where((session) => session.details?['source'] == 'health_sync')
          .take(30)
          .toList();
      final selected = await showModalBottomSheet<TrainingSession>(
        context: context,
        backgroundColor: AppTheme.surface,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 4, 18, 14),
                  child: Text(
                    'Scegli attivita importata',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: imports.isEmpty
                      ? Center(
                          child: Text(
                            'Nessuna attivita trovata.',
                            style:
                                TextStyle(color: AppTheme.textMediumEmphasis),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: imports.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: AppTheme.divider),
                          itemBuilder: (_, index) {
                            final session = imports[index];
                            return ListTile(
                              leading: const Icon(Icons.watch_outlined),
                              title: Text(
                                  '${session.date} · ${session.startTime}'),
                              subtitle: Text(
                                '${WorkoutCatalog.displayName(session.sportId)} · ${session.duration} min',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pop(sheetContext, session),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
      if (selected == null || !mounted) return;
      final activity = WorkoutCatalog.byId(selected.sportId);
      await _openWorkoutFlow(
        activity: activity,
        initialImport: selected,
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _openWorkoutFlow({
    required WorkoutActivityDefinition activity,
    WorkoutModeDefinition? initialMode,
    WorkoutProtocolDefinition? initialProtocol,
    WorkoutTemplate? initialTemplate,
    TrainingSession? initialImport,
  }) async {
    final session = await Navigator.push<TrainingSession>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutFlowScreen(
          activity: activity,
          initialMode: initialMode,
          initialProtocol: initialProtocol,
          initialTemplate: initialTemplate,
          initialImport: initialImport,
          coachTeam: widget.coachTeam,
          initialDate: widget.initialDate,
        ),
      ),
    );
    if (session == null || !mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailsScreen(
          session: session,
          sportName: session.details?['title']?.toString(),
          readOnly: widget.coachTeam != null,
        ),
      ),
    );
  }

  WorkoutActivityDefinition _activityForTemplate(WorkoutTemplate template) {
    final sportType = template.sportType;
    if (sportType != null && sportType.isNotEmpty) {
      return WorkoutCatalog.byId(sportType);
    }
    return switch (template.category) {
      ActivityCategory.strength => WorkoutCatalog.byId('dryland_strength'),
      ActivityCategory.plyometrics =>
        WorkoutCatalog.byId('dryland_plyometrics'),
      ActivityCategory.speedAgility =>
        WorkoutCatalog.byId('dryland_speed_agility'),
      ActivityCategory.circuit ||
      ActivityCategory.athleticPrep =>
        WorkoutCatalog.byId('conditioning_hiit'),
      ActivityCategory.mobility ||
      ActivityCategory.core =>
        WorkoutCatalog.byId('mobility_recovery'),
      _ => WorkoutCatalog.byId('other'),
    };
  }

  static Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 9),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.textMediumEmphasis,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SearchResult {
  final WorkoutActivityDefinition? activity;
  final WorkoutModeDefinition? mode;
  final WorkoutProtocolDefinition? protocol;
  final WorkoutTemplate? template;
  final String title;
  final String description;
  final String? badge;
  final IconData icon;
  final String identity;

  const _SearchResult._({
    this.activity,
    this.mode,
    this.protocol,
    this.template,
    required this.title,
    required this.description,
    required this.badge,
    required this.icon,
    required this.identity,
  });

  factory _SearchResult.activity(WorkoutActivityDefinition activity) {
    return _SearchResult._(
      activity: activity,
      title: activity.name,
      description: activity.description,
      badge: null,
      icon: activity.icon,
      identity: 'activity_${activity.id}',
    );
  }

  factory _SearchResult.mode(
    WorkoutActivityDefinition activity,
    WorkoutModeDefinition mode,
  ) {
    return _SearchResult._(
      activity: activity,
      mode: mode,
      title: '${activity.name} · ${mode.name}',
      description: mode.description,
      badge: 'MODALITA',
      icon: activity.icon,
      identity: 'mode_${activity.id}_${mode.id}',
    );
  }

  factory _SearchResult.protocol(WorkoutProtocolDefinition protocol) {
    return _SearchResult._(
      protocol: protocol,
      title: protocol.name,
      description: 'Corsa · Intervalli · ${protocol.description}',
      badge: 'PROTOCOLLO',
      icon: Icons.repeat,
      identity: 'protocol_${protocol.id}',
    );
  }

  factory _SearchResult.template(WorkoutTemplate template) {
    return _SearchResult._(
      template: template,
      title: template.name,
      description: template.description ??
          '${template.blocks.length} blocchi pronti da personalizzare',
      badge: 'TEMPLATE',
      icon: Icons.bookmark_outline,
      identity: 'template_${template.id}',
    );
  }
}
