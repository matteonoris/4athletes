import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import 'create_team_screen.dart';
import 'team_detail_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  void _showJoinModal(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Chiudi',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _JoinTeamModal();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final teams = appState.teams;

    return Scaffold(
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                backgroundColor: AppTheme.background.withValues(alpha: 0.95),
                pinned: true,
                elevation: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(
                      color: Colors.white.withValues(alpha: 0.05), height: 1),
                ),
                title: const Text(
                  'I tuoi Team',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(PhosphorIcons.user(),
                          size: 20, color: AppTheme.textMediumEmphasis),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),

              // Body
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (teams.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(PhosphorIcons.users(),
                                size: 48,
                                color: AppTheme.textMediumEmphasis
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(
                              'Non sei ancora in nessun team.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textMediumEmphasis
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...teams.map((team) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => TeamDetailScreen(team: team)),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Ink(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.05)),
                                  ),
                                  child: Row(
                                    children: [
                                      // Team Image or Placeholder
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.1)),
                                          image: team.image.isNotEmpty && team.image.startsWith('http')
                                              ? DecorationImage(
                                                  image:
                                                      NetworkImage(team.image),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: team.image.isEmpty || !team.image.startsWith('http')
                                            ? const Center(
                                                child: Icon(Icons.group,
                                                    color: AppTheme
                                                        .textMediumEmphasis))
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      // Team Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              team.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${team.members} Membri • ${team.category}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppTheme.textMediumEmphasis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Invite Code Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.secondary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: AppTheme.secondary
                                                  .withValues(alpha: 0.2)),
                                        ),
                                        child: Text(
                                          team.inviteCode,
                                          style: const TextStyle(
                                            color: AppTheme.secondary,
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )),

                    const SizedBox(height: 32),

                    // Join Team CTA Card
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showJoinModal(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            // Dashed effect isn't native, so we simulate it with a solid border for now,
                            // or use a package. Since we're keeping it simple, let's use a solid border
                            // with low opacity or a custom painter if needed. Here we use a subtle border.
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              style: BorderStyle.solid,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.secondary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(PhosphorIcons.qrCode(),
                                    color: AppTheme.secondary, size: 24),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Hai un codice invito?',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Unisciti immediatamente ad un team usando un codice o un link.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMediumEmphasis),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'INSERISCI CODICE',
                                    style: TextStyle(
                                      color: AppTheme.secondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(PhosphorIcons.arrowRight(),
                                      size: 12, color: AppTheme.secondary),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),

          // Floating Action Button
          Positioned(
            bottom:
                24, // Keep it above nav bar (bottom nav bar is handled by home scaffold usually)
            right: 16,
            child: Material(
              elevation: 8,
              shadowColor: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
              color: Colors.white,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateTeamScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(30),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.plus(), size: 20, color: Colors.black),
                      const SizedBox(width: 8),
                      const Text(
                        'CREA TEAM',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// JOIN MODAL
// ---------------------------------------------------------

class _JoinTeamModal extends StatefulWidget {
  const _JoinTeamModal();

  @override
  State<_JoinTeamModal> createState() => _JoinTeamModalState();
}

class _JoinTeamModalState extends State<_JoinTeamModal> {
  final _codeCtrl = TextEditingController();
  String _joinStatus = 'idle'; // idle, loading, success, error

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _handleJoin() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 4) return;

    setState(() => _joinStatus = 'loading');

    try {
      final supabase = Supabase.instance.client;
      final appState = Provider.of<AppState>(context, listen: false);

      // 1. Fetch team by invite code
      final teamResponse = await supabase
          .from('teams')
          .select()
          .eq('invite_code', code)
          .maybeSingle();

      if (teamResponse == null) {
        setState(() => _joinStatus = 'error');
        return;
      }

      final String teamId = teamResponse['id'];
      final int currentMembers = teamResponse['members'] ?? 0;

      // 2. Update user profile team_id
      await supabase
          .from('profiles')
          .update({'team_id': teamId})
          .eq('id', appState.userId);

      // 3. Increment team members count
      await supabase
          .from('teams')
          .update({'members': currentMembers + 1})
          .eq('id', teamId);

      // 4. Reload app state to sync
      await appState.init();

      if (!mounted) return;
      setState(() => _joinStatus = 'success');
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error joining team: $e');
      setState(() => _joinStatus = 'error');
    }
  }

  void _pasteCode() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      setState(() {
        _codeCtrl.text = data!.text!
            .toUpperCase()
            .substring(0, data.text!.length > 8 ? 8 : data.text!.length);
        _joinStatus = 'idle';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close Button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon:
                    const Icon(Icons.close, color: AppTheme.textMediumEmphasis),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            // Header Image
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.secondary, AppTheme.primary],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.secondary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.qr_code, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unisciti al Team',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Prova i codici 'ROME88' o 'MIL400'",
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMediumEmphasis.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),

            // Input Field
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _joinStatus == 'error'
                      ? AppTheme.error
                      : (_codeCtrl.text.isNotEmpty
                          ? AppTheme.secondary
                          : Colors.white.withValues(alpha: 0.1)),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TextField(
                    controller: _codeCtrl,
                    textAlign: TextAlign.center,
                    enabled:
                        _joinStatus != 'loading' && _joinStatus != 'success',
                    onChanged: (_) => setState(() => _joinStatus = 'idle'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: Colors.white,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'CODICE',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                  ),
                  if (_codeCtrl.text.isEmpty)
                    Positioned(
                      right: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _pasteCode,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            child: Row(
                              children: [
                                Icon(PhosphorIcons.clipboard(),
                                    size: 14, color: AppTheme.secondary),
                                const SizedBox(width: 4),
                                const Text(
                                  'INCOLLA',
                                  style: TextStyle(
                                      color: AppTheme.secondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (_joinStatus == 'error')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIcons.warningCircle(),
                        color: AppTheme.error, size: 16),
                    const SizedBox(width: 8),
                    const Text('Codice non valido o già in uso',
                        style: TextStyle(color: AppTheme.error, fontSize: 14)),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_codeCtrl.text.isEmpty ||
                        _joinStatus == 'loading' ||
                        _joinStatus == 'success')
                    ? null
                    : _handleJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _joinStatus == 'success'
                      ? AppTheme.success
                      : Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _joinStatus == 'loading'
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : _joinStatus == 'success'
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIcons.checkCircle(),
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              const Text('Benvenuto!',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Unisciti',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Icon(PhosphorIcons.arrowRight(), size: 16),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
