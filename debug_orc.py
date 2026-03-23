import sys
import os
import torch
import subprocess

env = os.environ.copy()
env["PYTHONPATH"] = os.path.abspath(".")

from cortical_mgd.core.mgd_metrics import compute_ollivier_ricci

print("\n--- DEBUG OLLIVIER RICCI STAR GRAPH ---")
W = torch.zeros(6, 6)
for i in range(1, 6):
    W[0, i] = W[i, 0] = 1.0

kappa = compute_ollivier_ricci(W)
print(f"FINAL KAPPA = {kappa}")
print("---------------------------------------\n")

print("--- RUNNING PYTEST ---")
result = subprocess.run([sys.executable, "-m", "pytest", "cortical_mgd/core/tests/test_mgd_metrics.py", "-v"], env=env, capture_output=True, text=True)
print(result.stdout)
print(result.stderr)
