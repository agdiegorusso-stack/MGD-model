import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'learning_verification_v0428.dart';
import 'transport_reasoning_v0433.dart';
import 'web_knowledge_explorer_v11.dart';

/// Examiner module. This file is never imported by the transport interpreter.
/// References specify compartment labels independently of the responder.
class ApplicationVerification433 {
  static const url = 'https://openstax.org/books/biology-2e/pages/5-2-passive-transport';

  static Future<WebDocument11> fetchDocument() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'MGD-Study/0.42.13');
      final response = await request.close().timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) throw StateError('OpenStax: HTTP ${response.statusCode}; nessuna prova eseguita.');
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 40))) {
        bytes.addAll(chunk);
        if (bytes.length > 4000000) throw StateError('Documento troppo grande.');
      }
      final html = utf8.decode(bytes);
      final text = html.replaceAll(RegExp(r'<script\b[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'<style\b[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll('&nbsp;', ' ')
          .replaceAll('&#39;', "'").replaceAll('&amp;', '&').replaceAll(RegExp(r'\s+'), ' ').trim();
      // Keep one original, complete declarative sentence, without rewriting
      // it into the interpreter's rule language. Never synthesize a fallback.
      final sentence = RegExp(r'In passive transport, substances move from an area of higher concentration to an area of lower concentration\.', caseSensitive: false)
          .firstMatch(text)?.group(0);
      if (sentence == null) throw StateError('OpenStax: principio non leggibile nella risposta; nessun testo sostitutivo.');
      return WebDocument11(provider: 'OpenStax', family: 'openstax.org',
        title: 'Biology 2e · 5.2 Passive Transport', url: url, text: sentence,
        trust: .9, meta318: {'retrievedAt433': DateTime.now().toIso8601String(),
          'acquiredBytes433': bytes.length, 'originalSentence433': true});
    } finally { client.close(force: true); }
  }

  static List<VerificationCase428> cases(WebDocument11 doc, int seed) {
    final random = Random(seed);
    final low = 1 + random.nextInt(5), high = 10 + random.nextInt(10);
    const solute = 'tracciante';
    const scope = 'In un sistema ideale a sola diffusione, senza pressione o trasporto attivo, consideriamo il soluto neutro tracciante.';
    const membrane = 'La membrana è permeabile a tracciante.';
    String c(String place, num value, [String unit = 'mmol/L']) => 'La concentrazione di tracciante in $place è $value $unit.';
    const ask = 'In quale direzione si muove il flusso netto di tracciante?';
    final evidence = [{'title': doc.title, 'url': doc.url, 'text': doc.text}];
    VerificationCase428 q(String id, String capability, List<String> premises,
        {String? from, String? to, bool zero = false, String expected = 'transfer',
        String question = ask}) => VerificationCase428(id: 'application-$id',
          capability: capability, prompt: [...premises, question].join(' '),
          expected: expected, subject: 'diffusione', sources: evidence,
          expectedTransfer433: expected == 'transfer'
              ? {'solute': solute, 'from': from, 'to': to, 'netZero': zero} : null);
    return [
      q('blood-to-bath', 'application', [scope, membrane, c('sangue', high), c('bagno', low)], from: 'sangue', to: 'bagno'),
      q('reverse', 'conditions', [scope, membrane, c('sangue', low), c('bagno', high)], from: 'bagno', to: 'sangue'),
      q('new-labels', 'application', [scope, membrane, c('sinistra', high), c('destra', low)], from: 'sinistra', to: 'destra'),
      q('order', 'paraphrase', [scope, membrane, c('bagno', low), c('sangue', high)], from: 'sangue', to: 'bagno'),
      q('rephrased', 'paraphrase', [scope, membrane,
        'Nel compartimento esterno, tracciante ha una concentrazione di $high mM.',
        'Nel compartimento interno, tracciante ha una concentrazione di $low mM.'],
        from: 'esterno', to: 'interno', question: 'Dove si sposta tracciante per diffusione?'),
      q('units', 'composition', [scope, membrane, c('alfa', .002, 'mol/L'), c('beta', 900, 'µmol/L')], from: 'alfa', to: 'beta'),
      q('decimal', 'application', [scope, membrane, c('uno', 1.2), c('due', 1.8)], from: 'due', to: 'uno'),
      q('equilibrium', 'conditions', [scope, membrane, c('sangue', high), c('bagno', high)], zero: true),
      q('blocked', 'conditions', [scope, 'La membrana è impermeabile a tracciante.', c('sangue', high), c('bagno', low)], zero: true),
      q('other-solute', 'composition', [scope, membrane, c('sangue', high), c('bagno', low),
        'La concentrazione di altro in sangue è 1 mmol/L.', 'La concentrazione di altro in bagno è 99 mmol/L.'], from: 'sangue', to: 'bagno'),
      q('missing-value', 'unknown', [scope, membrane, c('sangue', high)], expected: 'unknown'),
      q('missing-barrier', 'unknown', [scope, c('sangue', high), c('bagno', low)], expected: 'unknown'),
      q('unit-mismatch', 'unknown', [scope, membrane, c('sangue', high, 'mg/L'), c('bagno', low)], expected: 'unknown'),
      q('time', 'unknown', [scope, membrane, c('sangue', high), c('bagno', low)], expected: 'unknown', question: 'Quanto tempo impiega tracciante ad attraversare la membrana?'),
      q('unsupported-condition', 'unknown', [scope, membrane, c('sangue', high), c('bagno', low), 'È presente trasporto attivo.'], expected: 'unknown'),
      q('conflicting-values', 'conflict', [scope, membrane, c('sangue', high), c('sangue', low), c('bagno', low)], expected: 'conflict'),
      q('conflicting-barrier', 'conflict', [scope, membrane, 'La membrana è impermeabile a tracciante.', c('sangue', high), c('bagno', low)], expected: 'conflict'),
    ];
  }

  /// Do not award points for a quote or for an unsupported conclusion. The
  /// expected compartment labels were specified by the examiner, not queried
  /// from the interpreter. Every used premise must occur in the question.
  static ({bool passed, String reason}) grade(VerificationCase428 q, VerificationAnswer428 a) {
    final proof = a.proof;
    final actual = proof?['result'];
    final expected = q.expectedTransfer433!;
    final principle = proof?['principle'];
    final premises = proof?['premises'];
    final correct = a.route == 'inferenza' && proof?['kind'] == 'quantitative_transfer' &&
        actual is Map && expected.entries.every((e) => actual[e.key] == e.value) &&
        principle is Map && q.sources.any((s) => s['url'] == principle['url'] &&
            s['text']!.contains('${principle['text']}') && '${principle['text']}'.isNotEmpty) &&
        premises is List && premises.whereType<Map>().any((p) => p['kind'] == 'scope') &&
        premises.whereType<Map>().any((p) => p['kind'] == 'permeability') &&
        premises.whereType<Map>().where((p) => p['kind'] == 'concentration').length >= 2 &&
        premises.whereType<Map>().every((p) => TransportReasoning433.norm(q.prompt)
            .contains(TransportReasoning433.norm('${p['text']}')));
    return (passed: correct, reason: correct
        ? 'Ha applicato il principio letto ai valori nuovi, con fonte e premesse verificabili.'
        : 'Il verso, le premesse o il collegamento al principio letto non corrispondono al caso.');
  }
}
