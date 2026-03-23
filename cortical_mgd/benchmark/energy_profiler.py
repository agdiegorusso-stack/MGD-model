# cortical_mgd/benchmark/energy_profiler.py

class EnergyProfiler:
    def __init__(self, joules_per_flop: float = 1e-10):
        self.j_per_flop = joules_per_flop

    def compute_inference_energy(self, active_spikes: int, n_weights: int) -> float:
        ops = float(active_spikes * n_weights)
        return ops * self.j_per_flop

    def compare_with_transformer(self, snn_joules: float, d_model: int = 512, n_heads: int = 8) -> dict:
        transformer_flops = 2 * (d_model**2) * n_heads
        transformer_joules = transformer_flops * self.j_per_flop
        return {"snn_joules": snn_joules,
                "transformer_joules": transformer_joules,
                "ratio": transformer_joules / (snn_joules + 1e-12)}
