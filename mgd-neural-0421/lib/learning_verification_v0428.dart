import 'dart:convert';
import 'dart:math';

import 'cognitive_core_v0400.dart';
import 'knowledge_chat_v0423.dart';
import 'plastic_language_brain_v04.dart';
import 'reasoning_v0321.dart';
import 'rule_reasoning_v0429.dart';
import 'reading_query_v0430.dart';
import 'relational_memory_v0324.dart';
import 'study_goal_v0426.dart';
import 'web_knowledge_explorer_v11.dart';

/// These two retrieval paths are also called by the live chat. Assessment
/// questions never enter an observation/learning path.
class MemoryQuery428 {
  static String? map(PlasticLanguageBrain04 brain, ResearchMemory11 memory,
          String prompt) =>
      RelationalMemory324.answerIfKnown(memory, prompt) ??
      KnowledgeChat423.answer(brain, memory, prompt);

  static String? sourced(ResearchMemory11 memory, String prompt,
          {String? Function(String, String, String)? realize, bool readOnly = false}) =>
      RelationalMemory324.answerIfKnown(memory, prompt) ??
      Reasoning321.answer(prompt, memory) ??
      ResearchSemantics317.answer(prompt, memory, realize: realize) ??
      SourceMemory323.answer(prompt, memory, recordDiagnostics: !readOnly);

  static Future<VerificationAnswer428> answer(PlasticLanguageBrain04 brain,
      ResearchMemory11 memory, String prompt, CognitiveCore400 core) async {
    final logic = RuleReasoning429.answer(memory, prompt);
    if (logic != null) return VerificationAnswer428(logic.text,
        logic.truth == 'unknown' || logic.truth == 'conflict' ? 'astensione' : 'inferenza',
        proof: logic.proof?.toJson());
    final reading = ReadingQuery430.answer(memory, prompt);
    if (reading != null) return VerificationAnswer428(reading.text, 'letture', proof: reading.proof);
    final mapped = map(brain, memory, prompt);
    if (mapped != null) return VerificationAnswer428(mapped, 'relazioni');
    final sourcedText = sourced(memory, prompt, readOnly: true);
    if (sourcedText != null) {
      return VerificationAnswer428(sourcedText,
          sourcedText.startsWith('Passaggi pertinenti') ? 'passaggi' : 'fonti');
    }
    final cognitive = await core.answer(prompt);
    if (cognitive == null) {
      return const VerificationAnswer428('Non determinabile dalle informazioni disponibili.', 'astensione');
    }
    return VerificationAnswer428(cognitive,
        cognitive.startsWith('Le associazioni') ? 'associazioni' : 'cognitivo');
  }
}

class VerificationAnswer428 {
  final String text, route;
  final Map<String, dynamic>? proof;
  const VerificationAnswer428(this.text, this.route, {this.proof});
  Map<String, dynamic> toJson() => {'text': text, 'route': route,
    if (proof != null) 'proof': proof};
}

/// The answer key belongs to the examiner, never to the reader or responder.
/// A query-only interface receives just a question, not this object.
class VerificationCase428 {
  final String id, capability, prompt, expected, subject, relation, object;
  final List<Map<String, String>> sources;
  final String? claimKey;
  final Map<String, String> names;
  final List<Map<String, String>> acceptable;
  final String? expectedAtom;
  const VerificationCase428({required this.id, required this.capability,
    required this.prompt, required this.expected, this.subject = '',
    this.relation = '', this.object = '', this.sources = const [], this.claimKey,
    this.names = const {}, this.acceptable = const [], this.expectedAtom});
}

class VerificationWorld428 {
  final WebDocument11 document;
  final List<VerificationCase428> cases;
  const VerificationWorld428(this.document, this.cases);
}

class VerificationCancelled428 implements Exception {}

typedef VerificationQuery428 = Future<VerificationAnswer428> Function(String);

class LearningVerification428 {
  static const key = 'learningVerification428';
  static const capabilities = {
    'recall': 'Recupero dei fatti',
    'paraphrase': 'Domande riformulate',
    'composition': 'Collegamento di informazioni',
    'application': 'Applicazione a casi nuovi',
    'conditions': 'Cambio delle condizioni',
    'unknown': 'Informazioni mancanti',
    'conflict': 'Premesse in conflitto',
  };

  static String norm(String text) => ResearchSemantics317.norm(text)
      .replaceAll('ì', 'i').replaceAll('é', 'e').replaceAll('è', 'e')
      .replaceAll(RegExp(r'[^a-z0-9àòù]+'), ' ').trim();

  /// New identifiers and resource polarity on every run. The biological names
  /// are labels in a fictional deterministic model, not biological claims.
  static List<VerificationWorld428> worlds(int seed) {
    final random = Random(seed);
    final nonce = seed.toRadixString(36);
    final compositionAnswers = [true, true, false, false]..shuffle(random);
    final applicationAnswers = [true, true, false, false]..shuffle(random);
    return List.generate(4, (index) {
      final cell = 'cel$nonce${index}a', other = 'cel$nonce${index}b';
      final channel = 'can$nonce$index', substance = 'sos$nonce$index';
      final resource = 'ris$nonce$index';
      final activeWhenPresent = random.nextBool();
      final trigger = activeWhenPresent ? 'presente' : 'assente';
      final opposite = activeWhenPresent ? 'assente' : 'presente';
      final compositionCondition = compositionAnswers[index] ? trigger : opposite;
      final applicationCondition = applicationAnswers[index] ? trigger : opposite;
      final text = '$cell contiene $channel. '
          'In questo mondo simulato, $channel fa entrare $substance in ogni cellula '
          'che lo contiene se e solo se $resource è $trigger. '
          'Ogni cellula di questo modello diventa luminosa se e solo se '
          '$substance entra al suo interno. '
          'Tutte le cellule di questo modello hanno soltanto questo ingresso.';
      final doc = WebDocument11(provider: 'Mondo simulato',
          family: 'locale:verifica', title: 'Mondo ${index + 1}',
          url: 'local://verification/$nonce/$index', text: text, trust: .8);
      final evidence = [{'title': doc.title, 'url': doc.url, 'text': text}];
      final names = {cell: 'Cellula ${index + 1}A', other: 'Cellula ${index + 1}B',
        channel: 'Canale ${index + 1}', substance: 'Sostanza ${index + 1}', resource: 'Risorsa ${index + 1}'};
      VerificationCase428 question(String type, String prompt, String expected,
          {String relation = '', String object = ''}) => VerificationCase428(
          id: '$index-$type', capability: type.split('-').first,
          prompt: prompt, expected: expected, subject: cell,
          relation: relation, object: object, sources: evidence, names: names);
      return VerificationWorld428(doc, [
        question('recall', 'Che cosa contiene $cell?', channel,
            relation: 'contiene', object: channel),
        question('paraphrase', 'Quale canale è presente in $cell?', channel,
            relation: 'contiene', object: channel),
        question('composition', 'Nel modello, $cell contiene $channel e '
            '$resource è $compositionCondition. $cell diventa luminosa?',
            compositionAnswers[index] ? 'si' : 'no'),
        question('application', 'Una cellula nuova, $other, contiene $channel. '
            '$resource è $applicationCondition. $substance entra in $other?',
            applicationAnswers[index] ? 'si' : 'no'),
        question('conditions-positive', '$cell contiene $channel. '
            '$resource è presente. $substance entra in $cell?',
            activeWhenPresent ? 'si' : 'no'),
        question('conditions-negative', '$cell contiene $channel. '
            '$resource è assente. $substance entra in $cell?',
            activeWhenPresent ? 'no' : 'si'),
        question('unknown', 'Quanto pesa $cell?', 'unknown'),
      ]);
    });
  }

  /// Source recall has an extracted proposition as its reference. It measures
  /// consistency with retained evidence, not the scientific truth of a source.
  static List<VerificationCase428> sourceCases(ResearchMemory11 memory, int seed) {
    final goal = StudyGoal426.state(memory);
    final subjects = goal == null ? <String>[] : [
      '${goal['topic']}',
      ...StudyGoal426.items(goal).map((i) => '${i['lookup'] ?? i['label']}'),
    ];
    final eligible = memory.claims.values.where((c) =>
      !c.conflict && {'documentata', 'accettata'}.contains(c.status) &&
      c.evidenceIds.isNotEmpty && c.meta317['usable'] == true &&
      c.meta317['negative'] != true &&
      (c.meta317['qualifiers'] is! Map || (c.meta317['qualifiers'] as Map).isEmpty) &&
      (subjects.isEmpty || subjects.any((s) =>
          ResearchSemantics317.sameSubject(s, c.subject)))).toList();
    eligible.shuffle(Random(seed));
    final out = <VerificationCase428>[];
    for (final c in eligible.take(4)) {
      final evidence = memory.evidence.where((e) => c.evidenceIds.contains(e.id))
          .take(3).map((e) => {'title': e.sourceTitle, 'url': e.sourceUrl,
              'text': e.excerpt}).toList();
      if (evidence.isEmpty) continue;
      for (final type in ['recall', 'paraphrase']) {
        out.add(VerificationCase428(id: '${c.key}-$type', capability: type,
          prompt: type == 'recall' ? 'Che cosa sai di ${c.subject}?'
              : 'Quali elementi sono collegati a ${c.subject} dalla relazione ${c.relation}?',
          expected: '${c.subject} — ${c.relation} → ${c.object}',
          subject: c.subject, relation: c.relation, object: c.object,
          sources: evidence, claimKey: c.key,
          acceptable: type == 'recall' ? eligible.where((other) =>
              ReadingQuery430.key(other.subject) == ReadingQuery430.key(c.subject))
              .map((other) => {'subject': other.subject, 'relation': other.relation,
                'object': other.object}).toList() : const []));
      }
    }
    return out;
  }

  /// Strict grading: a source quote/co-occurrence list is not an application.
  /// The word "no" in an unrelated disclaimer is never a negative prediction.
  static ({bool passed, String reason}) grade(
      VerificationCase428 question, VerificationAnswer428 answer) {
    final clean = norm(answer.text);
    if (question.expected == 'conflict') {
      final passed = clean.startsWith('non determinabile') &&
          answer.text.toUpperCase().contains('IN CONFLITTO');
      return (passed: passed, reason: passed ? 'Ha riconosciuto le premesse incompatibili.'
          : 'Non ha dichiarato il conflitto tra le premesse.');
    }
    if (answer.text.toUpperCase().contains('IN CONFLITTO')) {
      return (passed: false, reason: 'La risposta segnala un conflitto: non è una conclusione determinata.');
    }
    if (question.expected == 'unknown') {
      final abstains = answer.route == 'astensione' ||
          RegExp(r'^(non (determinabile|lo so|posso (determinar|stabilir))|'
              r'informazioni insufficienti|il testo non (dice|specifica))').hasMatch(clean);
      return (passed: abstains, reason: abstains
          ? 'Ha riconosciuto che manca l’informazione.'
          : 'Non ha dichiarato in modo esplicito che l’informazione manca.');
    }
    if (question.expectedAtom != null) {
      final passed = answer.proof?['conclusion'] == question.expectedAtom &&
          answer.proof?['ruleId'] != null &&
          (answer.proof?['premises'] as List? ?? []).isNotEmpty;
      return (passed: passed, reason: passed ? 'La conclusione ha passaggi verificabili nel testo.'
          : 'Non ha ricavato la conclusione richiesta con una catena di premesse.');
    }
    if (question.object.isNotEmpty) {
      if (question.acceptable.isNotEmpty && answer.proof?['kind'] == 'retrieval') {
        final assertions = (answer.proof?['claims'] as List? ?? []).whereType<Map>().toList();
        final passed = assertions.isNotEmpty && assertions.every((a) =>
            question.acceptable.any((expected) =>
              ResearchSemantics317.sameSubject('${a['subject']}', expected['subject']!) &&
              ResearchSemantics317.relation('${a['relation']}') == ResearchSemantics317.relation(expected['relation']!) &&
              ResearchSemantics317.sameObject('${a['object']}', expected['object']!)) &&
            '${a['url'] ?? ''}'.isNotEmpty);
        return (passed: passed, reason: passed
            ? 'Ha recuperato fatti pertinenti con la fonte. Questa prova misura il recupero.'
            : 'Almeno una delle affermazioni non corrisponde ai fatti documentati idonei.');
      }
      final exact = clean == norm(question.object);
      final triple = answer.text.split('\n').any((line) {
        final row = line.replaceFirst(RegExp(r'^\s*[•*-]\s*'), '')
            .replaceAll(RegExp(r'(insegnata|con fonte|corroborata):\s*'), '')
            .replaceFirst(RegExp(r'\.$'), '');
        final parsed = RegExp(r'^(.+?)\s*—\s*(.+?)\s*→\s*(.+)$').firstMatch(row.trim());
        return parsed != null && !norm(parsed[2]!).startsWith('non ') &&
            ResearchSemantics317.sameSubject(parsed[1]!, question.subject) &&
            ResearchSemantics317.relation(parsed[2]!) == ResearchSemantics317.relation(question.relation) &&
            ResearchSemantics317.sameObject(parsed[3]!, question.object);
      });
      final passed = answer.route != 'passaggi' && (exact || triple);
      return (passed: passed, reason: passed
          ? 'La risposta contiene la relazione richiesta.'
          : 'La relazione richiesta non è stata recuperata in modo determinato.');
    }
    if (answer.route == 'passaggi' || answer.route == 'associazioni' ||
        answer.text.contains('→') || answer.text.contains('«')) {
      return (passed: false, reason: 'Ha recuperato testo o associazioni, senza formulare la previsione richiesta.');
    }
    final decision = RegExp(r'^(si|no)(?:\s|$)').firstMatch(clean)?[1];
    final ambiguous = RegExp(r'\b(si|no)\b').allMatches(clean)
        .map((m) => m[1]).toSet().length > 1;
    final passed = !ambiguous && decision == question.expected;
    return (passed: passed, reason: passed ? 'La previsione coincide con la regola del modello.'
        : decision == null ? 'Non ha formulato una risposta determinata alla domanda.'
        : 'La previsione contraddice le condizioni del modello.');
  }

  static Future<Map<String, dynamic>> run({required String mode,
    required int seed, required VerificationQuery428 query,
    required List<VerificationCase428> cases,
    Future<void> Function()? read,
    bool Function()? cancelled,
    void Function(int done, int total, String stage)? progress,
    String? goalId, String? topic, String version = '0.42.10'}) async {
    final results = <Map<String, dynamic>>[];
    final before = <String, VerificationAnswer428>{};
    var done = 0;
    final total = cases.length * (read == null ? 1 : 2);
    void check() { if (cancelled?.call() ?? false) throw VerificationCancelled428(); }
    if (read != null) {
      for (final c in cases) {
        check();
        before[c.id] = await query(c.prompt);
        progress?.call(++done, total, 'Prima della lettura');
        await Future<void>.delayed(Duration.zero);
      }
      check();
      progress?.call(done, total, 'Lettura dei mondi simulati');
      await read();
    }
    for (final c in cases) {
      check();
      final answer = await query(c.prompt);
      final score = grade(c, answer);
      results.add({'id': c.id, 'capability': c.capability, 'prompt': c.prompt,
        'expected': c.expected, 'answer': answer.toJson(), 'passed': score.passed,
        'reason': score.reason, 'subject': c.subject, 'claimKey': c.claimKey,
        'sources': c.sources,
        if (c.names.isNotEmpty) 'names': c.names,
        if (c.expectedAtom != null) 'expectedAtom': c.expectedAtom,
        if (before.containsKey(c.id)) ...{
          'before': before[c.id]!.toJson(), 'beforePassed': grade(c, before[c.id]!).passed},
      });
      progress?.call(++done, total, read == null ? 'Verifica delle letture' : 'Dopo la lettura');
      await Future<void>.delayed(Duration.zero);
    }
    check();
    return {'schema': 1, 'mode': mode, 'seed': seed, 'version': version,
      'at': DateTime.now().toIso8601String(), 'goalId': goalId, 'topic': topic,
      'results': results, 'total': results.length,
      'passed': results.where((r) => r['passed'] == true).length,
      'beforePassed': read == null ? null
          : results.where((r) => r['beforePassed'] == true).length};
  }

  static List<Map<String, dynamic>> reports(ResearchMemory11 memory) {
    final data = memory.state317[key];
    if (data is! List) return [];
    return data.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static void store(ResearchMemory11 memory, Map<String, dynamic> report) {
    // Detach nested records before persistence; cap report history, not knowledge.
    final detached = Map<String, dynamic>.from(jsonDecode(jsonEncode(report)) as Map);
    memory.state317[key] = [detached, ...reports(memory)].take(6).toList();
  }

  static List<Map<String, dynamic>> rows(Map<String, dynamic> report) =>
      (report['results'] as List? ?? []).whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r)).toList();

  static List<String> failedSubjects(Map<String, dynamic> report) =>
      report['mode'] != 'sources' ? [] : rows(report)
          .where((r) => r['passed'] != true && r['claimKey'] != null)
          .map((r) => '${r['subject']}').where((s) => s.isNotEmpty).toSet().toList();
}
