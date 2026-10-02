import 'story_graph_v0350.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'closed_book_store_v0350.dart';
import 'closed_book_service_v0350.dart';
import 'book_import_v0341.dart';
import 'book_lab_service_v0342.dart';
import 'book_understanding_v0342.dart';
import 'narrative_memory_v0350.dart';
import 'web_knowledge_explorer_v11.dart';

class ClosedBookPage350 extends StatefulWidget {
  final ClosedBookStore350? store;
  final ResearchMemory11? legacyMemory;
  final Widget Function()? legacyBuilder;
  const ClosedBookPage350(
      {super.key, this.store, this.legacyMemory, this.legacyBuilder});
  @override
  State<ClosedBookPage350> createState() => _ClosedBookPage350State();
}

class _ClosedBookPage350State extends State<ClosedBookPage350> {
  ClosedBookStore350? store;
  ClosedRecallWorker350? worker;
  final text = TextEditingController(),
      title = TextEditingController(text: 'Lettura personale'),
      question = TextEditingController(),
      hypothesis = TextEditingController(),
      word = TextEditingController(),
      phraseA = TextEditingController(),
      phraseB = TextEditingController(),
      subject = TextEditingController(),
      verb = TextEditingController(),
      object = TextEditingController();
  List<Map<String, dynamic>> books = [], events = [], exam = [];
  Map<String, dynamic>? meta, answer, languageResult, report;
  String? selected;
  String status = 'Apertura della memoria…', summary = '';
  bool busy = true, cancel = false, cancellable = false;
  int generation = 0, page = 0, examPage = 0, resultPage = 0;
  bool allBooksLanguage = true;
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, _boot);
  }

  @override
  void dispose() {
    cancel = true;
    generation++;
    worker?.close();
    for (final c in [
      text,
      title,
      question,
      hypothesis,
      word,
      phraseA,
      phraseB,
      subject,
      verb,
      object
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void say(String s) {
    if (mounted) setState(() => status = s);
  }

  Future<void> _boot() async {
    try {
      store = widget.store ?? await ClosedBookStore350.shared;
      if (widget.store == null) ClosedBookBridge350.enabled = true;
      await _reload();
    } catch (e) {
      say('Memoria non aperta: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reload([String? id]) async {
    books = await store!.books();
    selected = id ?? await store!.active();
    if (selected != null && !books.any((b) => b['id'] == selected))
      selected = null;
    selected ??= books.isEmpty ? null : books.first['id'] as String;
    if (selected != null) {
      await _select(selected!);
    } else {
      meta = null;
      events = [];
      worker?.close();
      worker = null;
      say('Pronto. Leggi un TXT o incolla un testo: vengono conservati eventi e statistiche, non le pagine.');
    }
  }

  Future<void> _select(String id) async {
    final epoch = ++generation;
    worker?.close();
    worker = null;
    if (mounted)
      setState(() {
        busy = true;
        selected = id;
        answer = null;
        summary = '';
        page = 0;
        examPage = 0;
        resultPage = 0;
      });
    try {
      final snapshot = await store!.snapshot(id),
          w = await ClosedRecallWorker350.open(snapshot);
      if (!mounted || epoch != generation) {
        w.close();
        return;
      }
      worker = w;
      meta = Map<String, dynamic>.from(snapshot['metadata'] as Map);
      events = await store!.eventPage(id);
      exam = await store!.cases(id);
      final history = await store!.reports(id);
      report = history.isEmpty ? null : history.first;
      await store!.setActive(id);
      ClosedBookBridge350.close();
      say('Pronto a libro chiuso. Il motore riceve eventi strutturati, non il testo originale.');
    } catch (e) {
      say('Selezione non completata: $e');
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  Future<void> _operation(Future<void> Function() action,
      {bool canCancel = false}) async {
    if (busy || store == null) return;
    cancel = false;
    setState(() {
      busy = true;
      cancellable = canCancel;
    });
    try {
      await action();
    } catch (e, st) {
      say('Operazione interrotta: $e. I blocchi già salvati restano disponibili.');
      try {
        final dir = await getApplicationDocumentsDirectory();
        await File('${dir.path}/closed-book-last-error.txt')
            .writeAsString('$e\n$st');
      } catch (_) {}
    } finally {
      if (mounted)
        setState(() {
          busy = false;
          cancellable = false;
        });
    }
  }

  Future<void> _readFile(File file, String name) async {
    final result = await store!.importFile(file,
        title: name,
        cancelled: () => cancel || !mounted,
        progress: (m) => say(
            'Lettura: ${m['units']} blocchi; ${m['sentences']} unità; ${m['events']} eventi. Salvataggio incrementale.'));
    if (!mounted) return;
    await _reload(result['id'] as String);
    if (result['complete'] == 1) text.clear();
    say(result['skippedComplete'] == true
        ? 'Libro già consolidato: nessuna duplicazione.'
        : '${result['cancelled'] == true ? 'Lettura interrotta e conservata' : 'Lettura consolidata'}: ${result['events']} eventi, ${result['unparsed']} unità non risolte. Testo integrale non archiviato.');
  }

  Future<void> _paste() async => _operation(() async {
        if (text.text.trim().isEmpty) return;
        final dir = await getTemporaryDirectory(),
            file = File(
                '${dir.path}/mgd-closed-${DateTime.now().microsecondsSinceEpoch}.txt');
        try {
          await file.writeAsString(text.text);
          await _readFile(
              file,
              title.text.trim().isEmpty
                  ? 'Testo personale.txt'
                  : '${title.text.trim()}.txt');
        } finally {
          if (await file.exists()) await file.delete();
        }
      }, canCancel: true);
  Future<void> _pick() async => _operation(() async {
        final picked = await FilePicker.platform.pickFiles(
            withReadStream: true, withData: false, type: FileType.any);
        if (picked == null || picked.files.isEmpty) return;
        final f = picked.files.single;
        BookText341.validateName(f.name);
        final stream =
            f.readStream ?? (f.path == null ? null : File(f.path!).openRead());
        if (stream == null)
          throw StateError('Il provider non offre un flusso leggibile.');
        final dir = await getTemporaryDirectory(),
            file = File(
                '${dir.path}/mgd-closed-${DateTime.now().microsecondsSinceEpoch}.txt');
        try {
          await BookText341.stage(stream, file,
              name: f.name, cancelled: () => cancel || !mounted);
          if (!cancel && mounted) await _readFile(file, f.name);
        } finally {
          if (await file.exists()) await file.delete();
        }
      }, canCancel: true);
  Future<void> _migrate() async => _operation(() async {
        if (widget.legacyMemory == null) return;
        final rows = BookLab342.rows(widget.legacyMemory!),
            scopes = BookLab342.scopes(rows);
        if (!mounted) return;
        final picked = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (c) => SimpleDialog(
                title: const Text('Consolida un archivio precedente'),
                children: scopes.isEmpty
                    ? [
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Nessun passaggio disponibile.'))
                      ]
                    : scopes
                        .map((s) => SimpleDialogOption(
                            onPressed: () => Navigator.pop(c, s),
                            child:
                                Text('${s['title']} · ${s['count']} passaggi')))
                        .toList()));
        if (picked == null) return;
        final selectedRows =
            rows.where((r) => bookScope342(r) == picked['key']).toList();
        final result = await store!.consolidateRows(selectedRows,
            title: '${picked['title']}',
            identity: '${picked['key']}',
            cancelled: () => cancel || !mounted,
            progress: (m) => say(
                'Consolidamento precedente: ${m['units']} passaggi, ${m['events']} eventi.'));
        if (mounted) {
          await _reload(result['id'] as String);
          say('Memoria strutturata creata. Il vecchio archivio resta intatto; l’ordine dei passaggi precedenti non garantisce la cronologia originale.');
        }
      }, canCancel: true);
  Future<void> _ask() async => _operation(() async {
        if (worker == null || question.text.trim().isEmpty) return;
        FocusManager.instance.primaryFocus?.unfocus();
        final r = await worker!.call(
            'ask', {'question': question.text, 'assumptions': hypothesis.text});
        if (mounted) setState(() => answer = r);
        say('Risposta da eventi e regole conservati. Le ipotesi e la domanda non vengono apprese.');
      });
  Future<void> _runExam() async => _operation(() async {
        if (worker == null || selected == null || exam.isEmpty) return;
        final r = await ClosedBookExam350.run(worker!, exam,
            metadata: meta ?? {},
            cancelled: () => cancel || !mounted,
            progress: (a, b) => say('Esame a libro chiuso: $a / $b.'));
        final empty =
            await ClosedRecallWorker350.open({'metadata': {}, 'events': []});
        try {
          r['emptyControl'] = await ClosedBookExam350.run(empty, exam,
              cancelled: () => cancel || !mounted);
        } finally {
          empty.close();
        }
        await store!.saveReport(selected!, r);
        if (mounted) setState(() => report = r);
        say('Esame conservato. Risposte esatte, errori e astensioni sono separati.');
      }, canCancel: true);
  Future<void> _addQuestion() async {
    final q = TextEditingController(),
        a = TextEditingController(),
        h = TextEditingController();
    String expected = 'answer';
    final added = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, update) => AlertDialog(
                    title: const Text('Domanda di verifica'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: q,
                          decoration:
                              const InputDecoration(labelText: 'Domanda')),
                      DropdownButton<String>(
                          value: expected,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'answer',
                                child: Text('Risposta determinabile')),
                            DropdownMenuItem(
                                value: 'unknown',
                                child: Text('Non determinabile')),
                            DropdownMenuItem(
                                value: 'conflict',
                                child: Text('Contraddizione'))
                          ],
                          onChanged: (v) => update(() => expected = v!)),
                      TextField(
                          controller: a,
                          decoration: const InputDecoration(
                              labelText:
                                  'Risposta corretta (alternative con |)')),
                      TextField(
                          controller: h,
                          decoration: const InputDecoration(
                              labelText: 'Ipotesi nuova, facoltativa')),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Annulla')),
                      FilledButton(
                          onPressed: () {
                            if (q.text.trim().isEmpty ||
                                (expected == 'answer' && a.text.trim().isEmpty))
                              return;
                            Navigator.pop(c, {
                              'id':
                                  'manual-${DateTime.now().microsecondsSinceEpoch}',
                              'question': q.text.trim(),
                              'expected': expected,
                              'answers': a.text
                                  .split('|')
                                  .map((x) => x.trim())
                                  .where((x) => x.isNotEmpty)
                                  .toList(),
                              'assumptions': h.text.trim(),
                              'origin': 'user_reference',
                              'category': 'manuale'
                            });
                          },
                          child: const Text('Aggiungi'))
                    ])));
    // Controllers are disposed after the dialog transition has finished.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    q.dispose();
    a.dispose();
    h.dispose();
    if (added != null && mounted && selected != null) {
      exam = BookExam342.validate([...exam, added]);
      await store!.setCases(selected!, exam);
      if (mounted) setState(() {});
    }
  }

  Future<void> _importExam() async => _operation(() async {
        final p = await FilePicker.platform.pickFiles(
            type: FileType.any, withReadStream: true, withData: false);
        if (p == null || selected == null) return;
        final f = p.files.single,
            stream = f.readStream ??
                (f.path == null ? null : File(f.path!).openRead());
        if (stream == null) throw StateError('File non leggibile.');
        final buffer = BytesBuilder();
        await for (final part in stream) {
          if (buffer.length + part.length > 2 * 1024 * 1024)
            throw const FormatException(
                'Esame oltre 2 MiB: dividilo in più prove.');
          buffer.add(part);
        }
        exam =
            BookExam342.validate(jsonDecode(utf8.decode(buffer.takeBytes())));
        await store!.setCases(selected!, exam);
        say('Riferimenti importati soltanto nell’esame.');
      });
  Future<void> _export() async => _operation(() async {
        if (selected == null) return;
        final data = await ClosedBookBridge350.export(store!, selected!);
        final path = await FilePicker.platform.saveFile(
            fileName: 'MGD-memoria-0350.json',
            bytes: Uint8List.fromList(utf8.encode(data)),
            type: FileType.any);
        say(path == null
            ? 'Esportazione annullata.'
            : 'Memoria e verifiche esportate, senza testo integrale.');
      });
  Future<void> _forget() async {
    if (busy || selected == null) return;
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Eliminare questa lettura?'),
                content: const Text(
                    'Vengono rimossi eventi, contributi linguistici ed esami di questo libro. Gli altri libri, il file originale e gli archivi precedenti non vengono cancellati.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Annulla')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Elimina lettura'))
                ]));
    if (ok == true)
      await _operation(() async {
        ClosedBookBridge350.close();
        worker?.close();
        worker = null;
        await store!.forgetBook(selected!);
        selected = null;
        await _reload();
      });
  }

  Widget _list(String id, List<Widget> children) => ListView(
      key: PageStorageKey('closed-scroll-$id'),
      padding: const EdgeInsets.all(16),
      children: children
          .map((w) =>
              Padding(padding: const EdgeInsets.only(bottom: 14), child: w))
          .toList());
  Widget _box(String heading, Widget body) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(heading, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            body
          ])));
  Widget _read() => _list('read', [
        const Text('Leggere deve cambiare ciò che sa fare',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
        const Text(
            'Questo percorso conserva statistiche linguistiche, relazioni ed eventi. Il TXT è letto a blocchi e la copia temporanea viene rimossa. Le parti non interpretate sono conteggiate, non inventate.'),
        FilledButton.icon(
            key: const ValueKey('closed-import-file'),
            onPressed: busy ? null : _pick,
            icon: const Icon(Icons.auto_stories),
            label: const Text('Leggi e apprendi un libro TXT')),
        TextField(
            controller: title,
            decoration: const InputDecoration(
                labelText: 'Titolo della lettura',
                border: OutlineInputBorder())),
        TextField(
            key: const ValueKey('closed-input'),
            controller: text,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
                labelText: 'Testo da apprendere',
                border: OutlineInputBorder())),
        FilledButton.tonalIcon(
            key: const ValueKey('closed-learn'),
            onPressed: busy ? null : _paste,
            icon: const Icon(Icons.psychology),
            label: const Text('Apprendi senza archiviare il testo')),
        if (widget.legacyMemory != null)
          OutlinedButton.icon(
              onPressed: busy ? null : _migrate,
              icon: const Icon(Icons.history),
              label: const Text('Consolida un libro già importato')),
        if (meta != null)
          _box(
              'Che cosa è cambiato',
              Text(
                  '${meta!['sentences']} unità lette\n${meta!['recognized']} interpretate · ${meta!['unparsed']} non risolte\n${meta!['events']} eventi / relazioni\n${meta!['complete'] == 1 ? 'Lettura completata' : 'Lettura parziale: riseleziona il TXT per riprendere'}\n\nQuesti numeri non misurano la comprensione generale.')),
        const Text(
            'TXT UTF-8, UTF-16 con BOM o Latin-1. PDF ed EPUB non sono ancora estratti da questo percorso.'),
      ]);
  Widget _recall() => _list('recall', [
        const Text('Interroga a libro chiuso',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
        const Text(
            'Il motore riceve soltanto la memoria strutturata. Nella chat principale puoi usare “Libro: …” o “Memoria: …”.'),
        TextField(
            key: const ValueKey('closed-question'),
            controller: question,
            decoration: const InputDecoration(
                labelText: 'Domanda',
                hintText: 'Dove si trova la chiave?',
                border: OutlineInputBorder())),
        TextField(
            controller: hypothesis,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
                labelText: 'Nuova situazione, facoltativa',
                hintText: 'Zeta è un neride.',
                border: OutlineInputBorder())),
        FilledButton(
            key: const ValueKey('closed-ask'),
            onPressed: busy || worker == null ? null : _ask,
            child: const Text('Rispondi dalla memoria')),
        if (answer != null)
          _box(
              '${answer!['status']} · testo originale consultato: ${answer!['rawPassagesRead'] ?? 0}',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SelectableText('${answer!['answer']}',
                    key: const ValueKey('closed-answer'),
                    style: const TextStyle(fontSize: 21)),
                const SizedBox(height: 12),
                Text('${answer!['reason']}'),
                for (final e in (answer!['evidence'] as List? ?? []).take(20))
                  ExpansionTile(
                      title:
                          Text('${e['subject'] ?? e['title'] ?? 'Premessa'}'),
                      children: [
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(e['predicate'] == null
                                ? '${e['text']}'
                                : Event350.fromJson(e as Map).describe()))
                      ]),
              ])),
      ]);
  Widget _italian() => _list('italian', [
        const Text('Usi, costruzioni e nuove combinazioni',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
        const Text(
            'Il lessico parte dalle tue letture. Le statistiche si sommano fra libri; il riconoscimento dei ruoli utilizza ancora un lettore iniziale a regole. Non è ancora italiano generale fluente.'),
        SwitchListTile(
            title: const Text('Usa l’apprendimento di tutti i libri'),
            value: allBooksLanguage,
            onChanged:
                busy ? null : (v) => setState(() => allBooksLanguage = v)),
        TextField(
            controller: word,
            decoration: const InputDecoration(
                labelText: 'Parola da esplorare',
                border: OutlineInputBorder())),
        OutlinedButton(
            onPressed: busy
                ? null
                : () => _operation(() async {
                      languageResult = await store!.word(word.text,
                          bookId: allBooksLanguage ? null : selected);
                      if (mounted) setState(() {});
                    }),
            child: const Text('Mostra usi e associazioni')),
        _box(
            'Quale frase è più sostenuta dall’esperienza?',
            Column(children: [
              TextField(
                  controller: phraseA,
                  decoration: const InputDecoration(labelText: 'Frase A')),
              TextField(
                  controller: phraseB,
                  decoration: const InputDecoration(labelText: 'Frase B')),
              TextButton(
                  key: const ValueKey('closed-grammar'),
                  onPressed: busy
                      ? null
                      : () => _operation(() async {
                            languageResult = await store!.compare(
                                [phraseA.text, phraseB.text],
                                bookId: allBooksLanguage ? null : selected);
                            if (mounted) setState(() {});
                          }),
                  child: const Text('Confronta con l’uso appreso')),
            ])),
        _box(
            'Usa una costruzione in una frase nuova',
            Column(children: [
              TextField(
                  controller: subject,
                  decoration: const InputDecoration(
                      labelText: 'Soggetto, con articolo se serve')),
              TextField(
                  controller: verb,
                  decoration: const InputDecoration(
                      labelText: 'Forma verbale osservata')),
              TextField(
                  controller: object,
                  decoration: const InputDecoration(
                      labelText: 'Oggetto, con articolo se serve')),
              TextButton(
                  onPressed: busy
                      ? null
                      : () => _operation(() async {
                            languageResult = await store!.compose(
                                subject.text, verb.text, object.text,
                                bookId: allBooksLanguage ? null : selected);
                            if (mounted) setState(() {});
                          }),
                  child: const Text('Componi senza salvare un nuovo fatto')),
            ])),
        if (languageResult != null)
          _box('Risultato linguistico', _languageView(languageResult!)),
      ]);
  Widget _languageView(Map<String, dynamic> r) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (r['word'] != null)
          Text('${r['word']} · ${r['observations']} osservazioni',
              style: const TextStyle(fontSize: 20)),
        if (r['best'] != null)
          Text('Preferenza: ${r['best']}',
              style: const TextStyle(fontSize: 20)),
        if (r['sentence'] != null)
          SelectableText('${r['sentence']}',
              style: const TextStyle(fontSize: 20)),
        if (r['status'] == 'undetermined')
          const Text('Dati insufficienti per distinguere le frasi.'),
        for (final a in r['associations'] as List? ?? [])
          Text('${a['word']} · ${a['observations']} co-occorrenze'),
        for (final a in r['senses'] as List? ?? [])
          Text('Uso contestuale: ${a['frame']} · ${a['count']}'),
        for (final a in r['usages'] as List? ?? [])
          Text('${a['frame']} · ${a['count']} osservazioni'),
        for (final a in r['ranking'] as List? ?? [])
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                  '${a['sentence']}\nPunteggio: ${(a['score'] as num).toStringAsFixed(3)}\n${(a['reasons'] as List).join('\n')}')),
        if (r['note'] != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('${r['note']}')),
      ]);
  Widget _story() => _list('story', [
        const Text('La rappresentazione della storia',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
        const Text(
            'Entità, ruoli ed eventi nell’ordine in cui sono stati riconosciuti. Collegamenti causali solo quando espliciti. Tocca un evento per controllare i suoi ruoli.'),
        OutlinedButton.icon(
            onPressed: busy || worker == null
                ? null
                : () => _operation(() async {
                      summary = '${(await worker!.call('summary'))['text']}';
                      if (mounted) setState(() {});
                    }),
            icon: const Icon(Icons.subject),
            label: const Text('Ricostruisci il riassunto')),
        if (summary.isNotEmpty)
          _box('Sintesi della memoria', SelectableText(summary)),
        if (events.isNotEmpty)
          StoryGraph350(
              events: events,
              onEvent: (e) => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (c) => SafeArea(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(Event350.fromJson(e).describe(),
                                    style: Theme.of(c).textTheme.titleLarge),
                                const SizedBox(height: 12),
                                Text(
                                    'Agente: ${e['subject']}\nRelazione: ${e['predicate']}\nOggetto: ${e['object']}\nDestinatario: ${e['target']}\nLuogo: ${e['location']}\nOrigine: ${e['resolution']}'),
                              ])))),
              onEntity: (name) {
                if (!busy && worker != null)
                  _operation(() async {
                    summary = '${(await worker!.call('summary', {
                          'entity': name
                        }))['text']}';
                    if (mounted) setState(() {});
                  });
              }),
        if (events.isNotEmpty)
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: events
                  .expand((e) => [e['subject'], e['object']])
                  .whereType<String>()
                  .where((s) => s.isNotEmpty && !s.contains(':'))
                  .toSet()
                  .take(30)
                  .map((name) => ActionChip(
                      label: Text(name),
                      onPressed: busy || worker == null
                          ? null
                          : () => _operation(() async {
                                summary = '${(await worker!.call('summary', {
                                      'entity': name
                                    }))['text']}';
                                if (mounted) setState(() {});
                              })))
                  .toList()),
        for (final e in events)
          _box(
              'Evento ${(e['ordinal'] as int) + 1}',
              ExpansionTile(
                  key: PageStorageKey('narrative350:$selected:${e['id']}'),
                  title: Text(Event350.fromJson(e).describe()),
                  subtitle: Text('${e['chapter']} · ${e['resolution']}'),
                  children: [
                    ListTile(
                        title: Text('Agente: ${e['subject']}'),
                        subtitle: Text(
                            'Azione / relazione: ${e['predicate']}\nOggetto: ${e['object']}\nDestinatario: ${e['target']}\nLuogo: ${e['location']}\nNegazione: ${e['negative'] == true ? 'sì' : 'no'}')),
                    if (e['kind'] != 'cause')
                      TextButton.icon(
                          onPressed: busy ? null : () => _correctEvent(e),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Correggi il ricordo')),
                  ])),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(
              onPressed: busy || page == 0 ? null : () => _eventPage(page - 1),
              child: const Text('Precedenti')),
          Text('Pagina ${page + 1}'),
          TextButton(
              onPressed: busy || events.length < 100
                  ? null
                  : () => _eventPage(page + 1),
              child: const Text('Successivi')),
        ]),
      ]);
  Future<void> _correctEvent(Map<String, dynamic> e) async {
    if (busy || selected == null) return;
    final controllers = {
      for (final key in ['subject', 'object', 'target', 'location'])
        key: TextEditingController(text: '${e[key] ?? ''}')
    };
    bool negative = e['negative'] == true;
    final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, update) => AlertDialog(
                    title: const Text('Correggi il ricordo'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          'Relazione: ${e['surface']}. La correzione sostituisce i ruoli riconosciuti e aggiorna i loro contributi linguistici.'),
                      for (final field in <String, String>{
                        'subject': 'Agente / soggetto',
                        'object': 'Oggetto',
                        'target': 'Destinatario',
                        'location': 'Luogo'
                      }.entries)
                        TextField(
                            key: ValueKey('correct350-${field.key}'),
                            controller: controllers[field.key],
                            decoration:
                                InputDecoration(labelText: field.value)),
                      CheckboxListTile(
                          value: negative,
                          onChanged: (v) => update(() => negative = v ?? false),
                          title: const Text('Affermazione negata')),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Annulla')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, {
                                for (final entry in controllers.entries)
                                  entry.key: entry.value.text,
                                'negative': negative
                              }),
                          child: const Text('Salva correzione'))
                    ])));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in controllers.values) c.dispose();
    if (data == null || !mounted || selected == null) return;
    await _operation(() async {
      await store!.correctEvent(selected!, '${e['id']}', data);
      ClosedBookBridge350.close();
      await _reload(selected);
      say('Ricordo corretto e contributi aggiornati. I vecchi esami sono da rieseguire.');
    });
  }

  Future<void> _eventPage(int p) async => _operation(() async {
        if (selected == null) return;
        events = await store!.eventPage(selected!, offset: p * 100);
        if (mounted) setState(() => page = p);
      });
  Widget _exam() => _list('exam', [
        const Text('Che cosa sa fare dopo la lettura?',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
        const Text(
            'Scrivi riferimenti separati dal testo di apprendimento. Il motore vede solo domanda e ipotesi, mai le risposte corrette. Il controllo a memoria vuota usa le stesse domande.'),
        Wrap(spacing: 8, children: [
          OutlinedButton(
              onPressed: busy || selected == null ? null : _addQuestion,
              child: const Text('Aggiungi domanda')),
          OutlinedButton(
              onPressed: busy || selected == null ? null : _importExam,
              child: const Text('Importa esame'))
        ]),
        Text('${exam.length} domande indipendenti configurate'),
        for (var i = examPage * 25;
            i < exam.length && i < (examPage + 1) * 25;
            i++)
          ListTile(
              title: Text('${exam[i]['question']}'),
              subtitle: Text(
                  '${exam[i]['expected']} · ${(exam[i]['answers'] as List).join(' | ')}'),
              trailing: IconButton(
                  onPressed: busy
                      ? null
                      : () async {
                          exam.removeAt(i);
                          await store!.setCases(selected!, exam);
                          if (mounted) setState(() {});
                        },
                  icon: const Icon(Icons.delete_outline))),
        if (exam.length > 25)
          Row(children: [
            TextButton(
                onPressed: busy || examPage == 0
                    ? null
                    : () => setState(() => examPage--),
                child: const Text('Precedenti')),
            Text('Domande ${examPage + 1} / ${(exam.length / 25).ceil()}'),
            TextButton(
                onPressed: busy || (examPage + 1) * 25 >= exam.length
                    ? null
                    : () => setState(() => examPage++),
                child: const Text('Successive')),
          ]),
        FilledButton(
            key: const ValueKey('closed-run-exam'),
            onPressed: busy || worker == null || exam.isEmpty ? null : _runExam,
            child: const Text('Esegui l’esame a libro chiuso')),
        if (report != null)
          _box(
              'Risultati verificabili',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (report!['bookRevision'] != meta?['revision'])
                  const Text(
                      'Questo report riguarda una revisione precedente: riesegui l’esame dopo le modifiche.'),
                Text(
                    '${report!['correctAnswerable']} / ${report!['answerable']} risposte corrette',
                    style: const TextStyle(fontSize: 22)),
                Text(
                    '${report!['wrongAnswers']} risposte prodotte ma errate\n${report!['correctUnknown']} / ${report!['unknownTotal']} astensioni corrette\nConsultazioni del testo originale: ${report!['rawPassagesRead']}'),
                if (report!['emptyControl'] is Map)
                  Text(
                      'Senza apprendimento: ${(report!['emptyControl'] as Map)['correctAnswerable']} / ${(report!['emptyControl'] as Map)['answerable']} risposte corrette'),
                if ((report!['results'] as List? ?? []).length > 25)
                  Row(children: [
                    TextButton(
                        onPressed: resultPage == 0
                            ? null
                            : () => setState(() => resultPage--),
                        child: const Text('Precedenti')),
                    Text('Risultati ${resultPage + 1}'),
                    TextButton(
                        onPressed: (resultPage + 1) * 25 >=
                                (report!['results'] as List).length
                            ? null
                            : () => setState(() => resultPage++),
                        child: const Text('Successivi')),
                  ]),
                for (final row in (report!['results'] as List? ?? [])
                    .skip(resultPage * 25)
                    .take(25))
                  ExpansionTile(
                      key: PageStorageKey(
                          'exam350:$selected:${row['case']['id']}'),
                      leading: Icon(row['correct'] == true
                          ? Icons.check_circle_outline
                          : Icons.error_outline),
                      title: Text('${row['case']['question']}'),
                      children: [
                        ListTile(
                            title: Text('Risposta: ${row['result']['answer']}'),
                            subtitle: Text(
                                'Riferimento: ${(row['case']['answers'] as List).join(' | ')}\nEsito: ${row['result']['status']}'))
                      ]),
              ])),
      ]);
  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
            title: const Text('MGD · A libro chiuso'),
            actions: [
              if (widget.legacyBuilder != null)
                IconButton(
                    tooltip: 'Archivio precedente e contatori storici',
                    onPressed: busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => widget.legacyBuilder!())),
                    icon: const Icon(Icons.history)),
              IconButton(
                  tooltip: 'Esporta memoria e verifiche',
                  onPressed: busy || selected == null ? null : _export,
                  icon: const Icon(Icons.ios_share)),
              IconButton(
                  tooltip: 'Elimina questa lettura',
                  onPressed: busy || selected == null ? null : _forget,
                  icon: const Icon(Icons.delete_outline)),
            ],
            bottom: const TabBar(isScrollable: true, tabs: [
              Tab(text: 'Leggi'),
              Tab(text: 'Ricorda'),
              Tab(text: 'Italiano'),
              Tab(text: 'Storia'),
              Tab(text: 'Esame')
            ])),
        body: Column(children: [
          if (books.isNotEmpty)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DropdownButton<String>(
                    key: const ValueKey('closed-book-selector'),
                    value: selected,
                    isExpanded: true,
                    items: books
                        .map((b) => DropdownMenuItem(
                            value: b['id'] as String,
                            child: Text('${b['title']}',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null) _select(v);
                          })),
          if (busy) const LinearProgressIndicator(),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(status,
                  key: const ValueKey('closed-status'),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis)),
          if (busy && cancellable)
            TextButton.icon(
                key: const ValueKey('closed-cancel'),
                onPressed: () => setState(() {
                      cancel = true;
                      status =
                          'Interruzione richiesta: attendo il blocco atomico corrente.';
                    }),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Interrompi e conserva i progressi')),
          Expanded(
              child: TabBarView(children: [
            _read(),
            _recall(),
            _italian(),
            _story(),
            _exam()
          ])),
        ]),
      ));
}
