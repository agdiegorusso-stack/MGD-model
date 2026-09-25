# MGD Neuro 0.32.1

Questa versione corregge acquisizione, contatori e operazioni manuali. Non costituisce una dimostrazione di superiorità sui Transformer o di generazione linguistica generale.

## Cambiamenti

- Letture preliminari e incrementali condividono l’elenco delle frasi; nessun doppio conteggio della stessa frase nello stesso documento e studio.
- Nuove proposizioni, proposizioni già note, nuove evidenze e corroborazioni sono distinguibili. Una reimportazione dello stesso testo non crea altre evidenze.
- L’importazione locale usa lo stesso controllo delle evidenze del web. Una proposizione riconosciuta da una sola fonte è interrogabile con attribuzione; non diventa una conferma indipendente.
- Testi da elaborare e testi non interpretati sono distinti; il lettore non ripete indefinitamente tentativi identici. Il testo originale rimane consultabile nei limiti degli archivi già previsti dall’app.
- I macro-nodi mostrati nel dettaglio hanno la stessa soglia del contatore. I cicli MGD sono distinti dai richiami conservati. Curvatura non ancora misurata non viene mostrata come misura zero.
- Le metriche della pagina lingua aprono i relativi archivi. Le barre spiegano valore e significato. L’indicatore di curiosità sensoriale può legittimamente essere zero senza nuove percezioni.
- I richiami di relazioni esistenti sono etichettati come richiami, con attivazione interna, senza percentuali presentate come verità.
- I 96 cicli manuali e il ripasso del sonno vengono calcolati in un isolate. Le metriche del calcolo attraversano il worker e vengono salvate.
- L’esplorazione autonoma ha opportunità di avvio ogni minuto di inattività in primo piano, con almeno 15 minuti fra studi automatici dello stesso argomento. Restano i limiti dei provider e le attese per query già effettuate.
- Le deduzioni per transitività di classi mostrano tutte le premesse. Sono regole logiche esplicite, non nuove fonti e non un ragionamento generale emerso dalla geometria. Una premessa in quarantena rende inutilizzabile la relativa deduzione.

## Prova pratica

In Mente → Impara / esplora lingua, incollare:

> Il talverio è una sottoclasse di lorvante. Il lorvante è una sottoclasse di zermante.

Premere Impara testo incollato, poi chiedere in Vivi:

> Cosa puoi dedurre sul talverio?

La risposta deve riportare zermante e le due premesse. Il contenuto resta interrogabile dopo il riavvio. Reimportando lo stesso testo, le nuove evidenze devono essere zero; le esposizioni linguistiche possono aumentare perché il testo è stato effettivamente riletto.

## Verifica riproducibile

```sh
flutter test --reporter expanded
MGD_BENCHMARK_OUT=benchmark.json flutter test tool/learning_benchmark_v0321_test.dart --reporter expanded
flutter test integration_test/runtime_android_v0319_test.dart -d emulator-5554 --reporter expanded
```

Il benchmark usa 140 frasi sintetiche e 240 casi: 100 domande dirette, 100 riformulazioni, 20 deduzioni di classe e 20 domande senza risposta. Registra tempi, risposte, persistenza e reimportazione. Le regole linguistiche sono predisposte nel codice; entità e oggetti sono generati da un seme fisso. È una verifica circoscritta di acquisizione e recupero, non un test di comprensione aperta.

Per confrontare un Transformer servono modello e versione fissati, stesso contenuto disponibile, domande mai usate per l’addestramento del confronto, hardware dichiarato e misure di accuratezza, astensione, latenza e memoria. Nessuna baseline Transformer è stata eseguita in questa sessione: il risultato è esplicitamente `not_run` nel rapporto.

I test Android esercitano SQLite, pulsante di apprendimento, risposta in chat, riavvio e protezione da caricamento corrotto. Le misure sul computer di build non rappresentano automaticamente i tempi del telefono dell’utente.
