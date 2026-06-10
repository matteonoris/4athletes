import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme.dart';
import '../services/health_service.dart';
import 'notification_permission_screen.dart';

class HealthPermissionScreen extends StatefulWidget {
  const HealthPermissionScreen({super.key});

  @override
  State<HealthPermissionScreen> createState() => _HealthPermissionScreenState();
}

class _HealthPermissionScreenState extends State<HealthPermissionScreen> {
  bool _isLoading = false;

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);

    final result = await HealthService().requestPermissionsDetailed();

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.isGranted) {
        _navigateToHome();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ??
                'Permessi non concessi completamente. Puoi gestirli in seguito.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const NotificationPermissionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platformName = Platform.isIOS ? 'Apple Health' : 'Health Connect';
    final settingsLabel = Platform.isIOS
        ? 'Apri Impostazioni / Salute'
        : 'Apri Impostazioni Health Connect';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.health_and_safety,
                      color: AppTheme.primary, size: 64),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'I TUOI DATI SALUTE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                platformName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                Platform.isIOS
                    ? 'Per offrirti analisi dettagliate su allenamento, recupero e sonno, 4ATHLETES richiede accesso ai dati Apple Health supportati.'
                    : 'Per offrirti analisi dettagliate su allenamento, recupero e sonno, 4ATHLETES richiede accesso a Health Connect. Se non e installato, ti porteremo al Play Store.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 14),
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
                      _buildPermissionItem(
                          PhosphorIconsRegular.heartbeat,
                          'Frequenza cardiaca & HRV',
                          'Per valutare sforzo, recupero e carico interno.'),
                      _buildPermissionItem(
                          PhosphorIconsRegular.personSimpleRun,
                          'Allenamenti, passi e distanze',
                          'Per importare sessioni e volume di allenamento.'),
                      _buildPermissionItem(
                          PhosphorIconsRegular.fire,
                          'Calorie attive',
                          'Per stimare consumo energetico e intensita.'),
                      _buildPermissionItem(
                          PhosphorIconsRegular.thermometer,
                          'Parametri vitali',
                          'SpO2, temperatura, respirazione, peso e altezza.'),
                      _buildPermissionItem(
                          PhosphorIconsRegular.drop,
                          'Ciclo mestruale',
                          'Per personalizzare recupero e fasi fisiologiche.'),
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
                        _requestPermissions();
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
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Consenti e completa',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  openAppSettings();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(settingsLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _navigateToHome();
                },
                child: Text('Salta per ora',
                    style: TextStyle(
                        color: AppTheme.textMediumEmphasis,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: AppTheme.textMediumEmphasis, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
