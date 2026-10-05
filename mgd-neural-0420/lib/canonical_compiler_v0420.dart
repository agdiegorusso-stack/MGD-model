import 'book_understanding_v0342.dart';
import 'competence_language_v0350.dart';
import 'narrative_memory_v0350.dart';

/// Conservative, source-backed compilation. Unsupported input is kept intact
/// by the store. This finite grammar is not a general language model.
Map<String, dynamic> compileCanonical420(Map<String, dynamic> request) {
  final compiler = NarrativeCompiler350(
      Map<String, dynamic>.from(request['state'] as Map? ?? {}));
  final text = '${request['text']}', unit = '${request['unit']}';
  final ordinal = request['ordinal'] as int;
  if (request['safe'] == false) {
    compiler.clearDiscourse();
    return CompiledUnit350(unit, ordinal, text.length, 1, [],
        CompetenceLanguage350.observeFragment(text),
        {'overlong_fragment': 1}, compiler.state()).toJson();
  }
  final sentences = text.split(RegExp(r'(?<=[.!?])\s+|\n+'));
  final events = <Map<String, dynamic>>[], issues = <String, int>{};
  final usage = <String, Map<String, int>>{};
  for (final original in sentences.where((s) => s.trim().isNotEmpty)) {
    var sentence = original.trim();
    // Remove a completed temporal adjunct only when an explicit main subject
    // follows. No conditions, reported beliefs or alternative clauses removed.
    final adjunct = RegExp(
      r'^Dopo aver [^,;?]+,\s*([A-ZÀÈÉÌÒÙ][a-zàèéìòù]+\s+.+)$');
    sentence = adjunct.firstMatch(sentence)?[1] ?? sentence;
    sentence = sentence.replaceFirst(
      RegExp(r'\s+prima di (?:salutare|partire|uscire)\b[^.!?]*'), '');
    sentence = sentence.replaceFirst(
      RegExp(r'\s+che aveva trovato[.!]?$'), '.');
    // Reordering must not move a sentence terminator into the middle of a
    // clause: that would split the recipient off as a separate sentence.
    sentence = sentence.replaceAll(RegExp(r'[.!]+$'), '').trim();
    // Recipient before the object is a distinct finite construction.
    final gift = RegExp(
      r'^([A-ZÀÈÉÌÒÙ][a-zàèéìòù]+)\s+(consegnò|consegna|consegnava)\s+a\s+([A-ZÀÈÉÌÒÙ][a-zàèéìòù]+)\s+((?:il|la|lo|una|un)\s+.+)$')
      .firstMatch(sentence);
    if (gift != null) {
      sentence = '${gift[1]} ${gift[2]} ${gift[4]} a ${gift[3]}';
    }
    final part = compiler.compile(sentence,
        unitOrdinal: ordinal, unitId: unit).toJson();
    events.addAll((part['events'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map)));
    for (final e in (part['issues'] as Map).entries) {
      issues['${e.key}'] = (issues['${e.key}'] ?? 0) + (e.value as num).toInt();
    }
    for (final kind in (part['language'] as Map).entries) {
      final target = usage.putIfAbsent('${kind.key}', () => {});
      for (final e in (kind.value as Map).entries) {
        target['${e.key}'] = (target['${e.key}'] ?? 0) + (e.value as num).toInt();
      }
    }
    final normalized = bookNorm342(original).replaceAll(RegExp(r'[.!]+$'), '');
    void add(String subject, String predicate, String object,
        {String kind = 'fact', List<String> links = const []}) {
      final n = compiler.nextOrdinal++;
      events.add(Event350(id: '$unit:$n', unit: unit, ordinal: n,
          subject: bookEntity342(subject), predicate: predicate,
          object: bookEntity342(object), surface: predicate, kind: kind,
          links: links, resolution: 'finite_explicit_construction').toJson());
    }
    final color = RegExp(
      r'^[a-zàèéìòù]+\s+(?:osservò|osserva|vide|vede)\s+(?:il|la|lo|una|un)\s+([a-zàèéìòù]+)\s+(ross[oa]|blu|verd[ei]|giall[oa]|ner[oa]|bianc[oa])(?:\s+(?:accanto|vicino)\s+.+)?$')
      .firstMatch(normalized);
    if (color != null) add(color[1]!, 'colore', color[2]!);
    final quantity = RegExp(
      r'^(?:il|la)\s+([a-zàèéìòù]+)\s+(?:ospitava|conteneva)\s+(\d+|uno|due|tre|quattro|cinque|sei|sette|otto|nove|dieci)\s+([a-zàèéìòù]+),\s+ma\s+(\d+|uno|due|tre|quattro|cinque|sei|sette|otto|nove|dieci)\s+furono trasferit[ei]\s+(?:al|alla|nel|nella)\s+[a-zàèéìòù]+$')
      .firstMatch(normalized);
    if (quantity != null) {
      final a = number420(quantity[2]!); final b = number420(quantity[4]!);
      if (a != null && b != null && b <= a) {
        add(quantity[1]!, 'quantità_residua', '${a - b} ${quantity[3]}',
            kind: 'calculation');
      }
    }
  }
  return {'hash': unit, 'ordinal': ordinal, 'characters': text.length,
    'sentences': sentences.where((s) => s.trim().isNotEmpty).length,
    'events': events, 'language': usage, 'issues': issues,
    'discourse': compiler.state()};
}

int? number420(String value) => int.tryParse(value) ?? const {
  'uno': 1, 'due': 2, 'tre': 3, 'quattro': 4, 'cinque': 5,
  'sei': 6, 'sette': 7, 'otto': 8, 'nove': 9, 'dieci': 10,
}[value];
