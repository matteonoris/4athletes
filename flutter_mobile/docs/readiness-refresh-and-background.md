# Punteggi Home, navigazione e background

Aggiornato il 15 settembre 2026.

## Comportamento implementato

- La Home usa la stessa scheda per sonno, sforzo e recupero. Al primo caricamento mostra tre indicatori che pulsano lentamente, senza percentuali inventate. Durante un aggiornamento mantiene visibili i punteggi precedenti. Supporta temi chiaro/scuro, testo ingrandito e animazioni ridotte.
- Il calcolo appartiene ad `AppState`, sopra la navigazione. Aprire altre schermate, rientrare nella Home o consultare un altro giorno non annulla il lavoro. Le richieste compatibili condividono il calcolo; richieste per giorni diversi vengono eseguite in sequenza.
- La data visualizzata e quella del calcolo sono distinte. Un risultato aggiorna cache e serie storiche della propria data senza cambiare il giorno che l’utente sta consultando. Si conserva la gestione precedente dei dati mancanti e degli errori, insieme alla versione dell’algoritmo in cache.
- Solo un nuovo risultato calcolato e salvato emette l’evento di completamento. Leggere la cache non genera avvisi. Un errore non annuncia un successo. L’avviso di oggi distingue il sonno pronto dal recupero ancora privo di dati sufficienti.
- Dentro l’app compare un banner in alto, sopra qualsiasi schermata, con un’azione per aprire i punteggi. Il banner può essere chiuso; scompare dopo sette secondi, salvo l’impostazione di accessibilità che richiede interazioni più stabili.
- Fuori dall’app viene inviata una notifica locale se l’utente ha già attivato le notifiche dell’app e autorizzato quelle di sistema. Il calcolo non richiede nuovamente il permesso. Quando le notifiche sono disattivate, l’avviso viene mostrato al rientro. Le notifiche non espongono valori biometrici.

## Cambio di app e spegnimento dello schermo

Su Android, il lavoro avviato dall’app visibile usa un servizio `dataSync` con notifica silenziosa di avanzamento. Il servizio termina alla conclusione del lavoro, alla rimozione del task o dopo un massimo di cinque minuti. Non riparte dal boot e non mantiene il telefono attivo indefinitamente. L’uso del servizio per proseguire letture iniziate in primo piano è previsto dalla [documentazione Health Connect](https://developer.android.com/health-and-fitness/health-connect/read-data); il tipo `dataSync` copre importazioni e trasferimenti di dati secondo la [documentazione Android](https://developer.android.com/develop/background-work/services/fgs/service-types#data-sync).

Su iOS, il calcolo richiede una finestra di esecuzione con `beginBackgroundTask`, rilasciata al completamento o alla scadenza. È una possibilità di terminare il lavoro in corso, non una garanzia di esecuzione continua: [Apple limita il tempo disponibile](https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(expirationhandler:)). Inoltre, con il dispositivo bloccato la cifratura di HealthKit può impedire le letture: [protezione dei dati HealthKit](https://developer.apple.com/documentation/healthkit/protecting-user-privacy).

Un indicatore locale, separato per account, registra il lavoro iniziato. Se il processo viene terminato, alla successiva apertura l’aggiornamento di oggi può ripartire senza attendere il normale intervallo di quindici minuti. Non si ricrea un isolate Flutter dopo una chiusura forzata. Il logout invalida gli esiti del calcolo precedente.

## Calcolo automatico al risveglio: fattibilità e passo successivo

Questa modifica **non avvia ancora l’app chiusa al risveglio**. L’evento corretto da osservare è l’arrivo di nuovi dati del sonno dal wearable, che può avvenire dopo il risveglio e in più aggiornamenti.

Su iOS si può usare `HKObserverQuery` per il sonno, con Background Delivery e relativo entitlement, per essere richiamati quando HealthKit riceve campioni. Occorrono un percorso di esecuzione senza schermata, gestione del dispositivo bloccato e verifiche su iPhone reale. Apple descrive esplicitamente il richiamo all’arrivo dei campioni e la frequenza massima, non un orario di risveglio garantito: [observer queries](https://developer.apple.com/documentation/healthkit/executing-observer-queries).

Su Android il percorso per un’app non visibile richiede disponibilità della funzione, permesso `READ_HEALTH_DATA_IN_BACKGROUND` e un worker pianificato, come nell’[esempio ufficiale Health Connect](https://developer.android.com/health-and-fitness/health-connect/read-data#background-read-example). Questa integrazione va distinta dal servizio che completa il calcolo già avviato. L’orario effettivo dipende dal sistema e da quando il wearable esporta i dati.

Per una successiva implementazione, usare la data di risveglio e una firma dei dati sorgente per evitare calcoli e notifiche duplicati; ricalcolare quando una notte inizialmente parziale viene completata. L’avvio in background deve riutilizzare lo stesso algoritmo, versionamento e regole di persistenza di Home e grafici.

## Verifica

I test `app_state_health_job_test.dart` coprono richieste duplicate, navigazione durante il calcolo, completamento su una data non visualizzata, aggiornamento delle serie e errori. `readiness_presentation_test.dart` verifica temi, schermi stretti, accessibilità, navigazione con banner globale, deduplicazione e avviso al rientro quando le notifiche sono disabilitate.

La prova nativa su dispositivi reali deve includere: avvio del calcolo e cambio app, blocco/sblocco schermo, revoca dei permessi, arrivo ritardato dei dati del wearable, notifica e apertura dei punteggi dal suo tocco. La compilazione iOS e questi comportamenti di sistema non sono verificabili mediante i soli widget test su Windows.
