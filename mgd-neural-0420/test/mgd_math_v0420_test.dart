import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/native_mgd_engine_v09.dart';

void main() {
  test('equilibrium solves the constant-forcing recurrence', () {
    const p = MgdMath09.defaults;
    for (final chi in [0.0, .01, .25, .5, .75, 1.0]) {
      final m = MgdMath09.equilibriumMaterial(chi);
      final next = p.rho * m + (1 - p.rho) * chi + p.xi * m * (1 - m);
      expect(m, closeTo(next, 1e-12));
    }
  });
  test('local geometry stays bounded under alternating feedback', () {
    final rng = Random(420);
    var w = .95, m = 0.0, material = 0.0, chi = 0.0;
    for (var i = 0; i < 5000; i++) {
      final step = MgdMath09.evolve(weight: w, memory: m, material: material,
        coherenceAverage: chi, activation: rng.nextDouble(),
        reward: (rng.nextInt(3) - 1).toDouble());
      w = step.weight; m = step.memory; material = step.material;
      chi = step.coherenceAverage;
      expect(w, inInclusiveRange(.05, 3.6));
      expect(m, inInclusiveRange(0, 1.5));
      expect(material, inInclusiveRange(0, 1));
      expect(chi, inInclusiveRange(0, 1));
      expect(step.informationalFlux, greaterThanOrEqualTo(0));
    }
  });
  test('negative feedback moves even a familiar edge away from the floor', () {
    final step = MgdMath09.evolve(weight: .05, memory: 1.0, material: 1.0,
      coherenceAverage: 1.0, activation: .2, reward: -1);
    expect(step.weight, greaterThan(.05));
  });
}
