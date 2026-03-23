import sys
import os
import subprocess
from cortical_mgd.core.mgd_metrics import compute_ollivier_ricci, compute_D_avg, compute_S_RT
import torch

env = os.environ.copy()
env["PYTHONPATH"] = os.path.abspath(".")
result = subprocess.run([sys.executable, "-m", "pytest", "cortical_mgd/core/tests/test_mgd_metrics.py", "-v"], env=env, capture_output=True, text=True)
with open("test_full_log.txt", "w", encoding="utf-8") as f:
    f.write("STDOUT:\n")
    f.write(result.stdout)
    f.write("\nSTDERR:\n")
    f.write(result.stderr)

print("----- Pytest ha terminato (vedi test_full_log.txt) -----")

# Calcoli esatti
W_star = torch.zeros(6, 6)
for i in range(1, 6):
    W_star[0, i] = W_star[i, 0] = 1.0
kappa_val = compute_ollivier_ricci(W_star)
print(f"Valore ORC per Star Graph: {kappa_val}")

W_disconn = torch.eye(10)
d_disc = compute_D_avg(W_disconn)
print(f"Valore D_avg per Matrice Disconnessa: {d_disc}")

torch.manual_seed(42)
W_dense = torch.abs(torch.randn(10, 10))
W_dense = (W_dense + W_dense.T) / 2
d_dense = compute_D_avg(W_dense)
print(f"Valore D_avg per Matrice Densa Random: {d_dense}")
