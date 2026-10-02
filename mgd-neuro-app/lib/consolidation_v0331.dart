import 'dart:math';

/// An explicitly versioned persistence rule, not an estimator of factual truth.
/// With no revocation, c<=epsilon and M>=nu/theta form an invariant basin.
/// The extra pressure/reward terms of the legacy engine are NOT part of it.
class ConsolidationParameters331 {
  final double c0, epsilon, rho, nu, lambda, theta;
  const ConsolidationParameters331({
    this.c0 = .05,
    this.epsilon = 1,
    this.rho = .92,
    this.nu = .0045,
    this.lambda = .055,
    this.theta = .009,
  });

  void validate() {
    if (![c0, epsilon, rho, nu, lambda, theta].every((x) => x.isFinite) ||
        c0 <= 0 ||
        epsilon < c0 ||
        rho < 0 ||
        rho >= 1 ||
        nu <= 0 ||
        lambda <= nu ||
        theta <= nu) {
      throw ArgumentError('Invalid parameters for incremental-linear-0331');
    }
  }

  double get threshold => nu / theta;
}

class ConsolidationStep331 {
  final double cost, material;
  final bool inBasin, revoked;
  const ConsolidationStep331(
      this.cost, this.material, this.inBasin, this.revoked);
}

class Consolidation331 {
  static const model = 'incremental-linear-0331';
  static const defaults = ConsolidationParameters331();

  static ConsolidationStep331 evolve({
    required double cost,
    required double material,
    double activation = 0,
    bool revoke = false,
    ConsolidationParameters331 p = defaults,
  }) {
    p.validate();
    if (!cost.isFinite ||
        cost < p.c0 ||
        !material.isFinite ||
        material < 0 ||
        material > 1 ||
        !activation.isFinite ||
        activation < 0 ||
        activation > 1) {
      throw ArgumentError('Invalid consolidation state or activation');
    }
    // An explicit correction overrides the invariant basin. It does not erase
    // evidence; the caller records which confirmations may no longer rearm it.
    if (revoke) {
      return ConsolidationStep331(
          max(cost + p.nu, p.epsilon + p.nu), 0, false, true);
    }
    final chi = cost <= p.epsilon ? 1.0 : 0.0;
    final nextCost =
        max(p.c0, cost + p.nu - p.lambda * activation - p.theta * material);
    final nextMaterial = p.rho * material + (1 - p.rho) * chi;
    return ConsolidationStep331(nextCost, nextMaterial,
        nextCost <= p.epsilon && nextMaterial >= p.threshold, false);
  }
}
