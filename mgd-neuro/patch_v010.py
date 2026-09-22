from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
main_path = root / 'lib' / 'main.dart'
pubspec_path = root / 'pubspec.yaml'
research_src = Path('mgd-neuro/web_knowledge_explorer_v10.dart')
research_persist_src = Path('mgd-neuro/research_persistence_v10.dart')
research_test_src = Path('mgd-neuro/web_knowledge_explorer_v10_test.dart')
research_dst = root / 'lib' / 'web_knowledge_explorer_v10.dart'
research_persist_dst = root / 'lib' / 'research_persistence_v10.dart'
research_test_dst = root / 'test' / 'web_knowledge_explorer_v10_test.dart'

research_dst.write_text(research_src.read_text())
research_persist_dst.write_text(research_persist_src.read_text())
research_test_dst.write_text(research_test_src.read_text())

m = main_path.read_text()

import_anchor = """import 'teacher_bridge_v08.dart';
import 'world_persistence_v06.dart';
"""
import_new = """import 'teacher_bridge_v08.dart';
import 'web_knowledge_explorer_v10.dart';
import 'research_persistence_v10.dart';
import 'world_persistence_v06.dart';
"""
if import_anchor not in m:
    raise SystemExit('main import anchor missing')
m = m.replace(import_anchor, import_new, 1)

field_anchor = """  final _persistence = Brain04Persistence();
  final _worldPersistence = WorldPersistence06();
  late PlasticLanguageBrain04 _brain;
  late MgdWorld06 _world;
"""
field_new = """  final _persistence = Brain04Persistence();
  final _worldPersistence = WorldPersistence06();
  final _researchPersistence = ResearchPersistence10();
  final _webExplorer = WebKnowledgeExplorer10();
  late PlasticLanguageBrain04 _brain;
  late MgdWorld06 _world;
  late ResearchMemory10 _researchMemory;
  bool _researchBusy = false;
"""
if field_anchor not in m:
    raise SystemExit('state field anchor missing')
m = m.replace(field_anchor, field_new, 1)

boot_anchor = """    final loaded = await _persistence.load();
    final world = await _worldPersistence.load();
    _brain = loaded?.brain ?? PlasticLanguageBrain04();
    _world = world ?? MgdWorld06();
"""
boot_new = """    final loaded = await _persistence.load();
    final world = await _worldPersistence.load();
    final research = await _researchPersistence.load();
    _brain = loaded?.brain ?? PlasticLanguageBrain04();
    _world = world ?? MgdWorld06();
    _researchMemory = research ?? ResearchMemory10();
"""
if boot_anchor not in m:
    raise SystemExit('boot load anchor missing')
m = m.replace(boot_anchor, boot_new, 1)

timer_old = """    _mindTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_ready || _busy) return;
      _world.think(_brain, cycles: 6);
      _mindTicks++;
      if (_mindTicks % 10 == 0) unawaited(_worldPersistence.save(_world));
      if (_mindTicks % 3 == 0) _maybeAskCuriosity09();
      if (_tab >= 1 && mounted) setState(() {});
    });
"""
timer_new = """    _mindTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_ready || _busy) return;
      _world.think(_brain, cycles: 6);
      _mindTicks++;
      if (_mindTicks % 10 == 0) {
        unawaited(_worldPersistence.save(_world));
        unawaited(_researchPersistence.save(_researchMemory));
        if (_researchMemory.enabled && !_researchBusy) {
          unawaited(_researchOnce10(autonomous: true));
        }
      } else if (_mindTicks % 3 == 0) {
        _maybeAskCuriosity09();
      }
      if (_tab >= 1 && mounted) setState(() {});
    });
"""
if timer_old not in m:
    raise SystemExit('mind timer anchor missing')
m = m.replace(timer_old, timer_new, 1)

lifecycle_old = """  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_persistence.save(_brain));
      unawaited(_worldPersistence.save(_world));
    }
  }
"""
lifecycle_new = """  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_persistence.save(_brain));
      unawaited(_worldPersistence.save(_world));
      unawaited(_researchPersistence.save(_researchMemory));
    } else if (state == AppLifecycleState.resumed &&
        _researchMemory.enabled &&
        !_researchBusy) {
      unawaited(_researchOnce10(autonomous: true));
    }
  }
"""
if lifecycle_old not in m:
    raise SystemExit('lifecycle anchor missing')
m = m.replace(lifecycle_old, lifecycle_new, 1)

save_old = """  Future<void> _save([String? label]) async {
    await _persistence.save(_brain);
    await _worldPersistence.save(_world);
    if (!mounted) return;
    setState(() => _status = label ?? 'Cervello salvato sul telefono');
  }
"""
save_new = """  Future<void> _save([String? label]) async {
    await _persistence.save(_brain);
    await _worldPersistence.save(_world);
    await _researchPersistence.save(_researchMemory);
    if (!mounted) return;
    setState(() => _status = label ?? 'Cervello salvato sul telefono');
  }

  void _setResearchEnabled10(bool enabled) {
    setState(() {
      _researchMemory.enabled = enabled;
      _researchMemory.lastStatus = enabled
          ? 'Ricerca autonoma Internet attiva.'
          : 'Ricerca autonoma Internet disattivata.';
    });
    unawaited(_researchPersistence.save(_researchMemory));
    if (enabled) unawaited(_researchOnce10(autonomous: true));
  }

  Future<void> _researchOnce10({
    bool autonomous = false,
    bool allowWhileBusy = false,
  }) async {
    if (!_ready || _researchBusy || !_researchMemory.enabled) return;
    if (_busy && !allowWhileBusy) return;

    final goal = _webExplorer.selectGoal(_brain, _world, _researchMemory);
    if (goal == null) {
      if (!autonomous && mounted) {
        setState(() => _status =
            'Non vedo ancora un vuoto informativo abbastanza utile da giustificare una ricerca.');
      }
      return;
    }
    if (!_researchMemory.canResearch(goal.query)) return;

    final now = DateTime.now();
    _researchMemory.beginQuery(goal.query, now);
    _researchMemory.lastStatus =
        'Sto approfondendo “${goal.focusLabel.isEmpty ? goal.query : goal.focusLabel}” su più fonti…';
    _researchMemory.lastError = null;
    _researchBusy = true;
    if (mounted) {
      setState(() {
        if (!autonomous || _tab == 2) _status = _researchMemory.lastStatus;
      });
    }

    try {
      final draft = await _webExplorer.research(goal);

      if (!allowWhileBusy) {
        var waits = 0;
        while (_busy && waits < 40) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          waits++;
        }
        if (_busy) {
          _researchMemory.lastStatus =
              'Ricerca completata ma integrazione rimandata: il cervello era occupato.';
          await _researchPersistence.save(_researchMemory);
          return;
        }
      }

      final outcome =
          _webExplorer.integrate(_brain, _world, _researchMemory, draft);
      await _persistence.save(_brain);
      await _worldPersistence.save(_world);
      await _researchPersistence.save(_researchMemory);
      if (mounted) {
        setState(() {
          _status = outcome.summary;
        });
      }
    } catch (e) {
      _researchMemory.lastError = e.toString();
      _researchMemory.lastStatus = 'Errore ricerca Internet: $e';
      await _researchPersistence.save(_researchMemory);
      if (mounted) setState(() => _status = _researchMemory.lastStatus);
    } finally {
      _researchBusy = false;
      if (mounted) setState(() {});
    }
  }
"""
if save_old not in m:
    raise SystemExit('save anchor missing')
m = m.replace(save_old, save_new, 1)

sleep_old = """    _brain.sleepReplay(cycles: 72);
    _world.sleepReplay(cycles: 72);
    _world.think(_brain, cycles: 32);
    await _save('Sonno completato • memoria lenta protetta');
    _maybeAskCuriosity09();
"""
sleep_new = """    _brain.sleepReplay(cycles: 72);
    _world.sleepReplay(cycles: 72);
    _world.think(_brain, cycles: 32);
    if (_researchMemory.enabled) {
      await _researchOnce10(autonomous: true, allowWhileBusy: true);
    }
    await _save('Sonno completato • memoria consolidata e conoscenza verificata');
    _maybeAskCuriosity09();
"""
if sleep_old not in m:
    raise SystemExit('sleep anchor missing')
m = m.replace(sleep_old, sleep_new, 1)

reset_old = """    await _persistence.clear();
    await _worldPersistence.clear();
    setState(() {
      _brain = PlasticLanguageBrain04();
      _world = MgdWorld06();
      _messages.clear();
      _status = 'Nuovo cervello 0.9.1 creato';
    });
"""
reset_new = """    await _persistence.clear();
    await _worldPersistence.clear();
    await _researchPersistence.clear();
    setState(() {
      _brain = PlasticLanguageBrain04();
      _world = MgdWorld06();
      _researchMemory = ResearchMemory10();
      _messages.clear();
      _status = 'Nuovo cervello 0.10 creato';
    });
"""
if reset_old not in m:
    raise SystemExit('reset anchor missing')
m = m.replace(reset_old, reset_new, 1)

page_old = """      _MindPage07(
        brain: _brain,
        world: _world,
        busy: _busy,
        onThink: _think06,
        onSleep: _sleep,
        onSave: _save,
        onReset: _reset,
      ),
"""
page_new = """      _MindPage07(
        brain: _brain,
        world: _world,
        research: _researchMemory,
        busy: _busy,
        researchBusy: _researchBusy,
        onThink: _think06,
        onSleep: _sleep,
        onResearch: () => _researchOnce10(autonomous: false),
        onResearchEnabled: _setResearchEnabled10,
        onSave: _save,
        onReset: _reset,
      ),
"""
if page_old not in m:
    raise SystemExit('Mind page construction anchor missing')
m = m.replace(page_old, page_new, 1)

mind_class_old = """class _MindPage07 extends StatelessWidget {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final bool busy;
  final Future<void> Function() onThink;
  final Future<void> Function() onSleep;
  final Future<void> Function([String?]) onSave;
  final Future<void> Function() onReset;

  const _MindPage07({
    required this.brain,
    required this.world,
    required this.busy,
    required this.onThink,
    required this.onSleep,
    required this.onSave,
    required this.onReset,
  });
"""
mind_class_new = """class _MindPage07 extends StatelessWidget {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final ResearchMemory10 research;
  final bool busy;
  final bool researchBusy;
  final Future<void> Function() onThink;
  final Future<void> Function() onSleep;
  final Future<void> Function() onResearch;
  final ValueChanged<bool> onResearchEnabled;
  final Future<void> Function([String?]) onSave;
  final Future<void> Function() onReset;

  const _MindPage07({
    required this.brain,
    required this.world,
    required this.research,
    required this.busy,
    required this.researchBusy,
    required this.onThink,
    required this.onSleep,
    required this.onResearch,
    required this.onResearchEnabled,
    required this.onSave,
    required this.onReset,
  });
"""
if mind_class_old not in m:
    raise SystemExit('Mind page class anchor missing')
m = m.replace(mind_class_old, mind_class_new, 1)

ui_anchor = """        _Meter04(label: 'Memoria lenta linguistica', value: bs.meanSlow.clamp(0, 1)),
        const SizedBox(height: 12),
        Wrap(
"""
ui_new = """        _Meter04(label: 'Memoria lenta linguistica', value: bs.meanSlow.clamp(0, 1)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: research.enabled,
                  onChanged: busy || researchBusy ? null : onResearchEnabled,
                  title: const Text('Esplorazione autonoma Internet'),
                  subtitle: const Text(
                    'MGD sceglie cosa approfondire in base a incertezza, rilevanza, curiosità e valore di ponte nel grafo. Cerca su Wikipedia IT, Wikidata e DuckDuckGo; le informazioni web entrano solo come prior deboli con provenienza.',
                  ),
                  secondary: const Icon(Icons.travel_explore),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Metric04('Conoscenze web', '${research.claims.length}'),
                    _Metric04('Evidenze', '${research.evidence.length}'),
                    _Metric04(
                      'Oggi',
                      '${research.requestsToday}/${research.dailyBudget}',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: !research.enabled || busy || researchBusy
                      ? null
                      : onResearch,
                  icon: researchBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.public),
                  label: Text(researchBusy ? 'Sto studiando…' : 'Studia ora'),
                ),
                const SizedBox(height: 8),
                Text(research.lastStatus),
                if (research.lastGoal != null && research.lastGoal!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ultimo obiettivo: ${research.lastGoal}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (research.claims.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Conoscenza ricercata recente',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  ...((research.claims.values.toList()
                        ..sort((a, b) => b.lastSeenIso.compareTo(a.lastSeenIso)))
                      .take(4)
                      .map(
                        (c) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.manage_search, size: 20),
                          title: Text('${c.subject} — ${c.relation} → ${c.object}'),
                          subtitle: Text(
                            'RICERCATO • ${c.independentSourceCount} famiglie di fonte • ${c.evidenceCount} evidenze${c.conflict ? ' • conflitto aperto' : ''}',
                          ),
                          trailing: Text('${(c.confidence * 100).round()}%'),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
"""
if ui_anchor not in m:
    raise SystemExit('Mind web panel UI anchor missing')
m = m.replace(ui_anchor, ui_new, 1)

m = m.replace('MGD Neuro 0.9.1', 'MGD Neuro 0.10')
m = m.replace('MGD-Neuro 0.9.1', 'MGD-Neuro 0.10')
m = m.replace('Nuovo cervello 0.9.1', 'Nuovo cervello 0.10')
m = m.replace('Cervello 0.9.1 ripristinato', 'Cervello 0.10 ripristinato')
main_path.write_text(m)

p = pubspec_path.read_text()
p = p.replace('version: 0.9.1+16', 'version: 0.10.0+17')
pubspec_path.write_text(p)
