import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'web_knowledge_explorer_v11.dart';

/// Persistent research frontier. Reading coverage is never a mastery score.
class StudyGoal426 {
  static const key = 'studyGoal426';
  static const schema = 3;
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
      'topic': topic, 'paused': false, 'schema': schema,
      'createdAt': t.toIso8601String(), 'lastError': null,
      'items': facets.map((f) => <String, dynamic>{
        'label': f, 'lookup': lookup(topic, f), 'attempts': 0, 'failures': 0,
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

  /// A plan label is not an entity name. Keep the session query separate from
  /// the actual subject whose title, redirects and evidence must be resolved.
  static String lookup(String topic, String label) {
    final n = norm(topic);
    if (n.contains('cellul')) {
      const subjects = {
        'struttura e tipi cellulari': 'Cellula',
        'membrane e trasporto': 'Membrana cellulare',
        'organelli': 'Organulo',
        'metabolismo ed energia': 'Metabolismo cellulare',
        'genetica ed espressione': 'Espressione genica',
        'ciclo cellulare': 'Ciclo cellulare',
        'segnalazione': 'Segnalazione cellulare',
        'differenziamento': 'Differenziamento cellulare',
        'evoluzione cellulare': 'Endosimbiosi',
        'domande aperte': 'Biologia cellulare',
      };
      if (subjects[label] != null) return subjects[label]!;
    } else if (n.contains('microrgan') || n.contains('microbiolog')) {
      const subjects = {
        'classificazione': 'Microrganismo',
        'struttura cellulare': 'Procarioti',
        'metabolismo': 'Metabolismo microbico',
        'genetica': 'Genetica microbica',
        'ecologia': 'Ecologia microbica',
        'microbioma': 'Microbiota',
        'evoluzione': 'Evoluzione dei microrganismi',
        'interazioni con gli ospiti': 'Simbiosi',
        'biodiversità': 'Diversità microbica',
        'domande aperte': 'Microbiologia',
      };
      if (subjects[label] != null) return subjects[label]!;
    }
    // Generic areas are questions about the root subject, not entity names.
    // Discovered subjects have an explicit lookup and bypass this function.
    return topic.replaceFirst(RegExp(
        r"^(?:(?:il|lo|la|i|gli|le|un|uno|una)\s+|l[’'])",
        caseSensitive: false), '');
  }

  static List<String> facetTerms431(String topic, String label) {
    final n = norm(topic);
    if (n.contains('cellul') || n.contains('microrgan') ||
        n.contains('microbiolog')) return const [];
    const terms = <String, List<String>>{
      'classificazione': ['classific', 'tipi', 'tipolog', 'categorie', 'modalit'],
      'struttura': ['struttur', 'component', 'composizion', 'apparat',
        'apparecch', 'dispositiv', 'costituit', 'organizz', 'configur'],
      'meccanismi': ['meccanism', 'funzion', 'princip', 'process'],
      'relazioni': ['relazion', 'interazion', 'collegament', 'associazion'],
      'evoluzione storica': ['storia', 'storic', 'evoluzion', 'svilupp', 'origine'],
      'evidenze scientifiche': ['evidenz', 'ricerca', 'ricerche', 'studi', 'speriment'],
      'domande aperte': ['limiti', 'incertezz', 'controvers', 'irrisolt', 'domande aperte'],
    };
    return terms[label] ?? const [];
  }

  static String query(Map<String, dynamic> g, Map<String, dynamic> item) =>
      '${g['topic']} ${item['label']}';

  /// Release only the empty legacy attempts delayed by the old eight-hour
  /// backoff; preserve the goal, pause setting, history and acquired memory.
  static void upgrade(ResearchMemory11 memory) {
    final g = state(memory);
    if (g == null || g['schema'] == schema) return;
    final all = items(g);
    for (final i in all) {
      i['lookup'] = i['discoveredFrom'] != null
          ? '${i['label']}' : lookup('${g['topic']}', '${i['label']}');
      if (count(i, 'documents') == 0) {
        i['nextAt'] = '';
        memory.queryLastIso.removeWhere((k, _) => norm(k) == norm(query(g, i)));
      }
    }
    g['items'] = all;
    g['schema'] = schema;
    g['lastError'] = null;
    memory.state317[key] = g;
  }

  static void retry(ResearchMemory11 memory) {
    upgrade(memory);
    final g = state(memory);
    if (g == null) return;
    final all = items(g);
    for (final i in all) {
      if (count(i, 'documents') == 0 || i['lastError'] != null) {
        i['nextAt'] = '';
        memory.queryLastIso.removeWhere((k, _) => norm(k) == norm(query(g, i)));
      }
    }
    g['items'] = all;
    memory.state317[key] = g;
  }

  /// Prioritize real subjects whose retained evidence could not be retrieved.
  /// Review changes scheduling only, never evidence counts or mastery labels.
  static void review(ResearchMemory11 memory, List<String> subjects) {
    final g = state(memory);
    if (g == null) return;
    final all = items(g);
    for (final subject in subjects) {
      final index = all.indexWhere((i) => ResearchSemantics317.sameSubject(
          '${i['lookup'] ?? i['label']}', subject));
      final item = index >= 0 ? all[index] : <String, dynamic>{
        'label': subject, 'lookup': subject, 'attempts': 0, 'failures': 0,
        'documents': 0, 'novel': 0, 'families': <String>[],
        'discoveredFrom': 'verifica delle letture',
      };
      item['review428'] = true;
      item['nextAt'] = '';
      memory.queryLastIso.removeWhere((k, _) => norm(k) == norm(query(g, item)));
      if (index < 0) all.add(item);
    }
    g['items'] = all;
    memory.state317[key] = g;
  }

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
      if (subject.length < 4 || subject.length > 80 ||
          ResearchSemantics317.sameSubject(subject, lookup('${g['topic']}', 'definizioni')) ||
          !seen.add(n)) continue;
      all.add({
        'label': subject, 'lookup': subject, 'attempts': 0, 'failures': 0,
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
    upgrade(memory);
    final g = state(memory);
    if (g == null || g['paused'] == true || !memory.enabled) return null;
    final t = now ?? DateTime.now();
    final all = items(g);
    final order = {for (var j = 0; j < all.length; j++) '${all[j]['label']}': j};
    final ready = all.where((i) {
      final due = DateTime.tryParse('${i['nextAt']}');
      return due == null || !due.isAfter(t);
    }).toList()
      ..sort((a, b) {
        final byReview = (b['review428'] == true ? 1 : 0)
            .compareTo(a['review428'] == true ? 1 : 0);
        if (byReview != 0) return byReview;
        final byAttempts = count(a, 'attempts').compareTo(count(b, 'attempts'));
        return byAttempts != 0 ? byAttempts :
            order['${a['label']}']!.compareTo(order['${b['label']}']!);
      });
    for (final item in ready) {
      final q = query(g, item);
      // The item deadline owns retry cadence, including transient failures.
      if (!memory.canResearch(q, now: t,
          repeatAfter: const Duration(seconds: 30))) continue;
      final subject = '${item['lookup'] ?? lookup('${g['topic']}', '${item['label']}')}';
      return ResearchGoal11(query: q, topic: subject,
          reason: 'Obiettivo persistente: ${g['topic']}',
          facetTerms431: item['discoveredFrom'] == null
              ? facetTerms431('${g['topic']}', '${item['label']}') : const [],
          value: 1, contextTerms: ['${g['topic']}', '${item['label']}']);
    }
    return null;
  }

  static void record(ResearchMemory11 memory, String goalId,
      ResearchGoal11 query, List<WebDocument11> documents,
      {String? error, List<Map<String, dynamic>> diagnostics = const [], DateTime? now}) {
    final g = state(memory);
    if (g == null || g['id'] != goalId) return;
    final all = items(g);
    final index = all.indexWhere((i) => StudyGoal426.query(g, i) == query.query);
    if (index < 0) return;
    final i = all[index];
    final t = now ?? DateTime.now();
    i['attempts'] = count(i, 'attempts') + 1;
    i.remove('review428');
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
    final delay = failed
        ? Duration(minutes: 1 << (count(i, 'failures') - 1).clamp(0, 5).toInt())
        : Duration(hours: novel == 0 ? 24 : 4);
    i['nextAt'] = t.add(delay).toIso8601String();
    g['items'] = all;
    g['lastError'] = i['lastError'];
    g['lastLookup'] = query.topic;
    g['lastArea'] = i['label'];
    g['lastDocuments'] = readable;
    g['lastAt'] = t.toIso8601String();
    g['diagnostics'] = diagnostics;
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
