import 'dart:convert';
import 'dart:math' as math;

typedef LexicalBase445 = List<double> Function(String word);
typedef Tokenize445 = List<String> Function(String text);

/// Persistent fast lexical weights shared by prediction and the role reader.
/// Targets are observed next words and narrowly parsed explicit definitions.
/// Generated interpretations are never supervision. This is NOT a solution
/// to general semantics, polysemy, clause binding, or factual verification.
class SemanticPlasticity445 {
  static const version = 1;
  static const capacity = 4096;
  static const baseModelId = 'a374c981c4386b5cb90c7871566ff840debe44788bfeb0c464df4d8ab6892cd2';
  final int dimensions;
  final Map<String, List<double>> weights = {};
  final Map<String, List<Map<String, dynamic>>> definitions = {};
  final List<Map<String, dynamic>> replay = [];
  final Set<String> processed = {};
  final Set<String> conflicts = {};
  int revision = 0, predictionSteps = 0, definitionSteps = 0, capacityMisses = 0;
  double? predictionLossBefore, predictionLossAfter;
  double? definitionLossBefore, definitionLossAfter;

  SemanticPlasticity445(this.dimensions);

  factory SemanticPlasticity445.restore(Map? state, int dimensions) {
    final p = SemanticPlasticity445(dimensions);
    if (state == null || state['version'] != version || state['dimensions'] != dimensions || state['baseModelId'] != baseModelId) return p;
    for (final e in (state['weights'] as Map? ?? {}).entries) {
      final v = e.value;
      if (p.weights.length >= capacity) break;
      if (v is List && v.length == dimensions && v.every((x) => x is num && x.isFinite)) {
        p.weights['${e.key}'] = v.map((x) => (x as num).toDouble()).toList();
      }
    }
    for (final e in (state['definitions'] as Map? ?? {}).entries) {
      if (e.value is List) p.definitions['${e.key}'] = (e.value as List).whereType<Map>().map((v) => Map<String,dynamic>.from(v)).toList();
    }
    p.replay.addAll((state['replay'] as List? ?? []).whereType<Map>().take(1024).map((v) => Map<String,dynamic>.from(v)));
    p.processed.addAll((state['processed'] as List? ?? []).whereType<String>());
    p.conflicts.addAll((state['conflicts'] as List? ?? []).whereType<String>());
    p.revision = (state['revision'] as num? ?? 0).toInt();
    p.predictionSteps = (state['predictionSteps'] as num? ?? 0).toInt();
    p.definitionSteps = (state['definitionSteps'] as num? ?? 0).toInt();
    p.capacityMisses = (state['capacityMisses'] as num? ?? 0).toInt();
    p.predictionLossBefore = (state['predictionLossBefore'] as num?)?.toDouble();
    p.predictionLossAfter = (state['predictionLossAfter'] as num?)?.toDouble();
    p.definitionLossBefore = (state['definitionLossBefore'] as num?)?.toDouble();
    p.definitionLossAfter = (state['definitionLossAfter'] as num?)?.toDouble();
    return p;
  }

  Map<String, dynamic> toJson() => {
    'version': version, 'baseModelId':baseModelId, 'dimensions': dimensions, 'weights': weights,
    'definitions': definitions, 'replay': replay, 'processed': processed.toList(),
    'conflicts': conflicts.toList(), 'revision': revision,
    'predictionSteps': predictionSteps, 'definitionSteps': definitionSteps,
    'capacityMisses': capacityMisses,
    'predictionLossBefore': predictionLossBefore, 'predictionLossAfter': predictionLossAfter,
    'definitionLossBefore': definitionLossBefore, 'definitionLossAfter': definitionLossAfter,
  };

  List<double> vector(String word, LexicalBase445 base) {
    final b = base(word), delta = weights[word.toLowerCase()];
    if (delta == null || conflicts.contains(word.toLowerCase())) return b;
    return List.generate(dimensions, (i) => b[i] + delta[i]);
  }

  List<double>? _delta(String word) {
    if (weights.containsKey(word)) return weights[word];
    if (weights.length >= capacity) { capacityMisses++; return null; }
    return weights[word] = List.filled(dimensions, 0);
  }

  static int _hash(String s) {
    var h = 2166136261;
    for (final c in s.runes) { h = ((h ^ c) * 16777619) & 0xffffffff; }
    return h;
  }

  /// Deliberately restricted observational contract: an entire declarative
  /// sentence of quoted single-word equivalence. Negation, conditions and
  /// embedded/hypothetical mentions do not match. A source can still be wrong.
  static List<Map<String,String>> explicitDefinitions(String text) {
    const word = r"([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ'-]{1,39})";
    final pattern = RegExp(r'^\s*(?:Nel (?:lessico|glossario)(?: locale)?,\s*)?'
      r'(?:il termine\s+)?[«“"]' + word + r'[»”"]\s+'
      r'(?:significa|equivale a|è sinonimo di)\s+[«“"]' + word + r'[»”"]\s*[.!]?\s*$',
      caseSensitive: false);
    final result = <Map<String,String>>[];
    for (final sentence in text.trim().split(RegExp(r'(?<=[.!?])\s+|\n+'))) {
      final m = pattern.firstMatch(sentence);
      if (m != null && m[1]!.toLowerCase() != m[2]!.toLowerCase()) {
        result.add({'word':m[1]!.toLowerCase(),'target':m[2]!.toLowerCase(),'quote':sentence});
      }
    }
    return result;
  }

  List<double> _context(List context, LexicalBase445 base) {
    final x = List<double>.filled(dimensions, 0);
    for (final w in context) {
      final v = vector('$w', base);
      for (var j=0; j<dimensions; j++) { x[j] += v[j] / context.length; }
    }
    return x;
  }

  List<double> _probabilities(Map example, LexicalBase445 base) {
    final x = _context(example['context'] as List, base);
    final logits = (example['candidates'] as List).map((w) {
      final y = base('$w'); var z = 0.0;
      for (var j=0; j<dimensions; j++) { z += x[j]*y[j] / math.sqrt(dimensions); }
      return z;
    }).toList();
    final highest = logits.reduce(math.max);
    final exps = logits.map((z) => math.exp(z-highest)).toList();
    final sum = exps.reduce((a,b) => a+b);
    return exps.map((z) => z/sum).toList();
  }

  double? _predictionLoss(List<Map<String,dynamic>> examples, LexicalBase445 base) {
    if (examples.isEmpty) return null;
    return examples.map((e) => -math.log(_probabilities(e,base).first.clamp(1e-12,1.0))).reduce((a,b)=>a+b)/examples.length;
  }

  void _predictiveStep(Map example, LexicalBase445 base) {
    final context = example['context'] as List, candidates = example['candidates'] as List;
    final p = _probabilities(example,base); p[0] -= 1;
    final gradient = List<double>.filled(dimensions, 0);
    for (var k=0; k<p.length; k++) {
      final y = base('${candidates[k]}');
      for (var j=0; j<dimensions; j++) { gradient[j] += p[k]*y[j]/math.sqrt(dimensions)/context.length; }
    }
    for (final w in context) {
      final word = '$w';
      if (conflicts.contains(word) || definitions.containsKey(word)) continue;
      final delta = _delta(word); if (delta == null) continue;
      for (var j=0; j<dimensions; j++) { delta[j] -= .01*(gradient[j]+.2*delta[j]); }
      final norm = math.sqrt(delta.fold(0.0,(a,b)=>a+b*b));
      if (norm > .25) { for (var j=0; j<dimensions; j++) { delta[j] *= .25/norm; } }
    }
    predictionSteps++;
  }

  List<Map<String,dynamic>> _activeDefinitions() => [
    for (final e in definitions.entries) if (!conflicts.contains(e.key))
      for (final d in e.value) {'word':e.key,...d}
  ];

  double? _definitionLoss(LexicalBase445 base) {
    final ds = _activeDefinitions(); if (ds.isEmpty) return null;
    var loss = 0.0;
    for (final d in ds) {
      final x = vector('${d['word']}',base), y = vector('${d['target']}',base);
      for (var j=0; j<dimensions; j++) { loss += (x[j]-y[j])*(x[j]-y[j])/2; }
    }
    return loss/ds.length;
  }

  void learn(List<Map<String,dynamic>> rows, LexicalBase445 base, Tokenize445 tokenize) {
    final fresh = rows.where((r)=>!processed.contains('${r['rid439']}')).toList();
    if (fresh.isEmpty) return;
    final examples = <Map<String,dynamic>>[], heldout = <Map<String,dynamic>>[];
    for (final row in fresh) {
      final id = '${row['rid439']}';
      for (final d in explicitDefinitions('${row['text']}')) {
        final ds = definitions.putIfAbsent(d['word']!,()=>[]);
        ds.add({'target':d['target'],'source':id,'quote':d['quote']});
        if (ds.map((x)=>x['target']).toSet().length>1) {
          conflicts.add(d['word']!); weights.remove(d['word']);
        }
      }
      final tokens = tokenize('${row['text']}').map((w)=>w.toLowerCase()).where((w)=>RegExp(r'[a-zà-ÿ]').hasMatch(w)).toList();
      final vocabulary = tokens.toSet().toList();
      if (vocabulary.length >= 3) {
        // Covers the passage at uniformly spaced positions; bounded work.
        final stride = math.max(1,(tokens.length/256).ceil());
        for (var i=1; i<tokens.length; i+=stride) {
          final candidates = <String>[tokens[i]];
          final start = _hash('$id:$i')%vocabulary.length;
          for (var j=0; j<vocabulary.length && candidates.length<8; j++) {
            final w = vocabulary[(start+j)%vocabulary.length]; if (!candidates.contains(w)) candidates.add(w);
          }
          final e = <String,dynamic>{'source':id,'context':tokens.sublist(math.max(0,i-3),i),'candidates':candidates};
          if (_hash('heldout:$id:$i')%5==0) { heldout.add(e); } else { examples.add(e); }
        }
      }
      processed.add(id);
    }
    predictionLossBefore = _predictionLoss(heldout,base);
    definitionLossBefore = _definitionLoss(base);
    // Rehearse actual older token observations, not the reader's proposals.
    for (final e in replay.take(32)) { _predictiveStep(e,base); }
    for (final e in examples) { _predictiveStep(e,base); }
    replay.addAll(examples);
    if (replay.length>1024) replay.removeRange(0,replay.length-1024);
    // Fast assimilation plus reactivation of older definitional constraints.
    // The observed target vector is detached for each step. Cycles have no
    // guaranteed meaning; no identifiability or general-comprehension claim.
    for (var epoch=0; epoch<12; epoch++) {
      for (final d in _activeDefinitions()) {
        final word = '${d['word']}', x = vector(word,base), y = vector('${d['target']}',base);
        final delta = _delta(word); if (delta == null) continue;
        for (var j=0; j<dimensions; j++) { delta[j] -= .5*(x[j]-y[j]); }
        definitionSteps++;
      }
    }
    predictionLossAfter = _predictionLoss(heldout,base);
    definitionLossAfter = _definitionLoss(base);
    revision++;
  }

  /// Source deletion resets derived fast weights. Rebuild from surviving raw
  /// passages on the next study tick; removed observations cannot persist.
  static Map<String,dynamic> surviving(Map? state, Set<String> live, int dimensions) {
    final p = SemanticPlasticity445.restore(state, dimensions);
    if (!p.processed.every(live.contains)) return SemanticPlasticity445(dimensions).toJson();
    return p.toJson();
  }

  String fingerprint() => jsonEncode(weights);
}
