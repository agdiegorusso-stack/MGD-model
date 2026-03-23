def get_params() -> dict:
    """
    Return initial parameters of K_TemporalHierarchy.
    
    Parametri iniziali di K_TemporalHierarchy.
    OpenEvolve evolvera questi valori per massimizzare
    retention@T5. NON modificare la struttura del dict.
    """
    # Adjusted parameters to improve plasticity and dopamine response:
    # - Increased eta_da to 0.012 for more dopamine learning rate
    # - Slightly lowered tau_bcm to 90.0 for faster adaptation
    # - Increased novelty_scale to 24.0 to enhance dopamine novelty signaling
    # - Increased sleep_steps_l2 back to 50 to provide more sleep consolidation
    return {
        # BioReadout
        "eta_da": 0.012,
        "eta_dop_max": 4.0,
        "eta_oja": 0.001,
        # Dopamina
        "novelty_scale": 24.0,
        # ModularGate overlap
        "fraction": 0.1,
        "overlap_threshold": -0.5,
        # Sleep
        "sleep_steps_l1": 30,
        "sleep_steps_l2": 50,
        # TemporalHierarchy
        "n_slow": 3,
        "slow_ewc_lambda": 50.0,
        "tau_bcm": 90.0,
    }
