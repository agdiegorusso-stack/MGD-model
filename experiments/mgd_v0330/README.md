# MGD Neuro 0.33.0: memoria multimodale verificabile

Questa versione aggiunge all’app un classificatore esperienziale locale, utilizzabile durante l’apprendimento. **Non dimostra che MGD superi i Transformer, non è un modello generale di linguaggio e non è AGI.** La comparazione comprende anche un Transformer che si aggiorna durante l’uso: il confronto non presume che i Transformer siano incapaci di apprendimento continuo.

## Cosa è stato implementato

Da **Mondo → Impara dall’esperienza** si possono associare testo, una foto e due secondi di audio allo stesso episodio. Il nome da insegnare è un campo separato: la risposta non viene aggiunta automaticamente alle caratteristiche d’ingresso. Si può chiedere una previsione, confermare un nome, cercare una categoria, esportare gli episodi o eliminarli. Immagini e suoni si acquisiscono tramite i sensori reali dell’app. L’audio viene descritto acusticamente, non trascritto.

Il nuovo classificatore opera nella pagina delle esperienze e alimenta la mappa condivisa. La chat mantiene il suo motore linguistico precedente: questo aggiornamento non lo trasforma in un assistente generale capace di comprendere immagini e parlato.

La nuova memoria conserva episodi immutabili, contesto, etichetta, fonte e data. Apprende anche una metrica diagonale, con aggiornamenti sottoposti a un controllo su esempi precedenti. I descrittori delle tre modalità vengono confrontati **congiuntamente all’interno di ciascun episodio**; non si confondono le associazioni tra modalità. Una foto già confermata non viene più spostata nel vecchio prototipo sensoriale da una nuova osservazione non confermata.

La pagina **Mappa della conoscenza** include le nuove categorie e una vista **Esperienze**. La ricerca comprende anche parole isolate della memoria linguistica. L’eliminazione ha due ambiti espliciti:

- Dalla vista Esperienze: cancella un episodio o una categoria in quel contesto e ricostruisce la nuova metrica dagli episodi rimanenti.
- Dalle memorie esistenti: rimuove il nodo e i riferimenti attivi associati nei fatti, nelle parole, nelle fonti, nelle relazioni e nei sensori. Gli identificatori interni rimangono stabili; gli slot eliminati non vengono presentati come conoscenze attive.

Non è una cancellazione forense del telefono o degli export già prodotti. L’esattezza del ricalcolo riguarda il nuovo classificatore; non viene rivendicata una prova di unlearning causale di ogni peso del vecchio motore MGD. Una nuova esposizione può insegnare nuovamente un nome eliminato.

L’elaborazione della nuova esperienza e la ricostruzione dopo una cancellazione avvengono fuori dal thread dell’interfaccia. Per impostazione predefinita, **Apprendimento su evento** disattiva ripasso e ricerche avviati dal timer; restano i comandi manuali e le azioni conseguenti all’interazione. Le operazioni native del vecchio motore non sono state tutte riscritte.

## Misure, non promesse

Sei esecuzioni finali indipendenti, seed 6–11. In ogni esecuzione: 64 esempi di apprendimento, 96 stimoli di verifica nuovi, otto classi e due fasi con quattro classi nuove per fase. Le tre informazioni indipendenti sono un colore in un PNG, una frequenza in un PCM e una breve indicazione testuale. È un esperimento artificiale ristretto: non misura comprensione del parlato, riconoscimento di oggetti naturali o ragionamento generale.

| Sistema | Risposte migliori corrette / 576 | Accuratezza |
|---|---:|---:|
| Nucleo Dart dell’app, metrica adattiva | 571 | 99,13% |
| Transformer di 19.464 parametri, aggiornato online con replay | 570 | 98,96% |
| Controllo: memoria episodica con distanza fissa | 574 | 99,65% |

**Una sola risposta corretta in più sul Transformer non costituisce una vittoria.** Il test esatto con inversione dei segni sulle differenze appaiate per seed restituisce p = 1,00. Il controllo senza metrica appresa supera entrambi in questo piccolo esperimento. La matematica specifica della curvatura MGD non entra nel nuovo classificatore e non viene convalidata da questi risultati.

| Canali disponibili al nucleo dell’app | Accuratezza media |
|---|---:|
| Solo immagine | 24,48% |
| Solo audio | 23,78% |
| Solo testo | 25,00% |
| Immagine + audio | 49,48% |
| Immagine + audio + testo | 99,13% |

Il nucleo accetta autonomamente 533 dei 576 stimoli di verifica (92,53%); tutti questi 533 sono corretti. Nei restanti 43 richiede una conferma: l’accuratezza della prima tabella include comunque il candidato migliore anche quando il sistema si astiene. Zero errori osservati in un sottoinsieme piccolo non garantisce zero errori futuri. La perdita logaritmica media è 0,2037 per il nucleo e 0,1681 per il Transformer: anche questa misura favorisce il Transformer.

Sulle classi della prima fase, l’accuratezza del nucleo non diminuisce dopo la seconda fase in nessuno dei sei seed. Questa è una misura su questo flusso, non una garanzia generale di assenza di dimenticanza. Il Transformer può inoltre migliorare sulle classi precedenti grazie al replay.

Le misure di tempo sono nel JSON per seed. La prima esecuzione usa Dart JIT e PyTorch CPU a un thread sullo stesso server Linux. La seconda compila il medesimo benchmark Dart in un eseguibile AOT: i risultati di accuratezza sono identici e si trovano in `results-aot`.

| Implementazione | Apprendimento, ms | Previsione, ms |
|---|---:|---:|
| Nucleo Dart JIT | 28,85 | 1,109 |
| Nucleo Dart AOT | 28,95 | 1,163 |
| Transformer PyTorch CPU | 4,64 | 0,234 |

Sono medie delle mediane dei sei seed e tempi del nucleo: escludono acquisizione/estrazione dei sensori, creazione dell’isolate, trasferimenti e SQLite. Il Transformer risulta più rapido in questa comparazione, anche rispetto all'eseguibile AOT. Runtime e implementazioni sono diversi: la tabella descrive queste implementazioni, non un limite teorico delle architetture. Non equivale a misure energetiche né a tempi sul telefono. Non sono stati misurati joule, watt o consumo della batteria.

La nuova memoria serializzata occupa circa 114 kB per 64 episodi del benchmark. Il limite esplicito è 2.048 episodi: a saturazione l’inserimento viene rifiutato, senza eliminazioni silenziose. Non è stata implementata una compressione con garanzia di conservazione delle predizioni. I file grezzi di foto e audio non sono archiviati dalla nuova memoria: rimangono i descrittori, quindi non si potranno ricalcolare rappresentazioni future dai file originali senza riacquisirli.

## Perché queste scelte, rispetto alla ricerca

| Ricerca primaria | Contributo utile | Stato in questa versione |
|---|---|---|
| [NCA, Goldberger et al.](https://www.cs.utoronto.ca/~hinton/absps/nca.pdf) | Imparare distanze rispetto alla classificazione di esempi esclusi dal proprio confronto | Variante diagonale con perdita logaritmica, bilanciamento per classe, controllo sugli esempi e calibrazione separata |
| [Complementary learning systems, Nature Neuroscience 2023](https://www.nature.com/articles/s41593-023-01382-9) | Separare apprendimento episodico rapido e generalizzazione più lenta | Ispirazione architetturale; non simulazione biologica del cervello |
| [Dark Experience Replay, NeurIPS 2020](https://arxiv.org/abs/2004.07211) | Il replay è un confronto necessario per apprendimento continuo | Replay nel Transformer di confronto; controllo su episodi nel nucleo. Non implementazione completa di DER++ |
| [Mamba-3, ICLR 2026](https://arxiv.org/abs/2603.15569) | Modellazione sequenziale efficiente con stato ricorrente | Candidato per un futuro motore sequenziale, non incluso nell’APK e non provato migliore su Android |
| [ImageBind, CVPR 2023](https://arxiv.org/abs/2305.05665) | Rappresentazioni condivise da modalità diverse apprese da dati associati | Non incluso: l’APK usa ancora descrittori di basso livello, senza pesi ImageBind |
| [Nested Learning / HOPE, NeurIPS 2025](https://abehrouz.github.io/files/NL.pdf) | Memorie e processi di aggiornamento a scale temporali differenti | Riferimento di ricerca; non implementazione di HOPE e non prova di apprendimento illimitato |

Non esiste una selezione dimostrata dei “migliori algoritmi in assoluto” ottenuta sommando questi lavori. Questi riferimenti suggeriscono componenti e confronti; la loro combinazione deve essere addestrata e misurata. Per una capacità generale rimangono da realizzare encoder semantici multimodali, un modello sequenziale/predittivo addestrato su scala adeguata, verifica su dati reali e misure energetiche su dispositivo. Il prototipo attuale non copre questi requisiti.

## Come riprodurre

I sorgenti del nucleo e i test sono in `mgd-neuro-app/lib/experience_*v0330.dart` e `mgd-neuro-app/test/experience_v0330_test.dart`. Il test Android aggiunto è in `integration_test/runtime_android_v0319_test.dart`. La suite completa comprende 247 test locali e controlli nativi separati in CI.

Con Flutter 3.47.5 e Dart 3.13.4:

```bash
cd mgd-neuro-app
flutter pub get
flutter test --reporter expanded
dart --packages=.dart_tool/package_config.json ../experiments/mgd_v0330/benchmark.dart
cd ..
python3 experiments/mgd_v0330/transformer_comparison.py
```

Il confronto Python usa `torch==2.14.0+cpu`, `numpy==2.3.5`, un thread, AdamW con learning rate 0,002 e weight decay 0,001. Il Transformer ha due blocchi, larghezza 32, quattro teste, feedforward 64 e dropout zero. Effettua due aggiornamenti per nuovo esempio con replay di massimo 16 esempi passati più quello corrente; conserva gli stessi 64 esempi disponibili al nucleo. Uguali dati e memoria disponibile non significano uguali FLOP: il confronto documenta entrambi i budget senza fingere equivalenza energetica.

I dataset JSON vengono rigenerati dal benchmark Dart; non sono necessari download esterni di corpora o pesi. Gli esiti di sviluppo con seed 0–5, precedenti alla calibrazione, sono conservati in `development-results/app-core-results.json` e non sono inclusi nel risultato finale. Hanno mostrato un’eccessiva astensione, correggibile senza osservare le etichette dei sei seed finali.

Per riprodurre anche la misura AOT, dalla cartella `mgd-neuro-app`:

```bash
dart compile exe --packages=.dart_tool/package_config.json ../experiments/mgd_v0330/benchmark.dart -o /tmp/mgd-benchmark-0330
/tmp/mgd-benchmark-0330 ../experiments/mgd_v0330/results-aot
```

## Verifica pratica nell’app

1. Aprire **Mondo → Impara dall’esperienza** e scegliere un contesto, per esempio `oggetti sulla scrivania`.
2. Acquisire una foto, aggiungere eventualmente audio e testo dello stesso evento, quindi scrivere il nome nel campo di conferma e insegnarlo. Il campo del nome non viene usato come ingresso della previsione.
3. Ripetere con esempi nuovi, conservando alcuni stimoli esclusi dall’apprendimento. Usare questi ultimi per verificare la previsione, prima di confermarne il nome.
4. Cercare il nome nella mappa; la vista **Esperienze** consente di ispezionare provenienza e riferimenti ed eliminare gli esempi scelti. Riavviare l’app per controllare la persistenza.

Per provare il caso `ciao`, inserire per esempio `saluto breve` come testo dell’episodio e `ciao` come nome da insegnare. Cercare poi `ciao` nella mappa. Un saluto digitato in chat e un episodio esplicitamente confermato hanno provenienze diverse: la mappa rende consultabili entrambi, senza attribuire automaticamente al saluto un significato visivo o acustico.

**Non usare l’APK come prova di superiorità generale.** Usarlo per verificare apprendimento e cancellazione nella propria interazione, conservando esempi nuovi per valutare ciò che ha effettivamente generalizzato.
