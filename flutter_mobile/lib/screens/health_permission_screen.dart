import 'package:flutter/material.dart';
import '../widgets/health_consent_gate.dart';
import 'notification_permission_screen.dart';

/// Signup reaches app consent before operating-system permissions.
class HealthPermissionScreen extends StatelessWidget {
  const HealthPermissionScreen({super.key});
  @override
  Widget build(BuildContext context) => const HealthConsentGate(
      existingUser: false, child: NotificationPermissionScreen());
}
