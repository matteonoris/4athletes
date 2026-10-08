# Importazione esercizi da foto e PDF

Nella creazione/modifica di un allenamento, ogni fase abilitata che usa esercizi
ha il pulsante **Importa da foto o PDF**. L'atleta può scattare una foto, scegliere
un'immagine dalla galleria oppure aprire un PDF. Il pulsante è disponibile su
Android e iOS; corsa e modulo dedicato dello sci alpino restano invariati.

La lettura avviene sul dispositivo: ML Kit con modello latino incluso su Android,
Apple Vision su iOS. I PDF, anche scansioni, vengono renderizzati una pagina alla
volta tramite PdfRenderer/PDFKit. Non sono necessari chiavi API, un servizio AI,
Storage o modifiche a Supabase. Limiti: 15 MB, 6 pagine PDF, lato massimo raster
2400 pixel; fino a 100 esercizi e 50 serie per esercizio.

## Revisione

- Foto/PDF producono esclusivamente una bozza. Il programma del preparatore non
  costituisce una conferma degli esercizi svolti: l'utente seleziona gli esercizi,
  corregge i valori e conferma. Il salvataggio dell'allenamento resta separato.
- Formati supportati: `Squat 3x10 40 kg rec 90s`, `Plank 3x30"`,
  `Sprint 4x200m`, `Panca 3x12/10/8`, campi etichettati in italiano/inglese
  e tabelle con intestazioni esplicite per serie/ripetizioni/carico/recupero.
  Le tabelle con prescrizioni compatte (`5×3`, `4X8`) sono supportate anche
  senza intestazione, con il nome prima o dopo la prescrizione e celle su più
  righe. Si usano posizione, larghezza e, quando disponibili, coordinate delle
  parole per ricostruire le celle prima di interpretare i numeri.
- RPE, RIR, durata e distanza possono essere verificati nei dettagli. Dati assenti
  restano vuoti. Intervalli di ripetizioni, carichi variabili e percentuali restano
  nelle note e richiedono correzione; non si inventano kg o ripetizioni.
- Il recupero generale sopra la tabella viene riportato in ciascun esercizio,
  salvo un recupero specifico. `2'-3' minuti` rimane un intervallo nelle note,
  con un avviso: il campo secondi resta vuoto. `2 minuti` diventa 120 secondi.
  Il contesto non passa alla pagina o sezione successiva.
- Intestazioni e righe non interpretate sono segnalate; l'intero testo OCR è
  consultabile e correggibile. Le righe tagliate senza nome non diventano
  esercizi; le sigle di gruppo (es. `A`) non diventano nomi.
  Schede con più tabelle affiancate, manoscritte, foto sfocate o circuiti
  complessi possono richiedere correzione
  del testo o inserimento manuale. Non si tratta di un interprete semantico AI.
- Gli esercizi selezionati vengono aggiunti alla fase corrente, conservando gli
  esistenti. Nel principale di Conditioning si aggiungono al circuito presente.
- I nomi e gli alias del catalogo vengono confrontati ignorando maiuscole,
  accenti, spazi e punteggiatura. Sono inclusi sinonimi italiani come `Squat`
  → `Back Squat`, `Panca piana` → `Bench Press`, `Stacco` → `Deadlift` e
  `Military press` → `Overhead Press (Barbell)`. Una corrispondenza unica salva
  il nome canonico, `exerciseId`, muscolo, attrezzo e modalità di tracciamento:
  storico e massimali usano lo stesso ID degli esercizi scelti manualmente.
- L'anteprima mostra il collegamento e consente di cambiarlo cercando nel
  catalogo, scegliere un suggerimento o mantenere un esercizio personalizzato.
  Somiglianze/refusi generano soltanto suggerimenti; alternative come
  `Lat machine / Trazioni` richiedono la scelta dell'esercizio svolto.
  Modificare il nome ricalcola il collegamento, evitando ID rimasti da una
  scelta precedente. Esercizi assenti nel catalogo restano personalizzati.
- L'associazione mantiene prescrizione originale, serie, ripetizioni, kg,
  recupero e note. Non riempie i dati mancanti con i valori predefiniti del
  catalogo e non converte automaticamente intervalli percentuali in kg.
- La bozza salva `importSource: document_ocr`, `sourceText`, le note e i valori
  di ogni serie nel payload `WorkoutBlockDraft` già esistente. Non salva il file.

## Verifica

```powershell
flutter test test/exercise_catalog_matcher_test.dart test/workout_document_layout_test.dart test/workout_document_parser_test.dart test/workout_document_import_screen_test.dart test/workout_document_phase_import_test.dart test/workout_creation_flow_test.dart test/workout_flow_screen_test.dart
flutter test integration_test/workout_document_ocr_test.dart -d emulator-5554
```

Il test di integrazione genera un PNG trasparente e un PDF multipagina e li legge
con l'OCR nativo. I widget test verificano la revisione nei temi chiaro/scuro.
I test del catalogo coprono sinonimi, varianti, refusi, scelta manuale,
personalizzati e persistenza dell'identità. Un test del flusso completo verifica
che lo Squat importato mostri il massimale già registrato e la percentuale del
carico, nei temi chiaro/scuro, conservando l'ID nel formato di salvataggio.
La fixture `test/fixtures/workout_table_spans.dart` annota manualmente testo e
coordinate della schermata Canva fornita: Squat 5×3, Stacco 5×2, Cable
pull-through 4×8, Military press 5×5, Lat machine / Trazioni con zavorra 4×6,
Panca Piana 4×5. Verifica tre scale, ordine OCR mescolato, celle unite, percentuali,
recupero comune, riga tagliata e conservazione delle note dopo conferma.
Questi test verificano il layout e l'importazione; non sostituiscono il
riconoscimento della foto con ML Kit/Vision sul telefono.
La correzione della tabella è verificata con test Dart/widget senza avviare
emulatori. La prova nativa sull'immagine reale resta da eseguire sul cellulare.
Per iOS eseguire lo stesso test su un simulatore o
dispositivo tramite macOS/Xcode prima di una release. Nessuna release automatica
è parte di questa modifica.

Riferimenti di implementazione: [ML Kit Android](https://developers.google.com/ml-kit/vision/text-recognition/v2/android),
[Apple Vision](https://developer.apple.com/documentation/vision/recognizing-text-in-images),
[selettore file Flutter](https://pub.dev/packages/file_selector).
