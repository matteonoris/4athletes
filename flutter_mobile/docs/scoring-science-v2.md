# Scoring science v2

Versione algoritmo: `wellness-scoring-v2.0.0`
Stato: evidence-informed, da validare prospetticamente
Ultimo aggiornamento: 2026-07-13

## Scopo e limiti d'uso

Sleep, strain e recovery sono indici di supporto al monitoraggio. Non sono
dispositivi medici, non diagnosticano malattia o sovrallenamento e non devono
prescrivere da soli una seduta. Per un atleta professionista il numero va
interpretato con trend, sintomi, percezione soggettiva, calendario, test di
performance e giudizio dello staff.

La versione 2 privilegia quattro principi:

1. confronto intra-atleta, con una baseline personale e robusta;
2. separazione tra misure realmente osservate e stime;
3. mancato punteggio o confidence ridotta quando i dati non bastano;
4. versione, componenti, metodi e warning conservati per rendere il calcolo
   auditabile.

I pesi attuali sono ipotesi iniziali motivate dalla letteratura, non coefficienti
clinicamente validati sul bacino utenti di 4athletes.

La source of truth di produzione è `flutter_mobile/lib/utils/scoring/`.
Il file root `backend_metrics.py` è un prototipo standalone legacy e non viene
importato dall'app.

## Sleep score v2

### Bisogno di sonno

Il riferimento personale usa le ultime 28 notti valide:

```text
target_età = 500 min se età >= 18 anni, 540 min se età <= 17 anni
baseline = max(target_età, percentile 75 del sonno notturno osservato)
```

Servono 7 notti per una baseline parziale e 14 per quella completa. Una storia
cronicamente corta non può quindi abbassare il target fisiologico. Il saldo di
sonno usa gli ultimi 7 giorni, con decadimento esponenziale `exp(-0.25 * età)`
e limite di +/-90 minuti. Un surplus recente può ripagare un deficit passato,
ma solo il saldo positivo aumenta il bisogno del giorno corrente.

I nap validi nel periodo precedente il risveglio entrano nel sonno effettivo
delle 24 ore. Non vengono sottratti dal bisogno. La precedente curva che
aggiungeva automaticamente fino a 45 minuti in funzione dello strain è
disattivata: non aveva una validazione sufficiente per trasformare un carico in
minuti di sonno prescritti.

### Componenti

```text
sleep_score =
    0.50 * durata_24h
  + 0.20 * adeguatezza_ultimi_7_giorni
  + 0.20 * efficienza
  + 0.10 * regolarità_circadiana
```

- `durata_24h`: `min(100, sonno_effettivo_24h / bisogno * 100)`;
- `adeguatezza_ultimi_7_giorni`: rapporto aggregato sonno/bisogno, con almeno
  3 giorni validi;
- `efficienza`: normalizzazione lineare tra 60% (0 punti) e 85% (100 punti);
- `regolarità`: variabilità di onset e risveglio su 14 giorni, con tolleranza
  iniziale di 30 minuti.

Deep e REM restano visibili ma non contribuiscono al punteggio. Le stime degli
stadi dei wearable hanno errori e bias device-specifici troppo rilevanti per
assegnare loro un peso numerico affidabile.

## Strain score v2

Lo strain distingue dimensioni che non devono essere duplicate:

- carico cardio interno;
- session-RPE (`durata_minuti * RPE_CR10`);
- esposizione/carico esterno sport-specifico.

### Carico cardio

La gerarchia dei dati è:

1. tempo in zone individualizzate con copertura sufficiente, usando i pesi
   Edwards `1, 2, 3, 4, 5` per Z1-Z5;
2. serie temporale HR, integrata con TRIMP basato sulla heart-rate reserve;
3. frequenza cardiaca media, marcata come stima;
4. componente non disponibile.

Il bucket Z0 sotto la prima soglia contribuisce alla copertura ma non al carico.
Il formato Health a sei bucket Z0-Z5 è distinto dal legacy a cinque bucket
Z1-Z5. Una copertura HR parziale può essere estrapolata, con warning e fattore
massimo 2.0. L'RPE non viene più riutilizzato come falso carico cardio.

### Carico esterno e normalizzazione

Quando presenti vengono usati dati osservati: distanza/dislivello, passi,
lavoro ciclistico da potenza media, dislivello negativo e run nello sci. Se
mancano, la sola durata può rappresentare un'esposizione stimata, sempre
etichettata e con confidence ridotta; non incorpora RPE, HR o rapporti di
potenza che duplicavano l'intensità interna.

Ogni componente è normalizzata sui propri giorni validi in una finestra di 42
giorni. La personalizzazione parte da 14 giorni e diventa completa a 28; prima
si usano anchor conservativi. P50, P90 e P95 producono una mappa continua 0-100.
Le giornate multi-sessione sono combinate in funzione della durata reale delle
sedute e dei pesi della categoria sportiva.

Lo score descrive il carico del giorno. Non usa l'acute:chronic workload ratio
come predittore di infortunio.

## Recovery score v2

### Baseline e qualità minima

La baseline mobile è di 28 giorni, deduplicata per data. Servono almeno 7
giornate valide con HRV o resting HR; 28 danno confidence piena. Il punteggio
richiede inoltre:

- almeno una componente autonomica disponibile oggi (HRV o resting HR);
- almeno il 45% del peso totale osservabile.

Il recovery non può quindi essere prodotto con il solo sleep score. I dati
mancanti vengono esclusi e i pesi disponibili rinormalizzati, mentre la
confidence diminuisce in modo esplicito.

### Componenti

```text
HRV                  30%
resting heart rate   20%
sleep score          25%
temperatura cutanea  10%
respiratory rate     10%
SpO2                  5%
```

- HRV usa `ln(HRV)` e una baseline robusta mediana/MAD; SDNN e RMSSD non
  vengono mescolati;
- resting HR usa mediana/MAD e direzione inversa;
- sleep è ancorato in assoluto: 75 è neutro, 15 punti equivalgono a 1 unità;
- temperatura, respirazione e SpO2 agiscono soprattutto come segnali di
  anomalia sfavorevole, con deadband di 0.5 unità robuste;
- i contributi favorevoli sono limitati a +1.5, mentre le anomalie possono
  penalizzare fino a -3.

La combinazione passa attraverso una sigmoide calibrata per mappare un quadro
neutro vicino a 70/100. Le correzioni luteali fisse (`-2 bpm`, `-0.4 °C`,
`+10% HRV`) sono disattivate: il ciclo è contesto, non una correzione uniforme
applicabile a tutte. Un modello futuro dovrà apprendere l'effetto intra-atleta
solo con dati longitudinali sufficienti e consenso esplicito.

## Correzioni nella pipeline dati

- gli intervalli di sonno sovrapposti vengono uniti prima della somma;
- onset e wake derivano dagli stati di sonno effettivo, non da `IN_BED` o
  record di sessione generici;
- i nap sono assegnati alla finestra di 24 ore precedente il risveglio;
- iOS conserva HRV come SDNN e temperatura notturna al polso; Android conserva
  RMSSD e deviazione di temperatura cutanea;
- le serie HRV con metrica diversa non condividono la baseline;
- gli RR beat-to-beat accettano intervalli fino a 2000 ms, applicano controlli
  di artefatti e non collegano battiti separati da campioni scartati;
- lo strain usa la mediana recente del resting HR, non un valore fisso di
  50 bpm;
- la UI mostra la confidence e ricorda che lo score non è una prescrizione.

## Piano di validazione necessario

Prima di presentare gli score come validati per sport professionistico:

1. congelare una versione dell'algoritmo e preregistrare endpoint e analisi;
2. raccogliere almeno 8-12 settimane per atleta, includendo PVT, CMJ o test
   sport-specifici, wellness/soreness, RPE della seduta, disponibilità
   all'allenamento, sintomi e diagnosi dello staff medico;
3. stimare affidabilità, errore intra-atleta, calibrazione e associazione con
   gli endpoint senza trasformare correlazioni in causalità;
4. validare separatamente per device/metrica, sport, sesso, fascia d'età e
   periodo competitivo;
5. confrontare la v2 con modelli più semplici e validare fuori campione;
6. apprendere eventuali pesi solo nel training set, poi congelarli e testarli
   su atleti e stagioni non visti;
7. definire con medici e performance staff soglie operative e protocollo di
   override umano.

## Limiti ancora aperti

- la priorità tra più sorgenti wearable concorrenti non è ancora modellata con
  una gerarchia device-specifica completa;
- il cambio di dispositivo richiede segmentazione esplicita delle baseline
  oltre alla separazione della metrica;
- la provenance completa di sleep/recovery è disponibile nel risultato/cache,
  ma va storicizzata in una tabella audit dedicata prima di studi longitudinali;
- manca ancora un check-in soggettivo strutturato nel recovery;
- anchor e pesi strain vanno calibrati per sport su dati osservati;
- nessuno score è stato ancora validato contro outcome clinici o di performance
  della popolazione 4athletes.

## Riferimenti principali

- Walsh et al., *Sleep and the athlete: narrative review and 2021 expert
  consensus recommendations*: https://pubmed.ncbi.nlm.nih.gov/33144349/
- Sargent et al., fabbisogno percepito e sonno ottenuto negli atleti elite:
  https://pubmed.ncbi.nlm.nih.gov/34021090/
- Meta-analisi 2024 dei wearable consumer da polso rispetto alla PSG:
  https://pubmed.ncbi.nlm.nih.gov/39484805/
- Plews et al., best practice per HRV negli atleti di endurance:
  https://pubmed.ncbi.nlm.nih.gov/23852425/
- Revisione metodologica e meta-analisi sull'allenamento guidato da HRV:
  https://pubmed.ncbi.nlm.nih.gov/34639599/
- Kellmann et al., consensus su recovery e performance:
  https://pubmed.ncbi.nlm.nih.gov/29345524/
- Foster et al., session-RPE per il monitoraggio del carico:
  https://pubmed.ncbi.nlm.nih.gov/11708692/
- Bourdon et al., consensus sul monitoring del training load:
  https://pubmed.ncbi.nlm.nih.gov/28463642/
- Schwellnus et al., IOC consensus su load, salute e rischio di malattia:
  https://bjsm.bmj.com/content/50/17/1043
- Impellizzeri et al., limiti concettuali dell'acute:chronic workload ratio:
  https://pubmed.ncbi.nlm.nih.gov/32502973/
- Living systematic review su HRV da wearable e ciclo mestruale:
  https://pubmed.ncbi.nlm.nih.gov/41545627/
