"""
Confronto compute_D_avg:
  - svd:      torch.linalg.svd (vecchia versione)
  - eigvalsh: torch.linalg.eigvalsh (nuova versione, simmetrica PSD)

Verifica:
  1. Risultati identici (matematica equivalente)
  2. Speedup di eigvalsh vs svd

Run: python validate_local_davg.py
"""

import torch
import time

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Device: {device}\n")


def d_avg_svd(W):
    if W.shape[0] > W.shape[1]:
        gram = W.T @ W
    else:
        gram = W @ W.T
    gram = gram + torch.eye(gram.shape[0], device=W.device, dtype=W.dtype) * 1e-6
    sv = torch.linalg.svd(gram, full_matrices=False).S
    sv = sv[sv > 1e-10]
    if sv.numel() == 0:
        return torch.tensor(1.0, device=W.device)
    p = sv / sv.sum()
    return torch.exp(-(p * torch.log(p + 1e-15)).sum())


def d_avg_eig(W):
    if W.shape[0] > W.shape[1]:
        gram = W.T @ W
    else:
        gram = W @ W.T
    gram = gram + torch.eye(gram.shape[0], device=W.device, dtype=W.dtype) * 1e-6
    sv = torch.linalg.eigvalsh(gram)
    sv = sv[sv > 1e-10]
    if sv.numel() == 0:
        return torch.tensor(1.0, device=W.device)
    p = sv / sv.sum()
    return torch.exp(-(p * torch.log(p + 1e-15)).sum())


# ── 1. Correttezza ────────────────────────────────────────────────────────────
print("=" * 55)
print("TEST 1: eigvalsh == svd (stessa matematica)")
print("=" * 55)

shapes = [(784, 100), (500, 500), (1000, 200), (100, 100), (200, 50)]
print(f"{'Shape':<15} {'D_svd':>8} {'D_eig':>8} {'diff':>10}")
print("-" * 45)
ok = True
for shape in shapes:
    W = torch.randn(*shape, device=device).abs()
    vs = d_avg_svd(W).item()
    ve = d_avg_eig(W).item()
    diff = abs(vs - ve)
    ok = ok and diff < 1e-3
    print(f"{str(shape):<15} {vs:>8.4f} {ve:>8.4f} {diff:>10.2e}")

print(f"\nRisultati identici: {'SI' if ok else 'NO'}")


# ── 2. Speedup ────────────────────────────────────────────────────────────────
print("\n" + "=" * 55)
print("TEST 2: Speedup eigvalsh vs svd")
print("=" * 55)

configs = [
    ("784x100  (System H)",  (784, 100)),
    ("500x500  (System I)",  (500, 500)),
    ("1000x200 (large)",    (1000, 200)),
]

N = 300
for name, shape in configs:
    W = torch.randn(*shape, device=device).abs()

    # warm-up
    for _ in range(20):
        d_avg_svd(W); d_avg_eig(W)
    if device.type == "cuda":
        torch.cuda.synchronize()

    t0 = time.perf_counter()
    for _ in range(N):
        d_avg_svd(W)
    if device.type == "cuda":
        torch.cuda.synchronize()
    t_svd = (time.perf_counter() - t0) / N * 1000

    t0 = time.perf_counter()
    for _ in range(N):
        d_avg_eig(W)
    if device.type == "cuda":
        torch.cuda.synchronize()
    t_eig = (time.perf_counter() - t0) / N * 1000

    speedup = t_svd / (t_eig + 1e-10)
    print(f"\n  {name}")
    print(f"    svd:      {t_svd:.4f} ms")
    print(f"    eigvalsh: {t_eig:.4f} ms")
    print(f"    speedup:  {speedup:.2f}x")


# ── 3. Benchmark completo con 5 task ─────────────────────────────────────────
print("\n" + "=" * 55)
print("TEST 3: Impatto su benchmark (5 chiamate simulate)")
print("=" * 55)
W = torch.randn(784, 100, device=device).abs()

N_tasks = 5
t0 = time.perf_counter()
for _ in range(N_tasks):
    d_avg_svd(W)
if device.type == "cuda":
    torch.cuda.synchronize()
t_run_svd = (time.perf_counter() - t0) * 1000

t0 = time.perf_counter()
for _ in range(N_tasks):
    d_avg_eig(W)
if device.type == "cuda":
    torch.cuda.synchronize()
t_run_eig = (time.perf_counter() - t0) * 1000

print(f"  svd      (5 task): {t_run_svd:.2f} ms totali")
print(f"  eigvalsh (5 task): {t_run_eig:.2f} ms totali")
print(f"  risparmio: {t_run_svd - t_run_eig:.2f} ms su un run da ~18s")
