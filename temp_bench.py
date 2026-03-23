# temp_bench.py
import time
from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite

suite1 = MGDBenchmarkSuite(n_neurons=100)
suite1.only_models = ["B_MGD_EWC"]
t0 = time.time()
df1 = suite1.run_task_sequence(skip_hierarchical=True)
t1 = time.time()
b_time = t1 - t0

suite2 = MGDBenchmarkSuite(n_neurons=100)
suite2.only_models = ["H_LocalMGD"]
t0 = time.time()
df2 = suite2.run_task_sequence(skip_hierarchical=True)
t1 = time.time()
h_time = t1 - t0

h_row = df2[(df2.Model=='H_LocalMGD') & (df2.Task==4)]
h_acc = float(h_row['Accuracy_Task1'].values[0]) if not h_row.empty else 0.0

print(f"TotalSeconds prima (B_MGD_EWC con SVD): {b_time:.2f}")
print(f"TotalSeconds dopo (H_LocalMGD senza SVD): {h_time:.2f}")
print(f"retention@T4 di H_LocalMGD: {h_acc:.3f}")
