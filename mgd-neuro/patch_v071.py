from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
main_path = root / 'lib' / 'main.dart'
world_path = root / 'lib' / 'sensory_world_v06.dart'
test_path = root / 'test' / 'grounded_world_v07_test.dart'

# ---------------------------------------------------------------------------
# World model: natural-language grounding for sensory bindings.
# ---------------------------------------------------------------------------
w = world_path.read_text()

bind_anchor = """  void bindLast({required String label, required int entityId}) {
"""
if bind_anchor not in w:
    raise SystemExit('bindLast anchor not found')

helpers = r'''  bool _identityRelation071(String relation) {
    final n = PlasticLanguageBrain04.normalizeText(relation);
    return n.contains('ident') || n.contains('nom') || n.contains('chiam');
  }

  int? _identityObject071(PlasticLanguageBrain04 brain, int subjectId) {
    for (final f in brain.cognitiveFacts06()) {
      if (f.subjectId == subjectId &&
          f.objectEntityId != null &&
          _identityRelation071(f.relation)) {
        return f.objectEntityId;
      }
    }
    return null;
  }

  ({int entityId, String label, bool identityAssertion})
      _resolveNaturalBinding071(
    PlasticLanguageBrain04 brain,
    String raw,
  ) {
    final original = raw.trim();
    final surfaces = PlasticLanguageBrain04.lexicalTokens(original);
    final ns = surfaces.map(PlasticLanguageBrain04.normalizeText).toList();
    final words = ns.toSet();

    const firstPerson = {
      'io', 'mi', 'me', 'mio', 'mia', 'miei', 'mie'
    };
    const copulas = {
      'sono', 'sei', 'è', 'e', 'siamo', 'siete', 'era', 'sara', 'sarà'
    };
    const demonstratives = {
      'questo', 'questa', 'questi', 'queste', 'qui', 'foto', 'immagine'
    };
    const removable = {
      'io', 'mi', 'me', 'mio', 'mia', 'miei', 'mie',
      'sono', 'sei', 'è', 'e', 'siamo', 'siete', 'era', 'sara', 'sarà',
      'questo', 'questa', 'questi', 'queste', 'qui',
      'foto', 'immagine',
      'un', 'uno', 'una', 'il', 'lo', 'la', 'i', 'gli', 'le',
      'chiamo', 'chiama', 'chiamato', 'chiamata', 'nome'
    };

    final hasSelf = words.any(firstPerson.contains);
    final hasCopula = words.any(copulas.contains);
    final startsAsSelfAssertion =
        ns.isNotEmpty && {'sono', 'io'}.contains(ns.first);
    final selfAssertion = hasSelf && hasCopula || startsAsSelfAssertion;

    String candidateFromRemainder() {
      final kept = <String>[];
      for (var i = 0; i < surfaces.length; i++) {
        if (removable.contains(ns[i])) continue;
        kept.add(surfaces[i]);
      }
      return kept.join(' ').trim();
    }

    if (selfAssertion) {
      final candidate = candidateFromRemainder();
      if (candidate.isNotEmpty) {
        // Ground the sensory statement into the same USER --identity--> entity
        // used by language. "Sono io Diego" therefore teaches identity and
        // binds the visual pattern to Diego, not to an entity literally named
        // "sono io Diego".
        brain.learnEvent('Mi chiamo $candidate.', reward: 1.0);
        final id = brain.entityIdForLabel06(candidate) ??
            brain.ensureSemanticEntity06(candidate);
        return (
          entityId: id,
          label: brain.entities[id].label,
          identityAssertion: true,
        );
      }

      final existing = _identityObject071(brain, brain.userId);
      final id = existing ?? brain.userId;
      return (
        entityId: id,
        label: brain.entities[id].label,
        identityAssertion: true,
      );
    }

    // Natural object labels such as "questo è un cane" are grounded to
    // "cane" rather than stored as a sentence-shaped entity.
    final looksLikeDemonstrativeLabel =
        words.any(demonstratives.contains) && hasCopula;
    final startsWithCopula = ns.isNotEmpty && copulas.contains(ns.first);
    if (looksLikeDemonstrativeLabel || startsWithCopula) {
      final candidate = candidateFromRemainder();
      if (candidate.isNotEmpty) {
        final id = brain.entityIdForLabel06(candidate) ??
            brain.ensureSemanticEntity06(candidate);
        brain.learnSurface(candidate, reward: 0.25);
        return (
          entityId: id,
          label: brain.entities[id].label,
          identityAssertion: false,
        );
      }
    }

    final id = brain.entityIdForLabel06(original) ??
        brain.ensureSemanticEntity06(original);
    brain.learnSurface(original, reward: 0.25);
    return (
      entityId: id,
      label: brain.entities[id].label,
      identityAssertion: false,
    );
  }

  String bindLastNatural071(
    PlasticLanguageBrain04 brain,
    String raw,
  ) {
    final resolved = _resolveNaturalBinding071(brain, raw);
    bindLast(label: resolved.label, entityId: resolved.entityId);
    return resolved.label;
  }

  int repairNaturalBindings071(PlasticLanguageBrain04 brain) {
    var repaired = 0;
    for (final p in prototypes) {
      final raw = p.label?.trim();
      if (raw == null || raw.isEmpty) continue;

      final ns = PlasticLanguageBrain04.lexicalTokens(raw)
          .map(PlasticLanguageBrain04.normalizeText)
          .toSet();
      final sentenceLike = ns.any({
        'io', 'mi', 'me', 'sono', 'sei', 'è', 'e',
        'questo', 'questa', 'foto', 'immagine'
      }.contains);
      if (!sentenceLike) continue;

      final resolved = _resolveNaturalBinding071(brain, raw);
      final changed = p.semanticEntityId != resolved.entityId ||
          PlasticLanguageBrain04.normalizeText(raw) !=
              PlasticLanguageBrain04.normalizeText(resolved.label);
      if (!changed) continue;

      p.semanticEntityId = resolved.entityId;
      p.label = resolved.label;
      p.stability = max(p.stability, 0.55);
      final e = _edge(_pNode(p.id), _eNode(resolved.entityId));
      _plasticUpdate(e, reward: 1.0, coactivity: 1.0);
      repaired++;
    }
    return repaired;
  }

'''
w = w.replace(bind_anchor, helpers + bind_anchor, 1)

# Ground self-identity questions directly through the unified world graph.
ground_anchor = """    final selfReference = words.any({'mi', 'me', 'io', 'mio', 'mia'}.contains);

    if (selfReference && asksSeen) {
"""
ground_new = """    final selfReference = words.any({'mi', 'me', 'io', 'mio', 'mia'}.contains);

    final asksSelfIdentity = selfReference &&
        (words.contains('chi') ||
            n.contains('come mi chiam') ||
            n.contains('come sono chiam'));
    if (asksSelfIdentity) {
      final identity = _identityObject071(brain, brain.userId);
      if (identity != null && identity < brain.entities.length) {
        return brain.entities[identity].label + '.';
      }

      // A visual/audio binding may already identify the user even if the
      // language fact has not yet been explicitly queried.
      final closure = _identityClosure07(brain, brain.userId);
      for (final p in prototypes.reversed) {
        if (p.semanticEntityId != null &&
            closure.contains(p.semanticEntityId!) &&
            p.label != null &&
            p.label!.trim().isNotEmpty) {
          return p.label!.trim() + '.';
        }
      }
    }

    if (selfReference && asksSeen) {
"""
if ground_anchor not in w:
    raise SystemExit('grounded answer anchor not found')
w = w.replace(ground_anchor, ground_new, 1)

world_path.write_text(w)

# ---------------------------------------------------------------------------
# UI: binding text is an experience, not a literal entity label.
# ---------------------------------------------------------------------------
m = main_path.read_text()

boot_old = """    _brain = loaded?.brain ?? PlasticLanguageBrain04();
    _world = world ?? MgdWorld06();
    if (!mounted) return;
"""
boot_new = """    _brain = loaded?.brain ?? PlasticLanguageBrain04();
    _world = world ?? MgdWorld06();
    final repairedGroundings = _world.repairNaturalBindings071(_brain);
    if (repairedGroundings > 0) {
      await _persistence.save(_brain);
      await _worldPersistence.save(_world);
    }
    if (!mounted) return;
"""
if boot_old not in m:
    raise SystemExit('boot anchor not found')
m = m.replace(boot_old, boot_new, 1)

bind_old = """    final entityId = _brain.ensureSemanticEntity06(label);
    _brain.learnSurface(label, reward: 0.25);
    _world.bindLast(label: label, entityId: entityId);
    _world.think(_brain, cycles: 24, seedText: label);
    _senseLabel.clear();
    if (mounted) setState(() => _status = 'Percezione legata a “$label” senza classificatore esterno');
"""
bind_new = """    final canonical = _world.bindLastNatural071(_brain, label);
    _world.think(_brain, cycles: 24, seedText: canonical);
    _senseLabel.clear();
    if (mounted) {
      setState(() => _status =
          'Percezione collegata all’entità “$canonical” nel world model');
    }
"""
if bind_old not in m:
    raise SystemExit('bind UI anchor not found')
m = m.replace(bind_old, bind_new, 1)

m = m.replace('MGD Neuro 0.7', 'MGD Neuro 0.7.1')
m = m.replace('MGD-Neuro 0.7', 'MGD-Neuro 0.7.1')
main_path.write_text(m)

# ---------------------------------------------------------------------------
# Regression tests reproduce the exact phone flow:
# photo -> "sono io Diego" -> "chi sono io?" / "mi hai già visto?"
# ---------------------------------------------------------------------------
t = test_path.read_text()
if "natural self label grounds photo to user identity" not in t:
    tests = r'''

  test('natural self label grounds photo to user identity', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    world.observeVisionBytes(solidPng(180, 120, 90));
    final canonical = world.bindLastNatural071(brain, 'sono io Diego');

    expect(canonical.toLowerCase(), 'diego');
    expect(
      world.lastPerceptionSummary().toLowerCase(),
      contains('diego'),
    );
    expect(
      world.groundedAnswer07(brain, 'chi sono io?')?.toLowerCase(),
      'diego.',
    );
    expect(
      world.groundedAnswer07(brain, 'mi hai già visto?')?.toLowerCase(),
      contains('sì'),
    );
  });

  test('old sentence-shaped sensory label is repaired on load', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    final result = world.observeVisionBytes(solidPng(170, 110, 85));
    final wrong = brain.ensureSemanticEntity06('sono io Diego');
    world.bindLast(label: 'sono io Diego', entityId: wrong);

    expect(
      result.prototype.label?.toLowerCase(),
      contains('sono io diego'),
    );

    final repaired = world.repairNaturalBindings071(brain);
    expect(repaired, 1);
    expect(result.prototype.label?.toLowerCase(), 'diego');
    expect(
      world.groundedAnswer07(brain, 'chi sono io?')?.toLowerCase(),
      'diego.',
    );
  });

  test('natural object sentence binds perception to object entity', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    world.observeVisionBytes(solidPng(220, 30, 30));
    final canonical = world.bindLastNatural071(brain, 'questo è un cane');
    expect(canonical.toLowerCase(), 'cane');
    expect(world.lastPerceptionSummary().toLowerCase(), contains('cane'));
  });
'''
    idx = t.rfind('\n}')
    t = t[:idx] + tests + t[idx:]
test_path.write_text(t)
