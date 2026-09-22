import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';

class ResearchEvidence10 {
  final String id;
  final String query;
  final String subject;
  final String relation;
  final String object;
  final String provider;
  final String sourceFamily;
  final String sourceTitle;
  final String sourceUrl;
  final String sourceHost;
  final String excerpt;
  final double sourceTrust;
  final String retrievedAtIso;

  const ResearchEvidence10({
    required this.id,
    required this.query,
    required this.subject,
    required this.relation,
    required this.object,
    required this.provider,
    required this.sourceFamily,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.sourceHost,
    required this.excerpt,
    required this.sourceTrust,
    required this.retrievedAtIso,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'subject': subject,
        'relation': relation,
        'object': object,
        'provider': provider,
        'sourceFamily': sourceFamily,
        'sourceTitle': sourceTitle,
        'sourceUrl': sourceUrl,
        'sourceHost': sourceHost,
        'excerpt': excerpt,
        'sourceTrust': sourceTrust,
        'retrievedAtIso': retrievedAtIso,
      };

  factory ResearchEvidence10.fromJson(Map<String, dynamic> j) =>
      ResearchEvidence10(
        id: (j['id'] ?? '').toString(),
        query: (j['query'] ?? '').toString(),
        subject: (j['subject'] ?? '').toString(),
        relation: (j['relation'] ?? '').toString(),
        object: (j['object'] ?? '').toString(),
        provider: (j['provider'] ?? '').toString(),
        sourceFamily: (j['sourceFamily'] ?? '').toString(),
        sourceTitle: (j['sourceTitle'] ?? '').toString(),
        sourceUrl: (j['sourceUrl'] ?? '').toString(),
        sourceHost: (j['sourceHost'] ?? '').toString(),
        excerpt: (j['excerpt'] ?? '').toString(),
        sourceTrust: (j['sourceTrust'] as num?)?.toDouble() ?? 0.5,
        retrievedAtIso: (j['retrievedAtIso'] ?? '').toString(),
      );
}

class ResearchClaim10 {
  final String key;
  String subject;
  String relation;
  String object;
  double confidence;
  bool conflict;
  String firstSeenIso;
  String lastSeenIso;
  final Set<String> evidenceIds;
  final Set<String> sourceFamilies;

  ResearchClaim10({
    required this.key,
    required this.subject,
    required this.relation,
    required this.object,
    required this.confidence,
    required this.conflict,
    required this.firstSeenIso,
    required this.lastSeenIso,
    Set<String>? evidenceIds,
    Set<String>? sourceFamilies,
  })  : evidenceIds = evidenceIds ?? <String>{},
        sourceFamilies = sourceFamilies ?? <String>{};

  int get evidenceCount => evidenceIds.length;
  int get independentSourceCount => sourceFamilies.length;

  Map<String, dynamic> toJson() => {
        'key': key,
        'subject': subject,
        'relation': relation,
        'object': object,
        'confidence': confidence,
        'conflict': conflict,
        'firstSeenIso': firstSeenIso,
        'lastSeenIso': lastSeenIso,
        'evidenceIds': evidenceIds.toList(),
        'sourceFamilies': sourceFamilies.toList(),
      };

  factory ResearchClaim10.fromJson(Map<String, dynamic> j) => ResearchClaim10(
        key: (j['key'] ?? '').toString(),
        subject: (j['subject'] ?? '').toString(),
        relation: (j['relation'] ?? '').toString(),
        object: (j['object'] ?? '').toString(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.4,
        conflict: j['conflict'] == true,
        firstSeenIso: (j['firstSeenIso'] ?? '').toString(),
        lastSeenIso: (j['lastSeenIso'] ?? '').toString(),
        evidenceIds: ((j['evidenceIds'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
        sourceFamilies: ((j['sourceFamilies'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
      );
}

class ResearchSession10 {
  final String query;
  final String reason;
  final double value;
  final String startedAtIso;
  String completedAtIso;
  String status;
  int documents;
  int extractedClaims;
  int integratedClaims;

  ResearchSession10({
    required this.query,
    required this.reason,
    required this.value,
    required this.startedAtIso,
    this.completedAtIso = '',
    this.status = 'avviata',
    this.documents = 0,
    this.extractedClaims = 0,
    this.integratedClaims = 0,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'reason': reason,
        'value': value,
        'startedAtIso': startedAtIso,
        'completedAtIso': completedAtIso,
        'status': status,
        'documents': documents,
        'extractedClaims': extractedClaims,
        'integratedClaims': integratedClaims,
      };

  factory ResearchSession10.fromJson(Map<String, dynamic> j) =>
      ResearchSession10(
        query: (j['query'] ?? '').toString(),
        reason: (j['reason'] ?? '').toString(),
        value: (j['value'] as num?)?.toDouble() ?? 0,
        startedAtIso: (j['startedAtIso'] ?? '').toString(),
        completedAtIso: (j['completedAtIso'] ?? '').toString(),
        status: (j['status'] ?? 'completata').toString(),
        documents: (j['documents'] as num?)?.toInt() ?? 0,
        extractedClaims: (j['extractedClaims'] as num?)?.toInt() ?? 0,
        integratedClaims: (j['integratedClaims'] as num?)?.toInt() ?? 0,
      );
}

class ResearchMemory10 {
  bool enabled;
  int dailyBudget;
  int requestsToday;
  String dayKey;
  String? lastResearchAtIso;
  String? lastGoal;
  String lastStatus;
  String? lastError;
  final List<ResearchEvidence10> evidence;
  final Map<String, ResearchClaim10> claims;
  final List<ResearchSession10> sessions;
  final Map<String, String> queryLastIso;

  ResearchMemory10({
    this.enabled = true,
    this.dailyBudget = 24,
    this.requestsToday = 0,
    this.dayKey = '',
    this.lastResearchAtIso,
    this.lastGoal,
    this.lastStatus = 'Ricerca autonoma pronta.',
    this.lastError,
    List<ResearchEvidence10>? evidence,
    Map<String, ResearchClaim10>? claims,
    List<ResearchSession10>? sessions,
    Map<String, String>? queryLastIso,
  })  : evidence = evidence ?? <ResearchEvidence10>[],
        claims = claims ?? <String, ResearchClaim10>{},
        sessions = sessions ?? <ResearchSession10>[],
        queryLastIso = queryLastIso ?? <String, String>{};

  void _rollDay(DateTime now) {
    final key =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (dayKey != key) {
      dayKey = key;
      requestsToday = 0;
    }
  }

  bool canResearch(
    String query, {
    DateTime? now,
    Duration repeatAfter = const Duration(hours: 6),
  }) {
    final t = now ?? DateTime.now();
    _rollDay(t);
    if (!enabled || requestsToday >= dailyBudget) return false;
    final last = queryLastIso[_norm(query)];
    if (last == null || last.isEmpty) return true;
    final parsed = DateTime.tryParse(last);
    if (parsed == null) return true;
    return t.difference(parsed) >= repeatAfter;
  }

  void beginQuery(String query, DateTime now) {
    _rollDay(now);
    requestsToday++;
    lastResearchAtIso = now.toIso8601String();
    lastGoal = query;
    queryLastIso[_norm(query)] = now.toIso8601String();
  }

  void trim() {
    if (evidence.length > 600) {
      evidence.removeRange(0, evidence.length - 600);
    }
    if (sessions.length > 120) {
      sessions.removeRange(0, sessions.length - 120);
    }
    if (claims.length > 500) {
      final ranked = claims.values.toList()
        ..sort((a, b) => b.lastSeenIso.compareTo(a.lastSeenIso));
      final keep = ranked.take(500).map((e) => e.key).toSet();
      claims.removeWhere((k, _) => !keep.contains(k));
    }
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'enabled': enabled,
        'dailyBudget': dailyBudget,
        'requestsToday': requestsToday,
        'dayKey': dayKey,
        'lastResearchAtIso': lastResearchAtIso,
        'lastGoal': lastGoal,
        'lastStatus': lastStatus,
        'lastError': lastError,
        'evidence': evidence.map((e) => e.toJson()).toList(),
        'claims': claims.values.map((e) => e.toJson()).toList(),
        'sessions': sessions.map((e) => e.toJson()).toList(),
        'queryLastIso': queryLastIso,
      };

  factory ResearchMemory10.fromJson(Map<String, dynamic> j) {
    final out = ResearchMemory10(
      enabled: j['enabled'] != false,
      dailyBudget: (j['dailyBudget'] as num?)?.toInt() ?? 24,
      requestsToday: (j['requestsToday'] as num?)?.toInt() ?? 0,
      dayKey: (j['dayKey'] ?? '').toString(),
      lastResearchAtIso: j['lastResearchAtIso'] as String?,
      lastGoal: j['lastGoal'] as String?,
      lastStatus: (j['lastStatus'] ?? 'Ricerca autonoma pronta.').toString(),
      lastError: j['lastError'] as String?,
      queryLastIso: Map<String, String>.from(
        ((j['queryLastIso'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      ),
    );
    for (final raw in (j['evidence'] as List?) ?? const []) {
      if (raw is Map) {
        out.evidence.add(
          ResearchEvidence10.fromJson(Map<String, dynamic>.from(raw)),
        );
      }
    }
    for (final raw in (j['claims'] as List?) ?? const []) {
      if (raw is Map) {
        final c = ResearchClaim10.fromJson(Map<String, dynamic>.from(raw));
        if (c.key.isNotEmpty) out.claims[c.key] = c;
      }
    }
    for (final raw in (j['sessions'] as List?) ?? const []) {
      if (raw is Map) {
        out.sessions.add(
          ResearchSession10.fromJson(Map<String, dynamic>.from(raw)),
        );
      }
    }
    out._rollDay(DateTime.now());
    out.trim();
    return out;
  }
}

class ResearchGoal10 {
  final String query;
  final String focusLabel;
  final String reason;
  final String kind;
  final double value;
  final List<int> seedEntityIds;

  const ResearchGoal10({
    required this.query,
    required this.focusLabel,
    required this.reason,
    required this.kind,
    required this.value,
    required this.seedEntityIds,
  });
}

class WebDocument10 {
  final String provider;
  final String sourceFamily;
  final String title;
  final String url;
  final String text;
  final double trust;

  const WebDocument10({
    required this.provider,
    required this.sourceFamily,
    required this.title,
    required this.url,
    required this.text,
    required this.trust,
  });

  String get host {
    try {
      return Uri.parse(url).host.toLowerCase();
    } catch (_) {
      return '';
    }
  }
}

class ResearchDraft10 {
  final ResearchGoal10 goal;
  final List<WebDocument10> documents;
  final List<ExtractedClaim10> claims;
  final String? error;

  const ResearchDraft10({
    required this.goal,
    required this.documents,
    required this.claims,
    this.error,
  });
}

class ResearchOutcome10 {
  final String query;
  final int documents;
  final int extractedClaims;
  final int integratedClaims;
  final String summary;

  const ResearchOutcome10({
    required this.query,
    required this.documents,
    required this.extractedClaims,
    required this.integratedClaims,
    required this.summary,
  });
}

class ExtractedClaim10 {
  final String subject;
  final String relation;
  final String object;
  final String sentence;
  final WebDocument10 document;
  final double patternQuality;

  const ExtractedClaim10({
    required this.subject,
    required this.relation,
    required this.object,
    required this.sentence,
    required this.document,
    required this.patternQuality,
  });
}

class WebKnowledgeExplorer10 {
  static const _userAgent =
      'MGD-Neuro/0.10 autonomous-learning research prototype';

  ResearchGoal10? selectGoal(
    PlasticLanguageBrain04 brain,
    MgdWorld06 world,
    ResearchMemory10 memory,
  ) {
    final now = DateTime.now();
    final weak = memory.claims.values.where((c) {
      if (c.confidence >= 0.62 || c.independentSourceCount >= 2) return false;
      final last = DateTime.tryParse(c.lastSeenIso);
      if (last == null) return true;
      return now.difference(last) > const Duration(hours: 12);
    }).toList()
      ..sort((a, b) => a.confidence.compareTo(b.confidence));
    if (weak.isNotEmpty) {
      final c = weak.first;
      final q =
          '${c.subject} ${c.relation} ${c.object} verifica fonti affidabili';
      if (memory.canResearch(q, now: now)) {
        final sid = brain.entityIdForLabel06(c.subject);
        return ResearchGoal10(
          query: q,
          focusLabel: c.subject,
          reason: 'verifica di una conoscenza web ancora debole',
          kind: 'verification',
          value: (1.0 - c.confidence).clamp(0.55, 0.95).toDouble(),
          seedEntityIds: sid == null ? const <int>[] : <int>[sid],
        );
      }
    }

    final pending = world.pendingCuriosityQuestion09?.trim();
    if (pending != null && pending.isNotEmpty) {
      final q = pending.replaceAll(RegExp(r'[?]+$'), '').trim();
      if (memory.canResearch(
        q,
        now: now,
        repeatAfter: const Duration(hours: 3),
      )) {
        final labels = world.pendingCuriosityEntities09
            .where((id) => id >= 0 && id < brain.entities.length)
            .map((id) => brain.entities[id].label)
            .toList();
        return ResearchGoal10(
          query: '$q spiegazione definizione fonti',
          focusLabel: labels.isEmpty ? '' : labels.first,
          reason: 'domanda generata dalla curiosità interna di MGD',
          kind: 'curiosity',
          value: max(0.78, world.curiosity).toDouble(),
          seedEntityIds: List<int>.from(world.pendingCuriosityEntities09),
        );
      }
    }

    final facts = brain.cognitiveFacts06();
    final bySubject = <int, List<CognitiveFact06>>{};
    for (final f in facts) {
      bySubject.putIfAbsent(f.subjectId, () => <CognitiveFact06>[]).add(f);
    }

    final graphDegree = <int, int>{};
    for (final e in world.edges.values) {
      for (final node in <String>[e.a, e.b]) {
        if (!node.startsWith('e:')) continue;
        final id = int.tryParse(node.substring(2));
        if (id != null) graphDegree[id] = (graphDegree[id] ?? 0) + 1;
      }
    }

    ResearchGoal10? best;
    for (final entity in brain.entities) {
      final label = entity.label.trim();
      final nl = _norm(label);
      if (label.length < 2 ||
          {'utente', 'self', 'io', 'tu'}.contains(nl) ||
          RegExp(r'^d+(?:[.,]d+)?$').hasMatch(label)) {
        continue;
      }

      final entityFacts =
          bySubject[entity.id] ?? const <CognitiveFact06>[];
      final factCount = entityFacts.length;
      final avgConfidence = entityFacts.isEmpty
          ? 0.0
          : entityFacts
                  .map((f) => f.confidence)
                  .reduce((a, b) => a + b) /
              entityFacts.length;
      final uncertainty = factCount == 0
          ? 1.0
          : (0.80 / (1.0 + 0.45 * factCount) +
                  0.20 * (1.0 - avgConfidence))
              .clamp(0.08, 1.0)
              .toDouble();
      final relevance = (0.30 +
              0.08 * min(entity.mentions, 6) +
              (brain.step - entity.lastSeen <= 60 ? 0.22 : 0.0))
          .clamp(0.25, 1.0)
          .toDouble();
      final c =
          max(0.35, max(world.curiosity, world.noveltyEma)).toDouble();
      final degree = graphDegree[entity.id] ?? 0;
      final bridge = (0.38 + 0.14 * min(degree, 4))
          .clamp(0.38, 0.94)
          .toDouble();
      final value = (uncertainty * relevance * c * bridge)
          .clamp(0.0, 1.0)
          .toDouble();

      if (value < 0.10) continue;
      final q =
          '$label definizione caratteristiche classificazione funzione';
      if (!memory.canResearch(q, now: now)) continue;
      final goal = ResearchGoal10(
        query: q,
        focusLabel: label,
        reason:
            'alta utilità di apprendimento: incertezza ${uncertainty.toStringAsFixed(2)}, rilevanza ${relevance.toStringAsFixed(2)}, ponte ${bridge.toStringAsFixed(2)}',
        kind: 'entity-deepening',
        value: value,
        seedEntityIds: <int>[entity.id],
      );
      if (best == null || goal.value > best.value) best = goal;
    }
    return best;
  }

  Future<ResearchDraft10> research(ResearchGoal10 goal) async {
    try {
      final results = await Future.wait<List<WebDocument10>>([
        _searchWikipedia(goal.query),
        _searchWikidata(goal.query),
        _searchDuckDuckGo(goal.query),
      ]);
      final docs = <WebDocument10>[];
      final seen = <String>{};
      for (final group in results) {
        for (final d in group) {
          final key = d.url.trim().isNotEmpty
              ? _norm(d.url)
              : '${d.provider}:${_norm(d.title)}:${_norm(d.text).hashCode}';
          if (seen.add(key) && d.text.trim().length >= 20) docs.add(d);
          if (docs.length >= 8) break;
        }
        if (docs.length >= 8) break;
      }

      final claims = <ExtractedClaim10>[];
      for (final d in docs) {
        claims.addAll(_extractClaims(goal, d));
      }
      return ResearchDraft10(
        goal: goal,
        documents: docs,
        claims: claims,
      );
    } catch (e) {
      return ResearchDraft10(
        goal: goal,
        documents: const <WebDocument10>[],
        claims: const <ExtractedClaim10>[],
        error: e.toString(),
      );
    }
  }

  ResearchOutcome10 integrate(
    PlasticLanguageBrain04 brain,
    MgdWorld06 world,
    ResearchMemory10 memory,
    ResearchDraft10 draft,
  ) {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final session = ResearchSession10(
      query: draft.goal.query,
      reason: draft.goal.reason,
      value: draft.goal.value,
      startedAtIso: memory.lastResearchAtIso ?? nowIso,
    );
    session.documents = draft.documents.length;
    session.extractedClaims = draft.claims.length;

    if (draft.error != null) {
      session.status = 'errore';
      session.completedAtIso = nowIso;
      memory.lastError = draft.error;
      memory.lastStatus = 'Ricerca fallita: ${draft.error}';
      memory.sessions.add(session);
      memory.trim();
      return ResearchOutcome10(
        query: draft.goal.query,
        documents: 0,
        extractedClaims: 0,
        integratedClaims: 0,
        summary: memory.lastStatus,
      );
    }

    final grouped = <String, List<ExtractedClaim10>>{};
    for (final c in draft.claims) {
      final key = _claimKey(c.subject, c.relation, c.object);
      grouped.putIfAbsent(key, () => <ExtractedClaim10>[]).add(c);
    }

    var integrated = 0;
    for (final entry in grouped.entries) {
      final claims = entry.value;
      final first = claims.first;
      final sourceFamilies =
          claims.map((e) => e.document.sourceFamily).toSet();
      final avgTrust = claims
              .map((e) => e.document.trust * e.patternQuality)
              .reduce((a, b) => a + b) /
          claims.length;
      final corroborationBonus =
          0.08 * max(0, sourceFamilies.length - 1);
      var confidence = (0.36 + 0.16 * avgTrust + corroborationBonus)
          .clamp(0.38, 0.72)
          .toDouble();

      final existingConflict = _hasFunctionalConflict(
        brain,
        first.subject,
        first.relation,
        first.object,
      );
      if (existingConflict) confidence = min(confidence, 0.44);

      final existing = memory.claims[entry.key];
      final claim = existing ??
          ResearchClaim10(
            key: entry.key,
            subject: first.subject,
            relation: first.relation,
            object: first.object,
            confidence: confidence,
            conflict: existingConflict,
            firstSeenIso: nowIso,
            lastSeenIso: nowIso,
          );
      claim.subject = first.subject;
      claim.relation = first.relation;
      claim.object = first.object;
      claim.lastSeenIso = nowIso;
      claim.conflict = claim.conflict || existingConflict;

      for (var i = 0; i < claims.length; i++) {
        final c = claims[i];
        final evId =
            '${now.microsecondsSinceEpoch}:${entry.key.hashCode}:$i';
        final excerpt = c.sentence.length > 360
            ? '${c.sentence.substring(0, 360)}…'
            : c.sentence;
        final evidence = ResearchEvidence10(
          id: evId,
          query: draft.goal.query,
          subject: c.subject,
          relation: c.relation,
          object: c.object,
          provider: c.document.provider,
          sourceFamily: c.document.sourceFamily,
          sourceTitle: c.document.title,
          sourceUrl: c.document.url,
          sourceHost: c.document.host,
          excerpt: excerpt,
          sourceTrust: c.document.trust,
          retrievedAtIso: nowIso,
        );
        memory.evidence.add(evidence);
        claim.evidenceIds.add(evId);
        claim.sourceFamilies.add(c.document.sourceFamily);
      }

      claim.confidence = (0.36 +
              0.10 * min(claim.evidenceCount, 3) +
              0.08 * max(0, claim.independentSourceCount - 1))
          .clamp(0.40, claim.conflict ? 0.48 : 0.70)
          .toDouble();
      memory.claims[entry.key] = claim;

      if (claim.confidence < 0.40) continue;
      brain.importTeacherFact08(
        subject: claim.subject,
        relation: claim.relation,
        object: claim.object,
        confidence: claim.confidence,
        source: 'web:${claim.sourceFamilies.join('+')}',
      );

      final sId = brain.entityIdForLabel06(claim.subject) ??
          brain.ensureSemanticEntity06(claim.subject);
      final oId = brain.entityIdForLabel06(claim.object) ??
          (PlasticLanguageBrain04.lexicalTokens(claim.object).length <= 6
              ? brain.ensureSemanticEntity06(claim.object)
              : null);
      if (oId != null && sId != oId) {
        world.importTeacherSemanticLink08(
          sId,
          oId,
          0.42 + 0.32 * claim.confidence,
          confidence: 0.44 + 0.30 * claim.confidence,
        );
      }
      world.integrateLanguageExperience09(
        brain,
        _claimSentence(
          claim.subject,
          claim.relation,
          claim.object,
        ),
        reward: 0.12 + 0.18 * claim.confidence,
      );
      integrated++;
    }

    brain.discoverConcepts();
    world.think(
      brain,
      cycles: 18,
      seedText: draft.goal.focusLabel,
    );
    session.integratedClaims = integrated;
    session.completedAtIso = nowIso;
    session.status =
        integrated > 0 ? 'integrata' : 'nessun fatto affidabile';
    memory.sessions.add(session);
    memory.lastError = null;
    memory.lastStatus = integrated > 0
        ? 'Ricerca autonoma: ${draft.goal.focusLabel.isEmpty ? draft.goal.query : draft.goal.focusLabel} • ${draft.documents.length} fonti • $integrated conoscenze integrate come prior deboli.'
        : 'Ricerca completata su ${draft.goal.query}, ma non ho trovato fatti abbastanza strutturati da integrare.';
    memory.trim();

    return ResearchOutcome10(
      query: draft.goal.query,
      documents: draft.documents.length,
      extractedClaims: draft.claims.length,
      integratedClaims: integrated,
      summary: memory.lastStatus,
    );
  }

  List<ExtractedClaim10> _extractClaims(
    ResearchGoal10 goal,
    WebDocument10 doc,
  ) {
    final subject = goal.focusLabel.trim().isNotEmpty
        ? goal.focusLabel.trim()
        : _cleanTitle(doc.title);
    if (subject.isEmpty) return const <ExtractedClaim10>[];

    final sentences = _sentences(doc.text);
    final out = <ExtractedClaim10>[];
    for (final sentence in sentences.take(12)) {
      final c = extractClaimFromSentence(subject, sentence, doc);
      if (c != null) out.add(c);
      if (out.length >= 4) break;
    }
    return out;
  }

  ExtractedClaim10? extractClaimFromSentence(
    String subject,
    String sentence,
    WebDocument10 doc,
  ) {
    final clean = sentence
        .replaceAll(RegExp(r'[[^]]*]'), ' ')
        .replaceAll(RegExp(r's+'), ' ')
        .trim();
    if (clean.length < 10 || clean.length > 520) return null;

    final escaped = RegExp.escape(subject.trim());
    final start =
        r'^(?:(?:il|lo|la|l'|un|uno|una)s+)?' +
            escaped +
            r's+';
    final patterns =
        <({RegExp re, String relation, double quality})>[
      (
        re: RegExp(
          start + r'(?:è|e)s+(?:un|uno|una)s+(.+)',
          caseSensitive: false,
        ),
        relation: 'tipo di',
        quality: 0.96,
      ),
      (
        re: RegExp(
          start + r'(?:è|e)s+compost[oa]s+das+(.+)',
          caseSensitive: false,
        ),
        relation: 'composto da',
        quality: 0.92,
      ),
      (
        re: RegExp(
          start + r'(?:è|e)s+costituit[oa]s+das+(.+)',
          caseSensitive: false,
        ),
        relation: 'composto da',
        quality: 0.92,
      ),
      (
        re: RegExp(
          start +
              r'fas+partes+(?:di|del|della|dei|degli|delle)s+(.+)',
          caseSensitive: false,
        ),
        relation: 'parte di',
        quality: 0.92,
      ),
      (
        re: RegExp(
          start +
              r'appartienes+(?:a|al|alla|ai|agli|alle)s+(.+)',
          caseSensitive: false,
        ),
        relation: 'appartiene a',
        quality: 0.90,
      ),
      (
        re: RegExp(
          start + r'(?:ha|possiede)s+(.+)',
          caseSensitive: false,
        ),
        relation: 'ha',
        quality: 0.86,
      ),
      (
        re: RegExp(
          start + r'vives+(?:in|nel|nella|nei|nelle)s+(.+)',
          caseSensitive: false,
        ),
        relation: 'vive in',
        quality: 0.88,
      ),
      (
        re: RegExp(
          start +
              r'sis+trovas+(?:in|nel|nella|nei|nelle)s+(.+)',
          caseSensitive: false,
        ),
        relation: 'si trova in',
        quality: 0.88,
      ),
      (
        re: RegExp(
          start + r'serves+(?:a|per)s+(.+)',
          caseSensitive: false,
        ),
        relation: 'serve per',
        quality: 0.86,
      ),
      (
        re: RegExp(
          start + r'puòs+(.+)',
          caseSensitive: false,
        ),
        relation: 'può',
        quality: 0.78,
      ),
      (
        re: RegExp(
          start + r'comprendes+(.+)',
          caseSensitive: false,
        ),
        relation: 'comprende',
        quality: 0.80,
      ),
    ];

    for (final p in patterns) {
      final m = p.re.firstMatch(clean);
      if (m == null) continue;
      final object = _cleanObject(m.group(1) ?? '');
      if (!_validObject(subject, object)) continue;
      return ExtractedClaim10(
        subject: subject,
        relation: p.relation,
        object: object,
        sentence: clean,
        document: doc,
        patternQuality: p.quality,
      );
    }
    return null;
  }

  Future<List<WebDocument10>> _searchWikipedia(String query) async {
    final uri = Uri.https('it.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': query,
      'gsrlimit': '3',
      'prop': 'extracts|info',
      'exintro': '1',
      'explaintext': '1',
      'inprop': 'url',
      'format': 'json',
      'formatversion': '2',
      'origin': '*',
    });
    final raw = await _getJson(uri);
    final pages =
        ((raw['query'] as Map?)?['pages'] as List?) ?? const [];
    final out = <WebDocument10>[];
    for (final x in pages) {
      if (x is! Map) continue;
      final j = Map<String, dynamic>.from(x);
      final text = (j['extract'] ?? '').toString().trim();
      if (text.length < 20) continue;
      final title = (j['title'] ?? '').toString();
      final url = (j['fullurl'] ??
              'https://it.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}')
          .toString();
      out.add(WebDocument10(
        provider: 'Wikipedia IT',
        sourceFamily: 'wikimedia',
        title: title,
        url: url,
        text: text,
        trust: 0.82,
      ));
    }
    return out;
  }

  Future<List<WebDocument10>> _searchWikidata(String query) async {
    final uri = Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbsearchentities',
      'search': query,
      'language': 'it',
      'uselang': 'it',
      'limit': '4',
      'format': 'json',
      'origin': '*',
    });
    final raw = await _getJson(uri);
    final rows = (raw['search'] as List?) ?? const [];
    final out = <WebDocument10>[];
    for (final x in rows) {
      if (x is! Map) continue;
      final j = Map<String, dynamic>.from(x);
      final label = (j['label'] ?? '').toString().trim();
      final desc = (j['description'] ?? '').toString().trim();
      if (label.isEmpty || desc.isEmpty) continue;
      final id = (j['id'] ?? '').toString();
      out.add(WebDocument10(
        provider: 'Wikidata',
        sourceFamily: 'wikimedia',
        title: label,
        url: (j['concepturi'] ??
                'https://www.wikidata.org/wiki/$id')
            .toString(),
        text: '$label è un $desc.',
        trust: 0.80,
      ));
    }
    return out;
  }

  Future<List<WebDocument10>> _searchDuckDuckGo(String query) async {
    final uri = Uri.https('api.duckduckgo.com', '/', {
      'q': query,
      'format': 'json',
      'no_html': '1',
      'no_redirect': '1',
      'skip_disambig': '0',
      'kl': 'it-it',
    });
    final raw = await _getJson(uri);
    final text = (raw['AbstractText'] ?? '').toString().trim();
    if (text.length < 20) return const <WebDocument10>[];
    final title = (raw['Heading'] ?? '').toString().trim();
    final url = (raw['AbstractURL'] ?? '').toString().trim();
    final source =
        (raw['AbstractSource'] ?? 'DuckDuckGo').toString().trim();
    String family = 'duckduckgo';
    try {
      final host = Uri.parse(url).host.toLowerCase();
      if (host.contains('wikipedia.org')) {
        family = 'wikimedia';
      } else if (host.isNotEmpty) {
        family = host;
      }
    } catch (_) {}
    return <WebDocument10>[
      WebDocument10(
        provider: 'DuckDuckGo/$source',
        sourceFamily: family,
        title: title.isEmpty ? query : title,
        url: url.isEmpty
            ? 'https://duckduckgo.com/?q=${Uri.encodeQueryComponent(query)}'
            : url,
        text: text,
        trust: family == 'wikimedia' ? 0.78 : 0.66,
      ),
    ];
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 7);
    try {
      final req =
          await client.getUrl(uri).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response =
          await req.close().timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'HTTP ${response.statusCode} da ${uri.host}',
        );
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      if (body.length > 1500000) {
        throw const FormatException('Risposta web troppo grande.');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const FormatException(
          'Risposta web non JSON-oggetto.',
        );
      }
      return Map<String, dynamic>.from(decoded);
    } finally {
      client.close(force: true);
    }
  }

  bool _hasFunctionalConflict(
    PlasticLanguageBrain04 brain,
    String subject,
    String relation,
    String object,
  ) {
    const functional = {
      'capitale di',
      'formula',
      'simbolo',
      'nasce il',
      'muore il',
    };
    if (!functional.contains(_norm(relation))) return false;
    final sid = brain.entityIdForLabel06(subject);
    if (sid == null) return false;
    for (final f in brain.cognitiveFacts06()) {
      if (f.subjectId != sid ||
          _norm(f.relation) != _norm(relation)) {
        continue;
      }
      if (_norm(f.object) != _norm(object) && f.confidence >= 0.55) {
        return true;
      }
    }
    return false;
  }

  static List<String> _sentences(String text) => text
      .replaceAll('
', ' ')
      .replaceAll(RegExp(r's+'), ' ')
      .split(RegExp(r'(?<=[.!?])s+'))
      .map((e) => e.trim())
      .where((e) => e.length >= 8)
      .toList();

  static String _cleanObject(String raw) {
    var x = raw
        .replaceAll(RegExp(r'([^)]*)'), ' ')
        .replaceAll(RegExp(r's+'), ' ')
        .trim();
    final breakers = <RegExp>[
      RegExp(
        r's+(?:che|dove|quando|mentre|poiché|perché|sebbene)s+',
        caseSensitive: false,
      ),
      RegExp(r's*;s*'),
    ];
    for (final b in breakers) {
      final m = b.firstMatch(x);
      if (m != null) x = x.substring(0, m.start).trim();
    }
    x = x.replaceAll(RegExp(r'[,:;.]+$'), '').trim();
    final words = x.split(RegExp(r's+'));
    if (words.length > 10) x = words.take(10).join(' ');
    return x;
  }

  static bool _validObject(String subject, String object) {
    if (object.length < 2 || object.length > 120) return false;
    if (_norm(object) == _norm(subject)) return false;
    if (RegExp(
      r'^(questo|questa|esso|essa|lui|lei)$',
      caseSensitive: false,
    ).hasMatch(object)) {
      return false;
    }
    return true;
  }

  static String _cleanTitle(String title) =>
      title.replaceAll(RegExp(r's*([^)]*)s*'), ' ').trim();

  static String _claimKey(String s, String r, String o) =>
      '${_norm(s)}|${_norm(r)}|${_norm(o)}';

  static String _claimSentence(String s, String r, String o) {
    switch (_norm(r)) {
      case 'tipo di':
        return '$s è un $o.';
      case 'parte di':
        return '$s fa parte di $o.';
      case 'appartiene a':
        return '$s appartiene a $o.';
      case 'ha':
        return '$s ha $o.';
      case 'vive in':
        return '$s vive in $o.';
      case 'si trova in':
        return '$s si trova in $o.';
      case 'serve per':
        return '$s serve per $o.';
      case 'composto da':
        return '$s è composto da $o.';
      case 'può':
        return '$s può $o.';
      default:
        return '$s $r $o.';
    }
  }
}

String _norm(String x) => x
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9àèéìòù]+'), ' ')
    .replaceAll(RegExp(r's+'), ' ')
    .trim();
