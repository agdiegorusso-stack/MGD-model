import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';

import 'experience_memory_v0330.dart';
import 'sensory_world_v06.dart';

typedef LearnRequest33 = ({
  Map<String, dynamic> memory,
  Features33 features,
  String label,
  String context,
  String description,
});
ExperienceMemory33 learnWorker33(LearnRequest33 r) =>
    ExperienceMemory33.fromJson(r.memory)
      ..learn(
        r.features,
        label: r.label,
        context: r.context,
        description: r.description,
      );
typedef PredictRequest33 = ({
  Map<String, dynamic> memory,
  Features33 features,
  String context,
});
({Prediction33 prediction, int micros, int coordinates}) predictWorker33(
  PredictRequest33 r,
) {
  final m = ExperienceMemory33.fromJson(r.memory);
  final p = m.predict(r.features, context: r.context);
  return (
    prediction: p,
    micros: m.lastPredictMicros,
    coordinates: m.coordinatesVisited,
  );
}

typedef DeleteRequest33 = ({
  Map<String, dynamic> memory,
  int? id,
  String? label,
  String? context,
});
ExperienceMemory33 deleteWorker33(DeleteRequest33 r) {
  final m = ExperienceMemory33.fromJson(r.memory);
  if (r.id != null) {
    m.deleteWhere((e) => e.id == r.id);
  } else if (r.label != null) {
    m.deleteConcept(r.label!, context: r.context);
  }
  return m;
}

Map<String, double> imageWorker33(Uint8List bytes) =>
    MgdWorld06.encodeVision33(bytes);
Map<String, double> audioWorker33(Uint8List bytes) =>
    MgdWorld06.encodeAudio33(bytes);

class ExperiencePage33 extends StatefulWidget {
  final MgdWorld06 world;
  final Future<void> Function() onSave;
  const ExperiencePage33({
    super.key,
    required this.world,
    required this.onSave,
  });
  @override
  State<ExperiencePage33> createState() => _ExperiencePage33State();
}

class _ExperiencePage33State extends State<ExperiencePage33>
    with WidgetsBindingObserver {
  final _text = TextEditingController(), _label = TextEditingController();
  final _context = TextEditingController(text: 'generale');
  final _filter = TextEditingController();
  AudioRecorder? _recorder;
  final _picker = ImagePicker();
  Map<String, double>? _vision, _audio;
  Uint8List? _preview;
  Prediction33? _prediction;
  bool _busy = false, _recording = false, _interrupted = false;
  String _status =
      'Aggiungi gli stimoli dello stesso episodio, poi chiedi una previsione o insegna un nome.';
  ExperienceMemory33 get memory => widget.world.experience33;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_recording && state != AppLifecycleState.resumed) {
      _interrupted = true;
      unawaited(_recorder?.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    _label.dispose();
    _context.dispose();
    _filter.dispose();
    unawaited(_recorder?.dispose());
    super.dispose();
  }

  Features33 _input() => {
        if (_text.text.trim().isNotEmpty)
          'text:v1': ExperienceMemory33.textFeatures(_text.text),
        if (_vision != null) 'vision:v1': _vision!,
        if (_audio != null) 'audio:v1': _audio!,
      };
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _status = 'Operazione non completata: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _image(ImageSource source) => _run(() async {
        final file = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
          requestFullMetadata: false,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        final features = await compute(imageWorker33, bytes);
        if (mounted)
          setState(() {
            _preview = bytes;
            _vision = features;
            _prediction = null;
            _status =
                'Immagine pronta. Aggiungi testo o audio solo se appartengono allo stesso episodio.';
          });
      });
  Future<void> _listen() => _run(() async {
        final recorder = _recorder ??= AudioRecorder();
        if (!await recorder.hasPermission())
          throw StateError('Permesso microfono non concesso.');
        final data = BytesBuilder(copy: false);
        StreamSubscription<Uint8List>? sub;
        _interrupted = false;
        _recording = true;
        try {
          final stream = await recorder.startStream(
            const RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 16000,
              numChannels: 1,
            ),
          );
          sub = stream.listen((bytes) {
            if (data.length < 96000) data.add(bytes);
          });
          if (mounted)
            setState(() => _status = 'Registrazione di 2 secondi in corso…');
          await Future<void>.delayed(const Duration(seconds: 2));
          await recorder.stop();
          await sub.cancel();
          sub = null;
          if (_interrupted)
            throw StateError(
              'Registrazione interrotta: riprova con l’app in primo piano.',
            );
          final features = await compute(audioWorker33, data.takeBytes());
          if (mounted)
            setState(() {
              _audio = features;
              _prediction = null;
              _status =
                  'Audio pronto. Il descrittore acustico non trascrive le parole.';
            });
        } finally {
          _recording = false;
          await sub?.cancel();
          await recorder.stop();
        }
      });
  Future<void> _predict() => _run(() async {
        final result = await compute(predictWorker33, (
          memory: memory.toJson(),
          features: _input(),
          context: _context.text,
        ));
        if (mounted)
          setState(() {
            _prediction = result.prediction;
            memory.lastPredictMicros = result.micros;
            memory.coordinatesVisited = result.coordinates;
            _status = result.prediction.reason;
          });
      });
  Future<void> _teach() => _run(() async {
        final next = await compute(learnWorker33, (
          memory: memory.toJson(),
          features: _input(),
          label: _label.text,
          context: _context.text,
          description: _text.text.trim(),
        ));
        if (!mounted) return;
        widget.world.experience33 = next;
        widget.world.step++; // invalidates any earlier runtime worker
        await widget.onSave();
        if (mounted)
          setState(() {
            _prediction = null;
            _status =
                'Esperienza confermata e salvata: ${_label.text.trim()}. È ora cercabile nella mappa.';
          });
      });
  Future<void> _delete({int? id, String? label, String? context}) async {
    final yes = await showDialog<bool>(
      context: this.context,
      builder: (c) => AlertDialog(
        title: Text(
          id != null ? 'Eliminare questa esperienza?' : 'Eliminare “$label”?',
        ),
        content: const Text(
          'Rimuove gli episodi selezionati e ricostruisce la metrica dai rimanenti. Le misure di previsione ripartono da zero. Le altre memorie dell’app si gestiscono dalla mappa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _run(() async {
      final next = await compute(deleteWorker33, (
        memory: memory.toJson(),
        id: id,
        label: label,
        context: context,
      ));
      widget.world.experience33 = next;
      widget.world.step++;
      await widget.onSave();
      if (mounted)
        setState(() {
          _prediction = null;
          _status =
              'Eliminazione salvata. Metrica ricostruita dagli episodi rimasti.';
        });
    });
  }

  Future<void> _export() => _run(() async {
        final bytes = Uint8List.fromList(
          utf8.encode(
              const JsonEncoder.withIndent('  ').convert(memory.toJson())),
        );
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Esporta esperienze',
          fileName: 'MGD-esperienze.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: bytes,
        );
        if (mounted)
          setState(
            () => _status = path == null
                ? 'Esportazione annullata.'
                : 'Esperienze esportate.',
          );
      });

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Experience33>>{};
    for (final e in memory.episodes) {
      final key = '${e.label} · ${e.context}';
      if (!canonical33(key).contains(canonical33(_filter.text))) continue;
      groups.putIfAbsent(key, () => []).add(e);
    }
    final m = memory.metrics;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Impara dall’esperienza'),
          actions: [
            IconButton(
              tooltip: 'Esporta episodi',
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.download_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Testo, immagine e audio possono descrivere insieme una sola esperienza. Il nome da imparare si inserisce separatamente.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('experience-context'),
                controller: _context,
                enabled: !_busy,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Contesto / domanda',
                  helperText:
                      'Esempi: colore, forma, oggetto, suono. Distingue compiti diversi.',
                ),
              ),
              TextField(
                key: const ValueKey('experience-input'),
                controller: _text,
                enabled: !_busy,
                maxLines: 3,
                maxLength: 8000,
                decoration: const InputDecoration(
                  labelText: 'Stimolo testuale (facoltativo)',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _image(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Fotocamera'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _image(ImageSource.gallery),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Immagine'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _listen,
                    icon: const Icon(Icons.mic_none),
                    label: const Text('Audio · 2 s'),
                  ),
                ],
              ),
              if (_preview != null)
                Image.memory(_preview!, height: 140, fit: BoxFit.contain),
              Wrap(
                spacing: 8,
                children: [
                  if (_vision != null)
                    InputChip(
                      label: const Text('Immagine presente'),
                      onDeleted: _busy
                          ? null
                          : () {
                              setState(() {
                                _vision = null;
                                _preview = null;
                                _prediction = null;
                              });
                            },
                    ),
                  if (_audio != null)
                    InputChip(
                      label: const Text('Audio presente'),
                      onDeleted: _busy
                          ? null
                          : () {
                              setState(() {
                                _audio = null;
                                _prediction = null;
                              });
                            },
                    ),
                ],
              ),
              FilledButton.tonalIcon(
                key: const ValueKey('experience-predict'),
                onPressed: _busy ? null : _predict,
                icon: const Icon(Icons.psychology_outlined),
                label: const Text('Prevedi usando gli stimoli'),
              ),
              if (_prediction != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _prediction!.accepted
                              ? 'Candidato: ${_prediction!.best}'
                              : 'Non abbastanza sicuro',
                        ),
                        Text(_prediction!.reason),
                        const Text(
                          'Punteggi di confronto, non probabilità di verità.',
                        ),
                        ..._prediction!.probabilities.entries.map(
                          (e) => Text(
                            '${e.key}: ${(100 * e.value).toStringAsFixed(1)}%',
                          ),
                        ),
                        ..._prediction!.channels.entries.map(
                          (e) => Text(
                            '${e.key.split(':').first}: ${e.value.entries.map((v) => '${v.key} ${(100 * v.value).round()}%').join(' · ')}',
                          ),
                        ),
                        Text(
                          'Episodi di supporto: ${_prediction!.evidenceIds.join(', ')}',
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('experience-label'),
                controller: _label,
                enabled: !_busy,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Nome / risposta da insegnare',
                  helperText:
                      'La tua conferma è un dato separato dallo stimolo.',
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('experience-teach'),
                onPressed: _busy ? null : _teach,
                icon: const Icon(Icons.school_outlined),
                label: const Text('Conferma e impara'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _text.clear();
                          _label.clear();
                          _vision = null;
                          _audio = null;
                          _preview = null;
                          _prediction = null;
                          _status = 'Nuova esperienza pronta.';
                        }),
                child: const Text('Nuova esperienza'),
              ),
              if (_busy) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_status, key: const ValueKey('experience-status')),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: widget.world.eventDriven33,
                title: const Text('Apprendimento su evento'),
                subtitle: const Text(
                  'Disattiva ripassi e ricerche avviati dal timer. Restano disponibili i comandi manuali. Il consumo in joule non è ancora misurato.',
                ),
                onChanged: _busy
                    ? null
                    : (v) => _run(() async {
                          widget.world.eventDriven33 = v;
                          await widget.onSave();
                        }),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${m['episodes']} episodi · ${m['concepts']} categorie · limite ${m['capacity']}',
                      ),
                      Text(
                        'Previsioni prima della conferma: ${m['correctBeforeLearning']}/${m['evaluatedBeforeLearning']} corrette; ${m['coldStarts']} senza esempi confrontabili.',
                      ),
                      Text(
                        'Risposte accettate: ${m['answeredCorrect']}/${m['answered']} corrette. Gli altri casi richiedono conferma.',
                      ),
                      Text(
                        'Metrica: ${m['acceptedMetricUpdates']} aggiornamenti accettati, ${m['rejectedMetricUpdates']} bloccati dal controllo su esempi precedenti.',
                      ),
                      Text(
                        'Ultima previsione: ${(memory.lastPredictMicros / 1000).toStringAsFixed(2)} ms; ultimo apprendimento: ${(memory.lastLearnMicros / 1000).toStringAsFixed(2)} ms.',
                      ),
                      if (memory.evaluationReset)
                        const Text(
                          'Misure di previsione azzerate dopo una cancellazione.',
                        ),
                      const Text(
                        'Nessun episodio viene scartato automaticamente. Il richiamo esatto è protetto; la generalizzazione su nuovi stimoli può ancora peggiorare.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Categorie ed episodi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextField(
                controller: _filter,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Cerca una categoria',
                ),
              ),
              if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nessuna categoria in questa vista.'),
                ),
              ...groups.entries.map(
                (g) => Card(
                  child: ExpansionTile(
                    key: PageStorageKey('experience330:${g.key}'),
                    title: Text(g.key),
                    subtitle: Text('${g.value.length} episodi confermati'),
                    trailing: IconButton(
                      tooltip: 'Elimina categoria',
                      onPressed: _busy
                          ? null
                          : () => _delete(
                                label: g.value.first.label,
                                context: g.value.first.context,
                              ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                    children: g.value
                        .map(
                          (e) => ListTile(
                            title: Text(
                              e.features.keys
                                  .map((m) => m.split(':').first)
                                  .join(' + '),
                            ),
                            subtitle: Text(
                              '${e.description.isEmpty ? 'Stimolo sensoriale' : e.description}\n${e.source} · ${e.at}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Elimina esperienza',
                              onPressed: _busy ? null : () => _delete(id: e.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Versione sperimentale locale: il testo usa parole e coppie ordinate; la visione descrittori di colore e struttura; l’audio descrittori acustici. Non include riconoscimento vocale né un modello generale di comprensione delle immagini.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
