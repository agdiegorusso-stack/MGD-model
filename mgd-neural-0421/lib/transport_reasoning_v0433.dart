import 'rule_reasoning_v0429.dart';
import 'web_knowledge_explorer_v11.dart';

/// A deliberately bounded interpreter: learns a transport ordering from a
/// retained sentence, then compares new measurements. It has no questions,
/// reference answers, patient decisions or pretrained language model.
class TransportPrinciple433 {
  final LogicSource429 source;
  final bool descending;
  const TransportPrinciple433(this.source, this.descending);
}

class TransportAnswer433 {
  final String text, truth;
  final Map<String, dynamic>? proof;
  const TransportAnswer433(this.text, this.truth, [this.proof]);
}

class TransportReasoning433 {
  static String norm(String s) => RuleReasoning429.norm(s)
      .replaceAll('µ', 'u').replaceAll('μ', 'u');
  static List<TransportPrinciple433> principles(ResearchMemory11 memory) {
    final out = <TransportPrinciple433>[];
    for (final source in RuleReasoning429.sources(memory)) {
      final s = norm(source.text);
      // Match a complete declarative transport sentence. A conditional,
      // negation, question or quotation of a rejected claim cannot teach it.
      if (s.contains('?') || RegExp(r'\b(not|non|may|might|if|unless|forse|se|potrebbe)\b').hasMatch(s)) continue;
      final english = RegExp(r'^(?:in (?:passive transport|diffusion), (?:substances|particles) move|a single substance moves) from (?:an area of |a )?(higher|high|lower|low) concentration to (?:an area of |a )?(lower|low|higher|high) concentration(?: area)?(?: until the concentration is equal across a space)?\.$').firstMatch(s);
      final italian = RegExp(r'^(?:nella diffusione|nel trasporto passivo), (?:le sostanze|le particelle) si muovono da (?:una zona a |un.area a )?concentrazione (maggiore|alta|minore|bassa) a (?:una zona a |un.area a )?concentrazione (minore|bassa|maggiore|alta)\.$').firstMatch(s);
      final match = english ?? italian;
      if (match == null) continue;
      const high = {'higher', 'high', 'maggiore', 'alta'};
      if (high.contains(match[1]) == high.contains(match[2])) continue;
      out.add(TransportPrinciple433(source, high.contains(match[1])));
    }
    return out;
  }

  static TransportAnswer433? answer(ResearchMemory11 memory, String prompt) {
    final cleaned = norm(prompt);
    final parts = cleaned.split(RegExp(r'(?<=[.!])\s+|\n+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty || !cleaned.endsWith('?')) return null;
    final question = parts.last;
    final asked = RegExp(r'^(?:in quale direzione si muove il flusso netto di|dove si sposta|qual e il verso del flusso netto di) ([a-z0-9_-]+)(?: per diffusione)?\?$').firstMatch(question);
    final amount = RegExp(r'^(?:quanto tempo impiega|quanti grammi di) ([a-z0-9_-]+)(?:.+)?\?$').firstMatch(question);
    if (asked == null && amount == null) return null;
    final solute = (asked ?? amount)![1]!;
    TransportAnswer433 unknown(String reason) => TransportAnswer433('Non determinabile: $reason', 'unknown');
    if (parts.length < 2) return unknown('mancano le condizioni del sistema e le concentrazioni.');
    final learned = principles(memory);
    if (learned.isEmpty) return unknown('nelle letture manca un principio di trasporto interpretabile.');
    if (learned.map((p) => p.descending).toSet().length != 1) {
      return const TransportAnswer433('Non determinabile: i principi letti sono IN CONFLITTO.', 'conflict');
    }
    final p = learned.first;
    final values = <String, double>{}, raw = <Map<String, dynamic>>[];
    bool bounded = false;
    bool? permeable;
    bool barrierConflict = false;
    for (final clause in parts.take(parts.length - 1)) {
      final s = clause.replaceFirst(RegExp(r'[.!]$'), '');
      // Charged solutes require electrical potential; competing transport or
      // pressure invalidates this restricted model. Do not silently ignore it.
      if (s == 'in un sistema ideale a sola diffusione, senza pressione o trasporto attivo, consideriamo il soluto neutro $solute') {
        bounded = true;
        raw.add({'kind': 'scope', 'text': clause});
        continue;
      }
      final membrane = RegExp(r'^la membrana e (permeabile|impermeabile) a ([a-z0-9_-]+)$').firstMatch(s);
      if (membrane != null) {
        if (membrane[2] == solute) {
          final next = membrane[1] == 'permeabile';
          if (permeable != null && permeable != next) barrierConflict = true;
          permeable = next;
          raw.add({'kind': 'permeability', 'text': clause, 'value': next});
        }
        continue;
      }
      final standard = RegExp(r'^la concentrazione di ([a-z0-9_-]+) in ([a-z0-9_-]+) e ([0-9]+(?:[.,][0-9]+)?) ([a-z/]+)$').firstMatch(s);
      final rephrased = RegExp(r'^nel compartimento ([a-z0-9_-]+), ([a-z0-9_-]+) ha una concentrazione di ([0-9]+(?:[.,][0-9]+)?) ([a-z/]+)$').firstMatch(s);
      final m = standard ?? rephrased;
      if (m == null) return unknown('una condizione non e interpretabile in questo modello: $clause');
      final substance = standard != null ? m[1]! : m[2]!;
      if (substance != solute) continue;
      final place = standard != null ? m[2]! : m[1]!;
      const units = {'mmol/l': 1.0, 'mm': 1.0, 'mol/l': 1000.0, 'umol/l': .001};
      final multiplier = units[m[4]];
      final value = double.tryParse(m[3]!.replaceAll(',', '.'));
      if (multiplier == null || value == null || !value.isFinite || !(value * multiplier).isFinite) {
        return unknown('le unita non sono confrontabili senza altre informazioni.');
      }
      final normalized = value * multiplier;
      if (values.containsKey(place) && values[place] != normalized) {
        return const TransportAnswer433('Non determinabile: le concentrazioni dello stesso compartimento sono IN CONFLITTO.', 'conflict');
      }
      values[place] = normalized;
      raw.add({'kind': 'concentration', 'text': clause, 'solute': solute, 'place': place,
        'value': value, 'unit': m[4], 'normalized': normalized, 'normalizedUnit': 'mmol/L'});
    }
    if (barrierConflict) return const TransportAnswer433('Non determinabile: la permeabilita della membrana e IN CONFLITTO.', 'conflict');
    if (!bounded) return unknown('specifica un soluto neutro in un sistema ideale a sola diffusione; altri meccanismi richiedono altri dati.');
    if (amount != null) return unknown('il principio letto indica il verso, ma non quantifica tempo, portata o massa trasferita.');
    if (permeable == null) return unknown('manca la permeabilita della membrana al soluto richiesto.');
    if (values.length != 2) return unknown('servono le concentrazioni dello stesso soluto in esattamente due compartimenti.');
    final places = values.keys.toList();
    final left = values[places[0]]!, right = values[places[1]]!;
    String? from, to;
    final zero = !permeable || left == right;
    if (!zero) {
      final forward = p.descending ? left > right : left < right;
      from = places[forward ? 0 : 1]; to = places[forward ? 1 : 0];
    }
    final result = {'solute': solute, 'from': from, 'to': to, 'netZero': zero};
    final proof = <String, dynamic>{'kind': 'quantitative_transfer',
      'mechanism': 'diffusion', 'ordering': p.descending ? 'descending' : 'ascending',
      'principle': p.source.toJson(), 'premises': raw, 'result': result};
    final conclusion = zero
        ? !permeable ? 'Flusso netto nullo: la membrana non lascia passare $solute.'
            : 'Flusso netto nullo: le concentrazioni di $solute sono uguali. Questa conclusione riguarda il saldo del trasferimento.'
        : 'Il flusso netto di $solute va da $from a $to.';
    return TransportAnswer433('$conclusion\n'
        '1. Ipotesi: sistema ideale a sola diffusione, soluto neutro; membrana ${permeable ? 'permeabile' : 'impermeabile'}.\n'
        '2. Concentrazioni confrontate: ${places[0]} = $left mmol/L; ${places[1]} = $right mmol/L.\n'
        '3. ${zero ? 'La barriera o il gradiente nullo escludono un trasferimento netto nel modello.' : 'Applico l’ordine tra le concentrazioni descritto nella lettura.'}\n'
        'Principio letto: ${p.source.text}\nFonte: ${p.source.title} · ${p.source.url}', 'true', proof);
  }
}
