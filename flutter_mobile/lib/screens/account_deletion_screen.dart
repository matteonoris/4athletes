import 'dart:async';
import 'package:flutter/material.dart';
import '../services/account_deletion_service.dart';
import '../core/legal_links.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen(
      {super.key,
      required this.service,
      this.userId,
      required this.onAccepted,
      required this.onLogin,
      required this.onClose});
  final AccountDeletionService service;
  final String? userId;
  final Future<void> Function() onAccepted;
  final Future<void> Function() onLogin;
  final VoidCallback onClose;
  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _confirmation = TextEditingController();
  final _scroll = ScrollController();
  String? _status;
  String? _error;
  bool _busy = false;
  bool _recentLoginRequired = false;
  bool _localCleanupDone = false;
  Timer? _poll;
  bool get _accepted => _status != null;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _confirmation.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy) return;
    try {
      final status = await widget.service.status();
      if (!mounted) return;
      if (status == null) {
        if (widget.userId == null) {
          setState(() => _error = 'La richiesta non risulta confermata. '
              'Accedi all’app e torna in Profilo → Elimina account, '
              'oppure contatta il titolare dalla pagina dedicata.');
        }
        return;
      }
      _updateStatus(status);
      await _completeLocally();
      _scheduleCheck();
    } catch (_) {
      if (mounted) {
        setState(() => _error = _accepted
            ? 'Connessione non disponibile. La richiesta resta in elaborazione.'
            : 'Connessione non disponibile. Non possiamo verificare la richiesta.');
      }
      _scheduleCheck();
    }
  }

  void _scheduleCheck() {
    _poll?.cancel();
    if (mounted &&
        _accepted &&
        (_status != 'completed' || !_localCleanupDone)) {
      _poll = Timer(const Duration(seconds: 5), _check);
    }
  }

  void _updateStatus(String status) {
    final changed = _status != status;
    setState(() { _status = status; _error = null; });
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  Future<void> _completeLocally() async {
    if (!_localCleanupDone) {
      await widget.onAccepted();
      _localCleanupDone = true;
    }
  }

  Future<void> _delete() async {
    if (_busy || _confirmation.text != 'ELIMINA') return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await widget.service.request(widget.userId ?? '');
      if (!mounted) return;
      _updateStatus(status);
      await _completeLocally();
      _scheduleCheck();
    } on RecentLoginRequired {
      if (mounted) {
        setState(() {
          _recentLoginRequired = true;
          _error = 'Per proteggere il tuo account, accedi di nuovo e torna in '
              'Profilo → Elimina account.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = _accepted
            ? 'Richiesta ricevuta. Non è stato possibile completare la pulizia '
                'su questo dispositivo. Riprova o riavvia l’app.'
            : 'Non possiamo confermare la richiesta. Verifica la connessione e '
                'premi Riprova: controlleremo prima se è già stata ricevuta.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_accepted && !_busy,
      child: Scaffold(
        appBar: AppBar(
            title: const Text('Elimina account'),
            automaticallyImplyLeading: !_accepted && !_busy),
        body: SafeArea(
            child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
                _status == 'completed'
                    ? Icons.check_circle_outline
                    : Icons.person_remove_outlined,
                size: 48,
                color: _status == 'completed'
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error),
            const SizedBox(height: 20),
            Text(
                _status == 'completed'
                    ? 'Account eliminato'
                    : _accepted
                        ? 'Eliminazione in corso'
                        : 'Eliminare il tuo account?',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(_status == 'completed'
                ? 'Account, dati personali e foto conservati per 4athletes sono '
                    'stati eliminati dal servizio attivo.'
                : _accepted
                    ? 'La richiesta è stata ricevuta. Sei stato disconnesso e i dati '
                        'personali dell’app sono stati rimossi. Stiamo completando '
                        'l’eliminazione del login e delle foto. Puoi chiudere questa '
                        'schermata: la procedura continuerà automaticamente.'
                    : 'Verranno eliminati il login, il profilo, la foto, gli '
                        'allenamenti personali, i dati salute importati, i consensi '
                        'e le tue risposte alle convocazioni. L’operazione è definitiva.'),
            const SizedBox(height: 16),
            const Text(
                'I dati degli altri atleti e le attività condivise della '
                'squadra restano disponibili, senza i tuoi riferimenti personali. '
                'Se sei l’ultimo responsabile, la squadra resterà da riassegnare. '
                'Puoi nominare prima un altro responsabile dalla squadra.'),
            const SizedBox(height: 16),
            const Text('I dati originali in Health Connect o Apple Health e le '
                'copie che hai esportato personalmente restano sui rispettivi '
                'servizi/dispositivi.'),
            TextButton(
                onPressed: () => openLegalPage(context, accountDeletionUrl),
                child: const Text('Dettagli sulla cancellazione')),
            if (!_accepted && widget.userId != null) ...[
              TextField(
                  controller: _confirmation,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                      labelText: 'Scrivi ELIMINA per confermare'),
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: _busy ||
                          _confirmation.text != 'ELIMINA' ||
                          _recentLoginRequired
                      ? null
                      : _delete,
                  style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError),
                  child: Text(_busy
                      ? 'Invio della richiesta…'
                      : 'Elimina definitivamente')),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              if (_recentLoginRequired)
                TextButton(
                    onPressed: widget.onLogin,
                    child: const Text('Accedi di nuovo'))
              else
                TextButton(
                    onPressed: _busy
                        ? null
                        : (_accepted || widget.userId == null)
                            ? _check
                            : _delete,
                    child: const Text('Riprova')),
            ],
            if (_accepted || widget.userId == null) ...[
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: widget.onClose,
                  child: const Text('Torna all’accesso')),
            ],
          ],
        )),
      ),
    );
  }
}
