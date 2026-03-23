# cortical_mgd/continual/task_geometry.py

import torch

class TaskGeometry:
    """Tracks geometric shifts across sequential learning tasks to anticipate catastrophic forgetting."""
    def __init__(self):
        self.history = []
        
    def compute_task_shift(self, D_avg_old: float, D_avg_new: float, kappa_old: float, kappa_new: float) -> float:
        """Quantifies the topological disruption between boundary tasks."""
        shift = abs(D_avg_new - D_avg_old) + abs(kappa_new - kappa_old)
        self.history.append(shift)
        return float(shift)
