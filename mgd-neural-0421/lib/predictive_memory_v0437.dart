import 'dart:math';
import 'dart:typed_data';

typedef Recall437 = Map<int, double> Function(List<int> context);

class TokenPrediction437 {
  final int token;
  final double probability;
  const TokenPrediction437(this.token, this.probability);
}

class PredictionEvaluation437 {
  final int examples;
  final double loss, accuracy;
  const PredictionEvaluation437(this.examples, this.loss, this.accuracy);
}

class _Example437 {
  final List<int> context;
  final int target;
  final Map<int, double> recall;
  const _Example437(this.context, this.target, this.recall);
  Map<String, dynamic> toJson() => {
    'context': context, 'target': target,
    'recall': {for (final e in recall.entries) '${e.key}': e.value},
  };
}

/// Small recurrent language predictor. MGD retrieval is a frozen input feature;
/// gradients train embeddings, recurrent state, output and retrieval gain, never
/// differentiate through the graph's discrete activation threshold.
class PredictiveMemory437 {
  static const maxVocabulary = 512;
  static const hiddenSize = 20;
  static const contextSize = 8;
  static const updatesPerExposure = 8;
  static const replayCapacity = 64;
  static const validationCapacity = 32;
  static const learningRate = .08;

  final List<int> _tokens = [-1]; // Unknown input, never offered as a word.
  final Map<int, int> _index = {-1: 0};
  final List<Float64List> _embeddings = [];
  final List<Float64List> _output = [];
  final List<double> _bias = [];
  late Float64List _recurrent;
  final Float64List _hiddenBias = Float64List(hiddenSize);
  final List<_Example437> _replay = [], _validation = [];
  int exposures = 0, updates = 0, skippedTargets = 0;
  int _replayCursor = 0;
  double lossEma = 0, accuracyEma = 0, retrievalGain = .3;

  PredictiveMemory437() {
    final rng = Random(437);
    _recurrent = Float64List.fromList(List.generate(hiddenSize * hiddenSize,
        (i) => (rng.nextDouble() - .5) * .24 +
            (i ~/ hiddenSize == i % hiddenSize ? .35 : 0)));
    _addRows(-1);
  }

  int get vocabulary => _tokens.length - 1;
  int get replayExamples => _replay.length;
  int get validationExamples => _validation.length;
  bool get ready => updates >= 16;
  bool covers(int token) => _index.containsKey(token) && token >= 0;

  void _addRows(int token) {
    final rng = Random(437 + token * 31);
    _embeddings.add(Float64List.fromList(List.generate(hiddenSize,
        (_) => (rng.nextDouble() - .5) * .5)));
    _output.add(Float64List.fromList(List.generate(hiddenSize,
        (_) => (rng.nextDouble() - .5) * .16)));
    _bias.add(0);
  }

  int _ensure(int token) {
    final old = _index[token];
    if (old != null) return old;
    if (token < 0 || _tokens.length >= maxVocabulary) return 0;
    final i = _tokens.length;
    _index[token] = i;
    _tokens.add(token);
    _addRows(token);
    return i;
  }

  static double _tanh(double x) {
    final e = exp(2 * x.clamp(-20.0, 20.0));
    return (e - 1) / (e + 1);
  }

  List<Float64List> _states(List<int> context) {
    final states = [Float64List(hiddenSize)];
    for (final token in context.skip(max(0, context.length - contextSize))) {
      final emb = _embeddings[_index[token] ?? 0];
      final prev = states.last, next = Float64List(hiddenSize);
      for (var j = 0; j < hiddenSize; j++) {
        var x = emb[j] + _hiddenBias[j];
        for (var k = 0; k < hiddenSize; k++) {
          x += _recurrent[j * hiddenSize + k] * prev[k];
        }
        next[j] = _tanh(x);
      }
      states.add(next);
    }
    return states;
  }

  Map<int, double> _features(Map<int, double> raw) {
    var largest = 0.0;
    for (final e in raw.entries) {
      if (_index.containsKey(e.key) && e.value.isFinite && e.value > largest) {
        largest = e.value;
      }
    }
    if (largest <= 0) return {};
    final denominator = log(1 + largest);
    return {for (final e in raw.entries)
      if (_index.containsKey(e.key) && e.value.isFinite && e.value > 0)
        e.key: log(1 + e.value) / denominator};
  }

  Float64List _probabilities(Float64List hidden, Map<int, double> features) {
    final p = Float64List(_tokens.length);
    var largest = double.negativeInfinity;
    for (var i = 0; i < p.length; i++) {
      var x = _bias[i] + retrievalGain * (features[_tokens[i]] ?? 0);
      for (var j = 0; j < hiddenSize; j++) x += _output[i][j] * hidden[j];
      p[i] = x;
      largest = max(largest, x);
    }
    var sum = 0.0;
    for (var i = 0; i < p.length; i++) { p[i] = exp(p[i] - largest); sum += p[i]; }
    for (var i = 0; i < p.length; i++) p[i] /= sum;
    return p;
  }

  /// Pure inference: does not create tokens, examples or update any weights.
  List<TokenPrediction437> predict(List<int> context, {Recall437? recall}) {
    final features = _features(recall?.call(context) ?? {});
    final p = _probabilities(_states(context).last, features);
    final result = [for (var i = 1; i < p.length; i++)
      TokenPrediction437(_tokens[i], p[i])];
    result.sort((a, b) => b.probability.compareTo(a.probability));
    return result;
  }

  /// Explicit supervised update; the caller owns the provenance of the target.
  /// The measured loss is BEFORE updating, rather than scoring a memorized target.
  double train(List<int> context, int target, {Map<int, double> recall = const {}}) {
    final ordered = context.skip(max(0, context.length - contextSize)).toList();
    for (final t in ordered) _ensure(t);
    final y = _ensure(target);
    if (y == 0) { skippedTargets++; return 0; }
    return _train(_Example437(ordered.map((t) => _index.containsKey(t) ? t : -1).toList(), target, _features(recall)));
  }

  double _train(_Example437 example) {
    final target = _index[example.target];
    if (target == null || target == 0) return 0;
    final states = _states(example.context);
    final hidden = states.last;
    final p = _probabilities(hidden, example.recall);
    final loss = -log(max(1e-12, p[target]));
    var best = 0;
    for (var i = 1; i < p.length; i++) if (p[i] > p[best]) best = i;
    final dh = Float64List(hiddenSize);
    final outputGradient = List.generate(p.length, (_) => Float64List(hiddenSize));
    final biasGradient = Float64List(p.length);
    var gainGradient = 0.0, normSquared = 0.0;
    for (var i = 0; i < p.length; i++) {
      final dy = p[i] - (i == target ? 1 : 0);
      biasGradient[i] = dy;
      normSquared += dy * dy;
      gainGradient += dy * (example.recall[_tokens[i]] ?? 0);
      for (var j = 0; j < hiddenSize; j++) {
        final g = dy * hidden[j];
        outputGradient[i][j] = g;
        normSquared += g * g;
        dh[j] += _output[i][j] * dy;
      }
    }
    final recurrentGradient = Float64List(hiddenSize * hiddenSize);
    final hiddenGradient = Float64List(hiddenSize);
    final embeddingGradient = <int, Float64List>{};
    var nextGradient = dh;
    for (var t = example.context.length - 1; t >= 0; t--) {
      final h = states[t + 1], prev = states[t];
      final dz = Float64List(hiddenSize), previousGradient = Float64List(hiddenSize);
      final id = _index[example.context[t]] ?? 0;
      final emb = embeddingGradient.putIfAbsent(id, () => Float64List(hiddenSize));
      for (var j = 0; j < hiddenSize; j++) {
        dz[j] = nextGradient[j] * (1 - h[j] * h[j]);
        hiddenGradient[j] += dz[j];
        emb[j] += dz[j];
        for (var k = 0; k < hiddenSize; k++) {
          recurrentGradient[j * hiddenSize + k] += dz[j] * prev[k];
          previousGradient[k] += _recurrent[j * hiddenSize + k] * dz[j];
        }
      }
      nextGradient = previousGradient;
    }
    for (final g in recurrentGradient) normSquared += g * g;
    for (final g in hiddenGradient) normSquared += g * g;
    for (final row in embeddingGradient.values) for (final g in row) normSquared += g * g;
    normSquared += gainGradient * gainGradient;
    final rate = learningRate * min(1.0, 3 / max(1e-12, sqrt(normSquared)));
    for (var i = 0; i < p.length; i++) {
      _bias[i] -= rate * biasGradient[i];
      for (var j = 0; j < hiddenSize; j++) _output[i][j] -= rate * outputGradient[i][j];
    }
    for (var i = 0; i < _recurrent.length; i++) _recurrent[i] -= rate * recurrentGradient[i];
    for (var j = 0; j < hiddenSize; j++) _hiddenBias[j] -= rate * hiddenGradient[j];
    for (final e in embeddingGradient.entries) {
      for (var j = 0; j < hiddenSize; j++) _embeddings[e.key][j] -= rate * e.value[j];
    }
    retrievalGain = (retrievalGain - rate * gainGradient).clamp(0.0, 2.0).toDouble();
    lossEma = updates == 0 ? loss : .95 * lossEma + .05 * loss;
    accuracyEma = .95 * accuracyEma + .05 * (best == target ? 1 : 0);
    updates++;
    return loss;
  }

  static int _sequenceHash(List<int> sequence) {
    var hash = 2166136261;
    for (final token in sequence) { hash = ((hash ^ token) * 16777619) & 0x7fffffff; }
    return hash;
  }

  /// Reserve a deterministic 20% of complete observations from weight updates.
  /// Repeated observations keep the same assignment. Holdout retrieval features
  /// are frozen on first acquisition, so later graph exposures cannot leak labels.
  void observe(List<int> sequence, {Recall437? recall}) {
    if (sequence.length < 2) return;
    exposures++;
    for (final t in sequence) _ensure(t);
    final heldOut = _sequenceHash(sequence) % 5 == 0;
    final count = min(updatesPerExposure, sequence.length - 1);
    for (var n = 0; n < count; n++) {
      final i = count == 1 ? 0 : n * (sequence.length - 2) ~/ (count - 1);
      final context = sequence.sublist(max(0, i + 1 - contextSize), i + 1);
      final target = sequence[i + 1];
      if ((_index[target] ?? 0) == 0) { skippedTargets++; continue; }
      final example = _Example437(context.map((t) => _index.containsKey(t) ? t : -1).toList(), target, _features(recall?.call(context) ?? {}));
      final buffer = heldOut ? _validation : _replay;
      final duplicate = buffer.any((e) => e.target == target && _same(e.context, example.context));
      // Keep the first frozen feature snapshot even on a repeated exposure.
      if (!duplicate) {
        buffer.add(example);
        if (buffer.length > (heldOut ? validationCapacity : replayCapacity)) buffer.removeAt(0);
      }
      if (!heldOut) _train(example);
    }
    if (!heldOut) replay(cycles: 2);
  }

  static bool _same(List<int> a, List<int> b) =>
      a.length == b.length && List.generate(a.length, (i) => a[i] == b[i]).every((x) => x);

  void replay({int cycles = 32}) {
    for (var i = 0; i < min(max(0, cycles), 128) && _replay.isNotEmpty; i++) {
      _train(_replay[_replayCursor % _replay.length]);
      _replayCursor = (_replayCursor + 1) % _replay.length;
    }
  }

  PredictionEvaluation437 validation() {
    var loss = 0.0, correct = 0;
    for (final e in _validation) {
      final p = _probabilities(_states(e.context).last, e.recall);
      final y = _index[e.target]!;
      loss -= log(max(1e-12, p[y]));
      var best = 0;
      for (var i = 1; i < p.length; i++) if (p[i] > p[best]) best = i;
      if (best == y) correct++;
    }
    return PredictionEvaluation437(_validation.length,
        loss / max(1, _validation.length), correct / max(1, _validation.length));
  }

  Map<String, dynamic> toJson() => {
    'schema': 1, 'tokens': _tokens, 'embeddings': _embeddings, 'output': _output,
    'bias': _bias, 'recurrent': _recurrent, 'hiddenBias': _hiddenBias,
    'retrievalGain': retrievalGain, 'exposures': exposures, 'updates': updates,
    'skippedTargets': skippedTargets, 'lossEma': lossEma, 'accuracyEma': accuracyEma,
    'replayCursor': _replayCursor, 'replay': _replay.map((e) => e.toJson()).toList(),
    'validation': _validation.map((e) => e.toJson()).toList(),
  };

  /// A malformed optional predictor never prevents loading legacy MGD memory.
  static PredictiveMemory437 fromJson(dynamic raw) {
    try {
      if (raw is! Map || raw['schema'] != 1) return PredictiveMemory437();
      final m = PredictiveMemory437();
      final tokens = (raw['tokens'] as List).cast<int>();
      if (tokens.isEmpty || tokens.length > maxVocabulary || tokens.first != -1 ||
          tokens.toSet().length != tokens.length || tokens.skip(1).any((t) => t < 0)) {
        throw const FormatException('Invalid vocabulary');
      }
      double number(dynamic x) {
        if (x is! num || !x.isFinite || x.abs() > 1e12) throw const FormatException('Invalid number');
        return x.toDouble();
      }
      Float64List vector(dynamic x, int length) {
        if (x is! List || x.length != length) throw const FormatException('Invalid shape');
        final a = Float64List.fromList(x.map(number).toList());
        if (a.any((v) => v.abs() > 100)) throw const FormatException('Invalid weight');
        return a;
      }
      List<Float64List> matrix(dynamic x) {
        if (x is! List || x.length != tokens.length) throw const FormatException('Invalid rows');
        return x.map((r) => vector(r, hiddenSize)).toList();
      }
      m._tokens..clear()..addAll(tokens);
      m._index..clear()..addEntries(List.generate(tokens.length, (i) => MapEntry(tokens[i], i)));
      m._embeddings..clear()..addAll(matrix(raw['embeddings']));
      m._output..clear()..addAll(matrix(raw['output']));
      m._bias..clear()..addAll(vector(raw['bias'], tokens.length));
      m._recurrent = vector(raw['recurrent'], hiddenSize * hiddenSize);
      m._hiddenBias.setAll(0, vector(raw['hiddenBias'], hiddenSize));
      m.retrievalGain = number(raw['retrievalGain']);
      m.lossEma = number(raw['lossEma']); m.accuracyEma = number(raw['accuracyEma']);
      if (m.retrievalGain < 0 || m.retrievalGain > 2 || m.lossEma < 0 ||
          m.accuracyEma < 0 || m.accuracyEma > 1) throw const FormatException('Invalid metrics');
      int count(String key) {
        final n = number(raw[key]);
        if (n < 0 || n != n.truncateToDouble()) throw const FormatException('Invalid count');
        return n.toInt();
      }
      m.exposures = count('exposures'); m.updates = count('updates');
      m.skippedTargets = count('skippedTargets'); m._replayCursor = count('replayCursor');
      void examples(dynamic x, List<_Example437> buffer, int limit) {
        if (x is! List || x.length > limit) throw const FormatException('Invalid replay');
        for (final row in x) {
          final c = (row['context'] as List).cast<int>().toList();
          final target = row['target'] as int;
          if (c.isEmpty || c.length > contextSize || !m._index.containsKey(target) ||
              target < 0 || c.any((t) => !m._index.containsKey(t))) {
            throw const FormatException('Invalid example');
          }
          final features = <int, double>{};
          for (final e in (row['recall'] as Map).entries) {
            final k = int.parse(e.key.toString()), v = number(e.value);
            if (!m._index.containsKey(k) || v < 0 || v > 1) throw const FormatException('Invalid recall');
            features[k] = v;
          }
          buffer.add(_Example437(c, target, features));
        }
      }
      examples(raw['replay'], m._replay, replayCapacity);
      examples(raw['validation'], m._validation, validationCapacity);
      return m;
    } catch (_) { return PredictiveMemory437(); }
  }
}
