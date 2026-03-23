def get_params():
    """
    Parametri iniziali per Neuromorphic Visual Cortex.
    OpenEvolve cerchera' i valori per abbattere la barriera 0.200 ACC.
    """
    return {
        "eta_v1": 0.005,
        "eta_v2": 0.002,
        "eta_v3": 0.001,
        "eta_v45": 0.005,
        "eta_dense": 0.005,
        "eta_oja": 0.005,
        "eta_da": 0.1,
        "beta": 3.0,
        "target_sum": 15.0,
        "target_sparsity": 0.05
    }
