import 'dart:convert';

import 'book_understanding_v0342.dart';
import 'canonical_memory_v0420.dart';
import 'cognitive_frame_v0420.dart' show CognitiveFrame420;
import 'competence_language_v0350.dart';
import 'narrative_memory_v0350.dart';
import 'social_memory_v0420.dart';

class CognitiveReply420 {
  final String status, text, reason;
  final List<Map<String, dynamic>> evidence;
  final int candidates, micros;
  final bool budgetReached;
  const CognitiveReply420(
    this.status,
    this.text, {
    this.reason = '',
    this.evidence = const [],
    this.candidates = 0,
    this.micros = 0,
    this.budgetReached = false,
  });
  List<String> get claimIds => evidence.map((e) => '${e['id']}').toList();
  Map<String, dynamic> toJson() => {
    'status': status,
    'text': text,
    'reason': reason,
    'evidence': evidence,
    'candidates': candidates,
    'micros': micros,
    'budgetReached': budgetReached,
  };
}

/// All production questions use this coordinator. No fluent fallback may
/// replace an unknown answer, and no generated response becomes evidence.
class CognitiveCoordinator420 {
  final CanonicalMemory420 memory;
  final SocialStore410 social;
  final TheoryOfMind410 mind;
  Future<void> _tail = Future<void>.value();
  CognitiveCoordinator420._(this.memory, this.social)
    : mind = TheoryOfMind410(social);

  static Future<CognitiveCoordinator420> create(
    CanonicalMemory420 memory,
  ) async => CognitiveCoordinator420._(
    memory,
    await SocialStore410.usingDatabase(memory.db),
  );

  Future<CognitiveReply420> process(String text, {String? scope}) {
    final result = _tail.then((_) => _process(text, scope: scope));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static bool isQuestion(String text) =>
      text.trim().endsWith('?') ||
      RegExp(
        r'^\s*(?:chi|a chi|di che|cosa|che cosa|che differenza|come|dove|quando|perch[eé]|qual[ei]?|quant[oaie]|cos[’\x27]|parlami|spiega\w*|dimmi|confronta|riassumi|riassunto|racconta|definisci|approfondisci|continua|in che senso|e quindi|ipotizza\s*:|libro\s*:)\b',
        caseSensitive: false,
      ).hasMatch(text);

  Future<CognitiveReply420> _process(String raw, {String? scope}) async {
    final text = raw.trim(), q = canon410(raw);
    if (text.isEmpty)
      return const CognitiveReply420('unknown', 'Scrivi un messaggio.');
    if (text.length > 32768)
      return const CognitiveReply420(
        'budget',
        'Questo testo supera il budget della chat. Importalo nella pagina Impara.',
        budgetReached: true,
      );
    if (RegExp(r'^(ciao|salve|buongiorno|buonasera|hey|ehi)$').hasMatch(q)) {
      return const CognitiveReply420(
        'dialogue',
        'Ciao. Puoi insegnarmi un testo, interrogare la memoria o controllare le prove delle risposte.',
      );
    }
    if (q == 'chi sei' || q == 'cosa sei') {
      return const CognitiveReply420(
        'dialogue',
        'Sono MGD Neural, un sistema sperimentale con memoria persistente e geometria adattiva. '
            'Il mio lettore usa una grammatica limitata: quando non interpreta il testo, conserva il passaggio e segnala la lacuna.',
      );
    }
    if (q == 'come stai' || q == 'cosa non sai' || q == 'cosa non capisci') {
      final stats = await memory.stats();
      return CognitiveReply420(
        'diagnostic',
        'La memoria contiene ${stats['claims']} relazioni e ${stats['unparsed']} passaggi senza relazioni estratte. '
            'Questi conteggi descrivono lo stato dell’archivio; la comprensione si verifica con domande nuove.',
      );
    }
    final alias = RegExp(
      r'^alias\s*:\s*(.+?)\s*=\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (alias != null) {
      await memory.alias(alias[1]!, alias[2]!);
      return const CognitiveReply420('learned', 'Alias collegato al concetto.');
    }
    if (RegExp(r'^correggi\s*:', caseSensitive: false).hasMatch(text)) {
      return const CognitiveReply420(
        'unknown',
        'Apri le evidenze della risposta, scegli la relazione da correggere e scrivi la nuova frase completa. '
            'La correzione conserva la fonte e revoca soltanto la relazione selezionata.',
      );
    }
    if (!isQuestion(text)) return _experience(text);
    var question = text.replaceFirst(
      RegExp(r'^libro\s*:\s*', caseSensitive: false),
      '',
    );
    var assumptions = '';
    final hypothesis = RegExp(
      r'^ipotizza\s*:\s*(.+?)\s*\|\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(question);
    if (hypothesis != null) {
      assumptions = hypothesis[1]!;
      question = hypothesis[2]!;
    }
    if (RegExp(
      r'^(spiegami meglio|approfondisci|continua|perché|perche|e quindi|in che senso)[?!.]*$',
      caseSensitive: false,
    ).hasMatch(question)) {
      final focus = await memory.meta('focus');
      if (focus == null || focus.isEmpty)
        return const CognitiveReply420(
          'unknown',
          'Indica il concetto da approfondire.',
        );
      question = 'Cosa sai di $focus?';
    }
    // A social query has a distinct epistemic type; it cannot answer a factual query.
    final socialReply = await mind.answer(question);
    if (socialReply != null)
      return CognitiveReply420(
        'belief',
        socialReply,
        reason:
            'Modello di credenze di primo ordine, con osservatori assunti compresenti nel dialogo. Non verifica lo stato del mondo.',
      );
    return answer(question, scope: scope, assumptions: assumptions);
  }

  Future<CognitiveReply420> _experience(String text) async {
    final q = canon410(text);
    final desire = RegExp(
      r'^(.+?)\s+(?:vuole|desidera|spera di)\s+(.+)$',
    ).firstMatch(q);
    if (desire != null) {
      await social.putGoal(
        desire[1]!,
        desire[2]!,
        source: 'Attribuzione esplicita dell’utente',
      );
      return const CognitiveReply420(
        'belief',
        'Obiettivo attribuito conservato separatamente dai fatti.',
      );
    }
    final attributed = RegExp(
      r'^(.+?)\s+(?:pensa|crede|ritiene|sa)\s+che\s+(.+)$',
    ).firstMatch(q);
    if (attributed != null) {
      final events = NarrativeCompiler350()
          .compile(attributed[2]!, unitOrdinal: 0)
          .events;
      if (events.length != 1)
        return const CognitiveReply420(
          'unknown',
          'Non riesco a interpretare con certezza il contenuto della credenza. Non l’ho trasformato in un fatto.',
        );
      final e = events.single;
      await social.putBelief(
        MentalBelief410(
          holder: attributed[1]!,
          subject: e.subject,
          predicate: e.location.isNotEmpty ? 'luogo' : e.predicate,
          object: e.location.isNotEmpty ? '' : e.object,
          location: e.location,
          negative: e.negative,
          source: 'Attribuzione utente: $text',
        ),
      );
      return const CognitiveReply420(
        'belief',
        'Credenza attribuita salvata. Il suo contenuto non è stato aggiunto ai fatti.',
      );
    }
    final presence = RegExp(
      r'^([a-zàèéìòù]+)\s+(esce|entra|torna|parte)$',
    ).firstMatch(q);
    if (presence != null) {
      await social.setPresence(
        presence[1]!,
        {'entra', 'torna'}.contains(presence[2]),
      );
      return const CognitiveReply420(
        'belief',
        'Presenza aggiornata nel modello degli osservatori.',
      );
    }
    final learned = await memory.ingestText(
      text,
      title: 'Dialogo utente',
      sourceId: 'chat:utente',
      kind: 'chat',
      continueSource: true,
    );
    final events = (learned['events'] as List? ?? []).map(
      (e) => Event350.fromJson(e as Map),
    );
    // Only explicitly parsed events enter the social model. The old suffix-based
    // frame guesser is not called by the production pipeline.
    for (final e in events) {
      if (e.kind == 'cause' || e.universal || e.epistemic != 'asserted')
        continue;
      final f = CognitiveFrame420(
        subject: e.subject,
        predicate: e.predicate,
        object: e.object,
        location: e.location,
        negative: e.negative,
        concepts: [e.subject, e.object],
      );
      // Presence is explicit for named actors; articles and common nouns do
      // not turn objects (e.g. "la capsula") into social observers.
      final named =
          e.subject.isNotEmpty &&
          !RegExp(
            r'^(?:il|la|lo|un|una|uno|l\x27)\b',
          ).hasMatch(e.subjectSurface) &&
          RegExp(
            '(?<![A-Za-zÀ-ù])${RegExp.escape(pretty350(e.subject))}(?![A-Za-zÀ-ù])',
          ).hasMatch(text);
      if (named) await mind.experience(e.describe(), f);
      if (e.subject.isNotEmpty) await memory.setMeta('focus', e.subject);
    }
    return CognitiveReply420(
      'learned',
      '${learned['units']} blocchi salvati; ${learned['claims']} relazioni interpretate. '
          '${learned['claims'] == 0 ? 'Il testo resta consultabile, ma non ho estratto fatti affidabili.' : 'Puoi verificarle con una domanda o dalla pagina Memoria.'}',
    );
  }

  Future<CognitiveReply420> answer(
    String input, {
    String? scope,
    String assumptions = '',
  }) async {
    final clock = Stopwatch()..start();
    if (input.length > 4096 || assumptions.length > 8192)
      return const CognitiveReply420(
        'budget',
        'Domanda o ipotesi oltre il budget di lavoro.',
        budgetReached: true,
      );
    var question = input;
    for (final term in BookEngine342.terms(input).toSet()) {
      final label = await memory.resolve(term);
      if (label != null && label != term)
        question = question.replaceAll(
          RegExp(
            '(?<![a-zàèéìòù])${RegExp.escape(term)}(?![a-zàèéìòù])',
            caseSensitive: false,
          ),
          label,
        );
    }
    const budget = 192;
    final q = canon410(question);
    final global = RegExp(
      r'\b(protagonista|personaggio principale|personaggio centrale|personaggi principali|personaggi centrali)\b',
    ).hasMatch(q);
    if (global && scope == null)
      return const CognitiveReply420(
        'unknown',
        'Seleziona la fonte per identificare i personaggi o il protagonista.',
      );
    if (global) return _story(question, scope!, clock);
    final batch = await memory.candidates(
      question,
      assumptions: assumptions,
      scope: scope,
      budget: budget,
    );
    final rows = batch.rows;
    if (batch.truncated)
      return CognitiveReply420(
        'budget',
        'Il recupero ha raggiunto il budget. Seleziona una fonte o rendi la domanda più precisa.',
        candidates: rows.length,
        micros: clock.elapsedMicroseconds,
        budgetReached: true,
      );
    final events = rows
        .map(
          (r) => Event350.fromJson(jsonDecode(r['payload'] as String) as Map),
        )
        .toList();
    final provenance = <String, Map<String, dynamic>>{
      for (final e in events)
        e.id: {
          'id': e.id,
          'text': e.describe(),
          'title': 'Memoria strutturata',
          'url': 'memory://claim/${e.id}',
        },
    };
    final facts = events
        .where(
          (e) =>
              e.kind != 'cause' &&
              e.epistemic == 'asserted' &&
              (e.object.isNotEmpty || e.predicate == 'luogo'),
        )
        .map(
          (e) => BookFact342(
            e.subject,
            BookEngine342.verbs[e.surface] ?? e.predicate,
            e.predicate == 'luogo' ? e.location : e.object,
            e.negative,
            e.universal,
            [e.id],
          ),
        )
        .toList();
    final factEngine = BookEngine342.fromKnowledge(facts, provenance);
    final candidates = <Map<String, dynamic>>[];
    final fact = factEngine.answer(question, assumptions: assumptions).toJson();
    if (fact['budgetReached'] == true)
      return CognitiveReply420(
        'budget',
        'La ricerca delle premesse ha raggiunto il budget operativo.',
        candidates: rows.length,
        micros: clock.elapsedMicroseconds,
        budgetReached: true,
      );
    final temporalLocation = RegExp(
      r'^(?:dove|in quale luogo)\s+(?:si trova|si trovava|è|era|sta)\s+',
    ).hasMatch(q);
    if (!temporalLocation &&
        {'direct', 'deduction', 'conflict'}.contains(fact['status']))
      candidates.add(fact);
    final byScope = <String, List<Event350>>{};
    for (var i = 0; i < events.length; i++) {
      byScope.putIfAbsent('${rows[i]['source']}', () => []).add(events[i]);
    }
    // Narrative order never mixes unrelated books. Timeless logical proofs may
    // combine sources, but always retain every proof identifier.
    for (final entry in byScope.entries) {
      final result = ClosedBookEngine350(entry.value, {
        'id': entry.key,
      }).answer(question, assumptions: assumptions);
      if ({'direct', 'deduction', 'conflict'}.contains(result['status']) &&
          assumptions.isEmpty)
        candidates.add(result);
    }
    final color = RegExp(r'^di che colore (?:è|era)\s+(.+)$').firstMatch(q);
    final number = RegExp(
      r'^quante?\s+(.+?)\s+(?:rimasero|rimangono|restano)\s+(?:nel|nella|in)\s+(.+)$',
    ).firstMatch(q);
    if (color != null || number != null) {
      final name = canonical420(color?[1] ?? number![2]!);
      final target = events
          .where(
            (e) =>
                e.subject == name &&
                e.predicate == (color == null ? 'quantità_residua' : 'colore'),
          )
          .toList();
      for (final e in target) {
        if (!e.negative)
          candidates.add({
            'status': e.kind == 'calculation' ? 'deduction' : 'direct',
            'answer': color == null ? e.object.split(' ').first : e.object,
            'reason': 'Costruzione esplicita interpretata dal lettore.',
            'evidence': [e.toJson()],
          });
      }
    }
    if (RegExp(
      r'^(?:cosa sai di|che cosa sai di|parlami di|spiegami)\s+',
    ).hasMatch(q)) {
      final term = canonical420(
        q.replaceFirst(
          RegExp(r'^(?:cosa sai di|che cosa sai di|parlami di|spiegami)\s+'),
          '',
        ),
      );
      final own = events
          .where((e) => e.subject == term || e.object == term)
          .take(8)
          .toList();
      if (own.isNotEmpty)
        return _reply(
          'description',
          await _description(own),
          'Descrizione delle relazioni registrate; non definizione verificata del concetto.',
          own.map((e) => e.id),
          rows.length,
          clock,
        );
    }
    final compare = RegExp(
      r'^(?:confronta|che differenza c è tra|qual è la differenza tra)\s+(.+?)\s+(?:e|con)\s+(.+)$',
    ).firstMatch(q);
    if (compare != null) {
      final a = canonical420(compare[1]!), b = canonical420(compare[2]!);
      final ea = events
          .where((e) => e.subject == a && e.kind != 'cause')
          .toList();
      final eb = events
          .where((e) => e.subject == b && e.kind != 'cause')
          .toList();
      if (ea.isEmpty || eb.isEmpty)
        return const CognitiveReply420(
          'unknown',
          'Servono relazioni interpretate per entrambi i concetti.',
        );
      String property(Event350 e) =>
          '${e.negative ? 'non ' : ''}${e.predicate} ${e.object} ${e.location}'
              .trim();
      final pa = ea.map(property).toSet(), pb = eb.map(property).toSet();
      final common = pa.intersection(pb);
      return _reply(
        'comparison',
        'Proprietà registrate comuni: ${common.isEmpty ? 'nessuna recuperata' : common.join('; ')}. '
            'Registrate solo per $a: ${pa.difference(pb).join('; ')}. Registrate solo per $b: ${pb.difference(pa).join('; ')}.',
        'Confronto delle affermazioni recuperate. Una proprietà non registrata non è una proprietà falsa.',
        [...ea, ...eb].map((e) => e.id),
        rows.length,
        clock,
      );
    }
    if (RegExp(
      r'^(?:riassumi|riassunto|racconta|cosa è successo|che cosa è successo)\b',
    ).hasMatch(q)) {
      if (scope == null)
        return const CognitiveReply420(
          'unknown',
          'Seleziona la fonte da riassumere.',
        );
      final all = await memory.db.query(
        'claims',
        where: 'source=? AND status="asserted"',
        whereArgs: [scope],
        limit: 193,
      );
      if (all.length > 192)
        return const CognitiveReply420(
          'budget',
          'La fonte supera il budget del riassunto. Serve un riepilogo gerarchico, che questa versione non implementa.',
          budgetReached: true,
        );
      final es = all
          .map(
            (r) => Event350.fromJson(jsonDecode(r['payload'] as String) as Map),
          )
          .toList();
      final result = ClosedBookEngine350(es).answer(question);
      return _reply(
        '${result['status']}',
        '${result['answer']}',
        'Ricostruzione degli eventi interpretati. Non copre i passaggi irrisolti.',
        es.map((e) => e.id),
        rows.length,
        clock,
      );
    }
    if (candidates.isEmpty) {
      return CognitiveReply420(
        'unknown',
        'Non ricavo una risposta sostenuta dalle informazioni interpretate.',
        reason:
            'La domanda non è stata appresa come fatto. Puoi consultare i passaggi irrisolti o fornire una frase più esplicita.',
        candidates: rows.length,
        micros: clock.elapsedMicroseconds,
      );
    }
    final evidenceIds = candidates
        .expand(
          (c) =>
              (c['evidence'] as List? ?? []).map((e) => '${(e as Map)['id']}'),
        )
        .where((id) => provenance.containsKey(id))
        .toSet();
    final conflicts = candidates
        .where((r) => r['status'] == 'conflict')
        .toList();
    final answers = candidates
        .where((r) => r['status'] != 'conflict')
        .map(
          (r) =>
              (('${r['answer']}')
                      .split(';')
                      .map(BookExam342.normalize)
                      .toSet()
                      .toList()
                    ..sort())
                  .join(';'),
        )
        .toSet();
    if (conflicts.isNotEmpty || answers.length > 1) {
      return _reply(
        'conflict',
        'Le evidenze o le interpretazioni producono risposte incompatibili.',
        'Nessun motore ha precedenza automatica. Controlla le fonti e correggi la relazione specifica.',
        evidenceIds,
        rows.length,
        clock,
      );
    }
    final selected = candidates.first;
    if (evidenceIds.isEmpty)
      return CognitiveReply420(
        'unknown',
        'Il lettore ha prodotto una risposta senza una prova recuperabile. Non la presento come fatto.',
        candidates: rows.length,
        micros: clock.elapsedMicroseconds,
      );
    final focus = events
        .where((e) => evidenceIds.contains(e.id) && e.subject.isNotEmpty)
        .firstOrNull;
    if (focus != null) await memory.setMeta('focus', focus.subject);
    return _reply(
      '${selected['status']}',
      '${selected['answer']}',
      '${selected['reason'] ?? ''}${assumptions.isEmpty ? '' : ' Ipotesi temporanee: $assumptions'}',
      evidenceIds,
      rows.length,
      clock,
    );
  }

  Future<String> _description(List<Event350> events) async {
    final CompetenceLanguage350 language = await memory.language();
    return events
        .map((e) {
          if (e.negative ||
              e.universal ||
              e.location.isNotEmpty ||
              e.target.isNotEmpty ||
              e.surface.isEmpty ||
              e.kind == 'cause' ||
              e.kind == 'calculation')
            return e.describe();
          final composed = language.compose(e.subject, e.surface, e.object);
          // Composition fills only the slots of an already supported assertion;
          // statistical free continuation is never used as a factual answer.
          return composed['status'] == 'construction'
              ? '${composed['sentence']}'
              : e.describe();
        })
        .join(' ');
  }

  Future<CognitiveReply420> _story(
    String question,
    String scope,
    Stopwatch clock,
  ) async {
    final sources = await memory.db.query(
      'sources',
      where: 'id=?',
      whereArgs: [scope],
    );
    if (sources.isEmpty)
      return const CognitiveReply420('unknown', 'Fonte non disponibile.');
    final state = jsonDecode(sources.single['state'] as String) as Map;
    final mentions = Map<String, dynamic>.from(
      state['entityMentions'] as Map? ?? {},
    );
    final first = Map<String, dynamic>.from(state['entityFirst'] as Map? ?? {});
    final last = Map<String, dynamic>.from(state['entityLast'] as Map? ?? {});
    if (mentions.isEmpty)
      return const CognitiveReply420(
        'unknown',
        'Non ho una struttura di personaggi sufficientemente esplicita.',
      );
    final subjects = await memory.db.rawQuery(
      'SELECT subject entity,COUNT(*) n FROM claims '
      'WHERE source=? AND status="asserted" AND kind!="cause" GROUP BY subject',
      [scope],
    );
    final objects = await memory.db.rawQuery(
      'SELECT object entity,COUNT(*) n FROM claims '
      'WHERE source=? AND status="asserted" AND kind!="cause" GROUP BY object',
      [scope],
    );
    final sn = {
      for (final r in subjects) '${r['entity']}': (r['n'] as num).toInt(),
    };
    final on = {
      for (final r in objects) '${r['entity']}': (r['n'] as num).toInt(),
    };
    final ranked = mentions.keys
        .where((x) => (sn[x] ?? 0) + (on[x] ?? 0) > 0)
        .toList();
    double score(String x) =>
        3.0 * (sn[x] ?? 0) +
        (on[x] ?? 0) +
        (mentions[x] as num).toDouble() +
        ((last[x] as num? ?? 0) - (first[x] as num? ?? 0)).abs().toDouble() *
            .05;
    ranked.sort((a, b) => score(b).compareTo(score(a)));
    if (ranked.isEmpty)
      return const CognitiveReply420(
        'unknown',
        'Le menzioni non sono collegate a eventi interpretati.',
      );
    final plural = question.toLowerCase().contains('personaggi');
    if (!plural && ranked.length > 1 && score(ranked[0]) == score(ranked[1])) {
      return const CognitiveReply420(
        'unknown',
        'I personaggi più salienti hanno lo stesso punteggio; non individuo un protagonista univoco.',
      );
    }
    final picked = ranked.take(plural ? 5 : 1).toList();
    final ids = <String>[];
    for (final entity in picked) {
      final proofs = await memory.db.query(
        'claims',
        columns: ['id'],
        where: 'source=? AND status="asserted" AND (subject=? OR object=?)',
        whereArgs: [scope, entity, entity],
        limit: 6,
      );
      ids.addAll(proofs.map((p) => '${p['id']}'));
    }
    return _reply(
      'deduction',
      picked.map(pretty350).join('; '),
      'Classifica euristica di salienza sull’intera fonte: menzioni, partecipazione agli eventi e persistenza. '
          'Non è una probabilità né una verifica dell’intenzione dell’autore.',
      ids,
      subjects.length + objects.length,
      clock,
    );
  }

  Future<CognitiveReply420> _reply(
    String status,
    String text,
    String reason,
    Iterable<String> ids,
    int candidates,
    Stopwatch clock,
  ) async {
    final evidence = await memory.evidence(ids);
    await memory.activate(evidence.map((e) => '${e['id']}'));
    return CognitiveReply420(
      status,
      text,
      reason: reason,
      evidence: evidence,
      candidates: candidates,
      micros: clock.elapsedMicroseconds,
    );
  }
}
