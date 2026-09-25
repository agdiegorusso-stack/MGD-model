import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'package:crypto/crypto.dart';
part 'research_semantics_v0317.dart';

String _n11(String x) => x
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9àèéìòù]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class ResearchEvidence11 {
  final String id;
  final String subject;
  final String relation;
  final String object;
  final String provider;
  final String sourceFamily;
  final String sourceTitle;
  final String sourceUrl;
  final String excerpt;
  final double trust;
  final String retrievedAtIso;
  final Map<String, dynamic> meta317;

  ResearchEvidence11({
    required this.id,
    required this.subject,
    required this.relation,
    required this.object,
    required this.provider,
    required this.sourceFamily,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.excerpt,
    required this.trust,
    required this.retrievedAtIso,
    Map<String, dynamic>? meta317,
  }) : meta317 = meta317 ?? <String, dynamic>{};

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'relation': relation,
        'object': object,
        'provider': provider,
        'sourceFamily': sourceFamily,
        'sourceTitle': sourceTitle,
        'sourceUrl': sourceUrl,
        'excerpt': excerpt,
        'trust': trust,
        'retrievedAtIso': retrievedAtIso,
        'meta317': meta317,
      };

  factory ResearchEvidence11.fromJson(Map<String, dynamic> j) =>
      ResearchEvidence11(
        id: (j['id'] ?? '').toString(),
        subject: (j['subject'] ?? '').toString(),
        relation: (j['relation'] ?? '').toString(),
        object: (j['object'] ?? '').toString(),
        provider: (j['provider'] ?? '').toString(),
        sourceFamily: (j['sourceFamily'] ?? '').toString(),
        sourceTitle: (j['sourceTitle'] ?? '').toString(),
        sourceUrl: (j['sourceUrl'] ?? '').toString(),
        excerpt: (j['excerpt'] ?? '').toString(),
        trust: (j['trust'] as num?)?.toDouble() ?? 0.5,
        retrievedAtIso: (j['retrievedAtIso'] ?? '').toString(),
        meta317: Map<String, dynamic>.from(j['meta317'] as Map? ?? {}),
      );
}

class ResearchClaim11 {
  final Map<String, dynamic> meta317;
  final String key;
  String subject;
  String relation;
  String object;
  double confidence;
  bool conflict;
  String status;
  String lastSeenIso;
  final Set<String> evidenceIds;
  final Set<String> sourceFamilies;
  final Set<String> sourceProviders;
  String? subjectSenseKey;
  String? subjectSenseLabel;
  String? subjectSenseGloss;

  ResearchClaim11({
    required this.key,
    required this.subject,
    required this.relation,
    required this.object,
    required this.confidence,
    required this.conflict,
    required this.status,
    required this.lastSeenIso,
    this.subjectSenseKey,
    this.subjectSenseLabel,
    this.subjectSenseGloss,
    Map<String, dynamic>? meta317,
    Set<String>? evidenceIds,
    Set<String>? sourceFamilies,
    Set<String>? sourceProviders,
  })  : meta317 = meta317 ?? <String, dynamic>{},
        evidenceIds = evidenceIds ?? <String>{},
        sourceFamilies = sourceFamilies ?? <String>{},
        sourceProviders = sourceProviders ?? <String>{};

  int get evidenceCount => evidenceIds.length;
  int get providerCount => sourceProviders.length;
  int get independentSources => sourceFamilies.length;
  int get independentSourceCount => independentSources;
  double get independenceScore030 =>
      sourceFamilies.length +
      0.25 * max(0, sourceProviders.length - sourceFamilies.length);

  Map<String, dynamic> toJson() => {
        'key': key,
        'meta317': meta317,
        'subject': subject,
        'relation': relation,
        'object': object,
        'confidence': confidence,
        'conflict': conflict,
        'status': status,
        'lastSeenIso': lastSeenIso,
        'subjectSenseKey': subjectSenseKey,
        'subjectSenseLabel': subjectSenseLabel,
        'subjectSenseGloss': subjectSenseGloss,
        'evidenceIds': evidenceIds.toList(),
        'sourceFamilies': sourceFamilies.toList(),
        'sourceProviders': sourceProviders.toList(),
      };

  factory ResearchClaim11.fromJson(Map<String, dynamic> j) => ResearchClaim11(
        key: (j['key'] ?? '').toString(),
        meta317: Map<String, dynamic>.from(j['meta317'] as Map? ?? {}),
        subject: (j['subject'] ?? '').toString(),
        relation: (j['relation'] ?? '').toString(),
        object: (j['object'] ?? '').toString(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.4,
        conflict: j['conflict'] == true,
        status: (j['status'] ?? 'dubbia').toString(),
        lastSeenIso: (j['lastSeenIso'] ?? '').toString(),
        subjectSenseKey: j['subjectSenseKey']?.toString(),
        subjectSenseLabel: j['subjectSenseLabel']?.toString(),
        subjectSenseGloss: j['subjectSenseGloss']?.toString(),
        evidenceIds: ((j['evidenceIds'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
        sourceFamilies: ((j['sourceFamilies'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
        sourceProviders: ((j['sourceProviders'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
      );
}

class ResearchPassage11 {
  final String id;
  final String topic;
  final String provider;
  final String sourceFamily;
  final String sourceTitle;
  final String sourceUrl;
  final String text;
  final double trust;
  final Map<String, dynamic> meta318;
  int attempts;
  bool structured;
  String lastAttemptIso;

  ResearchPassage11({
    required this.id,
    required this.topic,
    required this.provider,
    required this.sourceFamily,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.text,
    this.trust = 0.65,
    Map<String, dynamic> meta318 = const {},
    this.attempts = 0,
    this.structured = false,
    this.lastAttemptIso = '',
  }) : meta318 = Map<String, dynamic>.from(meta318);

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'provider': provider,
        'sourceFamily': sourceFamily,
        'sourceTitle': sourceTitle,
        'sourceUrl': sourceUrl,
        'text': text,
        'trust': trust,
        'meta318': meta318,
        'attempts': attempts,
        'structured': structured,
        'lastAttemptIso': lastAttemptIso,
      };

  factory ResearchPassage11.fromJson(Map<String, dynamic> j) =>
      ResearchPassage11(
        id: (j['id'] ?? '').toString(),
        topic: (j['topic'] ?? '').toString(),
        provider: (j['provider'] ?? '').toString(),
        sourceFamily: (j['sourceFamily'] ?? '').toString(),
        sourceTitle: (j['sourceTitle'] ?? '').toString(),
        sourceUrl: (j['sourceUrl'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        trust: (j['trust'] as num?)?.toDouble() ?? 0.65,
        meta318: Map<String, dynamic>.from(j['meta318'] as Map? ?? {}),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        structured: j['structured'] == true,
        lastAttemptIso: (j['lastAttemptIso'] ?? '').toString(),
      );
}

class ResearchSession11 {
  final String topic;
  final String query;
  final String reason;
  final String startedAtIso;
  String completedAtIso;
  String status;
  int documents;
  int providers;
  int families;
  int sentencesRead;
  int candidates;
  int integrated;
  int doubtful;
  int quarantined;
  int contradictions;
  final List<String> sources;
  final List<String> learnedFacts;
  final Map<String, dynamic> audit315 = <String, dynamic>{};

  ResearchSession11({
    required this.topic,
    required this.query,
    required this.reason,
    required this.startedAtIso,
    this.completedAtIso = '',
    this.status = 'avviata',
    this.documents = 0,
    this.providers = 0,
    this.families = 0,
    this.sentencesRead = 0,
    this.candidates = 0,
    this.integrated = 0,
    this.doubtful = 0,
    this.quarantined = 0,
    this.contradictions = 0,
    List<String>? sources,
    List<String>? learnedFacts,
  })  : sources = sources ?? <String>[],
        learnedFacts = learnedFacts ?? <String>[];

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'query': query,
        'reason': reason,
        'startedAtIso': startedAtIso,
        'completedAtIso': completedAtIso,
        'status': status,
        'documents': documents,
        'providers': providers,
        'families': families,
        'sentencesRead': sentencesRead,
        'candidates': candidates,
        'integrated': integrated,
        'doubtful': doubtful,
        'quarantined': quarantined,
        'contradictions': contradictions,
        'sources': sources,
        'learnedFacts': learnedFacts,
        'audit315': audit315,
      };

  factory ResearchSession11.fromJson(Map<String, dynamic> j) =>
      ResearchSession11(
        topic: (j['topic'] ?? '').toString(),
        query: (j['query'] ?? '').toString(),
        reason: (j['reason'] ?? '').toString(),
        startedAtIso: (j['startedAtIso'] ?? '').toString(),
        completedAtIso: (j['completedAtIso'] ?? '').toString(),
        status: (j['status'] ?? 'completata').toString(),
        documents: (j['documents'] as num?)?.toInt() ?? 0,
        providers: (j['providers'] as num?)?.toInt() ?? 0,
        families: (j['families'] as num?)?.toInt() ?? 0,
        sentencesRead: (j['sentencesRead'] as num?)?.toInt() ?? 0,
        candidates: (j['candidates'] as num?)?.toInt() ?? 0,
        integrated: (j['integrated'] as num?)?.toInt() ?? 0,
        doubtful: (j['doubtful'] as num?)?.toInt() ?? 0,
        quarantined: (j['quarantined'] as num?)?.toInt() ?? 0,
        contradictions: (j['contradictions'] as num?)?.toInt() ?? 0,
        sources: ((j['sources'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        learnedFacts: ((j['learnedFacts'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      )..audit315.addAll(
          Map<String, dynamic>.from((j['audit315'] as Map?) ?? const {}));
}

class NarrativeEpisode24 {
  final int id;
  final String source;
  final String text;
  final List<String> terms;
  final double salience;
  final String createdAtIso;

  NarrativeEpisode24(
      {required this.id,
      required this.source,
      required this.text,
      required this.terms,
      required this.salience,
      required this.createdAtIso});
  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'text': text,
        'terms': terms,
        'salience': salience,
        'createdAtIso': createdAtIso
      };
  factory NarrativeEpisode24.fromJson(Map<String, dynamic> j) =>
      NarrativeEpisode24(
        id: (j['id'] as num?)?.toInt() ?? 0,
        source: (j['source'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        terms: ((j['terms'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        salience: (j['salience'] as num?)?.toDouble() ?? .5,
        createdAtIso: (j['createdAtIso'] ?? '').toString(),
      );
}

class EmergentConcept24 {
  final String id;
  String label;
  final List<String> members;
  final List<String> anchors;
  int support;
  double coherence;
  double quality;
  bool crystallized;
  final Set<String> sources;

  EmergentConcept24(
      {required this.id,
      required this.label,
      required this.members,
      required this.anchors,
      required this.support,
      required this.coherence,
      this.quality = 0,
      this.crystallized = false,
      Set<String>? sources})
      : sources = sources ?? <String>{};
  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'members': members,
        'anchors': anchors,
        'support': support,
        'coherence': coherence,
        'quality': quality,
        'crystallized': crystallized,
        'sources': sources.toList()
      };
  factory EmergentConcept24.fromJson(Map<String, dynamic> j) =>
      EmergentConcept24(
        id: (j['id'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        members: ((j['members'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        anchors: ((j['anchors'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        support: (j['support'] as num?)?.toInt() ?? 0,
        coherence: (j['coherence'] as num?)?.toDouble() ?? 0,
        quality: (j['quality'] as num?)?.toDouble() ?? 0,
        crystallized: j['crystallized'] == true,
        sources: ((j['sources'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
      );
}

class NarrativeLink24 {
  final String episodeId;
  final String from;
  final String relation;
  final String to;
  final double confidence;
  final String source;
  NarrativeLink24(
      {required this.episodeId,
      required this.from,
      required this.relation,
      required this.to,
      required this.confidence,
      required this.source});
  Map<String, dynamic> toJson() => {
        'episodeId': episodeId,
        'from': from,
        'relation': relation,
        'to': to,
        'confidence': confidence,
        'source': source
      };
  factory NarrativeLink24.fromJson(Map<String, dynamic> j) => NarrativeLink24(
        episodeId: (j['episodeId'] ?? '').toString(),
        from: (j['from'] ?? '').toString(),
        relation: (j['relation'] ?? '').toString(),
        to: (j['to'] ?? '').toString(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? .4,
        source: (j['source'] ?? '').toString(),
      );
}

class TermMemory24 {
  final String term;
  int count;
  final Map<String, int> co;
  final Set<String> sources;
  TermMemory24(this.term,
      {this.count = 0, Map<String, int>? co, Set<String>? sources})
      : co = co ?? <String, int>{},
        sources = sources ?? <String>{};
  Map<String, dynamic> toJson() =>
      {'term': term, 'count': count, 'co': co, 'sources': sources.toList()};
  factory TermMemory24.fromJson(Map<String, dynamic> j) =>
      TermMemory24((j['term'] ?? '').toString(),
          count: (j['count'] as num?)?.toInt() ?? 0,
          co: Map<String, int>.from(((j['co'] as Map?) ?? const {})
              .map((k, v) => MapEntry(k.toString(), (v as num).toInt()))),
          sources: ((j['sources'] as List?) ?? const [])
              .map((e) => e.toString())
              .toSet());
}

class ResearchMemory11 {
  final Map<String, dynamic> state317 = <String, dynamic>{};
  bool enabled;
  int dailyBudget;
  int requestsToday;
  String dayKey;
  String? lastResearchAtIso;
  String? lastGoal;
  String lastStatus;
  String? lastError;
  final List<ResearchEvidence11> evidence;
  final Map<String, ResearchClaim11> claims;
  final List<ResearchPassage11> passages;
  final List<ResearchSession11> sessions;
  final Map<String, String> queryLastIso;
  final List<NarrativeEpisode24> narrativeEpisodes;
  final Map<String, EmergentConcept24> emergentConcepts;
  final List<NarrativeLink24> narrativeLinks;
  final Map<String, TermMemory24> termMemory;
  final Set<String> cognitiveSources030;
  int narrativeSentencesSeen;
  int nextNarrativeEpisodeId;

  ResearchMemory11({
    this.enabled = true,
    this.dailyBudget = 0,
    this.requestsToday = 0,
    this.dayKey = '',
    this.lastResearchAtIso,
    this.lastGoal,
    this.lastStatus = 'Ricerca autonoma pronta.',
    this.lastError,
    List<ResearchEvidence11>? evidence,
    Map<String, ResearchClaim11>? claims,
    List<ResearchPassage11>? passages,
    List<ResearchSession11>? sessions,
    Map<String, String>? queryLastIso,
    List<NarrativeEpisode24>? narrativeEpisodes,
    Map<String, EmergentConcept24>? emergentConcepts,
    List<NarrativeLink24>? narrativeLinks,
    Map<String, TermMemory24>? termMemory,
    Set<String>? cognitiveSources030,
    this.narrativeSentencesSeen = 0,
    this.nextNarrativeEpisodeId = 1,
  })  : evidence = evidence ?? <ResearchEvidence11>[],
        claims = claims ?? <String, ResearchClaim11>{},
        passages = passages ?? <ResearchPassage11>[],
        sessions = sessions ?? <ResearchSession11>[],
        queryLastIso = queryLastIso ?? <String, String>{},
        narrativeEpisodes = narrativeEpisodes ?? <NarrativeEpisode24>[],
        emergentConcepts = emergentConcepts ?? <String, EmergentConcept24>{},
        narrativeLinks = narrativeLinks ?? <NarrativeLink24>[],
        termMemory = termMemory ?? <String, TermMemory24>{},
        cognitiveSources030 = cognitiveSources030 ?? <String>{};

  ResearchSession11? get lastSession => sessions.isEmpty ? null : sessions.last;
  int get unresolvedPassages => passages.where((p) => !p.structured).length;
  Iterable<ResearchPassage11> get pendingPassages321 => passages
      .where((p) => !p.structured && p.meta318['extractorAttempt321'] != '322');
  Iterable<ResearchPassage11> get uninterpretedPassages321 => passages
      .where((p) => !p.structured && p.meta318['extractorAttempt321'] == '322');

  int get requestsToday321 {
    final t = DateTime.now();
    final key =
        '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    return dayKey == key ? requestsToday : 0;
  }

  bool canStudyTopic321(String topic, {DateTime? now}) {
    final history = state317['topicStudies321'] as Map? ?? {};
    final record = history[ResearchSemantics317.concept(topic)] as Map?;
    if (record == null) return true;
    final last = DateTime.tryParse('${record['at'] ?? ''}');
    return last == null ||
        (now ?? DateTime.now()).difference(last) >= const Duration(minutes: 15);
  }

  void recordTopicStudy321(String topic, int newEvidence, {DateTime? now}) {
    final history =
        Map<String, dynamic>.from(state317['topicStudies321'] as Map? ?? {});
    history[ResearchSemantics317.concept(topic)] = {
      'at': (now ?? DateTime.now()).toIso8601String(),
      'newEvidence': newEvidence
    };
    state317['topicStudies321'] = history;
  }

  String cognitiveSourceKey030(
      {required String provider,
      required String family,
      required String title,
      required String url}) {
    final u = url.trim().toLowerCase();
    if (u.isNotEmpty) return 'url:$u';
    return 'src:${_n11(family)}|${_n11(provider)}|${_n11(title)}';
  }

  void _rollDay(DateTime now) {
    final key =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (dayKey != key) {
      dayKey = key;
      requestsToday = 0;
    }
  }

  bool canResearch(String query,
      {DateTime? now, Duration repeatAfter = const Duration(hours: 4)}) {
    final t = now ?? DateTime.now();
    _rollDay(t);
    if (!enabled) return false;
    final last = DateTime.tryParse(queryLastIso[_n11(query)] ?? '');
    return last == null || t.difference(last) >= repeatAfter;
  }

  bool canResearchManual(String query, {DateTime? now}) {
    final t = now ?? DateTime.now();
    _rollDay(t);
    return enabled && query.trim().isNotEmpty;
  }

  void begin(String query, DateTime now) {
    _rollDay(now);
    requestsToday++;
    lastResearchAtIso = now.toIso8601String();
    lastGoal = query;
    queryLastIso[_n11(query)] = now.toIso8601String();
  }

  void trim() {
    // Bound the new detailed audit, not the knowledge/evidence archives.
    for (final session in sessions.take(max(0, sessions.length - 8))) {
      if (session.audit315.isNotEmpty) session.audit315.clear();
    }
    if (evidence.length > 12000) {
      final used = claims.values.expand((c) => c.evidenceIds).toSet();
      var surplus = evidence.length - 12000;
      evidence.removeWhere((e) => !used.contains(e.id) && surplus-- > 0);
    }
    if (passages.length > 2500) passages.removeRange(0, passages.length - 2500);
    if (sessions.length > 300) sessions.removeRange(0, sessions.length - 300);
    if (narrativeEpisodes.length > 1200)
      narrativeEpisodes.removeRange(0, narrativeEpisodes.length - 1200);
    if (narrativeLinks.length > 5000)
      narrativeLinks.removeRange(0, narrativeLinks.length - 5000);
    if (emergentConcepts.length > 240) {
      final ranked = emergentConcepts.values.toList()
        ..sort((a, b) => b.support.compareTo(a.support));
      final keep = ranked.take(240).map((x) => x.id).toSet();
      emergentConcepts.removeWhere((k, v) => !keep.contains(k));
    }
    if (termMemory.length > 1800) {
      final ranked = termMemory.values.toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      final keep = ranked.take(1800).map((x) => x.term).toSet();
      termMemory.removeWhere((k, v) => !keep.contains(k));
      for (final t in termMemory.values)
        t.co.removeWhere((k, v) => !keep.contains(k));
    }
    if (claims.length > 6000) {
      final ranked = claims.values.toList()
        ..sort((a, b) => b.lastSeenIso.compareTo(a.lastSeenIso));
      final keep = ranked.take(6000).map((e) => e.key).toSet();
      claims.removeWhere((k, c) =>
          !keep.contains(k) &&
          !{'accettata', 'documentata', 'corretta_utente'}.contains(c.status));
    }
  }

  Map<String, dynamic> toJson() => {
        'version': 11,
        'state317': state317,
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
        'passages': passages.map((e) => e.toJson()).toList(),
        'sessions': sessions.map((e) => e.toJson()).toList(),
        'queryLastIso': queryLastIso,
        'narrativeEpisodes': narrativeEpisodes.map((e) => e.toJson()).toList(),
        'emergentConcepts':
            emergentConcepts.values.map((e) => e.toJson()).toList(),
        'narrativeLinks': narrativeLinks.map((e) => e.toJson()).toList(),
        'termMemory': termMemory.values.map((e) => e.toJson()).toList(),
        'cognitiveSources030': cognitiveSources030.toList(),
        'narrativeSentencesSeen': narrativeSentencesSeen,
        'nextNarrativeEpisodeId': nextNarrativeEpisodeId,
      };

  factory ResearchMemory11.fromJson(Map<String, dynamic> j) {
    final out = ResearchMemory11(
      enabled: j['enabled'] != false,
      dailyBudget: 0,
      requestsToday: (j['requestsToday'] as num?)?.toInt() ?? 0,
      dayKey: (j['dayKey'] ?? '').toString(),
      lastResearchAtIso: j['lastResearchAtIso'] as String?,
      lastGoal: j['lastGoal'] as String?,
      lastStatus: (j['lastStatus'] ?? 'Ricerca autonoma pronta.').toString(),
      lastError: j['lastError'] as String?,
      queryLastIso: Map<String, String>.from(
          ((j['queryLastIso'] as Map?) ?? const {})
              .map((k, v) => MapEntry(k.toString(), v.toString()))),
      cognitiveSources030: ((j['cognitiveSources030'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
      narrativeSentencesSeen:
          (j['narrativeSentencesSeen'] as num?)?.toInt() ?? 0,
      nextNarrativeEpisodeId:
          (j['nextNarrativeEpisodeId'] as num?)?.toInt() ?? 1,
    );
    for (final x in (j['evidence'] as List?) ?? const []) {
      if (x is Map)
        out.evidence
            .add(ResearchEvidence11.fromJson(Map<String, dynamic>.from(x)));
    }
    for (final x in (j['claims'] as List?) ?? const []) {
      if (x is Map) {
        final c = ResearchClaim11.fromJson(Map<String, dynamic>.from(x));
        if (c.key.isNotEmpty) out.claims[c.key] = c;
      }
    }
    for (final x in (j['passages'] as List?) ?? const []) {
      if (x is Map)
        out.passages
            .add(ResearchPassage11.fromJson(Map<String, dynamic>.from(x)));
    }
    for (final x in (j['sessions'] as List?) ?? const []) {
      if (x is Map)
        out.sessions
            .add(ResearchSession11.fromJson(Map<String, dynamic>.from(x)));
    }
    for (final x in (j['narrativeEpisodes'] as List?) ?? const []) {
      if (x is Map)
        out.narrativeEpisodes
            .add(NarrativeEpisode24.fromJson(Map<String, dynamic>.from(x)));
    }
    for (final x in (j['emergentConcepts'] as List?) ?? const []) {
      if (x is Map) {
        final c = EmergentConcept24.fromJson(Map<String, dynamic>.from(x));
        if (c.id.isNotEmpty) out.emergentConcepts[c.id] = c;
      }
    }
    for (final x in (j['narrativeLinks'] as List?) ?? const []) {
      if (x is Map)
        out.narrativeLinks
            .add(NarrativeLink24.fromJson(Map<String, dynamic>.from(x)));
    }
    for (final x in (j['termMemory'] as List?) ?? const []) {
      if (x is Map) {
        final t = TermMemory24.fromJson(Map<String, dynamic>.from(x));
        if (t.term.isNotEmpty) out.termMemory[t.term] = t;
      }
    }
    final evById = <String, ResearchEvidence11>{
      for (final e in out.evidence) e.id: e
    };
    for (final c in out.claims.values) {
      for (final id in c.evidenceIds) {
        final ev = evById[id];
        if (ev != null) c.sourceProviders.add(ev.provider);
      }
    }
    out._rollDay(DateTime.now());
    out.trim();
    out.state317.addAll(Map<String, dynamic>.from(j['state317'] as Map? ?? {}));
    return out;
  }
}

class ResearchGoal11 {
  final String query;
  final String topic;
  final String reason;
  final double value;
  final List<String> contextTerms;
  final Set<String> avoidFamilies031;
  final bool diversityVerification031;
  final String? verifySubject031;
  final String? verifyRelation031;
  final String? verifyObject031;

  const ResearchGoal11({
    required this.query,
    required this.topic,
    required this.reason,
    required this.value,
    this.contextTerms = const <String>[],
    this.avoidFamilies031 = const <String>{},
    this.diversityVerification031 = false,
    this.verifySubject031,
    this.verifyRelation031,
    this.verifyObject031,
  });
  String get focusLabel => topic;
}

class WebDocument11 {
  final String provider;
  final String family;
  final String title;
  final String url;
  final String text;
  final double trust;
  final Map<String, dynamic> meta318;

  const WebDocument11(
      {required this.provider,
      required this.family,
      required this.title,
      required this.url,
      required this.text,
      required this.trust,
      this.meta318 = const <String, dynamic>{}});
}

class ExtractedClaim11 {
  final Map<String, dynamic> meta317;
  final String subject;
  final String relation;
  final String object;
  final String sentence;
  final WebDocument11 source;
  final double quality;
  final String? subjectSenseKey;
  final String? subjectSenseLabel;
  final String? subjectSenseGloss;

  const ExtractedClaim11({
    this.meta317 = const <String, dynamic>{},
    required this.subject,
    required this.relation,
    required this.object,
    required this.sentence,
    required this.source,
    required this.quality,
    this.subjectSenseKey,
    this.subjectSenseLabel,
    this.subjectSenseGloss,
  });
}

class ResearchDraft11 {
  final ResearchGoal11 goal;
  final List<WebDocument11> documents;
  final List<ExtractedClaim11> claims;
  final List<ResearchPassage11> passages;
  final int sentencesRead;
  final String? error;
  final List<Map<String, dynamic>> diagnostics318;

  const ResearchDraft11(
      {required this.goal,
      required this.documents,
      required this.claims,
      required this.passages,
      required this.sentencesRead,
      this.error,
      this.diagnostics318 = const <Map<String, dynamic>>[]});
}

class ResearchOutcome11 {
  final String summary;
  final int integrated;
  final int doubtful;
  final int contradictions;
  const ResearchOutcome11(
      this.summary, this.integrated, this.doubtful, this.contradictions);
}

class WebKnowledgeExplorer11 {
  final Future<Map<String, dynamic>> Function(Uri)? jsonLoader318;
  WebKnowledgeExplorer11({this.jsonLoader318});
  static Map<String, dynamic> validateResponse318(Map<String, dynamic> data) {
    if (data['error'] != null ||
        (data['errors'] is List && (data['errors'] as List).isNotEmpty)) {
      throw FormatException(
          'Errore API: ${jsonEncode(data['error'] ?? data['errors'])}');
    }
    return data;
  }

  static const _ua = 'MGD-Neuro/0.12 autonomous knowledge explorer';
  static final Map<String, Map<String, dynamic>> _cache12 =
      <String, Map<String, dynamic>>{};
  static final Map<String, DateTime> _hostNext12 = <String, DateTime>{};

  ResearchGoal11? selectGoal(
      PlasticLanguageBrain04 brain, MgdWorld06 world, ResearchMemory11 memory,
      {bool force = false}) {
    final now = DateTime.now();
    if (ResearchSemantics317.getPending(memory) > 0) return null;
    final weak = memory.claims.values.where((c) {
      if (!{'dubbia', 'ipotesi_mgd', 'documentata'}.contains(c.status))
        return false;
      if (c.sourceFamilies.length >= 2 && c.confidence >= 0.74) return false;
      final corpusOnly = c.sourceFamilies.isNotEmpty &&
          c.sourceFamilies.every(
              (f) => f.startsWith('corpus:') || f.startsWith('manuale:'));
      return !corpusOnly && _verificationEligible0313(c);
    }).toList()
      ..sort((a, b) =>
          _verificationPriority0313(b).compareTo(_verificationPriority0313(a)));
    // 0.31.4: do not give up on verification just because the highest-priority
    // claim is still inside its cooldown. Walk the ranked queue and verify the
    // next useful claim instead of falling back to generic topic exploration.
    for (final c in weak) {
      if (!force && !memory.canStudyTopic321(c.subject, now: now)) continue;
      final q = '${c.subject} ${c.relation} ${c.object}';
      if (!force &&
          !memory.canResearch(q,
              now: now, repeatAfter: const Duration(hours: 8))) {
        continue;
      }
      return ResearchGoal11(
        query: q,
        topic: c.subject,
        reason: c.sourceFamilies.length < 2
            ? 'ricerca deliberata di una fonte indipendente'
            : 'verifica di una conoscenza ancora debole',
        value: 0.90,
        avoidFamilies031: Set<String>.unmodifiable(c.sourceFamilies),
        diversityVerification031: c.sourceFamilies.length < 2,
        verifySubject031: c.subject,
        verifyRelation031: c.relation,
        verifyObject031: c.object,
      );
    }

    final pending = world.pendingCuriosityQuestion09?.trim();
    if (pending != null &&
        pending.isNotEmpty &&
        (force || memory.canResearch(pending, now: now))) {
      final ids = world.pendingCuriosityEntities09;
      final topic =
          ids.isNotEmpty && ids.first >= 0 && ids.first < brain.entities.length
              ? brain.entities[ids.first].label
              : pending.replaceAll('?', '');
      final sentenceLike = topic.split(RegExp(r'\s+')).length > 6 ||
          RegExp(r'^(?:e|ma|ora|cos[iì]|se|quando|mentre|perch[eé]|come|poi|allora|per\s+lui|per\s+lei)\b',
                  caseSensitive: false)
              .hasMatch(topic) ||
          topic.contains(':') ||
          topic.contains(';');
      if (!sentenceLike) {
        return ResearchGoal11(
            query: pending.replaceAll('?', ''),
            topic: topic,
            reason: 'domanda generata dalla curiosità interna',
            value: 0.92);
      }
    }

    final facts = brain.cognitiveFacts06();
    final count = <int, int>{};
    for (final f in facts) count[f.subjectId] = (count[f.subjectId] ?? 0) + 1;
    ResearchGoal11? best;
    for (final e in brain.entities) {
      final label = e.label.trim();
      if (!force && !memory.canStudyTopic321(label, now: now)) continue;
      final n = _n11(label);
      final oneWordVerb = !label.contains(' ') &&
          RegExp(r'(are|ere|ire)$', caseSensitive: false).hasMatch(label);
      final sentenceLike = label.split(RegExp(r'\s+')).length > 6 ||
          RegExp(r'^(?:e|ma|ora|cos[iì]|se|quando|mentre|perch[eé]|come|poi|allora|per\s+lui|per\s+lei)\b',
                  caseSensitive: false)
              .hasMatch(label) ||
          label.contains(':') ||
          label.contains(';');
      if (label.length < 3 ||
          sentenceLike ||
          oneWordVerb ||
          {'utente', 'self', 'io', 'tu'}.contains(n) ||
          RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(label)) continue;
      final context = <String>{};
      for (final f in facts) {
        if (f.subjectId == e.id && f.object.trim().length >= 3)
          context.add(f.object.trim());
        if (f.objectEntityId == e.id &&
            f.subjectId >= 0 &&
            f.subjectId < brain.entities.length) {
          context.add(brain.entities[f.subjectId].label);
        }
      }
      final contextTerms = context.where((x) => _n11(x) != n).take(3).toList();
      final factCount = count[e.id] ?? 0;
      final uncertainty =
          (1.0 / (1.0 + 0.42 * factCount)).clamp(0.10, 1.0).toDouble();
      final relevance = (0.35 +
              0.08 * min(e.mentions, 6) +
              (brain.step - e.lastSeen < 80 ? 0.20 : 0))
          .clamp(0.25, 1.0)
          .toDouble();
      final curiosity = max(0.42, max(world.curiosity, world.noveltyEma));
      final value =
          (uncertainty * relevance * curiosity).clamp(0.0, 1.0).toDouble();
      final q = ([label, ...contextTerms, 'definizione', 'caratteristiche'])
          .join(' ');
      if ((force || value >= 0.08) &&
          (force || memory.canResearch(q, now: now)) &&
          (best == null || value > best.value)) {
        best = ResearchGoal11(
          query: q,
          topic: label,
          reason: 'argomento rilevante ma poco strutturato nel grafo',
          value: value,
          contextTerms: contextTerms,
        );
      }
    }
    return best;
  }

  Future<ResearchDraft11> research(ResearchGoal11 goal) async {
    final diagnostics = <Map<String, dynamic>>[];
    try {
      final topic = goal.topic.trim().isEmpty ? goal.query : goal.topic.trim();
      Future<List<WebDocument11>> safeDocs(
          String provider, Future<List<WebDocument11>> source) async {
        try {
          final result = await source;
          diagnostics.add({
            'provider': provider,
            'status':
                result.isEmpty ? 'nessun documento' : 'documenti acquisiti',
            'documents': result.length
          });
          return result;
        } catch (e) {
          diagnostics.add({
            'provider': provider,
            'status': 'errore',
            'error': e.toString()
          });
          return const <WebDocument11>[];
        }
      }

      final scientificFirst = goal.diversityVerification031 ||
          _looksScientific031(
              '$topic ${goal.query} ${goal.contextTerms.join(' ')}');

      final scientificQueries0312 = <String>{topic, goal.query.trim()};
      final subjectAliases0313 = <String>{topic};
      if (goal.diversityVerification031 && goal.verifySubject031 != null) {
        final subject = goal.verifySubject031!.trim();
        if (subject.isNotEmpty) {
          scientificQueries0312.add(subject);
          subjectAliases0313.add(subject);
        }
        try {
          final aliases = await _wikidataLexicalAliases0312(subject);
          for (final a in aliases.take(4)) {
            if (a.trim().isNotEmpty) {
              scientificQueries0312.add(a.trim());
              subjectAliases0313.add(a.trim());
            }
          }
        } catch (_) {}
      }
      final preferredQueries0312 =
          scientificQueries0312.where((q) => q.trim().isNotEmpty).toList()
            ..sort((a, b) {
              final as = a.split(RegExp(r'\s+')).length;
              final bs = b.split(RegExp(r'\s+')).length;
              return as.compareTo(bs);
            });
      final requests = <Future<List<WebDocument11>>>[
        if (scientificFirst)
          for (final q in preferredQueries0312.take(2))
            safeDocs('Europe PMC', _europePmc031(q)),
        if (scientificFirst)
          for (final q in preferredQueries0312.take(2))
            safeDocs('Crossref', _crossref031(q)),
        safeDocs('Wikipedia IT', _wikipedia(topic)),
        safeDocs('Wikidata', _wikidata(topic)),
        safeDocs('DuckDuckGo', _duck(topic)),
        if (!scientificFirst) safeDocs('Crossref', _crossref031(goal.query)),
      ];
      final first = await Future.wait<List<WebDocument11>>(requests);
      final docs = <WebDocument11>[];
      final seen = <String>{};
      for (final group in first) {
        for (final d in group) {
          final key = d.url.isEmpty
              ? '${d.provider}|${_n11(d.title)}|${d.text.hashCode}'
              : d.url;
          if (seen.add(key) && d.text.trim().length >= 15) docs.add(d);
        }
      }
      if (goal.avoidFamilies031.isNotEmpty) {
        docs.sort((a, b) {
          final aFresh = goal.avoidFamilies031.contains(a.family) ? 0 : 1;
          final bFresh = goal.avoidFamilies031.contains(b.family) ? 0 : 1;
          if (aFresh != bFresh) return bFresh.compareTo(aFresh);
          return b.trust.compareTo(a.trust);
        });
      }
      if (docs.length < 2 && _n11(goal.query) != _n11(topic)) {
        for (final d
            in await safeDocs('Wikipedia IT', _wikipedia(goal.query))) {
          if (seen.add(d.url)) docs.add(d);
        }
      }
      // A resolved title/redirect is stronger than incidental context words.
      // Record every rejection so acquisition and usable documents are distinct.
      final rejected = docs.where((d) => !documentMatches320(goal, d)).toList();
      for (final d in rejected) {
        diagnostics.add({
          'provider': d.provider,
          'status': 'fuori argomento',
          'title': d.title,
          'url': d.url,
          'reason': 'Il soggetto richiesto non compare come termine completo.'
        });
      }
      docs.removeWhere((d) => rejected.contains(d));
      // A label imported as "A o B" may contain alternative descriptions.
      // Retry the parts only after the complete label yields no relevant
      // document, and preserve the page's own subject instead of asserting
      // that the alternatives are equivalent entities.
      if (docs.isEmpty) {
        for (final part in alternativeTopics322(topic)) {
          final alternatives = await safeDocs('Wikipedia IT', _wikipedia(part));
          for (final d in alternatives) {
            final resolvedPart =
                ResearchSemantics317.sameSubject(d.title, part) ||
                    (d.meta318['resolvedTopic'] == true &&
                        ResearchSemantics317.sameSubject(
                            '${d.meta318['requestedTopic'] ?? ''}', part));
            if (!resolvedPart) {
              diagnostics.add({
                'provider': d.provider,
                'status': 'risultato parziale escluso',
                'matchedTopic': part,
                'title': d.title,
                'url': d.url,
                'reason':
                    'Il titolo o un redirect non risolvono questa parte della richiesta.'
              });
              continue;
            }
            if (docs.any((old) => old.url == d.url)) continue;
            seen.add(d.url);
            docs.add(WebDocument11(
                provider: d.provider,
                family: d.family,
                title: d.title,
                url: d.url,
                text: d.text,
                trust: d.trust,
                meta318: {
                  ...d.meta318,
                  'requestedTopic': topic,
                  'resolvedTopic': false,
                  'partialTopic322': part,
                  'partialResolved322': true,
                  'resolution':
                      'Argomento parziale: $part; non equivalenza con tutta la ricerca.'
                }));
            diagnostics.add({
              'provider': d.provider,
              'status': 'argomento parziale',
              'requestedTopic': topic,
              'matchedTopic': part,
              'title': d.title,
              'url': d.url
            });
          }
        }
      }
      docs.sort((a, b) => (b.meta318['resolvedTopic'] == true ? 1 : 0)
          .compareTo(a.meta318['resolvedTopic'] == true ? 1 : 0));

      for (final d in docs) {
        if (d.meta318['resolvedTopic'] == true) subjectAliases0313.add(d.title);
      }
      final claims = <ExtractedClaim11>[];
      final passages = <ResearchPassage11>[];
      var sentenceCount = 0;
      for (final doc in docs.take(10)) {
        final sentences = _sentences(doc.text).take(24).toList();
        sentenceCount += sentences.length;
        for (var i = 0; i < sentences.length; i++) {
          final sentence = sentences[i];
          var extracted = ResearchSemantics317.extractDocument318(
              topic, sentence, doc,
              first: i == 0);
          if (extracted.isEmpty && subjectAliases0313.length > 1) {
            for (final alias in subjectAliases0313) {
              if (_n11(alias) == _n11(topic)) continue;
              final alt = extractClaimsFromSentence(alias, sentence, doc,
                  allowImplicitSubject: i < 4);
              if (alt.isEmpty) continue;
              extracted = alt
                  .map((c) => ExtractedClaim11(
                        subject: c.subject,
                        relation: c.relation,
                        object: c.object,
                        sentence: c.sentence,
                        source: c.source,
                        quality: c.quality * 0.98,
                        subjectSenseKey: c.subjectSenseKey,
                        subjectSenseLabel: c.subjectSenseLabel,
                        subjectSenseGloss: c.subjectSenseGloss,
                        meta317: c.meta317,
                      ))
                  .toList();
              break;
            }
          }
          if (extracted.isNotEmpty) {
            claims.addAll(extracted);
          } else if (_passageRelevant(topic, sentence)) {
            passages.add(ResearchPassage11(
              id: '${DateTime.now().microsecondsSinceEpoch}:${passages.length}:${sentence.hashCode}',
              topic: topic,
              provider: doc.provider,
              sourceFamily: doc.family,
              sourceTitle: doc.title,
              sourceUrl: doc.url,
              text: sentence,
              trust: doc.trust,
              meta318: doc.meta318,
            ));
          }
        }
      }
      try {
        final xs = await _wikidataClaims(topic,
            documents: docs, diagnostics: diagnostics);
        claims.addAll(xs);
        diagnostics.add({
          'provider': 'Wikidata proprietà',
          'status': xs.isEmpty
              ? 'nessuna dichiarazione risolta'
              : 'dichiarazioni acquisite',
          'claims': xs.length
        });
      } catch (e) {
        diagnostics.add({
          'provider': 'Wikidata proprietà',
          'status': 'errore',
          'error': e.toString()
        });
        // A throttled provider must not invalidate evidence already collected.
      }

      if (goal.diversityVerification031 &&
          goal.verifySubject031 != null &&
          goal.verifyRelation031 != null &&
          goal.verifyObject031 != null) {
        final targetSubject = goal.verifySubject031!;
        final targetRelation = goal.verifyRelation031!;
        final targetObject = goal.verifyObject031!;
        for (final doc in docs.take(10)) {
          if (goal.avoidFamilies031.contains(doc.family)) continue;
          for (final sentence in _sentences(doc.text).take(24)) {
            if (!_verificationEvidenceSupports0313(
              sentence,
              documentTitle: doc.title,
              subject: targetSubject,
              subjectAliases: subjectAliases0313,
              relation: targetRelation,
              object: targetObject,
            )) continue;
            claims.add(ExtractedClaim11(
              subject: targetSubject,
              relation: targetRelation,
              object: targetObject,
              sentence: sentence,
              source: doc,
              quality: 0.80,
            ));
          }
        }
      }

      return ResearchDraft11(
          goal: goal,
          documents: docs,
          claims: _dedupeClaims(claims),
          passages: passages.take(40).toList(),
          sentencesRead: sentenceCount,
          diagnostics318: diagnostics);
    } catch (e) {
      return ResearchDraft11(
          goal: goal,
          documents: const [],
          claims: const [],
          passages: const [],
          sentencesRead: 0,
          error: e.toString(),
          diagnostics318: diagnostics);
    }
  }

  ResearchOutcome11 integrate(PlasticLanguageBrain04 brain, MgdWorld06 world,
          ResearchMemory11 memory, ResearchDraft11 draft) =>
      ResearchSemantics317.integrate(brain, world, memory, draft);

  List<ExtractedClaim11> _corroborationSweep0314(
    ResearchMemory11 memory,
    ResearchDraft11 draft, {
    List<Map<String, dynamic>>? trace315,
  }) {
    if (draft.documents.isEmpty || memory.claims.isEmpty)
      return const <ExtractedClaim11>[];

    final topic = _n11(draft.goal.topic);
    final targets = memory.claims.values.where((c) {
      if (c.status != 'ipotesi_mgd' ||
          c.conflict ||
          c.sourceFamilies.length >= 2) return false;
      if (!_verificationEligible0313(c)) return false;
      final cs = _n11(c.subject);
      return cs == topic ||
          _rootCompatible0311(_semanticStem0313(cs), _semanticStem0313(topic));
    }).toList()
      ..sort((a, b) =>
          _verificationPriority0313(b).compareTo(_verificationPriority0313(a)));

    if (targets.isEmpty) return const <ExtractedClaim11>[];

    final out = <ExtractedClaim11>[];
    final seen = <String>{};
    for (final claim in targets.skip(8)) {
      trace315?.add({
        'claimKey': claim.key,
        'subject': claim.subject,
        'relation': claim.relation,
        'object': claim.object,
        'esito': 'Non esaminata: fuori dal limite di 8 ipotesi per ricerca.'
      });
    }
    for (final claim in targets.take(8)) {
      final aliases = <String>{claim.subject, draft.goal.topic};
      var documentsExamined315 = 0;
      for (final doc in draft.documents.take(24)) {
        documentsExamined315++;
        final audit = <String, dynamic>{
          'claimKey': claim.key,
          'subject': claim.subject,
          'relation': claim.relation,
          'object': claim.object,
          'sourceTitle': doc.title,
          'sourceUrl': doc.url,
          'provider': doc.provider,
          'family': doc.family,
          'metodo': 'Confronto aggiuntivo lessicale 0.31.4'
        };
        trace315?.add(audit);
        if (claim.sourceFamilies.contains(doc.family)) {
          audit['esito'] = 'Saltata: famiglia già presente nella proposizione.';
          continue;
        }
        var supported = false;
        final checked = <Map<String, dynamic>>[];
        audit['Frasi confrontate'] = checked;
        for (final sentence in _sentences(doc.text).take(20)) {
          checked.add(verificationDiagnostics315(sentence,
              documentTitle: doc.title,
              subject: claim.subject,
              subjectAliases: aliases,
              relation: claim.relation,
              object: claim.object));
          if (!_verificationEvidenceSupports0313(
            sentence,
            documentTitle: doc.title,
            subject: claim.subject,
            subjectAliases: aliases,
            relation: claim.relation,
            object: claim.object,
          )) continue;
          final key = '${claim.key}|${doc.family}|${doc.url}';
          if (!seen.add(key)) break;
          out.add(ExtractedClaim11(
            subject: claim.subject,
            relation: claim.relation,
            object: claim.object,
            sentence: sentence,
            source: doc,
            quality: 0.82,
            subjectSenseKey: claim.subjectSenseKey,
            subjectSenseLabel: claim.subjectSenseLabel,
            subjectSenseGloss: claim.subjectSenseGloss,
          ));
          supported = true;
          break;
        }
        audit['esito'] = supported
            ? 'Compatibilità lessicale rilevata; proposta come evidenza.'
            : 'Nessuna frase supera i tre controlli lessicali.';
        if (supported &&
            out
                    .where((x) =>
                        _n11(x.subject) == _n11(claim.subject) &&
                        _n11(x.relation) == _n11(claim.relation) &&
                        _objectsEquivalent0313(x.object, claim.object))
                    .length >=
                3) {
          break;
        }
      }
      if (documentsExamined315 < draft.documents.length) {
        trace315?.add({
          'claimKey': claim.key,
          'subject': claim.subject,
          'relation': claim.relation,
          'object': claim.object,
          'esito':
              'Documenti ulteriori non esaminati: limite o obiettivo di 3 supporti raggiunto.',
          'documenti non esaminati':
              draft.documents.length - documentsExamined315
        });
      }
    }
    return _dedupeClaims(out);
  }

  int reprocessDuringSleep(
      PlasticLanguageBrain04 brain, MgdWorld06 world, ResearchMemory11 memory,
      {int limit = 16}) {
    final pending = memory.pendingPassages321.take(limit).toList();
    var learned = 0;
    final now = DateTime.now().toIso8601String();
    for (final p in pending) {
      p.attempts++;
      p.lastAttemptIso = now;
      p.meta318['extractorAttempt321'] = '322';
      final doc = WebDocument11(
          provider: p.provider,
          family: p.sourceFamily,
          title: p.sourceTitle,
          url: p.sourceUrl,
          text: p.text,
          trust: p.trust,
          meta318: p.meta318);
      final xs = ResearchSemantics317.extractDocument318(p.topic, p.text, doc,
          first: true);
      if (xs.isEmpty)
        xs.addAll(ResearchSemantics317.extractAny321(p.text, doc));
      if (xs.isEmpty) continue;
      final newlyUsable =
          ResearchSemantics317.observePassage321(brain, world, memory, p, xs);
      // A parsed passage is structured even when its facts were already known.
      p.structured = true;
      learned += newlyUsable;
    }
    return learned;
  }

  List<ExtractedClaim11> extractClaimsFromSentence(
          String subject, String sentence, WebDocument11 doc,
          {bool allowImplicitSubject = false}) =>
      ResearchSemantics317.extract(subject, sentence, doc,
          implicit: allowImplicitSubject);

  bool _looksScientific031(String text) {
    final n = _n11(text);
    const terms = <String>{
      'dna',
      'rna',
      'proteina',
      'proteine',
      'amminoacido',
      'amminoacidi',
      'nucleotide',
      'nucleotidi',
      'cellula',
      'cellule',
      'gene',
      'geni',
      'genoma',
      'cromosoma',
      'enzima',
      'enzimi',
      'atp',
      'adp',
      'amp',
      'biologia',
      'chimica',
      'molecola',
      'molecole',
      'organismo',
      'organismi',
      'batterio',
      'batteri',
      'virus',
      'metabolismo',
      'recettore',
      'membrana',
      'microrganismo',
      'antibiotico',
      'resistenza'
    };
    final xs = n.split(' ').toSet();
    return xs.intersection(terms).isNotEmpty;
  }

  String _stripMarkup031(String x) => x
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\\s+'), ' ')
      .trim();

  String _paperFamily031(String? doi, String fallback) {
    final d = (doi ?? '')
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^https?://(?:dx\\.)?doi\\.org/'), '');
    if (d.isNotEmpty) return 'paper:doi:$d';
    return 'paper:${_n11(fallback).replaceAll(' ', ':')}';
  }

  Future<List<String>> _wikidataLexicalAliases0312(String term) async {
    final search = await _json(Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbsearchentities',
      'search': term,
      'language': 'it',
      'uselang': 'it',
      'limit': '2',
      'format': 'json',
      'origin': '*',
    }));
    final rows = ((search['search'] as List?) ?? const [])
        .whereType<Map>()
        .where((r) =>
            ResearchSemantics317.sameSubject('${r['label'] ?? ''}', term))
        .toList();
    if (rows.length != 1) return <String>[term];
    final ids = <String>[];
    for (final x in rows) {
      if (x is! Map) continue;
      final id = (x['id'] ?? '').toString();
      if (id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return const <String>[];
    final data = await _json(Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbgetentities',
      'ids': ids.join('|'),
      'props': 'labels|aliases',
      'languages': 'it|en',
      'format': 'json',
      'origin': '*',
    }));
    final entities = data['entities'];
    if (entities is! Map) return const <String>[];
    final out = <String>{term.trim()};
    for (final raw in entities.values) {
      if (raw is! Map) continue;
      final j = Map<String, dynamic>.from(raw);
      final labels = j['labels'];
      if (labels is Map) {
        for (final lang in const ['it', 'en']) {
          final v = labels[lang];
          if (v is Map) {
            final x = (v['value'] ?? '').toString().trim();
            if (x.length >= 2 && x.split(RegExp(r'\s+')).length <= 6)
              out.add(x);
          }
        }
      }
      final aliases = j['aliases'];
      if (aliases is Map) {
        for (final lang in const ['it', 'en']) {
          final xs = aliases[lang];
          if (xs is List) {
            for (final v in xs.take(4)) {
              if (v is! Map) continue;
              final x = (v['value'] ?? '').toString().trim();
              if (x.length >= 2 && x.split(RegExp(r'\s+')).length <= 6)
                out.add(x);
            }
          }
        }
      }
    }
    return out.toList();
  }

  Future<List<WebDocument11>> _europePmc031(String q) async {
    final uri =
        Uri.https('www.ebi.ac.uk', '/europepmc/webservices/rest/search', {
      'query': q,
      'format': 'json',
      'pageSize': '8',
      'resultType': 'core',
    });
    final raw = await _json(uri);
    final list = ((raw['resultList'] as Map?)?['result'] as List?) ?? const [];
    final out = <WebDocument11>[];
    for (final x in list) {
      if (x is! Map) continue;
      final j = Map<String, dynamic>.from(x);
      final title = (j['title'] ?? '').toString().trim();
      final abstractText =
          _stripMarkup031((j['abstractText'] ?? '').toString());
      if (title.isEmpty || abstractText.length < 45) continue;
      final doi = (j['doi'] ?? '').toString().trim();
      final pmid = (j['pmid'] ?? j['pmcid'] ?? '').toString().trim();
      final url = doi.isNotEmpty
          ? 'https://doi.org/$doi'
          : (pmid.isEmpty ? '' : 'https://europepmc.org/article/MED/$pmid');
      out.add(WebDocument11(
        provider: 'Europe PMC',
        family: _paperFamily031(doi, pmid.isEmpty ? title : pmid),
        title: title,
        url: url,
        text: '$title. $abstractText',
        trust: 0.93,
      ));
    }
    return out;
  }

  Future<List<WebDocument11>> _crossref031(String q) async {
    final uri = Uri.https('api.crossref.org', '/works', {
      'query.bibliographic': q,
      'rows': '8',
      'select': 'DOI,title,abstract,URL,publisher,type',
    });
    final raw = await _json(uri);
    final items = ((raw['message'] as Map?)?['items'] as List?) ?? const [];
    final out = <WebDocument11>[];
    for (final x in items) {
      if (x is! Map) continue;
      final j = Map<String, dynamic>.from(x);
      final titles = (j['title'] as List?) ?? const [];
      final title = titles.isEmpty ? '' : titles.first.toString().trim();
      final abstractText = _stripMarkup031((j['abstract'] ?? '').toString());
      if (title.isEmpty || abstractText.length < 45) continue;
      final doi = (j['DOI'] ?? '').toString().trim();
      final url =
          (j['URL'] ?? (doi.isEmpty ? '' : 'https://doi.org/$doi')).toString();
      out.add(WebDocument11(
        provider: 'Crossref',
        family: _paperFamily031(doi, title),
        title: title,
        url: url,
        text: '$title. $abstractText',
        trust: 0.86,
      ));
    }
    return out;
  }

  Future<List<WebDocument11>> _wikipedia(String q) async {
    final forms = ResearchSemantics317.queryForms318(q);
    final raw = await _json(Uri.https('it.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'titles': forms.join('|'),
      'redirects': '1',
      'prop': 'extracts|info|pageprops',
      'ppprop': 'wikibase_item|disambiguation',
      'exintro': '1',
      'explaintext': '1',
      'inprop': 'url',
      'format': 'json',
      'formatversion': '2',
      'origin': '*'
    }));
    final exact = _wikiDocuments318(raw, q, resolved: true);
    if (exact.isNotEmpty) return exact;
    final search = await _json(Uri.https('it.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': q,
      'gsrlimit': '4',
      'prop': 'extracts|info|pageprops',
      'ppprop': 'wikibase_item|disambiguation',
      'exintro': '1',
      'explaintext': '1',
      'inprop': 'url',
      'format': 'json',
      'formatversion': '2',
      'origin': '*'
    }));
    return _wikiDocuments318(search, q, resolved: false);
  }

  List<WebDocument11> _wikiDocuments318(Map<String, dynamic> raw, String q,
      {required bool resolved}) {
    final pages = ((raw['query'] as Map?)?['pages'] as List?) ?? const [];
    final out = <WebDocument11>[];
    for (final j in pages.whereType<Map>()) {
      if (j.containsKey('missing')) continue;
      final pp = j['pageprops'] is Map ? j['pageprops'] as Map : const {};
      if (pp.containsKey('disambiguation')) continue;
      final text = '${j['extract'] ?? ''}'.trim(),
          title = '${j['title'] ?? ''}'.trim();
      if (text.length < 20 || title.isEmpty) continue;
      out.add(WebDocument11(
          provider: 'Wikipedia IT',
          family: 'wikimedia',
          title: title,
          url: '${j['fullurl'] ?? ''}',
          text: text,
          trust: 0.84,
          meta318: {
            'wikidataId': pp['wikibase_item'],
            'requestedTopic': q,
            'resolvedTopic':
                resolved || ResearchSemantics317.sameSubject(title, q),
            'resolution': resolved
                ? 'titolo o redirect Wikipedia'
                : 'risultato ricerca, soggetto proprio',
            'redirects': (raw['query'] as Map?)?['redirects'] ?? [],
            'normalized': (raw['query'] as Map?)?['normalized'] ?? []
          }));
    }
    return out;
  }

  Future<List<WebDocument11>> _wikidata(String q) async {
    final uri = Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbsearchentities',
      'search': q,
      'language': 'it',
      'uselang': 'it',
      'limit': '4',
      'format': 'json',
      'origin': '*'
    });
    final raw = await _json(uri);
    final rows = (raw['search'] as List?) ?? const [];
    final out = <WebDocument11>[];
    for (final x in rows) {
      if (x is! Map) continue;
      final j = Map<String, dynamic>.from(x);
      final label = (j['label'] ?? '').toString().trim();
      final desc = (j['description'] ?? '').toString().trim();
      if (label.isEmpty || desc.isEmpty || _metadataNoise12(desc)) continue;
      out.add(WebDocument11(
          provider: 'Wikidata',
          family: 'wikimedia',
          title: label,
          url: (j['concepturi'] ?? '').toString(),
          text: 'Descrizione di $label: $desc.',
          trust: 0.88));
    }
    return out;
  }

  Future<List<ExtractedClaim11>> _wikidataClaims(String topic,
      {List<WebDocument11> documents = const [],
      List<Map<String, dynamic>>? diagnostics}) async {
    final search = await _json(Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbsearchentities',
      'search': topic,
      'language': 'it',
      'uselang': 'it',
      'limit': '4',
      'format': 'json',
      'origin': '*'
    }));
    final byId = <String, Map>{};
    for (final r in ((search['search'] as List?) ?? []).whereType<Map>()) {
      final aliases = <String>[
        '${r['label'] ?? ''}',
        if (r['match'] is Map) '${(r['match'] as Map)['text'] ?? ''}',
        ...((r['aliases'] as List?) ?? []).map((v) => '$v')
      ];
      if (aliases.any((v) => ResearchSemantics317.sameSubject(v, topic)) ||
          r['id'] == topic) byId['${r['id']}'] = r;
    }
    for (final d in documents) {
      final id = '${d.meta318['wikidataId'] ?? ''}';
      if (d.meta318['resolvedTopic'] == true &&
          RegExp(r'^Q[1-9][0-9]*$').hasMatch(id)) {
        byId[id] = {
          'id': id,
          'label': d.title,
          'description': '',
          'resolvedFrom': d.url
        };
      }
    }
    final rows = byId.values.toList();
    diagnostics?.add({
      'provider': 'Risoluzione identità',
      'status':
          rows.isEmpty ? 'termine non risolto' : 'identità distinte risolte',
      'topic': topic,
      'entities': rows
          .map((r) => {
                'id': r['id'],
                'label': r['label'],
                'resolvedFrom': r['resolvedFrom']
              })
          .toList()
    });
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => '${r['id']}').join('|');
    final data = await _json(Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbgetentities',
      'ids': ids,
      'props': 'claims|labels|descriptions|info',
      'languages': 'it|en',
      'format': 'json',
      'origin': '*'
    }));
    final entities = data['entities'];
    if (entities is! Map) return [];
    final targets = <String>{};
    for (final e in entities.values.whereType<Map>()) {
      final claims = e['claims'];
      if (claims is! Map) continue;
      for (final p in ResearchSemantics317.properties.keys) {
        final ss = claims[p];
        if (ss is! List) continue;
        for (final st in ss.whereType<Map>()) {
          final sn = st['mainsnak'];
          if (sn is! Map) continue;
          final dv = sn['datavalue'];
          if (dv is! Map) continue;
          final v = dv['value'];
          if (v is Map && v['id'] != null) targets.add('${v['id']}');
        }
      }
    }
    final labels = <String, dynamic>{};
    final targetList = targets.toList();
    for (var i = 0; i < targetList.length; i += 40) {
      final ld = await _json(Uri.https('www.wikidata.org', '/w/api.php', {
        'action': 'wbgetentities',
        'ids': targetList.skip(i).take(40).join('|'),
        'props': 'labels',
        'languages': 'it|en',
        'format': 'json',
        'origin': '*'
      }));
      if (ld['entities'] is Map)
        labels.addAll(Map<String, dynamic>.from(ld['entities'] as Map));
    }
    final out = <ExtractedClaim11>[];
    for (final r in rows) {
      final id = '${r['id']}';
      final e = entities[id];
      if (e is! Map) continue;
      String field(String name, String fallback) {
        final values = e[name];
        if (values is! Map) return fallback;
        final value = values['it'] ?? values['en'];
        return value is Map ? '${value['value'] ?? fallback}' : fallback;
      }

      final xs = ResearchSemantics317.structured(
          Map<String, dynamic>.from(e), labels,
          id: id,
          label: field('labels', '${r['label'] ?? topic}'),
          gloss: field('descriptions', '${r['description'] ?? ''}'));
      for (final x in xs) {
        x.meta317['queryAliases318'] = [topic, '${r['label'] ?? topic}'];
        x.meta317['identityResolution318'] =
            r['resolvedFrom'] ?? 'alias completo della fonte';
      }
      out.addAll(xs);
    }
    return out;
  }

  Future<List<WebDocument11>> _duck(String q) async {
    final raw = await _json(Uri.https('api.duckduckgo.com', '/', {
      'q': q,
      'format': 'json',
      'no_html': '1',
      'no_redirect': '1',
      'skip_disambig': '0',
      'kl': 'it-it'
    }));
    final text = (raw['AbstractText'] ?? '').toString().trim();
    if (text.length < 20) return const [];
    final url = (raw['AbstractURL'] ?? '').toString();
    if (!_looksItalian12(text)) return const [];
    var family = 'duckduckgo';
    try {
      final host = Uri.parse(url).host.toLowerCase();
      if (host.contains('wikipedia.org') || host.contains('wikidata.org')) {
        family = 'wikimedia';
      } else if (host.isNotEmpty) {
        family = host;
      }
    } catch (_) {}
    return [
      WebDocument11(
          provider: 'DuckDuckGo',
          family: family,
          title: (raw['Heading'] ?? q).toString(),
          url: url,
          text: text,
          trust: 0.68)
    ];
  }

  Future<Map<String, dynamic>> _json(Uri uri) async {
    if (jsonLoader318 != null)
      return validateResponse318(await jsonLoader318!(uri));
    final key = uri.toString();
    final cached = _cache12[key];
    if (cached != null) return Map<String, dynamic>.from(cached);

    final host = uri.host.toLowerCase();
    final next = _hostNext12[host];
    if (next != null) {
      final wait = next.difference(DateTime.now());
      if (!wait.isNegative) await Future<void>.delayed(wait);
    }

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 7);
      try {
        _hostNext12[host] =
            DateTime.now().add(const Duration(milliseconds: 1100));
        final req =
            await client.getUrl(uri).timeout(const Duration(seconds: 9));
        req.headers.set(HttpHeaders.userAgentHeader, _ua);
        req.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final res = await req.close().timeout(const Duration(seconds: 10));
        if (res.statusCode == 429) {
          lastError = HttpException('HTTP 429 da ${uri.host}');
          await res.drain<void>();
          await Future<void>.delayed(
              Duration(milliseconds: 1400 * (attempt + 1) * (attempt + 1)));
          continue;
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw HttpException('HTTP ${res.statusCode} da ${uri.host}');
        }
        final body = await res
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 10));
        if (body.length > 1800000)
          throw const FormatException('Risposta web troppo grande');
        final decoded = jsonDecode(body);
        if (decoded is! Map) throw const FormatException('JSON non valido');
        final out = validateResponse318(Map<String, dynamic>.from(decoded));
        _cache12[key] = out;
        return Map<String, dynamic>.from(out);
      } catch (e) {
        lastError = e;
        if (attempt >= 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
      } finally {
        client.close(force: true);
      }
    }
    throw lastError ?? StateError('Ricerca non disponibile');
  }

  static bool _metadataNoise12(String text) {
    final n = _n11(text);
    return n.contains('articolo della wikipedia') ||
        n.contains('pagina di disambiguazione') ||
        n.contains('categoria wikimedia') ||
        n.contains('pagina wikimedia') ||
        n.contains('lista di pagine');
  }

  static bool _looksItalian12(String text) {
    final n = ' ${_n11(text)} ';
    final italian = [
      ' il ',
      ' la ',
      ' di ',
      ' che ',
      ' è ',
      ' e ',
      ' un ',
      ' una ',
      ' del ',
      ' della ',
      ' per ',
      ' con '
    ].where(n.contains).length;
    final english = [
      ' the ',
      ' of ',
      ' using ',
      ' something ',
      ' is a ',
      ' and the '
    ].where(n.contains).length;
    return italian >= english && italian >= 1;
  }

  static List<String> alternativeTopics322(String topic) {
    final parts = topic
        .split(RegExp(r'\s+(?:o|oppure)\s+', caseSensitive: false))
        .map((s) => s.trim())
        .where((s) => s.length >= 2 && s.length <= 80)
        .toSet();
    return parts.length >= 2 && parts.length <= 3 ? parts.toList() : const [];
  }

  static bool documentMatches320(ResearchGoal11 goal, WebDocument11 doc) {
    final partial = doc.meta318['partialTopic322'];
    if (partial is String &&
        alternativeTopics322(goal.topic).contains(partial)) {
      return doc.meta318['partialResolved322'] == true;
    }
    if (doc.meta318['resolvedTopic'] == true &&
        ResearchSemantics317.sameSubject(
            '${doc.meta318['requestedTopic'] ?? goal.topic}', goal.topic))
      return true;
    if (ResearchSemantics317.sameSubject(doc.title, goal.topic)) return true;
    final hay = ' ${ResearchSemantics317.concept('${doc.title} ${doc.text}')} ';
    final topic = ResearchSemantics317.concept(goal.topic);
    // Context alone (e.g. "tassonomia" in clinical registries) is insufficient.
    return topic.isNotEmpty && hay.contains(' $topic ');
  }

  static bool _verificationEligible0313(ResearchClaim11 c) {
    if (c.conflict || _suspiciousKnowledge12(c.subject, c.relation, c.object))
      return false;
    final sw = c.subject
        .trim()
        .split(RegExp(r'\s+'))
        .where((x) => x.isNotEmpty)
        .length;
    final ow =
        c.object.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).length;
    if (sw == 0 || sw > 7 || ow == 0 || ow > 10) return false;
    final last = _n11(c.object).split(' ').where((x) => x.isNotEmpty).toList();
    if (last.isNotEmpty &&
        {
          'e',
          'ed',
          'di',
          'del',
          'della',
          'dei',
          'degli',
          'delle',
          'da',
          'con',
          'per',
          'and',
          'of',
          'to',
          'with'
        }.contains(last.last)) return false;
    return true;
  }

  static double _verificationPriority0313(ResearchClaim11 c) {
    final missingFamily = c.sourceFamilies.length < 2 ? 1.0 : 0.0;
    final evidence = min(6, c.evidenceCount).toDouble();
    final provider = min(4, c.providerCount).toDouble();
    final objectWords =
        c.object.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).length;
    return 4.0 * missingFamily +
        3.0 * c.confidence +
        0.65 * evidence +
        0.25 * provider -
        0.06 * objectWords;
  }

  static String _semanticStem0313(String raw) {
    var x = _root0311(raw);
    if (x.length > 5 && x.endsWith('ies'))
      x = '${x.substring(0, x.length - 3)}y';
    else if (x.length > 5 && x.endsWith('es'))
      x = x.substring(0, x.length - 2);
    else if (x.length > 4 && x.endsWith('s')) x = x.substring(0, x.length - 1);
    return x;
  }

  static String _semanticObjectKey0313(String object) =>
      ResearchSemantics317.concept(object);
  static String _claimSemanticKey0313(ExtractedClaim11 c) =>
      ResearchSemantics317.claimKey(c);
  static bool _objectsEquivalent0313(String a, String b) =>
      ResearchSemantics317.sameObject(a, b);
  static bool _claimEquivalent0313ToMemory(
          ExtractedClaim11 a, ResearchClaim11 b) =>
      ResearchSemantics317.equivalent(a, b);

  static bool _verificationEvidenceSupports0313(String sentence,
          {required String documentTitle,
          required String subject,
          required Set<String> subjectAliases,
          required String relation,
          required String object}) =>
      ResearchSemantics317.assess(sentence,
          subject: subject,
          rel: relation,
          object: object,
          aliases: subjectAliases,
          title: documentTitle) ==
      'support';

  static Map<String, dynamic> candidateRecord315(ExtractedClaim11 c) => {
        'subject': c.subject,
        'relation': c.relation,
        'object': c.object,
        'text': c.sentence,
        'provider': c.source.provider,
        'family': c.source.family,
        'sourceTitle': c.source.title,
        'sourceUrl': c.source.url,
        'quality': c.quality,
        'subjectSenseKey': c.subjectSenseKey,
      };

  static Map<String, dynamic> inspectionGates315(ResearchClaim11 c) => {
        'stato registrato': c.status,
        'supporti diretti': c.meta317['directSupports'] ?? 0,
        'evidenze contrarie': c.meta317['negativeSupports'] ?? 0,
        'famiglie assegnate': c.sourceFamilies.length,
        'famiglie per documentare': 1,
        'famiglie per corroborare': 2,
        'utilizzabile con fonte': c.meta317['usable'] == true,
        'nota':
            'Una fonte pertinente basta per documentare, non per certificare. Ripetizioni e geometria non aumentano la validità.',
        ...c.meta317,
      };
  static Map<String, dynamic> verificationDiagnostics315(String sentence,
          {required String documentTitle,
          required String subject,
          required Set<String> subjectAliases,
          required String relation,
          required String object}) =>
      {
        'text': sentence,
        'esito': ResearchSemantics317.assess(sentence,
            subject: subject,
            rel: relation,
            object: object,
            aliases: subjectAliases,
            title: documentTitle),
        'nota':
            'Verifica direzionale conservativa. Sintassi non riconosciuta = non interpretabile, non prova.'
      };

  static bool _suspiciousKnowledge12(
      String subject, String relation, String object) {
    final text = _n11('$subject $relation $object');
    if (_metadataNoise12(text)) return true;
    if (RegExp(r'\bthe\b|\busing\b|\bsomething\b|\bfilm del 2025\b')
        .hasMatch(text)) return true;
    final o = _n11(object).trim();
    final parts = o.split(' ').where((x) => x.isNotEmpty).toList();
    if (parts.isNotEmpty &&
        {
          'e',
          'ed',
          'di',
          'del',
          'della',
          'dei',
          'degli',
          'delle',
          'da',
          'con',
          'per',
          'and',
          'of',
          'to',
          'with'
        }.contains(parts.last)) return true;
    return false;
  }

  static List<String> _sentences(String text) => text
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((e) => e.trim())
      .where((e) => e.length >= 8)
      .toList();

  static String _cleanObject(String raw) {
    var x = raw
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    for (final breaker in [
      RegExp(
          r'\s+(?:che|dove|quando|mentre|poiché|perché|sebbene|il quale|la quale)\s+',
          caseSensitive: false),
      RegExp(r'\s*;\s*')
    ]) {
      final m = breaker.firstMatch(x);
      if (m != null) x = x.substring(0, m.start).trim();
    }
    x = x.replaceAll(RegExp(r'[,:;.]+$'), '').trim();
    final words = x.split(RegExp(r'\s+'));
    if (words.length > 12) x = words.take(12).join(' ');
    return x;
  }

  static bool _valid(String s, String o) =>
      o.length >= 2 &&
      o.length <= 140 &&
      _n11(s) != _n11(o) &&
      !_metadataNoise12(o) &&
      !RegExp(r'^(questo|questa|esso|essa|lui|lei)$', caseSensitive: false)
          .hasMatch(o);
  static bool _passageRelevant(String topic, String sentence) =>
      _n11(sentence).contains(_n11(topic)) || sentence.length > 45;
  static String _key(String s, String r, String o) =>
      '${_n11(s)}|${_n11(r)}|${_n11(o)}';
  static String _claimKey028(ExtractedClaim11 c) =>
      '${_key(c.subject, c.relation, c.object)}|${_n11(c.subjectSenseKey ?? '')}';

  static String _claimEvidenceKey0311(ExtractedClaim11 c) {
    final sourceKey = c.source.url.trim().isNotEmpty
        ? c.source.url.trim().toLowerCase()
        : '${_n11(c.source.provider)}|${_n11(c.source.title)}|${c.source.text.hashCode}';
    return '${ResearchSemantics317.claimKey(c)}|$sourceKey|${c.meta317['statementId'] ?? ''}|${c.meta317['polarity'] ?? 1}|${ResearchSemantics317.norm(c.sentence)}';
  }

  // Dedupe repeated extraction inside ONE document, never across documents.
  // Otherwise two independent sources saying the same thing collapse to one
  // candidate before integrate() ever gets a chance to count two families.
  static List<ExtractedClaim11> _dedupeClaims(List<ExtractedClaim11> input) {
    final seen = <String>{};
    return input.where((c) => seen.add(_claimEvidenceKey0311(c))).toList();
  }

  static List<ExtractedClaim11> dedupeClaimsForTest0311(
          List<ExtractedClaim11> input) =>
      _dedupeClaims(input);

  static String _root0311(String raw) => ResearchSemantics317.word(_n11(raw));

  static Set<String> _contentRoots0311(String text) {
    const stop = <String>{
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
      'dello',
      'della',
      'dei',
      'degli',
      'delle',
      'dell',
      'a',
      'al',
      'alla',
      'in',
      'nel',
      'nella',
      'con',
      'per',
      'da',
      'the',
      'an',
      'of',
      'to',
      'and',
      'or',
      'is',
      'are',
      'was',
      'were',
      'be',
      'being',
      'as'
    };
    final out = <String>{};
    for (final t in _n11(text).split(RegExp(r'\s+'))) {
      if (t.length < 3 || stop.contains(t)) continue;
      final r = _root0311(t);
      if (r.length >= 3) out.add(r);
    }
    return out;
  }

  static bool _rootCompatible0311(String a, String b) => a == b;

  static bool _mentions0311(String sentence, String phrase,
      {double ratio = 0.60}) {
    final need = _contentRoots0311(phrase);
    if (need.isEmpty) return false;
    final have = _contentRoots0311(sentence);
    var hits = 0;
    for (final n in need) {
      if (have.any((h) => _rootCompatible0311(h, n))) hits++;
    }
    return hits / max(1, need.length) >= ratio;
  }

  static bool _relationCue0311(String sentence, String relation) {
    final s = ' ${_n11(sentence)} ';
    switch (_n11(relation)) {
      case 'tipo di':
        return RegExp(r'\b(?:è|sono|is|are|type|class|category|classified)\b',
                caseSensitive: false)
            .hasMatch(s);
      case 'parte di':
        return s.contains(' parte di ') ||
            s.contains(' part of ') ||
            s.contains(' component of ') ||
            s.contains(' componente di ');
      case 'ha':
      case 'ha parte':
        return RegExp(r'\b(?:ha|hanno|has|have|contains|contiene|comprende)\b',
                caseSensitive: false)
            .hasMatch(s);
      case 'serve per':
        return s.contains(' serve per ') ||
            s.contains(' used for ') ||
            s.contains(' function ') ||
            s.contains(' funzione ');
      default:
        final roots = _contentRoots0311(relation);
        if (roots.isEmpty) return true;
        final have = _contentRoots0311(sentence);
        return roots.any((r) =>
            have.any((h) => h == r || h.startsWith(r) || r.startsWith(h)));
    }
  }

  static bool _verificationSentenceSupports031(String sentence,
          {required String subject,
          required String relation,
          required String object}) =>
      ResearchSemantics317.assess(sentence,
          subject: subject, rel: relation, object: object) ==
      'support';

  static bool verificationSentenceSupportsForTest0311(
    String sentence, {
    required String subject,
    required String relation,
    required String object,
  }) =>
      _verificationSentenceSupports031(sentence,
          subject: subject, relation: relation, object: object);

  static bool _functionalConflict(PlasticLanguageBrain04 brain, String subject,
      String relation, String object) {
    const functional = {'capitale di', 'formula', 'simbolo', 'paese'};
    if (!functional.contains(_n11(relation))) return false;
    final sid = brain.entityIdForLabel06(subject);
    if (sid == null) return false;
    for (final f in brain.cognitiveFacts06())
      if (f.subjectId == sid &&
          _n11(f.relation) == _n11(relation) &&
          _n11(f.object) != _n11(object) &&
          f.confidence >= 0.55) return true;
    return false;
  }

  static String _sentence(ResearchClaim11 c) {
    switch (_n11(c.relation)) {
      case 'tipo di':
        return '${c.subject} è un ${c.object}.';
      case 'parte di':
        return '${c.subject} fa parte di ${c.object}.';
      case 'ha':
        return '${c.subject} ha ${c.object}.';
      case 'serve per':
        return '${c.subject} serve per ${c.object}.';
      case 'usa':
        return '${c.subject} usa ${c.object}.';
      case 'vive in':
        return '${c.subject} vive in ${c.object}.';
      case 'si trova in':
        return '${c.subject} si trova in ${c.object}.';
      default:
        return '${c.subject} ${c.relation} ${c.object}.';
    }
  }
}
