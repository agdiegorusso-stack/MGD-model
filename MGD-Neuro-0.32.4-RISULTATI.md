# MGD Neuro 0.32.4 — primo esperimento verificabile

Data: 25 settembre 2026. Versione Android 0.32.4, codice 63.
Commit della build finale: `336848c817d3fbed5c6b5906ff085d262d21e914`.

## Cosa è stato implementato
- Lettore locale dei ruoli agente/predicato/oggetto: perceptron mediato addestrato su 700 esempi sintetici, seed 324, 22 epoche. Quattro famiglie di relazioni: inseguire, aiutare, contenere, possedere; alcune forme attive, passive e varianti lessicali.
- Pesi riproducibili da `mgd-neuro-app/tool/train_reader_v0324.mjs`, senza pesi linguistici preaddestrati esterni. Il controllo in CI rigenera esattamente il file incluso nell'app.
- Memoria delle affermazioni con testo, provenienza, versione, polarità e cronologia. Una correzione esplicita sostituisce la versione corrente senza cancellare il testo precedente.
- Integrazione in chat e nell'insegnamento dei corpora, schermata Mente → Relazioni apprese e visualizzazione dei nodi nella mappa Mondo.
- Ripetizioni e domande non aggiungono nuove affermazioni a questa memoria; un'importazione di testo già sostituito non lo riattiva.
- Le risposte delle fonti preesistenti restano disponibili quando la nuova memoria non ha una relazione pertinente. La ricerca considera anche la cronologia per impedire che il vecchio fatto riemerga dopo una correzione.
- Le domande riconosciute ma fuori dal lessico interrogativo addestrato non diventano asserzioni. La gestione sperimentale delle domande copre soprattutto «chi», forme passive e domande sì/no; «cosa/come» non sono una capacità generale già acquisita.

## Cosa è appreso, cosa è una regola
I ruoli e le etichette dei predicati vengono predetti con parametri appresi. I nomi delle entità sono mascherati nelle caratteristiche, mentre il testo originale è conservato: il lettore può quindi elaborare nomi assenti dal training.

La protezione di modalità, condizioni e discorso riportato è una regola conservativa con copertura limitata. La risoluzione dei pronomi è anch'essa una regola esplicita: un unico referente in una semplice frase introduttiva immediatamente precedente. Non è stato addestrato un risolutore generale di anafore. Il margine del classificatore non è una probabilità calibrata.

Il sistema continua ad astenersi su costruzioni fuori ambito. Questa build non parla italiano generale in modo fluente e non costituisce un nuovo modello fondazionale.

## Ruolo effettivo di MGD
Nuove osservazioni e correzioni alimentano la ricorrenza di `MgdMath09.evolve`. Costo, memoria e materia sono visibili per ogni relazione. Una correzione disattiva semanticamente il vecchio record tramite il versionamento, non per una soglia geometrica.

La variante di confronto conserva lettore, fatti e versioni identici e cambia l'ordinamento dei candidati: geometrico oppure cronologico. È un'ablazione dell'ordinamento, non la rimozione di ogni calcolo MGD dal programma. Nei casi del pilot c'è in genere un unico candidato utile: il confronto non sollecita un vantaggio del routing geometrico in presenza di molte memorie concorrenti. Un risultato perfetto non dimostra che le equazioni MGD abbiano imparato la grammatica.

## Protocollo e limiti
288 casi sintetici di sviluppo, 48 per categoria: attiva, passiva, negazione, correzione, riferimento pronominale semplice, astensione su condizione. I nomi delle entità sono diversi da quelli del training; le strutture di frase e il vocabolario verbale si sovrappongono. Il dataset è stato fissato prima della prima CI e non è stato modificato dopo i risultati. Non è un benchmark indipendente, cieco o rappresentativo dell'italiano.

I pesi del lettore sono rimasti invariati. Dopo la prima esecuzione sono stati corretti il riconoscimento delle domande senza punteggiatura e la compatibilità delle risposte con la memoria precedente; la suite finale rivaluta la build consegnata.

Il confronto Transformer iniziale usa Qwen2.5-0.5B-Instruct e non supera i quattro controlli del protocollo (2/4). L'audit successivo usa Qwen2.5-1.5B-Instruct, selezionando fra due rappresentazioni delle opzioni soltanto su otto controlli separati: entrambe ottengono 5/8, sotto la soglia prevista di 7/8. Il modello da 1.5B non è quindi passato alla valutazione dei 288 casi. La soglia è un requisito del nostro protocollo; non prova un guasto del modello e il mancato superamento può riflettere sensibilità al prompt o errori sulle capacità richieste.

Non si usa il risultato della baseline sotto soglia per dichiarare una vittoria. Il confronto con i Transformer resta non conclusivo. L'audit è un emendamento successivo al primo risultato, non un protocollo preregistrato.

Revisioni Qwen: 0.5B `7ae557604adf67be50417f59c2c2f167def9a775`; 1.5B `989aa7980e4cf806f80c7fef2b1adb7bc71aa306`. I modelli Transformer non sono inclusi nell'app.

## Download e installazione

- [APK Android 0.32.4 — archivio ZIP](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36185703631/artifacts/10887085835)
- [Sorgenti esatti della build](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36185703631/artifacts/10887105887)
- [Log completi, benchmark e verifiche di firma/versione](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36185703631/artifacts/10887415404)
- [Esecuzione CI conclusa con successo](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36185703631)

GitHub può richiedere l'accesso per scaricare gli artifact. I download sono disponibili fino al 25 ottobre 2026. Estrai `app-release.apk` dallo ZIP e installalo come aggiornamento, senza disinstallare l'app precedente.

Identità verificata: pacchetto `it.diegorusso.mgdneurostable`, versione `0.32.4`, codice `63`. Certificato SHA-256: `bfd6e2660a3c3a6e3b37d1736e1619777b933e976c312c5b1c6cd38e908f1589`, corrispondente alla firma stabile delle build precedenti.

## Verifiche eseguite

- Rigenerazione deterministica dei pesi: passata.
- Test unitari e dell'interfaccia: **228 passati**.
- Test Android su emulatore API 35: **5 passati**.
- Il nuovo test Android conferma `oneRead`, `passiveParaphrase`, `correction`, `history`, `worldMap` e `sqliteRestart`.
- Il benchmark precedente, mantenuto come regressione, passa **240/240** domande strutturate; risposte identiche dopo ripristino e nessun incremento di fatti/evidenze alla reimportazione. Il campo interno `version` di questo benchmark resta `0.32.3`: identifica il protocollo precedente, mentre il codice eseguito è quello della build finale indicata sopra.
- Analisi statica: **0 errori, 40 warning e 374 segnalazioni informative**. La CI consente warning e informazioni; il successo della build non significa assenza di debito tecnico. I dettagli sono nel log `analyze-0.32.4.log`.
- APK release generato; pacchetto, versione e continuità della firma verificati.

Queste verifiche riguardano i flussi coperti dalle suite. Non certificano che ogni funzione o metrica dell'intera applicazione sia corretta in ogni condizione.

## Risultati della build finale

Sul runner CI, entrambi gli ordinamenti rispondono correttamente a 288/288 casi, anche dopo serializzazione e ripristino. Ogni categoria ottiene 48/48.

| Variante | Risposte corrette | Dopo ripristino | Query mediana | Query p95 | Apprendimento mediano |
|---|---:|---:|---:|---:|---:|
| Ordinamento MGD | 288/288 | 288/288 | 93 µs | 234 µs | 141 µs |
| Ordinamento cronologico | 288/288 | 288/288 | 60 µs | 119 µs | 100 µs |

Sono microtempi della componente relazionale sul runner, non tempi di risposta completi dell'app sul telefono. Ordine delle esecuzioni e riscaldamento del runtime possono influenzarli. Entrambe le varianti mantengono i calcoli MGD all'inserimento. In questo esperimento MGD non aggiunge accuratezza e l'ordinamento cronologico risulta più rapido; non si deduce un vantaggio energetico o generale.

La baseline 0.5B produce 34/288, ma supera soltanto 2/4 controlli ed è marcata `validBaseline: false`. Il valore è conservato per trasparenza e non costituisce una prova comparativa di superiorità. L'audit 1.5B supera 5/8 controlli e non esegue i casi successivi.

- [Dati e risultati della valutazione finale](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36185703631/artifacts/10886281665).
- [Audit separato della baseline 1.5B](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36184829749/artifacts/10885488972).

## Prova manuale nell'app

1. In chat: **Il norvente insegue il talverio.**
2. Chiedi: **Da chi viene rincorso il talverio?** Il soggetto atteso è **norvente**.
3. Insegna: **Correggi: Il norvente insegue il felvario.**
4. Chiedi: **Il norvente rincorre chi?** L'oggetto atteso è **felvario**.
5. In **Mente → Relazioni apprese**, cerca `norvente`: la nuova relazione deve essere corrente e quella precedente deve restare nella cronologia. Nella mappa **Mondo** cerca `norvente`.
6. Riapri l'app e ripeti la domanda. Chiedendo del vecchio oggetto non deve riapparire la versione sostituita.

Questa è la stessa sequenza coperta dal nuovo test Android. Il test chiude e riapre SQLite e ricrea l'app: non simula ogni possibile interruzione o terminazione del processo da parte del sistema operativo. Le misure CI usano un emulatore Android API 35; non è stata eseguita una misura sul telefono dell'utente.

## Come interpretare il risultato

È un primo esperimento operativo su un dominio linguistico circoscritto: acquisizione da una sola esposizione, domande con varianti previste, correzioni tracciabili e persistenza. Non dimostra apprendimento rapido di qualunque frase, verità delle informazioni insegnate o superiorità generale sui Transformer.

Per stabilire se MGD dà un vantaggio, il confronto successivo dovrà includere molte memorie concorrenti, interferenze, ritardi e budget fissati, un insieme di valutazione indipendente e una baseline linguistica che superi prima i controlli del protocollo. L'app non richiede un modello Transformer per le quattro famiglie introdotte.
