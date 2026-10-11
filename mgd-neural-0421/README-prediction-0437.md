# MGD Studio 0.42.17 — previsioni apprese

Sorgenti basati sul commit 3f90c4e5cc26ee75de685fba0d7fb7b0b5365324 (0.42.16).

Il predittore ricorrente ha 20 componenti nascoste, 8 token di contesto ordinato e al massimo 511 token espliciti più un ingresso sconosciuto. Impara embedding, matrice ricorrente, proiezione di uscita e peso dei richiami MGD tramite softmax, entropia incrociata e backpropagation nel tempo. La geometria discreta MGD resta una caratteristica di ingresso, senza fingere di derivare la soglia.

Ogni osservazione usa al massimo 8 obiettivi distribuiti nel testo e 2 esempi di replay. Sono conservati al massimo 64 esempi di replay e 32 di controllo. Una divisione deterministica riserva il 20% delle sequenze dagli aggiornamenti neurali; le caratteristiche di memoria del controllo sono congelate prima dell'esposizione. Parole e frammenti possono essere condivisi fra sequenze: questo controllo non dimostra comprensione generale.

Le nuove esposizioni esterne allenano il predittore. Le risposte prodotte dall'app e il vecchio replay delle risposte non diventano suoi obiettivi; una risposta insegnata o confermata esplicitamente può allenarlo. Il replay neurale usa solo gli esempi già acquisiti. I pesi, il vocabolario, i buffer e i contatori sono salvati nel campo opzionale `predictor437`, lasciando compatibili gli snapshot MGD versione 8. La cancellazione di un nodo azzera tutto il predittore per eliminare anche tracce distribuite, conservando le altre memorie.

Aprire **Previsioni apprese** dall'icona in alto. **Ripassa testi già osservati** avvia un ripasso limitato degli ultimi 128 testi utente/osservati già in memoria e salva i pesi. **Impara** e le nuove letture continuano l'allenamento. La prova di completamento mostra probabilità sulla prossima parola; le risposte fattuali continuano a usare il recupero e il ragionamento documentati.

La suite verifica derivate numeriche per ogni famiglia di parametri, apprendimento dell'ordine, contesti mai addestrati con un prefisso nuovo, separazione del controllo, ricaricamento e identità dell'aggiornamento successivo, limiti di risorse, compatibilità della memoria, esclusione delle risposte generate, cancellazione e percorso della schermata. I risultati di apprendimento sono registrati in `tool/reports/predictor-0.42.17.json`.

Il workflow compila un APK di sviluppo. Il file consegnato viene poi firmato con la chiave privata MGD Studio conservata fuori dal repository; la firma provvisoria di CI non è la firma del file consegnato.
