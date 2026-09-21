from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
world_path = root / 'lib' / 'sensory_world_v06.dart'
main_path = root / 'lib' / 'main.dart'
pubspec_path = root / 'pubspec.yaml'
test_path = root / 'test' / 'grounded_world_v07_test.dart'

w = world_path.read_text()

# ---------------------------------------------------------------------------
# MGD-Neuro 0.8.1: canonical identity <-> multimodal memory repair.
# A sensory pattern labelled e.g. "Persona Diego" must not live as a second
# person if the language graph already knows USER --identity--> Diego.
# ---------------------------------------------------------------------------
identity_anchor = """  ({int entityId, String label, bool identityAssertion})
      _resolveNaturalBinding071(
"""
if identity_anchor not in w:
    raise SystemExit('identity resolver anchor missing')

identity_helpers = r'''  bool _matchesUserIdentityAlias081(
    PlasticLanguageBrain04 brain,
    String? raw,
    int identityId,
  ) {
    if (raw == null || raw.trim().isEmpty) return false;
    if (identityId < 0 || identityId >= brain.entities.length) return false;

    final candidate = PlasticLanguageBrain04.normalizeText(raw);
    final canonical = PlasticLanguageBrain04.normalizeText(
      brain.entities[identityId].label,
    );
    if (candidate.isEmpty || canonical.isEmpty) return false;
    if (candidate == canonical) return true;

    // Deliberately conservative: these are representation words, not a fuzzy
    // contains() match. "Persona Diego" / "volto Diego" collapse to Diego,
    // while an unrelated name containing the same token does not.
    const wrappers = {
      'persona', 'person', 'volto', 'viso', 'faccia', 'face',
      'utente', 'user', 'ritratto', 'portrait'
    };
    for (final wrapper in wrappers) {
      if (candidate == '$wrapper $canonical') return true;
      if (candidate == '$canonical $wrapper') return true;
    }
    return false;
  }

  int repairIdentityAliases081(PlasticLanguageBrain04 brain) {
    final identity = _identityObject071(brain, brain.userId);
    if (identity == null || identity < 0 || identity >= brain.entities.length) {
      return 0;
    }

    final canonical = brain.entities[identity];
    var repaired = 0;
    for (final p in prototypes) {
      String? semanticLabel;
      final sid = p.semanticEntityId;
      if (sid != null && sid >= 0 && sid < brain.entities.length) {
        semanticLabel = brain.entities[sid].label;
      }

      final isUserNode = sid == brain.userId;
      final aliasByPattern = _matchesUserIdentityAlias081(brain, p.label, identity);
      final aliasByEntity = _matchesUserIdentityAlias081(
        brain,
        semanticLabel,
        identity,
      );
      if (!isUserNode && !aliasByPattern && !aliasByEntity) continue;

      final oldLabel = p.label?.trim();
      if (oldLabel != null && oldLabel.isNotEmpty) {
        canonical.aliases.add(PlasticLanguageBrain04.normalizeText(oldLabel));
      }
      if (semanticLabel != null && semanticLabel.trim().isNotEmpty) {
        canonical.aliases.add(
          PlasticLanguageBrain04.normalizeText(semanticLabel),
        );
      }

      final changed = p.semanticEntityId != identity ||
          PlasticLanguageBrain04.normalizeText(p.label ?? '') !=
              PlasticLanguageBrain04.normalizeText(canonical.label);
      if (!changed) continue;

      p.semanticEntityId = identity;
      p.label = canonical.label;
      p.stability = max(p.stability, 0.55);
      final e = _edge(_pNode(p.id), _eNode(identity));
      _plasticUpdate(e, reward: 1.0, coactivity: 1.0);
      repaired++;
    }
    return repaired;
  }

'''
w = w.replace(identity_anchor, identity_helpers + identity_anchor, 1)

# If the user labels a perception as "Persona Diego" after Diego is already
# known, bind directly to the canonical identity instead of creating a new
# semantic entity.
resolver_anchor = """    final words = ns.toSet();

    const firstPerson = {
"""
if resolver_anchor not in w:
    raise SystemExit('resolver body anchor missing')
resolver_new = """    final words = ns.toSet();

    final knownIdentity081 = _identityObject071(brain, brain.userId);
    if (knownIdentity081 != null &&
        _matchesUserIdentityAlias081(brain, original, knownIdentity081)) {
      final canonical = brain.entities[knownIdentity081];
      canonical.aliases.add(PlasticLanguageBrain04.normalizeText(original));
      return (
        entityId: knownIdentity081,
        label: canonical.label,
        identityAssertion: true,
      );
    }

    const firstPerson = {
"""
w = w.replace(resolver_anchor, resolver_new, 1)

# Every grounded query sees a coherent world even with a 0.8 database that
# contains an old "Persona Diego" sensory node.
grounded_anchor = """  String? groundedAnswer07(PlasticLanguageBrain04 brain, String prompt) {
    final n = PlasticLanguageBrain04.normalizeText(prompt);
"""
if grounded_anchor not in w:
    raise SystemExit('groundedAnswer07 anchor missing')
grounded_new = """  String? groundedAnswer07(PlasticLanguageBrain04 brain, String prompt) {
    repairIdentityAliases081(brain);
    final n = PlasticLanguageBrain04.normalizeText(prompt);
"""
w = w.replace(grounded_anchor, grounded_new, 1)

world_path.write_text(w)

# Persist the migration at boot so the phone database is actually healed,
# rather than merely answering one question correctly.
m = main_path.read_text()
boot_old = """    final repairedGroundings = _world.repairNaturalBindings071(_brain);
    if (repairedGroundings > 0) {
      await _persistence.save(_brain);
      await _worldPersistence.save(_world);
    }
"""
boot_new = """    final repairedGroundings = _world.repairNaturalBindings071(_brain);
    final repairedIdentities = _world.repairIdentityAliases081(_brain);
    if (repairedGroundings > 0 || repairedIdentities > 0) {
      await _persistence.save(_brain);
      await _worldPersistence.save(_world);
    }
"""
if boot_old not in m:
    raise SystemExit('boot migration anchor missing')
m = m.replace(boot_old, boot_new, 1)
m = m.replace('MGD Neuro 0.8', 'MGD Neuro 0.8.1')
m = m.replace('MGD-Neuro 0.8', 'MGD-Neuro 0.8.1')
m = m.replace('Nuovo cervello 0.8', 'Nuovo cervello 0.8.1')
m = m.replace('Cervello 0.8 ripristinato', 'Cervello 0.8.1 ripristinato')
main_path.write_text(m)

p = pubspec_path.read_text()
p = p.replace('version: 0.8.0+12', 'version: 0.8.1+13')
pubspec_path.write_text(p)

# Regression tests for the exact state visible in the phone screenshot.
t = test_path.read_text()
if "0.8 Persona Diego alias is merged into canonical user identity" not in t:
    tests = r'''

  test('0.8 Persona Diego alias is merged into canonical user identity', () {
    final brain = PlasticLanguageBrain04();
    brain.learnEvent('Mi chiamo Diego.');
    final diego = brain.entityIdForLabel06('Diego');
    expect(diego, isNotNull);

    final world = MgdWorld06();
    final result = world.observeVisionBytes(imageBytes(160, 110, 80));
    final duplicate = brain.ensureSemanticEntity06('Persona diego');
    world.bindLast(label: 'Persona diego', entityId: duplicate);

    expect(result.prototype.semanticEntityId, duplicate);
    expect(
      world.groundedAnswer07(brain, 'mi hai mai visto?')?.toLowerCase(),
      contains('sì'),
    );
    expect(result.prototype.semanticEntityId, diego);
    expect(result.prototype.label?.toLowerCase(), 'diego');
    expect(
      world.groundedAnswer07(brain, 'chi sono io?')?.toLowerCase(),
      'diego.',
    );
  });

  test('Persona Diego natural binding reuses canonical identity', () {
    final brain = PlasticLanguageBrain04();
    brain.learnEvent('Mi chiamo Diego.');
    final diego = brain.entityIdForLabel06('Diego');
    expect(diego, isNotNull);

    final world = MgdWorld06();
    world.observeVisionBytes(imageBytes(140, 100, 90));
    final canonical = world.bindLastNatural071(brain, 'Persona Diego');

    expect(canonical.toLowerCase(), 'diego');
    expect(world.prototypes.single.semanticEntityId, diego);
    expect(
      world.groundedAnswer07(brain, 'mi hai visto?')?.toLowerCase(),
      contains('sì'),
    );
  });
'''
    idx = t.rfind('\n}')
    if idx < 0:
        raise SystemExit('test file closing brace missing')
    t = t[:idx] + tests + t[idx:]
test_path.write_text(t)
