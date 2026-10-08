import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController(text: 'Skiing');
  bool _isCreated = false;
  String _generatedCode = '';
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_creating || _nameCtrl.text.trim().isEmpty) return;
    setState(() => _creating = true);
    try {
      final team = await context.read<AppState>().addTeam(Team(
          id: '',
          name: _nameCtrl.text.trim(),
          members: 0,
          category: _categoryCtrl.text.trim(),
          image: '',
          inviteCode: ''));
      if (mounted)
        setState(() {
          _generatedCode = team.inviteCode;
          _isCreated = true;
        });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Creazione non riuscita. Riprova.')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _generatedCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Codice copiato negli appunti!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crea un nuovo Team'),
        elevation: 0,
        backgroundColor: AppTheme.background,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isCreated ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Dai un nome al tuo Team',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Inserisci il nome del team per poter invitare i tuoi atleti o compagni di squadra.',
          style: TextStyle(
              fontSize: 14,
              color: AppTheme.textMediumEmphasis.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: 'Nome del Team',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AppTheme.surface,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _categoryCtrl,
          decoration: InputDecoration(
            labelText: 'Categoria / Sport',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AppTheme.surface,
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: !_creating && _nameCtrl.text.trim().length >= 3
              ? _handleCreate
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('CREA TEAM',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
              color: AppTheme.success, size: 48),
        ),
        const SizedBox(height: 24),
        const Text(
          'Team Creato con Successo!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Condividi questo codice di invito con le persone che vuoi far unire al tuo team:',
          style: TextStyle(fontSize: 14, color: AppTheme.textMediumEmphasis),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.panelDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.secondary.withValues(alpha: 0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondary.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                _generatedCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontFamily: 'monospace',
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _copyCode,
                icon: Icon(PhosphorIcons.copy(), size: 18),
                label: const Text('Copia Codice'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textHighEmphasis,
                  side: BorderSide(color: AppTheme.subtleBorder),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.card,
            foregroundColor: AppTheme.textHighEmphasis,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Torna ai Teams',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }
}
