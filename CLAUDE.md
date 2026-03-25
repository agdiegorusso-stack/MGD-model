# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Cortical-MGD** is a biologically-inspired Spiking Neural Network (SNN) system implementing Metric Gradient Descent (MGD) information geometry principles to enable continual learning without catastrophic forgetting. The key innovation: hyperbolic Ricci curvature and SVD effective dimensionality gate synaptic plasticity to prevent forgetting.

## Commands

**Always run Python tests in WSL** (Triton is installed in WSL, not Windows):
```bash
wsl
cd /mnt/c/Users/Miste/Downloads/ricerca

# All tests
python -m pytest cortical_mgd/ -v

# Specific module
python -m pytest cortical_mgd/core/tests/test_mgd_metrics.py -v

# Run benchmark (all 11 models A-K on 4-task sequence)
python run_benchmark.py

# Text clustering simulation
python simulate_mgd.py

# Debug MGD metrics live
python diagnose_mgd.py

# Debug memory system
python debug_memory.py

# Check for dead neurons / weight explosion
python check_spikes.py
```

**Text agent** (requires `ollama serve` running in a separate terminal):
```bash
python run_text_agent.py --model qwen2.5:14b
```

**Multimodal agent** (requires `ollama serve`, opencv, whisper, sounddevice):
```bash
python run_multimodal_agent.py
```

## Architecture

### Mathematical Core (`cortical_mgd/core/mgd_metrics.py`)
Three geometric metrics drive all plasticity decisions:
- `compute_forman_ricci(W)` → `kappa`: negative = hyperbolic/dense network (high plasticity)
- `compute_D_avg_torch(W)` → `D_avg`: effective SVD dimensionality (representational capacity)
- `compute_S_RT(gram, src, snk)` → S_RT: min-cut information entropy between areas (used for routing and area selection)

### Plasticity modulation (`cortical_mgd/plasticity/stdp_mgd.py`)
STDP learning rate is scaled by geometry: `eta = eta_base * (1 + max(0, -kappa)*0.3) * clip(D_target/D_avg, 0.1, 2.0)`. BCM rule adds metaplasticity: per-neuron sliding threshold prevents saturation.

### Neuron model (`cortical_mgd/neurons/lif_adaptive.py`)
Adaptive LIF: `v(t) = decay_m * v(t-1) + I(t)`, spikes when `v >= v_th_base + beta*a`, adaptation `a` increases after each spike. WTA (`wta_lateral.py`) enforces ~2-10% sparsity.

### Building blocks
- `CorticalColumn` (architecture/cortical_column.py): single learnable column with W, LIF, WTA, STDP, and `compute_mgd_metrics()`
- `BioReadout` (plasticity/bio_readout.py): classifier using Oja's rule + BCM + dopamine gating (no backprop)
- `MGDReplayBuffer` (continual/replay_buffer.py): stores top-K discriminative samples per task for interleaved rehearsal
- `GeometricEWC` (continual/geometric_ewc.py): EWC variant using `d(D_avg)/dW` instead of Fisher matrix

### Brain architectures (11 models A-K in benchmark)
| Model | Class | Key mechanism | Retention@T4 |
|-------|-------|---------------|-------------|
| A | `CorticalColumn` + `STDPLocal` | Baseline | ~0.55 |
| E | `CorticalBrain` | 2 areas (sparse/visual) + ModularGate + replay | 0.933 |
| G | `BioMGDBrain` | Hippocampus + 4 cortical areas + S_RT routing | varies |
| K | `TemporalHierarchy` | 3 timescales (tau=1/3/10) + BioReadout + OpenEvolve | **1.000** |

**Model K best hyperparams** (found by OpenEvolve): `eta_da=0.012, tau_bcm=90.0, novelty_scale=24.0`

### Memory & text pipeline
- `TextEncoder` (text/text_encoder.py): sentence-BERT (all-MiniLM-L6-v2) → 384-dim embeddings → SDR spike conversion
- `MemoryIndex` (memory/memory_index.py): TinyDB-backed with tri-layer retrieval (MGD cluster → cosine → tags)
- `MemoryManager` (memory/memory_manager.py): asks LLM STORE/UPDATE/IGNORE per turn; dopamine policy by content type

### LLM integration
Ollama REST (`http://localhost:11434`) is the default. All LLM calls have synthetic fallbacks. `TextLLMInterface` is in `distillation/llm_interface.py`, model default: `qwen2.5:14b`.

## Key implementation notes

- All weight tensors (`W`) are `nn.Parameter` on auto-detected `device = torch.device("cuda" if available else "cpu")`
- `CorticalColumn` keeps co-activation as a `register_buffer` (not `nn.Parameter`) for `torch.compile` stability
- `sleep_consolidation()` in `BioMGDBrain` is **incomplete** (Phase 10 not started)
- `run_tests_strict.py` and `debug_orc.py` are **broken** (reference removed `compute_ollivier_ricci`)
- `spike_encoder.py` is largely unused by active models but kept for multimodal agent
- OpenEvolve optimization lives in `openevolve_mgd/`; best K params are already integrated into `temporal_hierarchy.py`
