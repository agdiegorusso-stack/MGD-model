import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'web_knowledge_explorer_v11.dart';

/// Persistent research frontier. Reading coverage is never a mastery score.
class StudyGoal426 {
  static const key = 'studyGoal426';
  static String norm(String s) => s.toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9àèéìòù ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ').trim();

  static String? command(String text) {
    final match = RegExp(
      r'^\s*(?:studiami|studia)\s+(?:(?:tutto\s+)?(?:ciò\s+|quello\s+)?che\s+riguarda\s+)?(.+?)\s*[.!]?\s*$',
      caseSensitive: false).firstMatch(text);
    return match?.group(1)?.trim();
  }

  static Map<String, dynamic>? state(ResearchMemory11 memory) {
    final raw = memory.state317[key];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  static void start(ResearchMemory11 memory, String topic,
      {DateTime? now}) {
    topic = topic.trim();
    if (topic.isEmpty || topic.length > 240) {
      throw ArgumentError('Inserisci un obiettivo tra 1 e 240 caratteri.');
    }
    final t = now ?? DateTime.now();
    final n = norm(topic);
    final facets = n.contains('cellul')
        ? ['struttura e tipi cellulari', 'membrane e trasporto',
           'organelli', 'metabolismo ed energia', 'genetica ed espressione',
           'ciclo cellulare', 'segnalazione', 'differenziamento',
           'evoluzione cellulare', 'domande aperte']
        : n.contains('microrgan') || n.contains('microbiolog')
        ? ['classificazione', 'struttura cellulare', 'metabolismo',
           'genetica', 'ecologia', 'microbioma', 'evoluzione',
           'interazioni con gli ospiti', 'biodiversità',
           'domande aperte']
        : ['definizioni', 'classificazione', 'struttura',
           'meccanismi', 'relazioni', 'evoluzione storica',
           'evidenze scientifiche', 'domande aperte'];
    // Preserve old goals as explicit history, without discarding knowledge.
    final old = state(memory);
    if (old != null) {
      final history = List<dynamic>.from(
          memory.state317['studyGoalHistory426'] as List? ?? []);
      history.add(old);
      memory.state317['studyGoalHistory426'] = history;
    }
    memory.state317[key] = {
      'id': t.microsecondsSinceEpoch.toString(),
      'topic': topic, 'paused': false,
      'createdAt': t.toIso8601String(), 'lastError': null,
      'items': facets.map((f) => <String, dynamic>{
        'label': f, 'attempts': 0, 'failures': 0,
        'documents': 0, 'novel': 0, 'families': <String>[],
        'hashes': <String>[], 'nextAt': '',
      }).toList(),
    };
  }

  static void pause(ResearchMemory11 memory, bool paused) {
    final g = state(memory);
    if (g == null) return;
    g['paused'] = paused;
    memory.state317[key] = g;
  }

  static List<Map<String, dynamic>> items(Map<String, dynamic> g) =>
      (g['items'] as List).map((x) => Map<String, dynamic>.from(x as Map))
          .toList();

  static int count(Map<String, dynamic> x, String key) =>
      (x[key] as num?)?.toInt() ?? 0;

  /// Grow the plan from relevant extracted concepts, with source provenance.
  /// These are research candidates, not accepted facts or proof of mastery.
  static void expand(ResearchMemory11 memory, String goalId,
      ResearchDraft11 draft) {
    final g = state(memory);
    if (g == null || g['id'] != goalId) return;
    final all = items(g);
    final seen = all.map((i) => norm('${i['label']}')).toSet();
    final roots = norm('${g['topic']}').split(' ')
        .where((s) => s.length >= 5)
        .map((s) => s.length > 6 ? s.substring(0, 6) : s).toList();
    var added = 0;
    for (final claim in draft.claims) {
      if (added >= 12) break; // Per-cycle work budget, not a knowledge ceiling.
      final title = norm(claim.source.title);
      final sentence = norm(claim.sentence);
      if (claim.quality < .7 || claim.source.trust < .6 ||
          !roots.any((r) => title.contains(r) || sentence.contains(r))) continue;
      final subject = claim.subject.trim();
      final n = norm(subject);
      if (subject.length < 4 || subject.length > 80 || n == norm('${g['topic']}') ||
          !seen.add(n)) continue;
      all.add({
        'label': subject, 'attempts': 0, 'failures': 0,
        'documents': 0, 'novel': 0, 'families': <String>[],
        'nextAt': '', 'parentQuery': draft.goal.query,
        'discoveredFrom': claim.source.url,
      });
      added++;
    }
    g['items'] = all;
    memory.state317[key] = g;
  }

  static ResearchGoal11? next(ResearchMemory11 memory, {DateTime? now}) {
    final g = state(memory);
    if (g == null || g['paused'] == true || !memory.enabled) return null;
    final t = now ?? DateTime.now();
    final ready = items(g).where((i) {
      final due = DateTime.tryParse('${i['nextAt']}');
      return due == null || !due.isAfter(t);
    }).toList()
      ..sort((a, b) {
        final byAttempts = count(a, 'attempts').compareTo(count(b, 'attempts'));
        return byAttempts != 0 ? byAttempts :
            '${a['label']}'.compareTo('${b['label']}');
      });
    for (final item in ready) {
      final query = '${g['topic']} ${item['label']}';
      if (!memory.canResearch(query, now: t)) continue;
      return ResearchGoal11(query: query, topic: query,
          reason: 'Obiettivo persistente: ${g['topic']}',
          value: 1, contextTerms: ['${g['topic']}', '${item['label']}']);
    }
    return null;
  }

  static void record(ResearchMemory11 memory, String goalId,
      ResearchGoal11 query, List<WebDocument11> documents,
      {String? error, DateTime? now}) {
    final g = state(memory);
    if (g == null || g['id'] != goalId) return;
    final all = items(g);
    final index = all.indexWhere(
        (i) => '${g['topic']} ${i['label']}' == query.query);
    if (index < 0) return;
    final i = all[index];
    final t = now ?? DateTime.now();
    i['attempts'] = count(i, 'attempts') + 1;
    // A source identifier alone is not novelty; changed text is.
    final hashes = Set<String>.from(g['hashes'] as List? ?? []);
    final families = Set<String>.from(i['families'] as List? ?? []);
    var novel = 0;
    var readable = 0;
    for (final doc in documents) {
      if (doc.text.trim().length < 80) continue;
      readable++;
      final hash = sha256.convert(utf8.encode(
          doc.text.replaceAll(RegExp(r'\s+'), ' ').trim())).toString();
      if (hashes.add(hash)) novel++;
      if (doc.family.isNotEmpty) families.add(doc.family);
    }
    final failed = error != null || readable == 0;
    i['documents'] = count(i, 'documents') + readable;
    i['novel'] = count(i, 'novel') + novel;
    g['hashes'] = hashes.toList();
    i['families'] = families.toList();
    i['failures'] = failed ? count(i, 'failures') + 1 : 0;
    i['lastAt'] = t.toIso8601String();
    i['lastError'] = error ?? (readable == 0 ? 'Nessun testo leggibile' : null);
    // Retryable waiting is not completion. No hard cap on study cycles.
    final hours = failed
        ? (4 * (1 << count(i, 'failures').clamp(0, 4).toInt()))
        : novel == 0 ? 24 : 4;
    i['nextAt'] = t.add(Duration(hours: hours)).toIso8601String();
    g['items'] = all;
    g['lastError'] = i['lastError'];
    memory.state317[key] = g;
  }

  static String summary(ResearchMemory11 memory) {
    final g = state(memory);
    if (g == null) return 'Nessun obiettivo di studio.';
    final all = items(g);
    final read = all.where((i) => count(i, 'documents') > 0).length;
    return '${g['topic']} — ${g['paused'] == true ? 'in pausa' : 'attivo'}\n'
        '$read/${all.length} aree con letture; '
        'comprensione ancora da verificare.';
  }
}
