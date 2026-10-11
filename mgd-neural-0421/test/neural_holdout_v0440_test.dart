import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/neural_reading_v0439.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../tool/legacy_reading_context439.dart';

void main() {
  test('emit 16 frozen new texts with paired production and historical retrieval', () {
    final input = File('tool/fixtures/neural_holdout_440.json').readAsBytesSync();
    expect(sha256.convert(input).toString(), 'c2234d70812f582ec973b020c0394f74d6f7da90da58fb34e05305dd3dbcecec');
    final prompts = <Map<String, dynamic>>[];
    for (final c in (jsonDecode(utf8.decode(input)) as List).cast<Map>()) {
      final m = ResearchMemory11();
      SourceMemory323.retain(m, WebDocument11(provider: 'Nuova verifica', family: 'local',
        title: 'Archivio', url: 'local://assessment/${c['id']}', trust: .9, text: c['text']));
      // Retrieval sees the question only, excluding answer-option clues.
      final context = NeuralReading439.context(m, c['question']);
      final baseline = LegacyReadingContext439.context(m, c['question']);
      final query = '${c['question']}\nScegli una risposta e riporta solo la lettera A, B, C o D nel campo answer.\n' +
        (c['options'] as Map).entries.map((e) => '${e.key}: ${e.value}').join('\n');
      prompts.add({'id': c['id'], 'domain': c['domain'], 'capability': c['capability'],
        'split': 'heldout_new', 'source_characters': '${c['text']}'.length,
        'available_rows': NeuralReading439.fragments(m).length,
        'context_rows': context.length, 'context': context,
        'prompt': NeuralReading439.answerPrompt(query, context),
        'baseline_context_rows': baseline.length, 'baseline_context': baseline,
        'baseline_prompt': NeuralReading439.answerPrompt(query, baseline)});
    }
    final out = Directory('tool/reports')..createSync(recursive: true);
    File('${out.path}/neural-holdout-prompts-440.json').writeAsStringSync(jsonEncode(prompts));
    expect(prompts.length, 16);
    expect(prompts.every((p) => p['context_rows'] > 0), true);
    final late = prompts.singleWhere((p) => p['id'] == 'K13');
    expect((late['context'] as List).any((r) => '${r['text']}'.contains('Tersio')), true);
    expect((late['baseline_context'] as List).any((r) => '${r['text']}'.contains('Tersio')), false);
    final chain = prompts.singleWhere((p) => p['id'] == 'K14');
    expect((chain['context'] as List).any((r) => '${r['text']}'.contains('Fergio')), true);
    expect((chain['baseline_context'] as List).any((r) => '${r['text']}'.contains('Fergio')), false);
  });
}
