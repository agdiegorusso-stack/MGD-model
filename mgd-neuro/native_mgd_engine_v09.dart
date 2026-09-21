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
    final b = p.xi + (1.0 - p.rho);
    final c = (1.0 - p.rho) * chi;
    if (a <= 1e-12) return chi;
    final disc = max(0.0, b * b - 4.0 * a * c);
    final smaller = (b - sqrt(disc)) / (2.0 * a);
    return smaller.clamp(0.0, 1.0).toDouble();
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
      final nextMemory = p.alpha * m + p.beta * a;

      // Generalised graph-coherence trigger: an admitted edge contributes to
      // local coherence when it is geometrically active (w <= epsilon).
      final chi = w <= p.epsilon ? 1.0 : 0.0;
      final nextChiAvg = 0.97 * chiAvg + 0.03 * chi;

      // MGD 0.5 logistic material recursion.
      final nextMaterial = (p.rho * M +
              (1.0 - p.rho) * chi -
              p.xi * M * (M - 1.0))
          .clamp(0.0, 1.0)
          .toDouble();

      final mStar = equilibriumMaterial(nextChiAvg, p: p);

      // MGD 0.5 full-weight drift, adapted from directional lattice arcs to
      // an arbitrary learned relation edge. Reward modulates forcing strength;
      // negative feedback adds a repulsive term instead of deleting memory.
      final effectiveActivation = a * (0.65 + 0.35 * positive);
      final deltaW = p.nu -
          p.lambda * effectiveActivation -
          p.eta * nextMemory +
          p.etaPlus * (nextMaterial - mStar) +
          p.punishment * negative * a;

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

  static double strength({
    required double weight,
    required double memory,
    required double material,
    MgdParameters09 p = defaults,
  }) {
    if (weight > p.epsilon) return 0.0;
    final geometric = exp(-(weight - p.c0).clamp(0.0, 4.0));
    return (geometric *
            (0.50 +
                0.25 * memory.clamp(0.0, 1.0) +
                0.25 * material.clamp(0.0, 1.0)))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  static double curiosityScore({
    required double novelty,
    required double uncertainty,
    required double relevance,
    required double stability,
  }) {
    return (novelty.clamp(0.0, 1.0) *
            uncertainty.clamp(0.0, 1.0) *
            relevance.clamp(0.0, 1.0) *
            stability.clamp(0.0, 1.0))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  static double ollivierRicci({
    required String a,
    required String b,
    required double edgeWeight,
    required Map<String, Map<String, double>> activeAdjacency,
    int maxBallSize = 12,
  }) {
    if (edgeWeight <= 1e-9) return 0.0;

    List<String> ball(String x) {
      final xs = <String>[x, ...?activeAdjacency[x]?.keys];
      final seen = <String>{};
      final out = <String>[];
      for (final n in xs) {
        if (seen.add(n)) out.add(n);
        if (out.length >= maxBallSize) break;
      }
      return out;
    }

    final left = ball(a);
    final right = ball(b);
    if (left.isEmpty || right.isEmpty) return 0.0;

    double shortest(String source, String target) {
      if (source == target) return 0.0;
      final dist = <String, double>{source: 0.0};
      final visited = <String>{};

      while (true) {
        String? best;
        var bestD = double.infinity;
        for (final e in dist.entries) {
          if (!visited.contains(e.key) && e.value < bestD) {
            best = e.key;
            bestD = e.value;
          }
        }
        if (best == null) break;
        if (best == target) return bestD;
        visited.add(best);
        for (final e in activeAdjacency[best]?.entries ?? const <MapEntry<String, double>>[]) {
          if (visited.contains(e.key)) continue;
          final nd = bestD + e.value;
          if (nd < (dist[e.key] ?? double.infinity)) dist[e.key] = nd;
        }
      }
      return 4.0 * max(1.0, edgeWeight);
    }

    final costs = List.generate(
      left.length,
      (i) => List<double>.generate(
        right.length,
        (j) => shortest(left[i], right[j]),
      ),
    );

    // Exact min-cost transport for the two uniform neighbourhood measures.
    final nL = left.length;
    final nR = right.length;
    final source = 0;
    final left0 = 1;
    final right0 = left0 + nL;
    final sink = right0 + nR;
    final n = sink + 1;

    final residual = List.generate(n, (_) => <_FlowEdge09>[]);
    void addEdge(int u, int v, double cap, double cost) {
      final f = _FlowEdge09(v, residual[v].length, cap, cost);
      final r = _FlowEdge09(u, residual[u].length, 0.0, -cost);
      residual[u].add(f);
      residual[v].add(r);
    }

    final supply = 1.0 / nL;
    final demand = 1.0 / nR;
    for (var i = 0; i < nL; i++) addEdge(source, left0 + i, supply, 0.0);
    for (var j = 0; j < nR; j++) addEdge(right0 + j, sink, demand, 0.0);
    for (var i = 0; i < nL; i++) {
      for (var j = 0; j < nR; j++) {
        addEdge(left0 + i, right0 + j, 1.0, costs[i][j]);
      }
    }

    var flow = 0.0;
    var totalCost = 0.0;
    const eps = 1e-9;
    while (flow < 1.0 - eps) {
      final dist = List<double>.filled(n, double.infinity);
      final prevNode = List<int>.filled(n, -1);
      final prevEdge = List<int>.filled(n, -1);
      dist[source] = 0.0;

      for (var iter = 0; iter < n - 1; iter++) {
        var changed = false;
        for (var u = 0; u < n; u++) {
          if (!dist[u].isFinite) continue;
          for (var ei = 0; ei < residual[u].length; ei++) {
            final e = residual[u][ei];
            if (e.capacity <= eps) continue;
            final nd = dist[u] + e.cost;
            if (nd + eps < dist[e.to]) {
              dist[e.to] = nd;
              prevNode[e.to] = u;
              prevEdge[e.to] = ei;
              changed = true;
            }
          }
        }
        if (!changed) break;
      }

      if (!dist[sink].isFinite) break;
      var aug = 1.0 - flow;
      var v = sink;
      while (v != source) {
        final u = prevNode[v];
        final ei = prevEdge[v];
        if (u < 0 || ei < 0) {
          aug = 0.0;
          break;
        }
        aug = min(aug, residual[u][ei].capacity);
        v = u;
      }
      if (aug <= eps) break;

      v = sink;
      while (v != source) {
        final u = prevNode[v];
        final ei = prevEdge[v];
        final e = residual[u][ei];
        e.capacity -= aug;
        residual[v][e.reverseIndex].capacity += aug;
        totalCost += aug * e.cost;
        v = u;
      }
      flow += aug;
    }

    if (flow < 1.0 - 1e-6) return 0.0;
    return (1.0 - totalCost / edgeWeight).clamp(-1.0, 1.0).toDouble();
  }
}

class _FlowEdge09 {
  final int to;
  final int reverseIndex;
  double capacity;
  final double cost;

  _FlowEdge09(this.to, this.reverseIndex, this.capacity, this.cost);
}
