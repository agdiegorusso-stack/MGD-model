# Composizione quantitativa — 0.42.16

La comprensione generale illimitata non è implementata né dimostrata. Questo
aggiornamento estende un componente delimitato: il ragionamento quantitativo
su relazioni esplicite conservate nelle letture. Non aggiunge un modello
linguistico esterno e non trasferisce risposte dai test nella memoria.

Il motore identifica le quantità dai nomi definiti dalla fonte. Collega più
formule per nome della quantità, propaga valori intermedi, risolve inversamente
un'incognita e usa eliminazione lineare per sistemi accoppiati o variabili
ripetute. Non richiede un nuovo handler per ogni dominio o formula. Accetta le
definizioni verbali già supportate e le dichiarazioni «X indica la quantità»
abbinate a «Formula: X = ...», con +, -, *, / e parentesi. Le equazioni restano
nel contesto dello stesso documento; documenti omonimi non vengono sommati.
Le domande attraversano il percorso normale, anche dopo il ripristino.

Un risultato conserva le equazioni, le definizioni dei simboli, le premesse
numeriche temporanee e le sostituzioni disponibili. Ogni relazione completamente
istanziata viene nuovamente valutata prima di rispondere. Dati incompatibili,
sistemi insufficienti, inversioni non univoche, divisioni per zero, negazioni e
premesse incerte producono astensione. I valori già forniti nella domanda sono
segnalati come forniti, non come nuove deduzioni. Le istruzioni dopo la domanda
non sono premesse. Questo percorso tratta scalari; unità o qualificatori non
interpretati sono rifiutati, mentre i precedenti percorsi per unità e vettori
nelle formule singole restano disponibili.

Limiti: grammatica italiana esplicita, 32 quantità, 128 relazioni per componente,
64 iterazioni, 64 token per espressione, numeri floating point con tolleranze
numeriche. Non risolve sistemi non lineari generali, non induce automaticamente
nuove leggi scientifiche, non garantisce comprensione di testi arbitrari. Non
si deve rinominare questo componente «comprensione generale» nell'interfaccia.

Le verifiche originali negli otto ambiti e i 40 controlli di trasferimento restano
invariati. I nuovi controlli sono scritti durante lo sviluppo: misurano
composizione di formule, sistemi lineari, variazioni dei parametri, assenza o
conflitto di premesse e isolamento dei contesti. Non costituiscono una prova
cieca o illimitata. Un test distinto verifica lettura reale, query di produzione,
ripristino SQLite e invarianza della memoria delle fonti.
