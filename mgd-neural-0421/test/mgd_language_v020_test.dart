import 'package:flutter_test/flutter_test.dart';
import '../lib/mgd_language_v020.dart';
import '../lib/plastic_language_brain_v04.dart';

void main() {
  test('PURE MGD language learns recurrent Italian paths and chunks', () {
    final l = MgdLanguage20();
    const corpus = 'Il cane è un mammifero. Il gatto è un mammifero. '
        'Il cane vive con le persone. Il gatto vive con le persone. '
        'Il cane è un animale. Il gatto è un animale.';
    for (var i = 0; i < 8; i++) {
      l.ingestText(corpus, reward: 0.5);
    }
    final s = l.stats();
    expect(s.tokens, greaterThan(8));
    expect(s.edges, greaterThan(10));
    expect(s.chunks, greaterThan(0));
    final out = l.generate('parlami del cane',
        semanticHint: 'Il cane è un mammifero',
        brain: PlasticLanguageBrain04());
    expect(out, isNotNull);
    expect(out!.split(' ').length, greaterThanOrEqualTo(4));
  });

  test('rare chunk pruning preserves recurrent paths through reopen and forgetting', () {
    final l = MgdLanguage20();
    for (var n = 0; n < 8; n++) {
      l.ingestText('Il cane vive con le persone.');
    }
    final before = (l.toJson()['ch'] as List)
        .firstWhere((c) => c['t'] == 'vive con le persone');
    for (var n = 0; n < 1800; n++) {
      l.ingestText('Campione $n contiene organello speciale numero $n.');
    }
    final after = (l.toJson()['ch'] as List)
        .firstWhere((c) => c['t'] == 'vive con le persone');
    expect(after, before);
    final reopened = MgdLanguage20.fromJson(l.toJson());
    String? answer(MgdLanguage20 m) => m.generate('cane',
        semanticHint: 'Il cane vive con le persone', brain: PlasticLanguageBrain04());
    expect(answer(l), isNotNull);
    expect(answer(reopened), answer(l));
    l.forgetNode33('cane');
    expect((l.toJson()['ch'] as List).any((c) =>
        PlasticLanguageBrain04.containsLabel33(c['t'], 'cane')), isFalse);
    expect(answer(MgdLanguage20.fromJson(l.toJson())), answer(l));
  });
}
