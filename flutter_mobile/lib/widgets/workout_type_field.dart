import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/workout_catalog.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/workout_session_type_utils.dart';

class WorkoutTypeField extends StatefulWidget {
  final TrainingSession session;
  final bool readOnly;

  const WorkoutTypeField({
    super.key,
    required this.session,
    this.readOnly = false,
  });

  @override
  State<WorkoutTypeField> createState() => _WorkoutTypeFieldState();
}

class _WorkoutTypeFieldState extends State<WorkoutTypeField> {
  bool _saving = false;

  Future<void> _edit() async {
    final selected = await showModalBottomSheet<WorkoutActivityDefinition>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WorkoutTypePicker(sportId: widget.session.sportId),
    );
    if (selected == null || !mounted || selected.id == widget.session.sportId) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().addSession(
            WorkoutSessionTypeUtils.changeType(widget.session, selected),
            rethrowErrors: true,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Tipologia aggiornata.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Impossibile salvare la tipologia. Riprova.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('workout_type_field'),
      contentPadding: EdgeInsets.zero,
      title: Text('Tipologia',
          style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 12)),
      subtitle: Text(
        WorkoutCatalog.displayName(widget.session.sportId),
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      onTap: widget.readOnly || _saving ? null : _edit,
      trailing: widget.readOnly
          ? null
          : _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  tooltip: 'Modifica tipologia',
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined,
                      color: AppTheme.primary, size: 20),
                ),
    );
  }
}

class _WorkoutTypePicker extends StatefulWidget {
  final String sportId;

  const _WorkoutTypePicker({required this.sportId});

  @override
  State<_WorkoutTypePicker> createState() => _WorkoutTypePickerState();
}

class _WorkoutTypePickerState extends State<_WorkoutTypePicker> {
  late final List<WorkoutActivityDefinition> _activities;
  late String _selectedId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedId = widget.sportId;
    _activities = WorkoutCatalog.allActivities
        .where((activity) => activity.id != 'external_import')
        .toList();
    if (!_activities.any((activity) => activity.id == widget.sportId)) {
      _activities.insert(0, WorkoutCatalog.editableDefinition(widget.sportId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches =
        _activities.where((activity) => activity.matches(_query)).toList();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tipologia allenamento',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Scegli il tipo di allenamento svolto.',
                  style: TextStyle(color: AppTheme.textMediumEmphasis)),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('workout_type_search'),
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                    hintText: 'Cerca tipologia',
                    prefixIcon: Icon(Icons.search)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: matches.isEmpty
                    ? const Center(child: Text('Nessuna tipologia trovata.'))
                    : ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          for (final section in [
                            (
                              WorkoutCatalogSection.preparation,
                              'Preparazione atletica'
                            ),
                            (WorkoutCatalogSection.sport, 'Sport'),
                            (WorkoutCatalogSection.other, 'Altre attività'),
                          ])
                            if (matches.any((activity) =>
                                activity.section == section.$1)) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(section.$2,
                                    style: TextStyle(
                                        color: AppTheme.textMediumEmphasis,
                                        fontWeight: FontWeight.w600)),
                              ),
                              for (final activity in matches.where(
                                  (activity) => activity.section == section.$1))
                                ListTile(
                                  key: ValueKey('workout_type_${activity.id}'),
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(activity.icon,
                                      color: AppTheme.primary),
                                  title: Text(activity.name),
                                  selected: _selectedId == activity.id,
                                  trailing: _selectedId == activity.id
                                      ? const Icon(Icons.check,
                                          color: AppTheme.primary)
                                      : null,
                                  onTap: () =>
                                      setState(() => _selectedId = activity.id),
                                ),
                            ],
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annulla')),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('save_workout_type'),
                    onPressed: _selectedId == widget.sportId
                        ? null
                        : () => Navigator.pop(
                            context,
                            _activities.firstWhere(
                                (activity) => activity.id == _selectedId)),
                    child: const Text('Salva'),
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
