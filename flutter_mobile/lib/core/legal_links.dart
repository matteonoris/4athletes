import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const privacyPolicyUrl = 'https://matteonoris.github.io/4athletes/privacy/';
const accountDeletionUrl =
    'https://matteonoris.github.io/4athletes/delete-account/';

Future<void> openLegalPage(BuildContext context, String url) async {
  try {
    if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {
    // Show the same actionable message for unavailable browser apps and errors.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossibile aprire la pagina. Riprova.')),
    );
  }
}
