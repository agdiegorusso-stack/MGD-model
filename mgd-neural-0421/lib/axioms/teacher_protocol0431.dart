import 'dart:convert';
import 'axiom_core.dart';

/// Format validation only. It never obtains expected labels from the student.
J decodeTeacher0431(String raw) {
  if (raw.length > 120000) {
    throw const FormatException('Risposta oltre 120000 caratteri.');
  }
  var text = raw.trim();
  if (text.startsWith('```')) {
    final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$',
        caseSensitive: false).firstMatch(text);
    if (fence == null) {
      throw const FormatException('Blocco JSON incompleto.');
    }
    text = fence.group(1)!;
  }
  final value = jsonDecode(text);
  if (value is! Map) {
    throw const FormatException('Serve un oggetto JSON, non una lista.');
  }
  return copyJ(value);
}

List<String> teacherProblems0431(J p, String request, J world) {
  final problems = <String>[];
  void checkProbe(dynamic q, String path, {bool target = false}) {
    if (q is! Map) {
      problems.add('$path: manca un oggetto con text, intent, args, negated, '
          'before, expected_after, expected_status.');
      return;
    }
    for (final k in ['text', 'intent', 'expected_status']) {
      if (q[k] is! String || (q[k] as String).isEmpty) {
        problems.add('$path.$k: stringa obbligatoria.');
      }
    }
    if (q['args'] is! Map || (q['args'] as Map).isEmpty ||
        !(q['args'] as Map).values.every((v) => v is String && entity(v))) {
      problems.add('$path.args: ruoli con valori testuali obbligatori.');
    }
    if (q['negated'] is! bool) {
      problems.add('$path.negated: booleano obbligatorio.');
    }
    if (q['expected_status'] is String && !const [
      'applied', 'preconditions_false', 'needs_context',
      'event_denied_no_update'
    ].contains(q['expected_status'])) {
      problems.add('$path.expected_status: usare uno stato operativo ammesso.');
    }
    if (target && q['text'] != request) {
      problems.add('task.text: copiare esattamente la richiesta, non una frase alternativa.');
    }
    // The user's observation, never the teacher's replacement, binds the target.
    final before = target ? world : q['before'];
    if (target && q['before'] != null && !equalJ(q['before'], world)) {
      problems.add('task.before: non modificare il contesto osservato.');
    }
    if (before is! Map || q['expected_after'] is! Map) {
      problems.add('$path: before ed expected_after devono essere mondi completi.');
      return;
    }
    final after = q['expected_after'] as Map;
    for (final relation in ['location', 'holder', 'owner']) {
      if (before[relation] is! Map || after[relation] is! Map) {
        problems.add('$path: includere le mappe $relation in before ed expected_after.');
        continue;
      }
      for (final key in (before[relation] as Map).keys) {
        if (!(after[relation] as Map).containsKey(key)) {
          problems.add('$path.expected_after.$relation.$key: fatto eliminato. '
              'Copia tutto before e cambia solo gli effetti previsti; non usare un delta.');
        }
      }
    }
  }

  checkProbe(p['task'], 'task', target: true);
  final lessons = p['lessons'];
  if (lessons is! List || lessons.isEmpty || lessons.length > 4) {
    problems.add('lessons: fornire da 1 a 4 lezioni, non risposte al posto del discepolo.');
  } else {
    for (var i = 0; i < lessons.length; i++) {
      final lesson = lessons[i];
      if (lesson is! Map || lesson['kind'] is! String ||
          lesson['id'] is! String) {
        problems.add('lessons[$i]: kind e id obbligatori.');
      }
    }
  }
  final probes = p['probes'];
  if (probes is! List || probes.length < 3 || probes.length > 24) {
    problems.add('probes: servono da 3 a 24 prove, almeno tre combinazioni di ruoli.');
  } else {
    for (var i = 0; i < probes.length; i++) {
      checkProbe(probes[i], 'probes[$i]');
      if (probes[i] is Map && probes[i]['text'] is String &&
          canonical(axTokens(probes[i]['text'] as String)) ==
              canonical(axTokens(request))) {
        problems.add('probes[$i].text: deve essere diverso anche dal task originale.');
      }
    }
  }
  return problems.take(12).toList();
}

String teachingReason0431(J assessment) {
  final details = <String>[];
  for (final attempt in assessment['attempts'] as List? ?? []) {
    if (attempt['error'] != null) details.add('${attempt['error']}');
    for (final failure in attempt['failures'] as List? ?? []) {
      details.add(jsonEncode(failure));
      if (details.length >= 2) break;
    }
    if (details.length >= 2) break;
  }
  return '${assessment['reason'] ?? 'Proposta non accettata.'}'
      '${details.isEmpty ? '' : '\nDettaglio: ${details.join('\n')}'}';
}

/// A complete, executable FORMAT example: it is never applied as a lesson.
/// Deliberately uses a different verb from the app's demonstration request.
J teacherFormatExample0431() {
  J probe(String id, String who, String where, String text,
      {bool negated = false}) {
    final before = <String, dynamic>{
      'location': {who: 'pisa', 'elio': 'pisa'},
      'holder': {'mappa': who},
      'owner': {'mappa': 'elio'}
    };
    final after = copyJ(before);
    if (!negated) after['location'][who] = where;
    return {
      'id': id, 'text': text, 'intent': 'move',
      'args': {'who': who, 'where': where}, 'negated': negated,
      'before': before, 'expected_after': after,
      'expected_status': negated ? 'event_denied_no_update' : 'applied'
    };
  }
  return {
    'diagnosis': 'ESEMPIO DI FORMATO: move è composto e noto; '
        'qui si insegna un collegamento linguistico, non una primitiva.',
    'task': probe('target', 'irene', 'roma', 'Irene viaggia verso Roma.'),
    'lessons': [{
      'kind': 'anchored', 'id': 'format-example-viaggia',
      'text': 'Nora viaggia verso Bari.', 'anchor': 'viaggia',
      'intent': 'move', 'args': {'who': 'nora', 'where': 'bari'}
    }],
    'probes': [
      probe('p1', 'dario', 'milano', 'Dario viaggia verso Milano.'),
      probe('p2', 'elena', 'torino', 'È Elena che viaggia verso Torino.'),
      probe('p3', 'marta', 'genova', 'Marta non viaggia verso Genova.', negated: true)
    ]
  };
}

String get axiomTeacherContract0431 => r'''
Sei l'insegnante del discepolo simbolico MGD, non il suo sostituto.
Esamina l'intero inventory. Una parola nuova non è un assioma nuovo: se il
significato è esprimibile con programmi e ruoli noti, insegna il collegamento.
Un candidato composto va scomposto; non certificare minimalità assoluta.
Distingui lessico mancante, costruzione, composizione e fatti contestuali assenti.
Non inventare un fatto o una primitiva per colmare un contesto sconosciuto.
Non aggiungere duplicati. Usa la più piccola proposta che supera il compito E
nuove prove. Non chiamare comprensione generale il superamento di queste prove.

Rispondi SOLO con un oggetto JSON completo e compatto, nessun markdown.
Campi obbligatori: diagnosis (breve), task, lessons (1-4), probes (3-24).
Ogni task/probe deve avere text, intent, args, negated (booleano), before,
expected_after, expected_status. task.text DEVE essere IDENTICO a request.
task.before DEVE essere IDENTICO a context. Non riusare i nomi dell'esempio.
expected_after è un MONDO COMPLETO: copia before, poi modifica soltanto gli
effetti previsti. Conserva persone, oggetti e relazioni non modificati; anche
holder e owner. NON fornire solo location, NON eliminare altre persone o oggetti.
Con negated=true l'evento non viene applicato: expected_after=before e
expected_status="event_denied_no_update". Non inventare un evento opposto.
Stati: applied, preconditions_false, needs_context, event_denied_no_update.
Le probes devono differire da task e lezioni e variare almeno tre assegnazioni
di ruoli. Almeno una prova deve essere negata o avere precondizioni false o
contesto mancante. Scrivi tre prove piccole ma COMPLETE, non tante incomplete.
Se feedback contiene errori, correggi ESATTAMENTE quei campi mantenendo la richiesta.

Lezioni lessicali: {"kind":"anchored","id":"nuovo-id","text":"...",
"anchor":"predicato","intent":"programma-noto","args":{"who":"...","where":"..."}}.
Il testo di una lezione anchored deve essere canonico, ruoli distinti e ciascuno
presente una volta. Scegli intent e ruoli dall'inventario, non inventare nomi.
Lezioni di costruzione: {"kind":"rewrite","id":"...","rule":{"id":"rule:nuova",
"source":[letterali o {"name":"v0","minimum":1,"maximum":1,"entity":true}],
"target":["$v0",letterali]},"equivalences":[{"source":"...","target":"..."},
{"source":"...","target":"..."}]}.
Ogni variabile una volta nel target; tutte le variabili devono variare fra i due esempi.
Lezioni semantiche: {"kind":"program","id":"...","intent":"...","program":
{"guards":[{"kind":"eq","left":{"kind":"arg","arg":"who"},
"right":{"kind":"read","relation":"holder","arg":"what"}}],
"writes":[{"relation":"holder","target_arg":"what","value":{"kind":"arg","arg":"to"}}]}}.
Relazioni location/holder/owner; espressioni arg/read/none; guardie eq/neq/known.
known ha solo left. Letture dal mondo precedente, scritture simultanee.
Per nuovi programmi servono transizioni e almeno un contesto mancante o falso.
Detenzione fisica e proprietà sono diverse. Donare significa, SOLO in questo
simulatore, consegna più cambio proprietario. Non proporre codice eseguibile.
Se la richiesta non è rappresentabile, restituisci diagnosis con la lacuna,
lessons:[] e probes:[]; la richiesta di estensione resta aperta, non è un successo.

Il seguente oggetto è SOLTANTO un esempio COMPLETO del formato. NON copiarne il
task, le lezioni o le risposte quando non sono pertinenti alla richiesta:
''' + jsonEncode(teacherFormatExample0431());
