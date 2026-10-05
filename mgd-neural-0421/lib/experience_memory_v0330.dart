/// An on-device episodic classifier, not a pretrained general purpose model.
/// Confirmed observations are immutable; only a bounded diagonal metric adapts.
/// There is no clock, background training, auto-labelled feedback or eviction.
library;

import 'dart:convert';
import 'dart:math';

typedef Features33 = Map<String, Map<String, double>>;

String canonical33(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class Experience33 {
  final int id;
  final String label, context, description, source, at;
  final Features33 features;
  Experience33({
    required this.id,
    required String label,
    required String context,
    required this.description,
    required this.source,
    required this.at,
    required Features33 features,
  })  : label = label.trim(),
        context = canonical33(context),
        features = Map.unmodifiable(
          features.map(
            (k, v) => MapEntry(k, Map<String, double>.unmodifiable(v)),
          ),
        );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'context': context,
        'description': description,
        'source': source,
        'at': at,
        'features': features,
      };
  factory Experience33.fromJson(Map<String, dynamic> j) => Experience33(
        id: (j['id'] as num).toInt(),
        label: j['label'] as String,
        context: j['context'] as String,
        description: j['description'] as String,
        source: j['source'] as String,
        at: j['at'] as String,
        features: ExperienceMemory33.validate(
          (j['features'] as Map).map(
            (k, v) => MapEntry(
              k.toString(),
              (v as Map).map(
                (a, b) => MapEntry(a.toString(), (b as num).toDouble()),
              ),
            ),
          ),
          normalize: false,
        ),
      );
}

class Prediction33 {
  final Map<String, double> probabilities;
  final Map<String, Map<String, double>> channels;
  final List<int> evidenceIds;
  final String reason;
  final bool accepted, exactRecall;
  const Prediction33(
    this.probabilities,
    this.channels,
    this.evidenceIds,
    this.reason, {
    this.accepted = false,
    this.exactRecall = false,
  });
  String? get best => probabilities.isEmpty
      ? null
      : probabilities.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  double get score => best == null ? 0 : probabilities[best]!;
}

class ExperienceMemory33 {
  static const int capacity = 2048, maxFeatures = 512;
  static const channels = {'text:v1', 'vision:v1', 'audio:v1'};
  static const double temperature = 12;
  final List<Experience33> _episodes = [];
  final Map<String, Map<String, Map<String, double>>> _weights = {};
  final Map<String, double> _temperatures = {};
  int _nextId = 1, revision = 0, acceptedUpdates = 0, rejectedUpdates = 0;
  int evaluated = 0,
      correct = 0,
      answered = 0,
      answeredCorrect = 0,
      coldStarts = 0;
  int lastPredictMicros = 0, lastLearnMicros = 0, coordinatesVisited = 0;
  double logLoss = 0;
  bool evaluationReset = false;

  List<Experience33> get episodes => List.unmodifiable(_episodes);
  int get conceptCount => _episodes
      .map((e) => jsonEncode([e.context, canonical33(e.label)]))
      .toSet()
      .length;
  int get serializedBytes => utf8.encode(jsonEncode(toJson())).length;
  Map<String, dynamic> get metrics => {
        'episodes': _episodes.length,
        'concepts': conceptCount,
        'capacity': capacity,
        'evaluatedBeforeLearning': evaluated,
        'correctBeforeLearning': correct,
        'answered': answered,
        'answeredCorrect': answeredCorrect,
        'coldStarts': coldStarts,
        'meanLogLoss': evaluated == 0 ? null : logLoss / evaluated,
        'acceptedMetricUpdates': acceptedUpdates,
        'rejectedMetricUpdates': rejectedUpdates,
        'lastPredictMicros': lastPredictMicros,
        'lastLearnMicros': lastLearnMicros,
        'coordinatesVisited': coordinatesVisited,
        'evaluationResetAfterDeletion': evaluationReset,
      };

  static Features33 validate(Features33 input, {bool normalize = true}) {
    if (input.isEmpty || input.length > 3)
      throw ArgumentError('Aggiungi almeno uno stimolo.');
    final out = <String, Map<String, double>>{};
    for (final entry in input.entries) {
      if (!channels.contains(entry.key))
        throw ArgumentError(
          'Versione del sensore non compatibile: ${entry.key}',
        );
      if (entry.value.isEmpty || entry.value.length > maxFeatures)
        throw ArgumentError('Dimensione dello stimolo non valida.');
      var norm = 0.0;
      for (final f in entry.value.entries) {
        if (f.key.isEmpty ||
            f.key.length > 160 ||
            !f.value.isFinite ||
            f.value.abs() > 1e6) {
          throw ArgumentError('Stimolo non finito o non valido.');
        }
        norm += f.value * f.value;
      }
      if (norm < 1e-20)
        throw ArgumentError('Stimolo privo di segnale: ${entry.key}');
      final scale = normalize ? sqrt(norm) : 1.0;
      out[entry.key] = {
        for (final f in entry.value.entries)
          if (f.value != 0) f.key: f.value / scale,
      };
    }
    return out;
  }

  /// Local lexical features preserve adjacent word order. They are NOT an LLM,
  /// speech recognizer or an assertion that lexical similarity is meaning.
  static Map<String, double> textFeatures(String text) {
    if (text.length > 8000)
      throw ArgumentError('Usa uno stimolo di massimo 8000 caratteri.');
    final words = RegExp(r"[a-zà-öø-ÿ0-9]+(?:'[a-zà-öø-ÿ0-9]+)?")
        .allMatches(canonical33(text))
        .map((m) => m.group(0)!)
        .toList();
    if (words.length > 240)
      throw ArgumentError('Usa al massimo 240 parole per esperienza.');
    final f = <String, double>{};
    for (var i = 0; i < words.length; i++) {
      final u = 'w:${words[i]}';
      f[u] = (f[u] ?? 0) + 1;
      if (i > 0) {
        final b = 'b:${words[i - 1]} ${words[i]}';
        f[b] = (f[b] ?? 0) + 1;
      }
    }
    return f;
  }

  double _distance(
    Map<String, double> a,
    Map<String, double> b,
    String context,
    String channel,
    Map<String, Map<String, Map<String, double>>> weights,
  ) {
    final w = weights[context]?[channel] ?? const <String, double>{};
    var d = 0.0;
    for (final k in {...a.keys, ...b.keys}) {
      final delta = (a[k] ?? 0) - (b[k] ?? 0);
      d += (w[k] ?? 1) * delta * delta;
      coordinatesVisited++;
    }
    return d;
  }

  static bool _same(Map<String, double> a, Map<String, double> b) =>
      a.length == b.length &&
      a.entries.every(
        (e) => ((b[e.key] ?? double.infinity) - e.value).abs() < 1e-9,
      );

  Prediction33 predict(Features33 input, {String context = 'generale'}) {
    final watch = Stopwatch()..start();
    coordinatesVisited = 0;
    final result = _predict(validate(input), canonical33(context), _weights);
    lastPredictMicros = watch.elapsedMicroseconds;
    return result;
  }

  Map<String, double> _posterior(
    Features33 x,
    List<Experience33> pool,
    String context,
    Map<String, Map<String, Map<String, double>>> weights,
  ) {
    final kernels = <String, List<double>>{};
    for (final e in pool) {
      if (!x.keys.every(e.features.containsKey)) continue;
      var d = 0.0;
      for (final m in x.keys) {
        d += _distance(x[m]!, e.features[m]!, context, m, weights);
      }
      // Arithmetic mean of within-class kernels gives each label equal prior
      // mass, independent of how often that label has been repeated.
      kernels
          .putIfAbsent(canonical33(e.label), () => [])
          .add(exp(-(_temperatures[context] ?? temperature) * d / x.length));
    }
    final scores = {
      for (final e in kernels.entries)
        e.key: e.value.reduce((a, b) => a + b) / e.value.length,
    };
    final sum = scores.values.fold(0.0, (a, b) => a + b);
    return sum <= 1e-100 ? {} : scores.map((k, v) => MapEntry(k, v / sum));
  }

  Prediction33 _predict(
    Features33 x,
    String context,
    Map<String, Map<String, Map<String, double>>> weights, {
    int? exclude,
  }) {
    final pool = _episodes
        .where((e) => e.context == context && e.id != exclude)
        .toList();
    final byChannel = <String, Map<String, double>>{
      for (final m in x.keys) m: _posterior({m: x[m]!}, pool, context, weights),
    };
    final complete =
        pool.where((e) => x.keys.every(e.features.containsKey)).toList();
    if (complete.isEmpty)
      return Prediction33(
        {},
        byChannel,
        [],
        pool.isEmpty
            ? 'Nessun esempio confermato in questo contesto.'
            : 'Questi canali non sono ancora associati in un episodio confermato.',
      );
    final exact = complete
        .where(
          (e) => x.entries.every((m) => _same(m.value, e.features[m.key]!)),
        )
        .toList();
    final exactLabels = exact.map((e) => canonical33(e.label)).toSet();
    if (exactLabels.isNotEmpty) {
      return Prediction33(
        {for (final l in exactLabels) l: 1 / exactLabels.length},
        byChannel,
        exact.map((e) => e.id).toList(),
        exactLabels.length == 1
            ? 'Richiamo di uno stimolo già confermato.'
            : 'Lo stesso stimolo ha conferme incompatibili: correggi gli episodi o distingui il contesto.',
        accepted: exactLabels.length == 1,
        exactRecall: true,
      );
    }
    final p = _posterior(x, complete, context, weights);
    final ranked = p.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var nearest = double.infinity;
    final evidence = <int>[];
    for (final e in complete) {
      var d = 0.0;
      for (final m in x.keys) {
        d += _distance(x[m]!, e.features[m]!, context, m, weights);
      }
      d /= x.length;
      if (d < nearest) nearest = d;
    }
    if (ranked.isNotEmpty)
      evidence.addAll(
        complete
            .where((e) => canonical33(e.label) == ranked.first.key)
            .take(8)
            .map((e) => e.id),
      );
    // Open-set distance check: a lone stored class must not get 100% certainty
    // for an arbitrary new stimulus. Scores are NOT calibrated probabilities.
    final accepted = ranked.isNotEmpty &&
        nearest < .38 &&
        ranked.first.value >= .72 &&
        (ranked.length == 1 || ranked.first.value - ranked[1].value >= .20);
    return Prediction33(
      p,
      byChannel,
      evidence,
      accepted
          ? 'Candidato per somiglianza; confermalo prima di apprenderlo.'
          : 'Stimolo nuovo o ambiguo: serve una conferma.',
      accepted: accepted,
    );
  }

  List<Experience33> _balanced(String context, {int limit = 24}) {
    final groups = <String, List<Experience33>>{};
    for (final e in _episodes.where((e) => e.context == context)) {
      groups.putIfAbsent(canonical33(e.label), () => []).add(e);
    }
    final result = <Experience33>[];
    // Round robin across classes, stable across restarts; keep both old and new.
    for (var depth = 0; result.length < limit; depth++) {
      var added = false;
      for (final g in groups.values) {
        if (depth >= g.length) continue;
        result.add(g[depth.isEven ? depth ~/ 2 : g.length - 1 - depth ~/ 2]);
        added = true;
        if (result.length == limit) break;
      }
      if (!added) break;
    }
    return result;
  }

  void _adapt(Experience33 incoming) {
    final temperature =
        this._temperatures[incoming.context] ?? ExperienceMemory33.temperature;
    final refs = _balanced(incoming.context, limit: 48);
    if (refs.map((e) => canonical33(e.label)).toSet().length < 2) return;
    final candidate = <String, Map<String, Map<String, double>>>{
      for (final c in _weights.entries)
        c.key: {for (final m in c.value.entries) m.key: Map.of(m.value)},
    };
    var changed = false;
    for (final m in incoming.features.keys) {
      final eligible = refs.where((e) => e.features.containsKey(m)).toList();
      final positive = eligible
          .where((e) => canonical33(e.label) == canonical33(incoming.label))
          .toList();
      if (positive.isEmpty || positive.length == eligible.length) continue;
      final counts = <String, int>{};
      for (final e in eligible) {
        final l = canonical33(e.label);
        counts[l] = (counts[l] ?? 0) + 1;
      }
      final mass = <int, double>{};
      var all = 0.0, pos = 0.0;
      for (final e in eligible) {
        final q = exp(
              -temperature *
                  _distance(
                    incoming.features[m]!,
                    e.features[m]!,
                    incoming.context,
                    m,
                    _weights,
                  ),
            ) /
            counts[canonical33(e.label)]!;
        mass[e.id] = q;
        all += q;
        if (canonical33(e.label) == canonical33(incoming.label)) pos += q;
      }
      if (pos < 1e-100 || all < 1e-100) continue;
      final w = candidate
          .putIfAbsent(incoming.context, () => {})
          .putIfAbsent(m, () => {});
      final keys = {
        ...incoming.features[m]!.keys,
        ...eligible.expand((e) => e.features[m]!.keys),
      };
      for (final k in keys) {
        var ea = 0.0, ep = 0.0;
        for (final e in eligible) {
          final d = (incoming.features[m]![k] ?? 0) - (e.features[m]![k] ?? 0);
          ea += mass[e.id]! * d * d / all;
          if (canonical33(e.label) == canonical33(incoming.label))
            ep += mass[e.id]! * d * d / pos;
        }
        // Gradient of class-balanced kernel negative log likelihood.
        w[k] = ((w[k] ?? 1) - .035 * temperature * (ep - ea))
            .clamp(.05, 8)
            .toDouble();
      }
      changed = true;
    }
    if (!changed) return;
    var oldLoss = 0.0, newLoss = 0.0;
    var pass = true;
    for (final e in refs.take(24)) {
      final old = _predict(e.features, e.context, _weights, exclude: e.id);
      final next = _predict(e.features, e.context, candidate, exclude: e.id);
      final label = canonical33(e.label);
      oldLoss -= log(max(1e-12, old.probabilities[label] ?? 0));
      newLoss -= log(max(1e-12, next.probabilities[label] ?? 0));
      if (old.best == label && next.best != label) pass = false;
    }
    if (pass && newLoss <= oldLoss + 1e-9) {
      _weights
        ..clear()
        ..addAll(candidate);
      acceptedUpdates++;
    } else {
      rejectedUpdates++;
    }
  }

  /// Select score sharpness using retained training episodes, leaving each
  /// anchor out of its own reference set. Never inspect evaluation samples.
  /// This is bounded empirical calibration, not an open-world certainty proof.
  void _calibrate(String context) {
    final pool = _episodes.where((e) => e.context == context).toList();
    if (pool.length % 8 != 0) return;
    final counts = <String, int>{};
    for (final e in pool) {
      final l = canonical33(e.label);
      counts[l] = (counts[l] ?? 0) + 1;
    }
    if (counts.length < 2 || counts.values.any((n) => n < 2)) return;
    final anchors = _balanced(context, limit: 16);
    final previous = _temperatures[context] ?? temperature;
    final baseline = <int, String?>{};
    double loss(double value, {bool capture = false}) {
      _temperatures[context] = value;
      var total = 0.0;
      for (final e in anchors) {
        final p = _posterior(e.features,
            pool.where((x) => x.id != e.id).toList(), context, _weights);
        final ranked = p.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final best = ranked.isEmpty ? null : ranked.first.key;
        if (capture) baseline[e.id] = best;
        if (!capture &&
            baseline[e.id] == canonical33(e.label) &&
            best != baseline[e.id]) return double.infinity;
        total -= log(max(1e-12, p[canonical33(e.label)] ?? 0));
      }
      return total / anchors.length + 1e-5 * value;
    }

    var selected = previous, bestLoss = loss(previous, capture: true);
    for (final value in [6.0, 12.0, 24.0, 48.0]) {
      final current = loss(value);
      if (current < bestLoss) {
        selected = value;
        bestLoss = current;
      }
    }
    _temperatures[context] = selected;
  }

  Experience33 learn(
    Features33 input, {
    required String label,
    String context = 'generale',
    String description = '',
    String source = 'Conferma utente',
    String? at,
  }) {
    if (label.trim().isEmpty ||
        label.length > 120 ||
        context.trim().isEmpty ||
        context.length > 100) {
      throw ArgumentError('Indica un nome breve e un contesto.');
    }
    if (description.length > 8000 || source.length > 300)
      throw ArgumentError('Descrizione troppo lunga.');
    if (_episodes.length >= capacity)
      throw StateError(
        'Memoria piena ($capacity episodi). Nessun ricordo è stato eliminato: esporta o elimina gli esempi che scegli tu.',
      );
    final x = validate(input), c = canonical33(context);
    final watch = Stopwatch()..start();
    final before = predict(x, context: c), target = canonical33(label);
    if (before.probabilities.isEmpty) {
      coldStarts++;
    } else {
      evaluated++;
      if (before.best == target) correct++;
      logLoss -= log(max(1e-12, before.probabilities[target] ?? 0));
      if (before.accepted) {
        answered++;
        if (before.best == target) answeredCorrect++;
      }
    }
    final e = Experience33(
      id: _nextId++,
      label: label,
      context: c,
      description: description,
      source: source,
      at: at ?? DateTime.now().toUtc().toIso8601String(),
      features: x,
    );
    _adapt(e);
    _episodes.add(e);
    _calibrate(c);
    revision++;
    lastLearnMicros = watch.elapsedMicroseconds;
    return e;
  }

  /// Rebuild from retained episodes: deleted observations leave no influence
  /// in this module's metric, replay set or predictive statistics.
  int deleteWhere(bool Function(Experience33) predicate) {
    final kept = _episodes.where((e) => !predicate(e)).toList();
    final count = _episodes.length - kept.length;
    if (count == 0) return 0;
    _episodes.clear();
    _weights.clear();
    _temperatures.clear();
    acceptedUpdates = 0;
    rejectedUpdates = 0;
    for (final e in kept) {
      _adapt(e);
      _episodes.add(e);
      _calibrate(e.context);
    }
    evaluated = 0;
    correct = 0;
    answered = 0;
    answeredCorrect = 0;
    coldStarts = 0;
    logLoss = 0;
    lastPredictMicros = 0;
    lastLearnMicros = 0;
    coordinatesVisited = 0;
    evaluationReset = true;
    revision++;
    return count;
  }

  int deleteConcept(String label, {String? context}) => deleteWhere(
        (e) =>
            canonical33(e.label) == canonical33(label) &&
            (context == null || e.context == canonical33(context)),
      );

  Map<String, dynamic> toJson() => {
        'schema': 1,
        'nextId': _nextId,
        'revision': revision,
        'episodes': _episodes.map((e) => e.toJson()).toList(),
        'weights': _weights,
        'temperatures': _temperatures,
        'acceptedUpdates': acceptedUpdates,
        'rejectedUpdates': rejectedUpdates,
        'evaluated': evaluated,
        'correct': correct,
        'answered': answered,
        'answeredCorrect': answeredCorrect,
        'coldStarts': coldStarts,
        'logLoss': logLoss,
        'evaluationReset': evaluationReset,
      };
  factory ExperienceMemory33.fromJson(Map<String, dynamic> j) {
    if (j['schema'] != 1)
      throw const FormatException(
        'Versione della memoria esperienziale non supportata.',
      );
    final m = ExperienceMemory33();
    for (final entry in (j['temperatures'] as Map? ?? {}).entries) {
      final value = (entry.value as num).toDouble();
      if (![6.0, 12.0, 24.0, 48.0].contains(value))
        throw const FormatException('Calibrazione non valida.');
      m._temperatures[entry.key.toString()] = value;
    }
    m._episodes.addAll(
      (j['episodes'] as List).map(
        (e) => Experience33.fromJson(Map<String, dynamic>.from(e as Map)),
      ),
    );
    if (m._episodes.length > capacity ||
        m._episodes.map((e) => e.id).toSet().length != m._episodes.length) {
      throw const FormatException('Memoria esperienziale non valida.');
    }
    for (final c in (j['weights'] as Map).entries) {
      final modalities = <String, Map<String, double>>{};
      for (final entry in (c.value as Map).entries) {
        final values = <String, double>{};
        for (final f in (entry.value as Map).entries) {
          final value = (f.value as num).toDouble();
          if (!value.isFinite || value < .05 || value > 8)
            throw const FormatException('Metrica non valida.');
          values[f.key.toString()] = value;
        }
        modalities[entry.key.toString()] = values;
      }
      m._weights[c.key.toString()] = modalities;
    }
    m._nextId = (j['nextId'] as num).toInt();
    if (m._episodes.any((e) => e.id >= m._nextId))
      throw const FormatException('Sequenza episodi non valida.');
    m.revision = (j['revision'] as num).toInt();
    m.acceptedUpdates = (j['acceptedUpdates'] as num).toInt();
    m.rejectedUpdates = (j['rejectedUpdates'] as num).toInt();
    m.evaluated = (j['evaluated'] as num).toInt();
    m.correct = (j['correct'] as num).toInt();
    m.answered = (j['answered'] as num).toInt();
    m.answeredCorrect = (j['answeredCorrect'] as num).toInt();
    m.coldStarts = (j['coldStarts'] as num).toInt();
    m.logLoss = (j['logLoss'] as num).toDouble();
    m.evaluationReset = j['evaluationReset'] == true;
    return m;
  }
  ExperienceMemory33();
}
