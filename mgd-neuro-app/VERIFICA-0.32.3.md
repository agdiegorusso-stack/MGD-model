# MGD Neuro 0.32.3 — lettura, memoria delle fonti e confronto

## Problema concreto
La 0.32.2 conservava molte frasi ma rispondeva quasi soltanto attraverso le proposizioni che il lettore a regole riusciva a estrarre. Una condizione introdotta da «se» faceva scartare l'intera frase, anche quando seguiva una definizione nominale esplicita. L'acquisizione del documento non equivaleva quindi alla disponibilità del suo contenuto nelle risposte.

## Modifiche
- Nuova memoria persistente di passaggi con testo originale, titolo, URL e provenienza.
- Indicizzazione invertita e ordinamento BM25; le ricerche riusano l'indice fino al successivo inserimento.
- Deduplicazione per URL canonico e testo; interrogare o rileggere un passaggio non crea prove aggiuntive.
- Recupero dei testi pregressi ancora presenti negli audit, nei passaggi e nelle evidenze.
- Risposta testuale con fonte quando manca una relazione strutturata. Viene dichiarata come citazione pertinente, non come fatto validato.
- Interpretazione limitata di una definizione nominale seguita da un inciso descrittivo: la testa viene estratta, l'intero inciso resta un qualificatore.
- Un qualificatore descrittivo non può confermare una proposizione senza condizioni né alimentare la transitività delle classi.
- In Mente, «passaggi consultabili» apre una schermata con conteggio reale, ricerca, testi e fonti.
- Persistenza attraverso SQLite; test Android della risposta in chat e dell'apertura dei passaggi.
- Restano invariati i controlli della 0.32.2 su parole isolate, mappa, quarantena e provenienza.

Le frasi oltre 4000 caratteri non vengono troncate: il testo originale resta nel documento, ma la frase non entra nell'indice interattivo; il numero escluso nell'ultima acquisizione è disponibile nella diagnostica. L'indice è lessicale: non è un interprete generale di anafore, sinonimi o relazioni inverse.

## Cosa fornisce MGD
Sono state consultate le sezioni su memoria, pesi, materia logistica, equilibrio e cronogenesi di:
- Diego Russo, Generative Mathematics of Dimensions, marzo 2026, 52 pagine.
- Open Problems: Resolutions and New Results, Companion Paper 1, v26, 56 pagine.
- Companion Paper 2, 41 pagine.

Le ricorrenze descrivono la dinamica di una struttura relazionale. Trasferire i risultati di un reticolo con forcing Bernoulli a un grafo linguistico con input umani richiede ipotesi e validazione ulteriori. Attivazione, curvatura e flusso non sono probabilità di verità né misure automatiche di comprensione.

C'è anche una discrepanza algebrica nel documento principale: la ricorrenza della sezione 9 è M' = rho*M + (1-rho)*chi + xi*M*(1-M), mentre la formula di equilibrio delle equazioni 7–9 ha il segno dell'altro ramo. Per la ricorrenza scritta, ponendo a=1-rho, l'equilibrio a forcing medio costante soddisfa xi*M²+(a-xi)*M-a*chi=0. Con rho=.92, xi=.06 e chi=.5 la radice corretta è 2/3; la formula stampata restituisce 1/3, che non è un punto fisso di quella ricorrenza. Il motore 0.32.2 usa già il punto fisso coerente con la ricorrenza positiva: non è stato reintrodotto il segno incoerente. Questo controllo puntuale non costituisce una revisione completa delle dimostrazioni dei tre paper. L'equilibrio del forcing medio non coincide necessariamente con la media stazionaria della dinamica non lineare.

## Ricerca esterna e decisioni
1. Titans: Learning to Memorize at Test Time — https://arxiv.org/abs/2501.00663
2. Google Research, Titans + MIRAS, 4 dicembre 2025 — https://research.google/blog/titans-miras-helping-ai-have-long-term-memory/
3. Google Research, Nested Learning, 7 novembre 2025 — https://research.google/blog/introducing-nested-learning-a-new-ml-paradigm-for-continual-learning/
4. Mamba-2 / Structured State Space Duality — https://arxiv.org/abs/2405.21060
5. Universal Dependencies — https://universaldependencies.org/u/dep/
6. Qwen3-0.6B, scheda ufficiale — https://huggingface.co/Qwen/Qwen3-0.6B

Titans/MIRAS motivano lo studio di memorie aggiornabili durante l'uso; Nested Learning studia aggiornamenti a più scale temporali. Sono modelli e programmi di addestramento, non componenti che trasformano automaticamente questo lettore in un modello linguistico competitivo. Mamba-2 riguarda il calcolo delle sequenze e non risolve da solo l'estrazione semantica. Universal Dependencies offre una rappresentazione linguistica utile, ma in questa versione non è stato inserito un parser preaddestrato.

La modifica implementata è una memoria di fonti indicizzata accanto alle proposizioni e alla dinamica MGD già presente. Non è un'implementazione di Titans, MIRAS, Hope o Mamba, e non ne eredita i risultati pubblicati. Il Transformer del confronto resta fuori dall'app.

## Protocollo di confronto
Il dataset `tool/source_eval_v0323.json` è fissato prima della prima esecuzione. Contiene 24 casi scritti per lo sviluppo, otto categorie in italiano e inglese, sei domande senza risposta e casi di negazione, condizioni, ruoli invertiti, parafrasi e anafore.

Entrambi i sistemi ricevono gli stessi tre passaggi e devono selezionare la fonte che risponde alla domanda, oppure 0. MGD usa l'indice dell'app; Qwen3-0.6B usa un prompt con istruzioni identiche per tutti i casi, modalità senza thinking, decoding deterministico e 12 token massimi. La revisione esatta del modello e le versioni software vengono registrate. Entrambi vengono eseguiti sulla stessa macchina CPU. Gli errori di formato del modello valgono come errori, non vengono eliminati.

Si riportano accuratezza complessiva e per categoria, tempi di ricerca, caricamento del modello, acquisizione dei passaggi e stabilità al ripristino. Non si equipara il pretraining del Transformer all'inserimento di un documento nell'indice. I tempi non sono misure sul telefono. Non si modifica il dataset per migliorare il punteggio dopo aver visto i risultati.

Questo è un confronto di selezione delle fonti contro un piccolo Transformer, non un benchmark pubblico indipendente né una prova di superiorità generale di MGD. Il benchmark sintetico precedente da 240 domande viene mantenuto come regressione, non presentato come evidenza di comprensione generale.

## Risultati
I risultati definitivi sono nei log della CI e negli artefatti `MGD-Neuro-0.32.3-reports` e `MGD-Neuro-0.32.3-comparison`. Se il download o l'esecuzione del modello fallisce, il confronto viene segnato fallito, senza inventare punteggi.
