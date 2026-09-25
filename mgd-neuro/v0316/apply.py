"""Apply 0.31.6 to the exact validated 0.31.5 application sources."""
from pathlib import Path
import hashlib
import shutil
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
folder = Path(__file__).parent

def replace_once(text, old, new):
    if text.count(old) != 1:
        raise SystemExit(f'Expected one anchor, found {text.count(old)}: {old[:100]}')
    return text.replace(old, new, 1)

world_path = root/'lib/sensory_world_v06.dart'
w = world_path.read_text()
w = replace_once(w, "import 'native_mgd_engine_v09.dart';", "import 'native_mgd_engine_v09.dart';\n\npart 'curiosity_policy_v0316.dart';")
start = w.index('  String? nextCuriosityQuestion09(')
stop = w.index('  void bindLast({', start)
w = w[:start] + '''  String? nextCuriosityQuestion09(PlasticLanguageBrain04 brain) =>
      nextCuriosityQuestion316(brain);

  String? consumeCuriosityAnswer09(PlasticLanguageBrain04 brain, String raw) =>
      consumeCuriosityAnswer316(brain, raw);

''' + w[stop:]
# The index in 0.31.6 replaces repeated full fact scans.
start = w.index('  bool _hasDirectFact09(')
stop = w.index('  int get _cognitiveClock09', start)
w = w[:start] + w[stop:]
world_path.write_text(w)

main_path = root/'lib/main.dart'
s = main_path.read_text()
s = replace_once(s, "import 'knowledge_inspector_v0315.dart';", "import 'knowledge_inspector_v0315.dart';\nimport 'curiosity_actions_v0316.dart';")
s = s.replace('MGD Neuro 0.31.5', 'MGD Neuro 0.31.6')
s = replace_once(s, '  final String? prompt;\n\n  ChatMessage04({required this.user, required this.text, this.prompt});',
'''  final String? prompt;
  final String? curiosityKey316;

  ChatMessage04({required this.user, required this.text, this.prompt, this.curiosityKey316});''')
s = replace_once(s, '      _world = world ?? MgdWorld06();', '''      _world = world ?? MgdWorld06();
      final repairedQuestion316 = _world.repairPendingCuriosity316(_brain);
      if (_world.pendingCuriosityKey316 != null) {
        _messages.add(ChatMessage04(user: false,
          text: _world.pendingCuriosityQuestion09!, curiosityKey316: _world.pendingCuriosityKey316));
      }
      if (repairedQuestion316) unawaited(_worldPersistence.save(_world));''')
s = replace_once(s, '''  void _maybeAskCuriosity09() {
    if (!mounted || !_ready || _busy) return;''', '''  void _maybeAskCuriosity09() {
    if (!mounted || !_ready || _busy || _tab != 0 || _chat.text.trim().isNotEmpty) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;''')
s = replace_once(s, '_messages.add(ChatMessage04(user: false, text: q));',
    '_messages.add(ChatMessage04(user: false, text: q, curiosityKey316: _world.pendingCuriosityKey316));')
s = replace_once(s, '''      _status = 'MGD ha rilevato un vuoto informativo e ha formulato una domanda.';
    });
    _scrollDown();''', '''      _status = 'Domanda aperta: puoi rispondere, correggere o saltare.';
    });
    unawaited(_worldPersistence.save(_world));
    _scrollDown();''')
s = replace_once(s, '''  void _maybeSpeak20() {
    if (!mounted || !_ready || _busy || _tab != 0 || !_uiIdle18) return;''', '''  void _maybeSpeak20() {
    if (!mounted || !_ready || _busy || _tab != 0 || !_uiIdle18 ||
        _world.pendingCuriosityQuestion09 != null || _chat.text.trim().isNotEmpty) return;''')
# Control messages never go through response reinforcement, surface ingestion or
# geometry co-activation. The same handler serves typed and button responses.
s = replace_once(s, '  Future<void> _send() async {', '''  Future<void> _curiosityResult316(String userText, String acknowledgement) async {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage04(user: true, text: userText));
      _messages.add(ChatMessage04(user: false, text: acknowledgement));
      _status = acknowledgement;
    });
    _scrollDown();
    await _save('Domanda gestita e memoria salvata');
  }

  Future<void> _send() async {''')
s = replace_once(s, '''    await Future<void>.delayed(Duration.zero);
    final sensoryGrounding =''', '''    await Future<void>.delayed(Duration.zero);
    final questionAnswer316 = _world.consumeCuriosityAnswer09(_brain, text);
    if (questionAnswer316 != null) {
      try {
        if (!mounted) return;
        setState(() {
          _messages.add(ChatMessage04(user: false, text: questionAnswer316));
          _status = questionAnswer316;
        });
        _scrollDown();
        await _save('Domanda gestita e memoria salvata');
      } catch (e) {
        if (mounted) setState(() => _status = 'Salvataggio non completato: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    final sensoryGrounding =''')
start = s.index('    final c = TextEditingController();', s.index('  Future<void> _correct('))
stop = s.index('    if (answer == null || answer.isEmpty) return;', start)
s = s[:start] + '''    if (_busy) return;
    final answer = await showTextDialog316(context,
      title: 'Correzione one-shot', hint: 'Scrivi la risposta corretta…');
    if (!mounted) return;
''' + s[stop:]
start = s.index('    final c = TextEditingController(text: initial);', s.index('  Future<String?> _askVariationText029('))
stop = s.index('  Future<String?> _variationMode029', start)
s = s[:start] + '''    return showTextDialog316(context, title: title, hint: hint,
      initial: initial, confirm: 'Collega');
  }

''' + s[stop:]
s = replace_once(s, '''      _LivePage07(
        messages: _messages,''', '''      LivePage07(
        brain: _brain,
        onCuriosityBusy316: (value) { if (mounted) setState(() => _busy = value); },
        onCuriosityResult316: _curiosityResult316,
        messages: _messages,''')
s = replace_once(s, 'class _LivePage07 extends StatelessWidget {', '''class LivePage07 extends StatelessWidget {
  final PlasticLanguageBrain04 brain;
  final ValueChanged<bool> onCuriosityBusy316;
  final Future<void> Function(String, String) onCuriosityResult316;''')
s = replace_once(s, '  const _LivePage07({', '''  const LivePage07({
    super.key,
    required this.brain,
    required this.onCuriosityBusy316,
    required this.onCuriosityResult316,''')
s = replace_once(s, '''                            if (!msg.user) ...[
                              const SizedBox(height: 8),''', '''                            if (!msg.user && msg.curiosityKey316 != null)
                              CuriosityActions316(
                                key: ValueKey(msg.curiosityKey316), brain: brain,
                                world: world, questionKey: msg.curiosityKey316!, busy: busy,
                                onBusy: onCuriosityBusy316, onResult: onCuriosityResult316,
                              ),
                            if (!msg.user && msg.prompt != null && msg.curiosityKey316 == null) ...[
                              const SizedBox(height: 8),''')
main_path.write_text(s)
pubspec = root/'pubspec.yaml'
pubspec.write_text(replace_once(pubspec.read_text(), 'version: 0.31.5+54', 'version: 0.31.6+55'))
for name in ['curiosity_policy_v0316.dart', 'curiosity_actions_v0316.dart']:
    shutil.copyfile(folder/name, root/'lib'/name)
shutil.copyfile(folder/'curiosity_v0316_test.dart', root/'test/curiosity_v0316_test.dart')
# This old test codified the faulty assumption. Replace it with a regression
# proving that an already-known common category does NOT request a new one.
p = root/'test/grounded_world_v07_test.dart'
t = p.read_text()
start = t.index("  test('geometry-first cluster can be named by answering MGD'")
stop = t.index("  test('chat deictic self assertion", start)
t = t[:start] + '''  test('known common category does not request a new cluster name', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    brain.learnEvent('Cane è animale.');
    brain.learnEvent('Gatto è animale.');
    for (var i = 0; i < 8; i++) {
      world.integrateLanguageExperience09(brain, 'Cane e gatto.', reward: 0.9);
    }
    expect(world.nextCuriosityQuestion09(brain), isNull);
    expect(world.pendingCuriosityType09, isNull);
  });

''' + t[stop:]
p.write_text(t)
print('Applied MGD Neuro 0.31.6+55: typed question actions, safe relation policy, pending-state migration.')
