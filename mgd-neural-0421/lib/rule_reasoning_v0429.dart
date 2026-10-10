import 'web_knowledge_explorer_v11.dart';

/// A small, explicit logic interpreter over retained sentences. It has no
/// answer keys, domain identifiers, stochastic scorer or closed-world default.
/// Unsupported language remains source text; it is never promoted to a rule.
class LogicAtom429 {
  final String predicate;
  final List<String> args;
  final bool positive;
  const LogicAtom429(this.predicate, this.args, [this.positive = true]);
  String get key => '$predicate(${args.join('|')})';
  String get signedKey => '${positive ? '+' : '-'}$key';
  LogicAtom429 get opposite => LogicAtom429(predicate, args, !positive);
  LogicAtom429 bind(String value) => LogicAtom429(predicate,
      args.map((a) => a == r'$x' ? value : a).toList(), positive);
  bool get variable => args.contains(r'$x');
  String get label {
    final verb = predicate == 'stato' ? 'è' : predicate == 'tipo' ? 'è un'
        : predicate == 'entra' ? 'entra in' : predicate;
    return '${args.first} ${positive ? '' : 'non '}$verb ${args.skip(1).join(' ')}';
  }

}

class LogicSource429 {
  final String id, text, title, url;
  const LogicSource429(this.id, this.text, this.title, this.url);
  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'title': title, 'url': url};
}

class LogicRule429 {
  final String id;
  final List<LogicAtom429> body;
  final LogicAtom429 head;
  final LogicSource429 source;
  const LogicRule429(this.id, this.body, this.head, this.source);
}

class LogicProof429 {
  final LogicAtom429 conclusion;
  final LogicSource429? source;
  final LogicRule429? rule;
  final String? binding;
  final List<LogicProof429> premises;
  final bool assumption;
  const LogicProof429(this.conclusion, {this.source, this.rule, this.binding,
      this.premises = const [], this.assumption = false});
  Map<String, dynamic> toJson() => {
    'conclusion': conclusion.signedKey, 'assumption': assumption,
    if (source != null) 'source': source!.toJson(),
    if (rule != null) ...{'ruleId': rule!.id, 'rule': rule!.source.toJson(),
      'binding': binding},
    'premises': premises.map((p) => p.toJson()).toList(),
  };
}

class LogicProgram429 {
  final List<LogicProof429> facts = [];
  final List<LogicRule429> rules = [];
  final Set<String> entities = {};
  void fact(LogicAtom429 atom, LogicSource429 source) {
    facts.add(LogicProof429(atom, source: source));
    entities.addAll(atom.args.where((a) => a != r'$x'));
  }
}

class LogicAnswer429 {
  final String truth, text;
  final LogicProof429? proof;
  const LogicAnswer429(this.truth, this.text, [this.proof]);
}

class RuleReasoning429 {
  static String norm(String s) => s.toLowerCase().replaceAll('è', 'e')
      .replaceAll('é', 'e').replaceAll('ì', 'i').replaceAll('à', 'a')
      .replaceAll('ò', 'o').replaceAll('ù', 'u')
      .replaceAll(RegExp(r'\s+'), ' ').trim();
  static String _entity(String s) => norm(s)
      .replaceFirst(RegExp(r'^(il|lo|la|un|uno|una|l[’\x27])\s*'), '').trim();
  static bool _name(String s) => s == r'$x' ||
      RegExp(r'^[a-z0-9][a-z0-9_ -]{0,90}$').hasMatch(s) &&
      !RegExp(r'\b(e|o|se|quando|che|oppure|salvo|eccetto)\b').hasMatch(s);
  static String _clean(String s) => norm(s).replaceFirst(RegExp(r'[.!?;]+$'), '')
      .replaceFirst(RegExp(r'^(nel modello|in questo mondo simulato),?\s*'), '').trim();

  /// Negation is a signed atom, not failure to find a positive atom. Only
  /// explicit lexical opposites are collapsed onto the same property.
  static LogicAtom429? atom(String input, {bool variable = false}) {
    var s = _clean(input);
    if (RegExp(r'^(quanto|quale|quali|chi|che cosa|come|dove|perche|qual e) ').hasMatch(s)) return null;
    if (variable) {
      s = s.replaceAll(RegExp(r'\b(al suo interno|in essa|in esso)\b'), r'in $x')
          .replaceAll(RegExp(r'\b(essa|esso)\b'), r'$x');
      s = s.replaceFirst(RegExp(r'^ogni [a-z]+(?: di questo modello)?\s+'), r'$x ');
    }
    final named = RegExp(r'^una? [a-z]+ nuova?, ([a-z0-9_ -]+), (.+)$').firstMatch(s);
    if (named != null) s = '${named[1]} ${named[2]}';
    var m = RegExp(r'^(.+?) (non )?e (?:un|uno|una) ([a-z0-9_-]+)$').firstMatch(s);
    if (m != null && _name(_entity(m[1]!))) {
      return LogicAtom429('tipo', [_entity(m[1]!), m[3]!], m[2] == null);
    }
    m = RegExp(r'^(.+?) (non )?(contiene|possiede|ha) (.+)$').firstMatch(s);
    if (m != null) {
      final a = _entity(m[1]!), b = _entity(m[4]!);
      if (_name(a) && _name(b)) return LogicAtom429('contiene', [a, b], m[2] == null);
    }
    m = RegExp(r'^(.+?) (non )?(entra|penetra) (?:in|nel|nella) (.+)$').firstMatch(s);
    if (m != null) {
      final a = _entity(m[1]!), b = _entity(m[4]!);
      if (_name(a) && _name(b)) return LogicAtom429('entra', [a, b], m[2] == null);
    }
    m = RegExp(r'^(.+?) (non )?(e|diventa|rimane|risulta) ([a-z0-9_-]+)$').firstMatch(s);
    if (m != null) {
      final a = _entity(m[1]!);
      if (!_name(a)) return null;
      var value = m[4]!, positive = m[2] == null;
      const gender = {'aperta': 'aperto', 'chiusa': 'chiuso', 'accesa': 'acceso',
        'spenta': 'spento', 'attiva': 'attivo', 'inattiva': 'inattivo',
        'pronta': 'pronto', 'luminosa': 'luminoso'};
      value = gender[value] ?? value;
      const opposites = {'assente': 'presente', 'spento': 'acceso',
        'chiuso': 'aperto', 'inattivo': 'attivo', 'falso': 'vero'};
      if (opposites.containsKey(value)) { value = opposites[value]!; positive = !positive; }
      return LogicAtom429('stato', [a, value], positive);
    }
    // Generic simple transitive verbs, including fictional relations. Modal,
    // disjunctive, quantified and qualified prose is deliberately rejected.
    m = RegExp(r'^([a-z0-9_-]+) (non )?([a-z]+) ([a-z0-9_-]+)$').firstMatch(s);
    if (m != null && !{'puo', 'potrebbe', 'deve', 'ogni', 'tutti', 'se', 'quando',
        'sono', 'sarebbe', 'era', 'forse', 'generalmente'}.contains(m[3])) {
      return LogicAtom429(m[3]!, [m[1]!, m[4]!], m[2] == null);
    }
    return null;
  }

  static List<LogicAtom429>? _body(String text, {bool variable = false}) {
    // The Italian "e" can be a conjunction or the normalized copula "è".
    // Split only when both resulting clauses parse completely as atoms.
    final whole = atom(text, variable: variable);
    if (whole != null) return [whole];
    for (final conjunction in RegExp(r'\s+e\s+').allMatches(text)) {
      final left = atom(text.substring(0, conjunction.start), variable: variable);
      if (left == null) continue;
      final right = _body(text.substring(conjunction.end), variable: variable);
      if (right != null) return [left, ...right];
    }
    return null;
  }

  static void _conditional(LogicProgram429 p, LogicSource429 source,
      LogicAtom429 head, List<LogicAtom429> conditions, {bool iff = false,
      List<LogicAtom429> guards = const [], bool allowNegative = true}) {
    void add(List<LogicAtom429> body, LogicAtom429 result) => p.rules.add(
        LogicRule429('${source.id}:${p.rules.length}', body, result, source));
    add([...guards, ...conditions], head);
    if (!iff) return;
    for (final condition in conditions) {
      add([...guards, head], condition);
      if (allowNegative) add([...guards, condition.opposite], head.opposite);
    }
    if (conditions.length == 1 && allowNegative) {
      add([...guards, head.opposite], conditions.single.opposite);
    }
  }

  static LogicProgram429 parse(List<LogicSource429> sources) {
    final p = LogicProgram429();
    // Exclusivity is local to the retained document; never inferred from an
    // absent alternative. Without it a disabled channel cannot exclude others.
    final exclusive = sources.where((s) => RegExp(
        r'^tutte le [a-z]+ di questo modello hanno soltanto questo ingresso$')
        .hasMatch(_clean(s.text))).map((s) => s.url).toSet();
    for (final source in sources) {
      final s = _clean(source.text);
      if (s.contains(RegExp(r'\b(puo|potrebbe|forse|generalmente|normalmente|probabilmente)\b'))) continue;
      var m = RegExp(r'^(.+?) fa entrare (.+?) in ogni ([a-z]+) che lo contiene se e solo se (.+)$').firstMatch(s);
      if (m != null) {
        final channel = _entity(m[1]!), cargo = _entity(m[2]!);
        final condition = atom(m[4]!);
        if (_name(channel) && _name(cargo) && condition != null) {
          _conditional(p, source, LogicAtom429('entra', [cargo, r'$x']), [condition],
              guards: [LogicAtom429('contiene', [r'$x', channel])],
              iff: exclusive.contains(source.url));
        }
        continue;
      }
      m = RegExp(r'^se (.+?),? allora (.+)$').firstMatch(s);
      if (m != null) {
        final conditions = _body(m[1]!.replaceFirst(RegExp(r',$'), ''));
        final head = atom(m[2]!);
        if (conditions != null && head != null) _conditional(p, source, head, conditions);
        continue;
      }
      m = RegExp(r'^(.+?) (se e solo se|se|quando) (.+)$').firstMatch(s);
      if (m != null) {
        final universal = m[1]!.startsWith('ogni ');
        final head = atom(m[1]!, variable: universal);
        final conditions = _body(m[3]!, variable: universal);
        if (head != null && conditions != null) {
          final type = universal && !m[1]!.contains('di questo modello')
              ? m[1]!.split(' ')[1] : null;
          _conditional(p, source, head, conditions, iff: m[2] == 'se e solo se',
              guards: type == null ? [] : [LogicAtom429('tipo', [r'$x', type])]);
        }
        continue;
      }
      // Universal guarded rules: "Ogni robot che contiene X diventa Y".
      m = RegExp(r'^ogni ([a-z]+) che (contiene|possiede|ha) (.+?) (diventa|e|rimane) ([a-z0-9_-]+)$').firstMatch(s);
      if (m != null) {
        final body = atom(r'$x ' + '${m[2]} ${m[3]}');
        final head = atom(r'$x ' + '${m[4]} ${m[5]}');
        if (body != null && head != null) _conditional(p, source, head, [body],
            guards: [LogicAtom429('tipo', [r'$x', m[1]!])]);
        continue;
      }
      // Reject an unparsed connective rather than extract an unconditional
      // fragment of a conditional, definition or negated quantifier.
      if (s.contains(RegExp(r'\b(se|quando|ogni|tutte|nessun|oppure|o|salvo|eccetto)\b'))) continue;
      final a = atom(s);
      if (a != null) p.fact(a, source);
    }
    return p;
  }

  /// Pure read: query/assessment never recovers, writes or learns source rows.
  static List<LogicSource429> sources(ResearchMemory11 memory) {
    final blocked = <String>{};
    for (final c in memory.claims.values) {
      if (c.conflict || {'quarantena', 'rifiutata', 'ritirata'}.contains(c.status)) {
        blocked.addAll(memory.evidence.where((e) => c.evidenceIds.contains(e.id)).map((e) => e.sourceUrl));
      }
    }
    final state = memory.state317['sourceMemory323'];
    final rows = state is Map ? state['rows'] : null;
    if (rows is Map) return rows.values.whereType<Map>()
        .where((r) => !blocked.contains(r['url']))
        .map((r) => LogicSource429('${r['id']}', '${r['text']}', '${r['title']}', '${r['url']}')).toList();
    final out = <LogicSource429>[];
    for (final d in ResearchSemantics317.uniqueDocuments320(memory)) {
      final doc = ResearchSemantics317.docFrom(d);
      if (blocked.contains(doc.url)) continue;
      for (final sentence in doc.text.split(RegExp(r'(?<=[.!?])\s+|\n+'))) {
        out.add(LogicSource429(ResearchSemantics317.digest([doc.url, sentence]),
            sentence, doc.title, doc.url));
      }
    }
    return out;
  }

  static bool validate(LogicProof429 proof, LogicProgram429 program,
      List<LogicAtom429> assumptions, {Set<LogicProof429>? visiting}) {
    final path = visiting ?? <LogicProof429>{};
    if (!path.add(proof)) return false;
    bool valid;
    if (proof.assumption) {
      valid = proof.source == null && proof.rule == null && proof.premises.isEmpty &&
          assumptions.any((a) => a.signedKey == proof.conclusion.signedKey);
    } else if (proof.rule == null) {
      valid = proof.premises.isEmpty && program.facts.any((p) => p.source?.id == proof.source?.id &&
          p.source?.text == proof.source?.text && p.source?.url == proof.source?.url &&
          p.conclusion.signedKey == proof.conclusion.signedKey);
    } else {
      final rule = proof.rule!;
      valid = program.rules.any((r) => identical(r, rule)) &&
          (!rule.head.variable || proof.binding != null) &&
          rule.head.bind(proof.binding ?? '').signedKey == proof.conclusion.signedKey &&
          rule.body.length == proof.premises.length;
      if (valid) for (var i = 0; i < rule.body.length; i++) {
        if (rule.body[i].bind(proof.binding ?? '').signedKey != proof.premises[i].conclusion.signedKey ||
            !validate(proof.premises[i], program, assumptions, visiting: path)) { valid = false; break; }
      }
    }
    path.remove(proof);
    return valid;
  }

  static LogicAnswer429 solve(LogicProgram429 program, LogicAtom429 target,
      List<LogicAtom429> assumptions, {int maxFacts = 4096, int maxWork = 100000}) {
    final known = <String, LogicProof429>{};
    // Backward dependency slicing binds variables against the requested
    // conclusion. Unrelated documents/conflicts cannot poison a prediction.
    final needed = <String>{}, queue = [target, target.opposite];
    final instances = <String, (LogicRule429, String)>{};
    var work = 0, limited = false;
    for (var i = 0; i < queue.length; i++) {
      final goal = queue[i];
      if (!needed.add(goal.signedKey)) continue;
      if (needed.length > maxFacts) { limited = true; break; }
      for (final rule in program.rules) {
        if (++work > maxWork) { limited = true; break; }
        final binding = _binding(rule.head, goal);
        if (binding == null) continue;
        instances['${rule.id}|$binding'] = (rule, binding);
        for (final body in rule.body) {
          final bound = body.bind(binding);
          queue.addAll([bound, bound.opposite]);
        }
      }
      if (limited) break;
    }
    final replaced = assumptions.map((a) => a.key).toSet();
    for (final fact in program.facts) {
      if (!replaced.contains(fact.conclusion.key) && needed.contains(fact.conclusion.signedKey)) {
        known[fact.conclusion.signedKey] = fact;
      }
    }
    for (final a in assumptions) {
      if (needed.contains(a.signedKey)) known[a.signedKey] = LogicProof429(a, assumption: true);
    }
    if (known.values.any((p) => known.containsKey(p.conclusion.opposite.signedKey))) {
      return const LogicAnswer429('conflict', 'Non determinabile: le premesse sono IN CONFLITTO.');
    }
    var changed = true;
    while (changed && !limited) {
      changed = false;
      for (final instance in instances.values) {
        final rule = instance.$1, value = instance.$2;
        if (++work > maxWork || known.length > maxFacts) { limited = true; break; }
        final head = rule.head.bind(value);
        if (known.containsKey(head.signedKey)) continue;
        final premises = <LogicProof429>[];
        for (final a in rule.body) {
          final bound = a.bind(value);
          final proof = known[bound.signedKey];
          if (proof == null || known.containsKey(bound.opposite.signedKey)) break;
          premises.add(proof);
        }
        if (premises.length != rule.body.length) continue;
        known[head.signedKey] = LogicProof429(head, rule: rule,
            binding: value, premises: premises);
        changed = true;
      }
    }
    if (limited) return const LogicAnswer429('unknown',
        'Non determinabile: il ragionamento ha raggiunto il limite di calcolo.');
    if (known.values.any((p) => known.containsKey(p.conclusion.opposite.signedKey))) {
      return const LogicAnswer429('conflict', 'Non determinabile: le regole producono premesse IN CONFLITTO.');
    }
    final yes = known[target.signedKey], no = known[target.opposite.signedKey];
    if (yes != null && no != null) return const LogicAnswer429('conflict',
        'Non determinabile: le premesse o le regole sono IN CONFLITTO.');
    final proof = yes ?? no;
    if (proof == null) {
      final absent = <String>{};
      for (final rule in program.rules) {
        final binding = _binding(rule.head, target);
        if (binding == null) continue;
        for (final a in rule.body) {
          final bound = a.bind(binding);
          if (!known.containsKey(bound.signedKey) && !known.containsKey(bound.opposite.signedKey)) {
            absent.add(bound.label);
          }
        }
      }
      final missing = absent.take(4).join('; ');
      return LogicAnswer429('unknown', 'Non determinabile dalle informazioni disponibili.'
          '${missing.isEmpty ? '' : ' Occorrono premesse verificate: $missing.'}');
    }
    if (!validate(proof, program, assumptions) || _tainted(proof, known)) {
      return const LogicAnswer429('conflict', 'Non determinabile: una premessa è IN CONFLITTO.');
    }
    final lines = <String>[], used = <String>{}, sourceIds = <String>{};
    var step = 0;
    void explain(LogicProof429 p) {
      if (!used.add(p.conclusion.signedKey)) return;
      for (final parent in p.premises) { explain(parent); }
      lines.add('${++step}. ${p.conclusion.label}'
          '${p.assumption ? ' (ipotesi della domanda)' : p.rule == null ? ' (premessa letta)' : ' (conseguenza della regola)'}');
      final s = p.rule?.source ?? p.source;
      if (s != null && sourceIds.add(s.id)) {
        lines.add('Testo: ${s.text}\nFonte: ${s.title} · ${s.url}');
      }
    }
    explain(proof);
    return LogicAnswer429(yes != null ? 'true' : 'false',
        '${yes != null ? 'Sì' : 'No'}. ${proof.conclusion.label}.\n'
        'Premesse e applicazione:\n${lines.join('\n')}', proof);
  }

  static String? _binding(LogicAtom429 template, LogicAtom429 ground) {
    if (template.predicate != ground.predicate || template.positive != ground.positive ||
        template.args.length != ground.args.length) return null;
    String? value;
    for (var i = 0; i < template.args.length; i++) {
      if (template.args[i] == r'$x') {
        if (value != null && value != ground.args[i]) return null;
        value = ground.args[i];
      } else if (template.args[i] != ground.args[i]) { return null; }
    }
    return value ?? '';
  }

  static bool _tainted(LogicProof429 p, Map<String, LogicProof429> known) =>
      known.containsKey(p.conclusion.opposite.signedKey) ||
      p.premises.any((parent) => _tainted(parent, known));

  static LogicAnswer429? answer(ResearchMemory11 memory, String prompt) {
    if (!prompt.trim().endsWith('?')) return null;
    final parts = prompt.trim().split(RegExp(r'(?<=[.!])\s+|\n+'));
    final question = _clean(parts.last);
    final target = atom(question);
    final program = parse(sources(memory));
    if (target == null) {
      // A requested unrecorded property of a known entity must not become a
      // list of associations presented as an answer.
      final quantity = RegExp(r'^(quanto pesa|quanto misura|qual e la massa di|qual e il peso di) (.+)$').firstMatch(question);
      if (quantity != null) {
        final subject = _entity(quantity[2]!);
        final predicate = quantity[1] == 'quanto misura' ? 'misura' : 'pesa';
        final known = program.facts.where((p) => p.conclusion.positive &&
            p.conclusion.predicate == predicate && p.conclusion.args.first == subject).toList();
        if (known.map((p) => p.conclusion.key).toSet().length > 1 ||
            known.any((p) => program.facts.any((other) =>
                other.conclusion.signedKey == p.conclusion.opposite.signedKey))) {
          return const LogicAnswer429('conflict', 'Non determinabile: i valori letti sono IN CONFLITTO.');
        }
        if (known.isNotEmpty) {
          final fact = known.first;
          return LogicAnswer429('fact', '${fact.conclusion.label}.\n'
              'Fonte: ${fact.source!.title} · ${fact.source!.url}', fact);
        }
        return const LogicAnswer429('unknown', 'Non determinabile: questa proprietà non è specificata nelle letture.');
      }
      return null;
    }
    final assumptions = <LogicAtom429>[];
    for (final part in parts.take(parts.length - 1)) {
      final parsed = _body(_clean(part));
      // Unsupported scenario clauses invalidate the attempted prediction,
      // rather than silently discarding an exception or qualification.
      if (parsed == null) return const LogicAnswer429('unknown',
          'Non determinabile: una condizione della domanda non è interpretabile in modo preciso.');
      assumptions.addAll(parsed);
    }
    final related = program.facts.any((p) => p.conclusion.key == target.key) ||
        program.rules.any((r) => r.head.predicate == target.predicate &&
          (r.head.variable || r.head.key == target.key));
    if (!related && assumptions.isEmpty && !program.entities.contains(target.args.first)) return null;
    return solve(program, target, assumptions);
  }
}
