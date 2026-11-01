# Luoghi degli allenamenti

## Inserimento manuale — 1 novembre 2026

Il campo **Luogo** è manuale: non propone risultati e non invia il testo a Photon
o ad altri servizi di geocodifica. Il componente condiviso copre creazione degli
allenamenti, sci alpino, preparazione atletica e dettagli eventi del coach.
Il servizio `PlaceSearchService`, la cache delle ricerche e l'opzione
`PHOTON_API_URL` sono stati rimossi, non soltanto nascosti nella UI.

`location` resta una stringa salvata nei normali payload di bozze, sessioni e
attività. I luoghi storici con `locationPlace` rimangono leggibili e mantengono
le coordinate quando non si modifica il campo. Cambiare o cancellare il testo
rimuove le coordinate precedenti. Nessuna migrazione o cancellazione di dati
server è necessaria; la preparazione non ha modificato il backend.

## Mappe esistenti

Le anteprime dei luoghi già provvisti di coordinate restano disponibili con
`flutter_map` e tile `https://tile.openstreetmap.org/{z}/{x}/{y}.png`.
“Apri mappa” apre OSM sulle coordinate salvate. Queste richieste non sono ricerche
Photon e continuano a richiedere una valutazione separata di posizione e dati
tecnici. Attribuzione, cache, errore/riprova e configurazione `OSM_TILE_URL`
restano invariati. Non dichiarare che l'intera app sia priva di servizi esterni.

## App Privacy e stato del rilascio

La rimozione riguarda il nuovo sorgente. La build iOS **1.0.4 (37)** già allegata
alla bozza App Store usa ancora Photon: non pubblicare dichiarazioni basate sul
nuovo comportamento prima di preparare e verificare una nuova build.
La digitazione manuale non crea una cronologia di ricerca remota; il luogo
salvato rimane un dato dell'allenamento, con le dichiarazioni sulla posizione
pertinenti. Non sono state pubblicate etichette privacy o inviate app in revisione.
Nessuna build, tag, workflow, nuovo servizio o costo è stato avviato.

## Verifica

Esito del 1 novembre 2026: **73 test superati**, analisi dei tre file Dart
modificati senza problemi e `git diff --check` superato. Nessun riferimento
Photon/`PlaceSearchService`/`PHOTON_API_URL` rimasto in `lib/`, `test/` o nei
workflow GitHub. Nessuna verifica su dispositivo fisico o nuovo IPA effettuata.

Comandi eseguiti da `flutter_mobile`:

```text
flutter test test/workout_location_widgets_test.dart test/workout_place_test.dart test/workout_flow_screen_test.dart test/workout_creation_flow_test.dart test/running_workout_flow_test.dart test/activity_select_workout_flow_test.dart test/workout_summary_screen_test.dart
flutter analyze --no-pub lib/widgets/workout_location_field.dart test/workout_location_widgets_test.dart test/workout_place_test.dart
```

- Widget: testo manuale, modifica/cancellazione di coordinate storiche e assenza
  di tentativi di connessione durante la digitazione, in entrambi i temi.
- Modelli: testo manuale preservato in salvataggio/ripristino locale e conversioni
  fra bozza, sessione e attività; regressioni dei luoghi storici e mappe.
- Flussi: regressioni creazione allenamento, corsa, selezione attività e riepilogo.

Riferimenti: [policy tile OSM](https://operations.osmfoundation.org/policies/tiles/),
[cache flutter_map](https://docs.fleaflet.dev/layers/tile-layer/caching).
