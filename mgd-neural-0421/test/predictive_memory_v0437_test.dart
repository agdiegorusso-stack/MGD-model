import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/predictive_memory_v0437.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';

Map<String, dynamic> copy(PredictiveMemory437 m) =>
    jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>;
double loss(PredictiveMemory437 m, List<int> context, int target,
    {Map<int, double> recall = const {}}) => -log(m.predict(context,
        recall: (_) => recall).firstWhere((p) => p.token == target).probability);
int hash(List<int> sequence) {
  var h = 2166136261;
  for (final t in sequence) h = ((h ^ t) * 16777619) & 0x7fffffff;
  return h;
}

void main() {
  test('Backpropagation agrees with numerical derivatives in every parameter family', () {
    final m = PredictiveMemory437();
    const c = [10, 20], y = 30;
    const recall = {30: 1.0, 20: .2};
    m.train(c, y, recall: recall);
    final before = copy(m);
    m.train(c, y, recall: recall);
    final after = copy(m);
    final families = <(String, int?, int?)>[
      ('embeddings', 1, 0), ('embeddings', 2, 0), ('recurrent', 0, null),
      ('hiddenBias', 0, null), ('output', 3, 0), ('bias', 3, null),
      ('retrievalGain', null, null),
    ];
    double get(Map<String, dynamic> j, (String, int?, int?) f) {
      dynamic v = j[f.$1];
      if (f.$2 != null) v = v[f.$2];
      if (f.$3 != null) v = v[f.$3];
      return (v as num).toDouble();
    }
    void set(Map<String, dynamic> j, (String, int?, int?) f, double v) {
      if (f.$2 == null) { j[f.$1] = v; }
      else if (f.$3 == null) { j[f.$1][f.$2] = v; }
      else { j[f.$1][f.$2][f.$3] = v; }
    }
    for (final f in families) {
      const epsilon = 1e-5;
      final plus = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
      final minus = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
      set(plus, f, get(before, f) + epsilon);
      set(minus, f, get(before, f) - epsilon);
      final numeric = (loss(PredictiveMemory437.fromJson(plus), c, y, recall: recall) -
          loss(PredictiveMemory437.fromJson(minus), c, y, recall: recall)) / (2 * epsilon);
      final analytic = (get(before, f) - get(after, f)) / PredictiveMemory437.learningRate;
      expect(analytic, closeTo(numeric, 1e-6), reason: '${f.$1}: analytic=$analytic numeric=$numeric');
    }
  });

  test('Learns order and transfers it to contexts with an unseen prefix', () {
    final m = PredictiveMemory437();
    const a = [10, 20, 30], b = [20, 10, 30];
    m.train(a, 40); m.train(b, 50);
    final initial = (loss(m, a, 40) + loss(m, b, 50)) / 2;
    final clock = Stopwatch()..start();
    for (var i = 0; i < 600; i++) { m.train(a, 40); m.train(b, 50); }
    final finalLoss = (loss(m, a, 40) + loss(m, b, 50)) / 2;
    expect(finalLoss, lessThan(initial * .3));
    expect(m.predict(a).first.token, 40);
    expect(m.predict(b).first.token, 50);
    // These complete ordered contexts were never supervised.
    final heldOut = <(List<int>, int)>[([99, ...a], 40), ([99, ...b], 50)];
    final correct = heldOut.where((e) => m.predict(e.$1).first.token == e.$2).length;
    expect(correct, 2);
    final out = Directory('tool/reports')..createSync(recursive: true);
    File('${out.path}/predictor-0.42.17.json').writeAsStringSync(jsonEncode({
      'version': '0.42.17', 'architecture': 'recurrent-20-context-8',
      'initial_loss': initial, 'final_loss': finalLoss, 'updates': m.updates,
      'unseen_prefix_correct': correct, 'unseen_prefix_total': heldOut.length,
      'training_ms': clock.elapsedMilliseconds,
      'scope': 'controlled sequence-order task; not a general language benchmark',
    }));
  });

  test('Frozen holdout does not update weights or enter replay, even on repetition', () {
    final m = PredictiveMemory437();
    final token = List.generate(100, (i) => i + 10)
        .firstWhere((t) => hash([0, t, 1]) % 5 == 0);
    final sequence = [0, token, 1];
    m.observe(sequence, recall: (_) => {token: .4});
    final before = jsonEncode(m.toJson()['validation']);
    m.observe(sequence, recall: (_) => {token: 100.0});
    m.replay();
    expect(m.updates, 0); expect(m.replayExamples, 0);
    expect(m.validationExamples, 2);
    expect(jsonEncode(m.toJson()['validation']), before);
    final state = jsonEncode(m.toJson());
    m.validation(); m.predict([0, token]);
    expect(jsonEncode(m.toJson()), state);
  });

  test('Reload preserves predictions, replay and the next exact training update', () {
    final m = PredictiveMemory437();
    for (var i = 0; i < 20; i++) m.observe([0, 10 + i, 11, 1]);
    final restored = PredictiveMemory437.fromJson(copy(m));
    expect(jsonEncode(restored.toJson()), jsonEncode(m.toJson()));
    m.replay(cycles: 16); restored.replay(cycles: 16);
    m.train([0, 71], 72); restored.train([0, 71], 72);
    expect(jsonEncode(restored.toJson()), jsonEncode(m.toJson()));
  });

  test('Bounded vocabulary, replay and per-exposure work survive overflow reload', () {
    final m = PredictiveMemory437();
    m.observe(List.generate(2000, (i) => i));
    expect(m.vocabulary, PredictiveMemory437.maxVocabulary - 1);
    expect(m.updates, lessThanOrEqualTo(PredictiveMemory437.updatesPerExposure + 2));
    for (var i = 0; i < 100; i++) m.observe([0, i + 1, i + 2, 1]);
    expect(m.replayExamples, lessThanOrEqualTo(PredictiveMemory437.replayCapacity));
    expect(m.validationExamples, lessThanOrEqualTo(PredictiveMemory437.validationCapacity));
    final data = copy(m), restored = PredictiveMemory437.fromJson(copy(m));
    expect(restored.updates, m.updates);
    expect(jsonEncode(restored.toJson()), jsonEncode(data));
    expect(jsonEncode(data).length, lessThan(700000));
    expect(m.predict([9999, -1]).every((p) => p.probability.isFinite), true);
  });

  test('Invalid shapes and nonfinite weights reset only the optional predictor', () {
    final m = PredictiveMemory437()..train([0, 10], 11);
    final wrong = copy(m)..['recurrent'] = [1.0];
    expect(PredictiveMemory437.fromJson(wrong).updates, 0);
    final bad = copy(m); bad['embeddings'][0][0] = double.nan;
    expect(PredictiveMemory437.fromJson(bad).updates, 0);
  });

  test('Legacy brain reload preserves facts with or without a predictor', () {
    final brain = PlasticLanguageBrain04()..learnEvent('Il gatto vive in casa.');
    final old = jsonDecode(brain.encodeJson()) as Map<String, dynamic>;
    old.remove('predictor437');
    final loaded = PlasticLanguageBrain04.fromJson(old);
    expect(loaded.predictor437.updates, 0);
    expect(loaded.strongestFacts().map((f) => f.object).toList(),
        brain.strongestFacts().map((f) => f.object).toList());
    final state = jsonDecode(brain.encodeJson()) as Map<String, dynamic>;
    expect(PlasticLanguageBrain04.fromJson(state).predictor437.updates, brain.predictor437.updates);
    state['predictor437'] = {'schema': 1};
    expect(PlasticLanguageBrain04.fromJson(state).assemblies.length, brain.assemblies.length);
  });

  test('Generated answers, zero reward, punishment and legacy sleep do not become targets', () {
    final brain = PlasticLanguageBrain04();
    final before = brain.predictor437.exposures;
    final answer = brain.respond('Il gatto dorme.');
    expect(brain.predictor437.exposures, before + 1);
    final generatedOnly = brain.encode(answer, create: false).ids
        .where((id) => !brain.predictor437.covers(id)).toList();
    expect(generatedOnly, isNotEmpty);
    final updates = brain.predictor437.updates;
    brain.learnSurface('testo non confermato', reward: 0);
    brain.reinforcePair('Il gatto dorme.', answer, false);
    expect(brain.predictor437.updates, updates);
    final exposures = brain.predictor437.exposures;
    brain.sleepReplay(cycles: 8);
    expect(brain.predictor437.exposures, exposures);
    expect(generatedOnly.any(brain.predictor437.covers), false);
  });

  test('Deleting a node clears distributed predictor traces and replay', () {
    final brain = PlasticLanguageBrain04()..learnEvent('Luca vive a Roma.');
    expect(brain.predictor437.exposures, greaterThan(0));
    brain.forgetNode33('Luca');
    expect(brain.predictor437.updates, 0);
    expect(brain.predictor437.vocabulary, 0);
    expect(brain.predictor437.replayExamples, 0);
  });
}
