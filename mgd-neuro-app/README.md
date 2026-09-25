# MGD Neuro 0.32.0

Applicazione Flutter Android con apprendimento incrementale su grafi, ricerca con provenienza e memoria SQLite locale. Questo albero contiene tutto il codice applicativo: non dipende dal recupero di vecchi artifact o da patch concatenate.

## Compilazione e test

Flutter 3.47.5, versione 0.32.0+59. Dalla radice del repository:

```
python3 mgd-neuro/v0315/ci.py signing
python3 mgd-neuro/v0315/ci.py platform
cd mgd-neuro-app
flutter pub get
flutter test --reporter expanded
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test integration_test/runtime_android_v0319_test.dart -d emulator-5554
flutter build apk --release --build-name 0.32.0 --build-number 59
```

La workflow build-mgd-neuro-0320 verifica package, versione, certificato originale e riapertura della memoria su Android prima di consegnare l'APK. La firma deve restare `bfd6e2660a3c3a6e3b37d1736e1619777b933e976c312c5b1c6cd38e908f1589`.

## Correzioni

- Ricerca: titolo/redirect risolto prevale sui termini di contesto; il solo contesto non ammette documenti estranei. Ricerche scientifiche anche sul soggetto, varianti singolari/plurali composte, motivi dei documenti scartati visibili.
- Prove: risoluzione conservativa di identità tra prosa e proposizioni identificate; relazione/oggetto completi devono coincidere e gli omonimi noti bloccano l'unificazione. Negazioni, qualificatori e famiglie di provenienza rimangono distinti.
- Riesame: attendibilità e metadati originali sono conservati. Nuova rilettura una tantum dei testi salvati. Cursori linguistici per contenuto invece che posizione nelle liste.
- Linguaggio: rimosso il beam search irraggiungibile. Le forme di predicato osservate vengono ricombinate con soggetto e oggetto espliciti; i cammini MGD ne valutano la forma. Se manca una forma osservata, la proposizione con fonte resta disponibile. Le risposte generate non diventano nuovi esempi di addestramento.
- Matematica: punto fisso coerente con la ricorrenza logistica effettiva; distanza minima nel denominatore della curvatura, nessun taglio arbitrario a -1; media inclusiva degli zeri misurati.
- Runtime: ripasso e scoperta dei concetti in isolate, scarto dei risultati diventati obsoleti, salvataggi atomici conservati, invalidazione concetti anche quando cambia il contenuto a parità di numero di fatti.
- Interfaccia: categorie di archi disgiunte, documenti distinti, errori che rilasciano il blocco dell'interazione, opportunità di ricerca anche con manutenzione pendente.

## Ambito delle verifiche

I test includono condizioni di contesto tratte dal guasto su Organismi, omonimia, contraddizioni, duplicati, conservazione della memoria, composizione di fatti non presenti nel corpus linguistico e riavvio Android. Gli esempi usati in repository sono sintetici. Nessuno snapshot personale è incluso.

Il punto fisso a forzante media costante non dimostra la media stazionaria di un processo stocastico non lineare. La curvatura usa misure uniformi troncate a 12 nodi per vicinato ed è una stima locale. Il modello resta un sistema a grafi con estrazione linguistica limitata; non è dimostrato superiore ai Transformer. Per tale conclusione servono modelli di confronto espliciti, dati separati di valutazione e misure comparabili di qualità, apprendimento, memoria, tempo ed energia.
