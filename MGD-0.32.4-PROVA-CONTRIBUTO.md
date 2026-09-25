# Prova del contributo MGD nella memoria relazionale 0.32.4

**Conclusione: il modulo relazionale corrente non mostra un vantaggio causale dovuto ai calcoli MGD.** Rimuoverli conserva le risposte e l'ordinamento nei test eseguiti. Il codice ne spiega il motivo con un'invariante.

Data: 25 settembre 2026. App esaminata: `336848c817d3fbed5c6b5906ff085d262d21e914`. Protocollo e strumenti fissati prima dell'esecuzione al commit `b5412cbc4c58006006337aaa8c5daf52f6aec7a3`.

[Scarica direttamente l'APK verificato](https://github.com/agdiegorusso-stack/MGD-model/releases/download/mgd-neuro-v0.32.4/MGD-Neuro-0.32.4.apk). Questo audit non modifica l'APK.

## Risultati osservati

| Verifica | Risultato |
|---|---:|
| Pilot con MGD | 288/288 |
| Pilot senza evoluzione né ordinamento MGD | 288/288 |
| Differenza di accuratezza | 0 punti percentuali |
| Predizioni diverse dopo ripristino | 0 |
| Confronti dell'ordine dei candidati | 19.200 |
| Differenze nell'ordine | 0 |
| Domande testuali nello stress | 12.800 |
| Differenze nelle risposte testuali | 0 |
| Differenze nei record semantici ai controlli periodici | 0 |
| Correzioni riuscite | 320 |
| Inserimenti iniziali/nuovi, escluse correzioni | 3.388 |
| Duplicati riconosciuti | 672 |
| Massimo di candidati concorrenti osservato | 77 |
| Stati geometrici correnti non uniformi osservati | 0 |

Lo stress usa 20 sequenze pseudocasuali di 160 passi, con ripristini periodici. Le 19.200 query sono confronti di equivalenza, non altrettanti quesiti linguistici indipendenti né un punteggio di accuratezza del 100% su un benchmark esterno. Il pilot resta il dataset sintetico di sviluppo già dichiarato.

Il controllo positivo altera artificialmente lo stato geometrico di una relazione: l'ordine MGD cambia rispetto al controllo cronologico. La verifica è quindi sensibile a una differenza reale di ordinamento. Questa manipolazione non dimostra un miglioramento semantico.

## Perché il precedente confronto non bastava

La funzione del pilot considera una risposta soltanto se esiste esattamente un candidato; con zero o più candidati restituisce null. Cambiare l'ordinamento non può modificare quel risultato. Il confronto precedente era quindi inadatto a dimostrare il beneficio dell'ordinamento MGD. È un limite del test che avevo implementato.

La verifica corrente rimuove invece l'intera evoluzione MGD e il calcolo della priorità dal modulo e aggiunge casi con candidati concorrenti. Lettore, pesi, regole, fonti, deduplicazione, versionamento, indici e formattazione restano identici.

## Dimostrazione nel codice, entro condizioni esplicite

Indichiamo con S lo stato geometrico iniziale dopo il primo aggiornamento.

1. Ogni nuova relazione parte dagli stessi valori numerici e riceve lo stesso passo deterministico: il suo stato diventa S.
2. Le ripetizioni non aggiornano la geometria. Le domande non aggiornano la geometria.
3. Una correzione crea un nuovo record nello stato S. Il vecchio record riceve l'aggiornamento negativo, ma diventa storico ed è escluso dai candidati correnti.
4. Serializzazione e ripristino fedeli conservano questo stato.

Per induzione, partendo da memoria vuota e usando queste operazioni, tutti i record correnti mantengono la stessa priorità geometrica. L'ordinamento MGD va sempre a pareggio e ricorre all'ordine cronologico. Rimuovere quei calcoli non cambia le risposte semantiche del modulo.

La conclusione assume assenza di manipolazioni esterne dei campi geometrici. Non riguarda altri motori dell'app, tutti i possibili snapshot importati o ogni possibile implementazione della teoria MGD. I campi geometrici visualizzati e il costo computazionale differiscono tra le varianti.

## Che cosa possiamo e non possiamo concludere

- La nuova memoria conserva e corregge le relazioni coperte dai test.
- I risultati del suo pilot sono interamente riproducibili senza i suoi calcoli MGD.
- Non è dimostrata superiorità sui Transformer. Il confronto precedente con Qwen resta non conclusivo; non è stato ripetuto qui per attribuire a MGD un risultato spiegato dagli altri componenti.
- Non si deduce che la teoria MGD sia falsa o che nessuna architettura basata su MGD possa funzionare.
- Per cercare un vantaggio MGD servirà un'implementazione in cui l'esperienza differenzi effettivamente la geometria e questa contribuisca a una decisione valutabile, con feedback e obiettivi espliciti. Il confronto dovrà conservare identici dati e compiti, includere una memoria semplice e una baseline Transformer verificata, e usare dati indipendenti. Non basta far crescere contatori o disegnare un grafo.

## Verifica e riproduzione

- [Protocollo fissato prima dell'esecuzione](https://github.com/agdiegorusso-stack/MGD-model/blob/b5412cbc4c58006006337aaa8c5daf52f6aec7a3/MGD-0.32.4-PROTOCOLLO-CONTRIBUTO.md)
- [Codice del test](https://github.com/agdiegorusso-stack/MGD-model/blob/b5412cbc4c58006006337aaa8c5daf52f6aec7a3/tools/mgd_contribution_0324_test.dart)
- [Generatore della variante senza MGD](https://github.com/agdiegorusso-stack/MGD-model/blob/b5412cbc4c58006006337aaa8c5daf52f6aec7a3/tools/prepare_mgd_contribution_0324.py)
- [Esecuzione CI conclusa con successo](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36188648800)
- [Archivio completo: predizioni, log e sorgente rimosso](https://github.com/agdiegorusso-stack/MGD-model/actions/runs/36188648800/artifacts/10887470780) — gli artifact Actions possono richiedere accesso GitHub.
- [Riepilogo numerico JSON pubblico](https://github.com/agdiegorusso-stack/MGD-model/blob/mgd-neuro-mobile/MGD-0.32.4-PROVA-RISULTATI.json)

SHA-256 del modulo originale: `a90cf550ed0f96ec3ce5bc8d335018c702625e2a86deed05503b9caa99d44b17`.
SHA-256 della copia privata dei calcoli MGD: `03c90cc8dd17adb8ecf8091d6b69f5e8296f8b66f78d443f05c5070b33fe43b7`.

La copia è un controllo sperimentale generato soltanto nella verifica, non un aggiornamento nascosto dell'app.
