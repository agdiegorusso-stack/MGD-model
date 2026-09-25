import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';

import 'persistence.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'teacher_bridge_v08.dart';
import 'web_knowledge_explorer_v11.dart';
import 'research_persistence_v11.dart';
import 'brain_admin_v012.dart';
import 'knowledge_editor_v012.dart';
import 'navigable_graph_v013.dart';
import 'multimodal_concept_v016.dart';
import 'mgd_scaling_lab_v016.dart';
import 'knowledge_snapshot_v012.dart';
import 'world_persistence_v06.dart';
import 'mgd_language_v020.dart';
import 'cognitive_induction_v024.dart';
import 'mgd_state_store_v026.dart';
import 'memory_runtime_v0319.dart';
import 'learning_service_v0321.dart';
import 'reasoning_v0321.dart';
import 'source_memory_page_v0323.dart';
import 'relational_memory_v0324.dart';
import 'relational_memory_page_v0324.dart';
import 'learned_reader_v0324.dart';
import 'knowledge_inspector_v0315.dart';
import 'curiosity_actions_v0316.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MgdNeuro04App());
}

class MgdNeuro04App extends StatelessWidget {
  const MgdNeuro04App({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C8CFF),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MGD Neuro 0.32.4',
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B0E13),
      ),
      home: const Brain04Home(),
    );
  }
}

class ChatMessage04 {
  final bool user;
  final String text;
  final String? prompt;
  final String? curiosityKey316;

  ChatMessage04(
      {required this.user,
      required this.text,
      this.prompt,
      this.curiosityKey316});
}

class Brain04Home extends StatefulWidget {
  const Brain04Home({super.key});

  @override
  State<Brain04Home> createState() => _Brain04HomeState();
}

class _Brain04HomeState extends State<Brain04Home> with WidgetsBindingObserver {
  final _checkpointWriter319 = MemoryCheckpoint319();
  AppLifecycleState _lifecycle319 = AppLifecycleState.resumed;
  final _persistence = Brain04Persistence();
  final _worldPersistence = WorldPersistence06();
  final _researchPersistence = ResearchPersistence11();
  final _webExplorer = WebKnowledgeExplorer11();
  final _languagePersistence20 = MgdLanguagePersistence20();
  late MgdLanguage20 _language20;
  DateTime _lastSpontaneous20 = DateTime.fromMillisecondsSinceEpoch(0);
  late PlasticLanguageBrain04 _brain;
  late MgdWorld06 _world;
  late ResearchMemory11 _researchMemory;
  bool _researchBusy = false;
  bool _maintenance317 = false;
  String? _bootError318;
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  final _senseLabel = TextEditingController();
  SensoryResult06? _lastSense;
  Timer? _mindTimer;
  int _mindTicks = 0;
  bool _autoSaveInFlight17 = false;
  DateTime _lastUserInteraction18 = DateTime.now();
  final List<double> _recentFrameMs18 = <double>[];
  int _jankFrames18 = 0;
  double _worstFrameMs18 = 0;

  bool get _uiIdle18 =>
      DateTime.now().difference(_lastUserInteraction18) >
      const Duration(seconds: 3);

  double get _frameP9518 {
    if (_recentFrameMs18.isEmpty) return 0;
    final xs = List<double>.from(_recentFrameMs18)..sort();
    final i = ((xs.length - 1) * 0.95).round().clamp(0, xs.length - 1);
    return xs[i];
  }

  void _markInteraction18() {
    _lastUserInteraction18 = DateTime.now();
  }

  void _onFrameTimings18(List<FrameTiming> timings) {
    for (final t in timings) {
      final ms = t.totalSpan.inMicroseconds / 1000.0;
      _recentFrameMs18.add(ms);
      if (_recentFrameMs18.length > 180) _recentFrameMs18.removeAt(0);
      if (ms > 24.0) _jankFrames18++;
      if (ms > _worstFrameMs18) _worstFrameMs18 = ms;
    }
  }

  final _chat = TextEditingController();
  final _teach = TextEditingController(
    text:
        'Il cane è animale. Il gatto è animale. Il cane mangia carne. Il gatto mangia carne. '
        'Roma è città. Milano è città.',
  );
  final _scroll = ScrollController();
  final List<ChatMessage04> _messages = [];

  bool _ready = false;
  bool _busy = false;
  int _tab = 0;
  double _progress = 0;
  String _status = 'Avvio del cervello relazionale…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings18);
    _boot();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings18);
    WidgetsBinding.instance.removeObserver(this);
    _chat.dispose();
    _teach.dispose();
    _senseLabel.dispose();
    _mindTimer?.cancel();
    unawaited(_recorder.dispose());
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    _bootError318 = null;
    if (mounted) setState(() => _ready = false);
    final sw = Stopwatch()..start();
    try {
      if (mounted)
        setState(() => _status = 'Apro memoria MGD 0.29 • SQLite WAL…');
      final loadedAll = await Future.wait<Object?>([
        _persistence.load(),
        _worldPersistence.load(),
        _researchPersistence.load(),
        _languagePersistence20.load(),
      ]);
      final loaded =
          loadedAll[0] as ({PlasticLanguageBrain04 brain, bool migrated})?;
      final world = loadedAll[1] as MgdWorld06?;
      final research = loadedAll[2] as ResearchMemory11?;
      final language = loadedAll[3] as MgdLanguage20?;

      _brain = loaded?.brain ?? PlasticLanguageBrain04();
      final repairedSemanticCorrections252 =
          _brain.repairSemanticCorrections0252();
      _world = world ?? MgdWorld06();
      final repairedQuestion316 = _world.repairPendingCuriosity316(_brain);
      if (_world.pendingCuriosityKey316 != null) {
        _messages.add(ChatMessage04(
            user: false,
            text: _world.pendingCuriosityQuestion09!,
            curiosityKey316: _world.pendingCuriosityKey316));
      }

      _researchMemory = research ?? ResearchMemory11();
      final needsConceptMigration25 = _researchMemory.termMemory.isNotEmpty &&
          (_researchMemory.emergentConcepts.isEmpty ||
              _researchMemory.emergentConcepts.values
                  .any((c) => c.quality <= 0));
      if (needsConceptMigration25) {
        if (mounted) setState(() => _status = 'Migro concetti MGD 0.25…');
        CognitiveInduction24.recrystallize(_researchMemory);
      }
      _language20 = language ?? MgdLanguage20();
      _language20.bootstrapFromBrain(_brain);

      // v0.19: never block first usable frame behind repair passes or rewrites.
      // Legacy maintenance is deferred and only runs for an actual migration.
      if (!mounted) return;
      sw.stop();
      setState(() {
        _ready = true;
        _status = loaded == null
            ? 'Nuovo cervello 0.20 • avvio ${sw.elapsedMilliseconds} ms'
            : loaded.migrated
                ? 'Memoria migrata • avvio ${sw.elapsedMilliseconds} ms'
                : 'Cervello 0.20 ripristinato • avvio ${sw.elapsedMilliseconds} ms';
      });

      _world.runtime319['loadedAt'] = DateTime.now().toIso8601String();
      _world.runtime319['loadedCycles'] = _world.thoughtCycles;
      _world.runtime319['loadedEdges'] = _world.edges.length;
      _world.runtime319['loadedAge'] = _world.entropicAge;
      _startMindTimer19();
      unawaited(_maintainResearch317());
      if (repairedSemanticCorrections252 > 0) {
        unawaited(_checkpoint319());
      }
      if (needsConceptMigration25) {
        // Persist the migrated quality/crystallization metadata so the next
        // launch can use it directly without rebuilding the concept graph.
        unawaited(_checkpoint319());
      }
      if (loaded?.migrated == true) {
        unawaited(_legacyMaintenance19());
      }
    } catch (e) {
      // A startup problem must not trap the user forever on the splash screen.
      _brain = PlasticLanguageBrain04();
      _world = MgdWorld06();
      _researchMemory = ResearchMemory11();
      _language20 = MgdLanguage20();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _bootError318 = e.toString();
        _status =
            'Caricamento non riuscito. Salvataggio automatico sospeso per proteggere la memoria.';
      });
      _mindTimer?.cancel();
    }
  }

  Future<void> _checkpoint319() async {
    if (!_ready || _bootError318 != null) return;
    try {
      await _checkpointWriter319.save(
          _brain, _world, _researchMemory, _language20);
      if (mounted)
        _world.runtime319['lastSavedAt'] = DateTime.now().toIso8601String();
    } catch (e) {
      if (mounted)
        setState(() =>
            _status = 'Salvataggio non riuscito; dati ancora in memoria: $e');
      rethrow;
    }
  }

  bool _mindBusy320 = false;

  void _startMindTimer19() {
    _mindTimer?.cancel();
    _mindTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted || !_ready || _bootError318 != null || _mindBusy320) return;
      if (_lifecycle319 != AppLifecycleState.resumed ||
          _busy ||
          _researchBusy ||
          !_uiIdle18 ||
          _chat.text.isNotEmpty) {
        _world.runtime319['state'] = _lifecycle319 != AppLifecycleState.resumed
            ? 'in pausa: app non in primo piano'
            : _researchBusy
                ? 'in pausa durante la ricerca web'
                : _busy
                    ? 'in pausa durante un’operazione'
                    : 'in pausa durante l’interazione';
        return;
      }
      if (_maintenance317) {
        _world.runtime319['state'] = 'riesame in corso';
        return;
      }
      _mindTicks++;
      _mindBusy320 = true;
      final brain = _brain, world = _world;
      final brainStep = brain.step, worldStep = world.step;
      try {
        final result = await MemoryRuntime319.compute320(brain, world);
        // UI/research may acquire new facts while the worker runs. A stale
        // result is discarded, never written over newer user experience.
        if (!mounted ||
            !identical(brain, _brain) ||
            !identical(world, _world) ||
            brain.step != brainStep ||
            world.step != worldStep ||
            _busy ||
            _researchBusy) return;
        _world.applyRuntime320(result.world);
        _brain.adoptConcepts320(result.concepts);
      } catch (e) {
        if (mounted) setState(() => _status = 'Ripasso sospeso: $e');
        return;
      } finally {
        _mindBusy320 = false;
      }
      if (mounted) setState(() {});
      if (_mindTicks % 3 == 0) unawaited(_autoSave17());
      if (_mindTicks % 6 == 1 && _researchMemory.enabled && !_researchBusy) {
        unawaited(_researchOnce10(autonomous: true));
      } else if (!_researchBusy &&
          ResearchSemantics317.needsMaintenance(_researchMemory)) {
        unawaited(_maintainResearch317());
      } else if (_mindTicks % 6 == 0) {
        _maybeAskCuriosity09();
      }
      if (_mindTicks % 12 == 0) _maybeSpeak20();
    });
  }

  Future<void> _legacyMaintenance19() async {
    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted || !_ready || !_uiIdle18) return;
    var changed = 0;
    changed += _world.repairNaturalBindings071(_brain);
    await Future<void>.delayed(Duration.zero);
    changed += _world.repairIdentityAliases081(_brain);
    await Future<void>.delayed(Duration.zero);
    changed += _brain.repairTeacherFacts082();
    await Future<void>.delayed(Duration.zero);
    changed += _world.repairCurrentUserFromHistory091(_brain);
    changed += _world.dedupeThoughts011();
    // Do not run quarantineUnsafeResearch12 automatically on every boot.
    // It remains available from the knowledge editor when explicitly needed.
    if (changed > 0) unawaited(_autoSave17());
  }

  Future<void> _saveAllSilent22() async {
    if (_bootError318 != null || !_ready) return;
    await _checkpoint319();
  }

  Future<void> _autoSave17() async {
    if (_autoSaveInFlight17 || !_ready || _bootError318 != null) return;
    _autoSaveInFlight17 = true;
    try {
      await _checkpoint319();
    } finally {
      _autoSaveInFlight17 = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle319 = state;
    if (!_ready || _bootError318 != null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_checkpoint319());
    } else if (state == AppLifecycleState.resumed &&
        _researchMemory.enabled &&
        !_researchBusy) {
      unawaited(_researchOnce10(autonomous: true));
    }
  }

  Future<void> _save([String? label]) async {
    if (_bootError318 != null || !_ready) return;
    await _checkpoint319();
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
    unawaited(_checkpoint319());
    if (enabled) unawaited(_researchOnce10(autonomous: true));
  }

  Future<void> _maintainResearch317() async {
    if (!mounted || !_ready || _maintenance317 || _researchBusy || _busy)
      return;
    if (_chat.text.isNotEmpty ||
        !ResearchSemantics317.needsMaintenance(_researchMemory)) return;
    _maintenance317 = true;
    try {
      if (ResearchSemantics317.needsRecovery318(_researchMemory)) {
        final store = MgdStateStore26.instance;
        if (await store.getMap('before_research318') == null) {
          await store.putMap('before_research318', {
            'brain': _brain.toJson(),
            'world': _world.toJson(),
            'research': _researchMemory.toJson(),
            'language': _language20.toJson(),
            'createdAt': DateTime.now().toIso8601String()
          });
        }
        ResearchSemantics317.recoverTexts318(_researchMemory);
        await _checkpoint319();
      }
      if (_researchMemory.state317['migrationComplete'] != true) {
        final store = MgdStateStore26.instance;
        final previous = await store.getMap('before_research317');
        if (previous == null) {
          await store.putMap('before_research317', {
            'brain': _brain.toJson(),
            'world': _world.toJson(),
            'research': _researchMemory.toJson(),
            'language': _language20.toJson(),
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
        if (!mounted) return;
        for (final c in _researchMemory.claims.values.toList()) {
          if (c.meta317['engine'] != 317)
            ResearchSemantics317.migrateClaim(
                _brain, _world, _researchMemory, c);
          await Future<void>.delayed(const Duration(milliseconds: 2));
          if (!mounted || _busy || _chat.text.isNotEmpty) return;
        }
        _researchMemory.state317['migrationComplete'] = true;
        _status =
            'Riesame completato. Originali conservati nel backup pre-0.31.7.';
      }
      ResearchSemantics317.reviewExtractions322(
          _brain, _world, _researchMemory);
      // Backfill language independently from claim acceptance, without repeating sentences.
      for (final doc in ResearchSemantics317.pendingLanguage320(_researchMemory)
          .take(32)) {
        await _language20.ingestWeb317(doc);
        ResearchSemantics317.markLanguage320(_researchMemory, doc);
        if (!mounted || _busy || _chat.text.isNotEmpty) return;
      }
      await LearningService321.drainResearch(_brain, _world, _researchMemory,
          shouldContinue: () => mounted && !_busy && _chat.text.isEmpty);
      await _saveAllSilent22();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted)
        setState(() => _status = 'Riesame sospeso, dati conservati: $e');
    } finally {
      _maintenance317 = false;
    }
  }

  Future<void> _backfillLegacyResearch030() async {
    if (!_ready || _researchBusy) return;
    final hasPending = _researchMemory.passages.any((p) {
          final key = _researchMemory.cognitiveSourceKey030(
              provider: p.provider,
              family: p.sourceFamily,
              title: p.sourceTitle,
              url: p.sourceUrl);
          return !_researchMemory.cognitiveSources030.contains(key);
        }) ||
        _researchMemory.evidence.any((e) {
          final key = _researchMemory.cognitiveSourceKey030(
              provider: e.provider,
              family: e.sourceFamily,
              title: e.sourceTitle,
              url: e.sourceUrl);
          return !_researchMemory.cognitiveSources030.contains(key);
        });
    if (!hasPending) return;
    _researchBusy = true;
    try {
      final n = await CognitiveInduction24.backfillLegacyPassages030(
          brain: _brain, memory: _researchMemory, maxSources: 32);
      if (n > 0) {
        _brain.discoverConcepts();
        await _checkpoint319();
        if (mounted && _tab == 2)
          setState(() => _status =
              'Migrazione cognitiva 0.30: $n vecchie fonti rielaborate.');
      }
    } finally {
      _researchBusy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _researchOnce10({
    bool autonomous = false,
    bool allowWhileBusy = false,
    String? manualTopic,
  }) async {
    if (!_ready ||
        _bootError318 != null ||
        _researchBusy ||
        _maintenance317 ||
        !_researchMemory.enabled) return;
    if (_busy && !allowWhileBusy) return;

    final requestedTopic = manualTopic?.trim() ?? '';
    final goal = requestedTopic.isNotEmpty
        ? ResearchGoal11(
            query: requestedTopic,
            topic: requestedTopic,
            reason: 'argomento scelto manualmente dall’utente',
            value: 1.0,
          )
        : _webExplorer.selectGoal(
            _brain,
            _world,
            _researchMemory,
            force: !autonomous,
          );
    if (goal == null) {
      if (!autonomous && mounted) {
        setState(() => _status =
            'Non vedo ancora un vuoto informativo abbastanza utile da giustificare una ricerca.');
      }
      return;
    }
    if (autonomous && !_researchMemory.canResearch(goal.query)) return;
    if (!autonomous && !_researchMemory.canResearchManual(goal.query)) return;

    final now = DateTime.now();
    _researchMemory.begin(goal.query, now);
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
      final studyClock = Stopwatch()..start();
      final draft = await _webExplorer.research(goal);
      _webExplorer.integrate(_brain, _world, _researchMemory, draft);
      await _checkpoint319();

      // Reading is learning even when the rule-based extractor cannot turn a
      // sentence into a clean subject-relation-object claim. Feed each new web
      // document into episodic/co-occurrence memory immediately, so 0 structured
      // candidates no longer means 0 learning.
      for (final doc in draft.documents) {
        await _language20.ingestWeb317(doc);
        ResearchSemantics317.markLanguage320(_researchMemory, doc);
        final cognitiveKey = _researchMemory.cognitiveSourceKey030(
            provider: doc.provider,
            family: doc.family,
            title: doc.title,
            url: doc.url);
        if (_researchMemory.cognitiveSources030.contains(cognitiveKey))
          continue;
        await CognitiveInduction24.learn(
          text: doc.text,
          sourceName: '${doc.provider}: ${doc.title}',
          brain: _brain,
          memory: _researchMemory,
        );
        _researchMemory.cognitiveSources030.add(cognitiveKey);
      }

      if (!allowWhileBusy) {
        var waits = 0;
        while (_busy && waits < 40) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          waits++;
        }
        if (_busy) {
          _researchMemory.lastStatus =
              'Ricerca completata ma integrazione rimandata: il cervello era occupato.';
          await _checkpoint319();
          return;
        }
      }

      await LearningService321.drainResearch(_brain, _world, _researchMemory,
          shouldContinue: () => mounted);
      final session = _researchMemory.sessions
          .where((s) => s.query == goal.query)
          .lastOrNull;
      if (session != null) {
        session.audit315['elapsedMicros321'] = studyClock.elapsedMicroseconds;
        session.completedAtIso = DateTime.now().toIso8601String();
        _researchMemory.recordTopicStudy321(
            goal.topic, session.audit315['newEvidence321'] as int? ?? 0);
      }
      // All readings and updated metrics are persisted together.
      await _checkpoint319();
      if (mounted) {
        setState(() {
          _status = _researchMemory.lastStatus;
        });
      }
    } catch (e) {
      _researchMemory.lastError = e.toString();
      _researchMemory.lastStatus = 'Errore ricerca Internet: $e';
      await _checkpoint319();
      if (mounted) setState(() => _status = _researchMemory.lastStatus);
    } finally {
      _researchBusy = false;
      if (mounted) setState(() {});
    }
  }

  void _maybeAskCuriosity09() {
    if (!mounted ||
        !_ready ||
        _busy ||
        _tab != 0 ||
        _chat.text.trim().isNotEmpty) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final q = _world.nextCuriosityQuestion09(_brain);
    if (q == null || q.trim().isEmpty) return;
    setState(() {
      _messages.add(ChatMessage04(
          user: false,
          text: q,
          curiosityKey316: _world.pendingCuriosityKey316));
      _status = 'Domanda aperta: puoi rispondere, correggere o saltare.';
    });
    unawaited(_checkpoint319());
    _scrollDown();
  }

  void _maybeSpeak20() {
    if (!mounted ||
        !_ready ||
        _busy ||
        _tab != 0 ||
        !_uiIdle18 ||
        _world.pendingCuriosityQuestion09 != null ||
        _chat.text.trim().isNotEmpty) return;
    if (DateTime.now().difference(_lastSpontaneous20) <
        const Duration(minutes: 2)) return;
    final utterance = _language20.spontaneous(_brain, _world);
    if (utterance == null || utterance.trim().isEmpty) return;
    _lastSpontaneous20 = DateTime.now();
    setState(() {
      _messages.add(ChatMessage04(user: false, text: utterance));
      _status = 'MGD ha verbalizzato spontaneamente uno stato interno.';
    });
    _scrollDown();
  }

  Future<void> _openLanguage20() async {
    if (_busy || _researchBusy || _maintenance317) return;
    setState(() => _busy = true);
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => InspectorScope315(
              inspector: MemoryInspector315(
                  brain: _brain,
                  world: _world,
                  research: _researchMemory,
                  language: _language20),
              child: MgdLanguageLab20(
                  language: _language20,
                  brain: _brain,
                  world: _world,
                  research: _researchMemory,
                  onSave: _saveAllSilent22))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _curiosityResult316(
      String userText, String acknowledgement) async {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage04(user: true, text: userText));
      _messages.add(ChatMessage04(user: false, text: acknowledgement));
      _status = acknowledgement;
    });
    _scrollDown();
    await _save('Domanda gestita e memoria salvata');
  }

  Future<void> _send() async {
    if (_busy || _researchBusy || _maintenance317 || !_ready) return;
    final text = _chat.text.trim();
    if (text.isEmpty) return;
    _chat.clear();
    setState(() {
      _busy = true;
      _messages.add(ChatMessage04(user: true, text: text));
      _status = 'MGD: convergenza verso attrattori relazionali…';
    });
    _scrollDown();

    await Future<void>.delayed(Duration.zero);
    try {
      _language20.ingestText(text, reward: 0.38);
      if (LearnedReader324.handles(text) ||
          RegExp(r'^\s*correggi\s*:',caseSensitive:false).hasMatch(text)) {
        String? reply324;
        if (LearnedReader324.isQuestion(text)) {
          reply324 = RelationalMemory324.answer(_researchMemory,text);
        } else {
          SourceMemory323.retain(_researchMemory,WebDocument11(
            provider:'Chat utente',family:'locale:utente',title:'Testo insegnato in chat',
            url:'local://chat/'+ResearchSemantics317.digest(text),text:text,trust:.75));
          final learned324=await RelationalMemory324.learnAsync(_researchMemory,text,
            source:'Chat utente');
          if(learned324.handled) reply324=learned324.message;
        }
        if(reply324!=null) {
          if(!mounted) return;
          setState(() {
            _messages.add(ChatMessage04(user:false,text:reply324!,prompt:text));
            _status='Lettura e memoria relazionale • salvataggio…';
          });
          _scrollDown();
          await _save('Relazioni insegnate e cronologia salvate');
          return;
        }
      }
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
          if (mounted)
            setState(() => _status = 'Salvataggio non completato: $e');
        } finally {
          if (mounted) setState(() => _busy = false);
        }
        return;
      }
      final sensoryGrounding = _world.bindLastFromUtterance091(_brain, text);
      final curiosityAnswer = sensoryGrounding == null
          ? _world.consumeCuriosityAnswer09(_brain, text)
          : null;
      final languageAnswer =
          (curiosityAnswer == null && sensoryGrounding == null)
              ? _brain.respond(text)
              : curiosityAnswer;
      final grounded = (curiosityAnswer == null && sensoryGrounding == null)
          ? _world.groundedAnswer07(_brain, text)
          : null;
      final sourced317 = RelationalMemory324.answer(_researchMemory,text) ??
          Reasoning321.answer(text, _researchMemory) ??
          ResearchSemantics317.answer(text, _researchMemory,
              realize: (s, r, o) => _language20.realizeFact320(s, r, o)) ??
          SourceMemory323.answer(text, _researchMemory);
      final semanticAnswer = sourced317 ?? grounded ?? languageAnswer;
      final composed031 = (semanticAnswer == null ||
              sensoryGrounding != null ||
              curiosityAnswer != null)
          ? null
          : _brain.composeAnswer031(text, semanticAnswer);
      final fluent = (sensoryGrounding == null && curiosityAnswer == null)
          ? _language20.generate(
              text,
              semanticHint: composed031 ?? semanticAnswer,
              brain: _brain,
            )
          : null;
      final answer = sensoryGrounding != null
          ? 'Ho collegato questa percezione a $sensoryGrounding.'
          : (sourced317 ??
              fluent ??
              semanticAnswer ??
              'Ho incorporato questa esperienza.');
      // A generated answer is not a new linguistic observation.
      _world.integrateLanguageExperience09(
        _brain,
        text,
        reward: sensoryGrounding != null
            ? 0.9
            : (curiosityAnswer == null ? 0.35 : 0.75),
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage04(user: false, text: answer, prompt: text));
        _status = 'Risposta dalla memoria • salvataggio…';
      });
      _scrollDown();
      await Future<void>.delayed(Duration.zero);
      _world.think(_brain, cycles: 2, seedText: text, stopFlux: 0.006);
      if (!mounted) return;
      setState(() {
        _busy = false;
        final bs = _brain.stats();
        _status = 'Esperienza chiusa • Δτ ${bs.lastFlux.toStringAsFixed(3)} • '
            'gen ${(_language20.lastGenerateMicros21 / 1000).toStringAsFixed(1)} ms • '
            '${_language20.lastVisitedEdges21} archi locali • ${_language20.lastStopReason21}';
      });
      _maybeAskCuriosity09();
      unawaited(
          Future<void>.delayed(const Duration(milliseconds: 80), () async {
        try {
          await _save('Memoria relazionale persistente aggiornata');
        } catch (e) {
          if (mounted) setState(() => _status = 'Salvataggio da riprovare: $e');
        }
      }));
    } catch (e) {
      if (mounted) setState(() => _status = 'Operazione non completata: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _feedback(ChatMessage04 m, bool positive) async {
    if (_busy || m.user || m.prompt == null) return;
    setState(() {
      _busy = true;
      _status = positive
          ? 'Rinforzo il circuito e la memoria…'
          : 'Depotenziamento metaplastico…';
    });
    try {
      await Future<void>.delayed(Duration.zero);
      _brain.reinforcePair(m.prompt!, m.text, positive);
      await _save(positive
          ? 'Circuito consolidato'
          : 'Risposta penalizzata senza cancellare il resto');
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (mounted) setState(() => _status = 'Operazione non completata: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _correct(ChatMessage04 m) async {
    if (m.prompt == null) return;
    if (_busy) return;
    final answer = await showTextDialog316(context,
        title: 'Correzione one-shot', hint: 'Scrivi la risposta corretta…');
    if (!mounted) return;
    if (answer == null || answer.isEmpty) return;
    setState(() {
      _busy = true;
      _status =
          'Correzione: rinforzo l’attrattore che ha prodotto la risposta…';
    });
    try {
      final query324=LearnedReader324.parse(m.prompt!);
      if(query324!=null && LearnedReader324.handles(m.prompt!)) {
        final candidates=RelationalMemory324.find(_researchMemory,query324);
        if(candidates.length==1) {
          final correction=RelationalMemory324.correct(_researchMemory,
            candidates.single['id'].toString(),answer);
          await _save(correction.message);
          return;
        }
      }
      _brain.teachResponse(m.prompt!, answer, reward: 1.0);
      await _save('Correzione consolidata nell’attrattore MGD');
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (mounted) setState(() => _status = 'Operazione non completata: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isUncertainResponse029(String text) =>
      text.startsWith('Non ho ancora una rappresentazione') ||
      text.startsWith('Non so ancora');

  Future<String?> _askVariationText029({
    required String title,
    String initial = '',
    String hint = 'Es. Sto bene',
  }) async {
    return showTextDialog316(context,
        title: title, hint: hint, initial: initial, confirm: 'Collega');
  }

  Future<String?> _variationMode029(ChatMessage04 m) =>
      showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Aggiungi una variazione',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Lo stesso stimolo può avere più risposte; una risposta può avere più rappresentazioni sensoriali.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: const Text('Altra risposta testuale'),
                  subtitle: const Text(
                      'Aggiunge un altro attrattore possibile, non sostituisce quelli esistenti.'),
                  onTap: () => Navigator.pop(sheetContext, 'text'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Foto dalla fotocamera'),
                  subtitle: const Text(
                      'Collega un pattern visivo a questa risposta / stato.'),
                  onTap: () => Navigator.pop(sheetContext, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Immagine dalla galleria'),
                  onTap: () => Navigator.pop(sheetContext, 'gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.mic_none),
                  title: const Text('Audio'),
                  subtitle: const Text(
                      'Registra 2 secondi e collega il pattern uditivo.'),
                  onTap: () => Navigator.pop(sheetContext, 'audio'),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _addVariation029(ChatMessage04 m) async {
    final prompt = m.prompt?.trim() ?? '';
    if (prompt.isEmpty || _busy) return;
    final mode = await _variationMode029(m);
    if (mode == null) return;

    if (mode == 'text') {
      final answer = await _askVariationText029(
        title: 'Altra risposta possibile',
        hint: 'Es. Sto male / Così così / Alla grande…',
      );
      if (answer == null || answer.isEmpty) return;
      setState(() {
        _busy = true;
        _status =
            'Aggiungo un nuovo attrattore di risposta senza cancellare gli altri…';
      });
      _brain.teachResponse(prompt, answer, reward: 0.90);
      _language20.ingestText(answer, reward: 0.22);
      _world.integrateLanguageExperience09(
        _brain,
        '$prompt $answer',
        reward: 0.42,
      );
      await _save('Variazione testuale aggiunta al grafo di risposta');
      if (mounted) {
        setState(() {
          _busy = false;
          _status =
              'Variazione aggiunta • ${_brain.responseOptions028(prompt).length} risposte possibili per questo stimolo';
        });
      }
      return;
    }

    var label = _isUncertainResponse029(m.text) ? '' : m.text.trim();
    if (label.isEmpty) {
      label = (await _askVariationText029(
            title: 'Cosa significa questa percezione?',
            hint: 'Es. Sto bene',
          )) ??
          '';
    }
    if (label.isEmpty) return;

    setState(() {
      _busy = true;
      _status = mode == 'audio'
          ? 'Registro la variazione uditiva…'
          : 'Acquisisco la variazione visiva…';
    });

    try {
      SensoryResult06? result;
      if (mode == 'camera' || mode == 'gallery') {
        final file = await _picker.pickImage(
          source: mode == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 88,
          maxWidth: 1600,
          maxHeight: 1600,
          requestFullMetadata: false,
        );
        if (file == null) return;
        result = _world.observeVisionBytes(await file.readAsBytes());
      } else if (mode == 'audio') {
        if (!await _recorder.hasPermission()) {
          if (mounted)
            setState(() => _status = 'Permesso microfono non concesso');
          return;
        }
        final chunks = <int>[];
        StreamSubscription<Uint8List>? sub;
        try {
          final stream = await _recorder.startStream(const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ));
          sub = stream.listen(chunks.addAll);
          await Future<void>.delayed(const Duration(seconds: 2));
          await _recorder.stop();
          await sub.cancel();
          sub = null;
        } finally {
          await sub?.cancel();
        }
        if (chunks.isEmpty) return;
        result = _world.observeAudioPcm(
          Uint8List.fromList(chunks),
          sampleRate: 16000,
        );
      }

      if (result == null) return;
      _lastSense = result;
      _brain.teachResponse(prompt, label, reward: 0.82);
      final entityId = _brain.entityIdForLabel06(label) ??
          _brain.ensureSemanticEntity06(label);
      _world.bindLast(label: label, entityId: entityId);
      _world.integrateLanguageExperience09(
        _brain,
        '$prompt $label',
        reward: 0.56,
      );
      _world.think(_brain, cycles: 18, seedText: label, stopFlux: 0.006);
      await _save('Variazione multimodale collegata allo stato “$label”');
      if (mounted) {
        setState(() {
          _status =
              'Variazione ${result!.observation.modality} collegata a “$label” • ${_brain.responseOptions028(prompt).length} attrattori possibili';
        });
      }
    } catch (e) {
      try {
        await _recorder.stop();
      } catch (_) {}
      if (mounted)
        setState(() => _status = 'Errore variazione multimodale: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _learnCorpus(int passes) async {
    if (_busy || _researchBusy || _maintenance317 || !_ready) return;
    final raw = _teach.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _status = 'Apprendo relazioni e forme linguistiche dallo stesso testo…';
    });
    try {
      final n = await LearningService321.learnText(
          _brain, _world, _language20, raw, passes: passes, memory: _researchMemory,
          progress: (done, total) {
        if (mounted)
          setState(() {
            _progress = done / total;
            _status = 'Frasi elaborate: $done/$total';
          });
      });
      await _save('$n frasi elaborate nelle memorie relazionale e linguistica');
    } catch (e) {
      if (mounted) setState(() => _status = 'Apprendimento interrotto: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sleep() async {
    if (_busy || _researchBusy || _maintenance317 || !_ready) return;
    setState(() {
      _busy = true;
      _status = 'Sonno: replay degli attrattori, consolidamento e pruning…';
    });
    try {
      await Future<void>.delayed(Duration.zero);
      final result =
          await LearningService321.sleep(_brain, _world, _researchMemory);
      if (!mounted) return;
      _brain = result.brain;
      _world.applyRuntime320(result.world);
      _researchMemory = result.research;
      await LearningService321.drainResearch(_brain, _world, _researchMemory,
          shouldContinue: () => mounted);
      if (_researchMemory.enabled) {
        await _researchOnce10(autonomous: true, allowWhileBusy: true);
      }
      await _save(
          'Ripasso completato; apri i dettagli dei testi interpretati e non interpretati.');
      _maybeAskCuriosity09();
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (mounted) setState(() => _status = 'Operazione non completata: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Azzerare MGD-Neuro 0.17?'),
        content: const Text(
            'Verranno cancellati episodi, relazioni, concetti e connessioni plastiche.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Azzera')),
        ],
      ),
    );
    if (ok != true) return;
    await _persistence.clear();
    await _worldPersistence.clear();
    await _researchPersistence.clear();
    await _languagePersistence20.clear();
    setState(() {
      _brain = PlasticLanguageBrain04();
      _world = MgdWorld06();
      _researchMemory = ResearchMemory11();
      _messages.clear();
      _status = 'Nuovo cervello 0.18 creato';
    });
    await _save();
  }

  Future<void> _observeImage06(ImageSource source) async {
    if (_busy || _researchBusy || _maintenance317 || !_ready) return;
    setState(() {
      _busy = true;
      _status = source == ImageSource.camera
          ? 'Apro gli occhi…'
          : 'Analizzo immagine…';
    });
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final result = _world.observeVisionBytes(bytes);
      _world.think(_brain, cycles: 28);
      if (!mounted) return;
      setState(() {
        _lastSense = result;
        _status = result.summary;
      });
      await _save('Esperienza visiva incorporata nel mondo MGD');
      _maybeAskCuriosity09();
    } catch (e) {
      if (mounted) setState(() => _status = 'Errore visivo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _listen06() async {
    if (_busy || _researchBusy || _maintenance317 || !_ready) return;
    setState(() {
      _busy = true;
      _status = 'Ascolto 2 secondi di audio grezzo…';
    });
    StreamSubscription<Uint8List>? sub;
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted)
          setState(() => _status = 'Permesso microfono non concesso');
        return;
      }
      final chunks = <int>[];
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      sub = stream.listen(chunks.addAll);
      await Future<void>.delayed(const Duration(seconds: 2));
      await _recorder.stop();
      await sub.cancel();
      sub = null;
      final result =
          _world.observeAudioPcm(Uint8List.fromList(chunks), sampleRate: 16000);
      _world.think(_brain, cycles: 28);
      if (!mounted) return;
      setState(() {
        _lastSense = result;
        _status = result.summary;
      });
      await _save('Esperienza uditiva incorporata nel mondo MGD');
      _maybeAskCuriosity09();
    } catch (e) {
      try {
        await _recorder.stop();
      } catch (_) {}
      if (mounted) setState(() => _status = 'Errore uditivo: $e');
    } finally {
      await sub?.cancel();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bindSense06() async {
    if (_lastSense == null) return;
    final label = _senseLabel.text.trim();
    if (label.isEmpty) return;
    final canonical = _world.bindLastNatural071(_brain, label);
    _world.think(_brain, cycles: 24, seedText: canonical);
    _senseLabel.clear();
    if (mounted) {
      setState(() => _status =
          'Percezione collegata all’entità “$canonical” nel world model');
    }
    await _save('Binding multimodale consolidato');
    _maybeAskCuriosity09();
  }

  Future<void> _saveTeacherImport271(
    TeacherPack08 pack,
    TeacherImportResult08 result,
  ) async {
    final sw = Stopwatch()..start();
    var stage = 'snapshot';

    void show(String text) {
      if (!mounted) return;
      setState(() => _status = text);
    }

    show('Salvataggio • snapshot coerente delle quattro memorie…');
    await _checkpoint319();

    final graphNodes = <String>{};
    final graphEdges =
        <({String src, String rel, String dst, double weight})>[];
    for (final f in pack.facts) {
      final a = f.subject.trim();
      final b = f.object.trim();
      if (a.isEmpty || b.isEmpty) continue;
      graphNodes
        ..add(a)
        ..add(b);
      graphEdges
          .add((src: a, rel: f.relation.trim(), dst: b, weight: f.confidence));
    }

    show('Salvataggio • 3/4 • indice grafo incrementale…');
    var lastPercent = -1;
    await MgdStateStore26.instance.upsertGraphDelta271(
      space: 'world',
      nodes: graphNodes,
      edges: graphEdges,
      batchSize: 256,
      onProgress: (done, total) {
        if (!mounted) return;
        final percent = total == 0 ? 100 : ((done * 100) / total).floor();
        if (percent == lastPercent && done != total) return;
        lastPercent = percent;
        setState(() => _status = 'Salvataggio • 3/4 • grafo ' +
            done.toString() +
            '/' +
            total.toString() +
            ' • ' +
            percent.toString() +
            '%');
      },
    );

    sw.stop();
    show('Salvataggio • 4/4 • completato in ' +
        (sw.elapsedMilliseconds / 1000).toStringAsFixed(1) +
        ' s • Teacher ' +
        result.model +
        ': ' +
        result.facts.toString() +
        ' fatti + ' +
        result.links.toString() +
        ' legami importati');
  }

  Future<void> _importTeacherPack08() async {
    if (_busy || _researchBusy || _maintenance317 || !_ready) return;
    setState(() {
      _busy = true;
      _status = 'Seleziona un knowledge pack distillato da un LLM…';
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'mgdpack', 'zip', 'gz'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final bytes = picked.files.single.bytes;
      if (bytes == null) {
        throw StateError('Il selettore non ha restituito i byte del file.');
      }

      if (mounted) {
        final isZip = bytes.length >= 4 &&
            bytes[0] == 0x50 &&
            bytes[1] == 0x4B &&
            bytes[2] == 0x03 &&
            bytes[3] == 0x04;
        final isGzip =
            bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B;
        setState(() {
          _status = isZip
              ? 'Apertura archivio ZIP e ricerca pack ALL_IN_ONE…'
              : isGzip
                  ? 'Decompressione knowledge pack GZIP…'
                  : 'Decodifica knowledge pack JSON in background…';
        });
      }
      final pack = await TeacherPack08.fromBytesAsync(bytes);
      if (!mounted) return;

      var lastUiProgress = -1;
      final result = await importTeacherPackAsync08(
        _brain,
        _world,
        pack,
        onProgress: (completed, totalItems, stage) {
          if (!mounted) return;
          final percent =
              totalItems == 0 ? 100 : ((completed * 100) / totalItems).floor();
          // Repaint at 1% granularity instead of rebuilding for every fact.
          if (percent == lastUiProgress && completed != totalItems) return;
          lastUiProgress = percent;
          setState(() {
            _status = 'Importazione ' +
                stage.toLowerCase() +
                ' • ' +
                completed.toString() +
                '/' +
                totalItems.toString() +
                ' • ' +
                percent.toString() +
                '%';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _status = 'Distillazione da ' +
            result.model +
            ' • ' +
            result.facts.toString() +
            ' fatti • ' +
            result.links.toString() +
            ' legami • +' +
            result.entities.toString() +
            ' entità. Salvataggio in background…';
      });

      // Persist in visible stages. Snapshot generation runs off the UI isolate,
      // and only this pack's graph delta is written.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _saveTeacherImport271(pack, result);
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Errore teacher pack: ' + e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportKnowledgePack12() async {
    try {
      final bytes = KnowledgeSnapshot12.knowledgePackBytes(
        _brain,
        _world,
        _researchMemory,
      );
      final uri = await FilePicker.platform.saveFile(
        dialogTitle: 'Esporta conoscenza MGD',
        fileName:
            'MGD-Conoscenza-${DateTime.now().millisecondsSinceEpoch}.mgdpack',
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _status = uri == null
          ? 'Esportazione annullata.'
          : 'Knowledge pack esportato: $uri');
    } catch (e) {
      if (mounted) setState(() => _status = 'Errore esportazione: $e');
    }
  }

  Future<void> _exportSnapshot12() async {
    try {
      final bytes = KnowledgeSnapshot12.fullSnapshotBytes(
        _brain,
        _world,
        _researchMemory,
        languageModel: _language20.toJson(),
      );
      final uri = await FilePicker.platform.saveFile(
        dialogTitle: 'Esporta cervello MGD completo',
        fileName:
            'MGD-Neuro-Snapshot-${DateTime.now().millisecondsSinceEpoch}.mgdbrain',
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _status = uri == null
          ? 'Esportazione annullata.'
          : 'Snapshot completo esportato: $uri');
    } catch (e) {
      if (mounted) setState(() => _status = 'Errore snapshot: $e');
    }
  }

  Future<void> _importSnapshot12() async {
    if (_busy) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mgdbrain', 'json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null) throw StateError('File snapshot senza dati.');
      final restored = KnowledgeSnapshot12.restoreSnapshotBytes(bytes);
      setState(() {
        _brain = restored.brain;
        _world = restored.world;
        _researchMemory = restored.research;
        _lastSense = null;
        if (restored.languageModel != null)
          _language20 = MgdLanguage20.fromJson(restored.languageModel!);
        _researchMemory.state317['migrationComplete'] = false;
        _status =
            'Snapshot ripristinato; riesame delle fonti disponibile al prossimo avvio.';
      });
      await _checkpoint319();
    } catch (e) {
      if (mounted) setState(() => _status = 'Errore ripristino snapshot: $e');
    }
  }

  Future<void> _openEditor12() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KnowledgeEditor12(
          brain: _brain,
          world: _world,
          research: _researchMemory,
          onChanged: (status) async {
            await _checkpoint319();
            if (mounted) setState(() => _status = status);
          },
          onExportPack: _exportKnowledgePack12,
          onExportSnapshot: _exportSnapshot12,
          onImportSnapshot: _importSnapshot12,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _think06() async {
    if (_busy || _researchBusy || _maintenance317 || !_ready) return;
    setState(() {
      _busy = true;
      _status =
          'Ciclo mentale autonomo: propagazione e competizione degli attrattori…';
    });
    try {
      final seed = _chat.text.trim().isEmpty ? null : _chat.text.trim();
      final result = await MemoryRuntime319.compute320(_brain, _world,
          cycles: 96, seedText: seed);
      if (!mounted) return;
      _world.applyRuntime320(result.world);
      _brain.adoptConcepts320(result.concepts);
      await _save('96 cicli MGD completati e salvati');
    } catch (e) {
      if (mounted) setState(() => _status = 'Ciclo interrotto: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_status),
            ],
          ),
        ),
      );
    }

    if (_bootError318 != null) {
      return Scaffold(
          appBar: AppBar(title: const Text('MGD Neuro 0.32.4')),
          body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Memoria protetta: caricamento non riuscito'),
                    const SizedBox(height: 16),
                    const Text(
                        'Non sovrascrivo i dati con una memoria vuota. Non disinstallare e non cancellare i dati.'),
                    const SizedBox(height: 12),
                    SelectableText(_bootError318!),
                    const SizedBox(height: 20),
                    FilledButton(
                        onPressed: _boot,
                        child: const Text('Riprova caricamento'))
                  ])));
    }
    final pages = [
      LivePage07(
        brain: _brain,
        onCuriosityBusy316: (value) {
          if (mounted) setState(() => _busy = value);
        },
        onCuriosityResult316: _curiosityResult316,
        messages: _messages,
        controller: _chat,
        scroll: _scroll,
        busy: _busy || _maintenance317 || _researchBusy,
        world: _world,
        last: _lastSense,
        labelController: _senseLabel,
        onSend: _send,
        onFeedback: _feedback,
        onCorrect: _correct,
        onAddVariation: _addVariation029,
        onCamera: () => _observeImage06(ImageSource.camera),
        onGallery: () => _observeImage06(ImageSource.gallery),
        onListen: _listen06,
        onBind: _bindSense06,
      ),
      _WorldPage07(
        brain: _brain,
        language: _language20,
        world: _world,
        research: _researchMemory,
        last: _lastSense,
        busy: _busy || _maintenance317 || _researchBusy,
        onImportTeacher: _importTeacherPack08,
        onEdit: _openEditor12,
      ),
      _MindPage07(
        brain: _brain,
        world: _world,
        research: _researchMemory,
        busy: _busy || _maintenance317 || _researchBusy,
        researchBusy: _researchBusy,
        onThink: _think06,
        onSleep: _sleep,
        onResearch: () => _researchOnce10(autonomous: false),
        onResearchTopic: (topic) => _researchOnce10(
          autonomous: false,
          manualTopic: topic,
        ),
        onResearchEnabled: _setResearchEnabled10,
        onEdit: _openEditor12,
        onSave: _save,
        onReset: _reset,
        frameP95Ms: _frameP9518,
        jankFrames: _jankFrames18,
        worstFrameMs: _worstFrameMs18,
        language20: _language20,
        onLanguage20: _openLanguage20,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('MGD Neuro 0.32.4'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: _Pulse04(active: _busy)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Row(
              children: [
                Icon(_busy ? Icons.bolt : Icons.psychology_alt, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _markInteraction18(),
              onPointerMove: (_) => _markInteraction18(),
              onPointerSignal: (_) => _markInteraction18(),
              child: KeyedSubtree(
                key: ValueKey<int>(_tab),
                child: InspectorScope315(
                  inspector: MemoryInspector315(
                      brain: _brain,
                      world: _world,
                      research: _researchMemory,
                      language: _language20),
                  child: pages[_tab],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (v) => setState(() => _tab = v),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Vivi'),
          NavigationDestination(
              icon: Icon(Icons.public_outlined),
              selectedIcon: Icon(Icons.public),
              label: 'Mondo'),
          NavigationDestination(
              icon: Icon(Icons.psychology_outlined),
              selectedIcon: Icon(Icons.psychology),
              label: 'Mente'),
        ],
      ),
    );
  }
}

class LivePage07 extends StatelessWidget {
  final PlasticLanguageBrain04 brain;
  final ValueChanged<bool> onCuriosityBusy316;
  final Future<void> Function(String, String) onCuriosityResult316;
  final List<ChatMessage04> messages;
  final TextEditingController controller;
  final ScrollController scroll;
  final bool busy;
  final MgdWorld06 world;
  final SensoryResult06? last;
  final TextEditingController labelController;
  final Future<void> Function() onSend;
  final Future<void> Function(ChatMessage04, bool) onFeedback;
  final Future<void> Function(ChatMessage04) onCorrect;
  final Future<void> Function(ChatMessage04) onAddVariation;
  final Future<void> Function() onCamera;
  final Future<void> Function() onGallery;
  final Future<void> Function() onListen;
  final Future<void> Function() onBind;

  const LivePage07({
    super.key,
    required this.brain,
    required this.onCuriosityBusy316,
    required this.onCuriosityResult316,
    required this.messages,
    required this.controller,
    required this.scroll,
    required this.busy,
    required this.world,
    required this.last,
    required this.labelController,
    required this.onSend,
    required this.onFeedback,
    required this.onCorrect,
    required this.onAddVariation,
    required this.onCamera,
    required this.onGallery,
    required this.onListen,
    required this.onBind,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Guarda',
                      onPressed: busy ? null : onCamera,
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: 'Immagine',
                      onPressed: busy ? null : onGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: 'Ascolta 2 secondi',
                      onPressed: busy ? null : onListen,
                      icon: const Icon(Icons.hearing),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        world.lastPerceptionSummary(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                if (last != null) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: labelController,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: 'Che cos’è / chi è?',
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        tooltip: 'Lega alla stessa entità del mondo',
                        onPressed: busy ? null : onBind,
                        icon: const Icon(Icons.link),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Vivi con MGD-Neuro: parlare, vedere e ascoltare sono parti della stessa esperienza. L’apprendimento avviene continuamente.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.all(14),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    return Align(
                      alignment: msg.user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 560),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: msg.user
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(msg.text),
                            if (!msg.user && msg.curiosityKey316 != null)
                              CuriosityActions316(
                                key: ValueKey(msg.curiosityKey316),
                                brain: brain,
                                world: world,
                                questionKey: msg.curiosityKey316!,
                                busy: busy,
                                onBusy: onCuriosityBusy316,
                                onResult: onCuriosityResult316,
                              ),
                            if (!msg.user &&
                                msg.prompt != null &&
                                msg.curiosityKey316 == null) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    onPressed: busy
                                        ? null
                                        : () => onFeedback(msg, true),
                                    icon: const Icon(
                                        Icons.thumb_up_alt_outlined,
                                        size: 19),
                                  ),
                                  IconButton(
                                    onPressed: busy
                                        ? null
                                        : () => onFeedback(msg, false),
                                    icon: const Icon(
                                        Icons.thumb_down_alt_outlined,
                                        size: 19),
                                  ),
                                  TextButton.icon(
                                    onPressed:
                                        busy ? null : () => onCorrect(msg),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18),
                                    label: const Text('Correggi'),
                                  ),
                                  TextButton.icon(
                                    onPressed:
                                        busy ? null : () => onAddVariation(msg),
                                    icon: const Icon(Icons.add_circle_outline,
                                        size: 18),
                                    label: const Text('Aggiungi variazione'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Invia / percepisci media',
                  enabled: !busy,
                  icon: const Icon(Icons.add_circle_outline),
                  onSelected: (value) {
                    if (value == 'camera') onCamera();
                    if (value == 'gallery') onGallery();
                    if (value == 'audio') onListen();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                        value: 'camera',
                        child: ListTile(
                            leading: Icon(Icons.photo_camera_outlined),
                            title: Text('Foto'))),
                    PopupMenuItem(
                        value: 'gallery',
                        child: ListTile(
                            leading: Icon(Icons.photo_library_outlined),
                            title: Text('Galleria'))),
                    PopupMenuItem(
                        value: 'audio',
                        child: ListTile(
                            leading: Icon(Icons.mic_none),
                            title: Text('Audio'))),
                  ],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: busy ? null : (_) => onSend(),
                    decoration: const InputDecoration(
                      hintText: 'Vivi / parla con il cervello…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: busy ? null : onSend,
                  icon: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WorldPage07 extends StatelessWidget {
  final MgdLanguage20 language;
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final ResearchMemory11 research;
  final SensoryResult06? last;
  final bool busy;
  final Future<void> Function() onImportTeacher;
  final Future<void> Function() onEdit;

  const _WorldPage07({
    required this.language,
    required this.brain,
    required this.world,
    required this.research,
    required this.last,
    required this.busy,
    required this.onImportTeacher,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final bs = brain.stats();
    final ws = world.stats();
    final facts = brain.strongestFacts(limit: 12);
    final bound =
        world.prototypes.where((p) => p.semanticEntityId != null).toList();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text('Mondo interno', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        const Text(
            'Entità, fatti, immagini e suoni condividono lo stesso spazio semantico MGD.'),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: busy ? null : onEdit,
          icon: const Icon(Icons.edit_note),
          label: const Text('Modifica Mondo / conoscenza'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Metric04('Entità', '${bs.entities}'),
            _Metric04('Fatti', '${bs.facts}'),
            _Metric04('Visione', '${ws.visualPatterns}'),
            _Metric04('Udito', '${ws.auditoryPatterns}'),
            _Metric04('Binding', '${ws.semanticBindings}'),
            _Metric04('Legami mondo', '${ws.worldEdges}'),
            _Metric04('Archi attivi', '${ws.activeEdges}'),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Ultima percezione'),
            subtitle: Text(world.lastPerceptionSummary()),
            trailing: last == null
                ? null
                : Text('${(last!.observation.similarity * 100).round()}%'),
          ),
        ),
        const SizedBox(height: 12),
        Text('Memoria multimodale',
            style: Theme.of(context).textTheme.titleMedium),
        if (bound.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child:
                Text('Nessun pattern sensoriale è ancora legato a un’entità.'),
          )
        else
          ...bound.reversed.take(10).map((p) => ListTile(
                leading: Icon(
                    p.modality == 'vision' ? Icons.visibility : Icons.hearing),
                title: Text(p.label ?? 'entità ${p.semanticEntityId}'),
                subtitle: Text(
                    '${p.modality} #${p.id} • ${p.observations} osservazioni • stabilità ${(p.stability * 100).round()}%'),
              )),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_outlined),
                    const SizedBox(width: 8),
                    Text(
                      'Distillazione LLM → MGD',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Importa fatti e geometria semantica estratti da un '
                  'modello open-weight. Non congela il cervello: i prior '
                  'restano connessioni MGD deboli e modificabili '
                  'dall’esperienza successiva.',
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onImportTeacher,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Importa knowledge pack'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hub_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mappa della conoscenza',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Apri la mappa in una pagina dedicata per cercare concetti, navigare nei vicinati e usare zoom e pan senza interferenze con lo scorrimento di Mondo.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SemanticMapPage14(
                          brain: brain, research: research, language: language),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('Visualizza mappa'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.blur_on),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Concetti multimodali',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ogni entità può avere una firma unica che fonde linguaggio, '
                  'fatti, immagini, suoni, ricerca web e vicinato MGD. '
                  'La stessa rappresentazione viene usata per confrontare concetti.',
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MultimodalConceptsPage16(
                        brain: brain,
                        world: world,
                        research: research,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.layers_outlined),
                  label: const Text('Esplora concetti multimodali'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Fatti appresi', style: Theme.of(context).textTheme.titleMedium),
        if (facts.isEmpty)
          const Text('Nessun fatto stabile ancora.')
        else
          ...facts.take(10).map((f) => ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: Text('${f.subject} — ${f.relation} → ${f.object}'),
                trailing: Text('${(f.confidence * 100).round()}%'),
              )),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _MindPage07 extends StatelessWidget {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final ResearchMemory11 research;
  final bool busy;
  final bool researchBusy;
  final Future<void> Function() onThink;
  final Future<void> Function() onSleep;
  final Future<void> Function() onResearch;
  final Future<void> Function(String topic) onResearchTopic;
  final ValueChanged<bool> onResearchEnabled;
  final Future<void> Function() onEdit;
  final Future<void> Function([String?]) onSave;
  final Future<void> Function() onReset;
  final double frameP95Ms;
  final int jankFrames;
  final double worstFrameMs;
  final MgdLanguage20 language20;
  final Future<void> Function() onLanguage20;

  const _MindPage07({
    required this.brain,
    required this.world,
    required this.research,
    required this.busy,
    required this.researchBusy,
    required this.onThink,
    required this.onSleep,
    required this.onResearch,
    required this.onResearchTopic,
    required this.onResearchEnabled,
    required this.onEdit,
    required this.onSave,
    required this.onReset,
    required this.frameP95Ms,
    required this.jankFrames,
    required this.worstFrameMs,
    required this.language20,
    required this.onLanguage20,
  });

  @override
  Widget build(BuildContext context) {
    final bs = brain.stats();
    final ws = world.stats();
    final thoughts = world.thoughts.reversed.take(12).toList();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text('Mente', style: Theme.of(context).textTheme.titleLarge),
        OutlinedButton.icon(
          onPressed: () =>
              InspectorScope315.maybeOf(context)?.openCatalog(context),
          icon: const Icon(Icons.search),
          label: const Text('Esplora tutta la memoria'),
        ),
        const Text(
            'Tocca qualsiasi contatore per vedere gli elementi e le fonti.'),
        const SizedBox(height: 5),
        const Text(
            'Memorie conservate e dinamica MGD sono misure diverse: un arco attivo indica familiarità geometrica, non verità. Apri Stato motore per l’ultimo ciclo e il ripristino.'),
        _Metric04('Stato motore', '${world.runtime319['state'] ?? 'in avvio'}'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Metric04('Cicli MGD', '${ws.thoughtCycles}'),
            _Metric04('Episodi relazionali', '${bs.episodes}'),
            _Metric04('Fatti cognitivi', '${brain.cognitiveFacts06().length}'),
            _Metric04('Concetti relazionali', '${bs.concepts}'),
            _Metric04('Concetti narrativi',
                '${research.emergentConcepts.values.where((c) => c.crystallized).length}'),
            _Metric04('Legami narrativi', '${research.narrativeLinks.length}'),
            _Metric04('Archi mondo', '${ws.worldEdges}'),
            _Metric04('Prior deboli',
                '${max(0, ws.worldEdges - ws.activeEdges - ws.preActiveEdges030)}'),
            _Metric04('Pre-attivi', '${ws.preActiveEdges030}'),
            _Metric04('Archi attivi', '${ws.activeEdges}'),
            _Metric04('Età τ', ws.entropicAge.toStringAsFixed(2)),
            _Metric04('κ medio', ws.meanCurvature.toStringAsFixed(3)),
          ],
        ),
        const SizedBox(height: 10),
        Card(
            child: InkWell(
                onTap: () =>
                    InspectorScope315.maybeOf(context)?.openCatalog(context),
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Memorie MGD 0.32.4',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                              'Lingua: ${language20.stats().sentences} frasi · Episodica web: ${research.narrativeEpisodes.length} episodi (${research.narrativeSentencesSeen} frasi osservate) · Concettuale: ${research.emergentConcepts.length} cluster · Web: ${research.claims.values.where((c) => c.status == 'documentata').length} documentate + ${research.claims.values.where((c) => c.status == 'accettata').length} corroborate + ${research.claims.values.where((c) => c.status == 'ipotesi_mgd').length} ipotesi MGD.'),
                        ])))),
        const SizedBox(height: 12),
        Card(child:ListTile(
          leading:const Icon(Icons.account_tree_outlined),
          title:Text('${RelationalMemory324.stats(research)['current']} relazioni apprese'),
          subtitle:const Text('Agente, azione, oggetto · fonti e correzioni'),
          trailing:const Icon(Icons.chevron_right),
          onTap:()=>Navigator.of(context).push(MaterialPageRoute(
            builder:(_)=>RelationalMemoryPage324(memory:research,onSave:()=>onSave()))),
        )),
        const SizedBox(height:12),
        Card(child: ListTile(
          leading: const Icon(Icons.find_in_page_outlined),
          title: Text(SourceMemory323.stats(research)['passages'].toString() +
              ' passaggi consultabili'),
          subtitle: Text(SourceMemory323.stats(research)['sources'].toString() +
              ' fonti conservate · apri e cerca nel testo'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SourceMemoryPage323(memory: research))),
        )),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: busy || researchBusy ? null : onEdit,
          icon: const Icon(Icons.tune),
          label: const Text('Modifica Mente / ricerca / pensieri'),
        ),
        const SizedBox(height: 12),
        _Meter04(label: 'Curiosità sensoriale', value: ws.curiosity),
        _Meter04(label: 'Errore previsione', value: ws.predictionError),
        _Meter04(label: 'Materia M media', value: ws.meanSlow.clamp(0, 1)),
        _Meter04(label: 'Flusso entropico Δτ', value: ws.entropicFlux),
        _Meter04(
            label: 'Memoria lenta relazionale', value: bs.meanSlow.clamp(0, 1)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Builder(builder: (context) {
              final ls = language20.stats();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.record_voice_over_outlined),
                    const SizedBox(width: 8),
                    Text('MGD Language',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                      'Forme linguistiche apprese dai testi e selezionate tramite il grafo MGD. Risposte vincolate ai fatti disponibili, con fonti quando presenti. Nessun modello linguistico preaddestrato.'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _Metric04('Token', '${ls.tokens}'),
                    _Metric04('Archi lingua', '${ls.edges}'),
                    _Metric04('Macro-nodi', '${ls.chunks}'),
                    _Metric04('Frasi viste', '${ls.sentences}'),
                  ]),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onLanguage20,
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Impara / esplora lingua'),
                  ),
                ],
              );
            }),
          ),
        ),
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
                    'MGD sceglie cosa approfondire in base a incertezza, rilevanza, curiosità e valore di ponte nel grafo. Interroga Wikipedia, Wikidata, DuckDuckGo, Europe PMC e Crossref. Una fonte pertinente documenta; più gruppi di provenienza corroborano. Ogni stato e la coda sono consultabili.',
                  ),
                  secondary: const Icon(Icons.travel_explore),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Metric04('Documentate',
                        '${research.claims.values.where((c) => c.status == 'documentata').length}'),
                    _Metric04('Documenti da leggere',
                        '${ResearchSemantics317.getPending(research)}'),
                    _Metric04('Corroborate web',
                        '${research.claims.values.where((c) => c.status == 'accettata').length}'),
                    _Metric04('Osservate',
                        '${research.claims.values.where((c) => c.status == 'ipotesi_mgd').length}'),
                    _Metric04('Quarantena',
                        '${research.claims.values.where((c) => c.status == 'quarantena').length}'),
                    _Metric04('Evidenze', '${research.evidence.length}'),
                    _Metric04('Provider con evidenza',
                        '${research.evidence.map((e) => e.provider).toSet().length}'),
                    _Metric04('Documenti registrati',
                        '${ResearchSemantics317.uniqueDocuments320(research).length}'),
                    _Metric04('Diagnostica ricerca',
                        '${research.lastSession?.documents ?? 0} doc'),
                    _Metric04('Famiglie con evidenza',
                        '${research.evidence.map((e) => e.sourceFamily).toSet().length}'),
                    _Metric04('Testi da elaborare',
                        '${research.pendingPassages321.length}'),
                    _Metric04('Testi non interpretati',
                        '${research.uninterpretedPassages321.length}'),
                    _Metric04(
                        'Ricerche avviate oggi', '${research.requestsToday}'),
                    const _Metric04('Limite giornaliero', 'Illimitato'),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
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
                      label: Text(
                          researchBusy ? 'Sto studiando…' : 'Studia da solo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: !research.enabled || busy || researchBusy
                          ? null
                          : () async {
                              final controller = TextEditingController();
                              final topic = await showDialog<String>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Cosa deve studiare?'),
                                  content: TextField(
                                    controller: controller,
                                    autofocus: true,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (value) =>
                                        Navigator.of(dialogContext)
                                            .pop(value.trim()),
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Es. legame covalente, mitocondrio, Roma…',
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Annulla'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext)
                                              .pop(controller.text.trim()),
                                      child: const Text('Studia'),
                                    ),
                                  ],
                                ),
                              );
                              controller.dispose();
                              if (topic != null && topic.trim().isNotEmpty) {
                                await onResearchTopic(topic.trim());
                              }
                            },
                      icon: const Icon(Icons.manage_search),
                      label: const Text('Scegli argomento'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(research.lastStatus),
                if (research.lastGoal != null &&
                    research.lastGoal!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ultimo obiettivo: ${research.lastGoal}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (research.lastSession != null) ...[
                  const SizedBox(height: 12),
                  Text('Ultimo studio: ${research.lastSession!.topic}',
                      style: Theme.of(context).textTheme.titleSmall),
                  TextButton.icon(
                      onPressed: () => InspectorScope315.maybeOf(context)
                          ?.openMetric(context, 'Documenti', session: true),
                      icon: const Icon(Icons.open_in_new),
                      label:
                          const Text('Apri documenti ed esiti dello studio')),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Metric04(
                          'Documenti', '${research.lastSession!.documents}',
                          session: true),
                      _Metric04(
                          'Provider', '${research.lastSession!.providers}',
                          session: true),
                      _Metric04('Famiglie', '${research.lastSession!.families}',
                          session: true),
                      _Metric04('Frasi lette',
                          '${research.lastSession!.sentencesRead}',
                          session: true),
                      _Metric04(
                          'Candidati', '${research.lastSession!.candidates}',
                          session: true),
                      _Metric04('Documentate',
                          '${research.lastSession!.audit315['documented'] ?? 0}',
                          session: true),
                      _Metric04('Proposizioni nuove',
                          '${research.lastSession!.audit315['newClaims321'] ?? 0}',
                          session: true),
                      _Metric04('Già note',
                          '${research.lastSession!.audit315['knownClaims321'] ?? 0}',
                          session: true),
                      _Metric04('Nuove evidenze',
                          '${research.lastSession!.audit315['newEvidence321'] ?? 0}',
                          session: true),
                      _Metric04(
                          'Corroborate', '${research.lastSession!.integrated}',
                          session: true),
                      _Metric04(
                          'Osservate', '${research.lastSession!.doubtful}',
                          session: true),
                      _Metric04(
                          'Quarantena', '${research.lastSession!.quarantined}',
                          session: true),
                      _Metric04('Conflitti',
                          '${research.lastSession!.contradictions}',
                          session: true),
                    ],
                  ),
                  if (research.lastSession!.sources.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                        'Provider consultati: ${research.lastSession!.sources.join(' • ')}'),
                  ],
                  if (research.lastSession!.learnedFacts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Nuove proposizioni registrate',
                        style: Theme.of(context).textTheme.titleSmall),
                    ...research.lastSession!.learnedFacts.take(6).map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('• $f'),
                          ),
                        ),
                  ],
                ],
                if (research.claims.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Conoscenza ricercata recente',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  ...((research.claims.values.toList()
                        ..sort(
                            (a, b) => b.lastSeenIso.compareTo(a.lastSeenIso)))
                      .take(4)
                      .map(
                        (c) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.manage_search, size: 20),
                          onTap: () => InspectorScope315.maybeOf(context)
                              ?.openClaim(context, c.key),
                          title: Text(
                              '${c.subject} — ${c.relation} → ${c.object}'),
                          subtitle: Text(
                            '${c.status == 'accettata' ? 'CORROBORATA' : c.status == 'documentata' ? 'DOCUMENTATA' : c.status == 'ipotesi_mgd' ? 'OSSERVATA' : c.status == 'quarantena' ? 'QUARANTENA' : 'RICERCATO'} • ${c.providerCount} provider • ${c.independentSourceCount} famiglie • ${c.evidenceCount} evidenze • supporti diretti ${c.meta317['directSupports'] ?? 0}${c.conflict ? ' • conflitto aperto' : ''}',
                          ),
                          trailing: Text(c.meta317['usable'] == true
                              ? 'Con fonte'
                              : 'Da verificare'),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Efficienza / scaling',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Ultimo pensiero: ${world.lastThinkMicros16 / 1000.0} ms • '
                  '${world.lastThinkVisitedEdges16} archi visitati • '
                  'picco ${world.lastThinkPeakActiveNodes16} nodi attivi.',
                ),
                const SizedBox(height: 6),
                Text(
                  'Fluidità UI: p95 degli ultimi 180 frame ${frameP95Ms.toStringAsFixed(1)} ms • '
                  'scatti dall’avvio >24 ms: $jankFrames • peggiore ${worstFrameMs.toStringAsFixed(1)} ms',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MgdScalingLabPage16(
                        brain: brain,
                        world: world,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.speed),
                  label: const Text('Apri laboratorio scaling'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : onThink,
              icon: const Icon(Icons.psychology),
              label: const Text('Pensa 96 cicli'),
            ),
            FilledButton.tonalIcon(
              onPressed: busy ? null : onSleep,
              icon: const Icon(Icons.bedtime_outlined),
              label: const Text('Dormi / consolida'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : () => onSave('Cervello e mondo salvati'),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salva'),
            ),
            TextButton.icon(
              onPressed: busy ? null : onReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Azzera'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Attività del grafo',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (thoughts.isEmpty)
          const Text('Nessuna traccia mentale ancora.')
        else
          ...thoughts.map((t) => Card(
                child: ListTile(
                  leading: const Icon(Icons.psychology_alt_outlined),
                  title: Text(t.hypothesis),
                  subtitle: Text(
                      'Attivazione: ${(t.coherence * 100).round()}% • ${t.focus.join(' · ')}'),
                ),
              )),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ChatPage04 extends StatelessWidget {
  final List<ChatMessage04> messages;
  final TextEditingController controller;
  final ScrollController scroll;
  final bool busy;
  final Future<void> Function() onSend;
  final Future<void> Function(ChatMessage04, bool) onFeedback;
  final Future<void> Function(ChatMessage04) onCorrect;

  const _ChatPage04({
    required this.messages,
    required this.controller,
    required this.scroll,
    required this.busy,
    required this.onSend,
    required this.onFeedback,
    required this.onCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const _EmptyChat04()
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.all(14),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    return Align(
                      alignment:
                          m.user ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 560),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: m.user
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.text),
                            if (!m.user) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Rinforza',
                                    onPressed:
                                        busy ? null : () => onFeedback(m, true),
                                    icon: const Icon(
                                        Icons.thumb_up_alt_outlined,
                                        size: 19),
                                  ),
                                  IconButton(
                                    tooltip: 'Penalizza',
                                    onPressed: busy
                                        ? null
                                        : () => onFeedback(m, false),
                                    icon: const Icon(
                                        Icons.thumb_down_alt_outlined,
                                        size: 19),
                                  ),
                                  TextButton.icon(
                                    onPressed: busy ? null : () => onCorrect(m),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18),
                                    label: const Text('Correggi'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: busy ? null : (_) => onSend(),
                    decoration: const InputDecoration(
                      hintText: 'Parla con il cervello…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                    onPressed: busy ? null : onSend,
                    icon: const Icon(Icons.arrow_upward)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyChat04 extends StatelessWidget {
  const _EmptyChat04();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_alt,
                size: 54, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text('MGD-Neuro 0.5.1',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Ora possiede anche un mondo sensoriale MGD: immagini e suoni diventano pattern appresi, non etichette fornite da un modello esterno. '
              'Nella scheda Sensi puoi fargli vedere e ascoltare; il ciclo mentale continua a propagare attività anche senza nuovi messaggi.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeachPage04 extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final double progress;
  final Future<void> Function(int) onLearn;

  const _TeachPage04({
    required this.controller,
    required this.busy,
    required this.progress,
    required this.onLearn,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Esperienza guidata',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
            'Ogni frase è un evento. Le frasi con relazioni stabili costruiscono memoria semantica senza fondere soggetti diversi.'),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          minLines: 8,
          maxLines: 16,
          decoration: const InputDecoration(
              border: OutlineInputBorder(), labelText: 'Testo da vivere'),
        ),
        const SizedBox(height: 12),
        if (busy || progress > 0)
          LinearProgressIndicator(value: progress.clamp(0, 1)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : () => onLearn(1),
              icon: const Icon(Icons.bolt),
              label: const Text('Vivi 1 volta'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : () => onLearn(5),
              icon: const Icon(Icons.repeat),
              label: const Text('Ripeti ×5'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _InfoCard04(
          icon: Icons.schema_outlined,
          title: 'Doppia memoria',
          body:
              'Episodi separati conservano il contesto; fatti relazionali integrano ciò che si ripete. Il sonno effettua replay e protegge le sinapsi consolidate con metaplasticità.',
        ),
      ],
    );
  }
}

class _SensesPage06 extends StatelessWidget {
  final MgdWorld06 world;
  final SensoryResult06? last;
  final TextEditingController labelController;
  final bool busy;
  final Future<void> Function() onCamera;
  final Future<void> Function() onGallery;
  final Future<void> Function() onListen;
  final Future<void> Function() onBind;
  final Future<void> Function() onThink;

  const _SensesPage06({
    required this.world,
    required this.last,
    required this.labelController,
    required this.busy,
    required this.onCamera,
    required this.onGallery,
    required this.onListen,
    required this.onBind,
    required this.onThink,
  });

  @override
  Widget build(BuildContext context) {
    final s = world.stats();
    final recent = world.thoughts.reversed.take(8).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Percezione MGD', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
          'Nessun classificatore di oggetti o trascrittore vocale esterno: la camera produce colore, contrasto, bordi e geometria; '
          'il microfono produce energia, ritmo, bande di frequenza e pitch. MGD crea e modifica i propri attrattori sensoriali.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
                onPressed: busy ? null : onCamera,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Guarda')),
            OutlinedButton.icon(
                onPressed: busy ? null : onGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Immagine')),
            FilledButton.tonalIcon(
                onPressed: busy ? null : onListen,
                icon: const Icon(Icons.hearing),
                label: const Text('Ascolta 2 s')),
            OutlinedButton.icon(
                onPressed: busy ? null : onThink,
                icon: const Icon(Icons.psychology),
                label: const Text('Pensa 96 passi')),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ultima percezione',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(world.lastPerceptionSummary()),
                if (last != null) ...[
                  const SizedBox(height: 8),
                  Text(
                      'Similarità ${(last!.observation.similarity * 100).round()}% · novità ${(last!.observation.novelty * 100).round()}%'),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: labelController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Se sai cos’è, dagli un nome',
                          hintText: 'es. mela, mia voce, campanello…',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                        onPressed: busy || last == null ? null : onBind,
                        icon: const Icon(Icons.link)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Metric04('Pattern visivi', '${s.visualPatterns}'),
            _Metric04('Pattern uditivi', '${s.auditoryPatterns}'),
            _Metric04('Legami mondo', '${s.worldEdges}'),
            _Metric04('Binding', '${s.semanticBindings}'),
            _Metric04('Cicli MGD', '${s.thoughtCycles}'),
            _Metric04('Età mondo τ', s.entropicAge.toStringAsFixed(2)),
          ],
        ),
        const SizedBox(height: 14),
        _Meter04(label: 'Novità sensoriale', value: s.novelty),
        _Meter04(label: 'Errore di previsione', value: s.predictionError),
        _Meter04(label: 'Curiosità', value: s.curiosity),
        _Meter04(label: 'Consolidamento mondo', value: s.meanSlow),
        const SizedBox(height: 14),
        Text('Attività del grafo',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text(
            'È propagazione ricorrente dell’attività tra memoria semantica e pattern sensoriali. I richiami mostrano relazioni già memorizzate. Il valore di attivazione non è una probabilità di verità.'),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const Text('Il ciclo mentale non ha ancora prodotto tracce.')
        else
          ...recent.map((t) => Card(
                child: ListTile(
                  leading: const Icon(Icons.psychology_alt_outlined),
                  title: Text(t.hypothesis),
                  subtitle: Text(
                      'Attivazione: ${(t.coherence * 100).round()}% • ${t.focus.join(' · ')}'),
                ),
              )),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _BrainPage04 extends StatefulWidget {
  final PlasticLanguageBrain04 brain;
  final bool busy;
  final Future<void> Function() onSleep;
  final Future<void> Function([String?]) onSave;
  final Future<void> Function() onReset;

  const _BrainPage04({
    required this.brain,
    required this.busy,
    required this.onSleep,
    required this.onSave,
    required this.onReset,
  });

  @override
  State<_BrainPage04> createState() => _BrainPage04State();
}

class _BrainPage04State extends State<_BrainPage04> {
  @override
  Widget build(BuildContext context) {
    final s = widget.brain.stats();
    final facts = widget.brain.strongestFacts(limit: 16);
    final graph = widget.brain.semanticGraph(limit: 120);
    final concepts = widget.brain.concepts.take(10).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Metric04('Token', '${s.vocabulary}'),
            _Metric04('Sinapsi', '${s.synapses}'),
            _Metric04('Episodi', '${s.episodes}'),
            _Metric04('Entità', '${s.entities}'),
            _Metric04('Relazioni', '${s.relations}'),
            _Metric04('Fatti', '${s.facts}'),
            _Metric04('Conflitti', '${s.conflicts}'),
            _Metric04('Concetti', '${s.concepts}'),
            _Metric04('Età τ', s.entropicAge.toStringAsFixed(2)),
          ],
        ),
        const SizedBox(height: 14),
        _Meter04(label: 'Novità', value: s.novelty),
        _Meter04(label: 'Prediction error', value: s.predictionError),
        _Meter04(label: 'Curiosità', value: s.curiosity),
        _Meter04(label: 'Memoria lenta media', value: s.meanSlow.clamp(0, 1)),
        _Meter04(
            label: 'Flusso Δτ ultimo evento', value: s.lastFlux.clamp(0, 1)),
        const SizedBox(height: 14),
        AspectRatio(
          aspectRatio: 1.55,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: _SemanticPainter04(graph),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('Memoria relazionale appresa',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (facts.isEmpty)
          const Text('Nessun fatto stabile ancora.')
        else
          ...facts.map((f) => ListTile(
                dense: true,
                leading: Icon(
                    f.conflict ? Icons.warning_amber_rounded : Icons.memory,
                    size: 19),
                title: Text('${f.subject}  — ${f.relation} →  ${f.object}'),
                subtitle: f.conflict
                    ? const Text('Conflitto attivo: più ipotesi concorrenti')
                    : null,
                trailing: Text('${(f.confidence * 100).round()}%'),
              )),
        const SizedBox(height: 8),
        Text('Concetti emergenti da struttura relazionale',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (concepts.isEmpty)
          const Text(
              'Servono più entità con relazioni simili. Le parole funzionali non vengono più scambiate per concetti.')
        else
          ...concepts.map((c) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '${c.label}  · ${(c.coherence * 100).toStringAsFixed(0)}%\n'
                    '${c.entityIds.map((id) => widget.brain.entities[id].label).join('  ·  ')}',
                  ),
                ),
              )),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: widget.busy ? null : widget.onSleep,
              icon: const Icon(Icons.bedtime),
              label: const Text('Dormi / consolida'),
            ),
            OutlinedButton.icon(
              onPressed: widget.busy ? null : () => widget.onSave(),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salva'),
            ),
            TextButton.icon(
              onPressed: widget.busy ? null : widget.onReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Azzera'),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Metric04 extends StatelessWidget {
  final String label, value;
  final bool session;
  const _Metric04(this.label, this.value, {this.session = false});
  @override
  Widget build(BuildContext context) =>
      InspectMetric315(label, value, session: session);
}

class _Meter04 extends StatelessWidget {
  final String label;
  final double value;
  const _Meter04({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0).toDouble();
    final isFlux = label.contains('Δτ');
    return InkWell(
      onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(label),
                content: Text('Valore: ${value.toStringAsFixed(6)}.\n'
                    '${isFlux ? "Variazione di età entropica nell’ultimo aggiornamento; non è una percentuale." : "Indicatore interno compreso tra 0 e 1; non misura intelligenza o accuratezza."}\n'
                    '${label.contains("sensoriale") || label.contains("previsione") ? "Si aggiorna con le osservazioni sensoriali. In assenza di osservazioni può restare a zero." : "Apri le memorie e gli archi per i dati sottostanti."}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Chiudi'))
                ],
              )),
      child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(
                width: 156,
                child:
                    Text(label, style: Theme.of(context).textTheme.bodySmall)),
            Expanded(child: LinearProgressIndicator(value: v)),
            const SizedBox(width: 8),
            SizedBox(
                width: 58,
                child: Text(
                    isFlux ? value.toStringAsFixed(3) : '${(v * 100).round()}%',
                    textAlign: TextAlign.end)),
          ])),
    );
  }
}

class _InfoCard04 extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _InfoCard04(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pulse04 extends StatelessWidget {
  final bool active;
  const _Pulse04({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _SemanticPainter04 extends CustomPainter {
  final List<({String from, String relation, String to, double confidence})>
      links;
  _SemanticPainter04(this.links);

  @override
  void paint(Canvas canvas, Size size) {
    if (links.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text:
              'Il grafo mostrerà entità e relazioni, non semplici co-occorrenze.',
          style: TextStyle(fontSize: 13, color: Colors.white70),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
      )..layout(maxWidth: size.width - 30);
      tp.paint(canvas, Offset(15, size.height / 2 - tp.height / 2));
      return;
    }

    final names = <String>{};
    for (final l in links) {
      names.add(l.from);
      names.add(l.to);
    }
    final nodes = names.take(14).toList();
    final pos = <String, Offset>{};
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.34;
    for (var i = 0; i < nodes.length; i++) {
      final a = 2 * pi * i / nodes.length - pi / 2;
      pos[nodes[i]] = center + Offset(cos(a) * radius, sin(a) * radius);
    }

    final line = Paint()..style = PaintingStyle.stroke;
    for (final l in links) {
      final a = pos[l.from];
      final b = pos[l.to];
      if (a == null || b == null) continue;
      line
        ..strokeWidth = 0.8 + 2.3 * l.confidence.clamp(0.0, 1.0)
        ..color = Colors.white
            .withValues(alpha: 0.12 + 0.34 * l.confidence.clamp(0.0, 1.0));
      canvas.drawLine(a, b, line);

      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final rt = TextPainter(
        text: TextSpan(
            text: l.relation,
            style: const TextStyle(fontSize: 8, color: Colors.white54)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 52);
      rt.paint(canvas, mid + const Offset(2, -8));
    }

    final nodePaint = Paint()..color = Colors.white.withValues(alpha: 0.80);
    for (final n in nodes) {
      final p = pos[n]!;
      canvas.drawCircle(p, 4.5, nodePaint);
      final tp = TextPainter(
        text: TextSpan(
            text: n,
            style: const TextStyle(fontSize: 10, color: Colors.white70)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 70);
      tp.paint(canvas, p + const Offset(7, -6));
    }
  }

  @override
  bool shouldRepaint(covariant _SemanticPainter04 oldDelegate) => true;
}
