"""Research primitive: normalized delta memory with an MGD material gate.

Not an implementation of the full papers, a language model, or a benchmark win.
The delta rule is established prior art; the use of material as its rate gate
is a proposed engineering adaptation that requires a controlled comparison.
"""
import numpy as np


class MGDPlasticMemory:
    def __init__(self, key_dim, value_dim, rho=.8, xi=.1,
                 eta_min=.02, eta_max=.9, error_scale=1., epsilon=1e-8):
        if not 0 < rho < 1 or not 0 <= xi <= rho:
            raise ValueError('Require 0<rho<1 and 0<=xi<=rho for material invariance.')
        if not 0 < eta_min <= eta_max <= 1:
            raise ValueError('Require 0<eta_min<=eta_max<=1 for the contraction bound.')
        if error_scale <= 0 or epsilon <= 0:
            raise ValueError('Scales must be positive.')
        self.W = np.zeros((value_dim, key_dim), dtype=float)
        self.M = 0.
        self.rho, self.xi = rho, xi
        self.eta_min, self.eta_max = eta_min, eta_max
        self.error_scale, self.epsilon = error_scale, epsilon

    def predict(self, key):
        return self.W @ np.asarray(key, dtype=float)

    def observe(self, key, observed_value):
        key = np.asarray(key, dtype=float)
        observed_value = np.asarray(observed_value, dtype=float)
        if key.shape != (self.W.shape[1],) or observed_value.shape != (self.W.shape[0],):
            raise ValueError('Key/value shape does not match memory dimensions.')
        if not np.isfinite(key).all() or not np.isfinite(observed_value).all():
            raise ValueError('Observations must be finite.')
        before = observed_value - self.predict(key)
        squared_norm = float(key @ key)
        eta = self.eta_min + (self.eta_max - self.eta_min) * (1 - self.M)
        self.W += eta * np.outer(before, key) / (self.epsilon + squared_norm)
        # This evidence gate is a design choice, not a theorem in the papers.
        chi = float(np.exp(-float(before @ before) / self.error_scale**2))
        self.M = self.rho * self.M + (1 - self.rho) * chi + self.xi * self.M * (1 - self.M)
        after = observed_value - self.predict(key)
        factor = 1 - eta * squared_norm / (self.epsilon + squared_norm)
        return {'eta': eta, 'material': self.M, 'before': before,
                'after': after, 'predicted_error_factor': factor}
