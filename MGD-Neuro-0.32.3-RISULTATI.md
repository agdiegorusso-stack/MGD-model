# MGD Neuro 0.32.3 — risultati verificati

Aggiornamento del 25 settembre 2026. Versione Android 0.32.3, codice 62.
Sorgenti dell'app: `9725c1fda0e024afd52550fe79e425d9ede8253e`.
L'audit del confronto aggiunge esclusivamente strumenti di verifica: la CI conferma che i file dell'app sono identici.

## Download
- [ZIP contenente app-release.apk](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36179215175/artifacts/10883629418)
- [Log dei test, firma, versione e SHA-256 dell'APK](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36179215175/artifacts/10883509514)
- [Confronto controllato, risultati caso per caso](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36179880148/artifacts/10883399293)
- [Prima prova e lettura reale di Bioma](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36179215175/artifacts/10883123887)
- [Sorgenti esatti della build](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36179215175/artifacts/10883609635)

Gli artefatti GitHub richiedono l'accesso e hanno conservazione di 30 giorni.
Estrarre app-release.apk e installarlo come aggiornamento, mantenendo l'installazione esistente.
Identificativo: `it.diegorusso.mgdneurostable`.
SHA-256 certificato: `bfd6e2660a3c3a6e3b37d1736e1619777b933e976c312c5b1c6cd38e908f1589`.
SHA-256 ZIP Android: `43ab145a4db1fa25fd52edc798268e46179568467b6dbcc3efff6abff80f05c9`.
Il valore sopra riguarda lo ZIP, non l'APK; l'hash dell'APK è in APK-SHA256.txt nell'artefatto dei rapporti.

## Risultato funzionale
La lettura reale della pagina Wikipedia italiana Bioma acquisisce 1868 caratteri e conserva 11 passaggi da una fonte. Ora produce una definizione strutturata con il contesto descrittivo, incluse le condizioni per gli ambienti terrestri e acquatici. La definizione ha una fonte: non viene presentata come corroborata da più fonti.

I testi che il lettore non struttura sono ricercabili nella nuova memoria delle fonti. La chat può riportarli con provenienza ed etichetta esplicita di passaggio testuale. Non vengono trasformati automaticamente in fatti o prove. In Mente il contatore «passaggi consultabili» apre tutti i testi e la ricerca.

## Verifiche concluse
- 216 test unitari e dell'interfaccia superati.
- 4 test Android superati su emulatore API 35.
- Verificati apprendimento dal pulsante e deduzione, ripristino SQLite, protezione dei dati corrotti, «ciao» nella mappa, citazione della fonte in chat, consultazione dei passaggi e persistenza.
- Benchmark sintetico precedente: 240/240, un passaggio su 140 frasi, risposte identiche dopo il ripristino, nessuna nuova evidenza dalla reimportazione. È una regressione su forme note, non una misura generale di comprensione.
- Analisi statica senza errori bloccanti; restano avvisi e informazioni del progetto.
- Release generata dopo i test Android; versione, identificativo e firma verificati nella CI.
- Le prove Android ricreano l'app e riaprono SQLite: non coprono ogni possibile terminazione dell'app da parte del sistema operativo.

## Confronto con un Transformer
Task: selezionare il passaggio che risponde alla domanda fra tre testi, oppure astenersi. Dataset di sviluppo di 24 casi, italiano e inglese. Non è un benchmark pubblico, blind o indipendente. Dati e codice MGD sono rimasti invariati durante l'audit.

| Sistema | Corretti | Mediana query, stessa CPU | P95 |
|---|---:|---:|---:|
| Memoria delle fonti MGD 0.32.3, indice lessicale/BM25 | 14/24 (58,3%) | 0,343 ms | 0,870 ms |
| Qwen2.5-0.5B-Instruct | 14/24 (58,3%) | 688,905 ms | 788,845 ms |

Il recupero nell'indice e la generazione autoregressiva sono operazioni diverse. I tempi non includono il pretraining, non sono tempi del telefono e non misurano energia. Il test non dimostra che la dinamica geometrica MGD sia superiore a un'architettura Transformer: valuta il sistema dell'app con un indice di fonti contro un piccolo modello preaddestrato.

| Categoria | MGD | Qwen2.5 |
|---|---:|---:|
| Definizioni italiane | 3/3 | 2/3 |
| Condizioni italiane | 2/3 | 2/3 |
| Negazioni italiane | 2/3 | 2/3 |
| Ruoli soggetto/oggetto | 2/3 | 2/3 |
| Parafrasi italiane | 0/3 | 2/3 |
| Definizioni inglesi | 3/3 | 1/3 |
| Condizioni inglesi | 2/3 | 1/3 |
| Anafore italiane | 0/3 | 2/3 |

La prima configurazione Qwen3-0.6B ha restituito 0 su tutte le domande. Il suo 6/24 non viene usato per dichiarare una vittoria. È stato eseguito un audit su quattro esempi di controllo separati dal dataset, con due configurazioni del prompt selezionate soltanto su tali esempi. Qwen3 non ha superato la soglia (2/4); Qwen2.5 l'ha superata (3/4, fallendo comunque il controllo di astensione). Anche questa debolezza della baseline limita il confronto. Il protocollo è stato corretto dopo aver osservato l'output costante: non si presenta la prova come preregistrata o blind.

Revisioni: Qwen3 `c1899de289a04d12100db370d81485cdf75e47ca`; Qwen2.5 `7ae557604adf67be50417f59c2c2f167def9a775`. CPU con 2 thread, PyTorch 2.8.0+cpu, Transformers 4.56.2. Dataset SHA-256 `ef8198a2990adfe27678d60b1c8b01e8c158ee1e521abbc374009d5cd9e2ac96`.

## Implicazioni per lo sviluppo
Il caso Bioma è risolto e la memoria delle fonti è utilizzabile in chat. La comprensione generale resta incompleta: parafrasi, risoluzione dei pronomi e interpretazione dei ruoli richiedono un lettore appreso o un analizzatore linguistico più completo. Alzare cicli, curvatura o soglie del grafo non insegna automaticamente queste competenze.

MGD mantiene il ruolo di dinamica della memoria e delle relazioni. La nuova indicizzazione è ingegneria del recupero testuale, non una derivazione dei teoremi MGD. I Transformer del confronto non sono stati inseriti nell'app.

La revisione dei PDF e le fonti esterne (Titans/MIRAS, Nested Learning, Mamba-2 e Universal Dependencies) sono descritte in [VERIFICA-0.32.3.md](mgd-neuro-app/VERIFICA-0.32.3.md). È documentata anche una discrepanza di segno tra ricorrenza logistica e formula dell'equilibrio nel PDF principale; il motore aveva già la formula coerente con la ricorrenza implementata. Non si tratta di una validazione completa delle dimostrazioni matematiche.

## Riproduzione
- Build e Android: https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36179215175
- Audit confronto: https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36179880148
- Test: `flutter test`
- Confronto MGD: `flutter test tool/source_eval_v0323_test.dart`, dalla cartella mgd-neuro-app.
- Audit: `python3 tools/mgd_comparison_0323.py`, dalla radice del repository, con le dipendenze della relativa workflow.

Durante questa sessione l'ambiente locale era indisponibile. Compilazione, test e conservazione dei risultati sono avvenuti in GitHub Actions; non viene dichiarata una verifica su un telefono fisico.
