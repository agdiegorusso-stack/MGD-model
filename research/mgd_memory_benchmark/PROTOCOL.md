# Esperimento MGD: memoria rumorosa e cambiamenti

25 settembre 2026. Protocollo fissato prima dell'esecuzione dei risultati finali.
Non è una preregistrazione esterna. È un esperimento progettato dopo il fallimento
del contributo causale del modulo relazionale 0.32.4.

## Ipotesi falsificabile

La dinamica memoria-costo-materia ispirata a MGD migliora la ricostruzione di
associazioni da osservazioni rumorose e mutevoli, rispetto a un Transformer
causale addestrato sul compito e a controlli semplici con la stessa informazione.

Il risultato riguarda questo compito sintetico. Non dimostra superiorità nel
linguaggio naturale, su tutti i Transformer o su modelli di frontiera.

## Dati e accesso alle risposte

8 chiavi, 4 valori, 128 eventi per episodio. Ogni evento mostra una chiave e
un valore osservato; il bersaglio è il suo valore latente corrente. Il bersaglio
non è dato alla memoria durante la valutazione. Rumore uniforme sugli altri tre
valori, probabilità 0,20. Cambiamento latente per visita: 0, 0,06 oppure 0,20.
Nessun modello vede il futuro. La metrica primaria media i tre scenari e gli
eventi 17-128; i primi 16 sono riscaldamento comune.

Validazione: 64 episodi per scenario, seed 62000-62002. Test: 256 episodi per
scenario, seed 72000-72002; generato soltanto dopo selezione e addestramento.
I dati sono sintetici, non un benchmark esterno indipendente. Le strutture dei
generatori di addestramento e test sono le stesse, con episodi disgiunti.

## Sistemi

- MGD: memoria esponenziale dell'eq.(1), costo dall'eq.(2), materia logistica
  dall'eq.(6), correzione del costo dall'eq.(10) del paper principale. Il punto
  fisso è ricalcolato coerentemente con eq.(6), perché eq.(9) ha un segno diverso.
- Adattamenti dichiarati: stato per coppia chiave-valore; tempo locale per
  visite della chiave; trigger di un singolo arco, non due vicini della griglia;
  minimo costo come decodifica; possibile tetto al costo. Non è la simulazione
  dell'intero modello geometrico del paper e non ne eredita automaticamente i
  teoremi. Non usa qui curvatura Ricci, entropia o dimensione emergente.
- Controlli: rimozione materia a parametri identici; rimozione memoria;
  rimozione materia con nuova selezione in validazione; costi senza tetto;
  media esponenziale (EMA), conteggi, ultima osservazione, assenza di stato.
- Riferimento Bayesiano: conosce probabilità del generatore; è esplicitamente
  privilegiato e serve a mostrare quanto manca al riferimento statistico.
- Transformer: due blocchi causali, dimensione 48, quattro teste, MLP 96,
  embedding di chiavi e valori, posizioni sinusoidali, normalizzazione e testa
  a quattro classi. Non è un modello linguistico preaddestrato.

MGD ha indirizzamento esatto delle chiavi progettato; il Transformer apprende
l'uso del contesto. Sono prior strutturali e budget di apprendimento diversi,
da dichiarare anziché nascondere. Un'eventuale vittoria non identifica da sola
la causa: servono le ablazioni e il controllo EMA.

## Budget e selezione

MGD: 54 configurazioni (3 alpha, 3 drift, 3 coefficienti materia, 2 tetti).
La materia usa rho=0,8 e xi=0,1, dentro il dominio di invarianza.
EMA: 11 decadimenti. Scelta esclusivamente su validazione.

Transformer: seed 21,22,23; 800 aggiornamenti per seed, batch 32, lunghezza128;
3.276.800 eventi di addestramento per seed. AdamW lr0,002, decay0,01; gradient
clip1. I batch mescolano hazard 0/0,03/0,06/0,20 e rumore0/0,1/0,2/0,35.
Checkpoint scelto ogni100 passi sulla validazione. Si pubblicano tutti i tre
seed, senza scegliere il migliore sul test. Nessun prolungamento selettivo
dell'addestramento dopo i risultati.

Controlli Transformer: accuratezza >=95% su episodi separati senza rumore e
assenza di dipendenza dal futuro (differenza logit <1e-5). Un modello che non
li supera è una baseline non valida per la rivendicazione prevista.

## Esito e incertezza

Pubblicare ogni risultato, anche negativo. Criterio di successo: tutti i
controlli passano e l'intervallo bootstrap95% della differenza MGD meno
Transformer, MGD meno EMA e MGD meno variante senza materia riottimizzata
rimane strettamente sopra zero. Bootstrap appaiato e stratificato per scenario,
3000 ricampionamenti; unità l'episodio, non il singolo evento correlato.
L'intervallo condiziona sui tre checkpoint e non copre ogni variabilità del
training. Si pubblicano le differenze per scenario e per seed.

I tempi sono throughput di un batch256 sullo stesso CPU; il Transformer può
calcolare in parallelo con maschera causale. Nessuna rivendicazione su latenza
Android o consumo energetico. Pesi, predizioni, dati, parametri e hash vengono
conservati. L'app Android non viene modificata da questo esperimento.

## Riferimenti primari

- Russo, Generative Mathematics of Dimensions, marzo2026, sezioni2,9-11.
- https://arxiv.org/abs/2501.00663 — Titans, memoria appresa durante l'uso.
- https://arxiv.org/abs/2407.04620 — Test-Time Training, stato aggiornato da un obiettivo.
- https://arxiv.org/abs/2102.11174 — fast weights e correzioni con regola delta.
- https://github.com/HazyResearch/based — compromesso memoria/recupero; il
  compito qui implementato è diverso da MQAR e non ne prende il nome.

Questi lavori motivano l'esperimento, ma non sono modelli riprodotti qui.
