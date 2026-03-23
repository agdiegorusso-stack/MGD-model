# Cortical MGD — Mappa dell'Architettura

## Diagramma di Flusso (componenti attivi)

```
INPUT (784-dim immagine/spike)
        |
        v
[spike_encoder.py] (*)
  rank_order_encode / rate_encode
  (*) NON usato attivamente in nessun modello live
        |
        v
+-----------------------------------------------+
|          CORE MATEMATICO                       |
|  mgd_metrics.py                                |
|  - compute_forman_ricci()   kappa              |
|  - compute_D_avg_torch()    D_avg              |
|  - compute_S_RT()           entropia min-cut   |
+-----------------------------------------------+
        |
        | (usato da CorticalColumn, routing, EWC, TemporalHierarchy)
        v
+-----------------------------------------------+
|        NEURONI BASE                            |
|  lif_adaptive.py  AdaptiveLIFGroup             |
|    LIF + adattamento soglia + sparsita 1-5%    |
|  wta_lateral.py   apply_wta_competition()      |
|    top-k spike selection                       |
+-----------------------------------------------+
        |
        | (composti dentro CorticalColumn)
        v
+-----------------------------------------------+
|        PLASTICITA                              |
|  stdp_mgd.py      STDPMgd                      |
|    STDP modulata da kappa + D_avg              |
|  stdp_local.py    STDPLocal     (baseline)     |
|  stdp_local_mgd.py STDPLocalMGD (locale)       |
|  homeostasis.py   normalizzazione pesi         |
|  bio_readout.py   BioReadout                   |
|    Oja + BCM metaplasticita + dopamina         |
|  geometric_ewc.py GeometricEWC                 |
|    EWC con importanza strutturale da D_avg     |
|  structural_plasticity.py  StructuralPlasticity|
|    pruning + sinaptogenesi locale (kappa)      |
+-----------------------------------------------+
        |
        v
+-----------------------------------------------+
|        COLONNA CORTICALE (mattone base)        |
|  cortical_column.py  CorticalColumn            |
|    W: [input_dim, n_neurons]                   |
|    forward: x @ W -> LIF -> WTA -> spikes      |
|    stdp: aggiorna tracce pre/post              |
|    compute_mgd_metrics(): (kappa, D_avg)       |
+-----------------------------------------------+
        |
        +------------------+------------------+
        |                  |                  |
        v                  v                  v
[MODELLI ARCHITETTURA]  [CONTINUAL]       [BENCHMARK]
        |                  |                  |
  area.py                  |           benchmark_suite.py
  CorticalArea             |           MGDBenchmarkSuite
  (ensemble colonne)       |           (tutti i modelli A-K)
        |                  |
  hierarchy.py        replay_buffer.py
  CorticalHierarchy   MGDReplayBuffer
  L1/L2/L3 3 aree     (buffer per task,
  (Fase 1)             selezione per varianza)
        |                  |
  routing.py          modular_gate.py
  route_via_S_RT()    ModularGate
                      (allocazione neuroni
                       per task)
        |                  |
        +------------------+
        |
        v
[MODELLI PRINCIPALI IN BENCHMARK]

  A_STDPLocal          CorticalColumn + STDPLocal
  B_MGD_EWC            CorticalColumn + STDPMgd + GeometricEWC
  C_MGD_LocalEWC       CorticalColumn + STDPLocalMGD + EWC
  D_MGD_Full           CorticalColumn + STDPMgd + EWC + replay
  E_CorticalBrain      cortical_brain.py  CorticalBrain
                         2 aree (sparse/visual) + ModularGate + replay
  F_HierarchicalBrain  hierarchical_brain.py  HierarchicalBrain
                         L1/L2/L3 + ModularGate + replay
  G_BioMGDBrain        bio_mgd_brain.py  BioMGDBrain
                         Ippocampo + 4 aree A-D + L2 + L3
                         routing S_RT, novelty, sleep (incompleto)
  H_LocalMGD           CorticalColumn + STDPLocalMGD
  I_OverlapMGD         CorticalColumn + ModularGate overlap
  J_NeuromorphicMGD    CorticalColumn + StructuralPlasticity
  K_TemporalHierarchy  temporal_hierarchy.py  TemporalHierarchy
                         3 livelli temporali (hip/cortex/neocortex)
                         + BioReadout + S_RT sleep
                         OTTIMIZZATO da OpenEvolve

        |
        v
[OPENEVOLVE]
  openevolve_mgd/
    initial_program.py   parametri iniziali K_TemporalHierarchy
    evaluator.py         fitness = retention@T5
    run.py               LLM-driven evolution (gpt-4.1-mini)
    results/best/        eta_da=0.012, tau_bcm=90.0, novelty_scale=24.0
```

---

## File per File

### `core/mgd_metrics.py`
Cuore matematico MGD. Tre metriche derivate dalla geometria iperbolica e dalla teoria della gravita olografica:
- **`compute_forman_ricci(W)`** — curvatura kappa: misura quanto la rete e ipabolica (molto negativa) o generica (vicino a 0). Usata come proxy dell'acetilcolina.
- **`compute_D_avg_torch(W)`** — dimensione effettiva via entropia SVD: quanto spazio rappresentazionale usa la colonna. Versione GPU-native.
- **`compute_S_RT(gram, src, snk)`** — entropia Ryu-Takayanagi via min-cut: misura la capacita informazionale tra partizioni della rete. Usata per routing e priorita nel sonno.

---

### `neurons/lif_adaptive.py`
`AdaptiveLIFGroup` — gruppo di neuroni LIF con adattamento della soglia. Ogni spike aumenta la soglia locale riducendo la probabilita di risparo (sparsita biologica 1-5%). Stato interno: tensori `v` (potenziale) e `a` (adattamento).

### `neurons/wta_lateral.py`
`apply_wta_competition()` — seleziona i top-k neuroni per potenziale, azzera tutti gli altri. Impone la sparsita target in output ad ogni forward pass.

### `neurons/spike_encoder.py`
`rank_order_encode()` e `rate_encode()` — converte input continui in spike train. **Non importato da nessun modello attivo.** Potenzialmente utilizzabile per preprocessing N-MNIST.

---

### `plasticity/stdp_mgd.py`
`STDPMgd` — STDP modulata da MGD. La learning rate eta viene scalata da kappa (curvatura) e D_avg (dimensione): aree ipaboliche apprendono di piu, aree sature apprendono meno. Usato in tutti i modelli dalla C in poi.

### `plasticity/stdp_local.py`
`STDPLocal` — STDP classica con learning rate fissa. Baseline sperimentale (modello A).

### `plasticity/stdp_local_mgd.py`
`STDPLocalMGD` — variante locale di STDPMgd che calcola la curvatura per sinapsi usando i gradi dei neuroni vicini invece dell'SVD globale. Piu efficiente, biologicamente piu plausibile.

### `plasticity/homeostasis.py`
`apply_homeostatic_normalization()` — normalizzazione moltiplicativa dei pesi in ingresso per mantenere la norma costante per neurone. Previene esplosione/collasso dei pesi durante STDP.

### `plasticity/bio_readout.py`
`BioReadout` — readout biologico senza backprop. Tre meccanismi sovrapposti:
1. **Oja**: PCA non supervisionata, stabilizza pesi
2. **BCM**: metaplasticita, ogni sinapsi scala la propria LR in base alla storia di attivazione
3. **Dopamina**: aggiorna solo se la predizione e sbagliata, scala per segnale DA

Usato da `TemporalHierarchy` (K) e `openevolve_mgd/evaluator.py`.

### `plasticity/geometric_ewc.py`
`GeometricEWC` — EWC dove la Fisher Information Matrix e sostituita dall'importanza strutturale: gradiente di D_avg rispetto a ogni colonna di W (differenze finite). Piu costoso ma piu fedele alla geometria della rete. Usato nei modelli B, C, D e (Phase 10) in BioMGDBrain.

### `plasticity/consolidation.py`
`compute_consolidation_mask()` — identifica sinapsi "mature" sopra soglia da proteggere. Usato solo nei test, non nei modelli attivi.

### `plasticity/structural_plasticity.py`
`StructuralPlasticity` — pruning e sinaptogenesi guidati da kappa locale, forza sinaptica, e co-attivazione. Il pruning libera neuroni per nuovi task. Usato nel modello J (NeuromorphicMGD).

---

### `architecture/cortical_column.py`
`CorticalColumn` — mattone base di tutta l'architettura. Contiene W (parametro apprendibile), LIF, WTA, STDP. Il metodo `compute_mgd_metrics()` restituisce (kappa, D_avg) della colonna corrente in tempo reale.

### `architecture/modular_gate.py`
`ModularGate` — alloca sottoinsiemi di neuroni a task specifici. Due strategie:
- `register_task()`: neuroni a bassa varianza (non sovrapposti)
- `register_task_overlapping()`: riusa neuroni generalisti (kappa bio > soglia)

### `architecture/area.py`
`CorticalArea` — ensemble di CorticalColumn con connettivita laterale sparsa. Usato in `CorticalHierarchy` (Fase 1).

### `architecture/hierarchy.py`
`CorticalHierarchy` — tre livelli L1/L2/L3 con CorticalArea. Il primo modello gerarchico (Fase 1). Nessun meccanismo di continual learning.

### `architecture/routing.py`
`route_via_S_RT()` — blocca la propagazione tra aree se S_RT < soglia. Filtra segnali informativamente insufficienti.

### `architecture/cortical_brain.py`
`CorticalBrain` — due aree specializzate (sparse per XOR/Banded, visual per MNIST) con routing automatico per densita input. ModularGate + MGDReplayBuffer per task. Modello E in benchmark.

### `architecture/hierarchical_brain.py`
`HierarchicalBrain` — versione gerarchica L1-L2-L3 di CorticalBrain. L3 convergenza condivisa. Modello F in benchmark.

### `architecture/bio_mgd_brain.py`
`BioMGDBrain` — architettura biologicamente dettagliata:
- Ippocampo (2000 neuroni, sparsita 2%) — separazione di pattern
- 4 aree corticali A-D (300 neuroni ciascuna) — routing S_RT
- Corteccia associativa L2 (500 neuroni)
- Esecutivo L3 (200 neuroni)
- `route_by_srt()` assegna ogni task all'area con piu capacita
- `_get_tasks_by_srt()` ordina task per S_RT decrescente
- `sleep_consolidation()` **INCOMPLETO** (Fase 10 da implementare)

Modello G in benchmark.

### `architecture/temporal_hierarchy.py`
`TemporalHierarchy` — tre scale temporali biologiche:
- L1 Ippocampo: tau=1 task, eta=1.0x, sparsita 2%
- L2 Corteccia: tau=3 task, eta=0.1x, sparsita 10%
- L3 Neocortex lento: tau=10 task, eta=0.001x, sparsita 5%

Consolidazione a cascata: L1->L2 ogni task, L2->L3 ogni n_slow task con EWC forte.
BioReadout per ogni task (Oja + BCM + dopamina).
**Ottimizzato da OpenEvolve**: eta_da=0.012, tau_bcm=90.0, novelty_scale=24.0.
Modello K in benchmark (retention@T5 = 1.000).

---

### `continual/replay_buffer.py`
`MGDReplayBuffer` — buffer di esperienza per task. Salva i K campioni piu discriminativi per task (alta varianza negli spike). Supporta preprocessing (es. passaggio per ippocampo). `sample_replay()` restituisce batch per replay interleaved.

### `continual/geometric_ewc.py`
`GeometricEWC` — vedi sezione plasticity.

### `continual/mgd_consolidation.py`
`MGDConsolidation` — wrapper minimale su `compute_consolidation_mask()`. Usato solo nei test.

### `continual/task_geometry.py`
`TaskGeometry` — traccia i shift geometrici (D_avg, kappa) tra task sequenziali. Strumento di monitoraggio, non integrato nei modelli attivi.

---

### `distillation/llm_interface.py`
`OllamaInterface` — interfaccia REST a un'istanza locale Ollama. Estrae soft label, embedding, e pesi di attenzione LLM per distillazione nella SNN. Fallback sintetico se Ollama non e disponibile. **Feature di ricerca**, non usata in produzione.

### `distillation/attention_extractor.py`
`extract_geometric_targets()` — converte le matrici di attenzione LLM in target geometrici (D_avg_llm, kappa_llm, S_RT_llm) per allineamento SNN-LLM.

### `distillation/soft_trainer.py`
`GeometricSoftTrainer` — loss di distillazione combinata: CE + differenza D_avg + divergenza kappa + divergenza S_RT. **Feature di ricerca**.

---

### `benchmark/benchmark_suite.py`
`MGDBenchmarkSuite` — framework di valutazione centrale. Genera task (XOR, Banded, MNIST 0-4, MNIST 5-9, N-MNIST), addestra e testa tutti i modelli A-K, misura retention e forgetting. E il punto di ingresso per tutti i test sperimentali.

### `benchmark/energy_profiler.py`
`EnergyProfiler` — stima il consumo energetico per inferenza SNN e lo confronta con Transformer densi. Strumento di analisi.

### `data/nmnist_loader.py`
`load_nmnist()` / `load_nmnist_flat()` — carica N-MNIST neuromorfico via Tonic, converte frame eventi in tensori spike binari 784-dim.

---

### `openevolve_mgd/`
Pipeline di ottimizzazione iperparametrica LLM-driven per `TemporalHierarchy`:
- **`initial_program.py`** — parametri iniziali (punto di partenza evolutivo)
- **`evaluator.py`** — funzione fitness: retention@T5 su 5 task sequenziali
- **`run.py`** — esecuzione OpenEvolve (100 iterazioni, 20 popolazione, 1 isola, gpt-4.1-mini)
- **`results/best/best_program.py`** — parametri ottimali trovati

---

---

## Script di root (ricerca/)

Script standalone nella cartella radice del progetto, usati durante lo sviluppo.

### `run_benchmark.py`
Entry point principale per eseguire il benchmark completo: instanzia `MGDBenchmarkSuite`, lancia `run_task_sequence()` su tutti i modelli A-K, salva risultati in `benchmark_table.txt` e grafico `benchmark_results.png`.

### `run_all_tests.py`
Lancia pytest su tutta la cartella `cortical_mgd/` e salva output in `test_all_log.txt`.

### `run_tests.py`
Lancia pytest su `test_mgd_metrics.py` e salva in `test_full_log.txt`.

### `run_tests_neurons.py`
Lancia pytest su `test_neurons.py` e salva in `test_neurons_log.txt`.

### `run_tests_plasticity.py`
Lancia pytest su `test_plasticity.py` e salva in `test_plasticity_log.txt`.

### `run_tests_strict.py`
Versione estesa di `run_tests.py`: dopo i test calcola manualmente kappa ORC e D_avg su grafi noti (star, disconnected, dense). Attenzione: referenzia `compute_ollivier_ricci` che non esiste piu in `mgd_metrics.py` (rimossa, sostituita da Forman-Ricci). **File rotto/obsoleto.**

### `run_val.py`
Lancia `quick_test_forgetting_D()` su MGDBenchmarkSuite e stampa i tre valori (lowvar, rand, abase). Usato per validazione rapida del modello D.

### `temp_bench.py`
Confronto temporale tra B_MGD_EWC (STDP+SVD globale) e H_LocalMGD (STDP locale senza SVD). Misura secondi e retention@T4 per valutare il tradeoff velocita/qualita.

### `test_xor_bench.py`
Test manuale del task XOR con `CorticalColumn` + readout `nn.Linear` + Adam + CrossEntropy. Utile per debuggare l'apprendimento di base prima di usare il benchmark.

### `check_spikes.py`
Test manuale spike count: instanzia `CorticalColumn` con `STDPLocal`, applica homeostasi, verifica che i forward pass producano spike non nulli. Usato per diagnosticare spike morti.

### `debug_orc.py`
Debug della vecchia funzione `compute_ollivier_ricci` su star graph. **File obsoleto**: referenzia una funzione rimossa da `mgd_metrics.py`.

### `tmp_simulate_bench.py`
Cerca un seed per cui il modello C migliora su A nel forgetting task1→task2. Cicla sui seed 1-99 con early stop. Script di ricerca parametri.

### `tmp_test_orc.py`
Calcola la Ollivier-Ricci Curvature su star graph via optimal transport (scipy `linprog`). Verifica matematica standalone, non usa nulla del progetto.

---

## DIMENSIONI/ — Prove matematiche MGD

Script Python a supporto della stesura del libro/articolo matematico MGD. Nessuna dipendenza da `cortical_mgd/`. Tutti producono grafici PNG o modificano file TEX.

### `DIMENSIONI/Nuova cartella/create_hierarchy.py`
Script eseguito una sola volta all'inizio del progetto per creare la struttura di cartelle e file vuoti di `cortical_mgd/`. **Non piu utile**, e uno scaffold iniziale.

### `DIMENSIONI/Nuova cartella/mgd_bifurcation_cancer.py`
Diagramma di biforcazione MGD nel modello dinamico M' = rho*M + (1-rho)*p + xi*M(1-M). Tre regimi: lambda>0 (tessuto sano, D_avg->2), lambda=0 (alternans cardiaci, precanceroso), lambda<0 (cancro, D_avg frattale). Salva `mgd_bifurcation_cancer.png`.

### `DIMENSIONI/Nuova cartella/mgd_block_argument.py`
Verifica numerica dei 3 passi della prova di stabilita globale MGD su Z²: (1) Lemma Jensen (diffusione riduce V), (2) Block Lyapunov (condizione F-L su reticolo finito), (3) limite termodinamico (correzione boundary ~ 4/L -> 0). Salva `mgd_block_argument.png`.

### `DIMENSIONI/Nuova cartella/mgd_dobrushin_full_z2.py`
Criterio di Dobrushin per unicita della misura stazionaria MGD su Z² con full coupling. Dimostra che per rho > 3/4 la costante c = 4*(1-rho)*alpha < 1, garantendo ergodicita geometrica. Analogia: canali ionici cardiaci.

### `DIMENSIONI/Nuova cartella/mgd_foster_lyapunov_proof.py`
Prova analitica + numerica del singolo sito Foster-Lyapunov: funzionale di Goh phi(M) = M - M* - M* ln(M/M*), condizione E[Delta_phi | M] <= -eps*phi + b. Analogia: Meyn-Tweedie + ecologia (Schreiber 2012).

### `DIMENSIONI/Nuova cartella/mgd_freidlin_wentzell.py`
Regime bistabile (rho <= 3/4): Freidlin-Wentzell quasipotential e legge di Kramers. Dimostra che il sistema passa facilmente da B (naive) ad A (memoria) ma raramente il contrario. Analogia: memoria immunologica T-cell.

### `DIMENSIONI/Nuova cartella/mgd_lambda_theorem.py`
Teorema lambda>0 assoluto: per ogni p in (0,1), rho in (0,1), xi >= 0 il parametro di stabilita lambda e strettamente positivo. Dimostrazione per contraddizione (se lambda=0 => |1-2p| >= 1, ma p in (0,1) => contraddizione). Risolve completamente la stabilita per tutti i parametri fisici.

### `DIMENSIONI/Nuova cartella/mgd_z2_stability.py`
Stabilita globale su Z² (reticolo 50x50): funzionale Goh-Lyapunov spaziale V = sum KL(M_x || M*). Quattro condizioni iniziali peggiori (half-half, striped, clustered, random). Verifica numerica che V(t) converge in tutti i casi.

### `DIMENSIONI/Nuova cartella/verifica_kappa0.py`
Verifica sperimentale della forma chiusa di kappa_0 (risoluzione L4). Tre esperimenti: (A) catena 1D omogenea -> kappa_0 = 1/3, (B) catena 1D con pesi geometrici -> kappa_0 = 1 - gamma_0 * DeltaM/w, (C) fit lineare per vari xi.

### `DIMENSIONI/check_tex.py`
Cerca pattern bad/good in `parte2resolutions.tex` per verificare che certe stringhe problematiche siano assenti e certe necessarie siano presenti.

### `DIMENSIONI/fix_duplicate.py`
Rimuove sezioni duplicate nel file TEX della parte 2.

### `DIMENSIONI/fix_overleaf_errors.py`
Corregge 6 errori di compilazione LaTeX in `parte2resolutions.tex`: sostituisce `\bm{1}` con `\mathbf{1}`, sistema riferimenti interni rotti, aggiunge `\IfFileExists` per robustezza su Overleaf.

### `DIMENSIONI/insert_dobrushin.py`
Inserisce la sezione Dobrushin nel file TEX principale.

### `DIMENSIONI/insert_final.py`
Inserimento finale di contenuti nel TEX (dettagli non ispezionati).

### `DIMENSIONI/insert_fw.py`
Inserisce la sezione Freidlin-Wentzell nel TEX principale.

---

## gemini-superpowers-antigravity/ — Progetto separato (agente AI)

Progetto indipendente basato su Gemini + FastAPI. Non ha dipendenze da `cortical_mgd/`.

### `e2e_demo/api/app.py`
Server FastAPI che simula un sistema source/sink: source pagina 25 item (3 pagine da 10), sink accetta upsert con rate limiting (429 ogni 5 chiamate). Progettato per testare la robustezza di un sync agent.

### `e2e_demo/sync_tool/sync.py`
Tool di sincronizzazione source→sink con retry policy esponenziale (httpx + backoff). Logga ogni operazione con uuid di sessione. Trova il repo root cercando `.agent/` nell'albero.

### `e2e_demo/tests/test_e2e.py`
Test end-to-end che avvia il server FastAPI e verifica che il sync tool riesca a sincronizzare tutti i 25 item nonostante i failure simulati.

### `.agent/skills/superpowers-workflow/scripts/`
- `record_activation.py` — registra attivazione skill nell'agente
- `spawn_subagent.py` — lancia sub-agenti
- `write_artifact.py` — scrive artefatti del workflow

---

## Componenti NON attivi / orfani

| File | Motivo |
|------|--------|
| `spike_encoder.py` | Non importato da nessun modello |
| `consolidation.py` | Solo nei test unitari |
| `task_geometry.py` | Monitoring only, non integrato |
| `llm_interface.py` | Feature ricerca, fallback sintetico |
| `attention_extractor.py` | Feature ricerca |
| `soft_trainer.py` | Feature ricerca |
| `mgd_consolidation.py` | Wrapper minimale, solo test |
| `run_tests_strict.py` | Referenzia `compute_ollivier_ricci` rimossa, rotto |
| `debug_orc.py` | Referenzia `compute_ollivier_ricci` rimossa, rotto |
| `DIMENSIONI/Nuova cartella/create_hierarchy.py` | Scaffold iniziale, eseguito una volta |
| `gemini-superpowers-antigravity/` | Progetto separato, nessuna dipendenza |

## Stato Fasi

| Fase | Modello | Stato |
|------|---------|-------|
| 1 | CorticalHierarchy | Funzionante |
| 2 | CorticalBrain, HierarchicalBrain | Funzionante |
| 3 | BioMGDBrain | Funzionante, sleep_consolidation incompleto |
| 8 | StructuralPlasticity (modelli I/J) | Funzionante |
| 9 | TemporalHierarchy (K) | Funzionante, retention@T5=1.000 |
| OpenEvolve | K ottimizzato | Completato (eta_da=0.012, tau_bcm=90.0, novelty_scale=24.0) |
| 10 | Neuromodulazione ACh/NA in BioMGDBrain | DA IMPLEMENTARE |
