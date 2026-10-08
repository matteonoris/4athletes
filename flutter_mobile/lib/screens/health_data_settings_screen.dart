import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Profile surface. Persistence and import cancellation belong to the caller.
class HealthDataSettingsScreen extends StatefulWidget {
  const HealthDataSettingsScreen({
    super.key,
    required this.providerName,
    required this.consentGranted,
    required this.onEnable,
    required this.onRevoke,
    required this.onRequestDeletion,
    this.revocationPending = false,
  });

  final String providerName;
  final bool consentGranted;
  final Future<bool> Function() onEnable;
  final Future<void> Function() onRevoke;
  final VoidCallback onRequestDeletion;
  final bool revocationPending;

  @override
  State<HealthDataSettingsScreen> createState() =>
      _HealthDataSettingsScreenState();
}

class _HealthDataSettingsScreenState extends State<HealthDataSettingsScreen> {
  late bool _granted = widget.consentGranted;
  bool _saving = false;
  late bool _revocationPending = widget.revocationPending;
  String? _error;

  Future<void> _change() async {
    if (_saving) return;
    final revoke = _granted || _revocationPending;
    setState(() {
      _saving = true;
      _error = null;
      if (revoke) {
        _granted = false;
        _revocationPending = true;
      }
    });
    try {
      if (revoke) {
        await widget.onRevoke();
        if (mounted) setState(() => _revocationPending = false);
      } else {
        final enabled = await widget.onEnable();
        if (mounted) setState(() => _granted = enabled);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = revoke
            ? 'Non è stato possibile confermare la revoca. Riprova.'
            : 'Non è stato possibile salvare la tua scelta. Riprova.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Gestisci dati salute')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.panelDecoration(context: context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined,
                      color: AppTheme.primary, size: 32),
                  const SizedBox(height: 16),
                  Text(_granted ? 'Consenso attivo' : 'Consenso non attivo',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    _granted
                        ? 'Le importazioni da ${widget.providerName} possono '
                            'continuare senza chiederti di nuovo il consenso, '
                            'nei limiti dei permessi che hai concesso.'
                        : 'Le nuove importazioni da ${widget.providerName} '
                            'sono disattivate. Puoi continuare a usare le '
                            'altre funzioni di 4athletes.',
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'La revoca interrompe le nuove importazioni. Non cancella '
              'automaticamente i dati già salvati su 4athletes e non modifica '
              'i permessi nelle impostazioni di ${widget.providerName}.',
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.6),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: _saving ? null : _change,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_saving
                    ? 'Salvataggio…'
                    : _revocationPending
                        ? 'Riprova la revoca'
                        : _granted
                            ? 'Revoca il consenso'
                            : 'Leggi e attiva il consenso'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _saving ? null : widget.onRequestDeletion,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Richiedi eliminazione dati salute',
                    textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
