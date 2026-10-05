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
    final out = l.generate('parlami del cane', semanticHint: 'Il cane è un mammifero', brain: PlasticLanguageBrain04());
    expect(out, isNotNull);
    expect(out!.split(' ').length, greaterThanOrEqualTo(4));
  });
}
