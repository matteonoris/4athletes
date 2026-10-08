# Luoghi degli allenamenti

Il campo Luogo propone risultati dopo almeno 3 caratteri e 1 secondo senza
digitazione. Photon cerca località, indirizzi e impianti presenti in OpenStreetMap;
i nomi che iniziano con il testo digitato hanno precedenza. Si può sempre salvare
un testo libero: la mappa compare solo quando si seleziona un risultato.

Nome, indirizzo, coordinate e identificativo OSM sono salvati in `locationPlace`
nei payload JSON già usati da bozze, sessioni e dettagli tecnici del coach.
`location` resta una stringa leggibile. Nessuna migrazione del database è richiesta.
Le attività precedenti restano leggibili senza geocodifica automatica ambigua.
Modificare il testo elimina le coordinate precedenti.

## Servizi e limiti

- Ricerca: <https://photon.komoot.io/api/>. Nessuna chiave o fatturazione.
  Il server pubblico consente un utilizzo ragionevole, senza garanzia di
  disponibilità; traffico elevato può essere limitato o bloccato. La cache tiene
  le ultime 60 ricerche in memoria, le richieste identiche vengono accorpate e
  le risposte 429/503 attivano una pausa. I termini digitati vengono inviati a
  Photon; non viene richiesta la posizione GPS del dispositivo.
- Mappa: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, tramite flutter_map
  8.3.2, con cache persistente predefinita su mobile, identificativo dell'app,
  attribuzione visibile e nessun download anticipato di aree fuori anteprima.
  Sul web valgono la cache HTTP e il Referer del browser. La mappa è un'anteprima
  fissa; “Apri mappa” apre il sito OSM sulle coordinate selezionate.
- I servizi pubblici sono gratuiti ma non illimitati. Prima di una diffusione
  ampia va rivalutata la capacità: Photon può essere ospitato su infrastruttura
  propria. Non è stato attivato alcun servizio a pagamento.

Endpoint sostituibili tramite `--dart-define=PHOTON_API_URL=https://.../api/` e
`--dart-define=OSM_TILE_URL=https://.../{z}/{x}/{y}.png`. Il secondo deve fornire
tile raster OSM compatibili; per provider con ulteriori obblighi di attribuzione
va aggiornata anche l'attribuzione della UI. Cambiare queste opzioni richiede una
nuova build. Senza rete il testo resta modificabile e salvabile; la mappa offre
un messaggio e un pulsante per riprovare.

Riferimenti: [Photon](https://github.com/komoot/photon),
[policy tile OSM](https://operations.osmfoundation.org/policies/tiles/),
[cache flutter_map](https://docs.fleaflet.dev/layers/tile-layer/caching).

Verifica automatica: `flutter test test/place_search_service_test.dart
test/workout_place_test.dart test/workout_location_widgets_test.dart`.
