import 'dart:math';

class MgdParameters09 {
  final double alpha;
  final double beta;
  final double epsilon;
  final double c0;
  final double rho;
  final double xi;
  final double lambda;
  final double eta;
  final double nu;
  final double etaPlus;
  final double punishment;

  const MgdParameters09({
    this.alpha = 0.86,
    this.beta = 0.14,
    this.epsilon = 1.0,
    this.c0 = 0.05,
    this.rho = 0.92,
    this.xi = 0.06,
    this.lambda = 0.055,
    this.eta = 0.035,
    this.nu = 0.0045,
    this.etaPlus = 0.018,
    this.punishment = 0.065,
  });
}

class MgdStep09 {
  final double weight;
  final double memory;
  final double material;
  final double coherenceAverage;
  final double equilibriumMaterial;
  final double informationalFlux;
  final bool active;

  const MgdStep09({
    required this.weight,
    required this.memory,
    required this.material,
    required this.coherenceAverage,
    required this.equilibriumMaterial,
    required this.informationalFlux,
    required this.active,
  });
}

class MgdMath09 {
  static const MgdParameters09 defaults = MgdParameters09();

  static double equilibriumMaterial(
    double chiAverage, {
    MgdParameters09 p = defaults,
  }) {
    final chi = chiAverage.clamp(0.0, 1.0).toDouble();
    final a = p.xi;
    // Fixed point of M' = rho*M + (1-rho)*chi + xi*M*(1-M).
    // This is the equilibrium under constant mean forcing, not E[M] of
    // the nonlinear stochastic recursion.
    final b = (1.0 - p.rho) - p.xi;
    final c = (1.0 - p.rho) * chi;
    if (a <= 1e-12) return chi;
    final root = sqrt(b * b + 4.0 * a * c);
    final equilibrium =
        b >= 0 ? (c == 0 ? 0.0 : 2.0 * c / (b + root)) : (root - b) / (2.0 * a);
    return equilibrium.clamp(0.0, 1.0).toDouble();
  }

  static MgdStep09 evolve({
    required double weight,
    required double memory,
    required double material,
    required double coherenceAverage,
    double activation = 0.0,
    double reward = 0.0,
    int iterations = 1,
    MgdParameters09 p = defaults,
  }) {
    var w = weight.clamp(p.c0, 3.6).toDouble();
    var m = memory.clamp(0.0, 1.5).toDouble();
    var M = material.clamp(0.0, 1.0).toDouble();
    var chiAvg = coherenceAverage.clamp(0.0, 1.0).toDouble();
    var flux = 0.0;
    final n = max(1, min(iterations, 32));

    for (var i = 0; i < n; i++) {
      final a = activation.clamp(0.0, 1.0).toDouble();
      final positive = max(0.0, reward).clamp(0.0, 1.0).toDouble();
      final negative = max(0.0, -reward).clamp(0.0, 1.0).toDouble();

      // MGD 0.2.4 memory recursion: m(t+1) = alpha*m(t) + beta*a(t).
      // A correction is not a fresh positive exposure.
      final nextMemory = p.alpha * m + p.beta * a * (negative > 0 ? 0 : 1);

      // Generalised graph-coherence trigger: an admitted edge contributes to
      // local coherence when it is geometrically active (w <= epsilon).
      final chi = w <= p.epsilon ? 1.0 : 0.0;
      final nextChiAvg = 0.97 * chiAvg + 0.03 * chi;

      // MGD 0.5 logistic material recursion.
      final nextMaterial =
          (p.rho * M + (1.0 - p.rho) * chi - p.xi * M * (M - 1.0))
              .clamp(0.0, 1.0)
              .toDouble();

      final mStar = equilibriumMaterial(nextChiAvg, p: p);

      // MGD 0.5 full-weight drift, adapted from directional lattice arcs to
      // an arbitrary learned relation edge. Reward modulates forcing strength;
      // Explicit negative feedback takes precedence over familiarity. Otherwise
      // saturated memory could cancel punishment and keep an incorrect edge at
      // the floor. This changes geometry, never factual evidence or provenance.
      final effectiveActivation = a * (0.65 + 0.35 * positive);
      final deltaW = negative > 0
          ? p.nu + p.punishment * negative
          : p.nu -
              p.lambda * effectiveActivation -
              p.eta * nextMemory +
              p.etaPlus * (nextMaterial - mStar);

      final nextWeight = max(p.c0, w + deltaW).clamp(p.c0, 3.6).toDouble();
      flux += (nextMaterial - M).abs();

      w = nextWeight;
      m = nextMemory.clamp(0.0, 1.5).toDouble();
      M = nextMaterial;
      chiAvg = nextChiAvg;
    }

    return MgdStep09(
      weight: w,
      memory: m,
      material: M,
      coherenceAverage: chiAvg,
      equilibriumMaterial: equilibriumMaterial(chiAvg, p: p),
      informationalFlux: flux,
      active: w <= p.epsilon,
    );
  }

}
