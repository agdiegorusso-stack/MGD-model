# Revisione MGD Neural 0.42.0 — 5 ottobre 2026

## Esito e confine della verifica

Il sorgente è stato riorganizzato per risolvere la separazione tra apprendimento dei libri, chat, memoria e geometria. La revisione conserva i nuclei utili della grammatica e della matematica, sostituisce l’orchestrazione e rimuove i percorsi concorrenti. Segue la richiesta di un’installazione da zero: nessuna conversione dei database precedenti.

Il controllo locale ha avuto esito positivo per quattro gruppi di verifiche. La build remota della nuova versione è riuscita: analisi Dart senza errori, 26 test Flutter passati, test Android UI/apprendimento/correzione/riapertura passato su emulatore API 35. Lo stesso APK release è stato verificato con apksigner, installato e avviato sull’emulatore. I flussi di fotocamera, microfono e provider di file non sono stati provati manualmente su un telefono fisico. I risultati sono quelli della nuova versione; non sono stati riutilizzati risultati di APK precedenti.

## Problemi affrontati nel sorgente precedente

| Problema rilevato | Modifica del sorgente nuovo | Evidenza prevista |
|---|---|---|
| Importazione e dialogo consultavano archivi diversi | Archivio canonico e coordinatore comune | Test di apprendimento e domanda immediata |
| Il percorso cognitivo non applicava la matematica MGD | Evoluzione locale chiamata all’ammissione e al recupero dei fatti | Test di variazione geometrica e confronto con ablation |
| Sottosistemi scelti con risposte di ripiego | Orchestrazione esplicita, prove confrontabili, stati unknown/conflict/budget | Test di contraddizione e budget |
| Familiarità poteva assumere il ruolo di affidabilità | Geometria separata dallo stato epistemico della relazione | Correzione dopo consolidamento e feedback geometrico |
| Domande/uscite rischiavano di rientrare nell’apprendimento | Solo gli input dichiarativi interpretati aggiungono fatti | Conteggio dei passaggi e relazioni prima/dopo domande |
| Memorie duplicate e pagine di laboratorio concorrenti | Riduzione da 59 a 13 file applicativi, nuova UI a quattro pagine | Inventario del pacchetto, assenza dei vecchi gestori |
| Testo non interpretato perso o nascosto | Originali conservati, passaggi da rivedere e lettore paginato delle fonti | Test dei passaggi incerti, verifica manuale della UI |
| Correzione senza revoca/provenienza atomica | Nuova evidenza e revoca in una transazione | Test di successo e rollback della correzione |
| Domande precise saturate da parole frequenti | Recupero dei ruoli espliciti, indici e limiti dichiarati | Test con oltre 200 fatti estranei/personaggio ricorrente |
| Percentuali di fiducia non calibrate | Rimozione di quelle percentuali; salienza narrativa etichettata come euristica | Ispezione dei sorgenti e della risposta |

I casi di regressione elencati sono inclusi nei test Flutter passati. I limiti della grammatica e delle capacità restano quelli descritti di seguito.

## Capacità effettivamente codificate

| Area | Stato del codice | Limite concreto |
|---|---|---|
| Memoria persistente comune | Implementata | SQLite locale, nessuna migrazione vecchia |
| Fonti, prove e correzioni | Implementate | Attendibilità esterna della fonte non verificata |
| Deduzioni | Implementate per regole esplicite di classe | Nessun ragionatore logico generale |
| Negazioni/contraddizioni | Gestite per le forme riconosciute | Non risolve negazioni complesse o tutta la pragmatica |
| Riutilizzo di regole con ipotesi nuove | Implementato in forma limitata | Ipotesi individuali semplici; non memorizzate |
| Lettura TXT a blocchi | Implementata | UTF-8, UTF-16 con BOM, Latin-1; PDF/DOCX/EPUB esclusi |
| Relazioni narrative e pronomi locali | Parziale | Grammatica finita, ambiguità segnalate, niente comprensione generale del romanzo |
| Quantità e colori | Parziale | Alcune costruzioni esplicite; sottrazione esatta in una forma definita, non problem solving matematico generale |
| Protagonista/personaggi | Euristica sull’intera fonte | Salienza da ruoli, menzioni e persistenza; non probabilità calibrata né intenzione dell’autore |
| Riassunto | Ricostruzione limitata | Fonte fino a 192 relazioni; output fino a 120 eventi. Riassunto gerarchico di libri lunghi assente |
| Linguaggio appreso | Conteggi d’uso e composizione di relazioni note | Non un generatore conversazionale generale, non apprende autonomamente tutti i significati |
| Credenze e obiettivi | Modello distinto di primo ordine | Osservatori nominati assunti compresenti nella chat; nessuna mente umana generale o secondo ordine |
| Immagini e audio | Descrittori e collegamento a concetti | Etichette umane, confronto di similarità; niente OCR, riconoscimento semantico verificato o trascrizione vocale |
| Esportazione/ripristino | Schema nuovo e transazione | Snapshot locale JSON, massimo 50 MB dall’interfaccia; non un formato interoperabile con le versioni vecchie |
| Mappa della memoria | Elenco delle relazioni paginato | Nessuna visualizzazione spaziale 3D |
| Causalità | Motivazioni esplicite riconosciute | Pianificazione, interventi e inferenza causale generale assenti |
| Attività autonoma | Nessun ciclo periodico | Non esiste un agente esploratore o un sistema generale di obiettivi/autovalutazione |

## Collegamento alla matematica MGD

Il nucleo mantiene la ricorrenza della memoria `m' = αm + βa`, la ricorrenza logistica del materiale `M' = ρM + (1−ρ)χ + ξM(1−M)` e il drift del peso. Il punto fisso usa la radice stabile dell’equazione quadratica per una forzante media costante.

Nel nuovo archivio ogni relazione ha un arco con peso, memoria, materiale, media del trigger e variazione cumulativa del materiale. La plasticità al recupero è modulata da `1/(1+4M)`. Nuove relazioni sono ammesse subito; il consolidamento non serve come soglia per renderle interrogabili. La correzione esplicita resta possibile indipendentemente da M.

Questa applicazione su relazioni linguistiche è una **scelta progettuale**, non una conseguenza dimostrata del modello su reticolo del PDF. Il trigger basato sull’attività dell’arco, i parametri adattivi e la modulazione del feedback richiedono una valutazione sperimentale propria. Il punto fisso a forzante costante non è la media di una ricorrenza stocastica non lineare. La somma delle variazioni di M non misura energia fisica, informazione di Shannon o intelligenza.

Il confronto con `useMgd:false` mantiene identica la politica di ammissione dei fatti. Il test passato controlla questa parità, non dimostra un vantaggio cognitivo della MGD. Per misurare un vantaggio servono dati indipendenti, domande nuove, prestazioni con budget uguale e risultati ripetuti. Nessun miglioramento percentuale è dichiarato nella consegna.

## File e percorso principale

`main.dart` → `CognitiveCoordinator420` → `CanonicalMemory420` è l’unico percorso della chat. La memoria chiama `compileCanonical420` per l’estrazione, poi conserva eventi/prove/uso linguistico/geometria nella stessa transazione. Il compilatore narrativo e il motore logico sono strumenti interni del coordinatore, non archivi alternativi.

L’importatore TXT usa la stessa compilazione, con hash del file e dei blocchi per deduplicazione e ripresa. Il testo originale è letto alla risposta solo per mostrare la prova; non viene passato al lettore come corpus da cercare per generare un’altra risposta. La UI delle fonti può sfogliarlo esplicitamente.

La memoria sensoriale usa gli stessi identificatori di concetto. La ToM condivide il database con tabelle epistemiche distinte. Le credenze osservate rimangono attribuzioni storiche: la correzione di un fatto non simula automaticamente un nuovo evento visto da tutti gli osservatori.

Sono stati rimossi il vecchio main, i gestori di memoria e ricerca concorrenti, i bridge di dialogo/apprendimento, il vecchio induttore di frame per suffissi, le vecchie pagine di laboratorio, il vecchio calcolo di salienza con percentuali arbitrarie, le autoprove generate dal lettore e il registratore Android di plugin obsoleto. I file con versioni 0.34/0.35 nel nome sono nuclei conservati e ridotti; non rappresentano altre app o database.

## Verifiche eseguite e mancanti

| Verifica | Esito di questa consegna |
|---|---|
| Delimitatori lessicali Dart e import locali risolvibili | Passata; non è analisi di tipo o parsing completo Dart |
| Schema SQLite realmente eseguito, foreign key, rollback e cascata | Passata in Python/SQLite sullo schema estratto dai sorgenti |
| Piani degli indici per i lookup verificati | Passata per le query incluse nel controllore |
| Punto fisso e dinamica limitata | Passata sia sul riferimento Python sia sui test Dart |
| Sintassi Bash dello script build | Passata con `bash -n` |
| Script build remoto | Passato, exit 0, APK release prodotto |
| Analisi Dart e 26 test Flutter | Passati; le segnalazioni residue dell’analizzatore sono informazioni di stile/deprecazione, non errori o warning |
| Test Android UI/apprendimento/correzione/riapertura | Passato su emulatore Android API 35 |
| Installazione e avvio dello stesso APK release | Passati su emulatore API 35; firma e identità verificate |
| Fotocamera, microfono e provider file su telefono fisico | Non verificati manualmente |
| Benchmark indipendente di comprensione e vantaggio MGD | Non eseguito |

Il pacchetto include i risultati reali `offline_checks.json` e `build_status.json`, gli script e i test. Non include risultati simulati o log della versione precedente.

## Provenienza del collaudo

https://github.com/agdiegorusso-stack/MGD-model/actions/runs/37320325261

APK: `MGD-Neural-0.42.0.apk`, SHA-256 `ffc0b414311a5c455e6c1d8b902dc05be99b4f60f0183e4ba1b097ae7e5041cd`, commit `4678984cfa3324fbcb304aa2e2f4e07390d737b5`. I log della build e dei test, i controlli della firma e il riepilogo sono inclusi in `tool/reports/`.
