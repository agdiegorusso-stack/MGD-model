import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'plastic_language_brain_v04.dart';
import 'native_mgd_engine_v09.dart';

part 'curiosity_policy_v0316.dart';

class WorldEdge06 {
  final String a;
  final String b;
  double cost;
  double fast;
  double slow;
  double elig;
  double meta;
  int uses;
  int lastUsed;
  double curvature;
  bool curvatureMeasured320;

  WorldEdge06({
    required this.a,
    required this.b,
    this.cost = 1.08,
    this.fast = 0,
    this.slow = 0,
    this.elig = 0,
    this.meta = 0,
    this.uses = 0,
    this.lastUsed = 0,
    this.curvature = 0,
    this.curvatureMeasured320 = false,
  });

  Map<String, dynamic> toJson() => {
        'a': a,
        'b': b,
        'cost': cost,
        'fast': fast,
        'slow': slow,
        'elig': elig,
        'meta': meta,
        'uses': uses,
        'lastUsed': lastUsed,
        'curvature': curvature,
        'curvatureMeasured320': curvatureMeasured320,
      };

  factory WorldEdge06.fromJson(Map<String, dynamic> j) => WorldEdge06(
        a: j['a'] as String,
        b: j['b'] as String,
        cost: (j['cost'] as num?)?.toDouble() ?? 1.08,
        fast: (j['fast'] as num?)?.toDouble() ?? 0,
        slow: (j['slow'] as num?)?.toDouble() ?? 0,
        elig: (j['elig'] as num?)?.toDouble() ?? 0,
        meta: (j['meta'] as num?)?.toDouble() ?? 0,
        uses: (j['uses'] as num?)?.toInt() ?? 0,
        lastUsed: (j['lastUsed'] as num?)?.toInt() ?? 0,
        curvature: (j['curvature'] as num?)?.toDouble() ?? 0,
        curvatureMeasured320: j['curvatureMeasured320'] == true,
      );
}

class SensoryPrototype06 {
  final int id;
  final String modality;
  final Map<String, double> centroid;
  int observations;
  int lastSeen;
  double stability;
  int? semanticEntityId;
  String? label;

  SensoryPrototype06({
    required this.id,
    required this.modality,
    Map<String, double>? centroid,
    this.observations = 0,
    this.lastSeen = 0,
    this.stability = 0,
    this.semanticEntityId,
    this.label,
  }) : centroid = centroid ?? <String, double>{};

  Map<String, dynamic> toJson() => {
        'id': id,
        'modality': modality,
        'centroid': centroid,
        'observations': observations,
        'lastSeen': lastSeen,
        'stability': stability,
        'semanticEntityId': semanticEntityId,
        'label': label,
      };

  factory SensoryPrototype06.fromJson(Map<String, dynamic> j) =>
      SensoryPrototype06(
        id: (j['id'] as num).toInt(),
        modality: j['modality'] as String,
        centroid: Map<String, double>.from(
          (j['centroid'] as Map?)?.map(
                  (k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
              const {},
        ),
        observations: (j['observations'] as num?)?.toInt() ?? 0,
        lastSeen: (j['lastSeen'] as num?)?.toInt() ?? 0,
        stability: (j['stability'] as num?)?.toDouble() ?? 0,
        semanticEntityId: (j['semanticEntityId'] as num?)?.toInt(),
        label: j['label'] as String?,
      );
}

class SensoryObservation06 {
  final int id;
  final String modality;
  final int prototypeId;
  final double similarity;
  final double novelty;
  final double predictionError;
  final int step;

  const SensoryObservation06({
    required this.id,
    required this.modality,
    required this.prototypeId,
    required this.similarity,
    required this.novelty,
    required this.predictionError,
    required this.step,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'modality': modality,
        'prototypeId': prototypeId,
        'similarity': similarity,
        'novelty': novelty,
        'predictionError': predictionError,
        'step': step,
      };

  factory SensoryObservation06.fromJson(Map<String, dynamic> j) =>
      SensoryObservation06(
        id: (j['id'] as num).toInt(),
        modality: j['modality'] as String,
        prototypeId: (j['prototypeId'] as num).toInt(),
        similarity: (j['similarity'] as num).toDouble(),
        novelty: (j['novelty'] as num).toDouble(),
        predictionError: (j['predictionError'] as num).toDouble(),
        step: (j['step'] as num).toInt(),
      );
}

class SensoryResult06 {
  final SensoryObservation06 observation;
  final SensoryPrototype06 prototype;
  final bool created;
  final String summary;

  const SensoryResult06({
    required this.observation,
    required this.prototype,
    required this.created,
    required this.summary,
  });
}

class ThoughtStep06 {
  final int cycle;
  final List<String> focus;
  final String hypothesis;
  final double coherence;

  const ThoughtStep06({
    required this.cycle,
    required this.focus,
    required this.hypothesis,
    required this.coherence,
  });

  Map<String, dynamic> toJson() => {
        'cycle': cycle,
        'focus': focus,
        'hypothesis': hypothesis,
        'coherence': coherence,
      };

  factory ThoughtStep06.fromJson(Map<String, dynamic> j) => ThoughtStep06(
        cycle: (j['cycle'] as num).toInt(),
        focus: ((j['focus'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        hypothesis: j['hypothesis'] as String? ?? '',
        coherence: (j['coherence'] as num?)?.toDouble() ?? 0,
      );
}

class MgdWorldStats06 {
  final int visualPatterns;
  final int auditoryPatterns;
  final int worldEdges;
  final int semanticBindings;
  final int thoughtCycles;
  final double novelty;
  final double predictionError;
  final double curiosity;
  final double entropicAge;
  final double meanSlow;
  final int activeEdges;
  final int preActiveEdges030;
  final double meanCurvature;
  final double entropicFlux;
  final bool curiosityPending;

  const MgdWorldStats06({
    required this.visualPatterns,
    required this.auditoryPatterns,
    required this.worldEdges,
    required this.semanticBindings,
    required this.thoughtCycles,
    required this.novelty,
    required this.predictionError,
    required this.curiosity,
    required this.entropicAge,
    required this.meanSlow,
    required this.activeEdges,
    required this.preActiveEdges030,
    required this.meanCurvature,
    required this.entropicFlux,
    required this.curiosityPending,
  });
}

class MgdWorld06 {
  MgdWorld06();

  static const int version = 1;
  static const int maxObservations = 160;
  static const int maxThoughts = 120;

  final List<SensoryPrototype06> prototypes = [];
  final Map<String, WorldEdge06> edges = {};
  final List<SensoryObservation06> observations = [];
  final List<ThoughtStep06> thoughts = [];

  final Map<String, dynamic> runtime319 = {};
  int step = 0;
  int nextObservationId = 1;
  int thoughtCycles = 0;
  double noveltyEma = 0;
  double predictionErrorEma = 0;
  double curiosity = 0;
  double entropicAge = 0;
  double lastEntropicFlux09 = 0;
  SensoryObservation06? lastObservation;
  String? pendingCuriosityType09;
  String? pendingCuriosityQuestion09;
  int? pendingCuriosityPrototype09;
  List<int> pendingCuriosityEntities09 = <int>[];
  int curiosityCooldown09 = 0;
  int? lastLanguageEntity09;
  int? currentUserEntityId091;
  final Set<String> askedCuriosity09 = <String>{};
  final Map<String, double> hypothesisFatigue011 = <String, double>{};
  int lastThinkVisitedEdges16 = 0;
  int lastThinkVisitedFacts16 = 0;
  int lastThinkPeakActiveNodes16 = 0;
  int lastThinkMicros16 = 0;
  final Set<String> _curvatureDirty18 = <String>{};

  String _pNode(int id) => 'p:$id';
  String _eNode(int id) => 'e:$id';

  String _edgeKey(String a, String b) =>
      a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

  WorldEdge06 _edge(String a, String b) {
    final key = _edgeKey(a, b);
    return edges.putIfAbsent(key, () => WorldEdge06(a: a, b: b));
  }

  double _strength(WorldEdge06 e) {
    return MgdMath09.strength(
      weight: e.cost,
      memory: e.fast,
      material: e.slow,
    );
  }

  Map<String, Map<String, double>> _activeAdjacency09() {
    final out = <String, Map<String, double>>{};
    for (final e in edges.values) {
      if (e.cost > MgdMath09.defaults.epsilon) continue;
      out.putIfAbsent(e.a, () => <String, double>{})[e.b] = e.cost;
      out.putIfAbsent(e.b, () => <String, double>{})[e.a] = e.cost;
    }
    return out;
  }

  void _updateCurvature09(
    WorldEdge06 e, {
    Map<String, Map<String, double>>? adjacency,
  }) {
    if (e.cost > MgdMath09.defaults.epsilon) {
      e.curvature = 0;
      e.curvatureMeasured320 = false;
      return;
    }
    final graph = adjacency ?? _activeAdjacency09();
    e.curvatureMeasured320 = true;
    e.curvature = MgdMath09.ollivierRicci(
      a: e.a,
      b: e.b,
      edgeWeight: e.cost,
      activeAdjacency: graph,
    );
  }

  void _refreshCurvature18(int budget) {
    if (budget <= 0 || _curvatureDirty18.isEmpty) return;
    // Build the active graph once for the whole batch, not once per edge.
    final adjacency = _activeAdjacency09();
    final keys = _curvatureDirty18.take(budget).toList(growable: false);
    for (final key in keys) {
      final e = edges[key];
      if (e != null) _updateCurvature09(e, adjacency: adjacency);
      _curvatureDirty18.remove(key);
    }
  }

  void _plasticUpdate(WorldEdge06 e,
      {required double reward, double coactivity = 1.0}) {
    final oldMaterial = e.slow;
    e.curvatureMeasured320 = false;
    e.elig = (0.84 * e.elig + 0.24 * coactivity).clamp(0.0, 1.0).toDouble();
    final evolved = MgdMath09.evolve(
      weight: e.cost,
      memory: e.fast,
      material: e.slow,
      coherenceAverage: e.meta,
      activation: coactivity.clamp(0.0, 1.0).toDouble(),
      reward: reward.clamp(-1.0, 1.0).toDouble(),
    );
    e.cost = evolved.weight;
    e.fast = evolved.memory;
    e.slow = evolved.material;
    e.meta = evolved.coherenceAverage;
    e.uses++;
    e.lastUsed = step;
    lastEntropicFlux09 = evolved.informationalFlux;
    entropicAge += evolved.informationalFlux;
    if (e.uses % 3 == 0 || evolved.active) {
      _curvatureDirty18.add(_edgeKey(e.a, e.b));
    }
  }

  double _cosine(Map<String, double> a, Map<String, double> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    var dot = 0.0;
    var aa = 0.0;
    var bb = 0.0;
    final keys = {...a.keys, ...b.keys};
    for (final k in keys) {
      final x = a[k] ?? 0;
      final y = b[k] ?? 0;
      dot += x * y;
      aa += x * x;
      bb += y * y;
    }
    if (aa <= 1e-12 || bb <= 1e-12) return 0;
    return (dot / sqrt(aa * bb)).clamp(0.0, 1.0);
  }

  void _transferSemanticBinding07(
    SensoryPrototype06 target,
    Map<String, double> features,
  ) {
    if (target.semanticEntityId != null) return;
    SensoryPrototype06? best;
    var bestSimilarity = 0.0;
    for (final p in prototypes) {
      if (p.id == target.id ||
          p.modality != target.modality ||
          p.semanticEntityId == null) {
        continue;
      }
      final sim = _cosine(features, p.centroid);
      if (sim > bestSimilarity) {
        bestSimilarity = sim;
        best = p;
      }
    }
    final threshold = target.modality == 'vision' ? 0.80 : 0.84;
    if (best == null || bestSimilarity < threshold) return;
    target.semanticEntityId = best.semanticEntityId;
    target.label = best.label;
    target.stability = max(target.stability, 0.18 + 0.35 * bestSimilarity);
    final e = _edge(_pNode(target.id), _eNode(target.semanticEntityId!));
    _plasticUpdate(e,
        reward: 0.48 + 0.35 * bestSimilarity, coactivity: bestSimilarity);
  }

  Set<int> _identityClosure07(PlasticLanguageBrain04 brain, int seed) {
    final found = <int>{seed};
    var changed = true;
    var rounds = 0;
    final facts = brain.cognitiveFacts06();
    while (changed && rounds++ < 4) {
      changed = false;
      for (final f in facts) {
        final rel = PlasticLanguageBrain04.normalizeText(f.relation);
        final identityLike = rel.contains('ident') ||
            rel.contains('nom') ||
            rel.contains('chiam');
        if (!identityLike || f.objectEntityId == null) continue;
        if (found.contains(f.subjectId) && found.add(f.objectEntityId!)) {
          changed = true;
        }
        if (found.contains(f.objectEntityId!) && found.add(f.subjectId)) {
          changed = true;
        }
      }
    }
    return found;
  }

  int? _mentionedEntity07(PlasticLanguageBrain04 brain, String prompt) {
    final n = PlasticLanguageBrain04.normalizeText(prompt);
    final candidates = brain.entities.toList()
      ..sort((a, b) => b.label.length.compareTo(a.label.length));
    for (final e in candidates) {
      final label = PlasticLanguageBrain04.normalizeText(e.label);
      if (label.length < 2) continue;
      if (RegExp(
              '(^|[^a-zà-ÿ0-9])' + RegExp.escape(label) + r'([^a-zà-ÿ0-9]|$)')
          .hasMatch(n)) {
        return e.id;
      }
    }
    return null;
  }

  List<SensoryPrototype06> sensoryForEntity07(
    PlasticLanguageBrain04 brain,
    int entityId, {
    String? modality,
  }) {
    final closure = _identityClosure07(brain, entityId);
    if (entityId == brain.userId && currentUserEntityId091 != null) {
      closure.add(currentUserEntityId091!);
    }
    if (currentUserEntityId091 != null && entityId == currentUserEntityId091) {
      closure.add(brain.userId);
    }
    return prototypes.where((p) {
      if (p.semanticEntityId == null || !closure.contains(p.semanticEntityId)) {
        return false;
      }
      return modality == null || p.modality == modality;
    }).toList();
  }

  String? groundedAnswer07(PlasticLanguageBrain04 brain, String prompt) {
    repairIdentityAliases081(brain);
    final n = PlasticLanguageBrain04.normalizeText(prompt);
    final words = PlasticLanguageBrain04.lexicalTokens(n).toSet();
    final asksSeen =
        n.contains('vist') || n.contains('vedut') || n.contains('riconosc');
    final asksHeard =
        n.contains('sentit') || n.contains('ascoltat') || n.contains('voce');
    final selfReference = words.any({'mi', 'me', 'io', 'mio', 'mia'}.contains);

    final asksSelfIdentity = selfReference &&
        (words.contains('chi') ||
            n.contains('come mi chiam') ||
            n.contains('come sono chiam'));
    if (asksSelfIdentity) {
      final identity = _identityObject071(brain, brain.userId);
      if (identity != null && identity < brain.entities.length) {
        return brain.entities[identity].label + '.';
      }

      // A visual/audio binding may already identify the user even if the
      // language fact has not yet been explicitly queried.
      final closure = _identityClosure07(brain, brain.userId);
      for (final p in prototypes.reversed) {
        if (p.semanticEntityId != null &&
            closure.contains(p.semanticEntityId!) &&
            p.label != null &&
            p.label!.trim().isNotEmpty) {
          return p.label!.trim() + '.';
        }
      }
    }

    if (selfReference && asksSeen) {
      final memories =
          sensoryForEntity07(brain, brain.userId, modality: 'vision');
      if (memories.isEmpty) {
        return 'Non ho ancora un ricordo visivo associato a te.';
      }
      final labels = memories
          .map((p) => p.label)
          .whereType<String>()
          .where((x) => x.trim().isNotEmpty)
          .toSet();
      final who = labels.isEmpty ? 'te' : labels.first;
      return 'Sì. Ho già un ricordo visivo associato a $who (${memories.length} pattern).';
    }

    if (selfReference && asksHeard) {
      final memories =
          sensoryForEntity07(brain, brain.userId, modality: 'audio');
      if (memories.isEmpty) {
        return 'Non ho ancora un ricordo uditivo associato a te.';
      }
      return 'Sì. Ho già ${memories.length} pattern uditivi associati a te.';
    }

    final entityId = _mentionedEntity07(brain, prompt);
    if (entityId == null) return null;
    final entity = brain.entities[entityId];
    final asksWho = words.contains('chi') ||
        n.contains('sai chi') ||
        n.contains('cosa sai') ||
        n.contains('che sai');
    if (!asksWho) return null;

    final facts = brain.cognitiveFacts06();
    final incoming = facts.where((f) => f.objectEntityId == entityId).toList();
    final outgoing = facts.where((f) => f.subjectId == entityId).toList();
    final sensory = sensoryForEntity07(brain, entityId);

    for (final f in incoming) {
      final rel = PlasticLanguageBrain04.normalizeText(f.relation);
      if (rel.contains('ident') ||
          rel.contains('nom') ||
          rel.contains('chiam')) {
        if (f.subjectId == brain.userId) return '${entity.label} sei tu.';
        if (f.subjectId == brain.selfId) return '${entity.label} sono io.';
      }
    }

    final pieces = <String>[];
    for (final f in outgoing.take(3)) {
      pieces.add('${entity.label} —${f.relation}→ ${f.object}');
    }
    for (final f in incoming.take(3)) {
      final subject = f.subjectId < brain.entities.length
          ? brain.entities[f.subjectId].label
          : 'entità ${f.subjectId}';
      pieces.add('$subject —${f.relation}→ ${entity.label}');
    }
    if (sensory.isNotEmpty) {
      final v = sensory.where((p) => p.modality == 'vision').length;
      final a = sensory.where((p) => p.modality == 'audio').length;
      pieces.add('ricordi sensoriali: $v visivi, $a uditivi');
    }
    if (pieces.isEmpty) return null;
    return pieces.join('. ') + '.';
  }

  SensoryResult06 _observe(String modality, Map<String, double> features) {
    step++;
    SensoryPrototype06? best;
    var bestSimilarity = 0.0;
    for (final p in prototypes) {
      if (p.modality != modality) continue;
      final sim = _cosine(features, p.centroid);
      if (sim > bestSimilarity) {
        bestSimilarity = sim;
        best = p;
      }
    }

    final threshold = modality == 'vision' ? 0.91 : 0.88;
    final created = best == null || bestSimilarity < threshold;
    late SensoryPrototype06 prototype;
    if (created) {
      prototype = SensoryPrototype06(
        id: prototypes.length,
        modality: modality,
        centroid: Map<String, double>.from(features),
        observations: 1,
        lastSeen: step,
        stability: 0.10,
      );
      prototypes.add(prototype);
      bestSimilarity = 0;
    } else {
      prototype = best!;
      final eta =
          (0.20 / sqrt(max(1, prototype.observations))).clamp(0.035, 0.20);
      final keys = {...prototype.centroid.keys, ...features.keys};
      for (final k in keys) {
        final old = prototype.centroid[k] ?? 0;
        prototype.centroid[k] = old + eta * ((features[k] ?? 0) - old);
      }
      prototype.observations++;
      prototype.lastSeen = step;
      prototype.stability =
          (prototype.stability + 0.06 * (1 - prototype.stability))
              .clamp(0.0, 1.0);
    }

    _transferSemanticBinding07(prototype, features);

    final novelty = created ? 1.0 : (1 - bestSimilarity).clamp(0.0, 1.0);
    final previous = lastObservation;
    var contextualPrediction = created ? 0.0 : bestSimilarity * 0.55;
    if (previous != null && previous.prototypeId != prototype.id) {
      final k = _edgeKey(_pNode(previous.prototypeId), _pNode(prototype.id));
      final transition = edges[k];
      if (transition != null) {
        contextualPrediction = max(contextualPrediction, _strength(transition));
      }
    }
    final error = (1.0 - contextualPrediction).clamp(0.0, 1.0);
    noveltyEma = 0.82 * noveltyEma + 0.18 * novelty;
    predictionErrorEma = 0.82 * predictionErrorEma + 0.18 * error;
    final unknown =
        prototype.label == null || prototype.label!.trim().isEmpty ? 1.0 : 0.30;
    final relevance = (prototype.observations / 6.0).clamp(0.0, 1.0);
    final stability = max(0.10, prototype.stability);
    final localCuriosity = MgdMath09.curiosityScore(
      novelty: max(unknown, noveltyEma),
      uncertainty: max(0.25, predictionErrorEma),
      relevance: max(0.25, relevance),
      stability: stability,
    );
    curiosity = (0.72 * curiosity + 0.28 * localCuriosity).clamp(0.0, 1.0);

    final obs = SensoryObservation06(
      id: nextObservationId++,
      modality: modality,
      prototypeId: prototype.id,
      similarity: bestSimilarity,
      novelty: novelty,
      predictionError: error,
      step: step,
    );
    observations.add(obs);
    if (observations.length > maxObservations) observations.removeAt(0);
    lastObservation = obs;

    if (previous != null && previous.prototypeId != prototype.id) {
      final prevP = prototypes[previous.prototypeId];
      final dt = step - previous.step;
      if (dt <= 3) {
        final e = _edge(_pNode(prevP.id), _pNode(prototype.id));
        _plasticUpdate(e,
            reward: prevP.modality == modality ? 0.28 : 0.55, coactivity: 1.0);
      }
    }

    final label = prototype.label;
    final summary = label != null && label.trim().isNotEmpty
        ? '${modality == 'vision' ? 'Vedo' : 'Sento'} qualcosa che assomiglia a $label (${(bestSimilarity * 100).round()}%).'
        : created
            ? 'Nuovo pattern ${modality == 'vision' ? 'visivo' : 'uditivo'} #${prototype.id}.'
            : 'Pattern ${modality == 'vision' ? 'visivo' : 'uditivo'} #${prototype.id}, similarità ${(bestSimilarity * 100).round()}%.';
    return SensoryResult06(
        observation: obs,
        prototype: prototype,
        created: created,
        summary: summary);
  }

  SensoryResult06 observeVisionBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw StateError('Immagine non decodificabile.');
    final resized = img.copyResize(decoded,
        width: 48, height: 48, interpolation: img.Interpolation.average);
    return _observe('vision', _visionFeatures(resized));
  }

  SensoryResult06 observeAudioPcm(Uint8List bytes, {int sampleRate = 16000}) {
    if (bytes.length < 800) throw StateError('Registrazione troppo breve.');
    final bd = ByteData.sublistView(bytes);
    final n = bytes.length ~/ 2;
    final samples = Float64List(n);
    for (var i = 0; i < n; i++) {
      samples[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return _observe('audio', _audioFeatures(samples, sampleRate));
  }

  Map<String, double> _visionFeatures(img.Image image) {
    final out = <String, double>{};
    final gray =
        List.generate(image.height, (_) => List<double>.filled(image.width, 0));
    var sr = 0.0, sg = 0.0, sb = 0.0, sy = 0.0, sy2 = 0.0, ss = 0.0;
    final hue = List<double>.filled(8, 0);
    final grid = List<double>.filled(9, 0);
    final gridN = List<int>.filled(9, 0);
    final count = image.width * image.height;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = p.r.toDouble() / 255.0;
        final g = p.g.toDouble() / 255.0;
        final b = p.b.toDouble() / 255.0;
        final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b).clamp(0.0, 1.0);
        gray[y][x] = lum;
        sr += r;
        sg += g;
        sb += b;
        sy += lum;
        sy2 += lum * lum;
        final mx = max(r, max(g, b));
        final mn = min(r, min(g, b));
        final d = mx - mn;
        final sat = mx <= 1e-9 ? 0.0 : d / mx;
        ss += sat;
        var h = 0.0;
        if (d > 1e-9) {
          if (mx == r) {
            h = ((g - b) / d) % 6;
          } else if (mx == g) {
            h = (b - r) / d + 2;
          } else {
            h = (r - g) / d + 4;
          }
          h /= 6;
          if (h < 0) h += 1;
        }
        hue[min(7, (h * 8).floor())] += sat * (0.25 + 0.75 * mx);
        final gx = min(2, x * 3 ~/ image.width);
        final gy = min(2, y * 3 ~/ image.height);
        final gi = gy * 3 + gx;
        grid[gi] += lum;
        gridN[gi]++;
      }
    }

    final mean = sy / count;
    out['v:rgb:r'] = sr / count;
    out['v:rgb:g'] = sg / count;
    out['v:rgb:b'] = sb / count;
    out['v:lum:mean'] = mean;
    out['v:lum:std'] = sqrt(max(0, sy2 / count - mean * mean)).clamp(0.0, 1.0);
    out['v:sat'] = ss / count;
    final hueSum = hue.fold<double>(0, (a, b) => a + b) + 1e-9;
    for (var i = 0; i < hue.length; i++) out['v:hue:$i'] = hue[i] / hueSum;
    for (var i = 0; i < grid.length; i++)
      out['v:grid:$i'] = grid[i] / max(1, gridN[i]);

    final orient = List<double>.filled(8, 0);
    var edgeSum = 0.0;
    for (var y = 1; y < image.height - 1; y++) {
      for (var x = 1; x < image.width - 1; x++) {
        final dx = gray[y][x + 1] - gray[y][x - 1];
        final dy = gray[y + 1][x] - gray[y - 1][x];
        final mag = sqrt(dx * dx + dy * dy);
        if (mag < 0.025) continue;
        var angle = atan2(dy, dx);
        if (angle < 0) angle += pi;
        if (angle >= pi) angle -= pi;
        final bin = min(7, (angle / pi * 8).floor());
        orient[bin] += mag;
        edgeSum += mag;
      }
    }
    final denom = edgeSum + 1e-9;
    out['v:edge:density'] = (edgeSum / (count * 0.55)).clamp(0.0, 1.0);
    for (var i = 0; i < orient.length; i++)
      out['v:edge:$i'] = orient[i] / denom;
    return out;
  }

  Map<String, double> _audioFeatures(Float64List s, int sampleRate) {
    final out = <String, double>{};
    var energy = 0.0;
    var zc = 0;
    for (var i = 0; i < s.length; i++) {
      energy += s[i] * s[i];
      if (i > 0 && ((s[i] >= 0) != (s[i - 1] >= 0))) zc++;
    }
    final rms = sqrt(energy / max(1, s.length));
    out['a:rms'] = (rms * 4).clamp(0.0, 1.0);
    out['a:zcr'] = (zc / max(1, s.length - 1) * 12).clamp(0.0, 1.0);

    const freqs = <double>[125, 250, 500, 750, 1000, 1500, 2500, 4000];
    final powers = <double>[];
    for (final f in freqs) powers.add(_goertzel(s, sampleRate, f));
    final powerSum = powers.fold<double>(0, (a, b) => a + b) + 1e-12;
    var centroid = 0.0;
    for (var i = 0; i < freqs.length; i++) {
      final v = powers[i] / powerSum;
      out['a:band:$i'] = v;
      centroid += freqs[i] * v;
    }
    out['a:centroid'] = (centroid / 4000).clamp(0.0, 1.0);

    const segments = 8;
    for (var k = 0; k < segments; k++) {
      final a = k * s.length ~/ segments;
      final b = (k + 1) * s.length ~/ segments;
      var e = 0.0;
      for (var i = a; i < b; i++) e += s[i] * s[i];
      final local = sqrt(e / max(1, b - a));
      out['a:env:$k'] = (local * 4).clamp(0.0, 1.0);
    }

    final pitch = _estimatePitch(s, sampleRate);
    out['a:pitch'] = pitch == null ? 0 : ((pitch - 70) / 330).clamp(0.0, 1.0);
    out['a:voiced'] = pitch == null ? 0 : 1;
    return out;
  }

  double _goertzel(Float64List s, int sampleRate, double frequency) {
    final n = min(s.length, sampleRate * 2);
    final omega = 2 * pi * frequency / sampleRate;
    final coeff = 2 * cos(omega);
    var q0 = 0.0, q1 = 0.0, q2 = 0.0;
    final stride = max(1, n ~/ 8000);
    var used = 0;
    for (var i = 0; i < n; i += stride) {
      q0 = coeff * q1 - q2 + s[i];
      q2 = q1;
      q1 = q0;
      used++;
    }
    return max(0, q1 * q1 + q2 * q2 - coeff * q1 * q2) / max(1, used);
  }

  double? _estimatePitch(Float64List s, int sampleRate) {
    final n = min(s.length, 6000);
    if (n < 1000) return null;
    final minLag = sampleRate ~/ 400;
    final maxLag = min(sampleRate ~/ 70, n ~/ 3);
    var bestLag = 0;
    var best = 0.0;
    var zero = 0.0;
    for (var i = 0; i < n; i += 2) zero += s[i] * s[i];
    if (zero < 1e-4) return null;
    for (var lag = minLag; lag <= maxLag; lag += 2) {
      var c = 0.0;
      for (var i = 0; i < n - lag; i += 2) c += s[i] * s[i + lag];
      if (c > best) {
        best = c;
        bestLag = lag;
      }
    }
    if (bestLag == 0 || best / zero < 0.18) return null;
    return sampleRate / bestLag;
  }

  bool _identityRelation071(String relation) {
    final n = PlasticLanguageBrain04.normalizeText(relation);
    return n.contains('ident') || n.contains('nom') || n.contains('chiam');
  }

  int? _identityObject071(PlasticLanguageBrain04 brain, int subjectId) {
    for (final f in brain.cognitiveFacts06()) {
      if (f.subjectId == subjectId &&
          f.objectEntityId != null &&
          _identityRelation071(f.relation)) {
        return f.objectEntityId;
      }
    }
    return null;
  }

  bool _matchesUserIdentityAlias081(
    PlasticLanguageBrain04 brain,
    String? raw,
    int identityId,
  ) {
    if (raw == null || raw.trim().isEmpty) return false;
    if (identityId < 0 || identityId >= brain.entities.length) return false;

    final candidate = PlasticLanguageBrain04.normalizeText(raw);
    final canonical = PlasticLanguageBrain04.normalizeText(
      brain.entities[identityId].label,
    );
    if (candidate.isEmpty || canonical.isEmpty) return false;
    if (candidate == canonical) return true;

    // Deliberately conservative: these are representation words, not a fuzzy
    // contains() match. "Persona Diego" / "volto Diego" collapse to Diego,
    // while an unrelated name containing the same token does not.
    const wrappers = {
      'persona',
      'person',
      'volto',
      'viso',
      'faccia',
      'face',
      'utente',
      'user',
      'ritratto',
      'portrait'
    };
    for (final wrapper in wrappers) {
      if (candidate == '$wrapper $canonical') return true;
      if (candidate == '$canonical $wrapper') return true;
    }
    return false;
  }

  int repairIdentityAliases081(PlasticLanguageBrain04 brain) {
    final identity = _identityObject071(brain, brain.userId);
    if (identity == null || identity < 0 || identity >= brain.entities.length) {
      return 0;
    }

    currentUserEntityId091 = identity;
    final canonical = brain.entities[identity];
    var repaired = 0;
    for (final p in prototypes) {
      String? semanticLabel;
      final sid = p.semanticEntityId;
      if (sid != null && sid >= 0 && sid < brain.entities.length) {
        semanticLabel = brain.entities[sid].label;
      }

      final isUserNode = sid == brain.userId;
      final aliasByPattern =
          _matchesUserIdentityAlias081(brain, p.label, identity);
      final aliasByEntity = _matchesUserIdentityAlias081(
        brain,
        semanticLabel,
        identity,
      );
      if (!isUserNode && !aliasByPattern && !aliasByEntity) continue;

      final oldLabel = p.label?.trim();
      if (oldLabel != null && oldLabel.isNotEmpty) {
        canonical.aliases.add(PlasticLanguageBrain04.normalizeText(oldLabel));
      }
      if (semanticLabel != null && semanticLabel.trim().isNotEmpty) {
        canonical.aliases.add(
          PlasticLanguageBrain04.normalizeText(semanticLabel),
        );
      }

      final changed = p.semanticEntityId != identity ||
          PlasticLanguageBrain04.normalizeText(p.label ?? '') !=
              PlasticLanguageBrain04.normalizeText(canonical.label);
      if (!changed) continue;

      p.semanticEntityId = identity;
      p.label = canonical.label;
      p.stability = max(p.stability, 0.55);
      final e = _edge(_pNode(p.id), _eNode(identity));
      _plasticUpdate(e, reward: 1.0, coactivity: 1.0);
      repaired++;
    }
    return repaired;
  }

  ({int entityId, String label, bool identityAssertion})
      _resolveNaturalBinding071(
    PlasticLanguageBrain04 brain,
    String raw,
  ) {
    final original = raw.trim();
    final surfaces = PlasticLanguageBrain04.lexicalTokens(original);
    final ns = surfaces.map(PlasticLanguageBrain04.normalizeText).toList();
    final words = ns.toSet();

    final knownIdentity081 = _identityObject071(brain, brain.userId);
    if (knownIdentity081 != null &&
        _matchesUserIdentityAlias081(brain, original, knownIdentity081)) {
      final canonical = brain.entities[knownIdentity081];
      canonical.aliases.add(PlasticLanguageBrain04.normalizeText(original));
      return (
        entityId: knownIdentity081,
        label: canonical.label,
        identityAssertion: true,
      );
    }

    const firstPerson = {'io', 'mi', 'me', 'mio', 'mia', 'miei', 'mie'};
    const copulas = {
      'sono',
      'sei',
      'è',
      'e',
      'siamo',
      'siete',
      'era',
      'sara',
      'sarà'
    };
    const demonstratives = {
      'questo',
      'questa',
      'questi',
      'queste',
      'qui',
      'foto',
      'immagine'
    };
    const removable = {
      'io',
      'mi',
      'me',
      'mio',
      'mia',
      'miei',
      'mie',
      'sono',
      'sei',
      'è',
      'e',
      'siamo',
      'siete',
      'era',
      'sara',
      'sarà',
      'questo',
      'questa',
      'questi',
      'queste',
      'qui',
      'foto',
      'immagine',
      'un',
      'uno',
      'una',
      'il',
      'lo',
      'la',
      'i',
      'gli',
      'le',
      'chiamo',
      'chiama',
      'chiamato',
      'chiamata',
      'nome'
    };

    final hasSelf = words.any(firstPerson.contains);
    final hasCopula = words.any(copulas.contains);
    final startsAsSelfAssertion =
        ns.isNotEmpty && {'sono', 'io'}.contains(ns.first);
    final selfAssertion = hasSelf && hasCopula || startsAsSelfAssertion;

    String candidateFromRemainder() {
      final kept = <String>[];
      for (var i = 0; i < surfaces.length; i++) {
        if (removable.contains(ns[i])) continue;
        kept.add(surfaces[i]);
      }
      return kept.join(' ').trim();
    }

    if (selfAssertion) {
      final candidate = candidateFromRemainder();
      if (candidate.isNotEmpty) {
        // Ground the sensory statement into the same USER --identity--> entity
        // used by language. "Sono io Diego" therefore teaches identity and
        // binds the visual pattern to Diego, not to an entity literally named
        // "sono io Diego".
        brain.learnEvent('Mi chiamo $candidate.', reward: 1.0);
        final id = brain.resolveSenseEntity028(candidate, context: original) ??
            brain.entityIdForLabel06(candidate) ??
            brain.ensureSemanticEntity06(candidate);
        return (
          entityId: id,
          label: brain.entities[id].label,
          identityAssertion: true,
        );
      }

      final existing = _identityObject071(brain, brain.userId);
      final id = existing ?? brain.userId;
      return (
        entityId: id,
        label: brain.entities[id].label,
        identityAssertion: true,
      );
    }

    // Natural object labels such as "questo è un cane" are grounded to
    // "cane" rather than stored as a sentence-shaped entity.
    final looksLikeDemonstrativeLabel =
        words.any(demonstratives.contains) && hasCopula;
    final startsWithCopula = ns.isNotEmpty && copulas.contains(ns.first);
    if (looksLikeDemonstrativeLabel || startsWithCopula) {
      final candidate = candidateFromRemainder();
      if (candidate.isNotEmpty) {
        final id = brain.entityIdForLabel06(candidate) ??
            brain.ensureSemanticEntity06(candidate);
        brain.learnSurface(candidate, reward: 0.25);
        return (
          entityId: id,
          label: brain.entities[id].label,
          identityAssertion: false,
        );
      }
    }

    final id = brain.resolveSenseEntity028(original, context: original) ??
        brain.entityIdForLabel06(original) ??
        brain.ensureSemanticEntity06(original);
    brain.learnSurface(original, reward: 0.25);
    return (
      entityId: id,
      label: brain.entities[id].label,
      identityAssertion: false,
    );
  }

  String bindLastNatural071(
    PlasticLanguageBrain04 brain,
    String raw,
  ) {
    final resolved = _resolveNaturalBinding071(brain, raw);
    bindLast(label: resolved.label, entityId: resolved.entityId);
    if (resolved.identityAssertion) {
      currentUserEntityId091 = resolved.entityId;
    }
    return resolved.label;
  }

  String? bindLastFromUtterance091(
    PlasticLanguageBrain04 brain,
    String raw,
  ) {
    if (lastObservation == null) return null;
    final original = raw.trim();
    if (original.isEmpty || original.contains('?')) return null;

    final tokens = PlasticLanguageBrain04.lexicalTokens(original);
    final ns = tokens.map(PlasticLanguageBrain04.normalizeText).toList();
    final words = ns.toSet();
    const firstPerson = {'io', 'mi', 'me'};
    const copulas = {'sono', 'sei', 'è', 'e', 'era', 'sarà', 'sara'};
    const deictics = {
      'questo',
      'questa',
      'questi',
      'queste',
      'foto',
      'immagine',
      'qui'
    };

    final hasSelf = words.any(firstPerson.contains);
    final hasCopula = words.any(copulas.contains);
    final hasDeictic = words.any(deictics.contains);
    final explicitSelf = hasSelf && hasCopula;
    final explicitObject = hasDeictic && hasCopula;

    if (!explicitSelf && !explicitObject) return null;
    return bindLastNatural071(brain, original);
  }

  int repairCurrentUserFromHistory091(PlasticLanguageBrain04 brain) {
    var changed = 0;

    final identity = _identityObject071(brain, brain.userId);
    if (identity != null && identity >= 0 && identity < brain.entities.length) {
      if (currentUserEntityId091 != identity) {
        currentUserEntityId091 = identity;
        changed++;
      }
      for (final p in prototypes) {
        final label = p.label?.trim();
        if (label == null || label.isEmpty) continue;
        if (_matchesUserIdentityAlias081(brain, label, identity) ||
            p.semanticEntityId == brain.userId) {
          if (p.semanticEntityId != identity ||
              PlasticLanguageBrain04.normalizeText(label) !=
                  PlasticLanguageBrain04.normalizeText(
                    brain.entities[identity].label,
                  )) {
            p.semanticEntityId = identity;
            p.label = brain.entities[identity].label;
            changed++;
          }
        }
      }
      return changed;
    }

    if (currentUserEntityId091 != null &&
        currentUserEntityId091! >= 0 &&
        currentUserEntityId091! < brain.entities.length) {
      return changed;
    }

    // Recover the exact phone scenario from existing 0.9 data:
    // a visual prototype was named "Diego", while the user had said in chat
    // "questo sono io Diego".  Match an explicit self assertion in episodic
    // language to an already labelled visual prototype; never infer identity
    // from a visual label alone.
    for (final p in prototypes.where((x) => x.modality == 'vision')) {
      final label = p.label?.trim();
      if (label == null || label.isEmpty) continue;
      final nl = PlasticLanguageBrain04.normalizeText(label);
      for (final ep in brain.episodes.reversed) {
        final text = PlasticLanguageBrain04.normalizeText(ep.userText);
        final explicitSelf = text.contains('sono io') ||
            text.startsWith('io sono ') ||
            text.contains('questo sono io') ||
            text.contains('questa sono io');
        if (!explicitSelf || !text.contains(nl)) continue;

        brain.learnEvent('Mi chiamo $label.', reward: 1.0);
        final id = brain.entityIdForLabel06(label) ??
            brain.ensureSemanticEntity06(label);
        currentUserEntityId091 = id;
        p.semanticEntityId = id;
        p.label = brain.entities[id].label;
        final e = _edge(_pNode(p.id), _eNode(id));
        _plasticUpdate(e, reward: 1.0, coactivity: 1.0);
        changed++;
        return changed;
      }
    }
    return changed;
  }

  int repairNaturalBindings071(PlasticLanguageBrain04 brain) {
    var repaired = 0;
    for (final p in prototypes) {
      final raw = p.label?.trim();
      if (raw == null || raw.isEmpty) continue;

      final ns = PlasticLanguageBrain04.lexicalTokens(raw)
          .map(PlasticLanguageBrain04.normalizeText)
          .toSet();
      final sentenceLike = ns.any({
        'io',
        'mi',
        'me',
        'sono',
        'sei',
        'è',
        'e',
        'questo',
        'questa',
        'foto',
        'immagine'
      }.contains);
      if (!sentenceLike) continue;

      final resolved = _resolveNaturalBinding071(brain, raw);
      final changed = p.semanticEntityId != resolved.entityId ||
          PlasticLanguageBrain04.normalizeText(raw) !=
              PlasticLanguageBrain04.normalizeText(resolved.label);
      if (!changed) continue;

      p.semanticEntityId = resolved.entityId;
      p.label = resolved.label;
      p.stability = max(p.stability, 0.55);
      final e = _edge(_pNode(p.id), _eNode(resolved.entityId));
      _plasticUpdate(e, reward: 1.0, coactivity: 1.0);
      repaired++;
    }
    return repaired;
  }

  void importTeacherSemanticLink08(
    int entityA,
    int entityB,
    double similarity, {
    double confidence = 0.65,
  }) {
    if (entityA == entityB) return;
    final sim = similarity.clamp(0.0, 1.0).toDouble();
    final conf = confidence.clamp(0.0, 1.0).toDouble();
    if (sim < 0.05 || conf <= 0) return;

    final e = _edge(_eNode(entityA), _eNode(entityB));
    final prior = sim * (0.25 + 0.55 * conf);
    // Teacher geometry is deliberately sub-threshold or barely active: it is
    // a prior, not a frozen truth. Lived co-activation must consolidate it.
    e.cost = min(e.cost, (1.10 - 0.12 * prior).clamp(0.97, 1.10).toDouble());
    e.fast = max(e.fast, 0.08 * prior);
    e.slow = max(e.slow, 0.02 * prior);
    e.meta = max(e.meta, 0.02 * prior);
    e.elig = max(e.elig, 0.06 + 0.10 * prior);
    e.uses += 1;
    e.lastUsed = step;
  }

  void rehearseExternalFact319(int a, int b) {
    if (a == b) return;
    final e = _edge(_eNode(a), _eNode(b));
    step++;
    for (var i = 0; i < 3; i++) {
      _plasticUpdate(e, reward: 0.25, coactivity: 0.80);
    }
  }

  void maintainCurvature319() {
    if (_curvatureDirty18.isEmpty) {
      for (final entry in edges.entries) {
        if (entry.value.cost <= MgdMath09.defaults.epsilon &&
            !entry.value.curvatureMeasured320) _curvatureDirty18.add(entry.key);
      }
    }
    _refreshCurvature18(1);
  }

  void retireResearchLink317(int a, int b) {
    final key = _edgeKey(_eNode(a), _eNode(b));
    final e = edges[key];
    if (e == null) return;
    e.cost = max(e.cost, MgdMath09.defaults.epsilon + 0.02);
    e.fast = min(e.fast, 0.05);
    e.slow = min(e.slow, 0.03);
    e.meta = min(e.meta, 0.03);
    _curvatureDirty18.add(key);
  }

  void reinforceSemanticHypothesis030(
    int entityA,
    int entityB, {
    required double confidence,
    required int evidenceCount,
    required int providerCount,
    required int independentFamilies,
  }) {
    if (entityA == entityB) return;
    final e = _edge(_eNode(entityA), _eNode(entityB));
    final c = confidence.clamp(0.0, 1.0).toDouble();
    final repetitions = min(3, max(1, 1 + (evidenceCount - 1) ~/ 2));
    final providerDiversity = min(1.0, max(0, providerCount - 1) / 3.0);
    for (var i = 0; i < repetitions; i++) {
      _plasticUpdate(
        e,
        reward: (0.10 + 0.22 * c + 0.05 * providerDiversity)
            .clamp(0.0, 0.42)
            .toDouble(),
        coactivity: (0.34 + 0.30 * c + 0.08 * providerDiversity)
            .clamp(0.0, 0.72)
            .toDouble(),
      );
    }
    if (independentFamilies < 2) {
      e.cost = max(e.cost, MgdMath09.defaults.epsilon + 0.012);
      _curvatureDirty18.add(_edgeKey(e.a, e.b));
    } else if (c >= 0.52) {
      consolidateSemanticLink029(entityA, entityB,
          confidence: c, independentFamilies: independentFamilies);
    }
  }

  void consolidateSemanticLink029(
    int entityA,
    int entityB, {
    double confidence = 0.72,
    int independentFamilies = 2,
  }) {
    if (entityA == entityB) return;
    final e = _edge(_eNode(entityA), _eNode(entityB));
    final c = confidence.clamp(0.0, 1.0).toDouble();
    final rounds = independentFamilies >= 3 ? 3 : 2;
    for (var i = 0; i < rounds; i++) {
      _plasticUpdate(
        e,
        reward: (0.52 + 0.38 * c).clamp(0.0, 1.0).toDouble(),
        coactivity: (0.78 + 0.16 * c).clamp(0.0, 1.0).toDouble(),
      );
    }
    _refreshCurvature18(1);
  }

  List<int> _mentionedEntities09(PlasticLanguageBrain04 brain, String text) {
    final n = PlasticLanguageBrain04.normalizeText(text);
    final found = <int>[];
    final candidates = brain.entities.toList()
      ..sort((a, b) => b.label.length.compareTo(a.label.length));
    final resolvedSense028 = brain.resolveSenseEntity028(text, context: text);
    if (resolvedSense028 != null) found.add(resolvedSense028);
    for (final e in candidates) {
      if (e.id == brain.selfId || e.id == brain.userId || e.kind == 'sense')
        continue;
      final labels = <String>{e.label, ...e.aliases};
      var hit = false;
      for (final raw in labels) {
        final label = PlasticLanguageBrain04.normalizeText(raw);
        if (label.length < 2) continue;
        if (RegExp(
                '(^|[^a-zà-ÿ0-9])' + RegExp.escape(label) + r'([^a-zà-ÿ0-9]|$)')
            .hasMatch(n)) {
          hit = true;
          break;
        }
      }
      if (hit) found.add(e.id);
      if (found.length >= 8) break;
    }
    return found;
  }

  void integrateLanguageExperience09(
    PlasticLanguageBrain04 brain,
    String text, {
    double reward = 0.35,
  }) {
    final ids = _mentionedEntities09(brain, text);
    if (ids.isEmpty) return;
    step++;

    if (ids.length == 1 &&
        lastLanguageEntity09 != null &&
        lastLanguageEntity09 != ids.first) {
      final e = _edge(_eNode(lastLanguageEntity09!), _eNode(ids.first));
      _plasticUpdate(e, reward: reward * 0.55, coactivity: 0.45);
    }
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final e = _edge(_eNode(ids[i]), _eNode(ids[j]));
        _plasticUpdate(e, reward: reward, coactivity: 0.85);
      }
    }
    lastLanguageEntity09 = ids.last;
  }

  String bindPrototypeNatural09(
    PlasticLanguageBrain04 brain,
    int prototypeId,
    String raw,
  ) {
    if (prototypeId < 0 || prototypeId >= prototypes.length) return raw.trim();
    final resolved = _resolveNaturalBinding071(brain, raw);
    final p = prototypes[prototypeId];
    p.label = resolved.label;
    p.semanticEntityId = resolved.entityId;
    p.stability = max(p.stability, 0.55);
    final e = _edge(_pNode(p.id), _eNode(resolved.entityId));
    _plasticUpdate(e, reward: 1.0, coactivity: 1.0);
    return resolved.label;
  }

  int _entityIdFromWorldNode09(String node) {
    if (!node.startsWith('e:')) return -1;
    return int.tryParse(node.substring(2)) ?? -1;
  }

  int get _cognitiveClock09 => step + thoughtCycles ~/ 8;

  String? nextCuriosityQuestion09(PlasticLanguageBrain04 brain) =>
      nextCuriosityQuestion316(brain);

  String? consumeCuriosityAnswer09(PlasticLanguageBrain04 brain, String raw) =>
      consumeCuriosityAnswer316(brain, raw);

  void bindLast({required String label, required int entityId}) {
    final obs = lastObservation;
    if (obs == null) return;
    final p = prototypes[obs.prototypeId];
    p.label = label.trim();
    p.semanticEntityId = entityId;
    p.stability = (p.stability + 0.25).clamp(0.0, 1.0);
    final e = _edge(_pNode(p.id), _eNode(entityId));
    _plasticUpdate(e, reward: 1.0, coactivity: 1.0);
  }

  String lastPerceptionSummary() {
    final obs = lastObservation;
    if (obs == null) return 'Nessuna percezione ancora.';
    final p = prototypes[obs.prototypeId];
    final kind = obs.modality == 'vision' ? 'visivo' : 'uditivo';
    if (p.label != null && p.label!.trim().isNotEmpty) {
      return 'Pattern $kind #${p.id}: ${p.label} • stabilità ${(p.stability * 100).round()}%';
    }
    return 'Pattern $kind #${p.id} • novità ${(obs.novelty * 100).round()}%';
  }

  List<ThoughtStep06> think(PlasticLanguageBrain04 brain,
      {int cycles = 48, String? seedText, double? stopFlux}) {
    if (cycles <= 0) return const [];
    final thinkClock16 = Stopwatch()..start();
    lastThinkVisitedEdges16 = 0;
    lastThinkVisitedFacts16 = 0;
    lastThinkPeakActiveNodes16 = 0;
    final activation = <String, double>{};
    final labels = <String, String>{};

    if (lastObservation != null) {
      final p = prototypes[lastObservation!.prototypeId];
      activation[_pNode(p.id)] = 1.0;
      labels[_pNode(p.id)] = p.label ?? '${p.modality}#${p.id}';
      if (p.semanticEntityId != null &&
          p.semanticEntityId! < brain.entities.length) {
        activation[_eNode(p.semanticEntityId!)] = 0.82;
      }
    }

    if (seedText != null && seedText.trim().isNotEmpty) {
      final words = PlasticLanguageBrain04.lexicalTokens(seedText)
          .map(PlasticLanguageBrain04.normalizeText)
          .toSet();
      for (final e in brain.entities) {
        final parts = PlasticLanguageBrain04.lexicalTokens(e.label)
            .map(PlasticLanguageBrain04.normalizeText)
            .toSet();
        if (words.intersection(parts).isNotEmpty)
          activation[_eNode(e.id)] = max(activation[_eNode(e.id)] ?? 0, 0.90);
      }
    }

    for (final ep in brain.episodes.reversed.take(3)) {
      if (ep.subjectId != null)
        activation[_eNode(ep.subjectId!)] =
            max(activation[_eNode(ep.subjectId!)] ?? 0, 0.58);
    }

    for (final e in brain.entities) labels[_eNode(e.id)] = e.label;
    for (final p in prototypes)
      labels[_pNode(p.id)] = p.label ?? '${p.modality}#${p.id}';

    final factEdges = brain.cognitiveFacts06();

    // Build incidence indexes once per thinking burst. Older versions scanned
    // every world edge and every fact on every mental cycle: O(cycles * E).
    // This makes propagation event-driven after a single O(E + F) indexing pass.
    final worldAdjacency16 = <String, List<WorldEdge06>>{};
    for (final e in edges.values) {
      worldAdjacency16.putIfAbsent(e.a, () => <WorldEdge06>[]).add(e);
      worldAdjacency16.putIfAbsent(e.b, () => <WorldEdge06>[]).add(e);
    }
    final factAdjacency16 = <String, List<CognitiveFact06>>{};
    for (final f in factEdges) {
      final sNode = _eNode(f.subjectId);
      final rNode = 'r:${f.relationId}';
      labels[rNode] = f.relation;
      factAdjacency16.putIfAbsent(sNode, () => <CognitiveFact06>[]).add(f);
      factAdjacency16.putIfAbsent(rNode, () => <CognitiveFact06>[]).add(f);
      final oId = f.objectEntityId;
      if (oId != null) {
        factAdjacency16
            .putIfAbsent(_eNode(oId), () => <CognitiveFact06>[])
            .add(f);
      }
    }

    final produced = <ThoughtStep06>[];
    var actualCycles16 = 0;
    var quietCycles16 = 0;
    final fatigue = <String, double>{};
    final visits = <String, int>{};
    for (final k in hypothesisFatigue011.keys.toList()) {
      hypothesisFatigue011[k] = hypothesisFatigue011[k]! * 0.68;
      if (hypothesisFatigue011[k]! < 0.04) hypothesisFatigue011.remove(k);
    }
    for (var c = 0; c < cycles; c++) {
      actualCycles16 = c + 1;
      final previousActivation16 = Map<String, double>.of(activation);
      final next = <String, double>{};
      for (final entry in activation.entries)
        next[entry.key] = entry.value * 0.72;

      final activeNodes16 = activation.entries
          .where((e) => e.value > 0.01)
          .map((e) => e.key)
          .toList(growable: false);
      lastThinkPeakActiveNodes16 =
          max(lastThinkPeakActiveNodes16, activeNodes16.length);

      final seenWorld16 = <WorldEdge06>{};
      for (final node in activeNodes16) {
        for (final e in worldAdjacency16[node] ?? const <WorldEdge06>[]) {
          if (!seenWorld16.add(e)) continue;
          lastThinkVisitedEdges16++;
          final s = _strength(e);
          final av = activation[e.a] ?? 0;
          final bv = activation[e.b] ?? 0;
          if (av > 0.01) next[e.b] = max(next[e.b] ?? 0, av * s);
          if (bv > 0.01) next[e.a] = max(next[e.a] ?? 0, bv * s);
        }
      }

      final seenFacts16 = <CognitiveFact06>{};
      for (final node in activeNodes16) {
        for (final f in factAdjacency16[node] ?? const <CognitiveFact06>[]) {
          if (!seenFacts16.add(f)) continue;
          lastThinkVisitedFacts16++;
          final sNode = _eNode(f.subjectId);
          final rNode = 'r:${f.relationId}';
          final oId = f.objectEntityId;
          final conf = f.confidence.clamp(0.0, 1.0);
          final sv = activation[sNode] ?? 0;
          final rv = activation[rNode] ?? 0;
          if (sv > 0.01) {
            next[rNode] = max(next[rNode] ?? 0, sv * (0.50 + 0.42 * conf));
          }
          if (rv > 0.01) {
            next[sNode] = max(next[sNode] ?? 0, rv * (0.36 + 0.32 * conf));
          }
          if (oId != null) {
            final oNode = _eNode(oId);
            final ov = activation[oNode] ?? 0;
            if (sv > 0.01) {
              next[oNode] = max(next[oNode] ?? 0, sv * (0.38 + 0.48 * conf));
            }
            if (ov > 0.01) {
              next[sNode] = max(next[sNode] ?? 0, ov * (0.30 + 0.38 * conf));
            }
            if (rv > 0.01) {
              next[oNode] = max(next[oNode] ?? 0, rv * (0.34 + 0.42 * conf));
            }
            if (ov > 0.01) {
              next[rNode] = max(next[rNode] ?? 0, ov * (0.28 + 0.34 * conf));
            }
          }
        }
      }

      // Refractory inhibition: recently dominant nodes become temporarily
      // expensive, so the recurrent process explores new hops instead of
      // oscillating forever inside the same attractor.
      for (final k in next.keys.toList()) {
        final f = fatigue[k] ?? 0.0;
        next[k] = (next[k]! / (1.0 + 0.85 * f)).clamp(0.0, 1.0);
      }
      for (final k in fatigue.keys.toList()) {
        fatigue[k] = fatigue[k]! * 0.84;
        if (fatigue[k]! < 0.01) fatigue.remove(k);
      }

      activation
        ..clear()
        ..addAll(next.map((k, v) => MapEntry(k, v.clamp(0.0, 1.0))));

      if (stopFlux != null && c >= 3) {
        final keys16 = <String>{
          ...previousActivation16.keys,
          ...activation.keys
        };
        var delta16 = 0.0;
        for (final k in keys16) {
          delta16 +=
              ((activation[k] ?? 0.0) - (previousActivation16[k] ?? 0.0)).abs();
        }
        final normFlux16 = keys16.isEmpty ? 0.0 : delta16 / keys16.length;
        if (normFlux16 < stopFlux) {
          quietCycles16++;
        } else {
          quietCycles16 = 0;
        }
        if (quietCycles16 >= 2) break;
      }

      if (c % 4 == 3 || c == cycles - 1) {
        final ranked = activation.entries.where((e) => e.value >= 0.08).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top = ranked.take(4).toList();
        final focus = top.map((e) => labels[e.key] ?? e.key).toList();
        final coherence = top.isEmpty
            ? 0.0
            : top.map((e) => e.value).reduce((a, b) => a + b) / top.length;
        String hypothesis = 'Nessun attrattore dominante.';

        CognitiveFact06? exploratoryFact;
        String? exploratoryKey;
        var exploratoryScore = -1.0;
        for (final f in factEdges) {
          final sn = _eNode(f.subjectId);
          final rn = 'r:${f.relationId}';
          final on =
              f.objectEntityId == null ? null : _eNode(f.objectEntityId!);
          final factKey =
              '${f.subjectId}|${f.relationId}|${PlasticLanguageBrain04.normalizeText(f.object)}';
          final repetition = hypothesisFatigue011[factKey] ?? 0.0;
          final score = (activation[sn] ?? 0) +
              (activation[rn] ?? 0) +
              (on == null ? 0 : activation[on] ?? 0) +
              0.45 * f.confidence -
              0.10 * (visits[sn] ?? 0) -
              0.08 * (on == null ? 0 : visits[on] ?? 0) -
              0.34 * repetition;
          if (score > exploratoryScore) {
            exploratoryScore = score;
            exploratoryFact = f;
            exploratoryKey = factKey;
          }
        }
        if (exploratoryFact != null && exploratoryScore > 0.18) {
          final f = exploratoryFact;
          final subject = f.subjectId < brain.entities.length
              ? brain.entities[f.subjectId].label
              : 'entità ${f.subjectId}';
          hypothesis = 'Ipotesi: $subject —${f.relation}→ ${f.object}';
          if (exploratoryKey != null) {
            hypothesisFatigue011[exploratoryKey] =
                (hypothesisFatigue011[exploratoryKey] ?? 0.0) + 1.0;
          }
        } else if (focus.isNotEmpty) {
          hypothesis = 'Esploro: ${focus.join(' ↔ ')}';
        }

        for (final e in top) {
          fatigue[e.key] = (fatigue[e.key] ?? 0) + 0.75;
          visits[e.key] = (visits[e.key] ?? 0) + 1;
        }
        final recentDuplicate = thoughts.reversed
            .take(5)
            .any((old) => old.hypothesis == hypothesis);
        if (!recentDuplicate || hypothesis.startsWith('Esploro:')) {
          final t = ThoughtStep06(
            cycle: thoughtCycles + c + 1,
            focus: focus,
            hypothesis: hypothesis,
            coherence: coherence,
          );
          thoughts.add(t);
          produced.add(t);
        }
      }
    }
    thoughtCycles += actualCycles16;
    if (thoughts.length > maxThoughts)
      thoughts.removeRange(0, thoughts.length - maxThoughts);
    // Exact curvature is maintenance work, not a per-frame operation.
    // Explicit/long thinking gets a tiny budget; 2-cycle background bursts get none.
    if (cycles >= 24) _refreshCurvature18(4);
    thinkClock16.stop();
    lastThinkMicros16 = thinkClock16.elapsedMicroseconds;
    return produced;
  }

  int dedupeThoughts011() {
    if (thoughts.length < 2) return 0;
    final kept = <ThoughtStep06>[];
    final recent = <String>[];
    var removed = 0;
    for (final t in thoughts) {
      if (recent.contains(t.hypothesis)) {
        removed++;
        continue;
      }
      kept.add(t);
      recent.add(t.hypothesis);
      if (recent.length > 5) recent.removeAt(0);
    }
    if (removed > 0) {
      thoughts
        ..clear()
        ..addAll(kept.length > maxThoughts
            ? kept.sublist(kept.length - maxThoughts)
            : kept);
    }
    return removed;
  }

  void sleepReplay({int cycles = 48}) {
    if (edges.isEmpty) return;
    final ranked = edges.values.toList()
      ..sort(
          (a, b) => (_strength(b) + b.slow).compareTo(_strength(a) + a.slow));
    lastEntropicFlux09 = 0;
    for (final e in ranked.take(min(cycles, ranked.length))) {
      final replay = MgdMath09.evolve(
        weight: e.cost,
        memory: e.fast,
        material: e.slow,
        coherenceAverage: e.meta,
        activation: e.uses >= 2 ? 0.55 : 0.15,
        reward: e.uses >= 2 ? 0.35 : 0.0,
      );
      e.cost = replay.weight;
      e.fast = replay.memory;
      e.slow = replay.material;
      e.meta = replay.coherenceAverage;
      e.elig *= 0.82;
      lastEntropicFlux09 += replay.informationalFlux;
      entropicAge += replay.informationalFlux;
    }
    _refreshCurvature18(8);
  }

  MgdWorldStats06 stats() {
    var slow = 0.0;
    var curvature = 0.0;
    var curvatureN = 0;
    var active = 0;
    var preActive030 = 0;
    for (final e in edges.values) {
      slow += e.slow;
      if (e.cost <= MgdMath09.defaults.epsilon) {
        active++;
      } else if (e.cost <= MgdMath09.defaults.epsilon + 0.035 && e.uses >= 2) {
        preActive030++;
      }
      if (e.curvatureMeasured320 && e.cost <= MgdMath09.defaults.epsilon) {
        curvature += e.curvature;
        curvatureN++;
      }
    }
    return MgdWorldStats06(
      visualPatterns: prototypes.where((p) => p.modality == 'vision').length,
      auditoryPatterns: prototypes.where((p) => p.modality == 'audio').length,
      worldEdges: edges.length,
      semanticBindings:
          prototypes.where((p) => p.semanticEntityId != null).length,
      thoughtCycles: thoughtCycles,
      novelty: noveltyEma,
      predictionError: predictionErrorEma,
      curiosity: curiosity,
      entropicAge: entropicAge,
      meanSlow: edges.isEmpty ? 0 : slow / edges.length,
      activeEdges: active,
      preActiveEdges030: preActive030,
      meanCurvature: curvatureN == 0 ? 0 : curvature / curvatureN,
      entropicFlux: lastEntropicFlux09,
      curiosityPending: pendingCuriosityQuestion09 != null,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'step': step,
        'nextObservationId': nextObservationId,
        'thoughtCycles': thoughtCycles,
        'runtime319': Map<String, dynamic>.of(runtime319),
        'noveltyEma': noveltyEma,
        'predictionErrorEma': predictionErrorEma,
        'curiosity': curiosity,
        'entropicAge': entropicAge,
        'lastEntropicFlux09': lastEntropicFlux09,
        'pendingCuriosityType09': pendingCuriosityType09,
        'pendingCuriosityQuestion09': pendingCuriosityQuestion09,
        'pendingCuriosityPrototype09': pendingCuriosityPrototype09,
        'pendingCuriosityEntities09': pendingCuriosityEntities09,
        'curiosityCooldown09': curiosityCooldown09,
        'lastLanguageEntity09': lastLanguageEntity09,
        'currentUserEntityId091': currentUserEntityId091,
        'askedCuriosity09': askedCuriosity09.toList(),
        'hypothesisFatigue011': hypothesisFatigue011,
        'prototypes': prototypes.map((e) => e.toJson()).toList(),
        'edges': edges.values.map((e) => e.toJson()).toList(),
        'observations': observations.map((e) => e.toJson()).toList(),
        'thoughts': thoughts.map((e) => e.toJson()).toList(),
        'lastObservationId': lastObservation?.id,
      };

  /// Apply only the state changed by a replay worker, retaining the world object
  /// held by open inspectors. The caller must reject stale worker results.
  void applyRuntime320(Map<String, dynamic> data) {
    final n = MgdWorld06.fromJson(data);
    final savedAt = runtime319['lastSavedAt'];
    edges
      ..clear()
      ..addAll(n.edges);
    thoughts
      ..clear()
      ..addAll(n.thoughts);
    runtime319
      ..clear()
      ..addAll(n.runtime319);
    if (savedAt != null) runtime319['lastSavedAt'] = savedAt;
    step = n.step;
    thoughtCycles = n.thoughtCycles;
    noveltyEma = n.noveltyEma;
    predictionErrorEma = n.predictionErrorEma;
    curiosity = n.curiosity;
    entropicAge = n.entropicAge;
    lastEntropicFlux09 = n.lastEntropicFlux09;
    curiosityCooldown09 = n.curiosityCooldown09;
    hypothesisFatigue011
      ..clear()
      ..addAll(n.hypothesisFatigue011);
    _curvatureDirty18.clear();
  }

  String encodeJson() => jsonEncode(toJson());

  factory MgdWorld06.fromJson(Map<String, dynamic> j) {
    final w = MgdWorld06();
    if (j['runtime319'] is Map)
      w.runtime319.addAll(Map<String, dynamic>.from(j['runtime319'] as Map));
    w.step = (j['step'] as num?)?.toInt() ?? 0;
    w.nextObservationId = (j['nextObservationId'] as num?)?.toInt() ?? 1;
    w.thoughtCycles = (j['thoughtCycles'] as num?)?.toInt() ?? 0;
    w.noveltyEma = (j['noveltyEma'] as num?)?.toDouble() ?? 0;
    w.predictionErrorEma = (j['predictionErrorEma'] as num?)?.toDouble() ?? 0;
    w.curiosity = (j['curiosity'] as num?)?.toDouble() ?? 0;
    w.entropicAge = (j['entropicAge'] as num?)?.toDouble() ?? 0;
    w.lastEntropicFlux09 = (j['lastEntropicFlux09'] as num?)?.toDouble() ?? 0;
    w.pendingCuriosityType09 = j['pendingCuriosityType09'] as String?;
    w.pendingCuriosityQuestion09 = j['pendingCuriosityQuestion09'] as String?;
    w.pendingCuriosityPrototype09 =
        (j['pendingCuriosityPrototype09'] as num?)?.toInt();
    w.pendingCuriosityEntities09 =
        ((j['pendingCuriosityEntities09'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList();
    w.curiosityCooldown09 = (j['curiosityCooldown09'] as num?)?.toInt() ?? 0;
    w.lastLanguageEntity09 = (j['lastLanguageEntity09'] as num?)?.toInt();
    w.currentUserEntityId091 = (j['currentUserEntityId091'] as num?)?.toInt();
    w.askedCuriosity09.addAll(((j['askedCuriosity09'] as List?) ?? const [])
        .map((e) => e.toString()));
    final hf = j['hypothesisFatigue011'];
    if (hf is Map) {
      for (final e in hf.entries) {
        final v = e.value;
        if (v is num) w.hypothesisFatigue011[e.key.toString()] = v.toDouble();
      }
    }
    for (final raw in (j['prototypes'] as List?) ?? const []) {
      w.prototypes.add(
          SensoryPrototype06.fromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (j['edges'] as List?) ?? const []) {
      final e = WorldEdge06.fromJson(Map<String, dynamic>.from(raw as Map));
      w.edges[w._edgeKey(e.a, e.b)] = e;
    }
    for (final raw in (j['observations'] as List?) ?? const []) {
      w.observations.add(
          SensoryObservation06.fromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (j['thoughts'] as List?) ?? const []) {
      w.thoughts
          .add(ThoughtStep06.fromJson(Map<String, dynamic>.from(raw as Map)));
    }
    final lastId = (j['lastObservationId'] as num?)?.toInt();
    if (lastId != null) {
      for (final o in w.observations.reversed) {
        if (o.id == lastId) {
          w.lastObservation = o;
          break;
        }
      }
    }
    return w;
  }
}
