import torch
from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite

if __name__ == "__main__":
    suite = MGDBenchmarkSuite()
    l, r, a = suite.quick_test_forgetting_D()
    print("="*40)
    print(f"FINAL LOWVAR: {l:.4f}")
    print(f"FINAL RAND: {r:.4f}")
    print(f"FINAL ABASE: {a:.4f}")
    print("="*40)
