import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'plastic_language_brain_v04.dart';
import 'native_mgd_engine_v09.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';
import 'corpus_semantic_bridge_v022.dart';
import 'mgd_state_store_v026.dart';

String _encodeLanguageSnapshot21(Map<String, dynamic> x) => jsonEncode(x);

class MgdLanguageStats20 {
  // Unique graph sizes.
  final int tokens;
  final int edges;
  final int chunks;

  // Cumulative exposure counters. These keep increasing even when a corpus
  // contains only words/transitions the graph has already seen.
  final int tokenOccurrences;
  final int edgeUses;
  final int chunkOccurrences;
  final int sentences;
  final int characters;
  final double meanMaterial;
  final double lastFlux;

  const MgdLanguageStats20({
    required this.tokens,
    required this.edges,
    required this.chunks,
    required this.tokenOccurrences,
    required this.edgeUses,
    required this.chunkOccurrences,
    required this.sentences,
    required this.characters,
    required this.meanMaterial,
    required this.lastFlux,
  });
}

class _LangEdge20 {
  final String a, b;
  int uses;
  double fast, slow, material, cost;
  _LangEdge20(
    this.a,
    this.b, {
    this.uses = 0,
    this.fast = 0,
    this.slow = 0,
    this.material = 0,
    this.cost = 1.1,
  });
  Map<String, dynamic> toJson() => {
        'a': a,
        'b': b,
        'u': uses,
        'f': fast,
        's': slow,
        'm': material,
        'c': cost,
      };
  factory _LangEdge20.fromJson(Map<String, dynamic> j) => _LangEdge20(
        j['a'],
        j['b'],
        uses: (j['u'] as num?)?.toInt() ?? 0,
        fast: (j['f'] as num?)?.toDouble() ?? 0,
        slow: (j['s'] as num?)?.toDouble() ?? 0,
        material: (j['m'] as num?)?.toDouble() ?? 0,
        cost: (j['c'] as num?)?.toDouble() ?? 1.1,
      );
}

class _Chunk20 {
  final String text;
  int count;
  double material;
  _Chunk20(this.text, {this.count = 0, this.material = 0});
  Map<String, dynamic> toJson() => {'t': text, 'c': count, 'm': material};
  factory _Chunk20.fromJson(Map<String, dynamic> j) => _Chunk20(
        j['t'],
        count: (j['c'] as num?)?.toInt() ?? 0,
        material: (j['m'] as num?)?.toDouble() ?? 0,
      );
}

class MgdLanguage20 {
  MgdLanguage20();
  final Map<String, dynamic> webSeen317 = {};
  Future<int> ingestWeb317(WebDocument11 doc) async {
    if (doc.provider == 'Wikidata proprietà') return 0;
    var added = 0;
    final sentences317 = doc.text.split(RegExp(r'(?<=[.!?])\s+|\n+'));
    for (final sentence in sentences317) {
      if (sentence.length < 8 || sentence.length > 1400) continue;
      final words = ResearchSemantics317.tokens(sentence).toSet();
      final it = words.intersection({
        'il',
        'lo',
        'la',
        'gli',
        'le',
        'una',
        'sono',
        'è',
        'della',
        'delle',
        'degli',
        'costituiti',
        'che',
      }).length;
      final en = words.intersection({
        'the',
        'are',
        'is',
        'of',
        'and',
        'with',
        'which',
        'that',
      }).length;
      if (it == 0 || en > it) continue;
      final key = ResearchSemantics317.digest([
        ResearchSemantics317.norm(sentence),
      ]);
      if (webSeen317.containsKey(key)) continue;
      ingestText(sentence, reward: 0.20);
      webSeen317[key] = {
        'sourceUrl': doc.url,
        'sourceTitle': doc.title,
        'provider': doc.provider,
        'language': 'it',
        'text': sentence,
      };
      added++;
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    return added;
  }

  static const double epsilon = 0.86, alpha = 0.82, rho = 0.965, xi = 0.03;
  static const _materialParameters320 = MgdParameters09(rho: rho, xi: xi);
  final Map<String, Map<String, int>> frames320 = {};
  final Map<String, bool> subjectPlural320 = {};
  final Map<String, int> tokenCount = {};
  final Map<String, _LangEdge20> edges = {};
  final Map<String, _Chunk20> chunks = {};

  // MGD 0.21 Active Cognitive Graph. The persistent graph may grow without
  // bound; a thought only touches the locally active neighbourhood.
  final Map<String, List<_LangEdge20>> _outgoing21 = {};
  final Map<String, List<_Chunk20>> _chunksByHead21 = {};
  bool _indexesReady21 = false;
  int lastGenerateMicros21 = 0;
  int lastVisitedEdges21 = 0;
  int lastPeakFrontier21 = 0;
  String lastStopReason21 = '';

  int sentences = 0, characters = 0;
  double lastFlux = 0;

  static List<String> toks(String s) => PlasticLanguageBrain04.lexicalTokens(s)
      .map(PlasticLanguageBrain04.normalizeText)
      .where((x) => x.isNotEmpty)
      .toList();
  static bool punct(String x) =>
      const {'.', '!', '?', ',', ';', ':'}.contains(x);
  String _ek(String a, String b) => '$a\u0001$b';

  void _indexEdge21(_LangEdge20 e) {
    final xs = _outgoing21.putIfAbsent(e.a, () => <_LangEdge20>[]);
    if (!xs.contains(e)) xs.add(e);
  }

  void _indexChunk21(_Chunk20 c) {
    if (c.count < 3) return;
    final ts = c.text.split(' ');
    if (ts.isEmpty) return;
    final xs = _chunksByHead21.putIfAbsent(ts.first, () => <_Chunk20>[]);
    if (!xs.contains(c)) xs.add(c);
  }

  void _rebuildIndexes21() {
    _outgoing21.clear();
    _chunksByHead21.clear();
    for (final e in edges.values) _indexEdge21(e);
    for (final c in chunks.values) _indexChunk21(c);
    _indexesReady21 = true;
  }

  void _ensureIndexes21() {
    if (!_indexesReady21) _rebuildIndexes21();
  }

  void ingestText(String text, {double reward = .35}) {
    final raw = text.trim();
    if (raw.isEmpty) return;
    characters += raw.length;
    final units = raw
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .where((x) => x.trim().isNotEmpty);
    var flux = 0.0;
    for (final sentence in units) {
      _learnFrame320(sentence);
      final xs = toks(sentence);
      if (xs.isEmpty) continue;
      sentences++;
      for (final x in xs) {
        tokenCount[x] = (tokenCount[x] ?? 0) + 1;
      }
      final seq = <String>['<bos>', ...xs, '<eos>'];
      for (var i = 0; i < seq.length - 1; i++) {
        final a = seq[i], b = seq[i + 1], k = _ek(a, b);
        var e = edges[k];
        if (e == null) {
          e = _LangEdge20(a, b);
          edges[k] = e;
          _indexEdge21(e);
        }
        final old = e.material;
        e.uses++;
        e.fast = alpha * e.fast + (1 - alpha);
        e.slow = rho * e.slow + (1 - rho) * e.fast;
        final drive = (.55 * e.fast + .45 * e.slow).clamp(0.0, 1.0);
        e.material = (rho * e.material +
                (1 - rho) * drive +
                xi * e.material * (1 - e.material))
            .clamp(0.0, 1.0);
        final mStar = MgdMath09.equilibriumMaterial(
          drive,
          p: _materialParameters320,
        );
        final saturation = max(0.0, e.material - mStar);
        e.cost = (1.12 -
                .62 * e.slow -
                .38 * min(e.material, mStar) +
                .95 * saturation +
                .08 * (1 - reward))
            .clamp(.08, 2.4);
        flux += (e.material - old).abs();
      }
      for (var n = 2; n <= 5; n++) {
        for (var i = 0; i + n <= xs.length; i++) {
          final phrase = xs.sublist(i, i + n).join(' ');
          final c = chunks.putIfAbsent(phrase, () => _Chunk20(phrase));
          c.count++;
          final target = (c.count / (c.count + 4.0)).clamp(0.0, 1.0);
          c.material = (.93 * c.material +
                  .07 * target +
                  xi * c.material * (1 - c.material))
              .clamp(0.0, 1.0);
          _indexChunk21(c);
        }
      }
    }
    final beforeChunks = chunks.length;
    chunks.removeWhere((_, c) => c.count < 3 && chunks.length > 5000);
    if (chunks.length != beforeChunks) _rebuildIndexes21();
    lastFlux = flux;
  }

  void bootstrapFromBrain(PlasticLanguageBrain04 brain) {
    if (sentences > 0) return;
    for (final ep in brain.episodes) {
      ingestText(ep.userText, reward: .25);
      if (ep.agentText?.trim().isNotEmpty == true)
        ingestText(ep.agentText!, reward: .30);
    }
  }

  List<_LangEdge20> _next(String from) {
    _ensureIndexes21();
    return List<_LangEdge20>.of(_outgoing21[from] ?? const <_LangEdge20>[]);
  }

  double _chunkBonus21(String token, Set<String> wanted) {
    _ensureIndexes21();
    var best = 0.0;
    for (final c in _chunksByHead21[token] ?? const <_Chunk20>[]) {
      if (c.count < 4) continue;
      var topic = 0.0;
      if (wanted.isNotEmpty) {
        final ts = c.text.split(' ');
        final hits = ts.where(wanted.contains).length;
        topic = .08 * hits;
      }
      best = max(best, .10 * c.material + .012 * log(1 + c.count) + topic);
    }
    return best;
  }

  void _learnFrame320(String sentence) {
    sentence = sentence.trim();
    final match = RegExp(
      r'^(.+?)\s+(è|sono|ha|hanno|contiene|contengono|serve|servono)\s+',
      caseSensitive: false,
    ).firstMatch(sentence.trim());
    if (match == null) return;
    final subject = match[1]!.trim().replaceFirst(
        RegExp(r"^(?:il|lo|la|i|gli|le|un|uno|una)\s+|^l[’']",
            caseSensitive: false),
        '');
    final doc = WebDocument11(
      provider: 'lingua osservata',
      family: '',
      title: subject,
      url: '',
      text: sentence,
      trust: 0,
    );
    final claims = ResearchSemantics317.extract(subject, sentence, doc);
    for (final c in claims) {
      if (c.meta317['polarity'] == -1 ||
          (c.meta317['qualifiers'] as Map).isNotEmpty) continue;
      final objectStart = sentence.toLowerCase().lastIndexOf(
            c.object.toLowerCase(),
          );
      if (objectStart < match.end - 1) continue;
      var bridge = sentence.substring(match[1]!.length, objectStart).trim();
      // Articles/gender belong to the noun phrase, not a reusable predicate.
      bridge = bridge.replaceFirst(
        RegExp(r'\s+(un|uno|una|il|lo|la|i|gli|le)$', caseSensitive: false),
        '',
      );
      if (bridge.isEmpty) continue;
      final plural = {
        'sono',
        'hanno',
        'contengono',
        'servono',
      }.contains(match[2]!.toLowerCase());
      subjectPlural320[ResearchSemantics317.concept(subject)] = plural;
      final key =
          '${ResearchSemantics317.relation(c.relation)}|${plural ? 1 : 0}';
      final bucket = frames320.putIfAbsent(key, () => {});
      bucket[bridge] = (bucket[bridge] ?? 0) + 1;
    }
  }

  /// Recombine an explicit fact with a predicate actually seen in source text.
  /// Subject, relation and object are fixed; graph scores choose surface form.
  /// Generated text is never fed back as evidence or as a new observation.
  String? realizeFact320(
    String subject,
    String relation,
    String object, {
    bool? plural,
  }) {
    final clock = Stopwatch()..start();
    lastVisitedEdges21 = 0;
    lastPeakFrontier21 = 0;
    if({'è','sono','is a','classe di'}.contains(ResearchSemantics317.norm(relation)))relation='tipo di';
    final key = ResearchSemantics317.concept(subject);
    final number = plural ??
        subjectPlural320[key] ??
        RegExp(r'^(?:i|gli|le)\s', caseSensitive: false).hasMatch(subject);
    final bucket = frames320[
        '${ResearchSemantics317.relation(relation)}|${number ? 1 : 0}'];
    if (bucket == null || bucket.isEmpty) {
      lastStopReason21 = 'nessuna forma osservata per la relazione';
      return null;
    }
    final wanted = toks('$subject $object').toSet();
    final candidates = <({String text, double score})>[];
    for (final frame in bucket.entries) {
      final text = '$subject ${frame.key} $object${RegExp(r"[.!?]$").hasMatch(object)?"":"."}';
      final ts = ['<bos>', ...toks(text), '<eos>'];
      var score = log(1 + frame.value);
      for (var i = 0; i < ts.length - 1; i++) {
        final e = edges[_ek(ts[i], ts[i + 1])];
        if (e != null) {
          score += _scoreEdge(e, wanted);
          lastVisitedEdges21++;
        }
      }
      candidates.add((text: text, score: score / max(1, ts.length)));
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    lastPeakFrontier21 = candidates.length;
    lastGenerateMicros21 = clock.elapsedMicroseconds;
    lastStopReason21 = 'composizione vincolata a un fatto, forme apprese';
    var out = candidates.first.text.trim();
    out = out[0].toUpperCase() + out.substring(1);
    if (!RegExp(r'[.!?]$').hasMatch(out)) out += '.';
    return out;
  }

  String? generate(
    String context, {
    String? semanticHint,
    PlasticLanguageBrain04? brain,
    int maxWords = 42,
  }) {
    _ensureIndexes21();
    lastVisitedEdges21 = 0;
    lastPeakFrontier21 = 0;
    lastGenerateMicros21 = 0;
    final hint = (semanticHint ?? '').trim();
    if (hint.isNotEmpty &&
        !hint.startsWith(
          'Non ho ancora una rappresentazione abbastanza stabile',
        )) {
      // Compatibility for explicit corrections/composed answers. This is
      // formatting, not a successful autonomous language-generation test.
      lastStopReason21 = 'risposta semantica conservata';
      return hint;
    }
    final wanted = ' ${ResearchSemantics317.concept(context)} ';
    if (brain != null) {
      final facts = brain
          .groundedFacts320()
          .where(
            (f) =>
                f.confidence >= .50 &&
                f.subjectId >= 0 &&
                f.subjectId < brain.entities.length &&
                wanted.contains(
                  ' ${ResearchSemantics317.concept(brain.entities[f.subjectId].label)} ',
                ),
          )
          .toList();
      if (facts.isNotEmpty) {
        final f = facts.first;
        final out = realizeFact320(
          brain.entities[f.subjectId].label,
          f.relation,
          f.object,
        );
        if (out != null) return out;
      }
    }
    final ts = toks(context).where((x) => !punct(x)).toList();
    if (ts.isNotEmpty && ts.length <= 2) {
      var previous = '<bos>', closed = true;
      for (final t in ts) {
        if (!edges.containsKey(_ek(previous, t))) {
          closed = false;
          break;
        }
        previous = t;
      }
      if (closed && _next(previous).any((e) => e.b == '<eos>' || punct(e.b))) {
        lastVisitedEdges21 = ts.length + 1;
        lastPeakFrontier21 = 1;
        lastStopReason21 = 'utteranza breve stabilizzata';
        return _surface(ts, brain);
      }
    }
    lastStopReason21 = 'nessun fatto utilizzabile o forma appresa';
    return null;
  }

  double _scoreEdge(_LangEdge20 e, Set<String> wanted) {
    final mStar = MgdMath09.equilibriumMaterial(
      e.slow,
      p: _materialParameters320,
    );
    final topic = wanted.contains(e.b) ? 0.22 : 0.0;
    final flow = (.45 * e.slow +
            .35 * min(e.material, mStar) +
            .20 * (1 - (e.cost / 2.4)))
        .clamp(0.0, 1.0)
        .toDouble();
    return (1.7 - e.cost) +
        .52 * e.slow +
        .24 * min(e.material, mStar) -
        .65 * max(0, e.material - mStar) +
        topic +
        _chunkBonus21(e.b, wanted) +
        .16 * flow +
        log(1 + e.uses) * .025;
  }

  double _scoreCandidate(
    _LangEdge20 e,
    Set<String> wanted,
    Map<String, int> used,
  ) =>
      _scoreEdge(e, wanted) -
      .30 * (used[e.b] ?? 0) +
      (punct(e.b) ? 0.02 : 0.0);

  String _surface(List<String> xs, PlasticLanguageBrain04? brain) {
    final b = StringBuffer();
    const noSpace = {'.', ',', '!', '?', ';', ':'};
    for (final x in xs) {
      if (b.isNotEmpty && !noSpace.contains(x)) b.write(' ');
      b.write(x);
    }
    var s = b.toString().trim();
    if (s.isEmpty) return s;
    s = s[0].toUpperCase() + s.substring(1);
    return s;
  }

  String? spontaneous(PlasticLanguageBrain04 brain, MgdWorld06 world) {
    if (brain.curiosity < .18 &&
        brain.predictionErrorEma < .18 &&
        world.thoughts.isEmpty) return null;
    String seed = '';
    if (world.thoughts.isNotEmpty) seed = world.thoughts.last.hypothesis;
    if (seed.trim().isEmpty && brain.episodes.isNotEmpty)
      seed = brain.episodes.last.userText;
    return generate(seed, brain: brain, maxWords: 32);
  }

  MgdLanguageStats20 stats() {
    final mean = edges.isEmpty
        ? 0.0
        : edges.values.fold<double>(0, (a, e) => a + e.material) / edges.length;
    final tokenOccurrences = tokenCount.values.fold<int>(0, (a, v) => a + v);
    final edgeUses = edges.values.fold<int>(0, (a, e) => a + e.uses);
    final chunkOccurrences = chunks.values.fold<int>(0, (a, c) => a + c.count);
    return MgdLanguageStats20(
      tokens: tokenCount.length,
      edges: edges.length,
      chunks: chunks.values.where((c) => c.count >= 4).length,
      tokenOccurrences: tokenOccurrences,
      edgeUses: edgeUses,
      chunkOccurrences: chunkOccurrences,
      sentences: sentences,
      characters: characters,
      meanMaterial: mean,
      lastFlux: lastFlux,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 2,
        'frames320': frames320,
        'subjectPlural320': subjectPlural320,
        'webSeen317': webSeen317,
        'tc': tokenCount,
        'e': edges.values.map((x) => x.toJson()).toList(),
        'ch': chunks.values.map((x) => x.toJson()).toList(),
        'sentences': sentences,
        'characters': characters,
        'flux': lastFlux,
      };
  factory MgdLanguage20.fromJson(Map<String, dynamic> j) {
    final m = MgdLanguage20();
    for (final e in (j['frames320'] as Map? ?? {}).entries) {
      m.frames320['${e.key}'] = Map<String, int>.from(e.value as Map);
    }
    m.subjectPlural320.addAll(
      Map<String, bool>.from(j['subjectPlural320'] as Map? ?? {}),
    );
    m.webSeen317.addAll(
      Map<String, dynamic>.from(j['webSeen317'] as Map? ?? {}),
    );
    m.tokenCount.addAll(
      Map<String, int>.from(
        (j['tc'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ),
      ),
    );
    for (final x in (j['e'] as List? ?? const [])) {
      final e = _LangEdge20.fromJson(Map<String, dynamic>.from(x));
      m.edges[m._ek(e.a, e.b)] = e;
    }
    for (final x in (j['ch'] as List? ?? const [])) {
      final c = _Chunk20.fromJson(Map<String, dynamic>.from(x));
      m.chunks[c.text] = c;
    }
    m.sentences = (j['sentences'] as num?)?.toInt() ?? 0;
    m.characters = (j['characters'] as num?)?.toInt() ?? 0;
    m.lastFlux = (j['flux'] as num?)?.toDouble() ?? 0;
    m._rebuildIndexes21();
    if (!j.containsKey('frames320')) {
      for (final row in m.webSeen317.values.whereType<Map>()) {
        m._learnFrame320('${row['text'] ?? ''}');
      }
    }
    return m;
  }
}

class MgdLanguagePersistence20 {
  Future<void> _saveTail = Future<void>.value();

  Future<File> _file() async => File(
        '${(await getApplicationDocumentsDirectory()).path}/mgd_language20.json',
      );

  Future<MgdLanguage20?> load() async {
    final map = await MgdStateStore26.instance.getMap('language_v20');
    if (map != null) return MgdLanguage20.fromJson(map);
    final f = await _file();
    try {
      if (!await f.exists()) return null;
      final m = MgdLanguage20.fromJson(jsonDecode(await f.readAsString()));
      unawaited(MgdStateStore26.instance.putMap('language_v20', m.toJson()));
      return m;
    } catch (_) {
      final bak = File('${f.path}.bak');
      try {
        if (await bak.exists())
          return MgdLanguage20.fromJson(jsonDecode(await bak.readAsString()));
      } catch (_) {}
      return null;
    }
  }

  Future<void> save(MgdLanguage20 m) async {
    await Future<void>.delayed(Duration.zero);
    final snapshot = m.toJson();
    final next = _saveTail
        .catchError((_) {})
        .then((_) => MgdStateStore26.instance.putMap('language_v20', snapshot));
    _saveTail = next;
    await next;
  }

  Future<void> _writePayload(String payload) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final tmp = File('${f.path}.tmp.$stamp');
    final bak = File('${f.path}.bak');
    await tmp.writeAsString(payload, flush: true);
    try {
      if (await bak.exists()) await bak.delete();
      if (await f.exists()) await f.rename(bak.path);
      await tmp.rename(f.path);
      if (await bak.exists()) await bak.delete();
    } catch (e) {
      if (!await f.exists() && await bak.exists()) {
        try {
          await bak.rename(f.path);
        } catch (_) {}
      }
      rethrow;
    } finally {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> clear() async {
    await MgdStateStore26.instance.deleteKey('language_v20');
    final f = await _file();
    for (final x in [f, File('${f.path}.bak')]) {
      if (await x.exists()) await x.delete();
    }
  }
}

class MgdLanguageLab20 extends StatefulWidget {
  final MgdLanguage20 language;
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final ResearchMemory11 research;
  final Future<void> Function() onSave;
  const MgdLanguageLab20({
    super.key,
    required this.language,
    required this.brain,
    required this.world,
    required this.research,
    required this.onSave,
  });
  @override
  State<MgdLanguageLab20> createState() => _MgdLanguageLab20State();
}

class _MgdLanguageLab20State extends State<MgdLanguageLab20> {
  final text = TextEditingController();
  bool busy = false;
  String status = '';

  String _decodeCorpusBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2)
        units.add(bytes[i] | (bytes[i + 1] << 8));
      return String.fromCharCodes(units);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2)
        units.add((bytes[i] << 8) | bytes[i + 1]);
      return String.fromCharCodes(units);
    }
    final decoded = utf8.decode(bytes, allowMalformed: true);
    final replacements = '�'.allMatches(decoded).length;
    if (replacements > max(8, decoded.length ~/ 200)) {
      return latin1.decode(bytes, allowInvalid: true);
    }
    return decoded;
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> train(String data, {String? sourceName}) async {
    final raw = data.trim();
    if (raw.isEmpty) {
      if (sourceName != null && mounted)
        setState(
          () => status =
              'Il corpus selezionato non contiene testo decodificabile.',
        );
      return;
    }
    if (busy) return;
    final before = widget.language.stats();
    if (mounted)
      setState(() {
        busy = true;
        status = sourceName == null
            ? 'Sto incorporando il testo…'
            : 'Sto importando $sourceName…';
      });
    try {
      const chunkSize = 120000;
      var start = 0;
      while (start < raw.length) {
        var end = min(start + chunkSize, raw.length);
        if (end < raw.length) {
          final searchStart = max(start, end - 8000);
          final tail = raw.substring(searchStart, end);
          final cuts = RegExp(r'[.!?]\s+|\n+').allMatches(tail).toList();
          if (cuts.isNotEmpty) end = searchStart + cuts.last.end;
        }
        if (end <= start) end = min(start + chunkSize, raw.length);
        widget.language.ingestText(raw.substring(start, end), reward: .42);
        start = end;
        if (mounted)
          setState(
            () => status = sourceName == null
                ? 'Sto leggendo… ${(100 * start / raw.length).round()}%'
                : 'Sto leggendo $sourceName… ${(100 * start / raw.length).round()}%',
          );
        await Future<void>.delayed(Duration.zero);
      }
      if (mounted)
        setState(
          () => status = sourceName == null
              ? 'Estraggo entità e relazioni dal testo…'
              : 'Estraggo conoscenza da $sourceName…',
        );
      final semantic = await CorpusSemanticBridge22.learn(
        text: raw,
        sourceName: sourceName ?? 'testo incollato',
        sourceFamily: sourceName == null ? 'manuale:incollato' : null,
        brain: widget.brain,
        world: widget.world,
        memory: widget.research,
      );
      await widget.onSave();
      final after = widget.language.stats();
      final dSent = after.sentences - before.sentences;
      final dTokSeen = after.tokenOccurrences - before.tokenOccurrences;
      final dEdgeUses = after.edgeUses - before.edgeUses;
      final dChunkUses = after.chunkOccurrences - before.chunkOccurrences;
      final dVocab = after.tokens - before.tokens;
      final dEdges = after.edges - before.edges;
      final dChunks = after.chunks - before.chunks;
      final dMatter = after.meanMaterial - before.meanMaterial;
      if (mounted)
        setState(
          () => status = '${sourceName == null ? 'Testo' : 'Corpus $sourceName'} appreso: '
              '+$dSent frasi, +$dTokSeen token letti, +$dEdgeUses transizioni rinforzate, '
              '+$dChunkUses sequenze elaborate. Nuove strutture: +$dVocab parole, '
              '+$dEdges archi, +$dChunks macro-nodi. Δ materia ${dMatter >= 0 ? '+' : ''}${dMatter.toStringAsFixed(3)}. '
              '${semantic.summary}.',
        );
    } catch (e) {
      if (mounted) setState(() => status = 'Errore durante l’importazione: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick() async {
    if (busy) return;
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );
      if (r == null || r.files.isEmpty) {
        if (mounted) setState(() => status = 'Importazione annullata.');
        return;
      }
      final f = r.files.single;
      final rawBytes = <int>[];

      // Android SAF often exposes a content:// document with no usable filesystem
      // path. FilePicker's readStream reads the document through the provider
      // instead of assuming that it is a normal File.
      final stream = f.readStream;
      if (stream != null) {
        await for (final chunk in stream) {
          rawBytes.addAll(chunk);
          if (mounted && f.size > 0) {
            final pct = (100 * rawBytes.length / f.size).clamp(0, 100).round();
            setState(() => status = 'Sto leggendo ${f.name}… $pct%');
          }
        }
      }

      // Fallbacks for providers/platforms that do expose bytes or a real path.
      if (rawBytes.isEmpty && f.bytes != null && f.bytes!.isNotEmpty) {
        rawBytes.addAll(f.bytes!);
      }
      if (rawBytes.isEmpty && f.path != null && f.path!.isNotEmpty) {
        try {
          final diskFile = File(f.path!);
          if (await diskFile.exists())
            rawBytes.addAll(await diskFile.readAsBytes());
        } catch (_) {}
      }

      if (rawBytes.isEmpty) {
        if (mounted)
          setState(
            () => status =
                'Android ha restituito 0 byte per ${f.name}. Riprova scegliendo il file da File/Download, non da una anteprima.',
          );
        return;
      }

      final data = _decodeCorpusBytes(rawBytes);
      if (data.trim().isEmpty) {
        if (mounted)
          setState(
            () => status =
                'Il file ${f.name} contiene ${rawBytes.length} byte, ma non è stato possibile decodificarli come testo.',
          );
        return;
      }
      await train(data, sourceName: f.name);
    } catch (e) {
      if (mounted)
        setState(() => status = 'Impossibile importare il corpus: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.language.stats();
    return Scaffold(
      appBar: AppBar(title: const Text('MGD Language — PURE')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            'Zero LLM, zero embedding preaddestrati, zero POS tagger. Il testo grezzo modifica memoria, materia, costi e macro-sequenze MGD.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LMetric20('Vocabolario', '${s.tokens}'),
              _LMetric20('Token visti', '${s.tokenOccurrences}'),
              _LMetric20('Archi unici', '${s.edges}'),
              _LMetric20('Passaggi', '${s.edgeUses}'),
              _LMetric20('Macro-nodi', '${s.chunks}'),
              _LMetric20('Frasi viste', '${s.sentences}'),
              _LMetric20('Materia media', s.meanMaterial.toStringAsFixed(3)),
              _LMetric20(
                'Conoscenze',
                '${widget.research.claims.values.where((c) => c.status == 'accettata' || c.status == 'validata_llm' || c.status == 'appresa_corpus').length}',
              ),
              _LMetric20(
                'Ipotesi',
                '${widget.research.claims.values.where((c) => c.status == 'dubbia').length}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: text,
            minLines: 6,
            maxLines: 14,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText:
                  'Incolla qui italiano grezzo: dialoghi, libri, articoli, trascrizioni…',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy || text.text.trim().isEmpty
                    ? null
                    : () => train(text.text),
                icon: const Icon(Icons.psychology),
                label: const Text('Impara testo incollato'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : pick,
                icon: const Icon(Icons.file_open),
                label: const Text('Importa e impara libro/corpus'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Importa e impara libro/corpus è un’azione completa: dopo aver scelto il file MGD lo legge, lo incorpora e lo salva automaticamente. Non serve premere il pulsante del testo incollato.',
            style: TextStyle(fontSize: 12),
          ),
          if (status.isNotEmpty) ...[const SizedBox(height: 10), Text(status)],
          const SizedBox(height: 18),
          const Text(
            'Come emerge la lingua',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'Le transizioni ricorrenti abbassano il costo; la memoria lenta le stabilizza; la materia facilita la coerenza ma oltre M* introduce resistenza alla ripetizione. Sequenze ricorrenti di 2–5 token condensano in macro-nodi. La generazione percorre solo archi linguisticamente attivi e viene orientata dai concetti semantici presenti nel cervello.',
          ),
        ],
      ),
    );
  }
}

class _LMetric20 extends StatelessWidget {
  final String a, b;
  const _LMetric20(this.a, this.b);
  @override
  Widget build(BuildContext c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(b, style: Theme.of(c).textTheme.titleLarge),
              Text(a),
            ],
          ),
        ),
      );
}
