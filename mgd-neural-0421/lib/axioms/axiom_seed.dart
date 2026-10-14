import 'axiom_core.dart';

/// Structural transcription of the supplied v03 checkpoint, not neural weights.
/// 13 role frames, 27 lexical couplings, 6 constructions, 6 action programs.
J axiomSeed() {
  Map slot(String n, [bool span = false]) => {
        'name': n,
        'minimum': 1,
        'maximum': span
            ? 24
            : n == 'predicate'
                ? 6
                : 1,
        'entity': !span && n != 'predicate'
      };
  List pattern(String s) => s
      .split(' ')
      .map((x) => x.startsWith(r'$') ? slot(x.substring(1)) : x)
      .toList();
  const layouts = <String, String>{
    '523d4b3b9a56': r'$who $predicate a $where',
    '1f4bc1119a94': r'$who $predicate $where',
    'cb9884e86b87': r'$who $predicate la $what',
    '18f8ff32c6f9': r'la $what viene $predicate da $who',
    'd7d750f2ab11': r'$who $predicate la $what a $to',
    '968a694edd9a': r'$to $predicate la $what da $who',
    '67fe6f1b1a33': r'la $what viene $predicate da $who a $to',
    '95172d4c2d26': r'$who $predicate della $what',
    '6f39dfd7d930': r'la $what $predicate a $who',
    '5dce0a22c88c': r'$who $predicate la $what a terra',
    'ec1bb8e686d4': r'la $what viene $predicate a terra da $who',
    '91bd38f50d9b': r'la proprietà della $what $predicate a $who',
    '003a1338994d': r'la $what $predicate $who',
  };
  final frames = layouts.entries.map((e) {
    final parts = pattern(e.value),
        roles = parts
            .whereType<Map>()
            .map((p) => p['name'] as String)
            .where((n) => n != 'predicate')
            .toList()
          ..sort();
    return {'id': 'frame:${e.key}', 'parts': parts, 'roles': roles};
  }).toList();
  const rows = [
    ['va', 'move', 0],
    ['si sposta', 'move', 0],
    ['raggiunge', 'move', 1],
    ['prende', 'pick', 2],
    ['raccoglie', 'pick', 2],
    ['presa', 'pick', 3],
    ['posa', 'drop', 2],
    ['lascia a terra', 'drop', 2],
    ['posata', 'drop', 3],
    ['consegna', 'give', 4],
    ['riceve', 'give', 5],
    ['consegnata', 'give', 6],
    ['ha la proprietà', 'own', 7],
    ['appartiene', 'own', 8],
    ['possiede', 'own', 2],
    ['arriva', 'move', 0],
    ['si reca', 'move', 0],
    ['afferra', 'pick', 2],
    ['raccolta', 'pick', 3],
    ['deposita', 'drop', 9],
    ['lasciata', 'drop', 10],
    ['passa fisicamente', 'give', 4],
    ['riceve in mano', 'give', 5],
    ['spetta', 'own', 11],
    ['è di proprietà di', 'own', 12],
    ['porge', 'give', 4],
    ['dona', 'donate', 4],
  ];
  final lexicon = rows
      .map((r) => {
            'surface': (r[0] as String).split(' '),
            'intent': r[1],
            'frame_id': frames[r[2] as int]['id'],
            'lesson_id': 'checkpoint-v03:${r[0]}'
          })
      .toList();
  final rules = <J>[
    {
      'id': 'rule:focus_preposition',
      'source': ['è', 'a', slot('v0'), 'che', slot('v1', true)],
      'target': [r'$v1', 'a', r'$v0']
    },
    {
      'id': 'rule:focus_object',
      'source': ['è', 'la', slot('v0'), 'che', slot('v1', true)],
      'target': [r'$v1', 'la', r'$v0']
    },
    {
      'id': 'rule:focus_subject',
      'source': ['è', slot('v0'), 'che', slot('v1', true)],
      'target': [r'$v0', r'$v1']
    },
    {
      'id': 'rule:fronted_preposition',
      'source': ['a', slot('v0'), ',', slot('v1', true)],
      'target': [r'$v1', 'a', r'$v0']
    },
    {
      'id': 'rule:argument_order',
      'source': [slot('v0', true), 'a', slot('v1'), 'la', slot('v2')],
      'target': [r'$v0', 'la', r'$v2', 'a', r'$v1']
    },
    {
      'id': 'rule:event_negation',
      'source': [slot('v0'), 'non', slot('v1', true)],
      'target': ['@not', r'$v0', r'$v1']
    },
  ];
  for (final r in rules) {
    r['lesson_ids'] = ['checkpoint-v03:${r['id']}'];
  }
  J arg(String s) => {'kind': 'arg', 'arg': s, 'relation': ''};
  J read(String r, String a) => {'kind': 'read', 'arg': a, 'relation': r};
  J nil() => {'kind': 'none', 'arg': '', 'relation': ''};
  J eq(J a, J b) => {'kind': 'eq', 'left': a, 'right': b};
  J known(J a) => {'kind': 'known', 'left': a, 'right': null};
  J write(String r, String a, J v) =>
      {'relation': r, 'target_arg': a, 'value': v};
  List<J> giveGuards() => [
        eq(arg('who'), read('holder', 'what')),
        eq(read('location', 'to'), read('location', 'who')),
        known(read('location', 'to'))
      ];
  return {
    'class': 'mgd_axiom_student_0430',
    'source':
        'Trascrizione strutturale del checkpoint sperimentale v03; non memoria neurale MGD.',
    'minimality_absolute_certified': false,
    'frames': frames,
    'lexicon': lexicon,
    'rules': rules,
    'programs': {
      'move': {
        'guards': [],
        'writes': [write('location', 'who', arg('where'))]
      },
      'pick': {
        'guards': [
          eq(read('location', 'what'), read('location', 'who')),
          known(read('location', 'who'))
        ],
        'writes': [
          write('holder', 'what', arg('who')),
          write('location', 'what', nil())
        ]
      },
      'drop': {
        'guards': [
          eq(arg('who'), read('holder', 'what')),
          known(read('location', 'who'))
        ],
        'writes': [
          write('holder', 'what', nil()),
          write('location', 'what', read('location', 'who'))
        ]
      },
      'give': {
        'guards': giveGuards(),
        'writes': [write('holder', 'what', arg('to'))]
      },
      'own': {
        'guards': [],
        'writes': [write('owner', 'what', arg('who'))]
      },
      'donate': {
        'guards': giveGuards(),
        'writes': [
          write('holder', 'what', arg('to')),
          write('owner', 'what', arg('to'))
        ]
      },
    },
    'lesson_ids': lexicon.map((l) => l['lesson_id']).toList(),
  };
}

/// Expected states are specified here, never labelled by the student or the LLM.
/// These are public regression cases, not a hidden or independent final benchmark.
List<J> axiomRegression() {
  final out = <J>[];
  const people = ['luca', 'sofia', 'vittorio', 'anna', 'marco', 'elena'];
  const places = ['roma', 'pisa', 'torino', 'milano', 'bari', 'genova'];
  void put(String text, String intent, J args, J before, J after,
      {String status = 'applied', bool neg = false}) {
    out.add({
      'id': 'reg-${out.length}',
      'text': text,
      'intent': intent,
      'args': args,
      'negated': neg,
      'before': copyJ(before),
      'expected_after': copyJ(after),
      'expected_status': status
    });
  }

  for (var i = 0; i < people.length; i++) {
    final who = people[i],
        to = people[(i + 1) % people.length],
        city = places[i],
        dest = places[(i + 2) % places.length];
    final held = <String, dynamic>{
      'location': {who: city, to: city, 'chiave': null},
      'holder': {'chiave': who},
      'owner': {'chiave': who}
    };
    final ground = copyJ(held);
    ground['location']['chiave'] = city;
    ground['holder']['chiave'] = null;
    for (final verb in ['va', 'arriva', 'si reca', 'si sposta']) {
      for (final text in [
        '$who $verb a $dest.',
        'È a $dest che $who $verb.',
        'A $dest, $who $verb.',
        'È $who che $verb a $dest.'
      ]) {
        final after = copyJ(held);
        after['location'][who] = dest;
        put(text, 'move', {'who': who, 'where': dest}, held, after);
      }
    }
    for (final spec in [
      ['consegna', 'give'],
      ['porge', 'give'],
      ['dona', 'donate'],
      ['passa fisicamente', 'give']
    ]) {
      final verb = spec[0],
          intent = spec[1],
          args = <String, dynamic>{'who': who, 'what': 'chiave', 'to': to};
      final after = copyJ(held);
      after['holder']['chiave'] = to;
      if (intent == 'donate') after['owner']['chiave'] = to;
      for (final text in [
        '$who $verb la chiave a $to.',
        'È la chiave che $who $verb a $to.',
        'È a $to che $who $verb la chiave.'
      ]) {
        put(text, intent, args, held, after);
      }
      put('È la chiave che $who non $verb a $to.', intent, args, held, held,
          status: 'event_denied_no_update', neg: true);
      final far = copyJ(held);
      far['location'][to] = dest;
      put('$who $verb la chiave a $to.', intent, args, far, far,
          status: 'preconditions_false');
      final missing = copyJ(held);
      (missing['location'] as Map).remove(to);
      put('$who $verb la chiave a $to.', intent, args, missing, missing,
          status: 'needs_context');
    }
    for (final verb in ['prende', 'raccoglie', 'afferra']) {
      final after = copyJ(ground);
      after['holder']['chiave'] = who;
      after['location']['chiave'] = null;
      put('$who $verb la chiave.', 'pick', {'who': who, 'what': 'chiave'},
          ground, after);
    }
    final afterDrop = copyJ(held);
    afterDrop['holder']['chiave'] = null;
    afterDrop['location']['chiave'] = city;
    put('$who posa la chiave.', 'drop', {'who': who, 'what': 'chiave'}, held,
        afterDrop);
    put('$who deposita la chiave a terra.', 'drop',
        {'who': who, 'what': 'chiave'}, held, afterDrop);
    final otherOwner = copyJ(held);
    otherOwner['owner']['chiave'] = to;
    put('La chiave appartiene a $to.', 'own', {'who': to, 'what': 'chiave'},
        held, otherOwner);
  }
  return out;
}

const axiomTeacherContract = r'''
Sei l'insegnante del discepolo simbolico MGD. NON rispondere al suo posto.
1. Un assioma candidato va scomposto usando la base nota (bind/read/eq/neq/known/null/write), se possibile. Una parola, una frase o un programma composto NON sono primitive. Non puoi certificare minimalità assoluta.
2. Individua significati, costruzioni, composizioni e fatti contestuali necessari. Confrontali con l'inventario. Se bastano, non insegnare duplicati: correggi la composizione. Se manca un fatto, chiedilo; non inventare un assioma. Se manca una primitiva non rappresentabile, lascia una richiesta di estensione aperta.
3. Produci 1–4 lezioni e 3–24 prove formative, con frasi diverse da quelle insegnate, almeno tre combinazioni di ruoli; prova negazioni e cambi di contesto. Il validatore mantiene anche regressioni non mostrate qui.
OBBLIGATORIO: aggiungi un campo task con text IDENTICO alla richiesta, intent, args, negated. Se è disponibile il mondo before, aggiungi expected_after ed expected_status senza cambiare before. Tutte le probes devono avere before, expected_after ed expected_status e almeno una deve negare l'evento o mostrare precondizioni false o contesto mancante. Non basta riconoscere una frase.
Restituisci SOLO un oggetto JSON, senza markdown, nel formato:
{"diagnosis":"lacuna / componenti conosciuti / necessari / decomposizione","lessons":[{"kind":"anchored","id":"lesson-unique","text":"Luca giunge a Roma.","anchor":"giunge","intent":"move","args":{"who":"luca","where":"roma"}}],"probes":[{"id":"probe-unique","text":"Anna giunge a Pisa.","intent":"move","args":{"who":"anna","where":"pisa"},"negated":false}]}
Gli esempi del formato NON costituiscono un pacchetto completo: devi produrre almeno tre prove realmente diverse per la richiesta dell'utente.
Lezioni per costruzioni: {"kind":"rewrite","id":"...","rule":{"id":"rule:nuova","source":[letterali o {"name":"v0","minimum":1,"maximum":1,"entity":true}],"target":["$v0",letterali]},"equivalences":[{"source":"...","target":"..."},{"source":"...","target":"..."}]}. Ogni variabile deve comparire esattamente una volta nel target e variare fra i due esempi. Le equivalenze rappresentano la stessa informazione.
Lezioni semantiche: {"kind":"program","id":"...","intent":"...","program":{"guards":[{"kind":"eq","left":{"kind":"arg","arg":"who"},"right":{"kind":"read","relation":"holder","arg":"what"}}],"writes":[{"relation":"holder","target_arg":"what","value":{"kind":"arg","arg":"to"}}]}}. Relazioni ammesse: location, holder, owner. Espressioni arg/read/none. Guardie eq/neq/known (known ha solo left). Vietati codice eseguibile, nuovi operatori e chiamate esterne. Le guardie e i valori si leggono dal mondo precedente; le scritture sono simultanee.
Le prove di programmi devono includere before ed expected_after (mappe location/holder/owner), expected_status applied/preconditions_false/needs_context/event_denied_no_update, almeno una precondizione falsa o un fatto mancante. Non trattare holder (detenzione fisica) e owner (proprietà) come sinonimi. Donare significa qui, solo nel simulatore, consegna più cambio proprietario.
Le proposte verranno respinte se duplicano conoscenza, non generalizzano nelle prove o peggiorano risposte corrette. Il loro successo è formativo, NON prova indipendente di verità, comprensione generale o minimalità assoluta.
''';
