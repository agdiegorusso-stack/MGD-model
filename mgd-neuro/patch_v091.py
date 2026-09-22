from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
world_path = root / 'lib' / 'sensory_world_v06.dart'
main_path = root / 'lib' / 'main.dart'
pubspec_path = root / 'pubspec.yaml'
test_path = root / 'test' / 'grounded_world_v07_test.dart'

w = world_path.read_text()

# Persistent explicit role binding: CURRENT_USER -> canonical entity.
field_anchor = """  int? lastLanguageEntity09;
  final Set<String> askedCuriosity09 = <String>{};
"""
if field_anchor not in w:
    raise SystemExit('world field anchor missing')
w = w.replace(
    field_anchor,
    """  int? lastLanguageEntity09;
  int? currentUserEntityId091;
  final Set<String> askedCuriosity09 = <String>{};
""",
    1,
)

# The sensory query must use the explicit role binding as well as linguistic identity facts.
sensory_old = """  List<SensoryPrototype06> sensoryForEntity07(
    PlasticLanguageBrain04 brain,
    int entityId, {
    String? modality,
  }) {
    final closure = _identityClosure07(brain, entityId);
    return prototypes.where((p) {
"""
sensory_new = """  List<SensoryPrototype06> sensoryForEntity07(
    PlasticLanguageBrain04 brain,
    int entityId, {
    String? modality,
  }) {
    final closure = _identityClosure07(brain, entityId);
    if (entityId == brain.userId && currentUserEntityId091 != null) {
      closure.add(currentUserEntityId091!);
    }
    if (currentUserEntityId091 != null &&
        entityId == currentUserEntityId091) {
      closure.add(brain.userId);
    }
    return prototypes.where((p) {
"""
if sensory_old not in w:
    raise SystemExit('sensoryForEntity07 anchor missing')
w = w.replace(sensory_old, sensory_new, 1)

# Persist explicit self-role whenever natural sensory grounding says "sono io ...".
bind_old = """  String bindLastNatural071(
    PlasticLanguageBrain04 brain,
    String raw,
  ) {
    final resolved = _resolveNaturalBinding071(brain, raw);
    bindLast(label: resolved.label, entityId: resolved.entityId);
    return resolved.label;
  }
"""
bind_new = """  String bindLastNatural071(
    PlasticLanguageBrain04 brain,
    String raw,
  ) {
    final resolved = _resolveNaturalBinding071(brain, raw);
    bindLast(label: resolved.label, entityId: resolved.entityId);
    if (resolved.identityAssertion) {
      currentUserEntityId091 = resolved.entityId;
    }
    return resolved.label;
  }

  String? bindLastFromUtterance091(
    PlasticLanguageBrain04 brain,
    String raw,
  ) {
    if (lastObservation == null) return null;
    final original = raw.trim();
    if (original.isEmpty || original.contains('?')) return null;

    final tokens = PlasticLanguageBrain04.lexicalTokens(original);
    final ns = tokens.map(PlasticLanguageBrain04.normalizeText).toList();
    final words = ns.toSet();
    const firstPerson = {'io', 'mi', 'me'};
    const copulas = {'sono', 'sei', 'è', 'e', 'era', 'sarà', 'sara'};
    const deictics = {
      'questo', 'questa', 'questi', 'queste',
      'foto', 'immagine', 'qui'
    };

    final hasSelf = words.any(firstPerson.contains);
    final hasCopula = words.any(copulas.contains);
    final hasDeictic = words.any(deictics.contains);
    final explicitSelf = hasSelf && hasCopula;
    final explicitObject = hasDeictic && hasCopula;

    if (!explicitSelf && !explicitObject) return null;
    return bindLastNatural071(brain, original);
  }

  int repairCurrentUserFromHistory091(PlasticLanguageBrain04 brain) {
    var changed = 0;

    final identity = _identityObject071(brain, brain.userId);
    if (identity != null && identity >= 0 && identity < brain.entities.length) {
      if (currentUserEntityId091 != identity) {
        currentUserEntityId091 = identity;
        changed++;
      }
      for (final p in prototypes) {
        final label = p.label?.trim();
        if (label == null || label.isEmpty) continue;
        if (_matchesUserIdentityAlias081(brain, label, identity) ||
            p.semanticEntityId == brain.userId) {
          if (p.semanticEntityId != identity ||
              PlasticLanguageBrain04.normalizeText(label) !=
                  PlasticLanguageBrain04.normalizeText(
                    brain.entities[identity].label,
                  )) {
            p.semanticEntityId = identity;
            p.label = brain.entities[identity].label;
            changed++;
          }
        }
      }
      return changed;
    }

    if (currentUserEntityId091 != null &&
        currentUserEntityId091! >= 0 &&
        currentUserEntityId091! < brain.entities.length) {
      return changed;
    }

    // Recover the exact phone scenario from existing 0.9 data:
    // a visual prototype was named "Diego", while the user had said in chat
    // "questo sono io Diego".  Match an explicit self assertion in episodic
    // language to an already labelled visual prototype; never infer identity
    // from a visual label alone.
    for (final p in prototypes.where((x) => x.modality == 'vision')) {
      final label = p.label?.trim();
      if (label == null || label.isEmpty) continue;
      final nl = PlasticLanguageBrain04.normalizeText(label);
      for (final ep in brain.episodes.reversed) {
        final text = PlasticLanguageBrain04.normalizeText(ep.userText);
        final explicitSelf =
            text.contains('sono io') ||
            text.startsWith('io sono ') ||
            text.contains('questo sono io') ||
            text.contains('questa sono io');
        if (!explicitSelf || !text.contains(nl)) continue;

        brain.learnEvent('Mi chiamo $label.', reward: 1.0);
        final id = brain.entityIdForLabel06(label) ??
            brain.ensureSemanticEntity06(label);
        currentUserEntityId091 = id;
        p.semanticEntityId = id;
        p.label = brain.entities[id].label;
        final e = _edge(_pNode(p.id), _eNode(id));
        _plasticUpdate(e, reward: 1.0, coactivity: 1.0);
        changed++;
        return changed;
      }
    }
    return changed;
  }
"""
if bind_old not in w:
    raise SystemExit('bindLastNatural071 anchor missing')
w = w.replace(bind_old, bind_new, 1)

# Existing repair path should also populate the role binding when possible.
repair_anchor = """  int repairIdentityAliases081(PlasticLanguageBrain04 brain) {
    final identity = _identityObject071(brain, brain.userId);
"""
repair_new = """  int repairIdentityAliases081(PlasticLanguageBrain04 brain) {
    final identity = _identityObject071(brain, brain.userId);
"""
# no textual change needed here; insert after null guard.
guard_old = """    if (identity == null || identity < 0 || identity >= brain.entities.length) {
      return 0;
    }

    final canonical = brain.entities[identity];
"""
guard_new = """    if (identity == null || identity < 0 || identity >= brain.entities.length) {
      return 0;
    }

    currentUserEntityId091 = identity;
    final canonical = brain.entities[identity];
"""
if guard_old not in w:
    raise SystemExit('identity repair guard missing')
w = w.replace(guard_old, guard_new, 1)

# JSON persistence.
json_old = """        'lastLanguageEntity09': lastLanguageEntity09,
        'askedCuriosity09': askedCuriosity09.toList(),
"""
json_new = """        'lastLanguageEntity09': lastLanguageEntity09,
        'currentUserEntityId091': currentUserEntityId091,
        'askedCuriosity09': askedCuriosity09.toList(),
"""
if json_old not in w:
    raise SystemExit('world toJson anchor missing')
w = w.replace(json_old, json_new, 1)

load_old = """    w.lastLanguageEntity09 = (j['lastLanguageEntity09'] as num?)?.toInt();
    w.askedCuriosity09.addAll(((j['askedCuriosity09'] as List?) ?? const []).map((e) => e.toString()));
"""
load_new = """    w.lastLanguageEntity09 = (j['lastLanguageEntity09'] as num?)?.toInt();
    w.currentUserEntityId091 =
        (j['currentUserEntityId091'] as num?)?.toInt();
    w.askedCuriosity09.addAll(((j['askedCuriosity09'] as List?) ?? const []).map((e) => e.toString()));
"""
if load_old not in w:
    raise SystemExit('world fromJson anchor missing')
w = w.replace(load_old, load_new, 1)

world_path.write_text(w)

m = main_path.read_text()

# Boot migration repairs the user's already-saved 0.9 phone state.
boot_old = """    final repairedGroundings = _world.repairNaturalBindings071(_brain);
    final repairedIdentities = _world.repairIdentityAliases081(_brain);
    final repairedTeacherFacts = _brain.repairTeacherFacts082();
    if (repairedGroundings > 0 ||
        repairedIdentities > 0 ||
        repairedTeacherFacts > 0) {
"""
boot_new = """    final repairedGroundings = _world.repairNaturalBindings071(_brain);
    final repairedIdentities = _world.repairIdentityAliases081(_brain);
    final repairedTeacherFacts = _brain.repairTeacherFacts082();
    final repairedCurrentUser =
        _world.repairCurrentUserFromHistory091(_brain);
    if (repairedGroundings > 0 ||
        repairedIdentities > 0 ||
        repairedTeacherFacts > 0 ||
        repairedCurrentUser > 0) {
"""
if boot_old not in m:
    raise SystemExit('boot migration anchor missing')
m = m.replace(boot_old, boot_new, 1)

# Chat and senses are now one interaction stream: a statement like
# "questo sono io Diego" immediately grounds the last visual perception.
send_old = """    await Future<void>.delayed(Duration.zero);
    final curiosityAnswer = _world.consumeCuriosityAnswer09(_brain, text);
    final languageAnswer = curiosityAnswer ?? _brain.respond(text);
    final grounded = curiosityAnswer == null ? _world.groundedAnswer07(_brain, text) : null;
    final answer = grounded ?? languageAnswer;
    _world.integrateLanguageExperience09(_brain, text, reward: curiosityAnswer == null ? 0.35 : 0.75);
"""
send_new = """    await Future<void>.delayed(Duration.zero);
    final sensoryGrounding =
        _world.bindLastFromUtterance091(_brain, text);
    final curiosityAnswer = sensoryGrounding == null
        ? _world.consumeCuriosityAnswer09(_brain, text)
        : null;
    final languageAnswer = (curiosityAnswer == null && sensoryGrounding == null)
        ? _brain.respond(text)
        : curiosityAnswer;
    final grounded =
        (curiosityAnswer == null && sensoryGrounding == null)
            ? _world.groundedAnswer07(_brain, text)
            : null;
    final answer = sensoryGrounding != null
        ? 'Ho collegato questa percezione a $sensoryGrounding.'
        : (grounded ?? languageAnswer ?? 'Ho incorporato questa esperienza.');
    _world.integrateLanguageExperience09(
      _brain,
      text,
      reward: sensoryGrounding != null
          ? 0.9
          : (curiosityAnswer == null ? 0.35 : 0.75),
    );
"""
if send_old not in m:
    raise SystemExit('chat send anchor missing')
m = m.replace(send_old, send_new, 1)

for a, b in [
    ('MGD Neuro 0.9', 'MGD Neuro 0.9.1'),
    ('MGD-Neuro 0.9', 'MGD-Neuro 0.9.1'),
    ('Nuovo cervello 0.9', 'Nuovo cervello 0.9.1'),
    ('Cervello 0.9 ripristinato', 'Cervello 0.9.1 ripristinato'),
]:
    m = m.replace(a, b)
main_path.write_text(m)

p = pubspec_path.read_text()
p = p.replace('version: 0.9.0+15', 'version: 0.9.1+16')
pubspec_path.write_text(p)

t = test_path.read_text()
if "chat deictic self assertion binds last photo" not in t:
    tests = r'''

  test('chat deictic self assertion binds last photo', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    world.observeVisionBytes(imageBytes(180, 120, 90));
    final canonical =
        world.bindLastFromUtterance091(brain, 'questo sono io Diego');

    expect(canonical?.toLowerCase(), 'diego');
    expect(world.currentUserEntityId091, isNotNull);
    expect(
      world.groundedAnswer07(brain, 'mi hai già visto?')?.toLowerCase(),
      contains('sì'),
    );
    expect(
      world.groundedAnswer07(brain, 'chi sono io?')?.toLowerCase(),
      'diego.',
    );
  });

  test('0.9 history migration repairs photo plus chat self assertion', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    final result = world.observeVisionBytes(imageBytes(170, 110, 80));
    final diego = brain.ensureSemanticEntity06('Diego');
    world.bindLast(label: 'Diego', entityId: diego);

    // Simulate the exact old 0.9 failure: language episode says who the
    // person is, but the sensor and CURRENT_USER role were never unified.
    brain.learnSurface('questo sono io Diego', reward: 0.3);
    expect(world.currentUserEntityId091, isNull);

    final repaired = world.repairCurrentUserFromHistory091(brain);
    expect(repaired, greaterThan(0));
    expect(world.currentUserEntityId091, diego);
    expect(result.prototype.semanticEntityId, diego);
    expect(
      world.groundedAnswer07(brain, 'mi hai già visto?')?.toLowerCase(),
      contains('sì'),
    );
  });

  test('deictic object chat assertion grounds last photo too', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    world.observeVisionBytes(imageBytes(220, 30, 30));
    final canonical =
        world.bindLastFromUtterance091(brain, 'questo è un cane');

    expect(canonical?.toLowerCase(), 'cane');
    expect(world.prototypes.single.label?.toLowerCase(), 'cane');
  });
'''
    idx = t.rfind('\n}')
    if idx < 0:
        raise SystemExit('test closing brace missing')
    t = t[:idx] + tests + t[idx:]
test_path.write_text(t)
