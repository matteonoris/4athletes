/// Emitted only after a fresh calculation has been saved, never for cache reads.
class HealthScoreUpdate {
  final int revision;
  final String dateKey;
  final double sleepScore;
  final double? recoveryScore;
  final bool systemNotificationShown;

  const HealthScoreUpdate(
      {required this.revision,
      required this.dateKey,
      required this.sleepScore,
      this.recoveryScore,
      this.systemNotificationShown = false});

  String get title => recoveryScore == null
      ? 'Il punteggio del sonno è pronto'
      : 'I tuoi punteggi sono pronti';

  String get message => recoveryScore == null
      ? 'Sonno aggiornato. Per il recupero servono ancora dati.'
      : 'Sonno e recupero aggiornati. Scopri come stai oggi.';
}
