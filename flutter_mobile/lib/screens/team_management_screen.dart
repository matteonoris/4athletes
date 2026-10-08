import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../services/team_access_service.dart';

class TeamManagementScreen extends StatefulWidget {
  final Team team;
  final TeamAccessService? service;
  const TeamManagementScreen({super.key, required this.team, this.service});
  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  late final TeamAccessService _service;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _busy = false;
  bool _authorized = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TeamAccessService(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    try {
      final teams = await _service.teams();
      final authorized = teams
          .any((t) => t.id == widget.team.id && t.isManager && !t.isPending);
      final rows = authorized
          ? await _service.directory(widget.team.id, includePending: true)
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _members = rows;
          _authorized = authorized;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossibile caricare la squadra. Riprova.';
        });
      }
    }
  }

  Future<void> _act(String action, Map<String, dynamic> member) async {
    if (_busy) return;
    if (action == 'remove' || action == 'demote' || action == 'reject') {
      final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Conferma modifica'),
                content: Text(action == 'demote'
                    ? 'Rimuovere il ruolo di responsabile? L’allenatore resterà nella squadra.'
                    : 'Rimuovere questa persona dalla squadra o rifiutare la richiesta?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annulla')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Conferma'))
                ],
              ));
      if (accepted != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await _service.operation(action,
          teamId: widget.team.id, subjectId: member['id']);
      await _load();
      if (mounted && widget.service == null) {
        await context.read<AppState>().refreshTeams();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is PostgrestException
                ? e.message
                : 'Modifica non riuscita. Riprova.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _member(Map<String, dynamic> member) {
    final pending = member['status'] == 'pending';
    final manager = member['is_manager'] == true;
    final name =
        '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'.trim();
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'Membro' : name,
                  style: Theme.of(context).textTheme.titleMedium),
              Text(pending
                  ? 'In attesa di approvazione'
                  : manager
                      ? 'Responsabile'
                      : member['role'] == 'coach'
                          ? 'Allenatore'
                          : 'Atleta'),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pending
                      ? [
                          FilledButton(
                              onPressed:
                                  _busy ? null : () => _act('approve', member),
                              child: const Text('Approva')),
                          TextButton(
                              onPressed:
                                  _busy ? null : () => _act('reject', member),
                              child: const Text('Rifiuta')),
                        ]
                      : [
                          if (member['role'] == 'coach')
                            OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _act(
                                        manager ? 'demote' : 'promote', member),
                                child: Text(manager
                                    ? 'Rimuovi ruolo'
                                    : 'Nomina responsabile')),
                          TextButton(
                              onPressed:
                                  _busy ? null : () => _act('remove', member),
                              child: const Text('Rimuovi dalla squadra')),
                        ]),
            ])));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Gestisci squadra')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_authorized && _error == null
                ? const Center(
                    child: Text('Gestione riservata ai responsabili.'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      Text(widget.team.name,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      const Text(
                          'I responsabili approvano gli allenatori e possono nominare altri responsabili. Deve rimanere almeno un responsabile.'),
                      const SizedBox(height: 12),
                      const Text(
                          'Dati salute personali: sola lettura per allenatori e responsabili.'),
                      if (_error != null) Text(_error!),
                      if (_busy) const LinearProgressIndicator(),
                      const SizedBox(height: 24),
                      if (_members.any((m) => m['status'] == 'pending')) ...[
                        Text('Richieste di accesso',
                            style: Theme.of(context).textTheme.titleLarge),
                        ..._members
                            .where((m) => m['status'] == 'pending')
                            .map(_member),
                      ],
                      Text('Membri',
                          style: Theme.of(context).textTheme.titleLarge),
                      ..._members
                          .where((m) => m['status'] == 'active')
                          .map(_member),
                    ])),
      );
}
