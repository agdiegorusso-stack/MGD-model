import 'dart:math';
import 'learning_verification_v0428.dart';
import 'web_knowledge_explorer_v11.dart';

/// A separate examiner: other predicates, an extra inference step, conjunction,
/// incomplete knowledge and inconsistent assumptions. None of this module is
/// imported by the responder or the text/rule interpreter.
class TransferVerification429 {
  static List<VerificationWorld428> worlds(int seed) {
    final random = Random(seed), nonce = seed.toRadixString(36);
    final types = ['robot', 'dispositivo', 'sensore', 'veicolo']..shuffle(random);
    return List.generate(4, (i) {
      final unit = 'unita${nonce}x$i', other = 'nuova${nonce}x$i';
      final module = 'modulo${nonce}x$i', resource = 'energia${nonce}x$i';
      final type = types[i];
      final doc = WebDocument11(provider: 'Modello didattico', family: 'locale:verifica',
          title: '${types[i]} simulato', url: 'local://transfer/$nonce/$i', trust: .8,
          text: '$unit è un $type. $unit contiene $module. '
              'Ogni $type che contiene $module diventa pronto. '
              'Ogni $type diventa attivo se e solo se $resource è presente e esso è pronto. '
              'Ogni $type diventa visibile se e solo se esso è attivo.');
      VerificationCase428 q(String id, String capability, String prompt, String expected) =>
          VerificationCase428(id: 'transfer-$i-$id', capability: capability,
            prompt: prompt, expected: expected, subject: unit,
            sources: [{'title': doc.title, 'url': doc.url, 'text': doc.text}]);
      return VerificationWorld428(doc, [
        q('new', 'application', '$other è un $type. $other contiene $module. $resource è presente. $other diventa attivo?', 'si'),
        q('chain', 'composition', '$resource è presente. $unit diventa visibile?', 'si'),
        q('change', 'conditions', '$resource è assente. $unit diventa visibile?', 'no'),
        q('missing', 'unknown', '$unit diventa attivo?', 'unknown'),
        q('one-way', 'unknown', '$other è un $type. $other non contiene $module. $other diventa pronto?', 'unknown'),
        q('conflict', 'conflict', '$resource è presente. $resource è assente. $unit diventa attivo?', 'conflict'),
      ]);
    });
  }
}
