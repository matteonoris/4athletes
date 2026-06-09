import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import '../services/training_reminder_notification_service.dart';
import 'home_screen.dart';

class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  State<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends State<NotificationPermissionScreen> {
  bool _isLoading = false;

  Future<void> _enableReminder() async {
    setState(() => _isLoading = true);
    final appState = Provider.of<AppState>(context, listen: false);
    final granted = await TrainingReminderNotificationService.instance
        .requestPermissionAndSchedule();

    if (appState.userProfile != null) {
      appState.userProfile!.notificationsEnabled = granted;
      appState.updateProfile(appState.userProfile!);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (granted) {
      _navigateToHome();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Permesso notifiche non concesso. Puoi attivarlo dal Profilo.',
        ),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _skipReminder() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.userProfile != null) {
      appState.userProfile!.notificationsEnabled = false;
      appState.updateProfile(appState.userProfile!);
    }
    TrainingReminderNotificationService.instance.cancelDailyTrainingReminder();
    _navigateToHome();
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppTheme.card,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active,
                      color: AppTheme.secondary, size: 64),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'REMINDER SERALE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Non perdere il lavoro di oggi',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ogni sera verso le 21:00 ti ricordiamo di registrare gli allenamenti svolti. Bastano pochi secondi per tenere aggiornati carico, recupero e progressi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: ListView(
                    children: [
                      _buildItem(
                        PhosphorIconsRegular.clockCountdown,
                        'Alle 21:00',
                        'Un promemoria ricorrente alla fine della giornata.',
                      ),
                      _buildItem(
                        PhosphorIconsRegular.timer,
                        'Solo 30 secondi',
                        'Apri l’app, registra la sessione e chiudi il cerchio.',
                      ),
                      _buildItem(
                        PhosphorIconsRegular.chartLineUp,
                        'Dati piu completi',
                        'Meno sessioni dimenticate, analisi piu affidabili.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _enableReminder();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Attiva reminder',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _skipReminder();
                      },
                child: const Text(
                  'Non ora',
                  style: TextStyle(
                    color: AppTheme.textMediumEmphasis,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.secondary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textMediumEmphasis,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
