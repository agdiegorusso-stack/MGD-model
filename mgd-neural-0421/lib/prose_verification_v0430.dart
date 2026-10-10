import 'learning_verification_v0428.dart';
import 'web_knowledge_explorer_v11.dart';

/// The examiner owns the questions and reference conclusions. Neither this
/// module nor its answer keys is imported by the reading/reasoning modules.
class ProseVerification430 {
  // Original teaching paragraph, not a downloaded or translated textbook.
  // The stated setting excludes a cell wall, permeant solutes and competing
  // pressure. This is a bounded osmotic example, not a clinical prediction.
  static const text = 'Consideriamo una cellula animale senza parete, con una membrana '
      'permeabile all’acqua ma non ai soluti, senza una pressione che contrasti il movimento. '
      'Il liquido esterno viene confrontato con il contenuto della cellula. '
      'Quando il liquido esterno è ipotonico, l’acqua entra nella cellula. '
      'Quando l’acqua entra nella cellula, la cellula si gonfia. '
      'Quando il liquido esterno è ipertonico, l’acqua esce dalla cellula. '
      'Quando l’acqua esce dalla cellula, la cellula si restringe. '
      'Quando il liquido esterno è isotonico, il flusso netto è assente. '
      'Il testo non quantifica la velocità o il tempo del cambiamento e non descrive la lisi.';
  static const reference = 'https://openstax.org/books/biology-2e/pages/5-2-passive-transport';

  static VerificationWorld428 world() {
    final doc = WebDocument11(provider: 'Testo didattico MGD', family: 'locale:verifica',
        title: 'Osmosi: esempio delimitato', url: 'local://verification/osmosi',
        text: text, trust: .8);
    const evidence = [{'title': 'Testo didattico MGD; riferimento: OpenStax Biology 2e, 5.2',
      'url': reference, 'text': text}];
    VerificationCase428 q(String id, String capability, String prompt,
        {String expected = 'si', String? atom}) => VerificationCase428(
        id: 'prose-$id', capability: capability, prompt: prompt, expected: expected,
        subject: 'cellula', sources: evidence, expectedAtom: atom);
    return VerificationWorld428(doc, [
      q('in', 'application', 'Il liquido esterno è ipotonico. L’acqua entra nella cellula?',
          atom: '+entra(acqua|cellula)'),
      q('chain', 'composition', 'Il liquido esterno è ipotonico. La cellula si gonfia?',
          atom: '+gonfia(cellula)'),
      q('if', 'application', 'Se il liquido esterno è ipotonico, la cellula si gonfia?',
          atom: '+gonfia(cellula)'),
      q('open', 'composition', 'Che cosa succede alla cellula quando il liquido esterno è ipotonico?',
          atom: '+gonfia(cellula)'),
      q('why', 'composition', 'Il liquido esterno è ipotonico. Perché la cellula si gonfia?',
          atom: '+gonfia(cellula)'),
      q('out', 'conditions', 'Il liquido esterno è ipertonico. L’acqua esce dalla cellula?',
          atom: '+esce(acqua|cellula)'),
      q('shrink', 'conditions', 'Il liquido esterno è ipertonico. La cellula si restringe?',
          atom: '+restringe(cellula)'),
      q('change', 'conditions', 'Se il liquido esterno è ipertonico, la cellula si restringe?',
          atom: '+restringe(cellula)'),
      q('isotonic', 'conditions', 'Il liquido esterno è isotonico. Il flusso netto è assente?',
          expected: 'si', atom: '-stato(flusso netto|presente)'),
      q('weight', 'unknown', 'Quanto pesa la cellula?', expected: 'unknown'),
      q('lysis', 'unknown', 'Il liquido esterno è ipotonico. La cellula è distrutta?', expected: 'unknown'),
      q('conflict', 'conflict', 'Il liquido esterno è ipotonico. Il liquido esterno non è ipotonico. '
          'La cellula si gonfia?', expected: 'conflict'),
    ]);
  }
}
