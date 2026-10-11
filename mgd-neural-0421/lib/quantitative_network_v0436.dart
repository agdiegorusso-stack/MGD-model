part of 'semantic_reasoning_v0435.dart';

/// Reusable algebra over quantities named by the retained document. This is
/// a finite, explicit-language interpreter, not a general language model.
class _Constraint436 {
  final String output;
  final _Expression435 expression;
  final List<ReadingSource435> sources;
  final String display;
  const _Constraint436(
    this.output,
    this.expression,
    this.sources,
    this.display,
  );
  Set<String> get variables => {output, ...expression.variables};
}

class _Linear436 {
  final double constant;
  final Map<String, double> coefficients;
  const _Linear436(this.constant, this.coefficients);
  _Linear436 scale(double n) => _Linear436(constant * n, {
    for (final e in coefficients.entries) e.key: e.value * n,
  });
  _Linear436 plus(_Linear436 b) => _Linear436(constant + b.constant, {
    for (final k in {...coefficients.keys, ...b.coefficients.keys})
      k: (coefficients[k] ?? 0) + (b.coefficients[k] ?? 0),
  });
  static _Linear436? read(_Expression435 e, Map<String, double> known) {
    if (e.left == null) {
      final n = double.tryParse(e.token) ?? known[e.token];
      return n != null ? _Linear436(n, {}) : _Linear436(0, {e.token: 1});
    }
    final a = read(e.left!, known), b = read(e.right!, known);
    if (a == null || b == null) return null;
    return switch (e.token) {
      '+' => a.plus(b),
      '-' => a.plus(b.scale(-1)),
      '*' when a.coefficients.isEmpty => b.scale(a.constant),
      '*' when b.coefficients.isEmpty => a.scale(b.constant),
      '/' when b.coefficients.isEmpty && b.constant != 0 => a.scale(
        1 / b.constant,
      ),
      _ => null,
    };
  }
}

class _QuantitativeNetwork436 {
  static bool _near(double a, double b) =>
      (a - b).abs() <= 1e-9 * (1 + a.abs() + b.abs());
  static _Expression435 _rename(_Expression435 e, Map<String, String> labels) =>
      _Expression435(
        labels[e.token] ?? e.token,
        e.left == null ? null : _rename(e.left!, labels),
        e.right == null ? null : _rename(e.right!, labels),
      );
  static GroundedAnswer435? answer(
    List<ReadingSource435> sources,
    ReadingQuestion435 q,
  ) {
    final constraints = <_Constraint436>[];
    for (final s in sources) {
      for (final e in _Equation435.read(s)) {
        constraints.add(
          _Constraint436(e.labels[e.output]!, _rename(e.expression, e.labels), [
            s,
          ], e.display),
        );
      }
    }
    // Symbols are meaningful only with explicit source definitions. Their
    // mappings and equations stay inside one document, as do scenario values.
    final labels = <String, String>{},
        definitions = <String, ReadingSource435>{};
    var ambiguous = false;
    for (final s in sources) {
      final text = _norm435(s.text).replaceFirst(RegExp(r'[.!]+$'), '');
      final m = RegExp(
        r"^([a-z][a-z0-9_]*) (?:indica|rappresenta) (?:il |la |lo |l')?([a-z][a-z ]*)$",
      ).firstMatch(text);
      if (m == null) continue;
      final symbol = m[1]!, label = _noun435(m[2]!);
      if (labels.containsKey(symbol) && labels[symbol] != label)
        ambiguous = true;
      labels[symbol] = label;
      definitions[symbol] = s;
    }
    for (final s in sources) {
      final text = _norm435(s.text).replaceFirst(RegExp(r'[.!]+$'), '');
      final m = RegExp(
        r'^(?:formula|equazione):\s*([a-z][a-z0-9_]*)\s*=\s*(.+)$',
      ).firstMatch(text);
      if (m == null) continue;
      final expression = _Expression435.parse(m[2]!);
      if (expression == null) continue;
      final symbols = {m[1]!, ...expression.variables};
      if (!symbols.every(labels.containsKey)) continue;
      constraints.add(
        _Constraint436(labels[m[1]]!, _rename(expression, labels), [
          s,
          ...symbols.map((v) => definitions[v]!),
        ], '${m[1]} = ${m[2]}'),
      );
    }
    // Existing single-equation paths keep their unit/vector interpretation.
    if (constraints.length < 2 && labels.isEmpty) return null;
    final variables = constraints.expand((c) => c.variables).toSet();
    final targets = variables
        .where((v) => RegExp('\\b${RegExp.escape(v)}\\b').hasMatch(q.question))
        .toList();
    if (targets.length != 1 ||
        !RegExp(r'^(quanto|qual e il valore|calcola)').hasMatch(q.question))
      return null;
    final target = targets.single;
    final needed = <String>{target}, relevant = <_Constraint436>{};
    var changed = true;
    while (changed) {
      changed = false;
      for (final c in constraints) {
        if (!relevant.contains(c) && c.variables.any(needed.contains)) {
          relevant.add(c);
          needed.addAll(c.variables);
          changed = true;
        }
      }
    }
    final usedSources = {
      for (final c in relevant)
        for (final s in c.sources) s.id: s,
    }.values.toList();
    GroundedAnswer435 unknown(String reason) => SemanticReasoning435._unknown(
      reason,
      usedSources,
      operation: 'equation-network',
    );
    if (ambiguous)
      return unknown('le definizioni dei simboli sono IN CONFLITTO');
    if (needed.length > 32 || relevant.length > 128)
      return unknown(
        'il sistema supera il limite di calcolo (32 quantità, 128 relazioni)',
      );
    final values = <String, double>{}, steps = <String>[];
    final valueSteps = <String, List<String>>{};
    // No value is extracted from the question itself or trailing instructions.
    // Different values are a conflict, not a license to pick the latest match.
    for (final variable in needed) {
      final pattern = RegExp(
        '\\b${RegExp.escape(variable)} (?:e |vale |di )?(-?$_numberPattern435)\\b',
      );
      final numbers = <double>[];
      for (final clause in q.premises) {
        final matches = pattern.allMatches(clause).toList();
        for (final m in matches) {
          // Negated, uncertain, conditional or quoted/reporting statements
          // cannot become unconditional numerical premises.
          if (RegExp(
            r'\b(non|forse|se|quando|potrebbe|dice|crede|secondo)\b|["«»]',
          ).hasMatch(clause))
            return unknown(
              'una quantità della domanda è negata, condizionata o attribuita; non è una premessa numerica certa',
            );
          final suffix = clause.substring(m.end).trimLeft();
          if (RegExp(r'^[a-z]').hasMatch(suffix) &&
              !RegExp(r'^e\b').hasMatch(suffix))
            return unknown(
              'il sistema quantitativo richiede valori scalari: l’unità o il qualificatore dopo $variable non è interpretato',
            );
          numbers.add(_number435(m[1]!)!);
        }
      }
      if (numbers.isEmpty) continue;
      if (numbers.any((n) => !_near(n, numbers.first)))
        return unknown('i valori di $variable sono IN CONFLITTO');
      values[variable] = numbers.first;
      valueSteps[variable] = [
        '$variable = ${_num435(numbers.first)} (ipotesi della domanda)',
      ];
    }
    // Ask only for a value; a supplied answer never counts as its derivation.
    final given = values.keys.toSet();
    final usedConstraints = <_Constraint436>{};
    void addValue(
      String variable,
      double value,
      Iterable<_Constraint436> from,
    ) {
      if (values.containsKey(variable) || !value.isFinite) return;
      values[variable] = value;
      final cs = from.toList();
      usedConstraints.addAll(cs);
      final parents = cs
          .expand((c) => c.variables)
          .where((v) => v != variable && values.containsKey(v));
      valueSteps[variable] = [
        ...{for (final v in parents) ...?valueSteps[v]},
        ...cs.map((c) => 'Relazione letta: ${c.display}'),
        ...cs
            .where((c) => c.variables.every(values.containsKey))
            .map(
              (c) =>
                  '${_num435(values[c.output]!)} = ${c.expression.substitute(values)}',
            ),
        '$variable = ${_num435(value)}',
      ];
    }

    for (var pass = 0; pass < 64; pass++) {
      final count = values.length;
      for (final c in relevant) {
        final absent = c.variables
            .where((v) => !values.containsKey(v))
            .toList();
        if (absent.isEmpty) {
          final rhs = c.expression.evaluate(values);
          if (rhs == null)
            return unknown(
              'una relazione contiene una divisione per zero o un risultato non finito',
            );
          if (!_near(values[c.output]!, rhs))
            return unknown(
              'i dati e le relazioni lette sono IN CONFLITTO (${c.display})',
            );
        } else if (absent.length == 1) {
          final variable = absent.single;
          final result = variable == c.output
              ? c.expression.evaluate(values)
              : c.expression.invert(variable, values[c.output]!, values);
          if (result != null) addValue(variable, result, [c]);
        }
      }
      // Repeated variables and coupled linear equations share this solver;
      // they need no domain or question-specific answer handler.
      final unknowns = needed.where((v) => !values.containsKey(v)).toList();
      final rows = <List<double>>[], rowConstraints = <Set<_Constraint436>>[];
      for (final c in relevant) {
        final rhs = _Linear436.read(c.expression, values);
        final lhs = values.containsKey(c.output)
            ? _Linear436(values[c.output]!, {})
            : _Linear436(0, {c.output: 1});
        if (rhs == null) continue;
        final line = lhs.plus(rhs.scale(-1));
        final row = [
          for (final v in unknowns) line.coefficients[v] ?? 0,
          -line.constant,
        ];
        if (!row.every((x) => x.isFinite))
          return unknown('il calcolo ha prodotto valori non finiti');
        rows.add(row);
        rowConstraints.add({c});
      }
      var pivotRow = 0;
      for (
        var col = 0;
        col < unknowns.length && pivotRow < rows.length;
        col++
      ) {
        var selected = pivotRow;
        for (var r = pivotRow + 1; r < rows.length; r++) {
          if (rows[r][col].abs() > rows[selected][col].abs()) selected = r;
        }
        if (rows[selected][col].abs() < 1e-12) continue;
        final oldRow = rows[pivotRow];
        rows[pivotRow] = rows[selected];
        rows[selected] = oldRow;
        final oldConstraints = rowConstraints[pivotRow];
        rowConstraints[pivotRow] = rowConstraints[selected];
        rowConstraints[selected] = oldConstraints;
        final divisor = rows[pivotRow][col];
        for (var j = 0; j <= unknowns.length; j++) rows[pivotRow][j] /= divisor;
        for (var r = 0; r < rows.length; r++) {
          if (r == pivotRow) continue;
          final factor = rows[r][col];
          if (factor == 0) continue;
          for (var j = 0; j <= unknowns.length; j++)
            rows[r][j] -= factor * rows[pivotRow][j];
          rowConstraints[r].addAll(rowConstraints[pivotRow]);
        }
        pivotRow++;
      }
      for (var r = 0; r < rows.length; r++) {
        final nonzero = [
          for (var j = 0; j < unknowns.length; j++)
            if (rows[r][j].abs() >= 1e-10) j,
        ];
        if (nonzero.isEmpty && rows[r].last.abs() >= 1e-8)
          return unknown('le relazioni numeriche sono IN CONFLITTO');
        if (nonzero.length == 1) {
          final j = nonzero.single;
          addValue(unknowns[j], rows[r].last / rows[r][j], rowConstraints[r]);
        }
      }
      if (values.length == count) break;
    }
    // Re-evaluate every fully bound relation independently of the solve path.
    for (final c in relevant.where(
      (c) => c.variables.every(values.containsKey),
    )) {
      final rhs = c.expression.evaluate(values);
      if (rhs == null || !_near(values[c.output]!, rhs))
        return unknown('la verifica delle relazioni non conferma la soluzione');
    }
    if (!values.containsKey(target)) {
      final missing = needed.where((v) => !values.containsKey(v)).toList();
      return unknown(
        'mancano dati o vincoli sufficienti per determinare $target: ${missing.join(', ')}',
      );
    }
    steps.addAll(valueSteps[target] ?? []);
    if (given.contains(target))
      steps.add(
        'Il valore richiesto era già fornito nella domanda; non è una nuova deduzione',
      );
    final resultSources = {
      for (final c in usedConstraints)
        for (final s in c.sources) s.id: s,
    }.values.toList();
    return SemanticReasoning435._answer(
      '${_num435(values[target]!)}.',
      'equation-network',
      resultSources.isEmpty ? usedSources : resultSources,
      steps,
    );
  }
}
