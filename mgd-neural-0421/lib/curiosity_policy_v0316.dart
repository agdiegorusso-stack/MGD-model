part of 'sensory_world_v06.dart';

/// Curiosity is a question, never an implicit taxonomy assertion.
class _KnownRelations316 {
  final Set<String> pairs = <String>{};
  final Map<int, Set<int>> parents = <int, Set<int>>{};
  _KnownRelations316(PlasticLanguageBrain04 brain) {
    for (final f in brain.cognitiveFacts06()) {
      final b = f.objectEntityId;
      if (b == null || b < 0 || f.subjectId < 0) continue;
      pairs.add(pair(f.subjectId, b));
      final key = brain.relations[f.relationId].key;
      if (key.endsWith(':generic-is') || f.relation == 'is_a') {
        parents.putIfAbsent(f.subjectId, () => <int>{}).add(b);
      }
    }
  }
  static String pair(int a, int b) => '${min(a, b)}:${max(a, b)}';
  Set<int> ancestors(int id) {
    final seen = <int>{};
    final queue = <int>[id];
    for (var i = 0; i < queue.length && i < 64; i++) {
      for (final p in parents[queue[i]] ?? const <int>{}) {
        if (seen.add(p) && queue.length < 64) queue.add(p);
      }
    }
    return seen;
  }
  bool explains(int a, int b) {
    if (a == b || pairs.contains(pair(a, b))) return true;
    final aa = ancestors(a), bb = ancestors(b);
    return aa.contains(b) || bb.contains(a) || aa.intersection(bb).isNotEmpty;
  }
}

extension CuriosityPolicy316 on MgdWorld06 {
  String? get pendingCuriosityKey316 => pendingCuriosityQuestion09 == null
      ? null
      : jsonEncode([pendingCuriosityType09, pendingCuriosityPrototype09,
          pendingCuriosityEntities09, pendingCuriosityQuestion09]);

  bool dismissCuriosity316({String? expectedKey}) {
    if (pendingCuriosityQuestion09 == null ||
        (expectedKey != null && expectedKey != pendingCuriosityKey316)) return false;
    if (pendingCuriosityEntities09.length == 2) {
      askedCuriosity09.add('relation:${_KnownRelations316.pair(
          pendingCuriosityEntities09[0], pendingCuriosityEntities09[1])}');
    }
    pendingCuriosityType09 = null;
    pendingCuriosityQuestion09 = null;
    pendingCuriosityPrototype09 = null;
    pendingCuriosityEntities09 = <int>[];
    curiosityCooldown09 = _cognitiveClock09 + 16;
    return true;
  }

  void _setRelationQuestion316(PlasticLanguageBrain04 brain, int a, int b) {
    pendingCuriosityType09 = 'relation';
    pendingCuriosityPrototype09 = null;
    pendingCuriosityEntities09 = <int>[a, b];
    pendingCuriosityQuestion09 =
        'Ho osservato ${brain.entities[a].label} e ${brain.entities[b].label} '
        'insieme, ma questo non basta a stabilire un rapporto. '
        'Sai indicarmi se e come sono collegati?';
    askedCuriosity09.add('relation:${_KnownRelations316.pair(a, b)}');
  }

  /// Restores valid pending questions; migrates old name-a-cluster requests.
  /// Does not delete knowledge, create categories, or rewire stored facts.
  bool repairPendingCuriosity316(PlasticLanguageBrain04 brain) {
    if (pendingCuriosityQuestion09 == null) return false;
    if (pendingCuriosityType09 == 'prototype-label') {
      final id = pendingCuriosityPrototype09;
      final valid = prototypes.any((p) => p.id == id &&
          (p.label == null || p.label!.trim().isEmpty));
      return valid ? false : dismissCuriosity316();
    }
    final ids = pendingCuriosityEntities09;
    if (ids.length < 2 || ids.any((id) => id < 0 || id >= brain.entities.length) ||
        ids.toSet().length != ids.length) return dismissCuriosity316();
    final known = _KnownRelations316(brain);
    if (pendingCuriosityType09 == 'concept-name') {
      for (var i = 0; i < ids.length && i < 7; i++) {
        for (var j = i + 1; j < ids.length && j < 7; j++) {
          if (!known.explains(ids[i], ids[j])) {
            _setRelationQuestion316(brain, ids[i], ids[j]);
            return true;
          }
        }
      }
      return dismissCuriosity316();
    }
    if (pendingCuriosityType09 != 'relation' || ids.length != 2 ||
        known.explains(ids[0], ids[1])) return dismissCuriosity316();
    return false;
  }

  String? nextCuriosityQuestion316(PlasticLanguageBrain04 brain) {
    if (pendingCuriosityQuestion09 != null || _cognitiveClock09 < curiosityCooldown09) return null;
    SensoryPrototype06? best;
    var score = 0.0;
    for (final p in prototypes) {
      if ((p.label != null && p.label!.trim().isNotEmpty) || p.observations < 3 ||
          p.stability < 0.18 || askedCuriosity09.contains('prototype:${p.id}')) continue;
      final s = MgdMath09.curiosityScore(novelty: 1,
          uncertainty: (0.55 + 0.45 * (1 - p.stability)).clamp(0.0, 1.0),
          relevance: (p.observations / 6.0).clamp(0.0, 1.0), stability: p.stability);
      if (s > score) { score = s; best = p; }
    }
    if (best != null && score >= 0.10) {
      pendingCuriosityType09 = 'prototype-label';
      pendingCuriosityPrototype09 = best.id;
      pendingCuriosityEntities09 = <int>[];
      final kind = best.modality == 'vision' ? 'visivo' : 'uditivo';
      pendingCuriosityQuestion09 = 'Ho riconosciuto più volte lo stesso pattern $kind, '
          'ma non so come chiamarlo. Che cos’è / chi è?';
      askedCuriosity09.add('prototype:${best.id}');
      curiosity = max(curiosity, score);
      return pendingCuriosityQuestion09;
    }
    // Co-activation alone cannot justify a class: ask only about a relation.
    // One fact index per pass, a bounded candidate buffer, no global edge sort.
    final known = _KnownRelations316(brain);
    final ranked = <WorldEdge06>[];
    var scanned = 0;
    for (final e in edges.values) {
      if (++scanned > 12000) break;
      final a = _entityIdFromWorldNode09(e.a), b = _entityIdFromWorldNode09(e.b);
      if (a < 0 || b < 0 || a == b || a >= brain.entities.length ||
          b >= brain.entities.length || e.uses < 5 || e.slow < 0.08 ||
          e.cost > MgdMath09.defaults.epsilon ||
          askedCuriosity09.contains('relation:${_KnownRelations316.pair(a, b)}')) continue;
      ranked.add(e);
      ranked.sort((x, y) => _strength(y).compareTo(_strength(x)));
      if (ranked.length > 16) ranked.removeLast();
    }
    for (final e in ranked) {
      final a = _entityIdFromWorldNode09(e.a), b = _entityIdFromWorldNode09(e.b);
      if (known.explains(a, b)) continue;
      _setRelationQuestion316(brain, a, b);
      curiosity = max(curiosity, 0.68);
      return pendingCuriosityQuestion09;
    }
    return null;
  }

  /// Explicit endpoints and direction, never "make every member an is_a".
  String teachCuriosityRelation316(PlasticLanguageBrain04 brain, {
    required String expectedKey, required String relation, bool reverse = false,
  }) {
    if (pendingCuriosityKey316 != expectedKey) return 'Questa domanda è già stata chiusa.';
    final ids = List<int>.from(pendingCuriosityEntities09);
    if (pendingCuriosityType09 != 'relation' || ids.length != 2 ||
        ids.any((id) => id < 0 || id >= brain.entities.length) || ids[0] == ids[1]) {
      return 'Non posso registrare una relazione con questi elementi.';
    }
    const allowed = {'is_a', 'part_of', 'ha', 'related_to', 'used_for'};
    if (!allowed.contains(relation)) return 'Scegli una relazione esplicita nel riquadro.';
    final a = ids[reverse ? 1 : 0], b = ids[reverse ? 0 : 1];
    final known = _KnownRelations316(brain);
    if (relation == 'is_a' && known.ancestors(b).contains(a)) {
      return 'Questa classificazione creerebbe un ciclo. Non ho modificato la memoria.';
    }
    brain.importTeacherFact08(subject: brain.entities[a].label, relation: relation,
        object: brain.entities[b].label, confidence: 0.96, source: 'utente-curiosita-0.31.6');
    importTeacherSemanticLink08(a, b, 0.76, confidence: 0.90);
    dismissCuriosity316(expectedKey: expectedKey);
    return 'Ho registrato la relazione indicata da te: '
        '${brain.entities[a].label} — $relation → ${brain.entities[b].label}.';
  }

  String? consumeCuriosityAnswer316(PlasticLanguageBrain04 brain, String raw) {
    if (pendingCuriosityType09 == null || pendingCuriosityQuestion09 == null) return null;
    final text = raw.trim();
    final n = PlasticLanguageBrain04.canonicalObject(text);
    if (const {'salta', 'non so', 'non lo so', 'non ora'}.contains(n)) {
      dismissCuriosity316();
      return 'Domanda saltata. Non ho aggiunto categorie o relazioni.';
    }
    if (text.isEmpty || text.endsWith('?')) return null;
    if (pendingCuriosityType09 == 'concept-name') {
      repairPendingCuriosity316(brain);
      if (pendingCuriosityQuestion09 == null) {
        return 'Ho ritirato la vecchia domanda: non serviva una nuova categoria. La memoria non è stata modificata.';
      }
    }
    if (pendingCuriosityType09 == 'prototype-label') {
      if (PlasticLanguageBrain04.lexicalTokens(text).length > 16) {
        return 'Per dare un nome alla percezione usa una descrizione breve, oppure premi Salta.';
      }
      final id = pendingCuriosityPrototype09;
      if (id == null || !prototypes.any((p) => p.id == id)) {
        dismissCuriosity316();
        return 'La percezione non è più disponibile. Non ho modificato la memoria.';
      }
      final label = bindPrototypeNatural09(brain, id, text);
      dismissCuriosity316();
      return 'Ho collegato la percezione a “$label”.';
    }
    if (pendingCuriosityType09 != 'relation' || pendingCuriosityEntities09.length != 2) {
      dismissCuriosity316();
      return 'Domanda non più valida. Non ho modificato la memoria.';
    }
    final ids = pendingCuriosityEntities09;
    if (ids.any((id) => id < 0 || id >= brain.entities.length)) {
      dismissCuriosity316();
      return 'Domanda non più valida. Non ho modificato la memoria.';
    }
    // Recognize only unambiguous, explicit statements about the two endpoints.
    // Unrecognized prose is NOT treated as a category or silently learned.
    const relations = <String, String>{
      'è un tipo di': 'is_a', 'è una forma di': 'is_a', 'è un': 'is_a',
      'è una': 'is_a', 'è': 'is_a', 'is_a': 'is_a',
      'è parte di': 'part_of', 'fa parte di': 'part_of',
      'ha': 'ha', 'è collegato a': 'related_to', 'è collegata a': 'related_to',
      'serve a': 'used_for',
    };
    String stripArticle(String x) => PlasticLanguageBrain04.canonicalObject(x)
        .replaceFirst(RegExp(r"^(il |lo |la |i |gli |le |un |una |uno |l')"), '');
    Set<String> names(int id) => <String>{
      brain.entities[id].label, ...brain.entities[id].aliases,
      brain.entities[id].label.split(' · ').first,
    }.map(stripArticle).where((s) => s.isNotEmpty).toSet();
    final input = stripArticle(n);
    for (final reverse in [false, true]) {
      final aa = names(ids[reverse ? 1 : 0]), bb = names(ids[reverse ? 0 : 1]);
      for (final a in aa) {
        if (!input.startsWith('$a ')) continue;
        final rest = input.substring(a.length + 1);
        for (final r in relations.entries) {
          if (rest.startsWith('${r.key} ') && bb.contains(stripArticle(rest.substring(r.key.length + 1)))) {
            return teachCuriosityRelation316(brain, expectedKey: pendingCuriosityKey316!,
                relation: r.value, reverse: reverse);
          }
        }
      }
    }
    return 'Non ho interpretato questa frase con sufficiente certezza. '
        'Premi Rispondi per scegliere i due elementi, il verso e la relazione, oppure Salta. '
        'Non ho aggiunto nulla alla memoria.';
  }
}
