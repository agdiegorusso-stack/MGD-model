import 'dart:convert';
import '../../lib/consolidation_v0331.dart';
import '../../lib/consolidation_provenance_v0331.dart';
import '../../lib/native_mgd_engine_v09.dart';
import '../../lib/plastic_language_brain_v04.dart';
import '../../lib/sensory_world_v06.dart';

Map<String, dynamic> runConsolidationChecks331() {
  final checks = <String, bool>{};
  void check(String name, bool value) {
    checks[name] = value;
    if (!value) throw StateError('FAIL: $name');
  }

  bool rejects(void Function() f) {
    try {
      f();
      return false;
    } on ArgumentError {
      return true;
    }
  }

  Map<String, dynamic> roundtrip(Map<String, dynamic> j) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(j)) as Map);
  const p = Consolidation331.defaults;
  var cost = 2.0, material = 0.0;
  var steps = 0;
  while ((cost > p.epsilon || material < p.threshold) && steps < 200) {
    final s =
        Consolidation331.evolve(cost: cost, material: material, activation: 1);
    cost = s.cost;
    material = s.material;
    steps++;
  }
  check('finite_training_enters_basin', steps < 200);
  for (var i = 0; i < 2000; i++) {
    final s = Consolidation331.evolve(cost: cost, material: material);
    if (!s.inBasin) throw StateError('Left invariant basin at $i');
    cost = s.cost;
    material = s.material;
  }
  check('withdrawal_preserves_activity_and_reaches_floor',
      cost == p.c0 && material > .999);
  final boundary =
      Consolidation331.evolve(cost: p.epsilon, material: p.threshold);
  check('boundary_basin_invariant', boundary.inBasin);
  final revoked =
      Consolidation331.evolve(cost: cost, material: material, revoke: true);
  check('revocation_overrides_basin',
      revoked.cost > p.epsilon && revoked.material == 0 && revoked.revoked);
  final immediate = Consolidation331.evolve(
      cost: .5, material: 0, p: const ConsolidationParameters331(rho: 0));
  check('rho_zero_supported', immediate.material == 1);
  check(
      'invalid_parameter_regimes_rejected',
      rejects(() =>
              const ConsolidationParameters331(lambda: .0045).validate()) &&
          rejects(() =>
              const ConsolidationParameters331(theta: .0045).validate()) &&
          rejects(() => const ConsolidationParameters331(rho: 1).validate()));
  check('nonfinite_state_rejected',
      rejects(() => Consolidation331.evolve(cost: double.nan, material: 0)));
  final negative = MgdMath09.evolve(
      weight: .05,
      memory: 1,
      material: 1,
      coherenceAverage: 1,
      activation: 1,
      reward: -1);
  check('negative_feedback_beats_saturated_familiarity',
      negative.weight > .05 && negative.memory < 1);
  final clocks = PlasticLanguageBrain04();
  final old = PlasticEdge04(from: 0, to: 1, cost: 2.6, lastUsed: 0);
  final recent = PlasticEdge04(from: 0, to: 2, cost: 2.6, lastUsed: 1900);
  clocks.temporal[0] = {1: old, 2: recent};
  clocks.step = 2000;
  clocks.maintenance();
  check('maintenance_prunes_old_edge_keeps_recent',
      clocks.temporal[0]?[1] == null && clocks.temporal[0]?[2] == recent);
  check('maintenance_does_not_fake_usage',
      recent.lastUsed == 1900 && recent.lastEvolved == 2000);
  final evolvedCost = recent.cost;
  clocks.maintenance();
  check('same_tick_maintenance_idempotent', recent.cost == evolvedCost);
  final legacyEdge = recent.toJson()..remove('lastEvolved');
  check('legacy_clock_migrates_from_usage',
      PlasticEdge04.fromJson(legacyEdge).lastEvolved == 1900);

  var b = PlasticLanguageBrain04();
  const prompt = 'Come stai?', answer = 'Sto male.';
  b.teachResponse(prompt, answer);
  b.reinforcePair(prompt, answer, false);
  check(
      'one_rejection_blocks_attractor_even_positive_aggregate_reward',
      b.responseOptions028(prompt).isEmpty &&
          b.episodes.any((e) => e.reward > 0 && e.responseRevoked331));
  b.sleepReplay(cycles: 64);
  b = PlasticLanguageBrain04.fromJson(roundtrip(b.toJson()));
  b.sleepReplay(cycles: 64);
  check(
      'rejected_response_stays_blocked_after_replay_restart',
      b.responseOptions028(prompt).isEmpty &&
          b.respond(prompt) != answer &&
          b.guardResponse331(prompt, answer) != answer);
  b.teachResponse(prompt, answer, reward: 0);
  check('neutral_teaching_cannot_rearm', b.responseOptions028(prompt).isEmpty);
  b.teachResponse(prompt, answer, reward: .65);
  check('explicit_positive_teaching_rearms',
      b.responseOptions028(prompt).contains(answer));

  b = PlasticLanguageBrain04();
  b.teachResponse('Dove vive Ada?', 'Roma');
  b.ensureSemanticEntity06('Roma');
  var w = MgdWorld06();
  w.setConsolidationEnabled331(true);
  void replay() {
    final facts = ConsolidationEvidence331.collect(b);
    final byEdge = ConsolidationEvidence331.byEdge(facts);
    w.syncConsolidationEvidence331(byEdge);
    for (final f in facts) {
      w.rehearseExternalFact319(f.subject, f.object,
          evidence331:
              byEdge[MgdWorld06.semanticEdgeKey331(f.subject, f.object)]);
    }
  }

  final factsBefore =
      jsonEncode(b.slots.values.map((s) => s.toJson()).toList());
  for (var i = 0; i < 30; i++) {
    replay();
  }
  check('actual_episode_provenance_consolidates',
      w.consolidationBasinCount331 > 0);
  check(
      'replay_does_not_manufacture_evidence_or_confidence',
      jsonEncode(b.slots.values.map((s) => s.toJson()).toList()) ==
          factsBefore);
  b.reinforcePair('Dove vive Ada?', 'Roma', false);
  replay();
  check(
      'rejected_source_withdrawn_and_world_revoked',
      ConsolidationEvidence331.collect(b).isEmpty &&
          w.consolidationRevokedCount331 > 0 &&
          w.edges.values.every((e) => e.cost > p.epsilon));
  b = PlasticLanguageBrain04.fromJson(roundtrip(b.toJson()));
  w = MgdWorld06.fromJson(roundtrip(w.toJson()));
  w.setConsolidationEnabled331(false);
  w.setConsolidationEnabled331(true);
  for (var i = 0; i < 30; i++) {
    replay();
    w.sleepReplay();
  }
  check(
      'restart_toggle_and_replay_cannot_restore_rejected_source',
      w.consolidationBasinCount331 == 0 &&
          w.edges.values.every((e) => e.cost > p.epsilon));
  b.teachResponse('Dove vive Ada?', 'Roma', reward: .65);
  for (var i = 0; i < 30; i++) {
    replay();
  }
  check('new_explicit_confirmation_can_rearm_world',
      w.consolidationBasinCount331 > 0);

  final key = w.edges.keys.first, edge = w.edges.values.first;
  w.syncConsolidationEvidence331({
    key: {'A', 'B'}
  });
  w.syncConsolidationEvidence331({
    key: {'B'}
  });
  w.syncConsolidationEvidence331({});
  w.syncConsolidationEvidence331({
    key: {'A'}
  });
  w.consolidateSemanticLink029(
      int.parse(edge.a.substring(2)), int.parse(edge.b.substring(2)));
  w.importTeacherSemanticLink08(
      int.parse(edge.a.substring(2)), int.parse(edge.b.substring(2)), 1);
  check(
      'partial_source_withdrawal_tombstone_survives_reanalysis',
      edge.blockedConsolidationEvidence331.containsAll({'A', 'B'}) &&
          edge.consolidationReplayBlocked331 &&
          edge.cost > p.epsilon);
  final saved = w.toJson();
  final oldSnapshot = roundtrip(saved)
    ..remove('consolidationModel331')
    ..remove('consolidationEnabled331');
  check(
      'legacy_snapshot_defaults_disabled_preserves_edges',
      !MgdWorld06.fromJson(oldSnapshot).consolidationEnabled331 &&
          MgdWorld06.fromJson(oldSnapshot).edges.length == w.edges.length);
  final stale = roundtrip(saved)..['runtimeBaseStep331'] = w.step;
  w.setConsolidationEnabled331(false);
  w.applyRuntime320(stale);
  check(
      'stale_worker_cannot_undo_toggle',
      !w.consolidationEnabled331 &&
          w.edges.values.every((e) => e.consolidationMaterial331 == 0));
  final deletedSnapshot = roundtrip(w.toJson())
    ..['runtimeBaseStep331'] = w.step;
  w.edges.clear();
  w.step++;
  w.applyRuntime320(deletedSnapshot);
  check('stale_worker_cannot_resurrect_deleted_edge', w.edges.isEmpty);
  return {
    'model': Consolidation331.model,
    'checks': checks,
    'passed': checks.length,
    'training_steps': steps,
    'negative_cost': negative.weight,
    'after_withdrawal_cost': cost
  };
}
