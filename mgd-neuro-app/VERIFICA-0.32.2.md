# MGD Neuro 0.32.2 — mappa e lettura

Correzioni ricavate dalle schermate della 0.32.1:

- La chat memorizzava «ciao» nel vocabolario; la mappa consultava le entità semantiche, senza accesso al vocabolario. Ora la vista Lingua mostra le parole e le successioni effettivamente osservate. La ricerca attraversa le memorie e seleziona quella che contiene il risultato.
- I nodi senza archi venivano nascosti quando il grafo non conteneva collegamenti. Ora sono rappresentati e dichiarati isolati, senza creare collegamenti artificiali.
- La ricerca aggiorna i dati prima di cercare; Indietro ripristina anche la vista di provenienza. Le conoscenze documentate sono visibili in Mondo con l’etichetta «con fonte»; le proposizioni in quarantena rimangono in Da verificare.
- Il disegno usa lo spazio effettivamente disponibile e lo zoom si adatta all’area occupata dai nodi. Controlli e dettagli rimangono consultabili su schermi piccoli e in orizzontale.
- Il lettore conserva l’inciso «In chimica» come contesto della frase, invece di incorporarlo nel nome dell’entità. Copule inverse o enumerazioni ambigue non diventano automaticamente relazioni «tipo di».
- Le estrazioni pregresse riconosciute come ambigue vengono messe in quarantena con il motivo. Proposizioni e fonti rimangono conservate; le correzioni esplicite dell’utente sono rispettate.
- Dopo una ricerca senza documenti pertinenti, un argomento composto come «Bioma o grande sistema ecologico» può essere cercato nelle sue parti. Sono ammessi titoli o redirect che risolvono quella parte; la semplice presenza della frase in un’altra pagina non basta. L’esito è indicato come argomento parziale: non si dichiara che i termini siano equivalenti.
- Lo stato del motore distingue la pausa per ricerca web, interazione, operazione e app non in primo piano. Nell’editor il punteggio delle relazioni è indicato come interno, non come probabilità di verità.

## Prova pratica

1. In Vivi scrivere «ciao» e inviare.
2. Aprire Mondo → Visualizza mappa.
3. Cercare «ciao»: la mappa deve selezionare Lingua e mostrare il nodo con il conteggio delle occorrenze. Se è stato osservato da solo, può avere zero collegamenti.
4. Ripetere dopo il riavvio. La parola deve restare ricercabile.

## Verifica

I nuovi test coprono parola isolata, persistenza, ricerca tra memorie, nodo semantico isolato, schermo piccolo e rotazione, estrazioni delle schermate, quarantena conservativa e ricerca di un argomento composto. Un test Android invia realmente «ciao» in chat, apre la mappa, lo cerca, riapre l’app e SQLite e ripete la ricerca.

Il lettore rimane basato su regole e non comprende ogni testo. L’aumento di cicli, archi attivi o età geometrica misura l’attività interna, non la correttezza dei fatti né l’intelligenza generale. Nessun confronto con Transformer è stato eseguito.
