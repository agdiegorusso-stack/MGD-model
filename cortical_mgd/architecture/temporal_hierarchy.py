# cortical_mgd/architecture/temporal_hierarchy.py

import torch
from cortical_mgd.architecture.cortical_column import CorticalColumn
from cortical_mgd.architecture.modular_gate import ModularGate
from cortical_mgd.architecture.visual_hierarchy import VisualHierarchy
from cortical_mgd.continual.replay_buffer import MGDReplayBuffer
from cortical_mgd.plasticity.bio_readout import BioReadout
from cortical_mgd.core.mgd_metrics import compute_S_RT_torch, compute_D_avg_torch


class TemporalHierarchy:
    """
    Tre livelli temporali biologici:

    L1 - Ippocampo: alta plasticita, decadimento rapido
         tau=1 task, eta=1.0x, sparsita=2%
         Impara tutto subito, dimentica presto

    L2 - Corteccia: plasticita media
         tau=3 task, eta=0.1x, sparsita=10%
         Consolida durante il sonno da L1

    L3 - Neocorteccia profonda: plasticita minima
         tau=10 task, eta=0.001x, sparsita=5%
         Memorie permanenti, quasi immutabile
         Aggiornata solo dopo n_slow sessioni di sleep

    Il trasferimento avviene in cascata:
    L1 -> L2 durante sleep (ogni task)
    L2 -> L3 durante deep sleep (ogni n_slow task)
    """

    def __init__(self, device='cuda', n_slow=3, **_):
        self.n_slow = n_slow
        self.task_count = 0
        self.device = device

        # Gerarchia visiva V1->V2->V4->IT (Hubel & Wiesel 1962, Tanaka 1996)
        # Sostituisce il flat pixel input: 3072 -> 512 rappresentazione oggetti
        self.visual_hierarchy = VisualHierarchy()

        # L1 - Ippocampo: riceve output PrefrontalCortex (1024-dim spike)
        self.hippocampus = CorticalColumn(
            n_neurons=2000, input_dim=VisualHierarchy.VH_OUT_DIM,
            target_sparsity=0.02)
        # novelty_scale=24.0 ottimizzato da OpenEvolve
        # (default era 20.0)
        self.hip_spike_mean = 0.0

        # L2 - Corteccia (4 aree, S_RT routing)
        self.cortex_A = CorticalColumn(300, 2000, 0.1)
        self.cortex_B = CorticalColumn(300, 2000, 0.1)
        self.cortex_C = CorticalColumn(300, 2000, 0.1)
        self.cortex_D = CorticalColumn(300, 2000, 0.1)
        self.gate_A = ModularGate(300, 30)
        self.gate_B = ModularGate(300, 30)
        self.gate_C = ModularGate(300, 30)
        self.gate_D = ModularGate(300, 30)
        self.replay_A = MGDReplayBuffer(100)
        self.replay_B = MGDReplayBuffer(100)
        self.replay_C = MGDReplayBuffer(100)
        self.replay_D = MGDReplayBuffer(100)

        # L3 - Neocorteccia profonda
        # Input: output di un'area corticale alla volta (300-dim)
        self.slow_cortex = CorticalColumn(
            n_neurons=500,
            input_dim=300,
            target_sparsity=0.05)
        self.slow_ewc_lambda = 50.0
        self.slow_fisher = None
        self.slow_params_star = None

        # Readout biologico (BioReadout, zero Adam)
        self.readouts = {}  # {task_id: BioReadout}

        # Routing
        self.task_routing = {}  # {task_id: area}

    # ------------------------------------------------------------------
    # Novelty
    # ------------------------------------------------------------------

    def _to_vis(self, x):
        """Applica la gerarchia visiva V1->IT. x: (B,3,H,W) -> (B,512) spike."""
        self.visual_hierarchy.reset_state()
        return self.visual_hierarchy(x)

    def compute_novelty(self, x):
        """Novelty via varianza spike ippocampali."""
        h = self.hippocampus(self._to_vis(x))
        sv = h.var().item()
        novelty = max(0.0, sv - self.hip_spike_mean)
        self.hip_spike_mean = (0.9 * self.hip_spike_mean
                               + 0.1 * sv)
        eta = 1.0 + 4.0 * float(
            torch.sigmoid(torch.tensor(novelty * 24.0)))
        return h, novelty, eta

    # ------------------------------------------------------------------
    # Routing
    # ------------------------------------------------------------------

    def route_by_srt(self, task_id):
        """
        Routing MGD: S_RT (connettivita Fiedler) + D_avg (dimensione effettiva).

        Score = S_RT / (1 + D_avg / n_neurons)
        Alta S_RT = area ben connessa, alta capacita di apprendimento.
        Basso D_avg / n_neurons = poche dimensioni usate, piu spazio per nuovi task.
        Combinazione: preferisce aree con alta connettivita E bassa occupazione dimensionale.
        """
        best_area = 'A'
        best_score = -1.0
        for name, col in [('A', self.cortex_A),
                           ('B', self.cortex_B),
                           ('C', self.cortex_C),
                           ('D', self.cortex_D)]:
            srt = compute_S_RT_torch(col.W)
            d_avg = float(compute_D_avg_torch(col.W).item())
            # Normalizza D_avg su n_neurons: D_avg in [1, n_neurons]
            score = srt / (1.0 + d_avg / col.n_neurons)
            if score > best_score:
                best_score = score
                best_area = name

        self.task_routing[task_id] = best_area
        col = getattr(self, f'cortex_{best_area}')
        gate = getattr(self, f'gate_{best_area}')
        gate.register_task_overlapping(
            task_id, col,
            fraction=0.10,
            overlap_threshold=-0.5)
        return best_area

    # ------------------------------------------------------------------
    # Forward
    # ------------------------------------------------------------------

    def forward(self, x, task_id, cortex_bias=None):
        """
        Forward completo L1->L2->L3.
        Ritorna (h_hip, h_cortex, h_slow).
        """
        area = self.task_routing[task_id]
        col = getattr(self, f'cortex_{area}')

        x_vis = self._to_vis(x)
        h_hip = self.hippocampus(x_vis)
        h_cortex = col(h_hip.detach(), bias=cortex_bias)
        h_slow = self.slow_cortex(h_cortex.detach())
        return h_hip, h_cortex, h_slow

    # ------------------------------------------------------------------
    # Sleep L1 -> L2 (ogni task)
    # ------------------------------------------------------------------

    def sleep_l1_to_l2(self, task_id, device, n_steps=30):
        """
        Consolidazione L1->L2: replay ogni task.
        eta ridotta, ippocampo frozen.
        """
        area = self.task_routing[task_id]
        col = getattr(self, f'cortex_{area}')
        gate = getattr(self, f'gate_{area}')
        replay = getattr(self, f'replay_{area}')

        kappa, d_avg = col.compute_mgd_metrics()
        sleep_eta = 0.1 / (1.0 + abs(kappa))

        for _ in range(n_steps):
            for _, (X_r, y_r) in replay.sample_replay(5):
                for i in range(len(X_r)):
                    x_r = X_r[i].unsqueeze(0).to(device)
                    x_vis = self._to_vis(x_r)
                    self.hippocampus.lif.reset_state()
                    col.lif.reset_state()
                    sum_h = torch.zeros(
                        1, col.n_neurons, device=device)
                    for _ in range(3):
                        h_hip = self.hippocampus(x_vis)
                        h1 = col(h_hip.detach())
                        sum_h += h1
                    ro = self.readouts.get(task_id)
                    if ro is not None:
                        ro.online_step(
                            sum_h,
                            int(y_r[i].item() % 10),
                            da_signal=0.5)
                    dW = col.stdp.compute_weight_update(
                        kappa, d_avg, 2.0, W=col.W.data)
                    mask = gate.get_plastic_mask(task_id)
                    dW = dW * mask.unsqueeze(0).to(device)
                    with torch.no_grad():
                        col.W.add_(dW * sleep_eta)
                        col.W.data.clamp_(0.0, 5.0)

    # ------------------------------------------------------------------
    # Sleep L2 -> L3 (ogni n_slow task)
    # ------------------------------------------------------------------

    def sleep_l2_to_l3(self, device, n_steps=50):
        """
        Deep sleep L2->L3: ogni n_slow task.
        Aggiorna slow_cortex con EWC fortissimo.
        Cristallizza le memorie a lungo termine.

        Nota: i replay buffer contengono input raw (784-dim).
        Il preprocessing via ippocampo viene applicato prima
        di passare alla colonna corticale (input_dim=2000).
        """
        if self.slow_params_star is None:
            self.slow_params_star = \
                self.slow_cortex.W.data.clone()

        kappa, d_avg = \
            self.slow_cortex.compute_mgd_metrics()
        deep_eta = 0.001

        for area in ['A', 'B', 'C', 'D']:
            col = getattr(self, f'cortex_{area}')
            replay = getattr(self, f'replay_{area}')

            for _ in range(n_steps // 4):
                for _, (X_r, _) in replay.sample_replay(3):
                    for i in range(len(X_r)):
                        x_r = X_r[i].unsqueeze(0).to(device)
                        x_vis = self._to_vis(x_r)
                        self.hippocampus.lif.reset_state()
                        col.lif.reset_state()
                        self.slow_cortex.lif.reset_state()
                        sum_slow = torch.zeros(
                            1, self.slow_cortex.n_neurons,
                            device=device)
                        for _ in range(3):
                            h_hip = self.hippocampus(x_vis)
                            h_c = col(h_hip.detach())
                            h_s = self.slow_cortex(
                                h_c.detach())
                            sum_slow += h_s

                        dW = self.slow_cortex.stdp\
                            .compute_weight_update(
                                kappa, d_avg, 2.0,
                                W=self.slow_cortex.W.data)

                        if self.slow_params_star is not None:
                            ewc_grad = self.slow_ewc_lambda * (
                                self.slow_cortex.W
                                - self.slow_params_star)
                            dW -= ewc_grad

                        with torch.no_grad():
                            self.slow_cortex.W.add_(
                                dW * deep_eta)
                            self.slow_cortex.W.data\
                                .clamp_(0.0, 5.0)

        self.slow_params_star = \
            self.slow_cortex.W.data.clone()
        print('[DeepSleep] L2->L3 consolidato')

    # ------------------------------------------------------------------
    # Registrazione task
    # ------------------------------------------------------------------

    def register_task(self, task_id, X_sample, n_classes: int = 5):
        """Registra nuovo task: novelty + routing."""
        x = X_sample[0].unsqueeze(0).to(self.device)
        self.hippocampus.lif.reset_state()
        _, novelty, eta = self.compute_novelty(x)
        area = self.route_by_srt(task_id)

        col = getattr(self, f'cortex_{area}')
        self.readouts[task_id] = BioReadout(
            col.n_neurons, n_classes,
            eta_oja=0.005,
            eta_da=0.1,        # Boosted for rapid 5-epoch tests
            tau_bcm=90.0
        ).to(self.device)

        print(f'[TH] Task{task_id+1}: area={area}, '
              f'novelty={novelty:.4f}, eta={eta:.2f}')
        self.task_count += 1
        return area, novelty, eta

    # ------------------------------------------------------------------
    # Consolidazione post-task
    # ------------------------------------------------------------------

    def consolidate(self, task_id, device):
        """
        Post-task: L1->L2 sempre.
        L2->L3 ogni n_slow task.
        Structural plasticity: pruning + sinaptogenesi su hippocampus e area attiva.
        """
        self.sleep_l1_to_l2(task_id, device)

        # Pruning sinaptico post-sleep (Holtmaat & Svoboda 2009):
        # rende W sparsa -> kappa_F inizia a variare da -1.98
        # libera neuroni deboli per i task futuri
        area = self.task_routing[task_id]
        col = getattr(self, f'cortex_{area}')
        gate = getattr(self, f'gate_{area}')
        col.prune_and_grow(task_id, gate.allocation_time)
        self.hippocampus.prune_and_grow(task_id, {})

        if self.task_count % self.n_slow == 0:
            print(f'[DeepSleep] Task{task_id+1}: '
                  f'attivazione L2->L3')
            self.sleep_l2_to_l3(device)

    # ------------------------------------------------------------------
    # Device placement
    # ------------------------------------------------------------------

    def to(self, device):
        self.device = device
        self.visual_hierarchy.to(device)
        self.hippocampus.to(device)
        for area in ['A', 'B', 'C', 'D']:
            getattr(self, f'cortex_{area}').to(device)
        self.slow_cortex.to(device)
        for ro in self.readouts.values():
            ro.to(device)
        if self.slow_params_star is not None:
            self.slow_params_star = \
                self.slow_params_star.to(device)
        return self
