import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../screens/health_consent_screen.dart';
import '../services/health_consent_service.dart';
import '../services/health_service.dart';

String get healthProviderName =>
    Platform.isIOS ? 'Apple Health' : 'Health Connect';

/// Only an explicit acceptance opens OS permissions. Later imports silently
/// check the saved choice. OS denial does not erase the saved app consent.
Future<void> acceptHealthConsent(AppState state, BuildContext context) async {
  final owner = state.userId;
  await state.setHealthConsent(HealthConsentDecision.granted);
  if (!context.mounted || state.userId != owner || !state.canImportHealthData) {
    return;
  }
  try {
    final result = await HealthService().requestPermissionsDetailed();
    if (state.userId != owner || !state.canImportHealthData) return;
    if (result.isGranted) {
      await state.markHealthAccessEnabled();
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message ??
              'Puoi gestire i permessi salute dal Profilo.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Scelta salvata. Puoi collegare i dati salute dal Profilo.')));
    }
  }
}

class HealthConsentGate extends StatefulWidget {
  const HealthConsentGate(
      {super.key, required this.child, this.existingUser = true});
  final Widget child;
  final bool existingUser;
  @override
  State<HealthConsentGate> createState() => _HealthConsentGateState();
}

class _HealthConsentGateState extends State<HealthConsentGate> {
  bool _choosing = false;
  Future<void> _choose(bool accept) async {
    setState(() => _choosing = true);
    final state = context.read<AppState>();
    try {
      if (accept) {
        await acceptHealthConsent(state, context);
      } else {
        await state.setHealthConsent(HealthConsentDecision.declined);
      }
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final consent = state.healthConsent;
    if (!_choosing && consent.loaded && consent.decision != null) {
      return widget.child;
    }
    if (!_choosing && !consent.loaded) {
      return Scaffold(
          body: SafeArea(
              child: Center(
                  child: consent.loadFailed
                      ? Column(mainAxisSize: MainAxisSize.min, children: [
                          const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                  'Non è stato possibile verificare la scelta sui dati salute.')),
                          FilledButton(
                              onPressed: state.loadHealthConsent,
                              child: const Text('Riprova')),
                          TextButton(
                              onPressed: state.logout,
                              child: const Text('Esci dall’account')),
                        ])
                      : const CircularProgressIndicator())));
    }
    return HealthConsentScreen(
        providerName: healthProviderName,
        existingUser: widget.existingUser,
        onAccept: () => _choose(true),
        onDecline: () => _choose(false));
  }
}

bool checkHealthImportEnabled(BuildContext context) {
  if (context.read<AppState>().canImportHealthData) return true;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:
          Text('Importazioni salute disattivate. Puoi gestirle dal Profilo.')));
  return false;
}
