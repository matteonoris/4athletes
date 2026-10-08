import 'package:flutter/material.dart';

Future<void> showAppleHealthAccessDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Accesso ad Apple Salute'),
      content: const SingleChildScrollView(
        child: Text(
          'Apri l’app Salute sul tuo iPhone e tocca la foto del profilo. '
          'In App (o App e servizi), seleziona 4athletes e abilita la '
          'lettura di Sonno e dei parametri vitali che vuoi importare.\n\n'
          'Questi interruttori si gestiscono in Salute e possono non '
          'comparire nelle impostazioni generiche di 4athletes.\n\n'
          'Se 4athletes o Sonno non compaiono, torna nell’app e richiedi '
          'l’accesso da Profilo → Consensi Salute. iOS può non riproporre '
          'la finestra per permessi già richiesti.\n\n'
          'Per importare il sonno, devono esserci registrazioni in '
          'Salute → Sonno. Nessun dato importato può indicare dati assenti '
          'oppure accesso disattivato: iOS non comunica la differenza all’app.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Ho capito'),
        ),
      ],
    ),
  );
}
