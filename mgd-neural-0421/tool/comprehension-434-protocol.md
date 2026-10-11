# Lettura in otto ambiti — protocollo 1

Suite: `assets/comprehension-434.json`.

SHA-256 fissato prima dell'esecuzione del motore:
`c2ba157a87c0e0e9d97233cf31bafe7bc1034bdb4dc2613ec1ce7a9312408db4`.

Gli esercizi sono testi originali, leggibili, con premesse sufficienti per le
risposte determinate. I riferimenti di meccanica, circuiti e biologia sono
indicati nel file. Non sono estratti dal database di risposte del motore.

Ogni ambito usa una memoria nuova: quattro domande prima della lettura,
lettura del solo paragrafo attraverso l'acquisizione di produzione, quattro
domande dopo. Testo e domanda sono gli unici dati consegnati al lettore.
Riferimenti, criteri, punteggi e commenti rimangono nell'esaminatore.
La memoria di ricerca deve restare identica durante entrambe le interrogazioni.
L'app conserva il rapporto senza insegnare gli esercizi alla memoria dell'utente.

32 casi: 8 recuperi, 16 collegamenti/applicazioni/cambi delle condizioni,
8 richieste di informazioni insufficienti. Le 24 conclusioni ricavabili sono
contate separatamente dalle astensioni. Dire soltanto «non determinabile»
non basta: occorre individuare il dato mancante. Le applicazioni richiedono
anche il calcolo o la giustificazione. Recuperare un passaggio non vale come
soluzione di applicazione. Per il recupero è valida anche una frase originale
pertinente citata singolarmente, oppure una relazione documentata. Non si
modifica il risponditore per alzare il punteggio.

Il controllo automatico usa criteri testuali dichiarati e viene calibrato
su risposte di riferimento e non-risposte. Non equivale a un giudice semantico:
una parafrasi corretta non riconosciuta deve essere valutata manualmente,
e una risposta accettata va comunque ispezionata. Il rapporto conserva tutte
le risposte, comprese quelle precedenti alla lettura, le domande e i testi.

Il test software verifica integrità e funzionamento della misura, senza
imporre un punteggio al motore. I suoi risultati restano distinti dai risultati
di comprensione. Il superamento della suite non certifica comprensione
generale. Il mancato superamento documenta limiti nei casi effettivamente provati.

Revisione 2 del valutatore: l'ispezione delle risposte della prima esecuzione
(commit `8a5e44a7ae0d9ae09c28b555f8cf726d8a73776b`, 0/32 automatico)
ha identificato tre recuperi corretti che il valutatore non contava: due frasi
citate e una relazione preceduta da un'intestazione. Sono riconosciuti come
recuperi, senza cambiare testi, domande, riferimenti o risponditore. La prima
esecuzione resta conservata separatamente nel rapporto di consegna. La misura
di applicazione e identificazione dei dati mancanti non cambia.
