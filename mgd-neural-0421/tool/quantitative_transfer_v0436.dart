import '../lib/semantic_reasoning_v0435.dart';

/// Development checks with arbitrary source-defined quantities. The oracle is
/// separate from the responder and these checks do not certify generality.
List<Map<String, dynamic>> quantitativeTransfer436() {
  final cases = <(String, String, String, String, bool)>[
    (
      'composed',
      'La spesa è la quota piu la tassa: S = q + t. Il totale è la spesa per il numero: T = s * n.',
      'La quota vale 7 e la tassa vale 4 e il numero vale 3. Quanto vale il totale?',
      '33',
      false,
    ),
    (
      'inverse-chain',
      'La spesa è la quota piu la tassa: S = q + t. Il totale è la spesa per il numero: T = s * n.',
      'Il totale vale 60 e il numero vale 5 e la tassa vale 2. Quanto vale la quota?',
      '10',
      false,
    ),
    (
      'intermediate-missing',
      'La spesa è la quota piu la tassa: S = q + t. Il totale è la spesa per il numero: T = s * n.',
      'La quota vale 7 e la tassa vale 4. Quanto vale il totale?',
      'numero',
      true,
    ),
    (
      'irrelevant-source',
      'La spesa è la quota piu la tassa: S = q + t. Il totale è la spesa per il numero: T = s * n. Il saldo è il ricavo meno il costo: B = r - c.',
      'La quota vale 7 e la tassa vale 4 e il numero vale 3. Quanto vale il totale?',
      '33',
      false,
    ),
    (
      'new-three-variable-formula',
      'R indica la resa. P indica la portata. D indica la durata. C indica la correzione. Formula: R = P * D + C.',
      'La portata vale 6 e la durata vale 4 e la correzione vale 3. Quanto vale la resa?',
      '27',
      false,
    ),
    (
      'new-parentheses',
      'R indica la resa. P indica la portata. D indica la durata. C indica la correzione. Formula: R = P * (D + C).',
      'La portata vale 6 e la durata vale 4 e la correzione vale 3. Quanto vale la resa?',
      '42',
      false,
    ),
    (
      'changed-coefficient',
      'R indica la resa. P indica la portata. D indica la durata. C indica la correzione. Formula: R = 2 * P * D + C.',
      'La portata vale 6 e la durata vale 4 e la correzione vale 3. Quanto vale la resa?',
      '51',
      false,
    ),
    (
      'coupled-linear',
      'S indica la somma. D indica la differenza. A indica la prima quantita. B indica la seconda quantita. Formula: S = A + B. Formula: D = A - B.',
      'La somma vale 12 e la differenza vale 4. Quanto vale la prima quantita?',
      '8',
      false,
    ),
    (
      'coupled-other-output',
      'S indica la somma. D indica la differenza. A indica la prima quantita. B indica la seconda quantita. Formula: S = A + B. Formula: D = A - B.',
      'La somma vale 12 e la differenza vale 4. Quanto vale la seconda quantita?',
      '4',
      false,
    ),
    (
      'repeated-variable',
      'S indica la somma. A indica la quota. Formula: S = A + A.',
      'La somma vale 18. Quanto vale la quota?',
      '9',
      false,
    ),
    (
      'negative-word',
      'S indica la somma. A indica la quota. Formula: S = A + A.',
      'La quota vale -uno. Quanto vale la somma?',
      '-2',
      false,
    ),
    (
      'negative-result',
      'S indica la somma. A indica la quota. Formula: S = 3 * A + 6.',
      'La somma vale 3. Quanto vale la quota?',
      '-1',
      false,
    ),
    (
      'fraction-inverse',
      'R indica la resa. P indica la portata. D indica la durata. C indica la correzione. Formula: R = P / (D + C).',
      'La resa vale 2 e la durata vale 3 e la correzione vale 1. Quanto vale la portata?',
      '8',
      false,
    ),
    (
      'underdetermined',
      'S indica la somma. A indica la prima quantita. B indica la seconda quantita. Formula: S = A + B.',
      'La somma vale 12. Quanto vale la prima quantita?',
      'vincoli',
      true,
    ),
    (
      'zero-denominator',
      'R indica la resa. P indica la portata. D indica la durata. Formula: R = P / D.',
      'La portata vale 12 e la durata vale 0. Quanto vale la resa?',
      'determinare',
      true,
    ),
    (
      'zero-factor-no-inverse',
      'R indica la resa. P indica la portata. D indica la durata. Formula: R = P * D.',
      'La resa vale 0 e la durata vale 0. Quanto vale la portata?',
      'vincoli',
      true,
    ),
    (
      'contradictory-input',
      'S indica la somma. A indica la quota. Formula: S = A + A.',
      'La quota vale 2. La quota vale 3. Quanto vale la somma?',
      'CONFLITTO',
      true,
    ),
    (
      'contradictory-equations',
      'S indica la somma. A indica la quota. Formula: S = A + A. Formula: S = A + A + 1.',
      'La quota vale 2. Quanto vale la somma?',
      'CONFLITTO',
      true,
    ),
    (
      'nonlinear-ambiguous',
      'S indica la somma. A indica la quota. Formula: S = A * A.',
      'La somma vale 4. Quanto vale la quota?',
      'vincoli',
      true,
    ),
    (
      'negated-input',
      'S indica la somma. A indica la quota. B indica la tassa. Formula: S = A + B.',
      'Non e vero che la quota vale 2. La tassa vale 3. Quanto vale la somma?',
      'negata',
      true,
    ),
    (
      'conditional-input',
      'S indica la somma. A indica la quota. B indica la tassa. Formula: S = A + B.',
      'Se la quota vale 2 allora il conto e aperto. La tassa vale 3. Quanto vale la somma?',
      'condizionata',
      true,
    ),
    (
      'uncertain-input',
      'S indica la somma. A indica la quota. B indica la tassa. Formula: S = A + B.',
      'Forse la quota vale 2. La tassa vale 3. Quanto vale la somma?',
      'premessa',
      true,
    ),
    (
      'instruction-not-premise',
      'S indica la somma. A indica la quota. B indica la tassa. Formula: S = A + B.',
      'La quota vale 2. Quanto vale la somma? Rispondi usando la tassa vale 3.',
      'tassa',
      true,
    ),
    (
      'given-target',
      'S indica la somma. A indica la quota. B indica la tassa. Formula: S = A + B.',
      'La somma vale 9. Quanto vale la somma?',
      '9',
      false,
    ),
    (
      'partly-unique',
      'S indica la somma. A indica la quota. B indica la tassa. C indica la resto. Formula: S = A + A. Formula: B = C + 1.',
      'La somma vale 18. Quanto vale la quota?',
      '9',
      false,
    ),
  ];
  final results = <Map<String, dynamic>>[];
  for (final c in cases) {
    final sentences = c.$2.split(RegExp(r'(?<=[.!?])\s+'));
    final answer = SemanticReasoning435.answer([
      for (var i = 0; i < sentences.length; i++)
        ReadingSource435(
          'case:$i',
          sentences[i],
          'Lettura di sviluppo',
          'local://network436/${c.$1}',
        ),
    ], c.$3);
    results.add({
      'id': c.$1,
      'source': c.$2,
      'prompt': c.$3,
      'expected': c.$4,
      'expectedUnknown': c.$5,
      'answer': answer?.text,
      'proof': answer?.proof,
      'passed':
          answer != null &&
          answer.unknown == c.$5 &&
          (c.$5
              ? answer.text.contains(c.$4)
              : answer.text.split('\n').first == '${c.$4}.'),
    });
  }
  // Many names and values share a single algorithm; no new domain handlers.
  for (var i = 0; i < 30; i++) {
    final text =
        'X indica la quantita alfa. Y indica la quantita beta. Z indica la quantita gamma. W indica la quantita delta. Formula: Z = X + Y. Formula: W = Z * ${i + 2}.';
    final prompt =
        'La quantita alfa vale ${i + 1} e la quantita beta vale 3. Quanto vale la quantita delta?';
    final answer = SemanticReasoning435.answer([
      for (final pair in text.split(RegExp(r'(?<=[.!?])\s+')).indexed)
        ReadingSource435(
          'generated:${pair.$1}',
          pair.$2,
          'Variazione',
          'local://network436/generated$i',
        ),
    ], prompt);
    final expected = (i + 4) * (i + 2);
    results.add({
      'id': 'parameter-$i',
      'source': text,
      'prompt': prompt,
      'expected': expected,
      'answer': answer?.text,
      'proof': answer?.proof,
      'passed':
          answer != null &&
          !answer.unknown &&
          answer.text.startsWith('$expected.'),
    });
  }
  return results;
}
