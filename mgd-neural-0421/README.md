# MGD Neural 0.42.4

Ripristino del progetto completo 0.41.0 dopo la regressione della 0.42.0. Tutti i 59 file Dart originali sono conservati.

La navigazione principale espone Vivi, Impara, Mappa, Mondo e Mente. La mappa navigabile originale conserva ricerca tra memorie, vicinati, livelli, zoom, scelta del numero di nodi (anche oltre 300), esportazione PNG e cancellazione. Mondo conserva sensi, knowledge pack, editor e concetti multimodali; Mente conserva studio web, controlli del motore, sonno/consolidamento, salvataggio, lingua, archivio libri e Core cognitivo.

Impara rende accessibile il modulo di insegnamento precedentemente scollegato dalla navigazione. Apprendi testo e Importa TXT nel motore alimentano lingua, memoria relazionale, grafo, CLS e motore cognitivo. I paragrafi vengono appresi come eventi distinti; le domande non sono nuove osservazioni nel motore cognitivo. Importazione TXT a blocchi, UTF-8/UTF-16 con BOM e Latin-1; interruzione conservando i blocchi già acquisiti.

I testi insegnati nelle Esperienze CLS e nel laboratorio cognitivo sono inoltrati anche alle memorie consultate dalla chat e dalla mappa. La ricerca web mantiene le fonti e inoltra i documenti nuovi al Core cognitivo. Le memorie originali mantengono i propri archivi; non viene promessa una transazione unica tra tutti gli archivi.

Questo ripristino non dimostra comprensione generale, coscienza o equivalenza con un LLM. Foto e audio rimangono pattern sensoriali con etichette utente, non un riconoscitore generale o una trascrizione vocale.

Compilazione: `bash tool/build_android.sh`. La CI esegue tutti i test originali e le regressioni aggiunte, compila il release, verifica identità/firma ed esegue il flusso reale insegnamento → mappa → domanda → comandi del motore → riavvio su Android. Risultati effettivi e schermate sono negli artefatti della build e in `tool/reports`. Nessun risultato è dichiarato prima dell’esecuzione.

Correzioni 0.42.2 conservate: interruzione del testo incollato e dei replay con salvataggio delle sole frasi acquisite; cancellazione dalla mappa estesa ai riferimenti cognitivi, sociali, alle esperienze CLS contenenti il nome e alla memoria di lavoro; contatori cognitivi aggiornati anche dalla chat; export PNG annullato senza falsa conferma. La cancellazione rimuove riferimenti attivi, non ricostruisce ogni contributo storico ai pesi.

Correzione 0.42.4: chat e vista Mondo leggono la stessa memoria relazionale, anche per nomi composti e archi entranti. Le consultazioni di un concetto non sono insegnamenti. Il richiamo CLS precede l’acquisizione del messaggio corrente ed esclude le copie esatte della richiesta. I conflitti vengono segnalati; un nodo senza relazioni non produce una definizione inventata.

Correzione 0.42.4: le relazioni dei pack conservano più oggetti compatibili e le etichette degli oggetti restano atomiche. Contenimento, localizzazione, funzioni, processi, cofattori e interazioni non generano conflitti per la sola molteplicità. Le relazioni funzionali note e le affermazioni positive/negative incompatibili mantengono il controllo dei conflitti. La manutenzione non accorpa più i predicati ha-funzione/ha-localizzazione in ha.
