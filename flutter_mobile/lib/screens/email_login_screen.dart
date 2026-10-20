import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';

/// Password access uses ordinary Auth and the same consent gate as social login.
class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key, required this.onSignIn});

  final Future<void> Function(String email, String password) onSignIn;

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSignIn(_email.text.trim().toLowerCase(), _password.text);
      if (!mounted) return;
      TextInput.finishAutofillContext();
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _messageFor(error);
      });
    }
  }

  String _messageFor(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'Email o password non corrette.';
        case 'email_not_confirmed':
          return 'Conferma la tua email prima di accedere.';
        case 'over_request_rate_limit':
        case 'over_email_send_rate_limit':
          return 'Troppi tentativi. Attendi qualche minuto e riprova.';
        case 'age_restricted':
          return 'Per usare 4athletes devi aver compiuto 14 anni.';
        case 'profile_unavailable':
          return 'Il profilo non è disponibile. Riprova o contatta l’assistenza.';
      }
    }
    return 'Accesso non riuscito. Verifica la connessione e riprova.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Accedi con email')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child:
                                Icon(Icons.mail_outline, color: colors.primary),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Bentornato',
                            style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 12),
                        Text(
                          'Accedi con l’email e la password del tuo account già registrato.',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          key: const Key('email-login-email'),
                          controller: _email,
                          enabled: !_busy,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          validator: (value) =>
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(value?.trim() ?? '')
                                  ? null
                                  : 'Inserisci un indirizzo email valido.',
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          key: const Key('email-login-password'),
                          controller: _password,
                          enabled: !_busy,
                          obscureText: _obscure,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'Mostra password'
                                  : 'Nascondi password',
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Inserisci la password.'
                              : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(_error!,
                                style: TextStyle(color: colors.error)),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Accedi'),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Se ti sei registrato con Google o Apple, torna indietro e usa lo stesso metodo.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
