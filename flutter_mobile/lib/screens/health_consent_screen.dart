import 'package:flutter/material.dart';

import '../core/legal_links.dart';
import '../core/theme.dart';

/// Explicit app consent, separate from the operating system permission picker.
/// The caller persists the decision before opening permissions or navigating.
class HealthConsentScreen extends StatefulWidget {
  const HealthConsentScreen({
    super.key,
    required this.providerName,
    required this.onAccept,
    required this.onDecline,
    this.existingUser = false,
    this.allowBack = false,
    this.onOpenPrivacy,
  });

  final String providerName;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final bool existingUser;
  final bool allowBack;
  final VoidCallback? onOpenPrivacy;

  @override
  State<HealthConsentScreen> createState() => _HealthConsentScreenState();
}

class _HealthConsentScreenState extends State<HealthConsentScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _choose(bool accept) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (accept ? widget.onAccept : widget.onDecline)();
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Non è stato possibile salvare la tua scelta. Riprova.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    return PopScope(
      canPop: widget.allowBack && !_saving,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: widget.allowBack ? AppBar() : null,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: AppTheme.primary, size: 34),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.existingUser
                        ? 'UNA SCELTA PER IL TUO ACCOUNT'
                        : 'PRIMA DI COLLEGARE I TUOI DATI',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('I tuoi dati salute,\nla tua scelta',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(color: ink, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  Text(
                    'Con il tuo consenso, 4athletes importa da '
                    '${widget.providerName} i dati che autorizzi per analizzare '
                    'allenamento, sonno e recupero.',
                    style: TextStyle(color: muted, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  _panel(context, [
                    _item(
                        context,
                        Icons.bedtime_outlined,
                        'Sonno e recupero',
                        'Durata e fasi del sonno, frequenza cardiaca a riposo '
                            'e variabilità cardiaca (HRV).'),
                    _item(
                        context,
                        Icons.directions_run,
                        'Attività e allenamenti',
                        'Sessioni, passi, distanze, velocità e calorie, per '
                            'analizzare volume e intensità.'),
                    _item(
                        context,
                        Icons.favorite_outline,
                        'Misure del corpo',
                        'Frequenza cardiaca, ossigenazione, respirazione, '
                            'temperatura, peso e altezza.'),
                    if (widget.providerName == 'Apple Health')
                      _item(
                          context,
                          Icons.water_drop_outlined,
                          'Ciclo mestruale',
                          'Se autorizzato in Apple Health, per contestualizzare '
                              'recupero e fasi fisiologiche.'),
                  ]),
                  const SizedBox(height: 16),
                  _panel(context, [
                    _item(
                        context,
                        Icons.cloud_outlined,
                        'Salvataggio e utilizzo',
                        'Dati importati, misure e risultati delle analisi possono '
                            'essere salvati su Supabase, oltre che sul dispositivo, '
                            'per il tuo account 4athletes.'),
                    _item(
                        context,
                        Icons.people_outline,
                        'Chi può consultarli',
                        'Tu e, attraverso le funzioni dell’app, gli allenatori '
                            'associati al tuo profilo. Matteo Noris può accedervi '
                            'per gestire il servizio.'),
                  ]),
                  const SizedBox(height: 20),
                  Text(
                    'Il consenso è facoltativo. Puoi usare le altre funzioni '
                    'dell’app e cambiare questa scelta dal profilo. La revoca '
                    'interrompe le nuove importazioni; per i dati già salvati '
                    'puoi richiedere la cancellazione.',
                    style: TextStyle(color: muted, fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Questo consenso riguarda il servizio 4athletes. '
                    'L’eventuale uso dei dati per una tesi richiede un '
                    'percorso separato.',
                    style: TextStyle(color: muted, fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.onOpenPrivacy ??
                        () => openLegalPage(context, privacyPolicyUrl),
                    child: const Text('Leggi l’informativa privacy'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : () => _choose(true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Acconsento e collega ${widget.providerName}',
                            textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _saving ? null : () => _choose(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text('Continua senza collegare i dati salute',
                        textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.panelDecoration(context: context),
        child: Column(children: children),
      );

  Widget _item(
      BuildContext context, IconData icon, String title, String detail) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text(detail,
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
