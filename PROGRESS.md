# MGD Brain — Stato del Progetto

> Obiettivo: avvicinarsi alle performance del cervello umano su Split CIFAR-100
> Baseline transformer: **DualPrompt ACC = 0.862**
> Nostro attuale:       **ACC ~ 0.21-0.23** (test piccolo, 5 task)

---

# RISULTATI NEL TEMPO

```
Config                          K_ACC   L_ACC   M_ACC   BWT     Note
─────────────────────────────────────────────────────────────────────
Base (no pretrain)              0.226   0.204   0.212   ~-0.03  baseline
+ Pretrain fix (Poisson enc.)   0.224   0.218   0.218   ~-0.02  spike_rate: 0.009 → 0.02
+ Omeostatica (L1 norm)         0.229   0.214   0.212   varies  +11% K
+ Plasticita' strutturale       0.210   0.234   0.178    0.000  BWT=0 per tutti!
+ BCM in STDP                   0.208   0.212   0.206    0.000  pesi piu' uniformi
+ DA per-batch (Schultz)        ~       ~       ~        ~      non misurato (job scaduto)
+ Gerarchia visiva V1->IT       ?       ?       ?        ?      APPENA IMPLEMENTATO
─────────────────────────────────────────────────────────────────────
DualPrompt (ViT-B/16)           0.862                   -0.005  reference
L2P (ViT-B/16)                  0.836                   -0.012  reference
EWC (ResNet)                    0.476                   -0.142  reference
```

**Nota**: test piccolo (5 task, 50 campioni/classe) — i numeri hanno alta varianza.
Per risultati stabili servono 20 task, 500 campioni/classe.

---

# COS'E' IMPLEMENTATO

## Neuroni

```
LIF Adattativi       neurons/lif_adaptive.py
  Leaky Integrate-and-Fire con soglia adattiva.
  Fonte: Gerstner 2002
  Formula: v(t) = v(t-1)*decay + I(t)
           spike = (v >= v_th_base + beta*a)
           v_th cresce ogni volta che il neurone spara (fa "stancare" il neurone)

WTA Laterale         neurons/wta_lateral.py
  Solo i top-k neuroni per potenziale sopravvivono.
  Fonte: Maass 2000
  Sparsita': 2% ippocampo, 5-10% corteccia

Codifica Poisson     neurons/spike_encoder.py + run_benchmark_cifar100.py
  Pixel in [0,1] -> spike binari: spike = (random < pixel_value)
  Usato nel pretrain: 5 timestep per immagine
  Fonte: Mainen & Sejnowski 1995
```

## Plasticita'

```
STDP classica        plasticity/stdp_mgd.py
  Bi & Poo 1998: neuroni che sparano insieme si connettono.
  Pre PRIMA di post -> LTP (rinforzo): dW += A+ * trace_pre.T @ post_spikes
  Post PRIMA di pre -> LTD (depressione): dW -= A- * pre_spikes.T @ trace_post

BCM rule  [AGGIUNTO]  plasticity/stdp_mgd.py
  Bienenstock-Cooper-Munro 1982: soglia adattiva per ogni neurone.
  theta_j cresce se il neurone spara troppo -> piu' LTD (si "annoia")
  theta_j scende se il neurone spara poco -> piu' LTP (si "sveglia")
  Formula: theta += (post^2 - theta) / tau_bcm
           dW_bcm = trace_pre.T @ (post * (post - theta))
  Effetto: previene saturazione W senza hard clamp

Plasticita' omeostatica  [COLLEGATA]  plasticity/homeostasis.py
  Turrigiano & Nelson 2004: ogni neurone bilancia i propri pesi totali.
  Formula: W_col *= target_sum / sum(W_col)    [target=15.0]
  Effetto: abilita competizione tra sinapsi -> specializzazione

Plasticita' strutturale  [COLLEGATA]  plasticity/structural_plasticity.py
  Holtmaat & Svoboda 2009: pruning + sinaptogenesi.
  Pruning: W[i,j] = 0 se sinapsi e' debole + non specializzata + inattiva da 3 task
  Sinaptogenesi: riattiva connessioni dormienti con alta co-attivazione
  Effetto: rende W sparsa nel tempo -> kappa_F inizia a variare da -1.98

BioReadout + Oja     plasticity/bio_readout.py
  Strato di classificazione biologico. Zero Adam.
  Regola Oja: aggiornamento pesi che convergono ai componenti principali
  BCM sul readout: theta per classe, non per sinapsi
  Fonte: Oja 1982 + BCM 1982
```

## Gerarchia Visiva

```
V1->V2->V4->IT      architecture/visual_hierarchy.py   [AGGIUNTO]
  V1 (Hubel & Wiesel 1962): Conv2d(3,32,3x3) -> LIF -> WTA 10%
     Estrae orientazioni locali (filtri Gabor-like)
     Receptive field: 3x3 pixel, output: 32x32x32 spike

  V2 (DeYoe & Van Essen 1988): Conv2d(32,64,3x3,s=2) -> LIF -> WTA 10%
     Forme semplici, stride 2 -> downsampling: 16x16x64 spike

  V4 (Desimone & Schein 1987): Conv2d(64,128,3x3,s=2) -> LIF -> WTA 10%
     Forme complesse e colore: 8x8x128 spike

  IT (Tanaka 1996): GlobalAvgPool -> Linear(128,512) -> LIF -> WTA 5%
     Invarianza di posizione via pooling globale
     Output: 512 spike -> input ippocampo (prima erano 3072 pixel grezzi)

  STDP Hebbiana locale: dW = spikes_post * unfold(x_pre)
    Applicata a ogni livello durante il pretrain
    Sviluppa filtri simili a quelli trovati in V1 biologico
```

## Architettura Continual Learning

```
Gerarchia Temporale L1/L2/L3    architecture/temporal_hierarchy.py
  Ispirata a: McClelland et al. 1995 (complementary learning systems)

  L1 - IPPOCAMPO (2000 neuroni, sparsita' 2%)
       Alta plasticita', impara subito, dimentica presto
       Pretrain non supervisionato su 50k immagini (Olshausen & Field 1996)

  L2 - CORTECCIA (4 aree A/B/C/D, 300 neuroni ciascuna, sparsita' 10%)
       Plasticita' media. Consolidata da L1 durante il sonno ogni task.

  L3 - NEOCORTECCIA PROFONDA (500 neuroni, sparsita' 5%)
       Quasi immutabile. Aggiornata ogni 3 task con deep sleep + EWC.

Sleep L1->L2         architecture/temporal_hierarchy.py
  Replay del task appena visto con eta ridotta. Stickgold 2005.

Deep Sleep L2->L3    architecture/temporal_hierarchy.py
  Replay di tutti i task ogni n_slow task. EWC geometrico.

ModularGate          architecture/modular_gate.py
  Assegna neuroni specifici a ogni task (overlap 10%).
  Frankland & Bontempi 2005: memoria episodica -> neocortice.

Replay Buffer        continual/replay_buffer.py
  Salva top-50 esempi piu' informativi per task (alta varianza spike).

Pretrain STDP        run_benchmark_cifar100.py
  5 epoche su 50k immagini CIFAR-100 con STDP+WTA+BCM+omeostatica.
  Obiettivo: sviluppare filtri Gabor come V1 (Olshausen & Field 1996)
```

## Metriche MGD (Multi-way Geometric Dynamics)

```
kappa_F (Forman-Ricci)    core/mgd_metrics.py
  Misura la curvatura del grafo neurale.
  Formula: kF(u,v) = [4*w(u,v) - deg(u) - deg(v)] / mean_deg
  kF << 0: struttura iperbolica, alta capacita' di memorizzazione
  kF ~ 0: struttura piatta, neuroni generalisti
  PROBLEMA ATTUALE: kF = -1.9800 costante perche' W e' ancora densa.
  Servono piu' epoche di pretrain per rendere W sparsa.

D_avg (Dimensione Effettiva)    core/mgd_metrics.py
  Misura quante dimensioni utili usa la rete.
  Formula: D_avg = exp(-sum(p*log(p))) sui valori singolari di W
  Alta D_avg = rappresentazioni ricche, bassa = collasso

S_RT (Ryu-Takayanagi proxy)    core/mgd_metrics.py
  Misura la connettivita' algebrica (valore di Fiedler del Laplaciano).
  Usato per routing: task va all'area con S_RT piu' alta (piu' libera).

STDP modulato MGD    plasticity/stdp_mgd.py
  eta_mgd = eta_base * (1 + max(0,-kF)*0.3) * clip(D_target/D_avg, 0.1, 2.0)
  Curvatura negativa -> eta piu' alta -> apprende piu' velocemente
  Bassa D_avg -> eta piu' alta -> espande rappresentazioni

kF locale (per sinapsi)    plasticity/structural_plasticity.py
  kF_ij = (4*w_ij - deg_i - deg_j) / d_bar   [O(n), non O(n^3)]
  Usato per identificare sinapsi non specializzate da potare
```

## Neuromodulazione

```
Dopamina DA  [AGGIUNTA]    run_benchmark_cifar100.py
  Schultz et al. 1997: VTA spara su sorpresa -> LTP piu' forte.
  delta_DA = var(h_cortex) - ema_var   (sorpresa = varianza inattesa)
  eta_batch = eta * sigmoid(delta_DA * 20)
  Effetto: input inattesi -> apprendimento piu' veloce quel batch
```

---

# COSA MANCA (PER PRIORITA')

## Priorita' ALTA — impatto diretto sull'ACC

```
1. GERARCHIA VISIVA V1->V2->V4->IT                    [IMPLEMENTATO]
   ─────────────────────────────────────────────────────────────────
   File: cortical_mgd/architecture/visual_hierarchy.py

   V1: Conv2d(3,32, k=3, s=1) -> LIF -> WTA 10%  (32x32x32 spike)
   V2: Conv2d(32,64, k=3, s=2) -> LIF -> WTA 10% (16x16x64 spike)
   V4: Conv2d(64,128, k=3, s=2) -> LIF -> WTA 10% (8x8x128 spike)
   IT: GlobalAvgPool -> Linear(128,512) -> LIF -> WTA 5% (512 spike)

   Connesso a: TemporalHierarchy._to_vis(x) prima di ogni hippocampus(x)
   L'ippocampo ora riceve 512 spike IT invece di 3072 pixel
   STDP Hebbiana locale per ogni livello nel pretrain
   Risultato atteso: +0.30 ACC (da testare)


2. RECEPTIVE FIELD LOCALI                             [RISOLTO CON VH]
   ─────────────────────────────────────────────────────────────────
   Risolto implicitamente dalla gerarchia visiva: i Conv2d hanno
   kernel locale 3x3, ogni neurone VH vede solo un piccolo patch.
   Non serve mask esplicita su CorticalColumn.
```

## Priorita' MEDIA

```
3. kF LOCALE COME MODULAZIONE STDP                    stima +0.05 ACC
   ─────────────────────────────────────────────────────────────────
   Gia' calcolato in structural_plasticity.py per il pruning.
   Manca: usarlo per modulare dW per ogni sinapsi individualmente.
   Formula: dW_ij *= (1 + max(0, -kF_ij) * 0.3)
   File: stdp_mgd.py -> ricevere kF_local come argomento


4. ACETILCOLINA (ACh)                                 stima +0.03 ACC
   ─────────────────────────────────────────────────────────────────
   Nucleus basalis -> cortex: apre finestra di plasticita' su novelty.
   Formula: eta(t) *= f([ACh](t))   dove [ACh] alto = novelty alta
   File: modular_gate.py


5. NORADRENALINA (NA)                                 stima +0.03 ACC
   ─────────────────────────────────────────────────────────────────
   Locus coeruleus: abbassa soglia LTP durante arousal/stress.
   Formula: theta_LTP(t) = theta_base * exp(-[NA]/K_NA)
   File: lif_adaptive.py


6. COMPARTIMENTI DENDRITICI                           stima +0.05 ACC
   ─────────────────────────────────────────────────────────────────
   Larkum et al. 1999: ogni neurone ha compartimenti indipendenti.
   Formula: h_j = sum_d(sigma(w_d * x_d))   sigma per compartimento
   File: lif_adaptive.py -> aggiungere compartimenti apicale/basale
```

## Priorita' BASSA

```
7. GANGLI DELLA BASE (Reinforcement Learning)
   delta-rule: dW = alpha * delta * e
   dove delta = reward - V_hat (prediction error), e = eligibility trace

8. BURST CODING
   n_spikes in {1,2,3+}: burst = alta salienza, singolo spike = routine
   dW proporzionale al numero di spike nel burst

9. LATENCY CODING (time-to-first-spike)
   t_spike = tau * log(I / (I - theta))
   Il tempo di risposta codifica l'intensita' -> -90% spike necessari

10. RICCI FLOW CONTINUO SUL GRAFO NEURALE
    g_ij(t+1) = g_ij(t) - 2*Ric_ij*dt   (Hamilton 1982 discreto)
    Il manifold si "appiattisce" durante l'apprendimento

11. 6 STRATI CORTICALI (Layer 2/3/4/5/6)
    Connettivita' a blocchi: input thalamico su Layer 4,
    output motorio da Layer 5, associazione in Layer 2/3
```

---

# ARCHITETTURA CORRENTE

```
INPUT: immagine CIFAR-100 (32x32x3) normalizzata in [0,1]
   |
   v
┌─────────────────────────────────────────────────────┐
│  GERARCHIA VISIVA  visual_hierarchy.py               │
│  V1: Conv(3->32,  k=3, s=1) LIF WTA10% -> 32x32x32 │
│  V2: Conv(32->64, k=3, s=2) LIF WTA10% -> 16x16x64 │
│  V4: Conv(64->128,k=3, s=2) LIF WTA10% ->  8x8x128 │
│  IT: Pool -> Linear(128->512) LIF WTA5% -> 512 spike│
└─────────────────────────────────────────────────────┘
   |
   | STDP Hebbiana locale a ogni livello (pretrain)
   v
┌─────────────────────────────────────────────────────┐
│  IPPOCAMPO L1  (2000 neuroni, sparsita' 2%)         │
│  CorticalColumn(2000, 512)   <- era 3072            │
│  + STDP + BCM + Omeostatica + Plasticita' strutturale │
│  + Pretrain 5 epoche su 50k immagini                 │
└─────────────────────────────────────────────────────┘
   |
   | routing S_RT -> area piu' libera
   v
┌─────────────────────────────────────────────────────┐
│  CORTECCIA L2  (4 aree A/B/C/D, 300 neuroni ciascuna) │
│  CorticalColumn(300, 2000, sparsita' 10%)            │
│  + ModularGate (overlap 10%)                         │
│  + Sleep L1->L2 ogni task                            │
│  + Pruning post-sleep                                │
└─────────────────────────────────────────────────────┘
   |
   v
┌─────────────────────────────────────────────────────┐
│  NEOCORTECCIA L3  (500 neuroni, sparsita' 5%)       │
│  CorticalColumn(500, 300)                            │
│  + EWC geometrico + Deep Sleep ogni 3 task           │
└─────────────────────────────────────────────────────┘
   |
   v
┌─────────────────────────────────────────────────────┐
│  READOUT  (per task, 5 classi)                       │
│  BioReadout: Oja + BCM, zero Adam                    │
└─────────────────────────────────────────────────────┘
   |
   v
OUTPUT: classe predetta (1 di 5 per task corrente)
```

---

# NOTE TECNICHE

```
Hardware: RTX 2060 (Turing, 6GB) + i9
torch.compile: mode='default' (non 'reduce-overhead' -> CUDAGraph incompatibile con STDP)
AMP FP16: torch.autocast(device_type='cuda', dtype=torch.float16)
Co-attivazione: register_buffer GPU-only (nessun round-trip CPU nel forward hot-path)
num_workers: 0 su Windows, 8 su Linux/WSL
```
