import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'native_mgd_engine_v09.dart';

class TokenAssembly04 {
  final int id;
  final String token;
  String surface;
  int count;
  int lastSeen;

  TokenAssembly04({
    required this.id,
    required this.token,
    required this.surface,
    this.count = 0,
    this.lastSeen = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'token': token,
        'surface': surface,
        'count': count,
        'lastSeen': lastSeen,
      };

  factory TokenAssembly04.fromJson(Map<String, dynamic> j) => TokenAssembly04(
        id: (j['id'] as num).toInt(),
        token: j['token'] as String,
        surface: j['surface'] as String,
        count: (j['count'] as num?)?.toInt() ?? 0,
        lastSeen: (j['lastSeen'] as num?)?.toInt() ?? 0,
      );
}

class PlasticEdge04 {
  final int from;
  final int to;
  double cost;
  double fast;
  double slow;
  double elig;
  double meta;
  int lastUsed;
  int uses;

  PlasticEdge04({
    required this.from,
    required this.to,
    this.cost = 1.08,
    this.fast = 0,
    this.slow = 0,
    this.elig = 0,
    this.meta = 0,
    this.lastUsed = 0,
    this.uses = 0,
  });

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'cost': cost,
        'fast': fast,
        'slow': slow,
        'elig': elig,
        'meta': meta,
        'lastUsed': lastUsed,
        'uses': uses,
      };

  factory PlasticEdge04.fromJson(Map<String, dynamic> j) => PlasticEdge04(
        from: (j['from'] as num).toInt(),
        to: (j['to'] as num).toInt(),
        cost: (j['cost'] as num).toDouble(),
        fast: (j['fast'] as num).toDouble(),
        slow: (j['slow'] as num).toDouble(),
        elig: (j['elig'] as num).toDouble(),
        meta: (j['meta'] as num?)?.toDouble() ?? 0,
        lastUsed: (j['lastUsed'] as num?)?.toInt() ?? 0,
        uses: (j['uses'] as num?)?.toInt() ?? 0,
      );
}

class EntityMemory04 {
  final int id;
  final String key;
  String label;
  String kind;
  final Set<String> aliases;
  int mentions;
  int lastSeen;

  EntityMemory04({
    required this.id,
    required this.key,
    required this.label,
    required this.kind,
    Set<String>? aliases,
    this.mentions = 0,
    this.lastSeen = 0,
  }) : aliases = aliases ?? <String>{};

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'label': label,
        'kind': kind,
        'aliases': aliases.toList(),
        'mentions': mentions,
        'lastSeen': lastSeen,
      };

  factory EntityMemory04.fromJson(Map<String, dynamic> j) => EntityMemory04(
        id: (j['id'] as num).toInt(),
        key: j['key'] as String,
        label: j['label'] as String,
        kind: j['kind'] as String,
        aliases: ((j['aliases'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
        mentions: (j['mentions'] as num?)?.toInt() ?? 0,
        lastSeen: (j['lastSeen'] as num?)?.toInt() ?? 0,
      );
}

class RelationMemory04 {
  final int id;
  final String key;
  String label;
  final Map<String, double> cues;
  int uses;
  bool multiValued;

  RelationMemory04({
    required this.id,
    required this.key,
    required this.label,
    Map<String, double>? cues,
    this.uses = 0,
    this.multiValued = false,
  }) : cues = cues ?? <String, double>{};

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'label': label,
        'cues': cues,
        'uses': uses,
        'multiValued': multiValued,
      };

  factory RelationMemory04.fromJson(Map<String, dynamic> j) => RelationMemory04(
        id: (j['id'] as num).toInt(),
        key: j['key'] as String,
        label: j['label'] as String,
        cues: Map<String, double>.from(
          (j['cues'] as Map?)?.map(
                  (k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
              const {},
        ),
        uses: (j['uses'] as num?)?.toInt() ?? 0,
        multiValued: j['multiValued'] as bool? ?? false,
      );
}

class FactCandidate04 {
  final String objectKey;
  String display;
  double confidence;
  int supports;
  int contradictions;
  int lastStep;
  String epistemicStatus;
  final Set<String> sourceFamilies;
  final Set<int> sourceEpisodes;

  FactCandidate04({
    required this.objectKey,
    required this.display,
    this.confidence = 0.55,
    this.supports = 1,
    this.contradictions = 0,
    this.lastStep = 0,
    this.epistemicStatus = 'experienced',
    Set<String>? sourceFamilies,
    Set<int>? sourceEpisodes,
  })  : sourceFamilies = sourceFamilies ?? <String>{},
        sourceEpisodes = sourceEpisodes ?? <int>{};

  Map<String, dynamic> toJson() => {
        'objectKey': objectKey,
        'display': display,
        'confidence': confidence,
        'supports': supports,
        'contradictions': contradictions,
        'lastStep': lastStep,
        'epistemicStatus': epistemicStatus,
        'sourceFamilies': sourceFamilies.toList(),
        'sourceEpisodes': sourceEpisodes.toList(),
      };

  factory FactCandidate04.fromJson(Map<String, dynamic> j) => FactCandidate04(
        objectKey: j['objectKey'] as String,
        display: j['display'] as String,
        confidence: (j['confidence'] as num).toDouble(),
        supports: (j['supports'] as num?)?.toInt() ?? 1,
        contradictions: (j['contradictions'] as num?)?.toInt() ?? 0,
        lastStep: (j['lastStep'] as num?)?.toInt() ?? 0,
        epistemicStatus: (j['epistemicStatus'] ?? 'experienced').toString(),
        sourceFamilies: ((j['sourceFamilies'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
        sourceEpisodes: ((j['sourceEpisodes'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toSet(),
      );
}

class RelationSlot04 {
  final int subjectId;
  final int relationId;
  final Map<String, FactCandidate04> candidates;

  RelationSlot04({
    required this.subjectId,
    required this.relationId,
    Map<String, FactCandidate04>? candidates,
  }) : candidates = candidates ?? <String, FactCandidate04>{};

  String get key => '$subjectId::$relationId';

  FactCandidate04? get winner {
    if (candidates.isEmpty) return null;
    final xs = candidates.values
        .where((c) =>
            c.epistemicStatus != 'review' && c.epistemicStatus != 'documented')
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    return xs.isEmpty ? null : xs.first;
  }

  bool get hasConflict {
    final viable = candidates.values.where((c) => c.confidence >= 0.35).length;
    return viable > 1;
  }

  Map<String, dynamic> toJson() => {
        'subjectId': subjectId,
        'relationId': relationId,
        'candidates': candidates.values.map((e) => e.toJson()).toList(),
      };

  factory RelationSlot04.fromJson(Map<String, dynamic> j) {
    final slot = RelationSlot04(
      subjectId: (j['subjectId'] as num).toInt(),
      relationId: (j['relationId'] as num).toInt(),
    );
    for (final raw in (j['candidates'] as List?) ?? const []) {
      final c = FactCandidate04.fromJson(Map<String, dynamic>.from(raw as Map));
      slot.candidates[c.objectKey] = c;
    }
    return slot;
  }
}

class LexicalSense028 {
  final String lexeme;
  final String senseKey;
  final int entityId;
  String label;
  String gloss;
  double confidence;
  int supports;
  final Set<String> contextCues;

  LexicalSense028({
    required this.lexeme,
    required this.senseKey,
    required this.entityId,
    required this.label,
    required this.gloss,
    this.confidence = 0.45,
    this.supports = 1,
    Set<String>? contextCues,
  }) : contextCues = contextCues ?? <String>{};

  Map<String, dynamic> toJson() => {
        'lexeme': lexeme,
        'senseKey': senseKey,
        'entityId': entityId,
        'label': label,
        'gloss': gloss,
        'confidence': confidence,
        'supports': supports,
        'contextCues': contextCues.toList(),
      };

  factory LexicalSense028.fromJson(Map<String, dynamic> j) => LexicalSense028(
        lexeme: (j['lexeme'] ?? '').toString(),
        senseKey: (j['senseKey'] ?? '').toString(),
        entityId: (j['entityId'] as num?)?.toInt() ?? -1,
        label: (j['label'] ?? '').toString(),
        gloss: (j['gloss'] ?? '').toString(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.45,
        supports: (j['supports'] as num?)?.toInt() ?? 1,
        contextCues: ((j['contextCues'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
      );
}

class ResponseCandidate028 {
  final String key;
  String text;
  double strength;
  int supports;
  int lastUsed;
  final Set<String> contextCues;

  ResponseCandidate028({
    required this.key,
    required this.text,
    this.strength = 0.55,
    this.supports = 1,
    this.lastUsed = -1000000,
    Set<String>? contextCues,
  }) : contextCues = contextCues ?? <String>{};

  Map<String, dynamic> toJson() => {
        'key': key,
        'text': text,
        'strength': strength,
        'supports': supports,
        'lastUsed': lastUsed,
        'contextCues': contextCues.toList(),
      };

  factory ResponseCandidate028.fromJson(Map<String, dynamic> j) =>
      ResponseCandidate028(
        key: (j['key'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        strength: (j['strength'] as num?)?.toDouble() ?? 0.55,
        supports: (j['supports'] as num?)?.toInt() ?? 1,
        lastUsed: (j['lastUsed'] as num?)?.toInt() ?? -1000000,
        contextCues: ((j['contextCues'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
      );
}

class ResponseSlot028 {
  final String promptKey;
  String promptSurface;
  final Map<String, ResponseCandidate028> candidates;
  int responseTick;

  ResponseSlot028({
    required this.promptKey,
    required this.promptSurface,
    Map<String, ResponseCandidate028>? candidates,
    this.responseTick = 0,
  }) : candidates = candidates ?? <String, ResponseCandidate028>{};

  Map<String, dynamic> toJson() => {
        'promptKey': promptKey,
        'promptSurface': promptSurface,
        'responseTick': responseTick,
        'candidates': candidates.values.map((e) => e.toJson()).toList(),
      };

  factory ResponseSlot028.fromJson(Map<String, dynamic> j) {
    final out = ResponseSlot028(
      promptKey: (j['promptKey'] ?? '').toString(),
      promptSurface: (j['promptSurface'] ?? '').toString(),
      responseTick: (j['responseTick'] as num?)?.toInt() ?? 0,
    );
    for (final raw in (j['candidates'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final c = ResponseCandidate028.fromJson(Map<String, dynamic>.from(raw));
      if (c.key.isNotEmpty) out.candidates[c.key] = c;
    }
    final maxUsed = out.candidates.values.fold<int>(
      0,
      (m, c) => c.lastUsed > m ? c.lastUsed : m,
    );
    if (maxUsed > out.responseTick) out.responseTick = maxUsed;
    return out;
  }
}

class BindingFrame04 {
  final int subjectId;
  final int relationId;
  final String? objectKey;
  final bool isQuery;
  final Uint32List subjectBinding;
  final Uint32List relationBinding;
  final Uint32List? objectBinding;
  final Uint32List composite;

  BindingFrame04({
    required this.subjectId,
    required this.relationId,
    required this.objectKey,
    required this.isQuery,
    required this.subjectBinding,
    required this.relationBinding,
    required this.objectBinding,
    required this.composite,
  });
}

class Interpretation04 {
  final bool isQuestion;
  final int? subjectId;
  final int? relationId;
  final String? objectText;
  final String? objectKey;
  final List<String> relationCues;
  final double confidence;

  const Interpretation04({
    required this.isQuestion,
    required this.subjectId,
    required this.relationId,
    required this.objectText,
    required this.objectKey,
    required this.relationCues,
    required this.confidence,
  });
}

class Episode04 {
  final int id;
  String userText;
  String? agentText;
  List<int> tokenIds;
  int? subjectId;
  int? relationId;
  String? objectKey;
  bool wasQuestion;
  double novelty;
  double predictionError;
  double boundary;
  double salience;
  double reward;
  double flux;
  int createdStep;
  int replays;

  Episode04({
    required this.id,
    required this.userText,
    required this.tokenIds,
    this.agentText,
    this.subjectId,
    this.relationId,
    this.objectKey,
    this.wasQuestion = false,
    this.novelty = 0,
    this.predictionError = 0,
    this.boundary = 1,
    this.salience = 0.5,
    this.reward = 0,
    this.flux = 0,
    this.createdStep = 0,
    this.replays = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userText': userText,
        'agentText': agentText,
        'tokenIds': tokenIds,
        'subjectId': subjectId,
        'relationId': relationId,
        'objectKey': objectKey,
        'wasQuestion': wasQuestion,
        'novelty': novelty,
        'predictionError': predictionError,
        'boundary': boundary,
        'salience': salience,
        'reward': reward,
        'flux': flux,
        'createdStep': createdStep,
        'replays': replays,
      };

  factory Episode04.fromJson(Map<String, dynamic> j) => Episode04(
        id: (j['id'] as num).toInt(),
        userText: j['userText'] as String,
        agentText: j['agentText'] as String?,
        tokenIds: ((j['tokenIds'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        subjectId: (j['subjectId'] as num?)?.toInt(),
        relationId: (j['relationId'] as num?)?.toInt(),
        objectKey: j['objectKey'] as String?,
        wasQuestion: j['wasQuestion'] as bool? ?? false,
        novelty: (j['novelty'] as num?)?.toDouble() ?? 0,
        predictionError: (j['predictionError'] as num?)?.toDouble() ?? 0,
        boundary: (j['boundary'] as num?)?.toDouble() ?? 1,
        salience: (j['salience'] as num?)?.toDouble() ?? 0.5,
        reward: (j['reward'] as num?)?.toDouble() ?? 0,
        flux: (j['flux'] as num?)?.toDouble() ?? 0,
        createdStep: (j['createdStep'] as num?)?.toInt() ?? 0,
        replays: (j['replays'] as num?)?.toInt() ?? 0,
      );
}

class Concept04 {
  final int id;
  final String label;
  final List<int> entityIds;
  final List<String> sharedFeatures;
  final double coherence;

  const Concept04({
    required this.id,
    required this.label,
    required this.entityIds,
    required this.sharedFeatures,
    required this.coherence,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'entityIds': entityIds,
        'sharedFeatures': sharedFeatures,
        'coherence': coherence,
      };

  factory Concept04.fromJson(Map<String, dynamic> j) => Concept04(
        id: (j['id'] as num).toInt(),
        label: j['label'] as String,
        entityIds:
            (j['entityIds'] as List).map((e) => (e as num).toInt()).toList(),
        sharedFeatures:
            (j['sharedFeatures'] as List).map((e) => e.toString()).toList(),
        coherence: (j['coherence'] as num).toDouble(),
      );
}

class LearningReport04 {
  final int tokens;
  final int newTokens;
  final double novelty;
  final double predictionError;
  final double flux;

  const LearningReport04({
    required this.tokens,
    required this.newTokens,
    required this.novelty,
    required this.predictionError,
    required this.flux,
  });
}

class Brain04Stats {
  final int vocabulary;
  final int synapses;
  final int entities;
  final int relations;
  final int episodes;
  final int facts;
  final int conflicts;
  final int concepts;
  final double novelty;
  final double predictionError;
  final double curiosity;
  final double entropicAge;
  final double lastFlux;
  final double meanSlow;

  const Brain04Stats({
    required this.vocabulary,
    required this.synapses,
    required this.entities,
    required this.relations,
    required this.episodes,
    required this.facts,
    required this.conflicts,
    required this.concepts,
    required this.novelty,
    required this.predictionError,
    required this.curiosity,
    required this.entropicAge,
    required this.lastFlux,
    required this.meanSlow,
  });
}

class CognitiveFact06 {
  final int subjectId;
  final int relationId;
  final String relation;
  final String object;
  final int? objectEntityId;
  final double confidence;

  const CognitiveFact06({
    required this.subjectId,
    required this.relationId,
    required this.relation,
    required this.object,
    required this.objectEntityId,
    required this.confidence,
  });
}

class _EdgeChange04 {
  final double slowDelta;
  final double fastDelta;
  final double costDelta;
  final bool created;

  const _EdgeChange04(
      this.slowDelta, this.fastDelta, this.costDelta, this.created);
}

class PlasticLanguageBrain04 {
  static const int version = 8;
  static const int vectorWords = 8; // 256-bit hypervectors.
  static const int workingMemorySize = 24;
  static const int maxEpisodes = 1200;
  static const int maxEdges = 180000;

  static const String selfKey = '@self';
  static const String userKey = '@user';

  final Map<String, int> _tokenToId = {};
  final List<TokenAssembly04> assemblies = [];
  final Map<int, Map<int, PlasticEdge04>> temporal = {};
  final Map<int, Map<int, PlasticEdge04>> associative = {};
  final List<int> workingMemory = [];

  final Map<String, int> _entityKeyToId = {};
  final List<EntityMemory04> entities = [];
  final Map<String, int> _relationKeyToId = {};
  final Map<int, int> relationRedirect = {};
  final List<RelationMemory04> relations = [];
  final Map<String, RelationSlot04> slots = {};
  final Map<String, List<LexicalSense028>> lexicalSenses028 = {};
  final Map<String, ResponseSlot028> responseAttractors028 = {};
  // 0.31: surface realization is learned from experience, not hard-coded per verb.
  // Entity forms preserve determiners (e.g. "il gatto"); relation frames preserve
  // the bridge between subject and object (e.g. "corre nel").
  final Map<int, Map<String, int>> entitySurfaceForms031 = {};
  final Map<int, Map<String, int>> relationSurfaceFrames031 = {};
  final List<Episode04> episodes = [];
  List<Concept04> concepts = [];
  final Map<int, Set<int>> _relationCompositions = {};
  bool _developmentalPriorsInstalled = false;

  int step = 0;
  int _nextEpisodeId = 1;
  int _nextConceptId = 1;
  double noveltyEma = 0;
  double predictionErrorEma = 0;
  double curiosity = 0;
  double entropicAge = 0;
  double lastFlux = 0;

  PlasticLanguageBrain04() {
    _ensureToken('<bos>', '<BOS>');
    _ensureToken('<eos>', '<EOS>');
    _ensureEntity(selfKey, 'SELF', 'self');
    _ensureEntity(userKey, 'UTENTE', 'user');
    _installDevelopmentalPriors();
  }

  int get selfId => _entityKeyToId[selfKey]!;
  int get userId => _entityKeyToId[userKey]!;

  static String normalizeText(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String canonicalObject(String input) {
    return normalizeText(input)
        .replaceAll(RegExp(r'^[\s,.:;!?]+|[\s,.:;!?]+$'), '');
  }

  static List<String> lexicalTokens(String input) {
    final text = input.replaceAll('’', "'");
    final rx =
        RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ0-9]+(?:'[A-Za-zÀ-ÖØ-öø-ÿ0-9]+)?|[?.!,;:]");
    return rx.allMatches(text).map((m) => m.group(0)!).toList();
  }

  static String _stem(String input) {
    var s = normalizeText(input);
    if (s.length <= 3) return s;
    const suffixes = [
      'erebbero',
      'irebbero',
      'assero',
      'essero',
      'issero',
      'eranno',
      'iranno',
      'ando',
      'endo',
      'iamo',
      'iate',
      'avate',
      'evate',
      'ivate',
      'ano',
      'ono',
      'ava',
      'eva',
      'iva',
      'ato',
      'uto',
      'ito',
      'are',
      'ere',
      'ire',
      'arsi',
      'ermi',
      'erti',
      'irsi',
      'ando',
      'endo',
      'iamo',
      'chiami',
      'chiamo',
      'iamo',
      'ate',
      'ete',
      'ite',
      'ano',
      'ono',
      'a',
      'e',
      'i',
      'o',
    ];
    for (final suf in suffixes) {
      if (s.length - suf.length >= 3 && s.endsWith(suf)) {
        s = s.substring(0, s.length - suf.length);
        break;
      }
    }
    return s;
  }

  int _hash(String s) {
    var h = 2166136261;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0x7fffffff;
    }
    return h;
  }

  Uint32List _vectorFor(String key) {
    var state = (_hash(key) ^ 0x6d2b79f5) & 0x7fffffff;
    final v = Uint32List(vectorWords);
    for (var i = 0; i < vectorWords; i++) {
      state ^= (state << 13) & 0x7fffffff;
      state ^= (state >> 17);
      state ^= (state << 5) & 0x7fffffff;
      final a = state & 0x7fffffff;
      state = (1103515245 * state + 12345) & 0x7fffffff;
      final b = state & 0x7fffffff;
      v[i] = ((a << 1) ^ b) & 0xffffffff;
    }
    return v;
  }

  Uint32List _xor(Uint32List a, Uint32List b) {
    final out = Uint32List(vectorWords);
    for (var i = 0; i < vectorWords; i++) {
      out[i] = a[i] ^ b[i];
    }
    return out;
  }

  int _popCount32(int x) {
    var v = x & 0xffffffff;
    v = v - ((v >> 1) & 0x55555555);
    v = (v & 0x33333333) + ((v >> 2) & 0x33333333);
    v = (v + (v >> 4)) & 0x0f0f0f0f;
    v = v + (v >> 8);
    v = v + (v >> 16);
    return v & 0x3f;
  }

  double _hammingSimilarity(Uint32List a, Uint32List b) {
    var distance = 0;
    for (var i = 0; i < vectorWords; i++) {
      distance += _popCount32(a[i] ^ b[i]);
    }
    return 1.0 - distance / (vectorWords * 32.0);
  }

  Uint32List _bundle(List<Uint32List> vectors) {
    if (vectors.isEmpty) return Uint32List(vectorWords);
    final out = Uint32List(vectorWords);
    for (var w = 0; w < vectorWords; w++) {
      var word = 0;
      for (var bit = 0; bit < 32; bit++) {
        var ones = 0;
        final mask = 1 << bit;
        for (final v in vectors) {
          if ((v[w] & mask) != 0) ones++;
        }
        if (ones * 2 >= vectors.length) word |= mask;
      }
      out[w] = word;
    }
    return out;
  }

  BindingFrame04 makeBindingFrame({
    required int subjectId,
    required int relationId,
    String? objectKey,
    bool isQuery = false,
  }) {
    final s = _xor(_vectorFor('role:subject'),
        _vectorFor('entity:${entities[subjectId].key}'));
    final r = _xor(_vectorFor('role:relation'),
        _vectorFor('relation:${relations[relationId].key}'));
    Uint32List? o;
    if (objectKey != null) {
      o = _xor(_vectorFor('role:object'), _vectorFor('object:$objectKey'));
    }
    final composite = _bundle([s, r, if (o != null) o]);
    return BindingFrame04(
      subjectId: subjectId,
      relationId: relationId,
      objectKey: objectKey,
      isQuery: isQuery,
      subjectBinding: s,
      relationBinding: r,
      objectBinding: o,
      composite: composite,
    );
  }

  int _ensureToken(String normalized, String surface) {
    final old = _tokenToId[normalized];
    if (old != null) {
      assemblies[old].surface = surface;
      return old;
    }
    final id = assemblies.length;
    assemblies
        .add(TokenAssembly04(id: id, token: normalized, surface: surface));
    _tokenToId[normalized] = id;
    return id;
  }

  ({List<int> ids, int newTokens}) encode(String text, {bool create = true}) {
    final ids = <int>[];
    var added = 0;
    for (final surface in lexicalTokens(text)) {
      final n = normalizeText(surface);
      var id = _tokenToId[n];
      if (id == null && create) {
        id = _ensureToken(n, surface);
        added++;
      }
      if (id != null) ids.add(id);
    }
    return (ids: ids, newTokens: added);
  }

  int _ensureEntity(String key, String label, String kind) {
    final canonical = normalizeText(key);
    final old = _entityKeyToId[canonical];
    if (old != null) {
      if (label.trim().isNotEmpty && kind != 'self' && kind != 'user') {
        entities[old].label = label.trim();
      }
      return old;
    }
    final id = entities.length;
    final e =
        EntityMemory04(id: id, key: canonical, label: label.trim(), kind: kind);
    if (label.trim().isNotEmpty) e.aliases.add(normalizeText(label));
    entities.add(e);
    _entityKeyToId[canonical] = id;
    return id;
  }

  int _entityForText(String text, {String kind = 'entity'}) {
    final clean = canonicalObject(text);
    final n = normalizeText(clean);
    final indexed = _entityKeyToId[n];
    if (indexed != null) return indexed;
    for (final e in entities) {
      if (e.aliases.contains(n) || normalizeText(e.label) == n) return e.id;
    }
    return _ensureEntity(n, _titleCase(clean), kind);
  }

  Set<String> _semanticTerms028(String text) {
    const stops = <String>{
      'il',
      'lo',
      'la',
      'i',
      'gli',
      'le',
      'un',
      'uno',
      'una',
      'di',
      'del',
      'della',
      'dei',
      'degli',
      'delle',
      'a',
      'al',
      'alla',
      'ai',
      'agli',
      'alle',
      'da',
      'dal',
      'dalla',
      'in',
      'nel',
      'nella',
      'con',
      'su',
      'per',
      'tra',
      'fra',
      'e',
      'o',
      'ma',
      'che',
      'chi',
      'cosa',
      'come',
      'quando',
      'dove',
      'perche',
      'perché',
      'questo',
      'questa',
      'questi',
      'queste',
      'è',
      'sono',
      'sei',
      'era',
      'essere',
      'ha',
      'ho',
      'hai',
      'hanno'
    };
    return lexicalTokens(text)
        .map(normalizeText)
        .where((x) => x.length >= 3 && !stops.contains(x))
        .toSet();
  }

  String _senseEntityLabel028(String label, String gloss) {
    final clean = label.trim().isEmpty ? 'Senso' : _titleCase(label.trim());
    final g = gloss.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (g.isEmpty) return clean;
    final short = g.length <= 54 ? g : '${g.substring(0, 51)}…';
    return '$clean · $short';
  }

  int registerLexicalSense028({
    required String surface,
    required String senseKey,
    String? label,
    String gloss = '',
    double confidence = 0.45,
    Iterable<String> contextCues = const <String>[],
  }) {
    final lexeme = normalizeText(surface);
    final sk = normalizeText(senseKey);
    if (lexeme.isEmpty || sk.isEmpty) return _entityForText(surface);

    // Keep a lexical hub distinct from its possible meanings.
    final hubId = _entityForText(surface, kind: 'lexeme');
    if (entities[hubId].kind != 'self' && entities[hubId].kind != 'user') {
      entities[hubId].kind = 'lexeme';
    }

    final list =
        lexicalSenses028.putIfAbsent(lexeme, () => <LexicalSense028>[]);
    LexicalSense028? existing;
    for (final x in list) {
      if (normalizeText(x.senseKey) == sk) {
        existing = x;
        break;
      }
    }

    final senseLabel = (label ?? surface).trim().isEmpty
        ? surface.trim()
        : (label ?? surface).trim();
    final cues = <String>{..._semanticTerms028(gloss)};
    for (final c in contextCues) {
      cues.addAll(_semanticTerms028(c));
    }

    if (existing != null) {
      existing.supports++;
      existing.confidence =
          max(existing.confidence, confidence.clamp(0.0, 1.0).toDouble());
      if (gloss.trim().isNotEmpty) existing.gloss = gloss.trim();
      if (senseLabel.isNotEmpty) existing.label = senseLabel;
      existing.contextCues.addAll(cues);
      final e = entities[existing.entityId];
      e.aliases
        ..add(lexeme)
        ..add(normalizeText(senseLabel));
      e.label = _senseEntityLabel028(existing.label, existing.gloss);
      return existing.entityId;
    }

    final entityKey = '@sense:$lexeme:$sk';
    final entityId = _ensureEntity(
      entityKey,
      _senseEntityLabel028(senseLabel, gloss),
      'sense',
    );
    entities[entityId].aliases
      ..add(lexeme)
      ..add(normalizeText(senseLabel));
    list.add(LexicalSense028(
      lexeme: lexeme,
      senseKey: senseKey,
      entityId: entityId,
      label: senseLabel,
      gloss: gloss.trim(),
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
      contextCues: cues,
    ));
    return entityId;
  }

  List<LexicalSense028> senseCandidates028(String surface,
      {String context = ''}) {
    final n = normalizeText(surface);
    final words = _semanticTerms028('$surface $context');
    final candidates = <LexicalSense028>[];
    for (final entry in lexicalSenses028.entries) {
      final lexeme = entry.key;
      final present = n == lexeme ||
          RegExp('(^|[^a-zà-ÿ0-9])' +
                  RegExp.escape(lexeme) +
                  r'([^a-zà-ÿ0-9]|$)')
              .hasMatch(n);
      if (!present) continue;
      candidates.addAll(entry.value);
    }
    candidates.sort((a, b) {
      double score(LexicalSense028 x) {
        final overlap = words.isEmpty
            ? 0.0
            : words.intersection(x.contextCues).length /
                max(1, words.union(x.contextCues).length);
        return 0.68 * x.confidence +
            0.24 * overlap +
            0.08 * min(1.0, x.supports / 4.0);
      }

      return score(b).compareTo(score(a));
    });
    return candidates;
  }

  int? resolveSenseEntity028(String surface, {String context = ''}) {
    final xs = senseCandidates028(surface, context: context);
    if (xs.isEmpty) return null;
    if (xs.length == 1) return xs.first.entityId;
    final terms = _semanticTerms028('$surface $context');
    double score(LexicalSense028 x) {
      final overlap = terms.isEmpty
          ? 0.0
          : terms.intersection(x.contextCues).length /
              max(1, terms.union(x.contextCues).length);
      return 0.68 * x.confidence +
          0.24 * overlap +
          0.08 * min(1.0, x.supports / 4.0);
    }

    final a = score(xs[0]);
    final b = score(xs[1]);
    if (terms.intersection(xs[0].contextCues).isNotEmpty && a >= b + 0.04)
      return xs[0].entityId;
    if (a >= b + 0.14) return xs[0].entityId;
    return null; // ambiguous on purpose: keep the lexical hub active.
  }

  String _titleCase(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  int _canonicalRelation(int id) {
    var current = id;
    final seen = <int>{};
    while (relationRedirect.containsKey(current) && seen.add(current)) {
      current = relationRedirect[current]!;
    }
    return current;
  }

  int _ensureRelation(List<String> cues, {String? preferredLabel}) {
    final clean = cues.where((e) => e.isNotEmpty).toSet().toList()..sort();
    final key = clean.isEmpty ? 'rel:unknown' : 'rel:${clean.join('+')}';
    final old = _relationKeyToId[key];
    if (old != null) {
      final r = relations[old];
      for (final cue in clean) {
        r.cues[cue] = (r.cues[cue] ?? 0) + 1;
      }
      r.uses++;
      return old;
    }
    final id = relations.length;
    final label = preferredLabel?.trim().isNotEmpty == true
        ? preferredLabel!.trim()
        : (clean.isEmpty ? 'relazione' : clean.join('/'));
    final r = RelationMemory04(id: id, key: key, label: label, uses: 1);
    for (final cue in clean) {
      r.cues[cue] = 1;
    }
    relations.add(r);
    _relationKeyToId[key] = id;
    return id;
  }

  int _relationFromCues(List<String> cues, {bool create = true}) {
    final clean = cues.where((e) => e.isNotEmpty).toSet().toList();
    if (clean.isEmpty) return create ? _ensureRelation(const ['unknown']) : -1;

    for (final cue in clean) {
      if (cue.startsWith('sem:')) {
        final family = cue.substring(4);
        return create
            ? _ensureSemanticRelation(family, extraCues: clean)
            : (_relationKeyToId['sem:$family'] ?? -1);
      }
    }
    final families = clean.map(_semanticFamilyOf).whereType<String>().toSet();
    if (families.length == 1) {
      final family = families.first;
      if (create) return _ensureSemanticRelation(family, extraCues: clean);
      return _relationKeyToId['sem:$family'] ?? -1;
    }

    var best = -1;
    var bestScore = 0.0;
    final set = clean.toSet();
    for (final r in relations) {
      if (_canonicalRelation(r.id) != r.id) continue;
      final rs = r.cues.keys.toSet();
      if (rs.isEmpty) continue;
      final inter = rs.intersection(set).length;
      final union = rs.union(set).length;
      final jaccard = union == 0 ? 0.0 : inter / union;
      var weighted = 0.0;
      for (final c in clean) {
        weighted += min(1.0, (r.cues[c] ?? 0) / 3.0);
      }
      weighted /= max(1, clean.length);
      final score = 0.65 * jaccard + 0.35 * weighted;
      if (score > bestScore) {
        bestScore = score;
        best = r.id;
      }
    }
    if (best >= 0 && bestScore >= 0.38) {
      best = _canonicalRelation(best);
      final r = relations[best];
      for (final c in clean) {
        r.cues[c] = (r.cues[c] ?? 0) + 0.25;
      }
      r.uses++;
      return best;
    }
    return create ? _ensureRelation(clean) : -1;
  }

  void _mergeRelations(int keepId, int mergeId) {
    if (keepId == mergeId ||
        keepId < 0 ||
        mergeId < 0 ||
        keepId >= relations.length ||
        mergeId >= relations.length) return;
    final keep = relations[keepId];
    final other = relations[mergeId];
    for (final e in other.cues.entries) {
      keep.cues[e.key] = (keep.cues[e.key] ?? 0) + e.value;
    }
    keep.uses += other.uses;
    keep.multiValued = keep.multiValued || other.multiValued;

    final affected =
        slots.values.where((s) => s.relationId == mergeId).toList();
    for (final slot in affected) {
      final targetKey = '${slot.subjectId}::$keepId';
      final target = slots.putIfAbsent(targetKey,
          () => RelationSlot04(subjectId: slot.subjectId, relationId: keepId));
      for (final c in slot.candidates.values) {
        final old = target.candidates[c.objectKey];
        if (old == null) {
          target.candidates[c.objectKey] = c;
        } else {
          old.confidence = max(old.confidence, c.confidence);
          old.supports += c.supports;
          old.contradictions += c.contradictions;
          old.sourceEpisodes.addAll(c.sourceEpisodes);
          old.lastStep = max(old.lastStep, c.lastStep);
        }
      }
      slots.remove(slot.key);
    }
    relationRedirect[mergeId] = keepId;
    _relationKeyToId[other.key] = keepId;
  }

  String? _legacyFamilyForRelation(
      RelationMemory04 relation, List<RelationSlot04> relationSlots) {
    if (relation.key.startsWith('sem:')) return relation.key.substring(4);
    final direct = _semanticFamilyOf(relation.label);
    if (direct != null) return direct;
    for (final cue in relation.cues.keys) {
      final family = _semanticFamilyOf(cue);
      if (family != null) return family;
    }

    final label = normalizeText(relation.label);
    final cueText = relation.cues.keys.map(normalizeText).join(' ');
    final looksLikeFigl = label.startsWith('figl') || cueText.contains('figl');
    if (looksLikeFigl) {
      if (label == 'figli' || label == 'figlie') return 'children';
      for (final slot in relationSlots) {
        for (final c in slot.candidates.values) {
          if (_splitObjectValues(c.display).length > 1) return 'children';
        }
      }
    }
    return null;
  }

  void repairSemanticMemory() {
    if (relations.isEmpty || slots.isEmpty) return;

    final canonicalRelations =
        relations.where((r) => _canonicalRelation(r.id) == r.id).toList();
    for (final relation in canonicalRelations) {
      final relationSlots = slots.values
          .where((s) => _canonicalRelation(s.relationId) == relation.id)
          .toList();
      if (relationSlots.isEmpty) continue;
      final family = _legacyFamilyForRelation(relation, relationSlots);
      if (family == null) continue;
      final targetId =
          _ensureSemanticRelation(family, extraCues: relation.cues.keys);
      relations[targetId].multiValued = relations[targetId].multiValued ||
          _multiSemanticRelations.contains(family);

      for (final slot in relationSlots) {
        final targetKey = '${slot.subjectId}::$targetId';
        final target = slots.putIfAbsent(
          targetKey,
          () => RelationSlot04(subjectId: slot.subjectId, relationId: targetId),
        );

        for (final c in slot.candidates.values) {
          final values = _relationIsMulti(targetId)
              ? _splitObjectValues(c.display)
              : <String>[c.display];
          for (final value in values) {
            final key = canonicalObject(value);
            if (key.isEmpty) continue;
            final existing = target.candidates[key];
            if (existing == null) {
              target.candidates[key] = FactCandidate04(
                objectKey: key,
                display: _titleCase(value),
                confidence: c.confidence,
                supports: c.supports,
                contradictions:
                    _relationIsMulti(targetId) ? 0 : c.contradictions,
                lastStep: c.lastStep,
                sourceEpisodes: {...c.sourceEpisodes},
              );
            } else {
              existing.confidence = max(existing.confidence, c.confidence);
              existing.supports += c.supports;
              if (!_relationIsMulti(targetId)) {
                existing.contradictions += c.contradictions;
              }
              existing.lastStep = max(existing.lastStep, c.lastStep);
              existing.sourceEpisodes.addAll(c.sourceEpisodes);
            }
          }
        }

        if (slot.key != targetKey) slots.remove(slot.key);
      }

      if (relation.id != targetId) {
        relationRedirect[relation.id] = targetId;
        _relationKeyToId[relation.key] = targetId;
      }
    }

    // Normalize already-semantic multi-valued slots that may still contain
    // legacy concatenated objects such as "Cloe e Dante".
    final multiSlots =
        slots.values.where((s) => _relationIsMulti(s.relationId)).toList();
    for (final slot in multiSlots) {
      final expanded = <String, FactCandidate04>{};
      for (final c in slot.candidates.values) {
        final values = _splitObjectValues(c.display);
        for (final value in values) {
          final key = canonicalObject(value);
          final existing = expanded[key];
          if (existing == null) {
            expanded[key] = FactCandidate04(
              objectKey: key,
              display: _titleCase(value),
              confidence: c.confidence,
              supports: c.supports,
              contradictions: 0,
              lastStep: c.lastStep,
              sourceEpisodes: {...c.sourceEpisodes},
            );
          } else {
            existing.confidence = max(existing.confidence, c.confidence);
            existing.supports += c.supports;
            existing.lastStep = max(existing.lastStep, c.lastStep);
            existing.sourceEpisodes.addAll(c.sourceEpisodes);
          }
        }
      }
      slot.candidates
        ..clear()
        ..addAll(expanded);
    }
  }

  static const Set<String> _questionWords = {
    'come',
    'cosa',
    'che',
    'chi',
    'quale',
    'qual',
    'quanto',
    'dove',
    'quando',
    'perché',
    'perche',
  };

  static const Set<String> _grammarStops = {
    'il',
    'lo',
    'la',
    'i',
    'gli',
    'le',
    'un',
    'uno',
    'una',
    'del',
    'dello',
    'della',
    'dei',
    'degli',
    'delle',
    'di',
    'a',
    'da',
    'in',
    'con',
    'su',
    'per',
    'tra',
    'fra',
    'e',
    'o',
    'ma',
    'che',
    'se',
    'io',
    'mi',
    'me',
    'mio',
    'mia',
    'miei',
    'mie',
    'tu',
    'ti',
    'te',
    'tuo',
    'tua',
    'tuoi',
    'tue',
    'lui',
    'lei',
    'loro',
    'si',
    'suo',
    'sua',
    'suoi',
    'sue',
    'questo',
    'questa',
    'quello',
    'quella',
    'come',
    'cosa',
    'chi',
    'quale',
    'qual',
    'quanto',
    'dove',
    'quando',
    'perché',
    'perche',
    '?',
    '.',
    ',',
    '!',
    ';',
    ':',
  };

  double _featureWeight(String feature) {
    if (feature.startsWith('lex:')) return 1.0;
    if (feature.startsWith('verb:')) return 0.95;
    if (feature.startsWith('bi:')) return 0.72;
    if (feature.startsWith('q:')) return 0.28;
    if (feature == 'ctx:deictic') return 0.45;
    if (feature == 'frame:deictic-bare') return 1.10;
    if (feature == 'mode:q') return 0.08;
    return 0.35;
  }

  List<String> _relationAttractorFeatures(
    List<String> surfaces, {
    required bool isQuestion,
    required int? subjectId,
    required int verbIndex,
  }) {
    final ns = surfaces.map(normalizeText).toList();
    final candidates = <String>[];

    Iterable<int> indices;
    if (isQuestion) {
      indices = List<int>.generate(ns.length, (i) => i);
    } else if (verbIndex >= 0) {
      indices = List<int>.generate(verbIndex + 1, (i) => i);
    } else {
      indices = List<int>.generate(ns.length, (i) => i);
    }

    final explicitSubjectWords = <String>{};
    if (subjectId != null &&
        subjectId != userId &&
        subjectId != selfId &&
        subjectId < entities.length) {
      final e = entities[subjectId];
      explicitSubjectWords.addAll(lexicalTokens(e.label).map(normalizeText));
      for (final a in e.aliases) {
        explicitSubjectWords.addAll(lexicalTokens(a).map(normalizeText));
      }
    }

    final contentForBigrams = <String>[];
    var hasDeictic = false;
    const firstSecond = {
      'io',
      'mi',
      'me',
      'mio',
      'mia',
      'miei',
      'mie',
      'tu',
      'ti',
      'te',
      'tuo',
      'tua',
      'tuoi',
      'tue',
      'nostro',
      'nostra',
      'nostri',
      'nostre'
    };

    for (final i in indices) {
      if (i < 0 || i >= ns.length) continue;
      final n = ns[i];
      if ({'?', '.', ',', '!', ';', ':'}.contains(n)) continue;
      if (firstSecond.contains(n)) {
        hasDeictic = true;
        continue;
      }
      if (explicitSubjectWords.contains(n)) continue;
      if (_questionWords.contains(n)) {
        candidates.add('q:$n');
        continue;
      }

      final isVerb = i == verbIndex || _looksLikeVerb(n);
      if (isVerb) {
        final stem = _stem(n);
        if (stem.isNotEmpty) {
          candidates.add('verb:$stem');
          contentForBigrams.add('v:$stem');
        }
        continue;
      }

      if (_grammarStops.contains(n)) continue;
      if (n.length < 2) continue;
      candidates.add('lex:$n');
      contentForBigrams.add('l:$n');
    }

    if (isQuestion) candidates.add('mode:q');
    if (hasDeictic || subjectId == userId || subjectId == selfId) {
      candidates.add('ctx:deictic');
      final hasLexicalRole = candidates.any((f) => f.startsWith('lex:'));
      if (!hasLexicalRole) candidates.add('frame:deictic-bare');
    }

    for (var i = 0; i + 1 < contentForBigrams.length; i++) {
      candidates.add('bi:${contentForBigrams[i]}>${contentForBigrams[i + 1]}');
    }

    return candidates.toSet().toList();
  }

  int _hiddenFeatureToken(String feature) {
    final key = '<f:$feature>';
    return _ensureToken(key, key);
  }

  int _relationAnchorToken(int relationId) {
    final key = '<rel:$relationId>';
    return _ensureToken(key, key);
  }

  void _primeAttractorEdge(int relationId, String feature, double strength) {
    final changes = <_EdgeChange04>[];
    final f = _hiddenFeatureToken(feature);
    final r = _relationAnchorToken(relationId);
    for (final pair in [(f, r), (r, f)]) {
      final e = _edge(associative, pair.$1, pair.$2, changes);
      e.fast = max(e.fast, 0.70 * strength);
      e.slow = max(e.slow, 0.38 * strength);
      e.meta = max(e.meta, 0.12 * strength);
      e.cost = min(e.cost, 0.72 - 0.22 * strength);
      e.uses = max(e.uses, 2);
    }
  }

  void _trainRelationAttractor(
      int relationId, Iterable<String> features, double reward) {
    if (relationId < 0 || relationId >= relations.length) return;
    final id = _canonicalRelation(relationId);
    final relation = relations[id];
    final anchor = _relationAnchorToken(id);
    final changes = <_EdgeChange04>[];
    for (final feature in features.toSet()) {
      relation.cues[feature] =
          (relation.cues[feature] ?? 0) + max(0.05, reward.abs());
      final f = _hiddenFeatureToken(feature);
      final a = _edge(associative, f, anchor, changes);
      final b = _edge(associative, anchor, f, changes);
      changes.add(
          _updateEdge(a, reward: reward, coactivity: _featureWeight(feature)));
      changes.add(_updateEdge(b,
          reward: reward * 0.85, coactivity: _featureWeight(feature)));
    }
  }

  double _relationAttractorScore(int relationId, Iterable<String> features) {
    if (relationId < 0 || relationId >= relations.length) return 0;
    final id = _canonicalRelation(relationId);
    final relation = relations[id];
    final fs = features.toSet();
    if (fs.isEmpty) return 0;
    final anchor = _tokenToId['<rel:$id>'];

    var numerator = 0.0;
    var inputMass = 0.0;
    var prototypeMass = 0.0;
    for (final feature in fs) {
      final w = _featureWeight(feature);
      inputMass += w;
      final cue = min(1.0, (relation.cues[feature] ?? 0) / 3.0);
      var edge = 0.0;
      if (anchor != null) {
        final f = _tokenToId['<f:$feature>'];
        if (f != null) {
          final e = associative[f]?[anchor];
          if (e != null) edge = _strength(e).clamp(0.0, 1.0).toDouble();
        }
      }
      numerator += w * (0.48 * cue + 0.52 * edge);
    }

    for (final entry in relation.cues.entries) {
      if (!entry.key.startsWith('lex:') &&
          !entry.key.startsWith('verb:') &&
          !entry.key.startsWith('bi:') &&
          !entry.key.startsWith('q:') &&
          entry.key != 'ctx:deictic' &&
          entry.key != 'mode:q') {
        continue;
      }
      prototypeMass += _featureWeight(entry.key) * min(1.0, entry.value / 3.0);
    }

    if (inputMass <= 0) return 0;
    final coverage = numerator / inputMass;
    final specificity = prototypeMass <= 0
        ? coverage
        : numerator / sqrt(max(0.0001, inputMass * prototypeMass));
    final usePrior = min(0.08, log(1 + relation.uses) * 0.012);
    var score = 0.68 * coverage + 0.32 * specificity + usePrior;

    // Contrastive lexical gating. If both the input and the attractor carry
    // concrete role words, an exact lexical match must matter more than
    // generic question/verb context. This prevents nearby forms such as
    // figlio / figlia / figli from collapsing into one attractor while still
    // allowing genuinely paraphrastic relations (e.g. partner/moglie) whose
    // prototype has learned both surface forms.
    final inputLex = fs.where((f) => f.startsWith('lex:')).toSet();
    final prototypeLex =
        relation.cues.keys.where((f) => f.startsWith('lex:')).toSet();
    if (inputLex.isNotEmpty && prototypeLex.isNotEmpty) {
      final overlap = inputLex.intersection(prototypeLex);
      if (overlap.isEmpty) {
        score *= 0.24;
      } else {
        final lexicalAgreement = overlap.length / inputLex.length;
        score += 0.12 * lexicalAgreement;
      }
    }

    return score.clamp(0.0, 1.0).toDouble();
  }

  int _createLatentRelation(List<String> features, {String? preferredLabel}) {
    final distinctive = features
        .where((f) => f.startsWith('verb:') || f.startsWith('lex:'))
        .toList();
    final label = preferredLabel ??
        (distinctive.isEmpty
            ? 'relazione ${relations.length + 1}'
            : distinctive.first.split(':').last);
    final id = relations.length;
    final key = 'latent:auto:$id';
    final r = RelationMemory04(id: id, key: key, label: label, uses: 1);
    relations.add(r);
    _relationKeyToId[key] = id;
    for (final feature in features.toSet()) {
      r.cues[feature] = 3.0;
      _primeAttractorEdge(id, feature, 0.96);
    }
    return id;
  }

  int _relationFromAttractor(
    List<String> features, {
    required bool create,
    double threshold = 0.40,
  }) {
    if (features.isEmpty) return create ? _createLatentRelation(const []) : -1;
    var best = -1;
    var second = -1;
    var bestScore = 0.0;
    var secondScore = 0.0;

    for (final r in relations) {
      if (_canonicalRelation(r.id) != r.id) continue;
      final score = _relationAttractorScore(r.id, features);
      if (score > bestScore) {
        second = best;
        secondScore = bestScore;
        best = r.id;
        bestScore = score;
      } else if (score > secondScore) {
        second = r.id;
        secondScore = score;
      }
    }

    final margin = bestScore - secondScore;
    if (best >= 0 &&
        bestScore >= threshold &&
        (margin >= 0.010 || bestScore >= 0.68)) {
      relations[best].uses++;
      return best;
    }
    return create ? _createLatentRelation(features) : -1;
  }

  int _ensureDevelopmentalRelation(
    String legacyFamily,
    String label,
    List<String> examples, {
    bool multiValued = false,
  }) {
    int? id = _relationKeyToId['latent:$legacyFamily'];
    id ??= _relationKeyToId['sem:$legacyFamily'];
    if (id == null) {
      id = relations.length;
      relations.add(RelationMemory04(
        id: id,
        key: 'latent:$legacyFamily',
        label: label,
        uses: 1,
        multiValued: multiValued,
      ));
      _relationKeyToId['latent:$legacyFamily'] = id;
    } else {
      id = _canonicalRelation(id);
      relations[id].label = label;
      relations[id].multiValued = relations[id].multiValued || multiValued;
      _relationKeyToId['latent:$legacyFamily'] = id;
    }

    for (final example in examples) {
      final surfaces = lexicalTokens(example);
      final ns = surfaces.map(normalizeText).toList();
      final isQuestion = normalizeText(example).endsWith('?') ||
          ns.any(_questionWords.contains);
      final subject = _resolveDeicticSubject(surfaces, speaker: 'user');
      final verbIndex = _findVerbIndex(surfaces, isQuestion: isQuestion);
      final features = _relationAttractorFeatures(
        surfaces,
        isQuestion: isQuestion,
        subjectId: subject,
        verbIndex: verbIndex,
      );
      for (final feature in features) {
        relations[id].cues[feature] = (relations[id].cues[feature] ?? 0) + 0.65;
        _primeAttractorEdge(id, feature, 0.88);
      }
    }
    return id;
  }

  void _installDevelopmentalPriors() {
    if (_developmentalPriorsInstalled) return;
    _developmentalPriorsInstalled = true;
    _relationCompositions.clear();

    final identity = _ensureDevelopmentalRelation('name', 'identità', const [
      'come mi chiamo?',
      'qual è il mio nome?',
      'io chi sono?',
      'mi chiamo qualcuno',
      'io sono qualcuno',
      'come ti chiami?',
      'qual è il tuo nome?',
      'tu chi sei?',
      'ti chiami qualcuno',
      'tu sei qualcuno',
    ]);

    final partner = _ensureDevelopmentalRelation('partner', 'partner', const [
      'come si chiama la mia compagna?',
      'chi è mia moglie?',
      'chi è il mio partner?',
      'la mia compagna si chiama qualcuno',
      'mia moglie è qualcuno',
    ]);

    final daughter = _ensureDevelopmentalRelation('daughter', 'figlia', const [
      'come si chiama mia figlia?',
      'mia figlia come si chiama?',
      'chi è mia figlia?',
      'mia figlia è qualcuno',
      'mia figlia si chiama qualcuno',
    ]);

    final son = _ensureDevelopmentalRelation('son', 'figlio', const [
      'come si chiama mio figlio?',
      'mio figlio come si chiama?',
      'chi è mio figlio?',
      'mio figlio è qualcuno',
      'mio figlio si chiama qualcuno',
    ]);

    final children = _ensureDevelopmentalRelation(
        'children',
        'figli',
        const [
          'come si chiamano i miei figli?',
          'i miei figli come si chiamano?',
          'chi sono i miei figli?',
          'quali sono i nomi dei miei figli?',
          'i miei figli sono qualcuno e qualcuno',
        ],
        multiValued: true);

    final sister = _ensureDevelopmentalRelation('sister', 'sorella', const [
      'chi è mia sorella?',
      'come si chiama mia sorella?',
      'mia sorella è qualcuno',
    ]);
    final brother = _ensureDevelopmentalRelation('brother', 'fratello', const [
      'chi è mio fratello?',
      'come si chiama mio fratello?',
      'mio fratello è qualcuno',
    ]);
    final siblings = _ensureDevelopmentalRelation(
        'siblings',
        'fratelli/sorelle',
        const [
          'chi sono i miei fratelli?',
          'come si chiamano i miei fratelli?',
          'chi sono i miei fratelli e sorelle?',
        ],
        multiValued: true);

    _ensureDevelopmentalRelation('mother', 'madre', const [
      'chi è mia madre?',
      'come si chiama mia madre?',
      'mia madre è qualcuno',
    ]);
    _ensureDevelopmentalRelation('father', 'padre', const [
      'chi è mio padre?',
      'come si chiama mio padre?',
      'mio padre è qualcuno',
    ]);

    // A generic copular/property attractor gives the system a learned path
    // for statements such as "il cane è animale" without hard-coded ontology.
    _ensureDevelopmentalRelation('generic-is', 'è', const [
      'il cane è animale',
      'che cosa è il cane?',
      'cosa è il cane?',
      'il gatto è animale',
    ]);

    _relationCompositions[children] = {daughter, son};
    _relationCompositions[siblings] = {sister, brother};

    // Keep these references alive in the learned graph; no runtime branches use them.
    if (identity == partner) {
      // Impossible, but prevents over-aggressive compiler tree assumptions in debug builds.
      relations[identity].uses++;
    }
  }

  static const Map<String, Set<String>> _semanticCueFamilies = {
    'name': {
      'nome',
      'nomi',
      'nomin',
      'chiam',
      'chiama',
      'chiami',
      'chiamo',
      'chiamano',
      'chiamate',
      'chiamarsi',
      'chiamato',
      'chiamata',
      'chiamero',
      'chiamerò',
    },
    'partner': {
      'compagna',
      'compagno',
      'partner',
      'fidanzata',
      'fidanzato',
      'moglie',
      'marito',
      'coniuge',
    },
    'daughter': {'figlia'},
    'son': {'figlio'},
    'children': {'figli', 'figlie', 'bambini', 'bambine'},
    'mother': {'madre', 'mamma'},
    'father': {'padre', 'papa', 'papà', 'babbo'},
    'sister': {'sorella'},
    'brother': {'fratello'},
    'siblings': {'fratelli', 'sorelle'},
  };

  static const Map<String, String> _semanticLabels = {
    'name': 'nome',
    'partner': 'partner',
    'daughter': 'figlia',
    'son': 'figlio',
    'children': 'figli',
    'mother': 'madre',
    'father': 'padre',
    'sister': 'sorella',
    'brother': 'fratello',
    'siblings': 'fratelli/sorelle',
  };

  static const Set<String> _multiSemanticRelations = {'children', 'siblings'};

  String? _semanticFamilyOf(String raw) {
    final n = normalizeText(raw);
    final stem = _stem(n);

    // 1) Exact surface forms always win. This is crucial for contrasts such
    // as figlia / figlio / figli: a naive prefix match would collapse all
    // three into the same relation and can overwrite NAME facts.
    final exactSurface = <String>{};
    for (final entry in _semanticCueFamilies.entries) {
      if (entry.value.contains(n)) exactSurface.add(entry.key);
    }
    if (exactSurface.length == 1) return exactSurface.first;
    if (exactSurface.length > 1) return null;

    // 2) A stem can map to a family only when that stem is itself an
    // explicitly registered cue (e.g. chiam -> NAME). We do not compare
    // arbitrary stems by prefix because "figl" is intentionally ambiguous.
    final exactStem = <String>{};
    for (final entry in _semanticCueFamilies.entries) {
      if (entry.value.contains(stem)) exactStem.add(entry.key);
    }
    if (exactStem.length == 1) return exactStem.first;
    if (exactStem.length > 1) return null;

    // 3) Conservative forward completion for productive roots such as
    // chiam- and nomin-. Require at least two additional characters so that
    // figlia does not match figli merely because it starts with "figli".
    final forward = <String>{};
    for (final entry in _semanticCueFamilies.entries) {
      for (final cue in entry.value) {
        if (cue.length < 4) continue;
        final surfaceExtension =
            n.startsWith(cue) && n.length >= cue.length + 2;
        final stemExtension =
            stem.startsWith(cue) && stem.length >= cue.length + 2;
        if (surfaceExtension || stemExtension) forward.add(entry.key);
      }
    }
    if (forward.length == 1) return forward.first;
    if (forward.length > 1) return null;

    // 4) Recover legacy truncated stems such as "compan" without collapsing
    // ambiguous roots like "figl" (figlio/figlia/figli).
    if (n.length >= 5 || stem.length >= 5) {
      final reverse = <String>{};
      for (final entry in _semanticCueFamilies.entries) {
        for (final cue in entry.value) {
          if (cue.startsWith(n) || cue.startsWith(stem)) reverse.add(entry.key);
        }
      }
      if (reverse.length == 1) return reverse.first;
    }
    return null;
  }

  int _ensureSemanticRelation(String family,
      {Iterable<String> extraCues = const []}) {
    final key = 'sem:$family';
    final old = _relationKeyToId[key];
    if (old != null) {
      final id = _canonicalRelation(old);
      final r = relations[id];
      r.multiValued = r.multiValued || _multiSemanticRelations.contains(family);
      for (final cue in extraCues) {
        if (cue.trim().isEmpty) continue;
        r.cues[normalizeText(cue)] = (r.cues[normalizeText(cue)] ?? 0) + 0.5;
      }
      r.uses++;
      return id;
    }
    final id = relations.length;
    final r = RelationMemory04(
      id: id,
      key: key,
      label: _semanticLabels[family] ?? family,
      uses: 1,
      multiValued: _multiSemanticRelations.contains(family),
    );
    r.cues['sem:$family'] = 2;
    for (final cue in _semanticCueFamilies[family] ?? const <String>{}) {
      r.cues[cue] = 1;
    }
    for (final cue in extraCues) {
      if (cue.trim().isEmpty) continue;
      r.cues[normalizeText(cue)] = (r.cues[normalizeText(cue)] ?? 0) + 0.5;
    }
    relations.add(r);
    _relationKeyToId[key] = id;
    return id;
  }

  bool _relationIsMulti(int relationId) {
    final id = _canonicalRelation(relationId);
    if (id < 0 || id >= relations.length) return false;
    return relations[id].multiValued;
  }

  List<String> _splitObjectValues(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'[.!?;:]+$'), '');
    if (text.isEmpty) return const [];
    final parts = text
        .split(
            RegExp(r'\s*(?:,|\be\b|\bed\b|\be/o\b)\s*', caseSensitive: false))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? [text] : parts;
  }

  String? _roleFamilyIn(List<String> tokens) {
    for (final raw in tokens) {
      final family = _semanticFamilyOf(raw);
      if (family != null && family != 'name') return family;
    }
    return null;
  }

  int? _resolveDeicticSubject(List<String> tokens, {required String speaker}) {
    final n = tokens.map(normalizeText).toList();
    const first = {'io', 'mi', 'me', 'mio', 'mia', 'miei', 'mie'};
    const second = {'tu', 'ti', 'te', 'tuo', 'tua', 'tuoi', 'tue'};
    if (n.any(first.contains)) return speaker == 'user' ? userId : selfId;
    if (n.any(second.contains)) return speaker == 'user' ? selfId : userId;
    return null;
  }

  bool _looksLikeVerb(String token) {
    final n = normalizeText(token);
    const special = {
      'è',
      'e',
      'sono',
      'sei',
      'era',
      'sarà',
      'sara',
      'ha',
      'ho',
      'hai',
      'hanno'
    };
    if (special.contains(n)) return true;
    if (n.length < 5) return false;
    const endings = [
      'are',
      'ere',
      'ire',
      'ando',
      'endo',
      'iamo',
      'ate',
      'ete',
      'ite',
      'ano',
      'ono',
      'ava',
      'eva',
      'iva',
      'ato',
      'uto',
      'ito',
      'assi',
      'essi',
      'issi',
      'chiama',
      'chiami',
      'chiamo',
      'chiamano',
      'chiamate',
      'chiamarsi',
    ];
    return endings.any((s) => n.length - s.length >= 3 && n.endsWith(s));
  }

  int _findVerbIndex(List<String> tokens, {required bool isQuestion}) {
    final ns = tokens.map(normalizeText).toList();
    const special = {
      'è',
      'e',
      'sono',
      'sei',
      'era',
      'sarà',
      'sara',
      'ha',
      'ho',
      'hai',
      'hanno',
      'aveva'
    };
    for (var i = 0; i < ns.length; i++) {
      if (special.contains(ns[i])) return i;
    }

    // Reflexive/clitic frames provide a language-general local cue without
    // assigning any semantic label to the following verb.
    const clitics = {'mi', 'ti', 'si', 'ci', 'vi'};
    for (var i = 0; i + 1 < ns.length; i++) {
      if (!clitics.contains(ns[i])) continue;
      var j = i + 1;
      while (j < ns.length && _grammarStops.contains(ns[j])) j++;
      if (j < ns.length && !{'?', '.', ',', '!', ';', ':'}.contains(ns[j])) {
        return j;
      }
    }

    for (var i = 0; i < tokens.length; i++) {
      if (_looksLikeVerb(tokens[i])) return i;
    }

    // In a question, the first content word after an interrogative marker is
    // usually the predicate ("cosa mangia il cane?").
    if (isQuestion) {
      for (var i = 0; i < tokens.length; i++) {
        final n = ns[i];
        if (_grammarStops.contains(n) || _questionWords.contains(n)) continue;
        return i;
      }
    }

    const personalPronouns = {'io', 'tu', 'lui', 'lei', 'noi', 'voi', 'loro'};
    if (ns.any(personalPronouns.contains)) {
      for (var i = 0; i < ns.length; i++) {
        if (_grammarStops.contains(ns[i]) || personalPronouns.contains(ns[i]))
          continue;
        return i;
      }
    }

    // Generic S-V-O fallback: first content token is the explicit subject,
    // second content token is the predicate.
    final content = <int>[];
    for (var i = 0; i < ns.length; i++) {
      if (_grammarStops.contains(ns[i]) || _questionWords.contains(ns[i]))
        continue;
      if ({'?', '.', ',', '!', ';', ':'}.contains(ns[i])) continue;
      content.add(i);
    }
    if (content.length >= 2) return content[1];
    if (content.length == 1) return content.first;
    return -1;
  }

  List<String> _relationCuesFromStructure(
      List<String> surfaces, int verbIndex, bool isQuestion) {
    final ns = surfaces.map(normalizeText).toList();

    // Possessive nominal frames such as "qual è il tuo nome?" or "il mio nome è Diego"
    // use the possessed noun as the latent relation, not the copula.
    const possessives = {
      'mio',
      'mia',
      'miei',
      'mie',
      'tuo',
      'tua',
      'tuoi',
      'tue',
      'suo',
      'sua',
      'suoi',
      'sue'
    };
    for (var i = 0; i < ns.length - 1; i++) {
      if (!possessives.contains(ns[i])) continue;
      for (var j = i + 1; j < ns.length; j++) {
        if (j == verbIndex && !isQuestion) break;
        final n = ns[j];
        if (_grammarStops.contains(n) || _questionWords.contains(n)) continue;
        return [_stem(n)];
      }
    }

    if (verbIndex >= 0 && verbIndex < ns.length) {
      final n = ns[verbIndex];
      if (n == 'è' ||
          n == 'e' ||
          n == 'sono' ||
          n == 'sei' ||
          n == 'era' ||
          n == 'sarà' ||
          n == 'sara') {
        return ['ess'];
      }
      if (n == 'ha' || n == 'ho' || n == 'hai' || n == 'hanno') return ['av'];
      if (!_grammarStops.contains(n) && !_questionWords.contains(n))
        return [_stem(n)];
    }

    for (final raw in surfaces) {
      final n = normalizeText(raw);
      if (_grammarStops.contains(n) ||
          _questionWords.contains(n) ||
          n.length < 3) continue;
      return [_stem(n)];
    }
    return const [];
  }

  String _joinObject(List<String> xs) {
    final cleaned = xs.where((x) {
      final n = normalizeText(x);
      return !{'?', '.', ',', '!', ';', ':'}.contains(n);
    }).toList();
    return cleaned.join(' ').trim();
  }

  Interpretation04? _semanticInterpretation(
    List<String> surfaces, {
    required String speaker,
    required bool create,
    required bool isQuestion,
  }) {
    if (surfaces.isEmpty) return null;
    final ns = surfaces.map(normalizeText).toList();
    var subject = _resolveDeicticSubject(surfaces, speaker: speaker);
    final roleFamily = _roleFamilyIn(surfaces);
    final hasNameCue = surfaces.any((t) => _semanticFamilyOf(t) == 'name');
    final hasCopula = ns.any(
        (n) => {'è', 'e', 'sono', 'sei', 'era', 'sarà', 'sara'}.contains(n));

    int predicateIndex() {
      for (var i = 0; i < surfaces.length; i++) {
        if (_semanticFamilyOf(surfaces[i]) == 'name') return i;
      }
      for (var i = 0; i < ns.length; i++) {
        if ({'è', 'e', 'sono', 'sei', 'era', 'sarà', 'sara'}.contains(ns[i]))
          return i;
      }
      return -1;
    }

    String? tailAfter(int index) {
      if (index < 0 || index + 1 >= surfaces.length) return null;
      var tail = surfaces.sublist(index + 1);
      while (tail.isNotEmpty &&
          {
            'si',
            'a',
            'in',
            'di',
            'da',
            'per',
            'con',
            'il',
            'lo',
            'la',
            'i',
            'gli',
            'le',
            'è',
            'e',
            'sono',
            'sei',
            'era',
            'sarà',
            'sara'
          }.contains(normalizeText(tail.first))) {
        tail = tail.sublist(1);
      }
      final value = _joinObject(tail);
      return value.trim().isEmpty ? null : value.trim();
    }

    // Kinship / partner frames take precedence over the generic NAME relation:
    // "mia figlia si chiama Cloe" means USER --daughter--> Cloe.
    if (roleFamily != null) {
      if (subject == null) {
        // A relational family phrase without a deictic owner is only interpreted
        // structurally when there is an explicit USER/SELF cue; otherwise the
        // generic parser gets a chance to resolve the subject.
        final hasPossessive = ns.any((n) => {
              'mio',
              'mia',
              'miei',
              'mie',
              'tuo',
              'tua',
              'tuoi',
              'tue',
              'nostro',
              'nostra',
              'nostri',
              'nostre'
            }.contains(n));
        if (hasPossessive) {
          subject = speaker == 'user' ? userId : selfId;
        }
      }
      if (subject != null) {
        final relationId = create
            ? _ensureSemanticRelation(roleFamily, extraCues: surfaces)
            : (_relationKeyToId['sem:$roleFamily'] ?? -1);
        String? objectText;
        if (!isQuestion) {
          objectText = tailAfter(predicateIndex());
          // "mia figlia Cloe" / "il mio partner Alessandra"
          if (objectText == null) {
            final roleIndex =
                surfaces.indexWhere((t) => _semanticFamilyOf(t) == roleFamily);
            objectText = tailAfter(roleIndex);
          }
        }
        return Interpretation04(
          isQuestion: isQuestion,
          subjectId: subject,
          relationId: relationId >= 0 ? _canonicalRelation(relationId) : null,
          objectText: objectText,
          objectKey: objectText == null ? null : canonicalObject(objectText),
          relationCues: ['sem:$roleFamily'],
          confidence: subject != null && relationId >= 0 ? 0.95 : 0.70,
        );
      }
    }

    // NAME is a semantic family shared by "chiamarsi" and "nome".
    if (hasNameCue) {
      final relationId = create
          ? _ensureSemanticRelation('name', extraCues: surfaces)
          : (_relationKeyToId['sem:name'] ?? -1);
      final pIndex = predicateIndex();
      String? objectText;

      if (isQuestion) {
        // "come si chiama Mario?" -> ask NAME(Mario), unless a deictic
        // already resolved SELF/USER.
        if (subject == null && pIndex >= 0 && pIndex + 1 < surfaces.length) {
          final tail = surfaces.sublist(pIndex + 1).where((t) {
            final n = normalizeText(t);
            return !_grammarStops.contains(n) && !_questionWords.contains(n);
          }).toList();
          if (tail.isNotEmpty) {
            final explicit = _joinObject(tail);
            subject = create ? _entityForText(explicit) : _findEntity(explicit);
          }
        }
      } else {
        objectText = tailAfter(pIndex);
      }

      if (subject != null) {
        return Interpretation04(
          isQuestion: isQuestion,
          subjectId: subject,
          relationId: relationId >= 0 ? _canonicalRelation(relationId) : null,
          objectText: objectText,
          objectKey: objectText == null ? null : canonicalObject(objectText),
          relationCues: const ['sem:name'],
          confidence: relationId >= 0 ? 0.95 : 0.70,
        );
      }
    }

    // Possessive "nome" with a copula can be tokenized in forms where the
    // generic verb detector would otherwise over-weight the copula.
    if (hasCopula && ns.contains('nome')) {
      subject ??= _resolveDeicticSubject(surfaces, speaker: speaker);
      if (subject != null) {
        final relationId = create
            ? _ensureSemanticRelation('name', extraCues: surfaces)
            : (_relationKeyToId['sem:name'] ?? -1);
        String? objectText;
        if (!isQuestion) objectText = tailAfter(predicateIndex());
        return Interpretation04(
          isQuestion: isQuestion,
          subjectId: subject,
          relationId: relationId >= 0 ? _canonicalRelation(relationId) : null,
          objectText: objectText,
          objectKey: objectText == null ? null : canonicalObject(objectText),
          relationCues: const ['sem:name'],
          confidence: relationId >= 0 ? 0.95 : 0.70,
        );
      }
    }
    return null;
  }

  bool _hasPredicate061(List<String> tokens) {
    if (tokens.isEmpty) return false;
    if (_findVerbIndex(tokens, isQuestion: false) >= 0) return true;
    return tokens.any((t) => _semanticFamilyOf(t) == 'name');
  }

  bool _rightStartsIndependentClause061(List<String> tokens) {
    if (tokens.isEmpty) return false;
    final vi = _findVerbIndex(tokens, isQuestion: false);
    if (vi > 0) return true;

    final deictic = _resolveDeicticSubject(tokens, speaker: 'user');
    if (deictic != null) {
      if (vi >= 0) return true;
      final content = tokens.where((t) {
        final n = normalizeText(t);
        return !_grammarStops.contains(n) &&
            !_questionWords.contains(n) &&
            !{'e', 'ma', 'però', 'pero'}.contains(n);
      }).length;
      return content >= 2;
    }
    return false;
  }

  String _completeEllipticalClause061(
    List<String> previous,
    List<String> current,
  ) {
    if (current.isEmpty) return '';
    final currentNs = current.map(normalizeText).toList();
    const explicitCopulas = {
      'è',
      'e',
      'sono',
      'sei',
      'siamo',
      'siete',
      'era',
      'sarà',
      'sara'
    };
    final hasExplicitPredicate = currentNs.any(explicitCopulas.contains) ||
        current.any((t) => _semanticFamilyOf(t) == 'name');
    if (hasExplicitPredicate) return current.join(' ');

    final currentSubject = _resolveDeicticSubject(current, speaker: 'user');
    if (currentSubject == null) return current.join(' ');

    final pvi = _findVerbIndex(previous, isQuestion: false);
    if (pvi < 0 || pvi >= previous.length) return current.join(' ');
    final predicate = normalizeText(previous[pvi]);

    const copulas = {'è', 'e', 'sono', 'sei', 'era', 'sarà', 'sara'};
    if (!copulas.contains(predicate)) return current.join(' ');

    final first = normalizeText(current.first);
    final copula = switch (first) {
      'io' => 'sono',
      'tu' => 'sei',
      'lui' || 'lei' => 'è',
      'noi' => 'siamo',
      'voi' => 'siete',
      'loro' => 'sono',
      _ => 'è',
    };
    return [current.first, copula, ...current.sublist(1)].join(' ');
  }

  List<String> _splitCoordinatedEvents061(String text) {
    final tokens = lexicalTokens(text);
    if (tokens.length < 4) {
      final t = text.trim();
      return t.isEmpty ? const <String>[] : <String>[t];
    }

    final out = <String>[];
    var start = 0;
    List<String>? previousClauseTokens;

    for (var i = 1; i < tokens.length - 1; i++) {
      final n = normalizeText(tokens[i]);
      if (!{'e', 'ma', 'però', 'pero'}.contains(n)) continue;

      final left = tokens.sublist(start, i);
      final right = tokens.sublist(i + 1);
      if (!_hasPredicate061(left) || !_rightStartsIndependentClause061(right)) {
        continue;
      }

      final leftText = previousClauseTokens == null
          ? left.join(' ')
          : _completeEllipticalClause061(previousClauseTokens, left);
      if (leftText.trim().isNotEmpty) out.add(leftText.trim());
      previousClauseTokens = left;
      start = i + 1;
    }

    final tail = tokens.sublist(start);
    if (tail.isNotEmpty) {
      final tailText = previousClauseTokens == null
          ? tail.join(' ')
          : _completeEllipticalClause061(previousClauseTokens, tail);
      if (tailText.trim().isNotEmpty) out.add(tailText.trim());
    }

    if (out.length <= 1) {
      final t = text.trim();
      return t.isEmpty ? const <String>[] : <String>[t];
    }
    return out;
  }

  Interpretation04? _interpretInverseRoleCopula061(
    String raw, {
    required String speaker,
    required bool create,
  }) {
    final surfaces = lexicalTokens(raw);
    if (surfaces.isEmpty) return null;
    final ns = surfaces.map(normalizeText).toList();
    final isQuestion =
        normalizeText(raw).endsWith('?') || ns.any(_questionWords.contains);
    if (isQuestion) return null;

    final roleFamily = _roleFamilyIn(surfaces);
    if (roleFamily == null) return null;

    var copulaIndex = -1;
    for (var i = 0; i < ns.length; i++) {
      if ({'è', 'e', 'sono', 'sei', 'siamo', 'siete', 'era', 'sarà', 'sara'}
          .contains(ns[i])) {
        copulaIndex = i;
        break;
      }
    }
    if (copulaIndex <= 0) return null;

    final roleIndex =
        surfaces.indexWhere((t) => _semanticFamilyOf(t) == roleFamily);
    if (roleIndex <= copulaIndex) return null;

    final owner = _resolveDeicticSubject(surfaces.sublist(copulaIndex + 1),
        speaker: speaker);
    if (owner == null) return null;

    final before = surfaces
        .sublist(0, copulaIndex)
        .where((t) => !_grammarStops.contains(normalizeText(t)))
        .toList();
    if (before.isEmpty) return null;
    final objectText = _joinObject(before).trim();
    if (objectText.isEmpty) return null;

    var relationRaw = _relationKeyToId['latent:' + roleFamily] ?? -1;
    if (relationRaw < 0) {
      relationRaw = create
          ? _ensureSemanticRelation(roleFamily, extraCues: surfaces)
          : (_relationKeyToId['sem:' + roleFamily] ?? -1);
    }
    if (relationRaw < 0) return null;

    return Interpretation04(
      isQuestion: false,
      subjectId: owner,
      relationId: _canonicalRelation(relationRaw),
      objectText: objectText,
      objectKey: canonicalObject(objectText),
      relationCues: ['sem:' + roleFamily],
      confidence: 0.97,
    );
  }

  Interpretation04? _interpretCopularType061(
    String raw, {
    required String speaker,
    required bool create,
  }) {
    final surfaces = lexicalTokens(raw);
    if (surfaces.isEmpty) return null;
    final ns = surfaces.map(normalizeText).toList();
    final isQuestion =
        normalizeText(raw).endsWith('?') || ns.any(_questionWords.contains);
    if (isQuestion) return null;

    if (_roleFamilyIn(surfaces) != null) return null;
    if (surfaces.any((t) => _semanticFamilyOf(t) == 'name')) return null;

    var copulaIndex = -1;
    for (var i = 0; i < ns.length; i++) {
      if ({'è', 'e', 'sono', 'sei', 'siamo', 'siete', 'era', 'sarà', 'sara'}
          .contains(ns[i])) {
        copulaIndex = i;
        break;
      }
    }
    if (copulaIndex < 0 || copulaIndex + 1 >= surfaces.length) return null;

    var subject = _resolveDeicticSubject(surfaces, speaker: speaker);
    if (subject == null && copulaIndex > 0) {
      final before = surfaces
          .sublist(0, copulaIndex)
          .where((t) => !_grammarStops.contains(normalizeText(t)))
          .toList();
      if (before.isNotEmpty) {
        final explicitSubject = before.join(' ');
        subject = create
            ? _entityForText(explicitSubject)
            : _findEntity(explicitSubject);
      }
    }
    if (subject == null) return null;

    var tail = surfaces.sublist(copulaIndex + 1);
    while (tail.isNotEmpty &&
        {'il', 'lo', 'la', 'i', 'gli', 'le'}
            .contains(normalizeText(tail.first))) {
      tail = tail.sublist(1);
    }
    if (tail.isEmpty) return null;

    final objectText = _joinObject(tail).trim();
    if (objectText.isEmpty) return null;
    final first = normalizeText(tail.first);

    final known = _findEntity(objectText);
    final properLike = tail.every((t) {
      if (t.isEmpty) return false;
      final c = t.codeUnitAt(0);
      return c >= 65 && c <= 90;
    });
    final classLike = {'un', 'uno', 'una'}.contains(first) ||
        (!properLike && known == null && tail.length >= 1);
    if (!classLike) return null;

    final relationRaw = create
        ? _ensureDevelopmentalRelation(
            'generic-is',
            'è',
            [raw],
          )
        : (_relationKeyToId['latent:generic-is'] ?? -1);
    if (relationRaw < 0) return null;
    final relationId = _canonicalRelation(relationRaw);

    return Interpretation04(
      isQuestion: false,
      subjectId: subject,
      relationId: relationId,
      objectText: objectText,
      objectKey: canonicalObject(objectText),
      relationCues: const ['frame:copular-type'],
      confidence: 0.96,
    );
  }

  Interpretation04 interpret(String raw,
      {String speaker = 'user', bool create = true}) {
    final surfaces = lexicalTokens(raw);
    final normalized = surfaces.map(normalizeText).toList();
    final isQuestion = normalizeText(raw).endsWith('?') ||
        normalized.any(_questionWords.contains);
    if (surfaces.isEmpty) {
      return const Interpretation04(
        isQuestion: false,
        subjectId: null,
        relationId: null,
        objectText: null,
        objectKey: null,
        relationCues: [],
        confidence: 0,
      );
    }

    final closedPredicate082 = _interpretClosedPredicateQuestion082(
      raw,
      speaker: speaker,
      create: create,
    );
    if (closedPredicate082 != null) return closedPredicate082;

    final inverseRole = _interpretInverseRoleCopula061(
      raw,
      speaker: speaker,
      create: create,
    );
    if (inverseRole != null) return inverseRole;

    final copularType = _interpretCopularType061(
      raw,
      speaker: speaker,
      create: create,
    );
    if (copularType != null) return copularType;

    var subject = _resolveDeicticSubject(surfaces, speaker: speaker);
    final verbIndex = _findVerbIndex(surfaces, isQuestion: isQuestion);
    String? objectText;

    if (subject == null && verbIndex > 0) {
      final before = surfaces
          .sublist(0, verbIndex)
          .where((t) => !_grammarStops.contains(normalizeText(t)))
          .toList();
      if (before.isNotEmpty) {
        final explicitSubject = before.join(' ');
        subject = create
            ? _entityForText(explicitSubject)
            : _findEntity(explicitSubject);
      }
    }

    if (isQuestion &&
        subject == null &&
        verbIndex >= 0 &&
        verbIndex + 1 < surfaces.length) {
      final tail = surfaces
          .sublist(verbIndex + 1)
          .where((t) => !_grammarStops.contains(normalizeText(t)))
          .toList();
      if (tail.isNotEmpty) {
        final explicit = _joinObject(tail);
        subject = create ? _entityForText(explicit) : _findEntity(explicit);
      }
    }

    if (!isQuestion && verbIndex >= 0 && verbIndex + 1 < surfaces.length) {
      var tail = surfaces.sublist(verbIndex + 1);
      while (tail.isNotEmpty &&
          {
            'si',
            'a',
            'in',
            'di',
            'da',
            'per',
            'con',
            'il',
            'lo',
            'la',
            'i',
            'gli',
            'le'
          }.contains(normalizeText(tail.first))) {
        tail = tail.sublist(1);
      }
      objectText = _joinObject(tail);
    }

    if (!isQuestion && subject == null) {
      final nonStops = surfaces
          .where((t) => !_grammarStops.contains(normalizeText(t)))
          .toList();
      if (nonStops.length >= 2) {
        subject = create
            ? _entityForText(nonStops.first)
            : _findEntity(nonStops.first);
        objectText ??= _joinObject(nonStops.sublist(1));
      }
    }

    final features = _relationAttractorFeatures(
      surfaces,
      isQuestion: isQuestion,
      subjectId: subject,
      verbIndex: verbIndex,
    );
    final relationRaw = _relationFromAttractor(features, create: create);
    final relationId = relationRaw < 0 ? null : _canonicalRelation(relationRaw);

    final objectKey = objectText == null || objectText.trim().isEmpty
        ? null
        : canonicalObject(objectText);

    var confidence = 0.20;
    if (subject != null) confidence += 0.28;
    if (relationId != null) {
      confidence +=
          0.32 * _relationAttractorScore(relationId, features).clamp(0.0, 1.0);
    }
    if (isQuestion || objectKey != null) confidence += 0.15;

    return Interpretation04(
      isQuestion: isQuestion,
      subjectId: subject,
      relationId: relationId,
      objectText: objectText,
      objectKey: objectKey,
      relationCues: features,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
    );
  }

  int? _findEntity(String text) {
    final n = canonicalObject(text);
    final indexed = _entityKeyToId[n];
    if (indexed != null) return indexed;
    for (final e in entities) {
      if (normalizeText(e.label) == n || e.aliases.contains(n)) return e.id;
    }
    return null;
  }

  PlasticEdge04 _edge(Map<int, Map<int, PlasticEdge04>> graph, int from, int to,
      List<_EdgeChange04> changes) {
    final row = graph.putIfAbsent(from, () => {});
    final old = row[to];
    if (old != null) return old;
    final e = PlasticEdge04(from: from, to: to, cost: 1.02, lastUsed: step);
    row[to] = e;
    changes.add(const _EdgeChange04(0, 0, 0, true));
    return e;
  }

  void _lazyDecay(PlasticEdge04 e) {
    final dt = max(0, step - e.lastUsed);
    if (dt == 0) return;
    final evolved = MgdMath09.evolve(
      weight: e.cost,
      memory: e.fast,
      material: e.slow,
      coherenceAverage: e.meta,
      activation: 0.0,
      reward: 0.0,
      iterations: min(dt, 16),
    );
    e.cost = evolved.weight;
    e.fast = evolved.memory;
    e.slow = evolved.material;
    e.meta = evolved.coherenceAverage;
    e.elig *= pow(0.86, min(dt, 24)).toDouble();
    e.lastUsed = step;
  }

  double _strength(PlasticEdge04 e) {
    _lazyDecay(e);
    return MgdMath09.strength(
      weight: e.cost,
      memory: e.fast,
      material: e.slow,
    );
  }

  _EdgeChange04 _updateEdge(PlasticEdge04 e,
      {double reward = 0.25, double coactivity = 1}) {
    _lazyDecay(e);
    final oldFast = e.fast;
    final oldSlow = e.slow;
    final oldCost = e.cost;

    e.elig = (0.82 * e.elig + 0.25 * coactivity).clamp(0.0, 1.0).toDouble();
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

    return _EdgeChange04(
      (e.slow - oldSlow).abs(),
      (e.fast - oldFast).abs(),
      (e.cost - oldCost).abs(),
      false,
    );
  }

  int? predictNext(List<int> context) {
    if (context.isEmpty) return null;
    final scores = <int, double>{};
    final depth = min(5, context.length);
    for (var d = 0; d < depth; d++) {
      final from = context[context.length - 1 - d];
      final row = temporal[from];
      if (row == null) continue;
      final w = 1.0 / (1 + d * 0.65);
      for (final entry in row.entries) {
        final s = _strength(entry.value);
        if (s > 0) scores[entry.key] = (scores[entry.key] ?? 0) + w * s;
      }
    }
    if (scores.isEmpty) return null;
    return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  LearningReport04 learnSurface(String text, {double reward = 0.25}) {
    final enc = encode(text);
    final ids = enc.ids;
    if (ids.isEmpty) {
      lastFlux = 0;
      return const LearningReport04(
          tokens: 0, newTokens: 0, novelty: 0, predictionError: 0, flux: 0);
    }

    final changes = <_EdgeChange04>[];
    var misses = 0;
    var predictions = 0;
    final sequence = <int>[_tokenToId['<bos>']!, ...ids, _tokenToId['<eos>']!];

    for (final id in ids) {
      final assembly = assemblies[id];
      assembly.count += 1;
      assembly.lastSeen = step;
    }

    for (var i = 0; i < sequence.length - 1; i++) {
      final context = sequence.sublist(max(0, i - 4), i + 1);
      final p = predictNext(context);
      if (p != null) {
        predictions++;
        if (p != sequence[i + 1]) misses++;
      }
      final e = _edge(temporal, sequence[i], sequence[i + 1], changes);
      changes.add(_updateEdge(e, reward: reward));
      step++;
    }

    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < min(ids.length, i + 5); j++) {
        final co = 1.0 / (j - i);
        final a = _edge(associative, ids[i], ids[j], changes);
        final b = _edge(associative, ids[j], ids[i], changes);
        changes.add(_updateEdge(a, reward: reward * 0.55, coactivity: co));
        changes.add(_updateEdge(b, reward: reward * 0.55, coactivity: co));
      }
    }

    workingMemory.addAll(ids);
    while (workingMemory.length > workingMemorySize) {
      workingMemory.removeAt(0);
    }

    final lexicalNovelty = enc.newTokens / max(1, ids.length);
    final error = predictions == 0 ? 1.0 : misses / predictions;
    final novelty =
        (0.55 * lexicalNovelty + 0.45 * error).clamp(0.0, 1.0).toDouble();
    noveltyEma = 0.92 * noveltyEma + 0.08 * novelty;
    predictionErrorEma = 0.92 * predictionErrorEma + 0.08 * error;
    curiosity = (4 * noveltyEma * (1 - noveltyEma)).clamp(0.0, 1.0).toDouble();

    // MGD-style entropic time: normalized change of persistent state, not number of tokens.
    var slowDelta = 0.0;
    var costDelta = 0.0;
    var created = 0;
    var updated = 0;
    for (final c in changes) {
      if (c.created) {
        created++;
      } else {
        slowDelta += c.slowDelta;
        costDelta += c.costDelta;
        updated++;
      }
    }
    final normalizedSlow = updated == 0 ? 0.0 : slowDelta / updated;
    final normalizedCost = updated == 0 ? 0.0 : costDelta / updated;
    final structural = created / max(1, created + updated);
    lastFlux =
        (0.55 * normalizedSlow + 0.25 * normalizedCost + 0.20 * structural)
            .clamp(0.0, 1.0)
            .toDouble();
    entropicAge += lastFlux;

    if (step % 350 == 0) maintenance();

    return LearningReport04(
      tokens: ids.length,
      newTokens: enc.newTokens,
      novelty: novelty,
      predictionError: error,
      flux: lastFlux,
    );
  }

  double _contextSimilarity(List<int> a, List<int> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final sa = a.toSet();
    final sb = b.toSet();
    return sa.intersection(sb).length / max(1, sa.union(sb).length);
  }

  Episode04 _storeEpisode({
    required String userText,
    required LearningReport04 report,
    required Interpretation04 interpretation,
    String? agentText,
    double reward = 0,
  }) {
    final tokenIds = encode(userText, create: false).ids;
    final prev = episodes.isEmpty ? null : episodes.last;
    final contextShift =
        prev == null ? 1.0 : 1.0 - _contextSimilarity(prev.tokenIds, tokenIds);
    final boundary = (0.58 * report.predictionError + 0.42 * contextShift)
        .clamp(0.0, 1.0)
        .toDouble();
    final ep = Episode04(
      id: _nextEpisodeId++,
      userText: userText.trim(),
      agentText: agentText,
      tokenIds: tokenIds,
      subjectId: interpretation.subjectId,
      relationId: interpretation.relationId,
      objectKey: interpretation.objectKey,
      wasQuestion: interpretation.isQuestion,
      novelty: report.novelty,
      predictionError: report.predictionError,
      boundary: boundary,
      salience:
          (0.35 + 0.30 * report.novelty + 0.20 * boundary + 0.15 * reward.abs())
              .clamp(0.0, 1.0)
              .toDouble(),
      reward: reward,
      flux: report.flux,
      createdStep: step,
    );
    episodes.add(ep);
    if (episodes.length > maxEpisodes) {
      final protected =
          episodes.where((e) => e.reward > 0.4 || e.salience > 0.75).toSet();
      episodes.sort((a, b) {
        final sa = a.salience + 0.06 * a.replays + 0.08 * max(0.0, a.reward);
        final sb = b.salience + 0.06 * b.replays + 0.08 * max(0.0, b.reward);
        return sb.compareTo(sa);
      });
      final keep = episodes.take(maxEpisodes).toSet()..addAll(protected);
      episodes.removeWhere((e) => !keep.contains(e));
      episodes.sort((a, b) => a.id.compareTo(b.id));
    }
    return ep;
  }

  double _putFact({
    required int subjectId,
    required int relationId,
    required String objectText,
    required double reward,
    int? episodeId,
    bool synchronize = true,
  }) {
    relationId = _canonicalRelation(relationId);
    final values = _relationIsMulti(relationId)
        ? _splitObjectValues(objectText)
        : <String>[objectText.trim()];
    if (values.isEmpty) return 0;

    var totalFlux = 0.0;
    for (final value in values) {
      totalFlux += _putFactValue(
        subjectId: subjectId,
        relationId: relationId,
        objectText: value,
        reward: reward,
        episodeId: episodeId,
        multi: _relationIsMulti(relationId),
      );
    }
    final flux = (totalFlux / max(1, values.length)).clamp(0.0, 1.0).toDouble();
    if (synchronize) {
      _synchronizeFamilyFacts(
        subjectId: subjectId,
        relationId: relationId,
        objectText: objectText,
        reward: reward,
        episodeId: episodeId,
      );
    }
    return flux;
  }

  double _putFactValue({
    required int subjectId,
    required int relationId,
    required String objectText,
    required double reward,
    required bool multi,
    int? episodeId,
  }) {
    final objectKey = canonicalObject(objectText);
    if (objectKey.isEmpty) return 0;
    _entityForText(objectText);

    final slotKey = '$subjectId::$relationId';
    final slot = slots.putIfAbsent(
      slotKey,
      () => RelationSlot04(subjectId: subjectId, relationId: relationId),
    );
    final before = slot.candidates.values.fold<double>(
      0.0,
      (m, c) => max(m, c.confidence),
    );
    final old = slot.candidates[objectKey];
    if (old == null) {
      final c = FactCandidate04(
        objectKey: objectKey,
        display: _titleCase(objectText.trim()),
        confidence:
            (0.56 + 0.16 * max(0.0, reward)).clamp(0.0, 0.96).toDouble(),
        lastStep: step,
      );
      if (episodeId != null) c.sourceEpisodes.add(episodeId);
      slot.candidates[objectKey] = c;

      if (!multi) {
        for (final other in slot.candidates.values) {
          if (other.objectKey == objectKey) continue;
          other.contradictions++;
          other.confidence =
              (other.confidence * (0.80 - 0.10 * max(0.0, reward)))
                  .clamp(0.02, 1.0)
                  .toDouble();
        }
      }
    } else {
      old.supports++;
      old.display = _titleCase(objectText.trim());
      old.confidence = (old.confidence + 0.10 + 0.08 * max(0.0, reward))
          .clamp(0.0, 0.995)
          .toDouble();
      old.lastStep = step;
      if (episodeId != null) old.sourceEpisodes.add(episodeId);

      if (!multi) {
        for (final other in slot.candidates.values) {
          if (other.objectKey == objectKey) continue;
          other.confidence =
              (other.confidence * 0.92).clamp(0.02, 1.0).toDouble();
        }
      }
    }

    final subjectEntity = entities[subjectId];
    subjectEntity.mentions += 1;
    subjectEntity.lastSeen = step;
    relations[relationId].uses++;

    final after = slot.candidates.values.fold<double>(
      0.0,
      (m, c) => max(m, c.confidence),
    );
    final semanticFlux = (after - before).abs().clamp(0.0, 1.0).toDouble();
    lastFlux = (lastFlux + 0.25 * semanticFlux).clamp(0.0, 1.0).toDouble();
    entropicAge += 0.25 * semanticFlux;
    return semanticFlux;
  }

  void _synchronizeFamilyFacts({
    required int subjectId,
    required int relationId,
    required String objectText,
    required double reward,
    int? episodeId,
  }) {
    final relation = relations[_canonicalRelation(relationId)];
    if (relation.key != 'sem:daughter' && relation.key != 'sem:son') return;
    final childrenId =
        _ensureSemanticRelation('children', extraCues: const ['figli']);
    _putFact(
      subjectId: subjectId,
      relationId: childrenId,
      objectText: objectText,
      reward: min(0.80, max(0.20, reward * 0.85)),
      episodeId: episodeId,
      synchronize: false,
    );
  }

  void _countSurface031(
      Map<int, Map<String, int>> store, int id, String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    final bucket = store.putIfAbsent(id, () => <String, int>{});
    bucket[v] = (bucket[v] ?? 0) + 1;
  }

  String? _bestSurface031(Map<int, Map<String, int>> store, int id) {
    final bucket = store[id];
    if (bucket == null || bucket.isEmpty) return null;
    final xs = bucket.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        if (c != 0) return c;
        return a.key.length.compareTo(b.key.length);
      });
    return xs.first.key;
  }

  int _subsequenceStart031(List<String> hay, List<String> needle, int start) {
    if (needle.isEmpty) return -1;
    final hn = hay.map(normalizeText).toList();
    final nn = needle.map(normalizeText).toList();
    for (var i = max(0, start); i + nn.length <= hn.length; i++) {
      var ok = true;
      for (var j = 0; j < nn.length; j++) {
        if (hn[i + j] != nn[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  void _learnSurfaceFrame031(String text, Interpretation04 i) {
    if (i.isQuestion ||
        i.subjectId == null ||
        i.relationId == null ||
        i.objectText == null) return;
    final surfaces = lexicalTokens(text)
        .where((x) => !{'.', '?', '!', ';', ':'}.contains(x))
        .toList();
    if (surfaces.length < 3) return;
    var vi = _findVerbIndex(surfaces, isQuestion: false);
    if (vi < 0) {
      final ns = surfaces.map(normalizeText).toList();
      vi = ns.indexWhere((x) => {
            'è',
            'e',
            'sono',
            'sei',
            'siamo',
            'siete',
            'era',
            'sarà',
            'sara'
          }.contains(x));
    }
    if (vi <= 0) return;
    final subjectSurface = surfaces.sublist(0, vi).join(' ').trim();
    if (subjectSurface.isNotEmpty)
      _countSurface031(entitySurfaceForms031, i.subjectId!, subjectSurface);

    final objectTokens = lexicalTokens(i.objectText!)
        .where((x) => !{'.', '?', '!', ';', ':'}.contains(x))
        .toList();
    var oi = _subsequenceStart031(surfaces, objectTokens, vi + 1);
    if (oi < 0) {
      // Parser may strip a preposition/article from the semantic object. Find its
      // final content tokens and keep the intervening grammatical material in the frame.
      final compact = objectTokens
          .where((x) => !_grammarStops.contains(normalizeText(x)))
          .toList();
      if (compact.isNotEmpty)
        oi = _subsequenceStart031(surfaces, compact, vi + 1);
    }
    if (oi < 0) oi = min(surfaces.length, vi + 1);
    final bridge = surfaces.sublist(vi, oi).join(' ').trim();
    if (bridge.isNotEmpty)
      _countSurface031(
          relationSurfaceFrames031, _canonicalRelation(i.relationId!), bridge);
  }

  String? composeSemantic031(
      {required String subject,
      required String relation,
      required String object}) {
    var sid = _findEntity(subject);
    if (sid == null) {
      final wanted = normalizeText(subject);
      for (final e in entitySurfaceForms031.entries) {
        final hit = e.value.keys.any((surface) {
          final tokens = normalizeText(surface)
              .split(' ')
              .where((x) => x.isNotEmpty)
              .toSet();
          return normalizeText(surface) == wanted || tokens.contains(wanted);
        });
        if (hit) {
          sid = e.key;
          break;
        }
      }
    }
    final relationNeedle = normalizeText(relation);
    int? rid;
    double best = 0;
    final wantedStem = _stem(relationNeedle);
    for (final e in relationSurfaceFrames031.entries) {
      for (final surface in e.value.keys) {
        final n = normalizeText(surface);
        final parts = n.split(' ').where((x) => x.isNotEmpty).toList();
        final first = parts.isEmpty ? null : parts.first;
        if (n == relationNeedle ||
            parts.contains(relationNeedle) ||
            (first != null && _stem(first) == wantedStem)) {
          rid = _canonicalRelation(e.key);
          best = 0.96;
          break;
        }
      }
      if (best >= 0.96) break;
    }
    for (final r in relations) {
      final id = _canonicalRelation(r.id);
      if (id != r.id) continue;
      final label = normalizeText(r.label);
      var score = 0.0;
      if (label == relationNeedle)
        score = 1.0;
      else if (label.contains(relationNeedle) || relationNeedle.contains(label))
        score = 0.82;
      else {
        final wanted =
            relationNeedle.split(' ').where((x) => x.isNotEmpty).toSet();
        final cues = r.cues.keys
            .map((x) => normalizeText(
                x.replaceFirst(RegExp(r'^(?:lex|verb|bi|q):'), '')))
            .toSet();
        if (wanted.isNotEmpty)
          score = wanted.intersection(cues).length / max(1, wanted.length);
      }
      if (score > best) {
        best = score;
        rid = id;
      }
    }
    // 0.31: composition must not depend on the relation-attractor having
    // already collapsed onto a canonical relation id. If the surface predicate
    // was genuinely observed in experience, it is itself a learned generator
    // component and can be recombined with another known subject/object.
    final wantedSubject = normalizeText(subject);
    bool tokenMatches(String token, String wanted) {
      final n = normalizeText(token);
      return n == wanted || _stem(n) == _stem(wanted);
    }

    final subjectObserved = sid != null ||
        episodes.any((ep) => lexicalTokens(ep.userText)
            .any((t) => normalizeText(t) == wantedSubject));
    final relationObserved = episodes.any((ep) =>
        lexicalTokens(ep.userText).any((t) => tokenMatches(t, relationNeedle)));
    if (!subjectObserved || !relationObserved) return null;

    if (sid != null && rid != null && best >= 0.45) {
      final composed =
          composeFact031(subjectId: sid, relationId: rid, objectText: object);
      if (composed != null) return composed;
    }

    final subjectSurface = sid != null && sid >= 0 && sid < entities.length
        ? (_bestSurface031(entitySurfaceForms031, sid) ?? entities[sid].label)
        : subject.trim();
    var obj = object.trim().replaceFirst(RegExp(r'[.!?]+$'), '');
    if (subjectSurface.trim().isEmpty || relation.trim().isEmpty || obj.isEmpty)
      return null;
    var out = '$subjectSurface ${relation.trim()} $obj'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    out = out[0].toUpperCase() + out.substring(1);
    if (!RegExp(r'[.!?]$').hasMatch(out)) out += '.';
    return out;
  }

  String? composeFact031(
      {required int subjectId,
      required int relationId,
      required String objectText}) {
    if (subjectId < 0 ||
        subjectId >= entities.length ||
        objectText.trim().isEmpty) return null;
    final rid = _canonicalRelation(relationId);
    if (rid < 0 || rid >= relations.length) return null;
    final subject = _bestSurface031(entitySurfaceForms031, subjectId) ??
        entities[subjectId].label;
    var bridge =
        _bestSurface031(relationSurfaceFrames031, rid) ?? relations[rid].label;
    if (bridge.trim().isEmpty) return null;
    var obj = objectText.trim().replaceFirst(RegExp(r'[.!?]+$'), '');
    // Avoid repeating grammatical material learned into both the bridge and object.
    final bLast = normalizeText(bridge.split(RegExp(r'\s+')).last);
    final oFirst = obj.split(RegExp(r'\s+')).first;
    if (normalizeText(oFirst) == bLast &&
        {
          'a',
          'al',
          'alla',
          'ai',
          'agli',
          'alle',
          'in',
          'nel',
          'nella',
          'nei',
          'nelle',
          'di',
          'del',
          'della',
          'da',
          'dal',
          'sul',
          'sulla',
          'con',
          'per'
        }.contains(bLast)) {
      obj = obj.split(RegExp(r'\s+')).skip(1).join(' ');
    }
    var out = '$subject $bridge $obj'.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (out.isEmpty) return null;
    out = out[0].toUpperCase() + out.substring(1);
    if (!RegExp(r'[.!?]$').hasMatch(out)) out += '.';
    return out;
  }

  String? composeAnswer031(String prompt, String semanticAnswer) {
    final a = semanticAnswer.trim();
    if (a.isEmpty ||
        a.startsWith('Non ho ancora') ||
        {'sì.', 'si.', 'no.', 'sì', 'si', 'no'}.contains(normalizeText(a)))
      return null;
    final i = interpret(prompt, speaker: 'user', create: false);
    if (!i.isQuestion || i.subjectId == null || i.relationId == null)
      return null;
    return composeFact031(
        subjectId: i.subjectId!, relationId: i.relationId!, objectText: a);
  }

  void _learnDeclarativeFrame(String text, Interpretation04 i,
      {required double reward, int? episodeId}) {
    if (i.isQuestion ||
        i.subjectId == null ||
        i.relationId == null ||
        i.objectText == null ||
        i.objectText!.trim().isEmpty) return;
    _learnSurfaceFrame031(text, i);
    _putFact(
      subjectId: i.subjectId!,
      relationId: i.relationId!,
      objectText: i.objectText!,
      reward: reward,
      episodeId: episodeId,
    );
  }

  double _relationSimilarity(int a, int b) {
    a = _canonicalRelation(a);
    b = _canonicalRelation(b);
    if (a == b) return 1.0;
    if (a < 0 || b < 0 || a >= relations.length || b >= relations.length)
      return 0.0;
    final ra = relations[a];
    final rb = relations[b];
    if (ra.key.startsWith('sem:') && ra.key == rb.key) return 1.0;
    final ca = ra.cues.keys.toSet();
    final cb = rb.cues.keys.toSet();
    if (ca.isEmpty || cb.isEmpty) return 0.0;
    final lexical = ca.intersection(cb).length / max(1, ca.union(cb).length);
    final va = _vectorFor('relation:${ra.key}');
    final vb = _vectorFor('relation:${rb.key}');
    final distributed = _hammingSimilarity(va, vb);
    return (0.78 * lexical + 0.22 * distributed).clamp(0.0, 1.0).toDouble();
  }

  RelationSlot04? _slotForQuery(Interpretation04 i) {
    if (i.subjectId == null || i.relationId == null) return null;
    final relationId = _canonicalRelation(i.relationId!);
    final exact = slots['${i.subjectId}::$relationId'];
    if (exact != null && exact.candidates.isNotEmpty) return exact;

    RelationSlot04? best;
    var bestScore = 0.0;
    for (final slot in slots.values) {
      if (slot.subjectId != i.subjectId) continue;
      final score = _relationSimilarity(relationId, slot.relationId);
      if (score > bestScore) {
        bestScore = score;
        best = slot;
      }
    }
    return bestScore >= 0.62 ? best : null;
  }

  String _joinDisplays(List<String> displays) {
    final unique = <String>[];
    for (final d in displays) {
      if (!unique.any((x) => normalizeText(x) == normalizeText(d)))
        unique.add(d);
    }
    if (unique.isEmpty) return '';
    if (unique.length == 1) return unique.first;
    if (unique.length == 2) return '${unique[0]} e ${unique[1]}';
    return '${unique.sublist(0, unique.length - 1).join(', ')} e ${unique.last}';
  }

  List<FactCandidate04> _strongCandidates(RelationSlot04 slot,
      {double threshold = 0.42}) {
    final values =
        slot.candidates.values.where((c) => c.confidence >= threshold).toList()
          ..sort((a, b) {
            final c = b.confidence.compareTo(a.confidence);
            if (c != 0) return c;
            return a.lastStep.compareTo(b.lastStep);
          });
    return values;
  }

  List<String> _derivedCollectionDisplays(Interpretation04 i) {
    if (i.subjectId == null || i.relationId == null) return const [];
    final relationId = _canonicalRelation(i.relationId!);
    final members = _relationCompositions[relationId];
    if (members == null || members.isEmpty) return const [];

    final displays = <String>[];
    for (final memberId in members) {
      final slot = slots['${i.subjectId}::${_canonicalRelation(memberId)}'];
      if (slot == null) continue;
      displays.addAll(_strongCandidates(slot).map((c) => c.display));
    }
    return displays;
  }

  String? _deriveCollectionQuery(Interpretation04 i) {
    final joined = _joinDisplays(_derivedCollectionDisplays(i));
    return joined.isEmpty ? null : '$joined.';
  }

  String? _answerFrameQuery(Interpretation04 i) {
    final slot = _slotForQuery(i);
    if (slot == null) return _deriveCollectionQuery(i);
    final relationId = _canonicalRelation(slot.relationId);

    if (i.objectKey != null && i.objectKey!.trim().isNotEmpty) {
      final wanted = canonicalObject(i.objectKey!);
      final exact = slot.candidates[wanted];
      if (exact != null && exact.confidence >= 0.35) {
        return 'Sì.';
      }
      // Absence from a small knowledge graph is not evidence of falsity.
      // Do not hallucinate "No": fall through to the uncertainty path.
      return null;
    }

    if (_relationIsMulti(relationId)) {
      final displays = <String>[
        ..._strongCandidates(slot).map((e) => e.display),
        ..._derivedCollectionDisplays(i),
      ];
      final joined = _joinDisplays(displays);
      return joined.isEmpty ? null : '$joined.';
    }

    final winner = slot.winner;
    if (winner == null || winner.confidence < 0.42) return null;
    return '${winner.display}.';
  }

  void _linkParaphraseByAnswer({
    required int subjectId,
    required int relationId,
    required String objectText,
  }) {
    final key = canonicalObject(objectText);
    final candidates = <RelationSlot04>[];
    for (final s in slots.values) {
      if (s.subjectId != subjectId || s.relationId == relationId) continue;
      final w = s.winner;
      if (w != null && w.objectKey == key && w.confidence >= 0.55)
        candidates.add(s);
    }
    if (candidates.length == 1) {
      _mergeRelations(candidates.first.relationId, relationId);
    }
  }

  Episode04? _findEpisodeForPrompt(String prompt) {
    final np = normalizeText(prompt);
    for (final ep in episodes.reversed) {
      if (normalizeText(ep.userText) == np) return ep;
    }
    return null;
  }

  String _responsePromptKey028(String prompt) => normalizeText(prompt)
      .replaceAll(RegExp(r'[?.!,;:]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Set<String> _responseCues028(String text) => _semanticTerms028(text);

  bool _isStatefulPrompt028(String prompt, Interpretation04 i) {
    final n = _responsePromptKey028(prompt);
    final tokens = lexicalTokens(n).map(normalizeText).toSet();
    final selfState = tokens.contains('stai') ||
        tokens.contains('sta') ||
        tokens.contains('senti') ||
        tokens.contains('sentire') ||
        tokens.contains('umore') ||
        tokens.contains('va') ||
        tokens.contains('facendo') ||
        tokens.contains('pensi');
    final conversational = n.startsWith('come stai') ||
        n.startsWith('come va') ||
        n.startsWith('come ti senti') ||
        n.startsWith('tutto bene') ||
        n.startsWith('che fai') ||
        n.startsWith('cosa fai') ||
        n.startsWith('come te la passi');
    return conversational ||
        (i.isQuestion &&
            selfState &&
            (i.subjectId == null || i.subjectId == selfId));
  }

  ResponseSlot028? _bestResponseSlot028(String prompt) {
    final key = _responsePromptKey028(prompt);
    final exact = responseAttractors028[key];
    if (exact != null) return exact;
    final q = _responseCues028(prompt);
    ResponseSlot028? best;
    var bestScore = 0.0;
    for (final slot in responseAttractors028.values) {
      final s = _responseCues028(slot.promptSurface);
      if (q.isEmpty || s.isEmpty) continue;
      final score = q.intersection(s).length / max(1, q.union(s).length);
      if (score > bestScore) {
        bestScore = score;
        best = slot;
      }
    }
    return bestScore >= 0.68 ? best : null;
  }

  void _teachResponseAttractor028(String prompt, String answer, double reward) {
    final key = _responsePromptKey028(prompt);
    final text = answer.trim();
    if (key.isEmpty || text.isEmpty) return;
    final slot = responseAttractors028.putIfAbsent(
      key,
      () => ResponseSlot028(promptKey: key, promptSurface: prompt.trim()),
    );
    slot.promptSurface = prompt.trim();
    final answerKey = canonicalObject(text);
    final cues = _responseCues028('$prompt $answer');
    final old = slot.candidates[answerKey];
    if (old == null) {
      slot.candidates[answerKey] = ResponseCandidate028(
        key: answerKey,
        text: text,
        strength: (0.48 + 0.28 * max(0.0, reward)).clamp(0.20, 0.96).toDouble(),
        contextCues: cues,
      );
    } else {
      old.supports++;
      old.text = text;
      old.strength = (old.strength + 0.07 + 0.06 * max(0.0, reward))
          .clamp(0.05, 0.995)
          .toDouble();
      old.contextCues.addAll(cues);
    }
  }

  List<String> responseOptions028(String prompt) {
    final slot = _bestResponseSlot028(prompt);
    if (slot == null) return const <String>[];
    final xs = slot.candidates.values.toList()
      ..sort((a, b) => b.strength.compareTo(a.strength));
    return xs.map((e) => e.text).toList();
  }

  String? _responseFromAttractor028(String prompt) {
    final slot = _bestResponseSlot028(prompt);
    if (slot == null || slot.candidates.isEmpty) return null;
    final q = _responseCues028(prompt);

    // Separate response-time geometry from token-learning time. A recently
    // emitted state is transiently inhibited so another plausible attractor
    // can become active without declaring the alternatives contradictory.
    slot.responseTick++;
    final tick = slot.responseTick;

    final xs = slot.candidates.values.toList();
    xs.sort((a, b) {
      double score(ResponseCandidate028 x) {
        final overlap = q.isEmpty
            ? 0.0
            : q.intersection(x.contextCues).length /
                max(1, q.union(x.contextCues).length);
        final age = max(0, tick - x.lastUsed);
        final recencyPenalty =
            age <= 1 ? 0.30 : (age <= 3 ? 0.14 : (age <= 6 ? 0.05 : 0.0));
        return x.strength +
            0.035 * min(4, x.supports) +
            0.12 * overlap -
            recencyPenalty;
      }

      final byScore = score(b).compareTo(score(a));
      if (byScore != 0) return byScore;
      return a.key.compareTo(b.key);
    });

    final chosen = xs.first;
    chosen.lastUsed = tick;
    return chosen.text;
  }

  String respond(String prompt) {
    final compoundEvents = _splitCoordinatedEvents061(prompt);
    final promptTokens = lexicalTokens(prompt).map(normalizeText).toList();
    final promptIsQuestion = normalizeText(prompt).endsWith('?') ||
        promptTokens.any(_questionWords.contains);
    if (!promptIsQuestion && compoundEvents.length > 1) {
      learnEvent(prompt, reward: 0.45);
      return 'Ho integrato ' +
          compoundEvents.length.toString() +
          ' eventi distinti.';
    }

    // A question is evidence about what the user wants, not evidence that a
    // particular semantic relation is correct. Query existing attractors
    // without creating/reinforcing one. Learning is reward-gated after a
    // successful answer or an explicit correction.
    final interpretation = interpret(prompt, speaker: 'user', create: false);
    final report = learnSurface(prompt, reward: 0.20);
    final ep = _storeEpisode(
        userText: prompt, report: report, interpretation: interpretation);

    String? answer;

    // Explicit relational-role cues have semantic precedence at retrieval time.
    // This does NOT replace the normal attractor interpretation: it only asks
    // the dedicated role slot first when the prompt itself contains a role
    // such as compagna/partner/figlia/figlio/madre/padre.
    final roleSurfaces0252b = lexicalTokens(prompt);
    final roleFamily0252b = _roleFamilyIn(roleSurfaces0252b);
    if (roleFamily0252b == 'partner') {
      final roleNormalized0252b = roleSurfaces0252b.map(normalizeText).toList();
      final roleIsQuestion0252b = normalizeText(prompt).endsWith('?') ||
          roleNormalized0252b.any(_questionWords.contains);
      final roleInterpretation0252b = _semanticInterpretation(
        roleSurfaces0252b,
        speaker: 'user',
        create: false,
        isQuestion: roleIsQuestion0252b,
      );
      if (roleInterpretation0252b != null &&
          roleInterpretation0252b.isQuestion &&
          roleInterpretation0252b.subjectId != null &&
          roleInterpretation0252b.relationId != null) {
        answer = _answerFrameQuery(roleInterpretation0252b);
      }
    }

    if (answer == null && _isStatefulPrompt028(prompt, interpretation)) {
      answer = _responseFromAttractor028(prompt);
    }

    if (answer == null && interpretation.isQuestion) {
      answer = _answerFrameQuery(interpretation);
    }

    if (answer == null) {
      answer = _responseFromAttractor028(prompt);
    }

    if (answer == null) {
      final pair = _retrieveEpisode(prompt);
      if (pair != null &&
          pair.agentText != null &&
          pair.agentText!.trim().isNotEmpty) {
        answer = pair.agentText!;
        pair.salience = (pair.salience + 0.03).clamp(0.0, 1.0).toDouble();
      }
    }

    // Free continuation from token statistics is not a semantic answer.
    // Use it only when the interpretation itself is already well constrained;
    // otherwise abstain and let the dedicated language/dialogue layer decide.
    if (answer == null && interpretation.confidence >= 0.72) {
      answer = _generateFromState(prompt);
    }
    if (answer == null || answer.trim().isEmpty) {
      answer =
          'Non ho ancora una rappresentazione abbastanza stabile per rispondere. Insegnamelo o correggimi.';
    }

    final successful = !answer.startsWith('Non ho ancora');
    if (successful && interpretation.relationId != null) {
      _trainRelationAttractor(
        interpretation.relationId!,
        interpretation.relationCues,
        0.08,
      );
    }
    ep.agentText = answer;
    learnSurface(answer, reward: successful ? 0.14 : 0.0);
    return answer;
  }

  Episode04? _retrieveEpisode(String query) {
    final q = encode(query, create: false).ids.toSet();
    final qi = interpret(query, speaker: 'user', create: false);
    BindingFrame04? qFrame;
    if (qi.subjectId != null && qi.relationId != null) {
      qFrame = makeBindingFrame(
          subjectId: qi.subjectId!, relationId: qi.relationId!, isQuery: true);
    }

    Episode04? best;
    var bestScore = 0.0;
    for (final ep in episodes) {
      if (ep.agentText == null || ep.agentText!.trim().isEmpty) continue;
      final e = ep.tokenIds.toSet();
      final lexical = q.isEmpty || e.isEmpty
          ? 0.0
          : q.intersection(e).length / max(1, q.union(e).length);
      final exact =
          normalizeText(query) == normalizeText(ep.userText) ? 1.0 : 0.0;
      var structured = 0.0;
      if (qFrame != null && ep.subjectId != null && ep.relationId != null) {
        final eFrame = makeBindingFrame(
          subjectId: ep.subjectId!,
          relationId: _canonicalRelation(ep.relationId!),
          objectKey: ep.objectKey,
          isQuery: ep.wasQuestion,
        );
        structured = frameSimilarity(qFrame, eFrame);
      }
      final score = 0.40 * lexical +
          0.22 * exact +
          0.25 * structured +
          0.08 * max(0.0, ep.reward) +
          0.05 * ep.salience;
      if (score > bestScore) {
        bestScore = score;
        best = ep;
      }
    }
    return bestScore >= 0.50 ? best : null;
  }

  String _joinTokens(List<int> ids) {
    final out = StringBuffer();
    const noSpace = {'.', ',', '?', '!', ';', ':'};
    for (final id in ids) {
      if (id < 0 || id >= assemblies.length) continue;
      final t = assemblies[id].surface;
      if (t == '<BOS>' || t == '<EOS>') continue;
      if (out.isNotEmpty && !noSpace.contains(t)) out.write(' ');
      out.write(t);
    }
    return out.toString().trim();
  }

  String _generateFromState(String seed) {
    final enc = encode(seed, create: false).ids;
    if (enc.isEmpty) return '';
    final context = [...enc];
    final out = <int>[];
    final eos = _tokenToId['<eos>']!;
    for (var i = 0; i < 20; i++) {
      final next = predictNext(context);
      if (next == null || next == eos) break;
      out.add(next);
      context.add(next);
      final t = assemblies[next].token;
      if (out.length >= 5 && {'.', '?', '!'}.contains(t)) break;
      if (out.length >= 6 &&
          out.sublist(max(0, out.length - 4)).toSet().length <= 1) break;
    }
    final s = _joinTokens(out);
    return s.split(' ').where((e) => e.isNotEmpty).length >= 3 ? s : '';
  }

  void teachResponse(String prompt, String answer, {double reward = 1.0}) {
    final interpretation = interpret(prompt, speaker: 'user', create: true);
    final stateful028 = _isStatefulPrompt028(prompt, interpretation);
    _teachResponseAttractor028(prompt, answer, reward);
    final ep = _findEpisodeForPrompt(prompt) ??
        _storeEpisode(
          userText: prompt,
          report: learnSurface(prompt, reward: 0.40),
          interpretation: interpretation,
          reward: reward,
        );
    ep.agentText = answer.trim();
    ep.reward = reward.clamp(-1.0, 1.0).toDouble();
    ep.salience = 1.0;

    learnSurface(answer, reward: reward);
    if (interpretation.relationId != null) {
      _trainRelationAttractor(
          interpretation.relationId!, interpretation.relationCues, reward);
    }

    if (!stateful028 &&
        interpretation.isQuestion &&
        interpretation.subjectId != null &&
        interpretation.relationId != null) {
      _putFact(
        subjectId: interpretation.subjectId!,
        relationId: interpretation.relationId!,
        objectText: answer,
        reward: reward,
        episodeId: ep.id,
      );
      _linkParaphraseByAnswer(
        subjectId: interpretation.subjectId!,
        relationId: interpretation.relationId!,
        objectText: answer,
      );
    } else {
      final statement = interpret(answer, speaker: 'agent', create: true);
      _learnDeclarativeFrame(answer, statement,
          reward: reward, episodeId: ep.id);
    }

    // Supplemental semantic-role binding. It never replaces the established
    // generic interpretation, so existing identity/coordination behavior stays
    // unchanged; it only prevents a role correction from being swallowed by
    // USER/name when that attractor is already stronger.
    final roleSurfaces0252 = lexicalTokens(prompt);
    final roleFamily0252 = _roleFamilyIn(roleSurfaces0252);
    if (roleFamily0252 != null) {
      final roleNormalized0252 = roleSurfaces0252.map(normalizeText).toList();
      final roleIsQuestion0252 = normalizeText(prompt).endsWith('?') ||
          roleNormalized0252.any(_questionWords.contains);
      final semanticRole0252 = _semanticInterpretation(
        roleSurfaces0252,
        speaker: 'user',
        create: true,
        isQuestion: roleIsQuestion0252,
      );
      if (semanticRole0252 != null &&
          semanticRole0252.subjectId != null &&
          semanticRole0252.relationId != null) {
        _putFact(
          subjectId: semanticRole0252.subjectId!,
          relationId: semanticRole0252.relationId!,
          objectText: answer,
          reward: max(0.95, reward),
          episodeId: ep.id,
        );
        _trainRelationAttractor(
          semanticRole0252.relationId!,
          semanticRole0252.relationCues,
          max(0.95, reward),
        );
        _linkParaphraseByAnswer(
          subjectId: semanticRole0252.subjectId!,
          relationId: semanticRole0252.relationId!,
          objectText: answer,
        );
      }
    }
    discoverConcepts();
  }

  int repairSemanticCorrections0252() {
    var repaired = 0;
    for (final ep in episodes) {
      final answer = ep.agentText?.trim() ?? '';
      if (answer.isEmpty || ep.reward < 0.95) continue;
      final surfaces = lexicalTokens(ep.userText);
      if (surfaces.isEmpty || _roleFamilyIn(surfaces) == null) continue;
      final ns = surfaces.map(normalizeText).toList();
      final isQuestion = normalizeText(ep.userText).endsWith('?') ||
          ns.any(_questionWords.contains);
      if (!isQuestion) continue;
      final i = _semanticInterpretation(
        surfaces,
        speaker: 'user',
        create: true,
        isQuestion: true,
      );
      if (i == null || i.subjectId == null || i.relationId == null) continue;
      final relationId = _canonicalRelation(i.relationId!);
      if (relationId < 0 || relationId >= relations.length) continue;
      if (!relations[relationId].key.startsWith('sem:')) continue;

      final key = canonicalObject(answer);
      final slot = slots['${i.subjectId}::$relationId'];
      final existing = slot?.candidates[key];
      if (existing != null && existing.confidence >= 0.85) continue;

      _putFact(
        subjectId: i.subjectId!,
        relationId: relationId,
        objectText: answer,
        reward: 1.0,
        episodeId: ep.id,
      );
      _trainRelationAttractor(relationId, i.relationCues, 1.0);
      _linkParaphraseByAnswer(
        subjectId: i.subjectId!,
        relationId: relationId,
        objectText: answer,
      );
      repaired++;
    }
    return repaired;
  }

  void reinforcePair(String prompt, String response, bool positive) {
    final ep = _findEpisodeForPrompt(prompt);
    if (ep != null) {
      ep.reward =
          (ep.reward + (positive ? 0.25 : -0.45)).clamp(-1.0, 1.0).toDouble();
      ep.salience =
          (ep.salience + (positive ? 0.08 : -0.16)).clamp(0.0, 1.0).toDouble();
    }
    learnSurface(response, reward: positive ? 0.70 : -0.65);
    if (positive) teachResponse(prompt, response, reward: 0.65);
  }

  LearningReport04 _learnSingleEvent061(
    String text, {
    double reward = 0.45,
  }) {
    final interpretation = interpret(text, speaker: 'user', create: true);
    final report = learnSurface(text, reward: reward);
    if (interpretation.relationId != null) {
      _trainRelationAttractor(
        interpretation.relationId!,
        interpretation.relationCues,
        reward,
      );
    }
    final ep = _storeEpisode(
      userText: text,
      report: report,
      interpretation: interpretation,
      reward: reward,
    );
    _learnDeclarativeFrame(
      text,
      interpretation,
      reward: reward,
      episodeId: ep.id,
    );
    return report;
  }

  LearningReport04 learnNarrativeEpisode24(String text, {double reward = .08}) {
    final report = learnSurface(text, reward: reward);
    final neutral = Interpretation04(
        isQuestion: false,
        subjectId: null,
        relationId: null,
        objectText: null,
        objectKey: null,
        relationCues: const <String>[],
        confidence: 0);
    final ep = _storeEpisode(
        userText: text,
        report: report,
        interpretation: neutral,
        reward: reward);
    ep.salience = (.24 + .36 * report.novelty + .18 * report.predictionError)
        .clamp(.0, .82)
        .toDouble();
    return report;
  }

  LearningReport04 learnEvent(String text, {double reward = 0.45}) {
    final events = _splitCoordinatedEvents061(text);
    if (events.length <= 1) {
      return _learnSingleEvent061(text, reward: reward);
    }

    var tokens = 0;
    var newTokens = 0;
    var novelty = 0.0;
    var error = 0.0;
    var flux = 0.0;
    var weight = 0;

    for (final event in events) {
      final r = _learnSingleEvent061(event, reward: reward);
      final w = max(1, r.tokens);
      tokens += r.tokens;
      newTokens += r.newTokens;
      novelty += r.novelty * w;
      error += r.predictionError * w;
      flux += r.flux * w;
      weight += w;
    }
    discoverConcepts();

    return LearningReport04(
      tokens: tokens,
      newTokens: newTokens,
      novelty: weight == 0 ? 0 : novelty / weight,
      predictionError: weight == 0 ? 0 : error / weight,
      flux: weight == 0 ? 0 : flux / weight,
    );
  }

  void sleepReplay({int cycles = 64}) {
    if (episodes.isEmpty) return;
    final ranked = [...episodes]..sort((a, b) {
        final sa = a.salience + 0.12 * a.boundary + 0.08 * max(0.0, a.reward);
        final sb = b.salience + 0.12 * b.boundary + 0.08 * max(0.0, b.reward);
        return sb.compareTo(sa);
      });
    final selected = ranked.take(min(cycles, ranked.length)).toList();
    var sleepFlux = 0.0;
    for (final ep in selected) {
      final replayReward = 0.14 + 0.20 * max(0.0, ep.reward);
      final r1 = learnSurface(ep.userText, reward: replayReward);
      final ri = interpret(ep.userText, speaker: 'user', create: false);
      if (ri.relationId != null) {
        _trainRelationAttractor(ri.relationId!, ri.relationCues, replayReward);
      }
      sleepFlux += r1.flux;
      if (ep.agentText != null && ep.agentText!.trim().isNotEmpty) {
        sleepFlux += learnSurface(ep.agentText!,
                reward: 0.18 + 0.22 * max(0.0, ep.reward))
            .flux;
      }
      ep.replays++;
    }
    _consolidate();
    discoverConcepts();
    maintenance();
    final normalized =
        (sleepFlux / max(1, selected.length * 2)).clamp(0.0, 1.0).toDouble();
    entropicAge += 0.35 * normalized;
    lastFlux = normalized;
  }

  void _consolidate() {
    for (final graph in [temporal, associative]) {
      for (final row in graph.values) {
        for (final e in row.values) {
          _lazyDecay(e);
          if (e.fast > 0.32 && e.uses >= 2) {
            final old = e.slow;
            e.slow = (e.slow + 0.025 * (1 - e.slow)).clamp(0.0, 1.0).toDouble();
            e.meta =
                (e.meta + 0.018 * (1 - e.meta)).clamp(0.0, 0.95).toDouble();
            entropicAge += 0.01 * (e.slow - old).abs();
          }
        }
      }
    }
  }

  Map<int, Set<String>> _entityFeatures() {
    final out = <int, Set<String>>{};
    for (final slot in slots.values) {
      final relId = _canonicalRelation(slot.relationId);
      final rel = relations[relId];
      final candidates = _relationIsMulti(relId)
          ? slot.candidates.values.where((c) => c.confidence >= 0.50)
          : <FactCandidate04>[if (slot.winner != null) slot.winner!];
      for (final w in candidates) {
        if (w.confidence < 0.50) continue;
        out
            .putIfAbsent(slot.subjectId, () => <String>{})
            .add('r:${rel.key}->${w.objectKey}');
        final objectEntity = _findEntity(w.objectKey);
        if (objectEntity != null) {
          out
              .putIfAbsent(objectEntity, () => <String>{})
              .add('in:${rel.key}<-${entities[slot.subjectId].key}');
        }
      }
    }
    return out;
  }

  void _rebuildSemanticFactsFromEpisodes() {
    final snapshot = [...episodes];
    for (final ep in snapshot) {
      final text = ep.userText.trim();
      if (text.isEmpty) continue;
      final i = interpret(text, speaker: 'user', create: false);

      var subjectId = i.subjectId ?? ep.subjectId;
      int? relationId;

      // Migration-only lexical recovery: old builds sometimes collapsed a
      // singular family role into its plural slot. The raw episode still
      // contains the role word, so use it to restore the intended family.
      final roleFamily = _roleFamilyIn(lexicalTokens(text));
      if (roleFamily != null) {
        relationId = _relationKeyToId['latent:$roleFamily'] ??
            _relationKeyToId['sem:$roleFamily'];
      }

      // Prefer the relation that the original episode was bound to when it
      // can be mapped to a known semantic family. Old slot migration could
      // lose the slot while leaving this episode-level binding intact.
      if (relationId == null &&
          ep.relationId != null &&
          ep.relationId! >= 0 &&
          ep.relationId! < relations.length) {
        final oldId = _canonicalRelation(ep.relationId!);
        final oldRelation = relations[oldId];
        String? family;
        if (oldRelation.key.startsWith('latent:')) {
          final candidate = oldRelation.key.substring(7);
          if (_semanticLabels.containsKey(candidate)) family = candidate;
        } else if (oldRelation.key.startsWith('sem:')) {
          final candidate = oldRelation.key.substring(4);
          if (_semanticLabels.containsKey(candidate)) family = candidate;
        }
        family ??= _semanticFamilyOf(oldRelation.label);
        if (family != null) {
          relationId = _relationKeyToId['latent:$family'] ??
              _relationKeyToId['sem:$family'] ??
              oldId;
        } else {
          relationId = oldId;
        }
      }
      relationId ??= i.relationId;
      if (subjectId == null || relationId == null) continue;

      String? objectText;
      if (!i.isQuestion) {
        objectText = i.objectText;
        if ((objectText == null || objectText.trim().isEmpty) &&
            ep.objectKey != null &&
            ep.objectKey!.trim().isNotEmpty) {
          objectText = ep.objectKey;
        }
      } else if (ep.agentText != null &&
          ep.agentText!.trim().isNotEmpty &&
          !ep.agentText!.startsWith('Non ho ancora')) {
        objectText = ep.agentText;
      }

      if (objectText == null || objectText.trim().isEmpty) continue;
      _putFact(
        subjectId: subjectId,
        relationId: relationId,
        objectText: objectText,
        reward: 0.72,
        episodeId: ep.id,
      );
    }
  }

  void _repairCoordinatedMemory061() {
    final affected = <int, List<String>>{};
    for (final ep in episodes) {
      if (ep.wasQuestion) continue;
      final parts = _splitCoordinatedEvents061(ep.userText);
      if (parts.length > 1) affected[ep.id] = parts;
    }
    if (affected.isEmpty) return;

    final ids = affected.keys.toSet();
    for (final slot in slots.values) {
      slot.candidates.removeWhere((_, candidate) {
        return candidate.sourceEpisodes.any(ids.contains);
      });
    }
    slots.removeWhere((_, slot) => slot.candidates.isEmpty);

    for (final ep in episodes.where((e) => affected.containsKey(e.id))) {
      final reward = max(0.45, ep.reward);
      for (final event in affected[ep.id]!) {
        final i = interpret(event, speaker: 'user', create: true);
        final report = learnSurface(event, reward: reward);
        if (i.relationId != null) {
          _trainRelationAttractor(i.relationId!, i.relationCues, reward);
        }
        _learnDeclarativeFrame(
          event,
          i,
          reward: reward,
          episodeId: ep.id,
        );
        ep.novelty = max(ep.novelty, report.novelty);
        ep.predictionError = min(ep.predictionError, report.predictionError);
      }
    }
  }

  void adoptConcepts320(List<Concept04> value) {
    concepts = value;
    for (final c in value) {
      _nextConceptId = max(_nextConceptId, c.id + 1);
    }
  }

  void discoverConcepts() {
    final features = _entityFeatures();
    final candidateIds = features.keys.where((id) {
      final e = entities[id];
      return e.kind == 'entity' && features[id]!.isNotEmpty;
    }).toList();

    final featureIndex = <String, List<int>>{};
    final candidateOrder = <int, int>{
      for (var i = 0; i < candidateIds.length; i++) candidateIds[i]: i
    };
    for (final id in candidateIds) {
      for (final feature in features[id]!) {
        featureIndex.putIfAbsent(feature, () => []).add(id);
      }
    }
    final used = <int>{};
    final found = <Concept04>[];
    for (final a in candidateIds) {
      if (used.contains(a)) continue;
      final group = <int>[a];
      var simSum = 0.0;
      final possible = <int>{};
      for (final f in features[a]!) {
        possible.addAll(featureIndex[f] ?? const <int>[]);
      }
      final nearby = possible.toList()
        ..sort((a, b) => candidateOrder[a]!.compareTo(candidateOrder[b]!));
      for (final b in nearby) {
        if (a == b || used.contains(b)) continue;
        final fa = features[a]!;
        final fb = features[b]!;
        final sim = fa.intersection(fb).length / max(1, fa.union(fb).length);
        if (sim >= 0.45) {
          group.add(b);
          simSum += sim;
          if (group.length >= 8) break;
        }
      }
      if (group.length >= 2) {
        var shared = {...features[group.first]!};
        for (final id in group.skip(1)) {
          shared = shared.intersection(features[id]!);
        }
        final sharedList = shared.toList();
        var label = 'Concetto ${_nextConceptId}';
        for (final f in sharedList) {
          if (f.contains('rel:ess')) {
            final idx = f.indexOf('->');
            if (idx >= 0 && idx + 2 < f.length)
              label = _titleCase(f.substring(idx + 2));
          }
        }
        found.add(Concept04(
          id: _nextConceptId++,
          label: label,
          entityIds: group,
          sharedFeatures: sharedList,
          coherence: simSum / max(1, group.length - 1),
        ));
        used.addAll(group);
      }
    }
    final oldIds = <String, int>{
      for (final c in concepts) (c.entityIds.toList()..sort()).join(','): c.id
    };
    concepts = found
        .take(24)
        .map((c) => Concept04(
              id: oldIds[(c.entityIds.toList()..sort()).join(',')] ?? c.id,
              label: c.label,
              entityIds: c.entityIds,
              sharedFeatures: c.sharedFeatures,
              coherence: c.coherence,
            ))
        .toList();
  }

  void maintenance() {
    void clean(Map<int, Map<int, PlasticEdge04>> graph) {
      final emptyRows = <int>[];
      for (final rowEntry in graph.entries) {
        final remove = <int>[];
        for (final entry in rowEntry.value.entries) {
          final e = entry.value;
          _lazyDecay(e);
          if ((e.cost > 2.50 && e.meta < 0.25 && step - e.lastUsed > 1400) ||
              e.cost >= 3.55) {
            remove.add(entry.key);
          }
        }
        for (final k in remove) {
          rowEntry.value.remove(k);
        }
        if (rowEntry.value.isEmpty) emptyRows.add(rowEntry.key);
      }
      for (final k in emptyRows) {
        graph.remove(k);
      }
    }

    clean(temporal);
    clean(associative);

    final total = _edgeCount(temporal) + _edgeCount(associative);
    if (total > maxEdges) {
      final all = <PlasticEdge04>[];
      for (final g in [temporal, associative]) {
        for (final row in g.values) {
          all.addAll(row.values);
        }
      }
      all.sort((a, b) {
        final sa = _strength(a) + 0.7 * a.slow + 0.7 * a.meta;
        final sb = _strength(b) + 0.7 * b.slow + 0.7 * b.meta;
        return sa.compareTo(sb);
      });
      final remove = all.take(total - maxEdges).toSet();
      for (final g in [temporal, associative]) {
        for (final row in g.values) {
          row.removeWhere((_, e) => remove.contains(e));
        }
      }
    }
  }

  int _edgeCount(Map<int, Map<int, PlasticEdge04>> g) {
    var n = 0;
    for (final row in g.values) n += row.length;
    return n;
  }

  int ensureSemanticEntity06(String label) => _entityForText(label);

  String _teacherRelationKey082(String raw) {
    return normalizeText(raw)
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _teacherRelationId082(String raw) {
    final n = _teacherRelationKey082(raw);
    final compact = n.replaceAll(' ', '');

    if (compact == 'isa' ||
        n == 'is a' ||
        n == 'tipo di' ||
        n == 'classe di' ||
        n == 'è' ||
        n == 'e') {
      final id = _ensureDevelopmentalRelation(
        'generic-is',
        'è',
        const [
          'il cane è animale',
          'che cosa è il cane?',
          'cosa è il cane?',
          'il cane è un animale?',
        ],
        multiValued: true,
      );
      relations[id].multiValued = true;
      return id;
    }

    if (n == 'ha' ||
        compact == 'has' ||
        n == 'possiede' ||
        n == 'contiene parte') {
      final id = _ensureDevelopmentalRelation(
        'generic-has',
        'ha',
        const [
          'il cane ha zampe',
          'cosa ha il cane?',
          'il cane ha quattro zampe?',
        ],
        multiValued: true,
      );
      relations[id].multiValued = true;
      return id;
    }

    final family = normalizeText(raw)
        .replaceAll(RegExp(r'[^a-z0-9àèéìòù]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final readable = n.isEmpty ? raw.trim() : n;
    return _ensureDevelopmentalRelation(
      'teacher-' + family,
      readable,
      [
        'qualcosa ' + readable + ' qualcosa',
        'cosa ' + readable + ' qualcosa?',
      ],
    );
  }

  int repairTeacherFacts082() {
    var repaired = 0;
    final snapshot =
        relations.where((r) => _canonicalRelation(r.id) == r.id).toList();

    for (final relation in snapshot) {
      final key = normalizeText(relation.key);
      final label = _teacherRelationKey082(relation.label);
      int? target;

      if (key.contains('teacher-is-a') ||
          label == 'is a' ||
          label == 'isa' ||
          label == 'is_a') {
        target = _teacherRelationId082('is_a');
      } else if (key.contains('teacher-ha') || label == 'ha') {
        target = _teacherRelationId082('ha');
      }

      if (target == null || target == relation.id) continue;
      _mergeRelations(target, relation.id);
      repaired++;
    }
    return repaired;
  }

  String _stripElidedArticle082(String raw) {
    final n = normalizeText(raw);
    for (final prefix in const ["l'", "un'"]) {
      if (n.startsWith(prefix) && raw.length > prefix.length) {
        return raw.substring(prefix.length);
      }
    }
    return raw;
  }

  Interpretation04? _interpretClosedPredicateQuestion082(
    String raw, {
    required String speaker,
    required bool create,
  }) {
    final surfaces = lexicalTokens(raw);
    if (surfaces.isEmpty || !normalizeText(raw).endsWith('?')) return null;

    final ns = surfaces.map(normalizeText).toList();
    var predicateIndex = -1;
    String? family;

    for (var i = 0; i < ns.length; i++) {
      final n = ns[i];
      if ({'è', 'e', 'sono', 'sei', 'era', 'sarà', 'sara'}.contains(n)) {
        predicateIndex = i;
        family = 'generic-is';
        break;
      }
      if ({'ha', 'ho', 'hai', 'hanno', 'aveva'}.contains(n)) {
        predicateIndex = i;
        family = 'generic-has';
        break;
      }
    }
    if (predicateIndex <= 0 || family == null) return null;

    final before = <String>[];
    for (final token in surfaces.sublist(0, predicateIndex)) {
      final n = normalizeText(token);
      if (_grammarStops.contains(n) ||
          _questionWords.contains(n) ||
          {'?', '.', ',', '!', ';', ':'}.contains(n)) {
        continue;
      }
      before.add(_stripElidedArticle082(token));
    }
    if (before.isEmpty) return null;

    final subjectText = before.join(' ').trim();
    final subject =
        create ? _entityForText(subjectText) : _findEntity(subjectText);
    if (subject == null) return null;

    final tail = <String>[];
    for (final token in surfaces.sublist(predicateIndex + 1)) {
      final n = normalizeText(token);
      if (_grammarStops.contains(n) ||
          _questionWords.contains(n) ||
          {'?', '.', ',', '!', ';', ':'}.contains(n)) {
        continue;
      }
      tail.add(_stripElidedArticle082(token));
    }
    if (tail.isEmpty) return null;

    final objectText = _joinObject(tail).trim();
    if (objectText.isEmpty) return null;

    final relationRaw = _relationKeyToId['latent:' + family] ??
        _relationKeyToId['sem:' + family];
    if (relationRaw == null) return null;

    return Interpretation04(
      isQuestion: true,
      subjectId: subject,
      relationId: _canonicalRelation(relationRaw),
      objectText: objectText,
      objectKey: canonicalObject(objectText),
      relationCues: <String>[
        family == 'generic-is' ? 'verb:ess' : 'verb:av',
        'mode:q',
      ],
      confidence: 0.99,
    );
  }

  double importTeacherFact08({
    required String subject,
    required String relation,
    required String object,
    double confidence = 0.65,
    String source = 'teacher',
  }) {
    final s = subject.trim();
    final r = relation.trim();
    final o = object.trim();
    if (s.isEmpty || r.isEmpty || o.isEmpty) return 0;

    final c = confidence.clamp(0.0, 1.0).toDouble();
    final subjectId = _entityForText(s);
    final relationId = _teacherRelationId082(r);

    for (final token in lexicalTokens(r)) {
      final cue = 'lex:' + normalizeText(token);
      relations[relationId].cues[cue] =
          (relations[relationId].cues[cue] ?? 0) + 0.25 + 0.35 * c;
      _primeAttractorEdge(relationId, cue, 0.25 + 0.40 * c);
    }

    final statement = s + ' ' + r + ' ' + o;
    final reward = 0.12 + 0.42 * c;
    final report = learnSurface(statement, reward: reward * 0.45);
    final interpretation = Interpretation04(
      isQuestion: false,
      subjectId: subjectId,
      relationId: relationId,
      objectText: o,
      objectKey: canonicalObject(o),
      relationCues:
          lexicalTokens(r).map((x) => 'lex:' + normalizeText(x)).toList(),
      confidence: 0.40 + 0.45 * c,
    );

    final ep = _storeEpisode(
      userText: '[teacher:' + source + '] ' + statement,
      report: report,
      interpretation: interpretation,
      reward: reward,
    );
    ep.salience = (0.18 + 0.42 * c).clamp(0.0, 0.72).toDouble();

    final flux = _putFact(
      subjectId: subjectId,
      relationId: relationId,
      objectText: o,
      reward: reward,
      episodeId: ep.id,
      synchronize: false,
    );
    relations[relationId].uses++;
    return flux;
  }

  bool reconcileResearch317(int sid, String relation, String object,
      String status, Iterable<String> families) {
    if (sid < 0 || sid >= entities.length) return false;
    final rid = _teacherRelationId082(relation), key = canonicalObject(object);
    final slot = slots.putIfAbsent(
        '$sid::$rid', () => RelationSlot04(subjectId: sid, relationId: rid));
    final old = slot.candidates[key];
    if (old != null &&
        (old.sourceEpisodes.isNotEmpty || old.epistemicStatus == 'experienced'))
      return false;
    final c = old ?? FactCandidate04(objectKey: key, display: object);
    c.epistemicStatus = status == 'accettata'
        ? 'consolidated'
        : status == 'documentata'
            ? 'documented'
            : 'review';
    c.confidence = status == 'accettata'
        ? 0.70
        : status == 'documentata'
            ? 0.30
            : 0.05;
    c.sourceFamilies
      ..clear()
      ..addAll(families);
    c.supports = families.length;
    c.lastStep = step;
    slot.candidates[key] = c;
    return true;
  }

  double importResearchHypothesis028({
    required int subjectId,
    required String relation,
    required String object,
    double confidence = 0.45,
    Iterable<String> sourceFamilies = const <String>[],
  }) {
    if (subjectId < 0 || subjectId >= entities.length) return 0;
    final o = object.trim();
    if (relation.trim().isEmpty || o.isEmpty) return 0;
    final relationId = _teacherRelationId082(relation);
    final objectKey = canonicalObject(o);
    _entityForText(o);
    final slot = slots.putIfAbsent(
      '$subjectId::$relationId',
      () => RelationSlot04(subjectId: subjectId, relationId: relationId),
    );
    final c0 = confidence.clamp(0.0, 1.0).toDouble();
    final target = (0.20 + 0.30 * c0).clamp(0.20, 0.50).toDouble();
    final existing = slot.candidates[objectKey];
    if (existing == null) {
      slot.candidates[objectKey] = FactCandidate04(
        objectKey: objectKey,
        display: _titleCase(o),
        confidence: target,
        lastStep: step,
        epistemicStatus: 'hypothesis',
        sourceFamilies: sourceFamilies.toSet(),
      );
    } else {
      existing.supports++;
      existing.lastStep = step;
      existing.display = _titleCase(o);
      existing.confidence = max(existing.confidence, target);
      if (existing.epistemicStatus != 'consolidated')
        existing.epistemicStatus = 'hypothesis';
      existing.sourceFamilies.addAll(sourceFamilies);
    }
    entities[subjectId].mentions++;
    entities[subjectId].lastSeen = step;
    relations[relationId].uses++;
    return target;
  }

  double importResearchFact028({
    required int subjectId,
    required String relation,
    required String object,
    double confidence = 0.65,
    Iterable<String> sourceFamilies = const <String>[],
  }) {
    if (subjectId < 0 || subjectId >= entities.length) return 0;
    final relationId = _teacherRelationId082(relation);
    final c = confidence.clamp(0.0, 1.0).toDouble();
    final flux = _putFact(
      subjectId: subjectId,
      relationId: relationId,
      objectText: object,
      reward: 0.24 + 0.48 * c,
      synchronize: false,
    );
    final candidate =
        slots['$subjectId::$relationId']?.candidates[canonicalObject(object)];
    if (candidate != null) {
      candidate.epistemicStatus = 'consolidated';
      candidate.sourceFamilies.addAll(sourceFamilies);
      candidate.confidence = max(
          candidate.confidence, (0.56 + 0.30 * c).clamp(0.0, 0.94).toDouble());
    }
    return flux;
  }

  int? entityIdForLabel06(String label) {
    final n = normalizeText(label);
    final senses = lexicalSenses028[n] ?? const <LexicalSense028>[];
    if (senses.length == 1) return senses.first.entityId;
    if (senses.length > 1) return null;
    final indexed = _entityKeyToId[n];
    if (indexed != null) return indexed;
    for (final e in entities) {
      if (normalizeText(e.label) == n || e.aliases.contains(n)) return e.id;
    }
    return null;
  }

  List<CognitiveFact06> groundedFacts320() {
    final out = <CognitiveFact06>[];
    for (final slot in slots.values) {
      final rid = _canonicalRelation(slot.relationId);
      final eligible = slot.candidates.values
          .where((c) =>
              c.contradictions == 0 &&
              c.confidence >= .50 &&
              ((c.epistemicStatus == 'experienced' &&
                      c.sourceEpisodes.isNotEmpty) ||
                  (c.epistemicStatus == 'consolidated' &&
                      c.sourceFamilies.isNotEmpty)))
          .toList();
      if (!_relationIsMulti(rid) && eligible.length != 1) continue;
      for (final c in eligible) {
        out.add(CognitiveFact06(
            subjectId: slot.subjectId,
            relationId: rid,
            relation: relations[rid].label,
            object: c.display,
            objectEntityId: entityIdForLabel06(c.display),
            confidence: c.confidence));
      }
    }
    return out;
  }

  List<CognitiveFact06> cognitiveFacts06() {
    final out = <CognitiveFact06>[];
    for (final slot in slots.values) {
      final relId = _canonicalRelation(slot.relationId);
      final rel = relations[relId];
      final candidates = _relationIsMulti(relId)
          ? slot.candidates.values.where((c) => c.confidence >= 0.35)
          : <FactCandidate04>[if (slot.winner != null) slot.winner!];
      for (final c in candidates) {
        if (c.confidence < 0.35) continue;
        out.add(CognitiveFact06(
          subjectId: slot.subjectId,
          relationId: relId,
          relation: rel.label,
          object: c.display,
          objectEntityId: entityIdForLabel06(c.display),
          confidence: c.confidence,
        ));
      }
    }
    return out;
  }

  Brain04Stats stats() {
    var slowSum = 0.0;
    var n = 0;
    for (final g in [temporal, associative]) {
      for (final row in g.values) {
        for (final e in row.values) {
          slowSum += e.slow;
          n++;
        }
      }
    }
    return Brain04Stats(
      vocabulary: max(0, assemblies.length - 2),
      synapses: _edgeCount(temporal) + _edgeCount(associative),
      entities: entities.length,
      relations:
          relations.where((r) => _canonicalRelation(r.id) == r.id).length,
      episodes: episodes.length,
      facts: slots.length,
      conflicts: slots.values.where((slot) {
        final relId = _canonicalRelation(slot.relationId);
        return !_relationIsMulti(relId) && slot.hasConflict;
      }).length,
      concepts: concepts.length,
      novelty: noveltyEma,
      predictionError: predictionErrorEma,
      curiosity: curiosity,
      entropicAge: entropicAge,
      lastFlux: lastFlux,
      meanSlow: n == 0 ? 0 : slowSum / n,
    );
  }

  List<
      ({
        String subject,
        String relation,
        String object,
        double confidence,
        bool conflict
      })> strongestFacts({int limit = 24}) {
    final xs = <({
      String subject,
      String relation,
      String object,
      double confidence,
      bool conflict
    })>[];
    for (final slot in slots.values) {
      final relId = _canonicalRelation(slot.relationId);
      final rel = relations[relId];
      if (_relationIsMulti(relId)) {
        final values = slot.candidates.values
            .where((c) => c.confidence >= 0.35)
            .toList()
          ..sort((a, b) => b.confidence.compareTo(a.confidence));
        if (values.isEmpty) continue;
        xs.add((
          subject: entities[slot.subjectId].label,
          relation: rel.label,
          object: values.map((e) => e.display).join(' · '),
          confidence: values.map((e) => e.confidence).reduce(min),
          conflict: false,
        ));
      } else {
        final w = slot.winner;
        if (w == null) continue;
        xs.add((
          subject: entities[slot.subjectId].label,
          relation: rel.label,
          object: w.display,
          confidence: w.confidence,
          conflict: slot.hasConflict,
        ));
      }
    }
    xs.sort((a, b) => b.confidence.compareTo(a.confidence));
    return xs.take(limit).toList();
  }

  List<({String from, String relation, String to, double confidence})>
      semanticGraph({int limit = 40}) {
    final out =
        <({String from, String relation, String to, double confidence})>[];
    for (final slot in slots.values) {
      final relId = _canonicalRelation(slot.relationId);
      final rel = relations[relId];
      if (_relationIsMulti(relId)) {
        for (final c in slot.candidates.values) {
          if (c.confidence < 0.35) continue;
          out.add((
            from: entities[slot.subjectId].label,
            relation: rel.label,
            to: c.display,
            confidence: c.confidence,
          ));
        }
      } else {
        final w = slot.winner;
        if (w == null || w.confidence < 0.35) continue;
        out.add((
          from: entities[slot.subjectId].label,
          relation: rel.label,
          to: w.display,
          confidence: w.confidence,
        ));
      }
    }
    for (final entry in lexicalSenses028.entries) {
      final hub = entities[_entityKeyToId[entry.key] ??
              _entityForText(entry.key, kind: 'lexeme')]
          .label;
      for (final sense in entry.value) {
        if (sense.entityId < 0 || sense.entityId >= entities.length) continue;
        out.add((
          from: hub,
          relation: 'può significare',
          to: entities[sense.entityId].label,
          confidence: sense.confidence.clamp(0.25, 0.95).toDouble(),
        ));
      }
    }
    out.sort((a, b) => b.confidence.compareTo(a.confidence));
    return out.take(limit).toList();
  }

  double frameSimilarity(BindingFrame04 a, BindingFrame04 b) {
    final s = _hammingSimilarity(a.subjectBinding, b.subjectBinding);
    final r = _hammingSimilarity(a.relationBinding, b.relationBinding);
    final o = a.objectBinding != null && b.objectBinding != null
        ? _hammingSimilarity(a.objectBinding!, b.objectBinding!)
        : 0.5;
    return (0.35 * s + 0.40 * r + 0.25 * o).clamp(0.0, 1.0).toDouble();
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'assemblies': assemblies.map((e) => e.toJson()).toList(),
        'temporal': _graphToJson(temporal),
        'associative': _graphToJson(associative),
        'workingMemory': workingMemory,
        'entities': entities.map((e) => e.toJson()).toList(),
        'relations': relations.map((e) => e.toJson()).toList(),
        'relationRedirect':
            relationRedirect.map((k, v) => MapEntry(k.toString(), v)),
        'slots': slots.values.map((e) => e.toJson()).toList(),
        'lexicalSenses028': lexicalSenses028.values
            .expand((e) => e)
            .map((e) => e.toJson())
            .toList(),
        'responseAttractors028':
            responseAttractors028.values.map((e) => e.toJson()).toList(),
        'entitySurfaceForms031': {
          for (final e in entitySurfaceForms031.entries)
            e.key.toString(): e.value
        },
        'relationSurfaceFrames031': {
          for (final e in relationSurfaceFrames031.entries)
            e.key.toString(): e.value
        },
        'episodes': episodes.map((e) => e.toJson()).toList(),
        'concepts': concepts.map((e) => e.toJson()).toList(),
        'step': step,
        'nextEpisodeId': _nextEpisodeId,
        'nextConceptId': _nextConceptId,
        'noveltyEma': noveltyEma,
        'predictionErrorEma': predictionErrorEma,
        'curiosity': curiosity,
        'entropicAge': entropicAge,
        'lastFlux': lastFlux,
      };

  List<Map<String, dynamic>> _graphToJson(Map<int, Map<int, PlasticEdge04>> g) {
    final out = <Map<String, dynamic>>[];
    for (final row in g.values) out.addAll(row.values.map((e) => e.toJson()));
    return out;
  }

  String encodeJson() => jsonEncode(toJson());

  static PlasticLanguageBrain04 fromJson(Map<String, dynamic> j) {
    final storedVersion = (j['version'] as num?)?.toInt() ?? 0;
    if (storedVersion != 4 &&
        storedVersion != 5 &&
        storedVersion != 6 &&
        storedVersion != 7 &&
        storedVersion != 8) return PlasticLanguageBrain04();
    final b = PlasticLanguageBrain04();
    b._tokenToId.clear();
    b.assemblies.clear();
    for (final raw in (j['assemblies'] as List?) ?? const []) {
      final a = TokenAssembly04.fromJson(Map<String, dynamic>.from(raw as Map));
      b.assemblies.add(a);
      b._tokenToId[a.token] = a.id;
    }
    b.temporal.clear();
    b.associative.clear();
    void loadGraph(dynamic raw, Map<int, Map<int, PlasticEdge04>> target) {
      for (final x in (raw as List?) ?? const []) {
        final e = PlasticEdge04.fromJson(Map<String, dynamic>.from(x as Map));
        target.putIfAbsent(e.from, () => {})[e.to] = e;
      }
    }

    loadGraph(j['temporal'], b.temporal);
    loadGraph(j['associative'], b.associative);
    b.workingMemory
      ..clear()
      ..addAll(((j['workingMemory'] as List?) ?? const [])
          .map((e) => (e as num).toInt()));

    b._entityKeyToId.clear();
    b.entities.clear();
    for (final raw in (j['entities'] as List?) ?? const []) {
      final e = EntityMemory04.fromJson(Map<String, dynamic>.from(raw as Map));
      b.entities.add(e);
      b._entityKeyToId[e.key] = e.id;
    }
    if (!b._entityKeyToId.containsKey(selfKey))
      b._ensureEntity(selfKey, 'SELF', 'self');
    if (!b._entityKeyToId.containsKey(userKey))
      b._ensureEntity(userKey, 'UTENTE', 'user');

    b.lexicalSenses028.clear();
    for (final raw in (j['lexicalSenses028'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final sense = LexicalSense028.fromJson(Map<String, dynamic>.from(raw));
      if (sense.lexeme.isEmpty ||
          sense.entityId < 0 ||
          sense.entityId >= b.entities.length) continue;
      b.lexicalSenses028
          .putIfAbsent(sense.lexeme, () => <LexicalSense028>[])
          .add(sense);
    }
    b.responseAttractors028.clear();
    for (final raw in (j['responseAttractors028'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final slot = ResponseSlot028.fromJson(Map<String, dynamic>.from(raw));
      if (slot.promptKey.isNotEmpty)
        b.responseAttractors028[slot.promptKey] = slot;
    }
    b.entitySurfaceForms031.clear();
    final esf031 = j['entitySurfaceForms031'];
    if (esf031 is Map) {
      for (final e in esf031.entries) {
        final id = int.tryParse(e.key.toString());
        if (id == null || e.value is! Map) continue;
        b.entitySurfaceForms031[id] = Map<String, int>.from((e.value as Map)
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
      }
    }
    b.relationSurfaceFrames031.clear();
    final rsf031 = j['relationSurfaceFrames031'];
    if (rsf031 is Map) {
      for (final e in rsf031.entries) {
        final id = int.tryParse(e.key.toString());
        if (id == null || e.value is! Map) continue;
        b.relationSurfaceFrames031[id] = Map<String, int>.from((e.value as Map)
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
      }
    }

    b._relationKeyToId.clear();
    b.relations.clear();
    for (final raw in (j['relations'] as List?) ?? const []) {
      final r =
          RelationMemory04.fromJson(Map<String, dynamic>.from(raw as Map));
      b.relations.add(r);
      b._relationKeyToId[r.key] = r.id;
    }
    b.relationRedirect.clear();
    final redirectRaw = j['relationRedirect'];
    if (redirectRaw is Map) {
      for (final e in redirectRaw.entries) {
        b.relationRedirect[int.parse(e.key.toString())] =
            (e.value as num).toInt();
      }
      for (final r in b.relations) {
        b._relationKeyToId[r.key] = b._canonicalRelation(r.id);
      }
    }
    b.slots.clear();
    for (final raw in (j['slots'] as List?) ?? const []) {
      final s = RelationSlot04.fromJson(Map<String, dynamic>.from(raw as Map));
      b.slots[s.key] = s;
    }
    b.episodes
      ..clear()
      ..addAll(((j['episodes'] as List?) ?? const [])
          .map((e) => Episode04.fromJson(Map<String, dynamic>.from(e as Map))));
    b.concepts = ((j['concepts'] as List?) ?? const [])
        .map((e) => Concept04.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    b.step = (j['step'] as num?)?.toInt() ?? 0;
    b._nextEpisodeId = (j['nextEpisodeId'] as num?)?.toInt() ??
        (b.episodes.isEmpty ? 1 : b.episodes.map((e) => e.id).reduce(max) + 1);
    b._nextConceptId = (j['nextConceptId'] as num?)?.toInt() ?? 1;
    b.noveltyEma = (j['noveltyEma'] as num?)?.toDouble() ?? 0;
    b.predictionErrorEma = (j['predictionErrorEma'] as num?)?.toDouble() ?? 0;
    b.curiosity = (j['curiosity'] as num?)?.toDouble() ?? 0;
    b.entropicAge = (j['entropicAge'] as num?)?.toDouble() ?? 0;
    b.lastFlux = (j['lastFlux'] as num?)?.toDouble() ?? 0;
    final needsMigration = storedVersion < version;
    if (needsMigration) {
      b.repairSemanticMemory();
    }
    b._developmentalPriorsInstalled = false;
    b._installDevelopmentalPriors();
    if (needsMigration) {
      b._rebuildSemanticFactsFromEpisodes();
      b.repairSemanticMemory();
      // repairSemanticMemory can redirect latent relations to canonical
      // semantic IDs. Re-prime the MGD feature edges on those final anchors.
      b._developmentalPriorsInstalled = false;
      b._installDevelopmentalPriors();
      b._repairCoordinatedMemory061();
      b.discoverConcepts();
    }
    return b;
  }

  static PlasticLanguageBrain04 migrateFromV03(Map<String, dynamic> j) {
    final b = PlasticLanguageBrain04();
    final seen = <String>{};
    for (final raw in (j['episodes'] as List?) ?? const []) {
      final m = Map<String, dynamic>.from(raw as Map);
      final prompt = (m['prompt'] as String?)?.trim() ?? '';
      final response = (m['response'] as String?)?.trim() ?? '';
      if (prompt.isEmpty || response.isEmpty) continue;
      final key = '${normalizeText(prompt)}=>${normalizeText(response)}';
      if (!seen.add(key)) continue;
      b.respond(prompt);
      b.teachResponse(prompt, response, reward: 0.9);
    }
    b.repairSemanticMemory();
    b.discoverConcepts();
    return b;
  }
}
