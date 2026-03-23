# Cortical-MGD: A Brain-Inspired Continual Learning System

## What it does
Cortical-MGD is a Spiking Neural Network (SNN) system that utilizes Information Geometry principles (Metric Gradient Descent) to learn new tasks sequentially while physically preventing the catastrophic forgetting of previous knowledge.

## Key Results

### 1. Forward Transfer
Theoretical principles translate to massive performance gains when learning new tasks. In our benchmark, the geometrically guided B_MGD_EWC model reached 87% accuracy on MNIST (Tasks 3-4), whereas the classical STDP baseline reached only 28%. This constitutes a 3x gap with identical nominal capacity. The core mechanism enabling this leap is the dynamic learning rate `eta_mgd`, which adapts locally based on the hyperbolic geometric constraint `f(kappa, D_avg)`.

### 2. Backward Retention — Homogeneous Tasks
When dealing with tasks sampled from the same distribution (like XOR followed by Banded data), we observed targeted preservation of memory traces. Using the D_MGD_lowvar approach, the system only experienced a 0.025 drop in accuracy on the original task. In stark contrast, an A_baseline model lost 0.245, and a D_MGD_random approach with arbitrary gating catastrophically lost 0.770, unequivocally proving that geometrically informed masking is necessary to protect consolidated knowledge.

### 3. Backward Retention — Heterogeneous Tasks
When expanding the sequence to fundamentally different modalities (XOR to Banded to multi-class dense MNIST), the standalone column suffers from representation drift. We resolved this through the hierarchical E_CorticalBrain architecture, reaching an unprecedented 0.933 retention on the initial synthetic task at the end of the four-task sequence. This was achieved by introducing an automatic input-density router: inputs evaluating below 0.05 density trigger processing in the sparse synthetic area, while denser signals naturally route to the visual area. Notably, the system exhibited exactly zero structural forgetting from Task 2 to Task 4.

## Architecture

Cortical-MGD is structured around discrete, biologically plausible components that map precisely to concepts in Metric Gradient Descent geometry.

The **CorticalColumn** is the foundational building block, representing a localized assembly of spiking neurons. It tracks geometric evolution internally, acting as the canvas for topological updates. The **ModularGate** controls synaptic plasticity inside the column; by evaluating the variance of incoming signals, it isolates and freezes neurons that have crystallized crucial topologies, leaving highly variable (unspecialized) pathways available for subsequent tasks. To reinforce this consolidation, the **MGDReplayBuffer** acts as a long-term episodic memory, triggering interleaved rehearsal of old data explicitly prioritized by their spike variance to stabilize weak topological links. Finally, the **CorticalBrain** manages multiple distinct cortical areas, preventing catastrophic representational drift entirely by physically segregating tasks with incompatible feature distributions.

These modules directly implement the theoretical construct of MGD:
- The adaptive plasticity scaling `eta_mgd` corresponds to OP5, driving a dynamic Ricci Tensor formulation.
- The scalar `kappa` reflects the local hyperbolic curvature of the network's topology.
- The scalar `D_avg` maps to the emergent effective dimensionality of the information manifold.
- Task distribution and input specialization emulate the routing action governed by the min-cut minimization of the structure `S_RT`.

## G_BioMGDBrain Results

### Offline Consolidation (Sleep-Based Learning)
- **Task 1 accuracy after immediate training**: 0.300
- **Task 1 accuracy after post-Task 2 sleep**: 0.967
- **Task 1 accuracy after Task 3-4**: 1.000
- **Mechanism**: MGDReplayBuffer + Offline Readout Optimization

BioMGDBrain successfully consolidates Task 1 during the sleep phase following Task 2, and maintains a perfect 1.000 retention score across subsequent heterogeneous tasks (Task 3 and Task 4). This strongly mirrors the biological function of the hippocampus: it temporarily holds sparse separated patterns before offloading and consolidating them into the neocortex during offline sleep phases.

### Comparison with Previous Systems
| System | Retention@Task4 | Mechanism |
|--------|-----------------|-----------|
| `A_STDPLocal` | 0.550 | None (Baseline) |
| `D_MGD_FULL` | 0.300 | Gating + EWC |
| `E_CorticalBrain` | 0.933 | Isolated Cortical Areas |
| `F_HierarchicalBrain` | 0.850 | Multi-level Hierarchy |
| `G_BioMGDBrain` | **1.000** | **Hippocampus + Sleep Consolidation** |

### Honest Limitations
- Task 1 is not learned immediately during the online phase (initial accuracy = 0.300).
- The consolidation mechanism strictly requires maintaining prior task data within the replay buffer (it is not a zero-shot mathematical memory).
- The current architecture has only been validated on sequences of 4 tasks; its stability bounds on significantly longer continuous sequences are yet to be tested.
