// CLS_MEDIA_ATLAS_0340
// CLS_REFINEMENT_0340_2
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'cls_core_v0340.dart';
import 'cls_media_v0340.dart';
import 'cls_store_v0340.dart';
import 'experience_page_v0330.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';

class ClsPage340 extends StatefulWidget {
  final MgdWorld06 world;
  final Future<void> Function() onSave;
  final ClsStore340? store;
  const ClsPage340(
      {super.key, required this.world, required this.onSave, this.store});
  @override
  State<ClsPage340> createState() => _ClsPage340State();
}

class _ClsPage340State extends State<ClsPage340> with WidgetsBindingObserver {
  ClsStore340? _store;
  final _text = TextEditingController(), _label = TextEditingController();
  final _context = TextEditingController(text: 'generale'),
      _query = TextEditingController();
  final _prefix = TextEditingController(),
      _topics =
          TextEditingController(text: 'lingua italiana, grammatica italiana');
  Map<String, double>? _vision, _audio;
  Uint8List? _imageBytes, _audioBytes;
  Map<String, int> _stats = {};
  List<Map<String, Object?>> _rows = [];
  Recall340? _fast, _slow, _neighbors;
  Pattern340? _focus;
  Map<int, MediaPreview340> _previews = {};
  bool _busy = true,
      _cancel = false,
      _auto = true,
      _web = false,
      _foreground = true,
      _more = true;
  String _status = 'Apertura dell’archivio episodico…', _generated = '';
  Timer? _timer;
  AudioRecorder? _recorder;
  DateTime _lastWeb = DateTime.fromMillisecondsSinceEpoch(0);

  static const _audioChannel = MethodChannel('mgd.cls/audio');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      _store = widget.store ?? await ClsStore340.shared;
      final imported = await _store!.migrateLegacy(
          widget.world.experience33.episodes.map((e) => e.toJson()));
      _auto = (await _store!.readSetting('auto')) != 'false';
      _topics.text = await _store!.readSetting('topics') ?? _topics.text;
      // Network permission is session-scoped; no hidden requests on startup.
      await _refresh();
      if (mounted)
        setState(() => _status =
            'Archivio pronto. $imported episodi precedenti importati.');
      _timer = Timer.periodic(
          const Duration(seconds: 10), (_) => unawaited(_tick()));
    } catch (e) {
      if (mounted) setState(() => _status = 'Apertura non riuscita: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _cancel = true;
      unawaited(_recorder?.stop());
      unawaited(_stopAudio());
    }
  }

  @override
  void dispose() {
    _cancel = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final c in [_text, _label, _context, _query, _prefix, _topics]) {
      c.dispose();
    }
    unawaited(_recorder?.dispose());
    unawaited(_stopAudio());
    super.dispose();
  }

  Future<void> _stopAudio() async {
    try {
      await _audioChannel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  Future<void> _refresh({bool append = false}) async {
    final s = _store;
    if (s == null) return;
    final stats = await s.stats();
    final rows = await s.page(
        after: append && _rows.isNotEmpty ? _rows.last['id'] as int : 0,
        query: _query.text,
        limit: 64);
    if (mounted)
      setState(() {
        _stats = stats;
        _more = rows.length == 64;
        _rows = append ? [..._rows, ...rows] : rows;
      });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _store == null) return;
    setState(() {
      _busy = true;
      _cancel = false;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _status = 'Operazione non completata: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Cue340 _cue() => {
        if (_text.text.trim().isNotEmpty)
          'text:v1': Italian340.features(_text.text),
        if (_vision != null) 'vision:v1': _vision!,
        if (_audio != null) 'audio:v1': _audio!,
      };
  Future<void> _teach() => _run(() async {
        final id = await _store!.learn(_cue(),
            label: _label.text,
            context: _context.text,
            text: _text.text,
            image: _imageBytes,
            audio: _audioBytes);
        await _refresh();
        if (mounted)
          setState(() => _status =
              'Episodio $id salvato; disponibile subito al richiamo.');
      });
  Future<void> _recall() => _run(() async {
        final fast = await _store!.recall(_cue(), context: _context.text);
        final slow = await _store!.recallSlow(_cue(), context: _context.text);
        if (mounted)
          setState(() {
            _fast = fast;
            _slow = slow;
            _status =
                'Richiamo in ${(_store!.lastRecallMicros / 1000).toStringAsFixed(2)} ms: '
                '${_store!.lastCandidates} candidati. Punteggi non calibrati.';
          });
      });
  Future<void> _image(ImageSource source) => _run(() async {
        final file = await ImagePicker().pickImage(
            source: source,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
            requestFullMetadata: false);
        if (file == null) return;
        final bytes = await file.readAsBytes();
        final f = await compute(imageWorker33, bytes);
        if (mounted)
          setState(() {
            _imageBytes = bytes;
            _vision = f;
            _status = 'Foto pronta e conservabile nell’episodio.';
          });
      });
  Future<void> _record() => _run(() async {
        final recorder = _recorder ??= AudioRecorder();
        if (!await recorder.hasPermission())
          throw StateError('Permesso microfono non concesso.');
        final bytes = BytesBuilder(copy: false);
        StreamSubscription<Uint8List>? sub;
        try {
          final stream = await recorder.startStream(const RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 16000,
              numChannels: 1));
          sub = stream.listen((b) {
            if (bytes.length < 96000) bytes.add(b);
          });
          if (mounted)
            setState(() => _status = 'Registrazione di due secondi…');
          await Future<void>.delayed(const Duration(seconds: 2));
          await recorder.stop();
          await sub.cancel();
          sub = null;
          if (_cancel || !_foreground)
            throw StateError('Registrazione interrotta.');
          final raw = bytes.takeBytes(),
              features = await compute(audioWorker33, raw);
          if (mounted)
            setState(() {
              _audioBytes = raw;
              _audio = features;
              _status =
                  'Audio conservato come PCM; nessuna trascrizione automatica.';
            });
        } finally {
          await sub?.cancel();
          await recorder.stop();
        }
      });
  Future<void> _import() => _run(() async {
        final result = await FilePicker.platform.pickFiles(
            type: FileType.custom, allowedExtensions: ['txt'], withData: false);
        final path = result?.files.single.path;
        if (path == null) return;
        final n = await _store!.importFile(File(path),
            context: _context.text,
            cancelled: () => _cancel || !mounted,
            progress: (n) {
              if (mounted)
                setState(() => _status =
                    '$n passaggi elaborati; puoi interrompere senza perdere quelli salvati.');
            });
        await _refresh();
        if (mounted)
          setState(() => _status =
              '$n passaggi elaborati. Il consolidamento aggiorna lessico e sequenze.');
      });
  Future<void> _sleep() => _run(() async {
        var n = 0;
        do {
          final done = await _store!.consolidate(budget: 8);
          n += done;
          if (done == 0) break;
          if (mounted)
            setState(
                () => _status = '$n episodi consolidati in questa sessione.');
          await Future<void>.delayed(const Duration(milliseconds: 2));
        } while (!_cancel && mounted && _foreground);
        await _refresh();
      });
  Future<void> _tick() async {
    if (!_auto || !_foreground || _busy || !mounted || _store == null) return;
    await _run(() async {
      final n = await _store!.consolidate(budget: 8);
      if (_web && DateTime.now().difference(_lastWeb).inSeconds >= 120)
        await _studyWeb();
      if (n > 0) {
        await _refresh();
        if (mounted)
          setState(() => _status = 'Consolidamento autonomo: $n episodi.');
      }
    });
  }

  Future<void> _studyWeb() async {
    final topics = _topics.text
        .split(',')
        .map((x) => x.trim())
        .where((x) => x.length >= 3 && x.length <= 100)
        .toList();
    if (topics.isEmpty) throw StateError('Indica gli argomenti autorizzati.');
    final before = (await _store!.stats())['episodes']!;
    final timer = Stopwatch()..start();
    final history =
        jsonDecode(await _store!.readSetting('studyProgress') ?? '{}') as Map;
    final topic = StudyPriority340.choose(
        topics, history, DateTime.now().millisecondsSinceEpoch);

    _lastWeb = DateTime.now();
    await _store!.setting('topics', _topics.text);
    if (mounted)
      setState(() => _status =
          'Studio di “$topic” da fonti esterne; i testi non diventano fatti certificati.');
    final draft = await WebKnowledgeExplorer11().research(ResearchGoal11(
        query: topic,
        topic: topic,
        reason: 'Argomento autorizzato dall’utente',
        value: 1));
    if (_cancel || !mounted || !_foreground) return;
    var n = 0;
    for (final doc in draft.documents) {
      if (_cancel || !mounted || !_foreground) break;
      n += await _store!.importText(doc.text,
          source: '${doc.provider}: ${doc.url}',
          label: doc.title,
          context: _context.text,
          cancelled: () => _cancel || !mounted || !_foreground);
    }
    final after = (await _store!.stats())['episodes']!;
    final previous = history[topic] as Map? ?? {};
    history[topic] = {
      'visits': ((previous['visits'] as num?) ?? 0) + 1,
      'gain': max(0, after - before),
      'cost': timer.elapsedMilliseconds / 1000,
      'at': DateTime.now().millisecondsSinceEpoch
    };
    await _store!.setting('studyProgress', jsonEncode(history));
    await _refresh();
    if (mounted)
      setState(() => _status =
          'Studio di “$topic”: $n passaggi elaborati, ${after - before} nuovi episodi.');
  }

  Future<void> _generate() => _run(() async {
        final value =
            await _store!.continueText(_prefix.text, context: _context.text);
        if (mounted)
          setState(() => _generated = value.isEmpty
              ? 'Nessuna sequenza appresa in questo contesto.'
              : value);
      });
  Future<void> _select(Pattern340 focus) => _run(() async {
        final neighbors = await _store!
            .recall(focus.cue, context: focus.context, neighborhood: true);
        final previews = <int, MediaPreview340>{};
        final ids = {focus.id, ...neighbors.evidence.take(24).map((e) => e.id)};
        for (final id in ids) {
          if (_cancel || !mounted || !_foreground) break;
          if (_previews.containsKey(id)) {
            previews[id] = _previews[id]!;
            continue;
          }
          final rows = await _store!.db.query('episodes',
              columns: ['image', 'audio'], where: 'id=?', whereArgs: [id]);
          if (rows.isEmpty) continue;
          final media = <String, Uint8List>{
            for (final e in rows.single.entries)
              if (e.value is Uint8List) e.key: e.value as Uint8List
          };
          if (media.isNotEmpty)
            previews[id] = await compute(mediaPreview340, media);
        }
        if (mounted)
          setState(() {
            _focus = focus;
            _neighbors = neighbors;
            _previews = previews;
          });
      });
  Future<void> _legacyDelete(String uid) async {
    if (!uid.startsWith('legacy33:')) return;
    final id = int.tryParse(uid.substring('legacy33:'.length));
    if (id == null) return;
    widget.world.experience33 = await compute(deleteWorker33, (
      memory: widget.world.experience33.toJson(),
      id: id,
      label: null,
      context: null
    ));
    widget.world.step++;
    await widget.onSave();
  }

  Future<void> _detail(int id) async {
    final row = await _store!.get(id);
    if (row == null || !mounted) return;
    final corrected = TextEditingController(text: row['label'] as String);
    final action = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text('Esperienza $id'),
                content: SizedBox(
                    width: 560,
                    child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          if (row['image'] is Uint8List)
                            Image.memory(row['image'] as Uint8List,
                                cacheWidth: 600),
                          if (row['audio'] is Uint8List)
                            Wrap(children: [
                              TextButton.icon(
                                  onPressed: () async {
                                    try {
                                      await _audioChannel.invokeMethod<void>(
                                          'play', row['audio']);
                                    } catch (e) {
                                      if (mounted)
                                        setState(() => _status =
                                            'Riproduzione non disponibile: $e');
                                    }
                                  },
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Riascolta audio')),
                              TextButton(
                                  onPressed: _stopAudio,
                                  child: const Text('Ferma'))
                            ]),
                          SelectableText(row['text'] as String),
                          const SizedBox(height: 12),
                          SelectableText(
                              'Fonte: ${row['source']}\nData: ${row['created']}\nContesto: ${row['context']}'),
                          const SizedBox(height: 12),
                          TextField(
                              controller: corrected,
                              decoration: const InputDecoration(
                                  labelText: 'Etichetta corretta')),
                          const Text(
                              'La cancellazione rimuove anche allegati e contributi linguistici. I concetti interessati vengono ricostruiti.')
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, 'delete'),
                      child: const Text('Elimina')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, 'correct'),
                      child: const Text('Correggi')),
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Chiudi'))
                ]));
    await _stopAudio();
    final label = corrected.text;
    Future<void>.delayed(const Duration(milliseconds: 500), corrected.dispose);
    if (!mounted) return;
    if (action == 'delete') {
      final yes = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Confermi l’eliminazione?'),
                  content: const Text(
                      'Questa esperienza e i suoi allegati verranno rimossi.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Annulla')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Elimina'))
                  ]));
      if (yes != true || !mounted) return;
      await _run(() async {
        await _legacyDelete(row['uid'] as String);
        await _store!.delete(id);
        await _refresh();
        if (mounted)
          setState(() {
            _focus = null;
            _neighbors = null;
            _fast = null;
            _slow = null;
            _generated = '';
          });
      });
    } else if (action == 'correct') {
      await _run(() async {
        await _legacyDelete(row['uid'] as String);
        await _store!.correct(id, label);
        await _refresh();
        if (mounted)
          setState(() {
            _focus = null;
            _neighbors = null;
            _fast = null;
            _slow = null;
            _status = 'Correzione persistente salvata.';
          });
      });
    }
  }

  Future<void> _export() => _run(() async {
        final bytes = await _store!.exportDatabase();
        await FilePicker.platform
            .saveFile(fileName: 'MGD-CLS-0.34.sqlite', bytes: bytes);
        if (mounted)
          setState(() => _status =
              'Esportazione richiesta: archivio con memorie e allegati.');
      });
  Widget _button(String text, VoidCallback action, {IconData? icon}) => Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: OutlinedButton.icon(
          onPressed: _busy ? null : action,
          icon: Icon(icon ?? Icons.play_arrow),
          label: Text(text)));
  Widget _prediction(String title, Recall340? r) => r == null
      ? const SizedBox.shrink()
      : Card(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$title: ${r.best ?? 'nessun candidato'}',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(r.conflict
                        ? 'Conferme incompatibili: occorre correggere.'
                        : r.accepted
                            ? 'Candidato richiamato, non certificazione di verità.'
                            : 'Stimolo nuovo o ambiguo: non accettato.'),
                    Text(
                        'Somiglianza: ${r.similarity.toStringAsFixed(3)} · ${r.energy.length - 1} aggiornamenti Hopfield'),
                    for (final e in r.evidence.take(3))
                      ListTile(
                          dense: true,
                          title: Text(e.label),
                          subtitle: Text(e.text,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: e.id > 0 ? () => _detail(e.id) : null)
                  ])));
  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 4,
      child: PopScope(
          canPop: !_busy,
          child: Scaffold(
              appBar: AppBar(
                  title: const Text('MGD · Memorie complementari'),
                  actions: [
                    IconButton(
                        onPressed: _busy ? null : _export,
                        icon: const Icon(Icons.save_alt),
                        tooltip: 'Esporta archivio'),
                    IconButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => ExperiencePage33(
                                        world: widget.world,
                                        onSave: widget.onSave))),
                        icon: const Icon(Icons.history),
                        tooltip: 'Archivio precedente')
                  ],
                  bottom: const TabBar(isScrollable: true, tabs: [
                    Tab(text: 'Esperienza'),
                    Tab(text: 'Atlante'),
                    Tab(text: 'Italiano'),
                    Tab(text: 'Studio')
                  ])),
              body: SafeArea(
                  child: Column(children: [
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Text(
                          '${_stats['episodes'] ?? 0} episodi · ${_stats['prototypes'] ?? 0} concetti lenti · ${_stats['vocabulary'] ?? 0} token'),
                      Text(_status,
                          key: const ValueKey('cls-status'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                      if (_busy)
                        Row(children: [
                          const Expanded(child: LinearProgressIndicator()),
                          TextButton(
                              onPressed: () => setState(() => _cancel = true),
                              child: const Text('Interrompi'))
                        ])
                    ])),
                Expanded(
                    child: TabBarView(children: [
                  ListView(
                      key: const ValueKey('cls-experience-list'),
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                            'Il testo, la foto e l’audio appartengono allo stesso episodio. Il nome da imparare resta separato dagli stimoli.'),
                        TextField(
                            controller: _context,
                            enabled: !_busy,
                            decoration:
                                const InputDecoration(labelText: 'Contesto')),
                        TextField(
                            key: const ValueKey('cls-input'),
                            controller: _text,
                            enabled: !_busy,
                            maxLines: 4,
                            maxLength: 16000,
                            decoration: const InputDecoration(
                                labelText: 'Testo dell’esperienza')),
                        TextField(
                            key: const ValueKey('cls-label'),
                            controller: _label,
                            enabled: !_busy,
                            maxLength: 160,
                            decoration: const InputDecoration(
                                labelText: 'Nome / etichetta da imparare')),
                        if (_imageBytes != null)
                          Image.memory(_imageBytes!,
                              height: 140, cacheWidth: 300),
                        Wrap(children: [
                          _button(
                              'Fotocamera', () => _image(ImageSource.camera),
                              icon: Icons.camera_alt),
                          _button('Galleria', () => _image(ImageSource.gallery),
                              icon: Icons.photo),
                          _button('Registra audio', _record, icon: Icons.mic),
                          _button(
                              'Rimuovi stimoli',
                              () => setState(() {
                                    _vision = null;
                                    _audio = null;
                                    _imageBytes = null;
                                    _audioBytes = null;
                                  }),
                              icon: Icons.clear)
                        ]),
                        FilledButton(
                            key: const ValueKey('cls-teach'),
                            onPressed: _busy ? null : _teach,
                            child: const Text('Conferma e impara')),
                        const SizedBox(height: 8),
                        OutlinedButton(
                            onPressed: _busy ? null : _recall,
                            child: const Text('Richiama per associazione')),
                        _prediction('Memoria episodica rapida', _fast),
                        _prediction('Memoria concettuale lenta', _slow)
                      ]),
                  ListView(padding: const EdgeInsets.all(16), children: [
                    TextField(
                        controller: _query,
                        decoration: const InputDecoration(
                            labelText: 'Cerca nelle esperienze',
                            prefixIcon: Icon(Icons.search)),
                        onSubmitted: (_) => _run(() => _refresh())),
                    const Text(
                        'Seleziona un episodio per vedere i vicini associativi; apri la scheda per foto, audio, fonti e correzioni.'),
                    if (_focus != null && _neighbors != null)
                      SizedBox(
                          height: 420,
                          child: ExperienceAtlas340(
                              focus: _focus!,
                              neighbors: _neighbors!.evidence.take(24).toList(),
                              previews: _previews,
                              onOpen: _detail)),
                    if (_focus != null)
                      const Text(
                          'Distanza radiale basata sulla somiglianza degli stimoli. Angolo puramente grafico; non anatomia del cervello.'),
                    for (final row in _rows)
                      Card(
                          child: ListTile(
                              title: Text('${row['label']} · #${row['id']}'),
                              subtitle: Text('${row['text']}\n${row['source']}',
                                  maxLines: 3, overflow: TextOverflow.ellipsis),
                              onTap:
                                  _busy ? null : () => _select(pattern340(row)),
                              trailing: IconButton(
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: _busy
                                      ? null
                                      : () => _detail(row['id'] as int)))),
                    if (_more)
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() => _refresh(append: true)),
                          child: const Text('Carica altri episodi'))
                  ]),
                  ListView(padding: const EdgeInsets.all(16), children: [
                    const Text(
                        'Apprendimento incrementale da testi reali: lessico e contesti di fino a tre token. Non è ancora italiano fluente né comprensione generale.'),
                    const SizedBox(height: 12),
                    _button('Importa libro TXT', _import,
                        icon: Icons.upload_file),
                    _button('Consolida gli episodi', _sleep,
                        icon: Icons.bedtime),
                    TextField(
                        controller: _prefix,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                            labelText: 'Inizio della frase')),
                    _button('Continua con le sequenze apprese', _generate),
                    SelectableText(_generated),
                    const SizedBox(height: 12),
                    const Text(
                        'La continuazione è un esperimento statistico, non una risposta fattuale. Le parole derivano dai testi consolidati nel contesto selezionato.')
                  ]),
                  ListView(padding: const EdgeInsets.all(16), children: [
                    SwitchListTile(
                        value: _auto,
                        onChanged: _busy
                            ? null
                            : (v) async {
                                setState(() => _auto = v);
                                await _store?.setting('auto', v.toString());
                              },
                        title: const Text('Consolidamento autonomo locale'),
                        subtitle: const Text(
                            'Piccoli lotti, solo con questa pagina in primo piano. Nessun ricordo eliminato per fare spazio.')),
                    TextField(
                        controller: _topics,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                            labelText:
                                'Argomenti autorizzati, separati da virgole')),
                    SwitchListTile(
                        value: _web,
                        onChanged:
                            _busy ? null : (v) => setState(() => _web = v),
                        title: const Text(
                            'Studio web degli argomenti autorizzati'),
                        subtitle: const Text(
                            'Invia soltanto gli argomenti qui indicati ai servizi di ricerca. Non invia foto, audio o memorie personali. Si disattiva chiudendo la pagina.')),
                    _button(
                        'Studia adesso questi argomenti', () => _run(_studyWeb),
                        icon: Icons.travel_explore),
                    _button('Ripassa e consolida adesso', _sleep,
                        icon: Icons.psychology),
                    Text(
                        'Da consolidare: ${(_stats['episodes'] ?? 0) - (_stats['consolidated'] ?? 0)}\nContenuti: ${((_stats['payloadBytes'] ?? 0) / 1048576).toStringAsFixed(2)} MiB (esclusi indici e spazio SQLite).'),
                    const SizedBox(height: 12),
                    const Text(
                        'Nessun tetto al numero totale di episodi. Rimangono budget per singolo calcolo, disco e memoria fisici. Richiamo indicizzato approssimato: non confronta ogni ricordo a ogni domanda.')
                  ])
                ]))
              ])))));
}

class ExperienceAtlas340 extends StatelessWidget {
  final Pattern340 focus;
  final List<Pattern340> neighbors;
  final ValueChanged<int> onOpen;
  final Map<int, MediaPreview340> previews;
  const ExperienceAtlas340(
      {super.key,
      required this.focus,
      required this.neighbors,
      required this.onOpen,
      this.previews = const {}});
  @override
  Widget build(BuildContext context) {
    const center = Offset(550, 400);
    final nodes = <Pattern340>[
      focus,
      ...neighbors.where((e) => e.id != focus.id)
    ];
    final points = <Offset>[center];
    final similarities = <double>[1];
    for (var i = 1; i < nodes.length; i++) {
      final channels = focus.cue.keys.where(nodes[i].cue.containsKey).toList();
      final s = channels.isEmpty
          ? 0.0
          : Hopfield340.dot(Hopfield340.flatten(focus.cue, channels),
              Hopfield340.flatten(nodes[i].cue, channels));
      final radius = 150 + 250 * (1 - s.clamp(0.0, 1.0));
      final angle = i * 2.399963229728653;
      points.add(center + Offset(cos(angle) * radius, sin(angle) * radius));
      similarities.add(s);
    }
    return InteractiveViewer(
        minScale: 1,
        maxScale: 8,
        child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
                width: 1100,
                height: 800,
                child: Stack(children: [
                  Positioned.fill(
                      child: CustomPaint(
                          painter: _AtlasEdges340(
                              points, Theme.of(context).colorScheme.outline))),
                  for (var i = 0; i < nodes.length; i++)
                    Positioned(
                        left: points[i].dx - 70,
                        top: points[i].dy - 35,
                        width: 140,
                        child: Card(
                            child: InkWell(
                                onTap: () => onOpen(nodes[i].id),
                                child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(children: [
                                      ExperiencePreview340(
                                          preview: previews[nodes[i].id],
                                          fallback: nodes[i]
                                                  .cue
                                                  .containsKey('vision:v1')
                                              ? Icons.image
                                              : nodes[i]
                                                      .cue
                                                      .containsKey('audio:v1')
                                                  ? Icons.graphic_eq
                                                  : Icons.notes),
                                      Text(nodes[i].label,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      Text(
                                          '#${nodes[i].id} · ${similarities[i].toStringAsFixed(2)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall)
                                    ])))))
                ]))));
  }
}

class _AtlasEdges340 extends CustomPainter {
  final List<Offset> points;
  final Color color;
  _AtlasEdges340(this.points, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final point in points.skip(1)) canvas.drawLine(points.first, point, p);
  }

  @override
  bool shouldRepaint(covariant _AtlasEdges340 old) =>
      old.points != points || old.color != color;
}
