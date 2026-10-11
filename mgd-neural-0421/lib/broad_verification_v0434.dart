import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'learning_verification_v0428.dart';
import 'verification_reader_v0428.dart';
import 'web_knowledge_explorer_v11.dart';

/// Examiner only. The responder receives texts through normal reading and
/// questions through its query-only interface; never references or criteria.
/// The benchmark does not assert or certify general comprehension.
class BroadVerification434 {
  static const asset = 'assets/comprehension-434.json';
  static const frozenSha = 'c2ba157a87c0e0e9d97233cf31bafe7bc1034bdb4dc2613ec1ce7a9312408db4';

  static Future<Map<String, dynamic>> load() async {
    final bytes = await rootBundle.load(asset);
    final raw = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    if (sha256.convert(raw).toString() != frozenSha) {
      throw StateError('Il testo o i riferimenti della verifica sono cambiati.');
    }
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(raw)) as Map);
  }

  static String norm(String text) => text.toLowerCase()
      .replaceAll('à', 'a').replaceAll('è', 'e').replaceAll('é', 'e')
      .replaceAll('ì', 'i').replaceAll('ò', 'o').replaceAll('ù', 'u')
      .replaceAll('²', '2').replaceAll('’', "'");

  /// Explicit finite text criteria, with calibrated reference examples.
  /// Unmatched paraphrases need review; this is not a semantic oracle.
  static ({bool passed, String reason}) grade(Map q, VerificationAnswer428 a) {
    final text = norm(a.text);
    final recall = q['capability'] == 'recall';
    if (recall && a.route == 'passaggi') {
      final quotes = RegExp(r'«([^»]+)»').allMatches(text).toList();
      final retrieved = quotes.length == 1 && quotes.single[1]!.length < 240 &&
          !quotes.single[1]!.contains('\n') &&
          RegExp('${q['conclusion']}').hasMatch(quotes.single[1]!) && q['reason'] == null;
      return (passed: retrieved, reason: retrieved
          ? 'Ha recuperato il passaggio originale pertinente. Questo misura il recupero, non l’applicazione.'
          : 'Non ha recuperato una risposta puntuale alla domanda.');
    }
    if ({'associazioni', 'passaggi'}.contains(a.route) ||
        text.startsWith('le associazioni') || text.contains('«')) {
      return (passed: false, reason: 'Ha restituito associazioni o un passaggio, senza la risposta richiesta.');
    }
    if (q['determinate'] == true && (a.route == 'astensione' ||
        text.startsWith('non determinabile') ||
        text.startsWith('non ho ancora') || text.startsWith('non so'))) {
      return (passed: false, reason: 'Non ha formulato la conclusione ricavabile dai dati.');
    }
    if (!recall && q['determinate'] == true &&
        {'fonti', 'letture', 'relazioni'}.contains(a.route)) {
      return (passed: false, reason: 'Ha recuperato fatti; manca la soluzione del caso e la sua giustificazione.');
    }
    final lines = text.split(RegExp(r'\n+')).where((s) => s.trim().isNotEmpty &&
        !s.startsWith('fatti documentati') && !s.startsWith('dal testo,') &&
        !s.startsWith('nella memoria di')).toList();
    final first = (lines.isEmpty ? text : lines.first)
        .split(RegExp(r'[.!?]\s+')).first;
    final conclusion = RegExp('${q['conclusion']}').hasMatch(first);
    final reason = q['reason'] == null || RegExp('${q['reason']}', dotAll: true).hasMatch(text);
    final passed = conclusion && reason;
    return (passed: passed, reason: passed
        ? recall ? 'Il criterio di recupero è soddisfatto.'
            : 'Conclusione e giustificazione soddisfano i criteri espliciti di questo caso.'
        : !conclusion ? 'Conclusione non verificata dai criteri: controlla risposta e riferimento.'
            : 'Manca la giustificazione richiesta o l’identificazione del dato mancante.');
  }

  static Future<Map<String, dynamic>> run({
    Future<VerificationReader428> Function()? openReader,
    bool Function()? cancelled,
    void Function(int, int, String)? progress,
    String version = '0.42.20',
  }) async {
    final suite = await load();
    final domains = (suite['domains'] as List).cast<Map>();
    final total = domains.fold<int>(0, (n, d) => n + (d['questions'] as List).length);
    final rows = <Map<String, dynamic>>[];
    var done = 0;
    void check() { if (cancelled?.call() ?? false) throw VerificationCancelled428(); }
    for (final domain in domains) {
      check();
      final reader = await (openReader?.call() ?? VerificationReader428.open());
      try {
        final questions = (domain['questions'] as List).cast<Map>();
        final before = <VerificationAnswer428>[];
        final initial = jsonEncode(reader.memory.toJson());
        for (final q in questions) {
          check();
          before.add(await reader.answer('${q['prompt']}'));
          progress?.call(++done, total * 2, '${domain['title']}: prima della lettura');
          await Future<void>.delayed(Duration.zero);
        }
        if (jsonEncode(reader.memory.toJson()) != initial) {
          throw StateError('Una domanda ha modificato la memoria durante la verifica.');
        }
        final doc = WebDocument11(provider: 'Esercizio originale', family: 'locale:verifica434',
            title: '${domain['title']}', url: 'local://comprehension434/${domain['id']}',
            text: '${domain['text']}', trust: .8);
        await reader.read([doc], cancelled: cancelled);
        final frozen = jsonEncode(reader.memory.toJson());
        for (var i = 0; i < questions.length; i++) {
          check();
          final q = questions[i];
          final answer = await reader.answer('${q['prompt']}');
          final score = grade(q, answer);
          rows.add({'id': '${domain['id']}-${q['id']}', 'domain': domain['title'],
            'capability': q['capability'], 'determinate434': q['determinate'],
            'prompt': q['prompt'], 'expected': q['reference'],
            'answer': answer.toJson(), 'before': before[i].toJson(),
            'passed': score.passed, 'beforePassed': grade(q, before[i]).passed,
            'reason': score.reason,
            'sources': [{'title': doc.title, 'text': doc.text, 'url': doc.url,
              if (domain['reference'] != null) 'reference': domain['reference']}],
          });
          progress?.call(++done, total * 2, '${domain['title']}: dopo la lettura');
          await Future<void>.delayed(Duration.zero);
        }
        if (jsonEncode(reader.memory.toJson()) != frozen) {
          throw StateError('Domande o risultati hanno modificato la memoria della lettura.');
        }
      } finally { await reader.close(); }
    }
    check();
    final determinate = rows.where((r) => r['determinate434'] == true).toList();
    final applied = determinate.where((r) => r['capability'] != 'recall').toList();
    final unknown = rows.where((r) => r['determinate434'] != true).toList();
    return {'schema': 1, 'mode': 'broad', 'version': version, 'status': 'completed', 'graderRevision434': 2,
      'at': DateTime.now().toIso8601String(), 'suite434': suite['id'], 'sha256434': frozenSha,
      'scope434': suite['description'], 'generalComprehension434': 'not_demonstrated',
      'memoryUnchanged434': true, 'results': rows, 'total': rows.length,
      'passed': rows.where((r) => r['passed'] == true).length,
      'beforePassed': rows.where((r) => r['beforePassed'] == true).length,
      'determinate434': {'passed': determinate.where((r) => r['passed'] == true).length, 'total': determinate.length},
      'applied434': {'passed': applied.where((r) => r['passed'] == true).length, 'total': applied.length},
      'unknown434': {'passed': unknown.where((r) => r['passed'] == true).length, 'total': unknown.length},
      'domains434': [for (final d in domains) {'title': d['title'],
        'passed': rows.where((r) => r['domain'] == d['title'] && r['passed'] == true).length,
        'total': (d['questions'] as List).length}],
    };
  }
}
