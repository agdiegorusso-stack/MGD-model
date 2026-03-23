from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite

if __name__ == "__main__":
    # Inizializza l'orchestrazione sulle dimensioni raw massime compatibili con MNIST = 784
    suite = MGDBenchmarkSuite(n_neurons=50, input_dim=784)
    print("Launching full Benchmark Sequence on XOR -> BANDED -> MNIST (0-4) -> MNIST (5-9)...")
    df = suite.run_task_sequence()
    
    print("\n================ MGD CORTICAL BENCHMARK RESULTS ================")
    print(df.to_string())
    with open("benchmark_table.txt", "w") as f:
        f.write(df.to_string())
    print("================================================================")
    
    suite.plot_metrics("benchmark_results.png")
    print("Metrics plotted and saved to 'benchmark_results.png'.")
