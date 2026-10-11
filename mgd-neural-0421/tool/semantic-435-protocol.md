# Operazioni sulle letture — 0.42.15

La chat e MemoryQuery428 chiamano lo stesso ReadingReasoning435. L'adattatore
legge esclusivamente le righe originali conservate in sourceMemory323. Le fonti
ritirate o rifiutate restano escluse; i conflitti bloccano gli specifici passaggi
di evidenza. Una singola estrazione in quarantena non esclude tutte le altre
frasi del documento: l'interprete valuta le frasi originali, mantenendo
negazioni, condizioni e proprietà mancanti. Non legge
report, criteri o risposte di riferimento e non interroga un modello esterno.

SemanticReasoning435 interpreta grammatiche italiane esplicite: equazioni
abbinate alla loro definizione verbale; quantità e unità; acquisti e rimborsi;
classi universali e istanze; spostamenti con orari; orari di partenza e durate;
differenze tra valori; antecedenti ed effetti espliciti; proprietà dichiarate
mancanti. Le classi si collegano anche tra documenti distinti. Gli eventi e i
conti restano all'interno di un singolo racconto per evitare di combinare
contesti omonimi. La risposta conserva fonti e passaggi. Domande e supposizioni
temporanee non entrano nella memoria delle letture.

Non è un interprete completo del linguaggio naturale. Le formule non hanno
più di due variabili a destra e la soluzione inversa richiede una sola occorrenza
dell'incognita. Le istruzioni esplicative dopo la domanda non nascondono più
l'interrogativa, anche nel vecchio motore delle regole. Formule condizionali,
negate o interrogative non sono apprese come uguaglianze universali. Un valore
mancante o incompatibile provoca astensione motivata. La semplificazione
morfologica delle classi non sostituisce un lessico italiano completo.

La verifica originale comprehension-434.json e il suo SHA restano invariati:
sono casi già conosciuti durante lo sviluppo e dunque una regressione, non una
valutazione cieca. I 40 ulteriori casi sono controlli di trasferimento scritti
dopo l'implementazione, con altri valori, oggetti, verbi e formule. Includono
rimozione e inversione della fonte, unità convertite, zero, negazione, conflitti,
assenza di premesse, nuovi acquisti, un percorso sul limite dell'orario, catene
tra documenti. Non provano comprensione generale illimitata.

Un test distinto usa lettura, memoria, query e ripristino reali dell'app con
SQLite; verifica la stessa soluzione prima e dopo il ripristino e l'assenza di
scritture durante le domande. I numeri nelle risposte dipendono dalle quantità
della domanda e dalla formula letta; le prove non forniscono risposte al motore.
