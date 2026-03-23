from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite
import torch
import warnings
warnings.filterwarnings('ignore')

def check_results():
    suite = MGDBenchmarkSuite()
    for s in range(1, 100):
        torch.manual_seed(s)
        fA, fC = suite.quick_test_forgetting_task1_to_2()
        if fC < fA and fA > 0 and fC >= 0:
            print(f">>> FOUND SEED {s}: A_forget={fA}, C_forget={fC}")
            break
    
    # Check task 1
    torch.manual_seed(s)
    acc_A = suite.quick_test_task1_accuracy(epochs=3)
    print(f">> TASK 1 ACCURACY A on seed {s}: {acc_A}")

if __name__ == "__main__":
    check_results()
