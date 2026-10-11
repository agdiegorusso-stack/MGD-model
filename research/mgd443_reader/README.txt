MGD 443 — Lettore ricorrente proprio, sperimentale
================================================

Scopo: costruire capacità linguistiche MGD apprese senza pesi pretrained e
senza transformer, misurando separatamente sintassi, domande, referenti,
risposte e conservazione delle conoscenze. Comprensione totale NON risolta.

Documenti MGD esaminati
----------------------
Le tre copie allegate coincidono byte per byte con quelle precedentemente
esaminate. Generative Mathematics of Dimensions: 52 pagine, SHA256
ed10315a991520eabcf64042ee2c39dbf58a3212210def76d3320455a7bb9f49.
Prima parte delle risoluzioni: 56 pagine, SHA256
54ea46d47dc3f1c915f5d5a81658d7f9b6163ab4f76b97cf1341e2d35af871d1.
Seconda parte: 41 pagine, SHA256
2f1860792383abac5faf41dbdfd4a2cf1eee4205391f0d54f3e9e6ed1f86097b.
Sono stati letti il testo estratto e le sezioni pertinenti alla geometria,
memoria e dinamica; questo lavoro non certifica tutte le dimostrazioni fisiche.

Dal documento principale: eventi, costi simmetrici non nulli sugli archi
ammessi, grafo attivo, distanza di cammino, dimensione tramite crescita delle
palle, memoria delle attivazioni. Non vi è un algoritmo completo per apprendere
semantica linguistica, assegnare il credito o decodificare risposte. Il forcing
Bernoulli assegnato NON è già un errore predittivo appreso dal testo.

La variante linguistica qui proposta non eredita automaticamente i teoremi
del modello originale. Nell'indice PredictiveGeometry Q contiene solo la
classificazione dello stato dell'evento. Distanza TV, costo >= c0, soglia e
revisione del predittore sono espliciti. Tale geometria NON rende equivalenti
i nomi o le proposizioni e NON certifica verità. Gli episodi originali restano
conservati. Le idee di geometria predittiva erano già esplicite nei volumi
revisionati letti prima, quindi non vengono presentate come scoperta nuova.

Implementazione
---------------
1. Riconoscimento probabilistico delle entità appreso, separato dalla loro
   identità copiata dal testo. Nessuna tabella di due entità fornita in input.
2. Encoder ricorrente bidirezionale tanh, 48 unità per direzione, caratteri
   hashed appresi: parole nuove non diventano tutte lo stesso UNK.
3. Ruoli appresi: agente, predicato, oggetto, destinatario, tempo, negazione,
   condizione, modalità, luogo e riferimenti. Schema esplicito e limitato.
4. Domande in linguaggio naturale: classificatore appreso su caratteri e
   sequenze di parole. Non una scelta fra dodici domande prestabilite.
5. Coreferenza: confronto appreso dei candidati riconosciuti dal lettore.
   Genere grammaticale/articoli sono prior espliciti; margine per astensione.
6. Risposte estrattive con stato dell'evento e fonti. NON un decoder generativo
   libero addestrato. Le interpretazioni non vengono promosse a fatti veri.
7. Esperimento di plasticità: un controller appreso sceglie blocchi attraverso
   gradienti, errore futuro e replay. Non riceve manualmente la parola da
   aggiornare. I risultati su nuovi casi non dimostrano ancora un miglioramento
   affidabile; il controller resta fuori dall'app. Un tentativo senza guardia
   alterava 16/64 e 3/64 risposte nel replay; quello protetto non migliorava le
   capacità nuove misurate. Non è una soluzione all'apprendimento continuo.

Addestramento e licenza
----------------------
13.064 frasi italiane UD ISDT train, oltre a 6.000 frasi di curriculum nella
seconda variante. I ruoli da UD sono conversioni SILVER di annotazioni
sintattiche: non annotazioni di verità o comprensione completa.
Nomi nuovi numerosi nel curriculum impediscono di limitarsi a dodici nomi.
Esempi sintetici riusano strutture: non dimostrano generalizzazione a libri.
Ruoli e scopi restano fissi dopo l'addestramento offline nell'APK. Il testo
acquisito aggiorna memoria e il motore predittivo già presente; NON è provato
che aggiorni automaticamente la semantica di questo lettore.

UD Italian ISDT: https://universaldependencies.org/treebanks/it_isdt/
Repository: https://github.com/UniversalDependencies/UD_Italian-ISDT
Commit ff2447f6b21e03adbbbed5eff306f79b8857286b.
Contributori: Cristina Bosco, Alessandro Lenci, Simonetta Montemagni, Maria Simi.
Dataset CC BY-NC-SA 3.0. Per questi pesi sperimentali derivati dal dataset si
mantengono attribuzione e uso non commerciale con condivisione alle stesse
condizioni: https://creativecommons.org/licenses/by-nc-sa/3.0/
Il pacchetto non redistribuisce il corpus originale.

Risultati e interpretazione
--------------------------
Prima versione: accuratezza token 92,96%, F1 media dei sei ruoli valutati
81,37%, 178/480 frasi esatte nel test UD tenuto fuori dall'addestramento.
Seconda versione: 93,06%, F1 84,36%, 194/480 frasi esatte sullo STESSO test,
ora riutilizzato. Architettura e curriculum cambiano insieme: nessuna prova
isolata che il miglioramento derivi soltanto dalla fattorizzazione.
In entrambi i test controllati: 300/300 frasi esatte. Sono sintesi, non libri.
Primo interprete domande: 4/8 formulazioni riservate. Nuova testa: 7/8 su un
altro insieme, con diverse confidenze sotto la soglia .55, quindi anche le
classificazioni corrette possono produrre astensione. Le prove riutilizzate
sono dichiarate nei protocolli, non conteggiate nuovamente come indipendenti.

Prima prova su 21 nuovi casi con risposta e ambito verificati: 13/21, incluse
astensioni appropriate. Presenti errori nei passivi, domande nuove, ambiguità
pronominali e contraddizioni. TUTTI i risultati sono esportati. Le correzioni
successive riusano questa prova come sviluppo e non ne fanno un nuovo test.
La prova contiene prosa originale scritta per il test, non autori/libri
indipendenti e non dimostra comprensione scientifica della dialisi.

Limiti ancora aperti
--------------------
Gli scopi delle proposizioni annidate richiedono eventi separati e riferimenti
tra clausole; una classificazione globale in quattro stati è insufficiente.
Mancano generalizzazione robusta a libri nuovi, decoder libero, apprendimento
semantico autonomo verificato, comprensione di quantificatori/implicazioni
arbitrarie, ragionamento scientifico generale e confronto energetico su telefono.
Non è dimostrata superiorità ai transformer né equivalenza al cervello umano.

Riproduzione
------------
Python 3.12, NumPy 2.3.5, SciPy 1.16.3, PyTorch CPU 2.10.0 solo per training.
train.py conserva il primo esperimento; train_v2.py la variante fattorizzata.
questions.py addestra la testa delle domande; reader.py esegue solo NumPy.
audit.py registra il protocollo PRIMA di valutare e conserva anche gli errori.
prepare_app.py prepara gli asset dai pesi del run immutabile 38176357502.
own_reader_v0443.dart porta l'inferenza in Dart; test numerico Python/Dart
separato dai test di efficacia. Nessuna chiamata a un servizio generativo.

L'APK 0.42.21 è un laboratorio utilizzabile con limiti espliciti, non una
soluzione dichiarata alla comprensione totale. I dati precedenti dell'app e
i brani originali vengono conservati; le vecchie note di un lettore diverso
non sono validate come note del nuovo modello.
