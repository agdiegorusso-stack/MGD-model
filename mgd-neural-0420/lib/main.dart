import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'book_text_v0420.dart' show BookText420;
import 'canonical_memory_v0420.dart';
import 'cognitive_coordinator_v0420.dart';
import 'sensory_features_v0420.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MgdNeuralApp420());
}

class MgdNeuralApp420 extends StatelessWidget {
  final CanonicalMemory420? memory;
  const MgdNeuralApp420({super.key, this.memory});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'MGD Neural',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xff889cff),
    ),
    home: NeuralHome420(memory: memory),
  );
}

class NeuralHome420 extends StatefulWidget {
  final CanonicalMemory420? memory;
  const NeuralHome420({super.key, this.memory});
  @override
  State<NeuralHome420> createState() => _NeuralHome420State();
}

class _NeuralHome420State extends State<NeuralHome420> {
  CanonicalMemory420? memory;
  CognitiveCoordinator420? coordinator;
  final chat = TextEditingController(), teaching = TextEditingController();
  final label = TextEditingController(),
      title = TextEditingController(text: 'Testo insegnato');
  final recorder = AudioRecorder();
  final history = <Map<String, dynamic>>[];
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> sources = [], graph = [], unresolved = [];
  Map<String, double>? sensorFeatures;
  String sensorModality = '',
      sensorStatus =
          'Acquisisci una foto o un suono, poi assegna un’etichetta.';
  String status = 'Apertura della memoria…', error = '';
  String? scope;
  int tab = 0, graphPage = 0;
  bool ready = false, busy = false, cancelled = false;
  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    chat.dispose();
    teaching.dispose();
    label.dispose();
    title.dispose();
    cancelled = true;
    unawaited(recorder.dispose());
    if (widget.memory == null)
      unawaited(memory?.close() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _open() async {
    try {
      memory = widget.memory ?? await CanonicalMemory420.open();
      coordinator = await CognitiveCoordinator420.create(memory!);
      final old = await memory!.meta('chat_history420');
      history.clear();
      if (old != null) {
        history.addAll(
          (jsonDecode(old) as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
      }
      await _refresh();
      if (mounted)
        setState(() {
          ready = true;
          status = 'Memoria pronta. Le risposte mostrano le proprie evidenze.';
          error = '';
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          status = 'Apertura interrotta. I dati precedenti sono conservati.';
        });
    }
  }

  Future<void> _refresh() async {
    final m = memory!;
    final nextStats = await m.stats(), nextSources = await m.sources();
    final nextGraph = await m.graph(offset: graphPage * 100);
    final nextUnresolved = await m.unresolved();
    if (mounted)
      setState(() {
        stats = nextStats;
        sources = nextSources;
        graph = nextGraph;
        unresolved = nextUnresolved;
        if (scope != null && !sources.any((s) => s['id'] == scope))
          scope = null;
      });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || !ready) return;
    setState(() {
      busy = true;
      cancelled = false;
      error = '';
    });
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          status = 'Operazione non completata.';
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _send() => _run(() async {
    final input = chat.text.trim();
    if (input.isEmpty) return;
    chat.clear();
    setState(() {
      history.add({'user': true, 'text': input});
      status = 'Recupero e confronto delle evidenze…';
    });
    final reply = await coordinator!.process(input, scope: scope);
    if (!mounted) return;
    setState(() {
      history.add({
        'user': false,
        'text': reply.text,
        'status': reply.status,
        'reason': reply.reason,
        'ids': reply.claimIds,
      });
      status =
          '${reply.candidates} relazioni consultate · ${(reply.micros / 1000).toStringAsFixed(1)} ms';
    });
    if (history.length > 80) history.removeRange(0, history.length - 80);
    await memory!.setMeta('chat_history420', jsonEncode(history));
  });
  Future<void> _teach() => _run(() async {
    final result = await memory!.ingestText(
      teaching.text,
      title: title.text.trim().isEmpty ? 'Testo insegnato' : title.text,
    );
    if (mounted)
      setState(
        () => status = result['new'] == true
            ? '${result['units']} blocchi salvati, ${result['claims']} relazioni interpretate.'
            : 'Questo testo è già presente. Nessuna nuova evidenza conteggiata.',
      );
  });
  Future<void> _import() => _run(() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withReadStream: true,
      withData: false,
    );
    if (picked == null) return;
    final item = picked.files.single;
    File? staged;
    try {
      final File file;
      if (item.path != null) {
        file = File(item.path!);
      } else {
        if (item.readStream == null)
          throw const FormatException(
            'Il provider non ha fornito un flusso leggibile.',
          );
        staged = File(
          '${(await getTemporaryDirectory()).path}/mgd-import-${DateTime.now().microsecondsSinceEpoch}.txt',
        );
        await BookText420.stage(
          item.readStream!,
          staged,
          name: item.name,
          cancelled: () => cancelled || !mounted,
        );
        if (cancelled || !mounted) {
          if (mounted)
            setState(
              () => status =
                  'Acquisizione interrotta. Nessuna fonte parziale aggiunta.',
            );
          return;
        }
        file = staged;
      }
      final result = await memory!.importFile(
        file,
        title: item.name,
        cancelled: () => cancelled || !mounted,
        progress: (units, chars) {
          if (mounted)
            setState(() => status = '$units blocchi, $chars caratteri letti.');
        },
      );
      if (mounted)
        setState(() {
          scope = result['source'] as String;
          status = result['new'] == false
              ? 'Libro già presente.'
              : '${result['cancelled'] == true ? 'Lettura interrotta e salvata' : 'Lettura completata'}: ${result['claims']} nuove relazioni.';
        });
    } finally {
      if (staged != null && await staged.exists()) await staged.delete();
    }
  });
  Future<String?> _askText(String heading, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(heading),
        content: TextField(
          key: const ValueKey('correction420'),
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _evidence(Map<String, dynamic> message) async {
    final ids = List<String>.from(message['ids'] as List? ?? []);
    final rows = await memory!.evidence(ids);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .75,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Evidenze della risposta',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              if (rows.isEmpty)
                const Text('Nessuna relazione fattuale utilizzata.'),
              for (final row in rows)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${row['title']} · blocco ${row['ordinal']}'),
                        Text(
                          _relationLabel(row),
                          style: Theme.of(sheetContext).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          '${row['text']}'.isEmpty
                              ? 'Originale non disponibile.'
                              : '${row['text']}',
                        ),
                        if (row['status'] != 'asserted')
                          const Text(
                            'Questa relazione è stata corretta dopo la risposta.',
                          ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  unawaited(_correct('${row['id']}'));
                                },
                          child: const Text('Correggi questa relazione'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _correct(String id) async {
    final text = await _askText(
      'Correggi la relazione',
      'Scrivi la nuova frase completa, con soggetto e predicato.',
    );
    if (text == null || text.isEmpty || !mounted) return;
    await _run(() async {
      await memory!.correct([id], text);
      if (mounted)
        setState(
          () => status =
              'Correzione salvata; la relazione precedente è revocata.',
        );
    });
  }

  Future<void> _photo(ImageSource source) => _run(() async {
    final photo = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
      requestFullMetadata: false,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    final features = await compute(SensoryFeatures420.vision, bytes);
    sensorFeatures = features;
    sensorModality = 'vision';
    final matches = await memory!.recognize('vision', features);
    if (mounted)
      setState(
        () => sensorStatus = matches.isEmpty
            ? 'Foto acquisita. Assegna un’etichetta per collegarla a un concetto.'
            : 'Descrittore più simile: ${matches.first['label']} · similarità ${((matches.first['similarity'] as double) * 100).round()}%. '
                  'È un confronto di descrittori, non un riconoscimento semantico verificato.',
      );
  });
  Future<void> _audio() => _run(() async {
    if (!await recorder.hasPermission())
      throw StateError('Permesso microfono non concesso.');
    final bytes = <int>[];
    StreamSubscription<Uint8List>? sub;
    try {
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      sub = stream.listen((chunk) {
        final remaining = 128000 - bytes.length;
        if (remaining > 0) bytes.addAll(chunk.take(remaining));
      });
      if (mounted)
        setState(() => sensorStatus = 'Registrazione per 2 secondi…');
      await Future<void>.delayed(const Duration(seconds: 2));
      await recorder.stop();
      await sub.cancel();
      sub = null;
      sensorFeatures = SensoryFeatures420.audio(
        Uint8List.fromList(bytes),
        sampleRate: 16000,
      );
      sensorModality = 'audio';
      final matches = await memory!.recognize('audio', sensorFeatures!);
      if (mounted)
        setState(
          () => sensorStatus = matches.isEmpty
              ? 'Suono acquisito. Assegna un’etichetta.'
              : 'Descrittore più simile: ${matches.first['label']}. Il suono non è stato trascritto né interpretato come linguaggio.',
        );
    } finally {
      await sub?.cancel();
      try {
        await recorder.stop();
      } catch (_) {}
    }
  });
  Future<void> _bind() => _run(() async {
    if (sensorFeatures == null || label.text.trim().isEmpty) return;
    await memory!.bindSensor(label.text, sensorModality, sensorFeatures!);
    if (mounted)
      setState(
        () => sensorStatus =
            'Esperienza collegata al concetto “${label.text.trim()}”.',
      );
  });
  Future<void> _export() => _run(() async {
    final snapshot = await memory!.export();
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(snapshot)));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Salva memoria',
      fileName: 'MGD-Neural-0.42.0.mgdbrain',
      bytes: bytes,
    );
    if (mounted)
      setState(
        () => status = path == null
            ? 'Esportazione annullata.'
            : 'Snapshot esportato.',
      );
  });
  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ripristinare uno snapshot?'),
        content: const Text(
          'La memoria attuale verrà sostituita solo se il file è valido. Puoi esportarla prima.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Scegli snapshot'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _run(() async {
      final selected = await FilePicker.platform.pickFiles(withData: true);
      if (selected == null) return;
      final item = selected.files.single;
      if (item.size > 50 * 1024 * 1024)
        throw const FormatException('Snapshot oltre il limite di 50 MB.');
      final bytes = item.bytes ?? await File(item.path!).readAsBytes();
      final data = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(bytes)) as Map,
      );
      await memory!.restore(data);
      final old = await memory!.meta('chat_history420');
      if (mounted)
        setState(() {
          history.clear();
          if (old != null)
            history.addAll(
              (jsonDecode(old) as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            );
          scope = null;
          graphPage = 0;
          status = 'Snapshot ripristinato.';
        });
    });
  }

  Future<void> _delete(String source) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questa fonte?'),
        content: const Text(
          'Verranno rimossi passaggi, relazioni e contributi linguistici di questa fonte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted)
      await _run(() async {
        await memory!.deleteSource(source);
      });
  }

  Future<void> _sourceText(Map<String, dynamic> source) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .8,
            child: _SourceText420(memory: memory!, source: source),
          ),
        ),
      );
  Widget _sourceSelector() => DropdownButtonFormField<String>(
    value: scope ?? '',
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Fonte della domanda'),
    items: [
      const DropdownMenuItem(value: '', child: Text('Tutta la memoria')),
      for (final s in sources)
        DropdownMenuItem(
          value: '${s['id']}',
          child: Text('${s['title']}', overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: busy
        ? null
        : (value) => setState(() => scope = value!.isEmpty ? null : value),
  );
  Widget _chatPage() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _sourceSelector(),
      ),
      Expanded(
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final row = history[history.length - 1 - index],
                user = row['user'] == true;
            return Align(
              alignment: user ? Alignment.centerRight : Alignment.centerLeft,
              child: Card(
                color: user
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!user)
                        Text(
                          _statusLabel('${row['status']}'),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      SelectableText('${row['text']}'),
                      if (!user && '${row['reason'] ?? ''}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('${row['reason']}'),
                        ),
                      if (!user && (row['ids'] as List? ?? []).isNotEmpty)
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: busy ? null : () => _evidence(row),
                              child: const Text('Evidenze e correzioni'),
                            ),
                            IconButton(
                              tooltip: 'Favorisci questo recupero',
                              onPressed: busy
                                  ? null
                                  : () => _run(() async {
                                      await memory!.activate(
                                        List<String>.from(row['ids'] as List),
                                        reward: 1,
                                      );
                                      if (mounted)
                                        setState(
                                          () => status =
                                              'Preferenza di recupero aggiornata; nessuna nuova prova aggiunta.',
                                        );
                                    }),
                              icon: const Icon(Icons.thumb_up_outlined),
                            ),
                            IconButton(
                              tooltip: 'Riduci questo recupero',
                              onPressed: busy
                                  ? null
                                  : () => _run(() async {
                                      await memory!.activate(
                                        List<String>.from(row['ids'] as List),
                                        reward: -1,
                                      );
                                      if (mounted)
                                        setState(
                                          () => status =
                                              'Preferenza di recupero ridotta; i fatti non sono stati cancellati.',
                                        );
                                    }),
                              icon: const Icon(Icons.thumb_down_outlined),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('chat420'),
                controller: chat,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Insegna un’esperienza o fai una domanda…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('send420'),
              onPressed: busy || !ready ? null : _send,
              tooltip: 'Invia',
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _learningPage() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Apprendimento verificabile',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const Text(
        'Il testo originale resta disponibile anche quando il lettore non lo interpreta.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: title,
        decoration: const InputDecoration(labelText: 'Nome della fonte'),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('teach420'),
        controller: teaching,
        minLines: 8,
        maxLines: 18,
        decoration: const InputDecoration(
          hintText: 'Incolla il testo da apprendere',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: busy ? null : _teach,
            child: const Text('Apprendi testo'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : _import,
            icon: const Icon(Icons.upload_file),
            label: const Text('Importa TXT'),
          ),
          OutlinedButton(
            onPressed: busy ? () => setState(() => cancelled = true) : null,
            child: const Text('Interrompi lettura'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const Text(
        'Dopo la lettura, torna in Chat e seleziona la fonte. Prova domande nuove, negazioni e correzioni.',
      ),
      const Text(
        'PDF, DOCX ed EPUB richiedono un estrattore dedicato; questo importatore accetta TXT UTF-8, UTF-16 con BOM e Latin-1.',
      ),
    ],
  );
  Widget _sensesPage() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Esperienze sensoriali',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const Text(
        'Collega descrittori visivi e acustici allo stesso concetto usato nei testi.',
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: busy ? null : () => _photo(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Fotocamera'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _photo(ImageSource.gallery),
            icon: const Icon(Icons.photo),
            label: const Text('Galleria'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : _audio,
            icon: const Icon(Icons.mic),
            label: const Text('Ascolta'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(sensorStatus),
      const SizedBox(height: 16),
      TextField(
        controller: label,
        decoration: const InputDecoration(
          labelText: 'Concetto confermato da te',
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: busy || sensorFeatures == null ? null : _bind,
        child: const Text('Collega al concetto'),
      ),
    ],
  );
  Widget _memoryPage() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Memoria comune', style: Theme.of(context).textTheme.headlineSmall),
      Wrap(
        spacing: 8,
        children: [
          for (final e in {
            'Fonti': stats['sources'],
            'Relazioni': stats['claims'],
            'Concetti': stats['concepts'],
            'Passaggi da rivedere': stats['unparsed'],
            'Esperienze sensoriali': stats['sensory'],
          }.entries)
            Chip(label: Text('${e.key}: ${e.value ?? 0}')),
        ],
      ),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: busy ? null : _export,
            child: const Text('Esporta snapshot'),
          ),
          OutlinedButton(
            onPressed: busy ? null : _restore,
            child: const Text('Ripristina snapshot'),
          ),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => _run(() async {
                    await memory!.consolidate();
                    if (mounted)
                      setState(
                        () => status =
                            'Consolidamento locale completato. Nessuna nuova evidenza generata.',
                      );
                  }),
            child: const Text('Consolida'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Text('Fonti', style: Theme.of(context).textTheme.titleLarge),
      for (final s in sources)
        ListTile(
          title: Text('${s['title']}'),
          subtitle: Text(
            '${s['units']} blocchi · ${s['complete'] == 1 ? 'lettura completata' : 'lettura parziale'}',
          ),
          onTap: () => setState(() {
            scope = '${s['id']}';
            tab = 0;
          }),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Leggi testo originale',
                onPressed: busy ? null : () => _sourceText(s),
                icon: const Icon(Icons.menu_book_outlined),
              ),
              IconButton(
                tooltip: 'Elimina fonte',
                onPressed: busy ? null : () => _delete('${s['id']}'),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      const SizedBox(height: 20),
      Text(
        'Relazioni · pagina ${graphPage + 1}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      Row(
        children: [
          TextButton(
            onPressed: busy || graphPage == 0
                ? null
                : () => _run(() async {
                    graphPage--;
                  }),
            child: const Text('Precedente'),
          ),
          TextButton(
            onPressed: busy || graph.length < 100
                ? null
                : () => _run(() async {
                    graphPage++;
                  }),
            child: const Text('Successiva'),
          ),
        ],
      ),
      for (final e in graph)
        ListTile(
          title: Text(_relationLabel(e)),
          onTap: () {
            chat.text = 'Cosa sai di ${e['subject']}?';
            setState(() => tab = 0);
          },
          trailing: IconButton(
            tooltip: 'Correggi relazione',
            onPressed: busy ? null : () => _correct('${e['id']}'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ),
      const SizedBox(height: 20),
      Text(
        'Passaggi da rivedere',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      for (final p in unresolved)
        ExpansionTile(
          key: PageStorageKey('unparsed:${p['id']}'),
          title: Text('${p['title']} · blocco ${p['ordinal']}'),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText('${p['text']}'),
            ),
          ],
        ),
    ],
  );
  Future<void> _lab() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Laboratorio MGD 0.42.0'),
        content: SingleChildScrollView(
          child: Text(
            'Archi attivi: ${stats['activeEdges']}\nArchi consolidati: ${stats['consolidated']}\n'
            'Relazioni revocate: ${stats['revoked']}\nVariazione cumulativa del materiale: ${stats['flux']}\n\n'
            'Questi valori misurano la geometria e l’archivio, non intelligenza, energia o comprensione. '
            'Nessun ciclo gira in background quando non arriva un’esperienza o un comando. '
            'La fluidità di un grande modello linguistico, il ragionamento causale generale e il riassunto gerarchico non sono implementati.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('MGD Neural · 0.42.0'),
      actions: [
        IconButton(
          onPressed: !ready ? null : _lab,
          tooltip: 'Laboratorio',
          icon: const Icon(Icons.science_outlined),
        ),
      ],
    ),
    body: Column(
      children: [
        if (busy || !ready) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            error.isEmpty ? status : '$status\n$error',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (error.isNotEmpty && !ready)
          TextButton(onPressed: _open, child: const Text('Riprova apertura')),
        Expanded(
          child: !ready
              ? const Center(child: Text('Preparazione della memoria…'))
              : switch (tab) {
                  0 => _chatPage(),
                  1 => _learningPage(),
                  2 => _sensesPage(),
                  _ => _memoryPage(),
                },
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.chat_outlined), label: 'Chat'),
        NavigationDestination(
          icon: Icon(Icons.school_outlined),
          label: 'Impara',
        ),
        NavigationDestination(icon: Icon(Icons.sensors), label: 'Sensi'),
        NavigationDestination(icon: Icon(Icons.hub_outlined), label: 'Memoria'),
      ],
    ),
  );
}

String _relationLabel(Map<String, dynamic> e) =>
    '${e['subject']} → ${e['negative'] == 1 ? 'non ' : ''}${e['predicate']} → '
    '${e['object'] ?? ''}${'${e['target'] ?? ''}'.isEmpty ? '' : ' a ${e['target']}'}'
    '${'${e['location'] ?? ''}'.isEmpty ? '' : ' ${e['location']}'}';

class _SourceText420 extends StatefulWidget {
  final CanonicalMemory420 memory;
  final Map<String, dynamic> source;
  const _SourceText420({required this.memory, required this.source});
  @override
  State<_SourceText420> createState() => _SourceText420State();
}

class _SourceText420State extends State<_SourceText420> {
  List<Map<String, dynamic>> rows = [];
  int page = 0;
  bool loading = true;
  String error = '';
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final result = await widget.memory.sourcePassages(
        '${widget.source['id']}',
        offset: page * 32,
      );
      if (mounted) setState(() => rows = result);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '${widget.source['title']}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: loading || page == 0
                ? null
                : () {
                    page--;
                    unawaited(_load());
                  },
            child: const Text('Precedente'),
          ),
          Text('Pagina ${page + 1}'),
          TextButton(
            onPressed: loading || rows.length < 32
                ? null
                : () {
                    page++;
                    unawaited(_load());
                  },
            child: const Text('Successiva'),
          ),
        ],
      ),
      if (loading) const LinearProgressIndicator(),
      if (error.isNotEmpty)
        Padding(padding: const EdgeInsets.all(16), child: Text(error)),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, index) => Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Blocco ${rows[index]['ordinal']}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  SelectableText('${rows[index]['text']}'),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

String _statusLabel(String value) =>
    const {
      'direct': 'Risposta dalle evidenze',
      'deduction': 'Deduzione',
      'conflict': 'Contraddizione',
      'unknown': 'Informazione insufficiente',
      'budget': 'Budget raggiunto',
      'learned': 'Apprendimento',
      'belief': 'Credenza attribuita',
      'summary': 'Ricostruzione',
      'description': 'Relazioni registrate',
      'comparison': 'Confronto dalle evidenze',
      'diagnostic': 'Stato della memoria',
      'dialogue': 'Dialogo',
    }[value] ??
    value;
