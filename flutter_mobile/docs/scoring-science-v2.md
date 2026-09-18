# Scoring science v2

Versione algoritmo: `wellness-scoring-v2.2.0`
Stato: evidence-informed, da validare prospetticamente
Ultimo aggiornamento: 2026-09-12

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

Il riferimento personale usa le notti valide nei 28 giorni precedenti, ordinate
e deduplicate per data. Il giorno valutato e i giorni futuri sono esclusi:

```text
target_età = 500 min se età >= 18 anni, 540 min se età <= 17 anni
baseline = max(target_età, percentile 75 del sonno notturno osservato)
```

Servono 7 notti per una baseline parziale e 14 per quella completa. Una storia
cronicamente corta non può quindi abbassare il target prudenziale. I 500/540
minuti sono riferimenti di prodotto, non misure del reale fabbisogno individuale.
Il saldo di
sonno usa gli ultimi 7 giorni, con decadimento esponenziale `exp(-0.25 * età)`
e limite di +/-90 minuti. Un surplus recente può ripagare un deficit passato,
ma solo il saldo positivo aumenta il bisogno del giorno corrente.
Le finestre e il decadimento usano giorni di calendario anche quando mancano
registrazioni; una notte vecchia non viene trattata come se fosse ieri.

I nap validi nel periodo precedente il risveglio entrano nel sonno effettivo
delle 24 ore. Non vengono sottratti dal bisogno. La precedente curva che
aggiungeva automaticamente fino a 45 minuti in funzione dello strain è
disattivata: non aveva una validazione sufficiente per trasformare un carico in
minuti di sonno prescritti.

### Componenti

```text
score_base =
    0.55 * durata_24h
  + 0.15 * adeguatezza_ultimi_7_giorni
  + 0.20 * efficienza
  + 0.10 * regolarità_circadiana

sleep_score = clamp(
  min(score_base, durata_24h + 10) - penalità_fasi_personali,
  0, 100
)
```

- `durata_24h`: curva continua a tratti sul rapporto sonno/bisogno. Anchor:
  0% → 0, 50% → 15, 60% → 30, 70% → 45, 80% → 60, 90% → 80, 100% → 100.
  Un sonno oltre il bisogno non genera bonus. Senza durata odierna valida non
  viene prodotto uno score, anche se lo storico è disponibile.
- `adeguatezza_ultimi_7_giorni`: media degli score giornalieri ottenuti con la
  stessa curva e limite individuale a 100, con almeno 3 giorni validi. Una notte
  lunga non cancella completamente le notti corte; il saldo di sonno può comunque
  riconoscere un recupero parziale nel calcolo del bisogno.
- `efficienza`: normalizzazione lineare tra 60% (0 punti) e 95% (100 punti).
  L'85% produce circa 71 punti, non più 100.
- `regolarità`: per onset e risveglio usa il maggiore tra variabilità della
  finestra di 14 giorni e scostamento odierno dalla media circolare dello storico,
  poi media le due componenti. Tolleranza iniziale 30 minuti; un cambio netto
  dell'orario odierno non viene diluito nelle notti precedenti.
- Il limite `durata + 10` impedisce a efficienza, regolarità e buona storia di
  trasformare una forte carenza di durata in uno score elevato.

Questa è una calibrazione di prodotto: curva, pesi, limite di compensazione,
target di efficienza e penalità non sono soglie cliniche validate. Il principio
di personalizzazione è coerente con il consensus sugli atleti; i coefficienti
richiedono verifica prospettica sulla popolazione 4athletes.

### Fasi personali

Le fasi sono confrontate esclusivamente con lo storico dello stesso atleta:

- finestra dei 28 giorni precedenti, almeno 7 notti complete utilizzabili;
- mediana e MAD delle proporzioni di profondo, REM e leggero, con deviazione
  standard robusta minima di 3 punti percentuali per assorbire rumore;
- confronto limitato alla stessa identità `piattaforma/sorgente/dispositivo`
  esposta da Health. Sorgenti miste o sconosciute non attivano la correzione;
- tutti e tre gli stadi devono essere osservati e coprire tra il 90% e il 102%
  del totale. Il margine superiore ammette piccoli arrotondamenti. Il residuo
  non classificato non viene inventato come sonno leggero;
- per profondo e REM, nessuna penalità entro 1 deviazione robusta sotto la
  mediana; progressione lineare fino a 3 deviazioni, massimo 4 punti per fase;
- la correzione cresce con `min(1, notti_valide / 14)`: a 7 notti il massimo
  complessivo è 4 punti, da 14 notti è 8;
- più profondo non compensa meno REM e viceversa; nessun bonus per percentuali
  alte. Il leggero è solo contestuale e non è considerato sonno negativo;
- si confrontano proporzioni per evitare di penalizzare due volte una notte
  corta. Nei dettagli rimangono anche mediana in minuti e minuti attesi alla
  durata odierna;
- dati mancanti, incoerenti o storico insufficiente escludono la correzione e
  riducono l'affidabilità, senza inventare fasi o uno score neutro.

La correzione massima di 8 punti è intenzionalmente contenuta per l'incertezza
delle stime wearable, descritta anche nella
[posizione AASM sui consumer sleep tracker](https://aasm.org/advocacy/position-statements/consumer-sleep-technology/).
Non rappresenta una validazione scientifica del punteggio delle fasi.

### Esempi di calibrazione

Scenari sintetici: bisogno 500 minuti (8h20), storico completo di 500 minuti
per notte, efficienza almeno 95%, orari regolari, fasi nelle proporzioni abituali,
nessun nap. Punteggi arrotondati; non sono dati di utenti reali.

| Durata | v2.0 | v2.1 |
| --- | ---: | ---: |
| 5h | 79 | 40 |
| 6h | 85 | 58 |
| 7h | 92 | 78 |
| 8h | 98 | 95 |
| 8h20 | 100 | 100 |

La versione aggiornata invalida le cache locali tramite `algorithmVersion`.
I punteggi salvati nei log remoti non vengono migrati retroattivamente: sono
aggiornati quando la relativa giornata viene nuovamente sincronizzata. Anche
il recovery può cambiare, perché usa lo sleep score come ingresso al 25%.

Prossimi sviluppi da valutare: percezione di riposo al risveglio, numero e durata
dei risvegli con copertura verificabile, gestione esplicita di viaggi/turni, e
confronto prospettico tra score e sensazioni/performance. Non aumentare il peso
degli stadi prima di averne verificato stabilità e utilità sullo stesso atleta.

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

La baseline mobile è di 28 giorni di calendario, ordinata e deduplicata per
data; esclude il giorno valutato, i giorni futuri e le date invalide. Servono almeno 7
giornate valide con HRV o resting HR; 28 danno confidence piena. Il punteggio
richiede inoltre:

- almeno una componente autonomica disponibile oggi (HRV o resting HR);
- almeno il 45% del peso totale osservabile.

Il recovery non può quindi essere prodotto con il solo sleep score. I dati
mancanti vengono esclusi e i pesi disponibili rinormalizzati, mentre la
confidence diminuisce in modo esplicito. La v2.2 usa la maturità di ciascuna
metrica, evitando che 28 misure di resting HR facciano sembrare completa una
serie HRV di sole 7 misure. Per ogni componente fisiologica disponibile:
`confidenza = min(1, giorni_validi_metrica / 28)`; HRV con metrica sconosciuta
applica inoltre il fattore 0.8. Per il sonno:
`confidenza = confidenza_sleep_score * min(1, giorni_autonomici_validi / 28)`.
La confidence finale è la somma delle confidence pesate con i pesi nominali.
Un sonno con confidence parziale conserva il proprio contributo numerico ma
rende esplicitamente parziale l'affidabilità del recovery. Un risultato sleep
non valido o con confidence nulla/non finita viene escluso.

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
- i contributi favorevoli sono limitati a +1.5; quelli sfavorevoli di HRV,
  resting HR e sonno possono arrivare a -3. Temperatura, respirazione e SpO2
  arrivano a -2.5 dopo il clipping a 3 e la deadband di 0.5.

La v2.2 riduce il bonus di una componente autonomica quando l'altra è
sfavorevole: nessuna riduzione entro 0.5 unità robuste negative, riduzione
lineare fino ad annullare il bonus a 2 unità negative. Per esempio, HRV alta
non può nascondere resting HR nettamente elevata; lo stesso vale per resting
HR bassa con HRV nettamente ridotta. I valori grezzi e il contributo prima e
dopo la correzione sono mantenuti nei dettagli. Questa regola esprime discordanza
dei segnali, non una diagnosi di fatica o malattia.

La combinazione passa attraverso `100 * sigmoid(z_totale + 0.619039, k=1)`.
Un quadro neutro mappa a 65/100, mentre segnali concordemente favorevoli possono
superare 85. La precedente curva (`bias=1.06, k=0.8`) poneva la neutralità
intorno a 70, già nella fascia "buono". Pesi e trasformazione sono scelte di
calibrazione del prodotto, non percentuali di recupero fisiologico validate.

Le correzioni luteali fisse (`-2 bpm`, `-0.4 °C`,
`+10% HRV`) sono disattivate: il ciclo è contesto, non una correzione uniforme
applicabile a tutte. Un modello futuro dovrà apprendere l'effetto intra-atleta
solo con dati longitudinali sufficienti e consenso esplicito.

### Simulazioni del recupero

Scenari sintetici con 28 giorni completi, baseline stabile HRV RMSSD 70 ms e
resting HR 50 bpm, temperatura/respirazione/SpO2 abituali e confidence piena.
Il punteggio del sonno è fissato uguale nei due calcoli per isolare la modifica
del recovery dalla precedente ricalibrazione del sonno.

| Scenario | Prima | v2.2 |
| --- | ---: | ---: |
| Parametri abituali, sleep 75 | 70.0 | 65.0 |
| Parametri abituali, sleep 40 | 59.4 | 50.9 |
| HRV 90 ms, resting HR 53 bpm, sleep 75 | 70.8 | 55.5 |
| HRV 90 ms, resting HR 47 bpm, sleep 95 | 84.7 | 84.6 |
| HRV 50 ms, resting HR 54 bpm, sleep 40 | 31.7 | 19.8 |

### Coerenza dei grafici di sonno e recupero

- Home, Salute e dettagli Analytics dell'atleta leggono lo stesso snapshot
  disponibile; i valori ricalcolati/cache aggiornati prevalgono sui vecchi log.
- Un risultato di recupero ricalcolato con dati insufficienti rimane assente;
  non viene sostituito automaticamente da un precedente voto alto. I fallimenti
  della lettura Health restano distinti da un calcolo completato senza score.
- Le schede odierne di Salute non prendono il valore di un altro giorno. Lo
  storico rimane consultabile e la media usa solo giornate osservate.
- Le serie score sono deduplicate per data, accettano solo valori finiti 0–100
  e mantengono valido lo zero. Le date mancanti non diventano zero.
- I dettagli Analytics, inclusi quelli aperti dal coach con i log dell'atleta,
  usano asse 0–100, distanze temporali reali e interruzioni nei giorni senza
  dati. Le linee dei punteggi in Salute non sono smussate.
- I colori di recupero in Home e dettagli rispettano le stesse soglie 40/55/70;
  un punteggio "medio" non viene colorato come "buono".
- La versione aggiornata invalida le cache precedenti. I log remoti non hanno
  ancora provenienza algoritmica per punto: non viene inventata una versione
  storica, né effettuato un ricalcolo retroattivo. I grafici segnalano che il
  confronto può includere versioni precedenti. Il coach vede i log sincronizzati,
  non le cache private del dispositivo dell'atleta.

Il recupero incorpora già il sonno al 25%: correlare i due grafici non è una
validazione indipendente dell'algoritmo. Non sommarli in un ulteriore indice
senza considerare questa sovrapposizione. Le priorità future sono un check-in
su fatica, stress e dolore muscolare, dati longitudinali di performance e
tracciamento della versione su ogni punto storico. Le misure cardiache da sole
non descrivono tutte le dimensioni del recupero, come discusso nel
[consensus su recovery e performance](https://pubmed.ncbi.nlm.nih.gov/29345524/) e
nel [framework sui segnali cardiaci negli sport di squadra](https://pubmed.ncbi.nlm.nih.gov/29904351/).

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
- le fasi del sonno separano ora la baseline per sorgente/dispositivo quando
  l'identità è esposta da Health; cambi di hardware o firmware nascosti dietro
  la stessa identità non sono rilevabili. Le altre baseline richiedono ancora
  segmentazione esplicita oltre alla separazione della metrica;
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
