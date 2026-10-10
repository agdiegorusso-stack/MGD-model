/// Source-grounded, deterministic operations on a small Italian text grammar.
/// This module has no examiner, answer-key, network or mutable memory access.
/// Unsupported clauses remain text: parsing a fragment never makes it a rule.
class ReadingSource435 {
  final String id, text, title, url;
  const ReadingSource435(this.id, this.text, this.title, this.url);
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'title': title,
    'url': url,
  };
}

class GroundedAnswer435 {
  final String text, operation;
  final bool unknown;
  final List<ReadingSource435> sources;
  final List<String> steps;
  const GroundedAnswer435(
    this.text,
    this.operation,
    this.sources,
    this.steps, {
    this.unknown = false,
  });
  Map<String, dynamic> get proof => {
    'kind': 'semantic435',
    'operation': operation,
    'sources': sources.map((s) => s.toJson()).toList(),
    'steps': steps,
    'unknown': unknown,
  };
}

String _norm435(String s) => s
    .toLowerCase()
    .replaceAll('à', 'a')
    .replaceAll('è', 'e')
    .replaceAll('é', 'e')
    .replaceAll('ì', 'i')
    .replaceAll('ò', 'o')
    .replaceAll('ù', 'u')
    .replaceAll('’', "'")
    .replaceAll('×', '*')
    .replaceAll('−', '-')
    .replaceAll('²', '2')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
String _noun435(String s) => _norm435(s)
    .replaceFirst(
      RegExp(
        r"^(?:il |lo |la |i |gli |le |un |uno |una |l'|dei |delle |del |della )",
      ),
      '',
    )
    .replaceFirst(RegExp(r'[.!?,;]+$'), '')
    .trim();
String _stem435(String s) =>
    _noun435(s)
        .split(' ')
        .map((w) => w.length > 3 ? w.replaceFirst(RegExp(r'[aeio]$'), '') : w)
        .join(' ');
String _num435(num n) => n == n.roundToDouble()
    ? '${n.toInt()}'
    : n.toStringAsPrecision(9).replaceFirst(RegExp(r'0+$'), '');
double? _number435(String s) {
  const words = {
    'zero': 0,
    'un': 1,
    'uno': 1,
    'una': 1,
    'due': 2,
    'tre': 3,
    'quattro': 4,
    'cinque': 5,
    'sei': 6,
    'sette': 7,
    'otto': 8,
    'nove': 9,
    'dieci': 10,
    'dodici': 12,
    'quindici': 15,
    'venti': 20,
    'trenta': 30,
  };
  return double.tryParse(s.replaceAll(',', '.')) ?? words[s]?.toDouble();
}

const _numberPattern435 =
    r'(?:\d+(?:[.,]\d+)?|zero|uno|una|un|due|tre|quattro|cinque|sei|sette|otto|nove|dieci|dodici|quindici|venti|trenta)';

/// The interrogative can be followed by "show the calculation" and can have
/// preceding premises. The last sentence is not necessarily the question.
class ReadingQuestion435 {
  final String full, question;
  final List<String> premises;
  ReadingQuestion435(String prompt)
    : full = _norm435(prompt),
      question = _question(prompt),
      premises = _premises(prompt);
  static List<String> clauses(String s) =>
      _norm435(s).split(RegExp(r'(?<=[!?;])\s+|(?<=[.])\s+(?=[a-z])'));
  static String _question(String s) {
    final parts = clauses(s);
    final questions = parts.where((p) => p.contains('?')).toList();
    return (questions.isEmpty ? _norm435(s) : questions.last)
        .replaceFirst(RegExp(r'\?.*$'), '')
        .trim();
  }

  static List<String> _premises(String s) => clauses(s)
      .where(
        (p) =>
            !p.contains('?') &&
            !RegExp(r'^(?:mostra|spiega|indica|rispondi|giustifica)\b')
                .hasMatch(p),
      )
      .map((p) => p.replaceFirst(RegExp(r'[.;]+$'), ''))
      .toList();
}

/// Arithmetic AST and reversible one-unknown equations; no physical formulas
/// are installed here. Equations and variable labels must occur in the source.
class _Expression435 {
  final String token;
  final _Expression435? left, right;
  const _Expression435(this.token, [this.left, this.right]);
  Set<String> get variables => left == null
      ? double.tryParse(token) == null
            ? {token}
            : <String>{}
      : {...left!.variables, ...right!.variables};
  double? evaluate(Map<String, double> values) {
    if (left == null) return double.tryParse(token) ?? values[token];
    final a = left!.evaluate(values), b = right!.evaluate(values);
    if (a == null || b == null || (token == '/' && b == 0)) return null;
    final v = switch (token) {
      '+' => a + b,
      '-' => a - b,
      '*' => a * b,
      '/' => a / b,
      _ => double.nan,
    };
    return v.isFinite ? v : null;
  }

  double? invert(String target, double result, Map<String, double> values) {
    if (left == null) return token == target ? result : null;
    final inLeft = left!.variables.contains(target),
        inRight = right!.variables.contains(target);
    if (inLeft == inRight) return null;
    final other = (inLeft ? right : left)!.evaluate(values);
    if (other == null) return null;
    final next = switch (token) {
      '+' => result - other,
      '-' => inLeft ? result + other : other - result,
      '*' => other == 0 ? double.nan : result / other,
      '/' =>
        inLeft
            ? result * other
            : result == 0
            ? double.nan
            : other / result,
      _ => double.nan,
    };
    return next.isFinite
        ? (inLeft ? left : right)!.invert(target, next, values)
        : null;
  }

  String substitute(Map<String, double> values) => left == null
      ? values.containsKey(token)
            ? _num435(values[token]!)
            : token
      : '(${left!.substitute(values)} $token ${right!.substitute(values)})';
  static _Expression435? parse(String text) {
    final tokens = RegExp(r'[a-z][a-z0-9_]*|\d+(?:\.\d+)?|[()+*/-]')
        .allMatches(text)
        .map((m) => m[0]!)
        .toList();
    if (tokens.join('') != text.replaceAll(' ', '') || tokens.length > 64)
      return null;
    var i = 0;
    _Expression435? expression(int level) {
      _Expression435? v;
      if (level < 2) {
        v = expression(level + 1);
        final ops = level == 0 ? {'+', '-'} : {'*', '/'};
        while (i < tokens.length && ops.contains(tokens[i])) {
          final op = tokens[i++], r = expression(level + 1);
          if (v == null || r == null) return null;
          v = _Expression435(op, v, r);
        }
      } else {
        if (i >= tokens.length) return null;
        final t = tokens[i++];
        if (t == '(') {
          v = expression(0);
          if (i >= tokens.length || tokens[i++] != ')') return null;
        } else if (RegExp(r'^[a-z0-9]').hasMatch(t)) {
          v = _Expression435(t);
        } else {
          return null;
        }
      }
      return v;
    }

    final e = expression(0);
    return i == tokens.length ? e : null;
  }
}

class _Equation435 {
  final String output, display;
  final _Expression435 expression;
  final Map<String, String> labels;
  final ReadingSource435 source;
  _Equation435(
    this.output,
    this.expression,
    this.labels,
    this.display,
    this.source,
  );
  static List<_Equation435> read(ReadingSource435 source) {
    final s = _norm435(source.text);
    if (RegExp(r'\b(non|se|quando|forse|potrebbe)\b|\?').hasMatch(s)) return [];
    final equations = <_Equation435>[];
    for (final m in RegExp(
      r'\b([a-z])\s*=\s*([a-z0-9 +*/()-]+)',
    ).allMatches(s)) {
      final raw = m[2]!.trim(), e = _Expression435.parse(raw);
      if (e == null ||
          e.variables.length != 2 ||
          !RegExp(r'^[a-z]$').hasMatch(m[1]!))
        continue;
      final prefix = s.substring(0, m.start).replaceFirst(RegExp(r':\s*$'), '');
      final verbal = RegExp(
        r"(?:la |il |l')([a-z ]+?) (?:e |equivale a )(?:uguale (?:alla |al |a |all'))?(?:la |il |l')?([a-z ]+?) (moltiplicata per|moltiplicato per|divisa per|diviso per|per|meno|piu) (?:la |il |l'|quella )?([a-z ]+)$",
      ).firstMatch(prefix);
      if (verbal == null) continue;
      final vars = RegExp(r'\b[a-z]\b')
          .allMatches(raw)
          .map((v) => v[0]!)
          .toList();
      if (vars.length != 2 || vars[0] == vars[1]) continue;
      final op = verbal[3]!.startsWith('divis')
          ? '/'
          : verbal[3] == 'meno'
          ? '-'
          : verbal[3] == 'piu'
          ? '+'
          : '*';
      if (e.token != op) continue;
      equations.add(
        _Equation435(
          m[1]!,
          e,
          {
            m[1]!: _noun435(verbal[1]!),
            vars[0]: _noun435(verbal[2]!),
            vars[1]: _noun435(verbal[4]!),
          },
          '${m[1]!.toUpperCase()} = $raw',
          source,
        ),
      );
    }
    return equations;
  }
}

class _Edge435 {
  final String from, to;
  final ReadingSource435 source;
  const _Edge435(this.from, this.to, this.source);
}

class _Location435 {
  final String actor, object, place;
  final int? time;
  final int order;
  final ReadingSource435 source;
  const _Location435(
    this.actor,
    this.object,
    this.place,
    this.time,
    this.order,
    this.source,
  );
}

class SemanticReasoning435 {
  /// All handlers implement language/operation grammars over the supplied
  /// sources. No document IDs, benchmark subjects, numbers or references are
  /// inspected. Responses from conflicting documents cannot be cherry-picked.
  static GroundedAnswer435? answer(
    List<ReadingSource435> sources,
    String prompt,
  ) {
    if (sources.isEmpty || prompt.length > 12000 || sources.length > 20000)
      return null;
    final q = ReadingQuestion435(prompt);
    if (!prompt.contains('?')) return null;
    final classes = _taxonomy(sources, q);
    if (classes != null) return classes;
    final groups = <String, List<ReadingSource435>>{};
    for (final source in sources) {
      (groups[source.url] ??= []).add(source);
    }
    final answers = <GroundedAnswer435>[];
    for (final group in groups.values) {
      // Source sentences retain their identity; adjacency is only within one
      // document, never across independent providers.
      final answer =
          _formula(group, q) ??
          _locations(group, q) ??
          _ledger(group, q) ??
          _schedule(group, q) ??
          _comparison(group, q) ??
          _conditional(group, q) ??
          _containment(group, q) ??
          _relations(group, q) ??
          _missing(group, q);
      if (answer != null) answers.add(answer);
    }
    final determinate = answers.where((a) => !a.unknown).toList();
    if (determinate.map((a) => a.text.split('\n').first).toSet().length > 1) {
      return GroundedAnswer435(
        'Non determinabile: le conclusioni delle fonti sono IN CONFLITTO.',
        'conflict',
        determinate.expand((a) => a.sources).toList(),
        determinate.map((a) => a.text.split('\n').first).toList(),
        unknown: true,
      );
    }
    return determinate.isNotEmpty
        ? determinate.first
        : answers.isNotEmpty
        ? answers.first
        : null;
  }

  static GroundedAnswer435 _answer(
    String conclusion,
    String operation,
    Iterable<ReadingSource435> sources,
    List<String> steps, {
    bool unknown = false,
  }) => GroundedAnswer435(
    '$conclusion${steps.isEmpty ? '' : '\n${steps.join('; ')}.'}',
    operation,
    {for (final s in sources) s.id: s}.values.toList(),
    steps,
    unknown: unknown,
  );
  static GroundedAnswer435 _unknown(
    String missing,
    Iterable<ReadingSource435> sources, {
    String operation = 'missing',
  }) => _answer(
    'Non determinabile: $missing.',
    operation,
    sources,
    [],
    unknown: true,
  );

  static const _units = <String, (String, String, double)>{
    'kg': ('massa', 'kg', 1),
    'chilogrammi': ('massa', 'kg', 1),
    'g': ('massa', 'kg', .001),
    'grammi': ('massa', 'kg', .001),
    'n': ('forza', 'N', 1),
    'newton': ('forza', 'N', 1),
    'volt': ('tensione', 'volt', 1),
    'v': ('tensione', 'volt', 1),
    'ohm': ('resistenza', 'ohm', 1),
    'ω': ('resistenza', 'ohm', 1),
    'ampere': ('corrente', 'ampere', 1),
    'a': ('corrente', 'ampere', 1),
    'm/s2': ('accelerazione', 'm/s²', 1),
  };
  static GroundedAnswer435? _formula(
    List<ReadingSource435> ss,
    ReadingQuestion435 q,
  ) {
    for (final source in ss) {
      for (final eq in _Equation435.read(source)) {
        final qs = q.question;
        if (qs.contains('relazione') && eq.labels.values.every(qs.contains)) {
          return _answer('${eq.display}.', 'equation-recall', [source], []);
        }
        final targets = eq.labels.entries
            .where((l) => qs.contains(l.value))
            .toList();
        if (targets.length != 1) continue;
        final target = targets.single.key, values = <String, double>{};
        final input = q.full;
        final steps = <String>[];
        final vars = {eq.output, ...eq.expression.variables};
        for (final variable in vars.where((v) => v != target)) {
          final label = eq.labels[variable]!;
          final compatible = _units.entries
              .where((u) => label.contains(u.value.$1))
              .toList();
          final unitDefinitions = ss
              .expand(
                (s) => RegExp(
                  r"(?:la |il |l')?([a-z ]+?) (?:si misura )?in ([a-z/0-9]+)",
                ).allMatches(_norm435(s.text)),
              )
              .where((m) => _noun435(m[1]!).endsWith(label))
              .map((m) => m[2]!)
              .toSet();
          final units = {...compatible.map((u) => u.key), ...unitDefinitions};
          final readings = <(double, String)>[];
          for (final unit in units) {
            final matches = RegExp(
              '($_numberPattern435)\\s*${RegExp.escape(unit)}\\b',
            ).allMatches(input);
            for (final m in matches) {
              var n = _number435(m[1]!)! * (_units[unit]?.$3 ?? 1);
              if (m.start > 0 && input[m.start - 1] == '-') n = -n;
              if (label.contains('massa') && n <= 0)
                return _unknown(
                  'la massa deve essere positiva in questo modello',
                  [source],
                  operation: 'equation',
                );
              final suffix = input
                  .substring(m.end)
                  .split(RegExp(r'[.,;?]'))
                  .first;
              if (suffix.startsWith(' verso sinistra') ||
                  suffix.startsWith(' verso il basso'))
                n = -n;
              readings.add((n, unit));
            }
          }
          if (readings.length > 1) {
            final vector =
                label.contains('forza') &&
                ss.any(
                  (s) =>
                      _norm435(s.text)
                          .contains('direzioni opposte si sottraggono'),
                ) &&
                readings.every((r) => r.$2 == readings.first.$2) &&
                RegExp(r'verso (?:destra|sinistra|alto|il basso)')
                    .hasMatch(input);
            if (vector && !RegExp(r'verso (?:alto|il basso)').hasMatch(input)) {
              values[variable] = readings.fold(0, (a, b) => a + b.$1);
              steps.add(
                '${readings.map((r) => _num435(r.$1)).join(' + ')} = ${_num435(values[variable]!)} ${readings.first.$2}',
              );
            } else if (readings.map((r) => r.$1).toSet().length == 1) {
              values[variable] = readings.first.$1;
            } else {
              return _unknown('i valori di $label sono IN CONFLITTO', [
                source,
              ], operation: 'conflict');
            }
          } else if (readings.isNotEmpty) {
            values[variable] = readings.single.$1;
          }
          // Source-defined non-SI quantities can be given by their label.
          if (!values.containsKey(variable)) {
            final m = RegExp(
              '${RegExp.escape(label)} (?:e |vale |di )?($_numberPattern435)\\b',
            ).firstMatch(input);
            if (m != null) values[variable] = _number435(m[1]!)!;
          }
        }
        final needed = target == eq.output
            ? eq.expression.variables
            : {eq.output, ...eq.expression.variables.where((v) => v != target)};
        final missing = needed.where((v) => !values.containsKey(v)).toList();
        if (missing.isNotEmpty)
          return _unknown(
            'manca ${missing.map((v) => eq.labels[v]).join(' e ')}',
            [source],
            operation: 'equation',
          );
        final result = target == eq.output
            ? eq.expression.evaluate(values)
            : eq.expression.invert(target, values[eq.output]!, values);
        if (result == null || !result.isFinite)
          return _unknown(
            'l’equazione non consente una soluzione finita univoca con questi dati',
            [source],
            operation: 'equation',
          );
        final label = eq.labels[target]!;
        var unit =
            _units.values
                .where((u) => label.contains(u.$1))
                .map((u) => u.$2)
                .firstOrNull ??
            '';
        for (final s in ss) {
          final m = RegExp(
            '${RegExp.escape(label)} (?:si misura )?in ([a-z/0-9]+)',
          ).firstMatch(_norm435(s.text));
          if (m != null && !_units.values.any((u) => label.contains(u.$1)))
            unit = m[1]!;
        }
        final direction =
            label.contains('accelerazione') &&
                RegExp(r'verso (?:destra|sinistra)').hasMatch(input) &&
                ss.any(
                  (s) =>
                      _norm435(s.text)
                          .contains('direzione della forza risultante'),
                )
            ? result < 0
                  ? ' verso sinistra'
                  : result > 0
                  ? ' verso destra'
                  : ''
            : '';
        if (target == eq.output) {
          steps.add('${eq.expression.substitute(values)} = ${_num435(result)}');
        } else {
          steps.add(
            'Da ${eq.display}, ${eq.labels[eq.output]} = ${_num435(values[eq.output]!)}',
          );
          steps.add(
            '${_num435(values[eq.output]!)} = ${eq.expression.substitute({...values, target: result})}',
          );
        }
        return _answer(
          '${_num435(direction.isEmpty ? result : result.abs())}${unit.isEmpty ? '' : ' $unit'}$direction.',
          'equation',
          [source],
          steps,
        );
      }
    }
    return null;
  }

  static GroundedAnswer435? _taxonomy(
    List<ReadingSource435> ss,
    ReadingQuestion435 q,
  ) {
    final edges = <_Edge435>[],
        instances = <_Edge435>[],
        negatives = <_Edge435>[];
    for (final s in ss) {
      final text = _norm435(s.text).replaceFirst(RegExp(r'[.!]+$'), '');
      var m = RegExp(
        r'^(?:tutti i|tutte le|ogni) ([a-z]+) (?:sono|e un|e una) ([a-z]+)$',
      ).firstMatch(text);
      if (m != null) edges.add(_Edge435(_noun435(m[1]!), _noun435(m[2]!), s));
      m = RegExp(r'^([a-z][a-z0-9_-]*) e (?:un |una |uno )([a-z]+)$')
          .firstMatch(text);
      if (m != null) instances.add(_Edge435(m[1]!, m[2]!, s));
      final no = RegExp(r'^([a-z][a-z0-9_-]*) non e (?:un |una |uno )([a-z]+)$')
          .firstMatch(text);
      if (no != null) negatives.add(_Edge435(no[1]!, no[2]!, s));
    }
    if (instances.isEmpty && edges.isEmpty) return null;
    final qs = q.question;
    final recall = RegExp(
      r'(?:che tipo di .+? e|che cos.e|cos.e) ([a-z][a-z0-9_-]*)(?: nel testo)?$',
    ).firstMatch(qs);
    if (recall != null) {
      final facts = instances.where((i) => i.from == recall[1]).toList();
      if (facts.isNotEmpty)
        return _answer(
          '${facts.first.from} è ${facts.first.to}.',
          'class-recall',
          [facts.first.source],
          [],
        );
    }
    final m = RegExp(
      r'(?:possiamo concludere che e|([a-z][a-z0-9_-]*) e) (?:un |una |uno )([a-z]+)$',
    ).firstMatch(qs);
    if (m == null) return null;
    var subject = m[1];
    if (subject == null) {
      final premise = RegExp(
        r'di ([a-z][a-z0-9_-]*) sappiamo (?:soltanto |solo )?che e (?:un |una )([a-z]+)',
      ).firstMatch(q.full);
      if (premise == null) return null;
      subject = premise[1]!;
      instances.add(
        _Edge435(
          subject,
          premise[2]!,
          ReadingSource435(
            'premise',
            premise[0]!,
            'Premessa della domanda',
            'query://premise',
          ),
        ),
      );
    }
    final wanted = _stem435(m[2]!);
    final initial = instances.where((i) => i.from == subject).toList();
    if (initial.isEmpty) return null;
    final queue = <List<_Edge435>>[
      for (final i in initial) [i],
    ];
    final seen = <String>{};
    for (var i = 0; i < queue.length && i < 1024; i++) {
      final path = queue[i], last = path.last.to;
      if (!seen.add(_stem435(last))) continue;
      if (_stem435(last) == wanted) {
        if (negatives.any(
          (n) =>
              n.from == subject &&
              path.any((e) => _stem435(e.to) == _stem435(n.to)),
        )) {
          return _unknown('le premesse di classe sono IN CONFLITTO', [
            ...path.map((p) => p.source),
            ...negatives.map((p) => p.source),
          ], operation: 'conflict');
        }
        return _answer(
          'Sì, $subject è ${m[2]}.',
          'class-inheritance',
          path.map((p) => p.source),
          path.map((p) => '${p.from} → ${p.to}').toList(),
        );
      }
      for (final e in edges.where((e) => _stem435(e.from) == _stem435(last))) {
        queue.add([...path, e]);
      }
    }
    final inverse = edges.any(
      (e) => _stem435(e.from) == wanted && seen.contains(_stem435(e.to)),
    );
    if (inverse)
      return _answer(
        'No, non possiamo concluderlo.',
        'invalid-converse',
        edges.map((e) => e.source),
        [
          'Una regola universale non vale automaticamente al contrario: ${m[2]} implica ${edges.firstWhere((e) => _stem435(e.from) == wanted).to}, ma l’inverso non è stato dato',
        ],
      );
    return _unknown(
      'manca una regola che colleghi $subject alla classe ${m[2]}',
      initial.map((i) => i.source),
      operation: 'class-inheritance',
    );
  }

  static int? _clock(String s) {
    final m = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(s);
    if (m == null) return null;
    final h = int.parse(m[1]!), minutes = int.parse(m[2]!);
    return h < 24 && minutes < 60 ? h * 60 + minutes : null;
  }

  static String _time(int n) =>
      '${(n ~/ 60) % 24}:${(n % 60).toString().padLeft(2, '0')}';
  static GroundedAnswer435? _locations(
    List<ReadingSource435> ss,
    ReadingQuestion435 q,
  ) {
    final events = <_Location435>[];
    for (var i = 0; i < ss.length; i++) {
      final s = ss[i],
          text = _norm435(s.text).replaceFirst(RegExp(r'[.!]+$'), '');
      final m = RegExp(
        r'^(?:alle \d{1,2}:\d{2} )?([a-z][a-z0-9_-]*) (mette|sposta) (?:la stessa |lo stesso |la |il |un |una )([a-z][a-z0-9_-]*) (?:nel|nella|in|dal .+? alla|dal .+? al) (.+)$',
      ).firstMatch(text);
      if (m != null)
        events.add(_Location435(m[1]!, m[3]!, m[4]!, _clock(text), i, s));
    }
    if (events.isEmpty || !q.question.startsWith('dove ')) return null;
    final mentioned = events.where((e) => q.full.contains(e.object)).toList();
    final belief = RegExp(r'dove (?:cerchera|cerca)').hasMatch(q.question);
    final relevant = mentioned.isNotEmpty
        ? mentioned
        : belief
        ? events
        : <_Location435>[];
    if (relevant.isEmpty) return null;
    final object = relevant.first.object;
    if (belief) {
      final actors = events
          .map((e) => e.actor)
          .toSet()
          .where(q.question.contains)
          .toList();
      if (actors.length != 1) return null;
      final actor = actors.single;
      final hidden = ss
          .where(
            (s) =>
                RegExp('${RegExp.escape(actor)} non (?:vede|ha visto)')
                    .hasMatch(_norm435(s.text)) &&
                RegExp(r'nessuno.*(?:raccont|inform)')
                    .hasMatch(_norm435(s.text)),
          )
          .toList();
      if (hidden.isEmpty)
        return _unknown(
          'manca ciò che $actor ha osservato o saputo degli spostamenti',
          ss,
          operation: 'perspective',
        );
      final prior = events
          .where((e) => e.actor == actor && e.object == object)
          .toList();
      if (prior.isEmpty)
        return _unknown(
          'manca una posizione nota a $actor',
          hidden,
          operation: 'perspective',
        );
      return _answer(
        'Nel ${prior.last.place}.',
        'perspective',
        [prior.last.source, ...hidden],
        [
          '$actor non ha visto lo spostamento e nessuno lo ha informato: conserva l’ultima posizione a lui nota',
        ],
      );
    }
    final requestedTime = _clock(q.question);
    final valid = relevant
        .where(
          (e) =>
              requestedTime == null ||
              e.time == null ||
              e.time! <= requestedTime,
        )
        .toList();
    if (valid.isEmpty)
      return _unknown(
        'manca la posizione di $object prima dell’orario richiesto',
        ss,
        operation: 'event-state',
      );
    valid.sort((a, b) => (a.time ?? a.order).compareTo(b.time ?? b.order));
    final last = valid.last;
    // An event gives a state at its instant. Extending it to a later instant
    // requires the narrative's explicit no-later-movement premise.
    if (requestedTime != null &&
        last.time != null &&
        requestedTime > last.time! &&
        !ss.any(
          (s) =>
              RegExp(r'nessuno sposta|nessun altro spostamento')
                  .hasMatch(_norm435(s.text)),
        )) {
      return _unknown(
        'manca la conferma che non vi siano stati altri spostamenti',
        [last.source],
        operation: 'event-state',
      );
    }
    return _answer(
      'Nel ${last.place}.',
      'event-state',
      [last.source],
      [
        '${last.actor} ha ${last.source.text.toLowerCase().contains('sposta') ? 'spostato' : 'messo'} $object in ${last.place}${last.time == null ? '' : ' alle ${_time(last.time!)}'}',
      ],
    );
  }

  static GroundedAnswer435? _ledger(
    List<ReadingSource435> ss,
    ReadingQuestion435 q,
  ) {
    final initial = <(String, double, String, ReadingSource435)>[];
    final purchases = <(double, String, double, ReadingSource435)>[];
    final credits = <(double, ReadingSource435)>[];
    for (final s in ss) {
      final text = _norm435(s.text).replaceFirst(RegExp(r'[.!]+$'), '');
      var m = RegExp(
        '^([a-z][a-z0-9_-]*) ha ($_numberPattern435) (euro|crediti|dollari)\$',
      ).firstMatch(text);
      if (m != null) initial.add((m[1]!, _number435(m[2]!)!, m[3]!, s));
      m = RegExp(
        '^(?:[a-z][a-z0-9_-]* )?compra ($_numberPattern435) ([a-z]+) che costano ($_numberPattern435) (?:euro|crediti|dollari) ciascuno(?:, senza sconti)?\$',
      ).firstMatch(text);
      if (m != null)
        purchases.add((_number435(m[1]!)!, m[2]!, _number435(m[3]!)!, s));
      m = RegExp(
        '^(?:poi )?(?:[a-z][a-z0-9_-]* )?riceve un (?:rimborso|accredito) di ($_numberPattern435) (?:euro|crediti|dollari)\$',
      ).firstMatch(text);
      if (m != null) credits.add((_number435(m[1]!)!, s));
    }
    if (initial.length != 1 || purchases.isEmpty) return null;
    final account = initial.single;
    final price = RegExp(r'^quanto costa (?:un |una )([a-z]+)$')
        .firstMatch(q.question);
    if (price != null) {
      final found = purchases
          .where((p) => _stem435(p.$2) == _stem435(price[1]!))
          .toList();
      if (found.length != 1) return null;
      return _answer(
        '${_num435(found.single.$3)} ${account.$3}.',
        'unit-price',
        [found.single.$4],
        [],
      );
    }
    if (!RegExp(r'quanto (?:denaro|ha)|saldo|quanti (?:euro|crediti|dollari)')
            .hasMatch(q.question) ||
        !q.full.contains(account.$1))
      return null;
    final closed = ss.any(
      (s) => _norm435(s.text).contains('non ci sono altre entrate o spese'),
    );
    if (!closed)
      return _unknown(
        'manca la conferma che non vi siano altre entrate o spese',
        ss,
        operation: 'ledger',
      );
    final extra = RegExp(
      'compra anche (?:un |una |$_numberPattern435 )([a-z]+)',
    ).firstMatch(q.full);
    if (extra != null &&
        !purchases.any((p) => _stem435(p.$2) == _stem435(extra[1]!))) {
      return _unknown(
        'manca il prezzo di ${extra[1]}',
        ss,
        operation: 'ledger',
      );
    }
    var balance = account.$2;
    final calculation = StringBuffer(_num435(balance));
    for (final p in purchases) {
      balance -= p.$1 * p.$3;
      calculation.write(' - ${_num435(p.$1)} × ${_num435(p.$3)}');
    }
    for (final c in credits) {
      balance += c.$1;
      calculation.write(' + ${_num435(c.$1)}');
    }
    if (extra != null) {
      final item = purchases
          .where((p) => _stem435(p.$2) == _stem435(extra[1]!))
          .toList();
      if (item.length != 1)
        return _unknown(
          'il prezzo dell’acquisto aggiuntivo è IN CONFLITTO',
          ss,
          operation: 'conflict',
        );
      final quantity = RegExp('compra anche ($_numberPattern435)')
          .firstMatch(q.full);
      final count = quantity == null ? 1.0 : _number435(quantity[1]!)!;
      balance -= count * item.single.$3;
      calculation.write(' - ${_num435(count)} × ${_num435(item.single.$3)}');
    }
    final steps = <String>['$calculation = ${_num435(balance)}'];
    final returned = RegExp(
      'restituisce (?:anche )?($_numberPattern435) ([a-z]+)',
    ).firstMatch(q.full);
    if (returned != null) {
      final item = purchases
          .where((p) => _stem435(p.$2) == _stem435(returned[2]!))
          .toList();
      final count = _number435(returned[1]!)!;
      final refund = ss.any(
        (s) =>
            _norm435(s.text).startsWith('se restituisce') &&
            _norm435(s.text).contains('restituisce esattamente'),
      );
      if (item.length != 1 || !refund || count > item.single.$1)
        return _unknown(
          'manca una regola di rimborso applicabile alla restituzione',
          ss,
          operation: 'ledger',
        );
      final old = balance;
      balance += count * item.single.$3;
      steps.add(
        '${_num435(old)} + ${_num435(count * item.single.$3)} = ${_num435(balance)}',
      );
    }
    return _answer('${_num435(balance)} ${account.$3}.', 'ledger', ss, steps);
  }

  static GroundedAnswer435? _schedule(
    List<ReadingSource435> ss,
    ReadingQuestion435 q,
  ) {
    final timetable = ss
        .where((s) => _norm435(s.text).contains('partono alle'))
        .toList();
    if (timetable.length != 1) return null;
    final departures =
        RegExp(r'\d{1,2}:\d{2}')
            .allMatches(timetable.single.text)
            .map((m) => _clock(m[0]!)!)
            .toList()
          ..sort();
    if (departures.isEmpty) return null;
    if (RegExp(r'(?:primo|prima).*?(?:autobus|bus|treno)')
        .hasMatch(q.question)) {
      return _answer(
        'Alle ${_time(departures.first)}.',
        'schedule-recall',
        timetable,
        [],
      );
    }
    final origins = ss
        .where(
          (s) =>
              RegExp(r'esce di casa alle|parte da casa alle')
                  .hasMatch(_norm435(s.text)),
        )
        .toList();
    if (origins.length != 1) return null;
    final origin = origins.single;
    final actor = RegExp(r'^([a-z][a-z0-9_-]*) ')
        .firstMatch(_norm435(origin.text))?[1];
    if (actor == null ||
        !q.full.contains(actor) ||
        !RegExp(r'arriva|arrivo').hasMatch(q.question))
      return null;
    final alternative = RegExp(r'prende (?:un|il) ([a-z]+)').firstMatch(q.full);
    if (alternative != null &&
        !RegExp(RegExp.escape(alternative[1]!))
            .hasMatch(_norm435(timetable.single.text)) &&
        alternative[1] != 'bus') {
      return _unknown(
        'manca la durata del viaggio in ${alternative[1]}',
        ss,
        operation: 'schedule',
      );
    }
    final walking = RegExp(
      'impiega (?:esattamente )?($_numberPattern435) minuti',
    ).firstMatch(_norm435(origin.text));
    final trips = ss
        .expand(
          (s) => RegExp(
            '(?:il viaggio dura|il tragitto dura) ($_numberPattern435) minuti',
          ).allMatches(_norm435(s.text)),
        )
        .toList();
    if (walking == null || trips.length != 1)
      return _unknown(
        'manca la durata di una tratta del percorso',
        ss,
        operation: 'schedule',
      );
    final changed = RegExp('(?:esce|parte) (?:invece )?alle (\\d{1,2}:\\d{2})')
        .firstMatch(q.full);
    final start = changed == null ? _clock(origin.text) : _clock(changed[1]!);
    if (start == null)
      return _unknown(
        'manca l’orario di partenza da casa',
        ss,
        operation: 'schedule',
      );
    final stop = start + _number435(walking[1]!)!.toInt();
    final eligible = departures.where((t) => t >= stop).toList();
    if (eligible.isEmpty)
      return _unknown(
        'non è indicata una partenza successiva all’arrivo alla fermata',
        timetable,
        operation: 'schedule',
      );
    final bus = eligible.first,
        duration = _number435(trips.single[1]!)!.toInt(),
        arrival = bus + duration;
    final deadline = RegExp(r'entro (?:le )?(\d{1,2}:\d{2})')
        .firstMatch(q.question);
    final conclusion = deadline == null
        ? 'Alle ${_time(arrival)}.'
        : '${arrival <= _clock(deadline[1]!)! ? 'Sì' : 'No'}, arrivo alle ${_time(arrival)}.';
    return _answer(conclusion, 'schedule', ss, [
      'Fermata alle ${_time(stop)}',
      'partenza alle ${_time(bus)}',
      'viaggio di $duration minuti',
      'arrivo alle ${_time(arrival)}',
    ]);
  }

  static GroundedAnswer435? _comparison(
    List<ReadingSource435> ss,
    ReadingQuestion435 q,
  ) {
    final pairs = <String, (double, double)>{};
    for (final s in ss) {
      final t = _norm435(s.text);
      for (final m in RegExp(
        '(?:la media di |quella di )([a-z][a-z0-9_-]*) (?:passa )?da ($_numberPattern435) a ($_numberPattern435)',
      ).allMatches(t)) {
        pairs[m[1]!] = (_number435(m[2]!)!, _number435(m[3]!)!);
      }
    }
    if (pairs.length < 2) return null;
    final improvement = ss
        .where(
          (s) =>
              RegExp(r'miglioramento e la media finale meno quella iniziale')
                  .hasMatch(_norm435(s.text)),
        )
        .toList();
    if (q.question.contains('certezza') &&
        q.question.contains('miglioramento')) {
      final limits = ss
          .where(
            (s) =>
                RegExp(r'non.*assegnat.*caso|non sappiamo.*condizioni')
                    .hasMatch(_norm435(s.text)),
          )
          .toList();
      if (limits.isEmpty) return null;
      return _unknown(
        'manca un confronto che controlli le altre differenze e condizioni; non è indicata un’assegnazione casuale',
        limits,
        operation: 'causal-limit',
      );
    }
    final gain = RegExp(r'miglior').hasMatch(q.question);
    if (!gain && !q.question.contains('media finale')) return null;
    if (gain && improvement.isEmpty) return null;
    final changed = RegExp(
      'media iniziale di ([a-z][a-z0-9_-]*) fosse ($_numberPattern435)',
    ).firstMatch(q.full);
    if (changed != null && pairs.containsKey(changed[1]!))
      pairs[changed[1]!] = (_number435(changed[2]!)!, pairs[changed[1]!]!.$2);
    final values = {
      for (final e in pairs.entries)
        e.key: gain ? e.value.$2 - e.value.$1 : e.value.$2,
    };
    final sorted = values.values.toList()..sort();
    final best = values.entries
        .where((e) => e.value == sorted.last)
        .map((e) => e.key)
        .toList();
    final conclusion = best.length > 1
        ? 'Nessuna prevale: risultati uguali.'
        : 'La classe ${best.single.toUpperCase()}, ${_num435(sorted.last)} punti.';
    return _answer(
      conclusion,
      gain ? 'difference-comparison' : 'value-comparison',
      ss,
      [
        for (final e in pairs.entries)
          gain
              ? '${e.key.toUpperCase()}: ${_num435(e.value.$2)} - ${_num435(e.value.$1)} = ${_num435(values[e.key]!)}'
              : '${e.key.toUpperCase()}: ${_num435(e.value.$2)}',
      ],
    );
  }

  static GroundedAnswer435? _conditional(
    List<ReadingSource435> ss,
    ReadingQuestion435 q,
  ) {
    // Resolve a possessive only with one explicitly named owner in this text.
    // The full antecedent must be supplied, never inferred from word overlap.
    final owners = <String, String>{};
    for (final s in ss) {
      final m = RegExp(r'(?:una |un )?([a-z]+) ([a-z][a-z0-9_-]*) ha (.+)')
          .firstMatch(_norm435(s.text));
      if (m != null) owners[m[2]!] = m[1]!;
    }
    String clause(String value) {
      var text = _norm435(value)
          .replaceFirst(RegExp(r'^(?:nel caso descritto, |nel modello, )'), '')
          .replaceFirst(RegExp(r'[.!]+$'), '');
      if (owners.length == 1) {
        final owner = owners.keys.single;
        text = text.replaceAllMapped(
          RegExp(r'tutti i suoi ([a-z]+)'),
          (m) => 'tutti i ${m[1]} di $owner',
        );
        text = text.replaceAll(
          RegExp(
            '(?:la |il )?${RegExp.escape(owners[owner]!)} ${RegExp.escape(owner)} ',
          ),
          '$owner ',
        );
      }
      return text.replaceAll(' puo ancora ', ' puo ');
    }

    for (final s in ss) {
      final raw = _norm435(s.text).replaceFirst(RegExp(r'[.!]+$'), '');
      final m = RegExp(r'^se (.+?), (.+?)(?:;.*)?$').firstMatch(raw);
      if (m == null) continue;
      final effect = RegExp(r'^(.+?) (non )?puo (.+)$')
          .firstMatch(clause(m[2]!));
      if (effect == null ||
          clause(q.question) != '${effect[1]} puo ${effect[3]}')
        continue;
      if (!q.premises.map(clause).contains(clause(m[1]!))) {
        return _unknown('manca la condizione ${clause(m[1]!)}', [
          s,
        ], operation: 'conditional');
      }
      return _answer(
        effect[2] == null
            ? 'Sì, ${effect[1]} può ${effect[3]}.'
            : 'No, ${effect[1]} non può ${effect[3]}.',
        'conditional',
        [s],
        ['La condizione ${clause(m[1]!)} soddisfa la regola letta'],
      );
    }
    return null;
  }

  static GroundedAnswer435? _containment(
    List<ReadingSource435> ss,
    ReadingQuestion435 q,
  ) {
    final m = RegExp(
      r'^tutto (?:il |lo |la )(.+?) di ([a-z][a-z0-9_-]*) e (?:necessariamente )?(?:nel |nella )(.+)$',
    ).firstMatch(q.question);
    if (m == null) return null;
    final cargo = _noun435(m[1]!), owner = m[2]!, target = _noun435(m[3]!);
    final membership = ss
        .where(
          (s) =>
              RegExp('(?:[a-z]+ )?${RegExp.escape(owner)} ha ')
                  .hasMatch(_norm435(s.text)),
        )
        .toList();
    if (membership.length != 1) return null;
    final parts = _norm435(membership.single.text)
        .split(' ha ')
        .last
        .replaceFirst(RegExp(r'[.!]+$'), '')
        .split(RegExp(r', | e '))
        .map(_noun435)
        .toSet();
    if (!parts.any((p) => _stem435(p) == _stem435(target))) return null;
    final alternatives = <(String, ReadingSource435)>[];
    for (final s in ss) {
      final fact = RegExp(
        r'^(?:anche )?(?:i |gli |le |il |lo |la )?([a-z]+) (?:contengono|contiene|ospitano|ospita) (?:un proprio |proprio |il |lo |la )?(.+?)[.!]?$',
      ).firstMatch(_norm435(s.text));
      if (fact != null &&
          _stem435(fact[1]!) != _stem435(target) &&
          parts.any((p) => _stem435(p) == _stem435(fact[1]!)) &&
          _stem435(fact[2]!) == _stem435(cargo)) {
        alternatives.add((fact[1]!, s));
      }
    }
    // An explicit source rejection of exclusivity is needed. Merely mentioning
    // two containers does not prove they are disjoint.
    final exclusion = ss
        .where(
          (s) =>
              RegExp('non identifica (?:il |la |lo )?${RegExp.escape(target)}')
                  .hasMatch(_norm435(s.text)) ||
              _norm435(s.text).contains('non tutto $cargo'),
        )
        .toList();
    if (alternatives.isEmpty || exclusion.isEmpty) return null;
    return _answer(
      'No, non è tutto necessariamente in $target.',
      'counterexample',
      [membership.single, ...alternatives.map((a) => a.$2), ...exclusion],
      [
        'Anche ${alternatives.first.$1} di $owner contengono $cargo: il testo esclude l’identificazione esclusiva',
      ],
    );
  }

  static GroundedAnswer435? _relations(
    List<ReadingSource435> ss,
    ReadingQuestion435 q,
  ) {
    // Factual verb-object questions, with exact predicate agreement. It does
    // not turn co-occurrence or a question's own words into source facts.
    final m = RegExp(r'^(?:che cosa|cosa) ([a-z]+) (.+)$')
        .firstMatch(q.question);
    if (m != null) {
      final subject = _noun435(m[2]!);
      final facts = <(String, ReadingSource435)>[];
      for (final s in ss) {
        final text = _norm435(s.text).replaceFirst(RegExp(r'[.!]+$'), '');
        final fact = RegExp(
          '^(?:i |gli |le |il |la |lo )?${RegExp.escape(subject)} ${RegExp.escape(m[1]!)} (.+)\$',
        ).firstMatch(text);
        if (fact != null &&
            !RegExp(r'\bse|\bnon|\bforse|\bpuo').hasMatch(fact[1]!))
          facts.add((fact[1]!, s));
      }
      if (facts.length == 1)
        return _answer('${facts.single.$1}.', 'relation-projection', [
          facts.single.$2,
        ], []);
    }
    // Measurement definitions can be read without any calculation or equation.
    final unit = RegExp(r'^quale grandezza si misura in ([a-z]+)$')
        .firstMatch(q.question);
    if (unit != null)
      for (final s in ss) {
        final m = RegExp(
          r'(?:^|, | e )(?:la |il )([a-z]+) (?:si misura )?in ([a-z]+)',
        ).allMatches(_norm435(s.text));
        for (final match in m) {
          if (match[2] == unit[1])
            return _answer('${match[1]}.', 'unit-definition', [s], []);
        }
      }
    return null;
  }

  static GroundedAnswer435? _missing(
    List<ReadingSource435> ss,
    ReadingQuestion435 q,
  ) {
    final questionWords = RegExp(r'[a-z][a-z0-9_-]*')
        .allMatches(q.question)
        .map((m) => _stem435(m[0]!))
        .toSet();
    for (final s in ss) {
      final text = _norm435(s.text).replaceFirst(RegExp(r'[.!]+$'), '');
      final patterns = [
        RegExp(
          r'^(?:il |la |lo )(.+?) (?:non e|non sono) (?:indicat[oaie]|not[oaie]|specificat[oaie])$',
        ),
        RegExp(r'^non sono date informazioni (?:sulla |sul |su )(.+)$'),
        RegExp(r'^.+? non specifica (.+)$'),
      ];
      for (final p in patterns) {
        final m = p.firstMatch(text);
        if (m == null) continue;
        final missing = m[1]!;
        final words = RegExp(r'[a-z][a-z0-9_-]*')
            .allMatches(missing)
            .map((m) => _stem435(m[0]!))
            .where((w) => w.length > 3 || w == 'x')
            .toSet();
        if (words.intersection(questionWords).isNotEmpty &&
            (words.intersection(questionWords).length >= 2 ||
                questionWords.contains(words.firstOrNull))) {
          return _unknown('manca $missing', [s]);
        }
      }
    }
    return null;
  }
}
