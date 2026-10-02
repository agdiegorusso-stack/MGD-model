// BOOK_ANSWERABLE_METRIC_0342
import 'dart:convert';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'book_understanding_v0342.dart';
import 'book_lab_service_v0342.dart';
import 'web_knowledge_explorer_v11.dart';

class BookLabPage342 extends StatefulWidget {
  final ResearchMemory11 memory;
  final Future<void> Function() onSave;
  const BookLabPage342({super.key, required this.memory, required this.onSave});
  @override
  State<BookLabPage342> createState() => _BookLabPage342State();
}

class _BookLabPage342State extends State<BookLabPage342> {
  final question = TextEditingController(),
      assumptions = TextEditingController();
  List<Map<String, dynamic>> all = [], sources = [], cases = [], history = [];
  BookWorker342? worker;
  String? scope;
  String status = 'Preparazione dei passaggi conservati…';
  bool busy = true;
  int epoch = 0;
  Map<String, dynamic>? answer, report;
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, _prepare);
  }

  @override
  void dispose() {
    epoch++;
    worker?.close();
    question.dispose();
    assumptions.dispose();
    super.dispose();
  }

  void message(String x) {
    if (mounted) setState(() => status = x);
  }

  Future<void> _prepare() async {
    try {
      all = BookLab342.rows(widget.memory);
      sources = BookLab342.scopes(all);
      final old = BookLab342.state(widget.memory)['activeScope'] as String?;
      if (sources.isEmpty) {
        if (mounted)
          setState(() {
            busy = false;
            status =
                'Non ci sono passaggi conservati. Importa un libro TXT in MGD Language.';
          });
        return;
      }
      await _select(
          sources.any((s) => s['key'] == old) ? old! : bookScope342(all.last));
    } catch (e) {
      if (mounted)
        setState(() {
          busy = false;
          status = 'Preparazione non completata: $e';
        });
    }
  }

  Future<void> _select(String value) async {
    final version = ++epoch;
    worker?.close();
    worker = null;
    if (!mounted) return;
    setState(() {
      busy = true;
      scope = value;
      answer = null;
      report = null;
      status =
          'Indicizzazione del materiale selezionato in esecuzione separata…';
    });
    try {
      final w = await BookWorker342.open(
          all.where((r) => bookScope342(r) == value).toList());
      if (!mounted || version != epoch) {
        w.close();
        return;
      }
      worker = w;
      cases = BookLab342.cases(widget.memory, value);
      history = BookLab342.reports(widget.memory, value);
      BookLab342.state(widget.memory)['activeScope'] = value;
      await widget.onSave();
      if (!mounted) return;
      setState(() {
        busy = false;
        report = history.isEmpty ? null : history.last;
        status =
            'Pronto. Le domande e i riferimenti dell’esame non vengono appresi dal motore.';
      });
    } catch (e) {
      if (mounted && version == epoch)
        setState(() {
          busy = false;
          status = 'Lettore non pronto: $e';
        });
    }
  }

  Future<void> _ask() async {
    if (busy || worker == null || question.text.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      status = 'Ricerca delle evidenze…';
    });
    try {
      final r = await worker!.call('ask', {
        'question': question.text.trim(),
        'assumptions': assumptions.text.trim()
      });
      if (mounted)
        setState(() {
          answer = Map<String, dynamic>.from(r as Map);
          status = 'Risposta con evidenze e limiti consultabili.';
        });
    } catch (e) {
      message('Domanda non completata: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _run({bool auto = false}) async {
    if (busy || worker == null || scope == null) return;
    setState(() {
      busy = true;
      status = auto
          ? 'Autoprove interne (non indipendenti)…'
          : 'Esame sui riferimenti separati…';
    });
    try {
      final tests =
          auto ? BookExam342.validate(await worker!.call('probes')) : cases;
      if (tests.isEmpty) {
        message(auto
            ? 'Nessuna relazione adatta alle autoprove: non è un punteggio zero di comprensione.'
            : 'Aggiungi almeno una domanda con il riferimento corretto.');
        return;
      }
      final r = Map<String, dynamic>.from(
          await worker!.call('exam', {'cases': tests}) as Map);
      final baseline = Map<String, dynamic>.from(
          await worker!.call('emptyControl', {'cases': tests}) as Map);
      r['emptyControl'] = {
        'correct': baseline['correct'],
        'total': baseline['total'],
        'categories': baseline['categories'],
        'fingerprint': baseline['fingerprint'],
        'note':
            'Controllo senza passaggi, con le stesse ipotesi. Non è una misura storica della precedente installazione.'
      };
      BookLab342.retainReport(widget.memory, scope!, r);
      await widget.onSave();
      if (!mounted) return;
      setState(() {
        report = r;
        history = BookLab342.reports(widget.memory, scope!);
        status =
            'Esame salvato. Apri Risultati: ogni risposta è confrontabile con riferimento e passaggi.';
      });
    } catch (e) {
      message('Esame non completato: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit([int? index]) async {
    if (busy || scope == null) return;
    final old = index == null ? null : cases[index];
    final q = TextEditingController(
        text: old?['question'] as String? ?? question.text);
    final a = TextEditingController(
        text: old?['assumptions'] as String? ?? assumptions.text);
    final refs = TextEditingController(
        text: (old?['answers'] as List? ?? []).join('\n'));
    final support = TextEditingController(
        text: (old?['support'] as List? ?? []).join('\n'));
    var expected = old?['expected'] as String? ?? 'answer';
    var category = old?['category'] as String? ?? 'diretta';
    if (!const [
      'diretta',
      'parafrasi',
      'deduzione',
      'trasferimento',
      'non determinabile',
      'contraddizione',
      'altro'
    ].contains(category)) category = 'altro';
    String? error;
    final saved = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, change) => AlertDialog(
                    title: Text(index == null
                        ? 'Nuova prova indipendente'
                        : 'Modifica prova'),
                    content: SizedBox(
                        width: 520,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text(
                                  'Verifica il riferimento sul libro, non copiando la risposta di MGD. I riferimenti sono conservati separatamente dal materiale interrogato.'),
                              TextField(
                                  controller: q,
                                  key: const ValueKey('exam-question'),
                                  decoration: const InputDecoration(
                                      labelText: 'Domanda'),
                                  maxLines: 2),
                              TextField(
                                  controller: a,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'Ipotesi nuove, opzionali (non apprese)'),
                                  maxLines: 2),
                              DropdownButtonFormField<String>(
                                  initialValue: category,
                                  decoration: const InputDecoration(
                                      labelText: 'Capacità da verificare'),
                                  items: const [
                                    'diretta',
                                    'parafrasi',
                                    'deduzione',
                                    'trasferimento',
                                    'non determinabile',
                                    'contraddizione',
                                    'altro'
                                  ]
                                      .map((s) => DropdownMenuItem(
                                          value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (v) =>
                                      change(() => category = v!)),
                              DropdownButtonFormField<String>(
                                  initialValue: expected,
                                  decoration: const InputDecoration(
                                      labelText: 'Esito corretto atteso'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'answer',
                                        child: Text('Risposta determinabile')),
                                    DropdownMenuItem(
                                        value: 'unknown',
                                        child: Text('Non determinabile')),
                                    DropdownMenuItem(
                                        value: 'conflict',
                                        child: Text('Contraddizione esplicita'))
                                  ],
                                  onChanged: (v) =>
                                      change(() => expected = v!)),
                              if (expected == 'answer')
                                TextField(
                                    controller: refs,
                                    key: const ValueKey('exam-reference'),
                                    decoration: const InputDecoration(
                                        labelText:
                                            'Risposte accettate: una per riga'),
                                    maxLines: 3),
                              TextField(
                                  controller: support,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'Passaggi di supporto esatti: uno per riga',
                                      helperText:
                                          'Senza riferimenti testuali, la correttezza delle evidenze non viene valutata.'),
                                  maxLines: 3),
                              if (error != null)
                                Text(error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annulla')),
                      FilledButton(
                          onPressed: () {
                            try {
                              final c = {
                                'id': old?['id'] ??
                                    'manual:${DateTime.now().microsecondsSinceEpoch}',
                                'question': q.text.trim(),
                                'assumptions': a.text.trim(),
                                'category': category,
                                'expected': expected,
                                'answers': refs.text
                                    .split('\n')
                                    .map((s) => s.trim())
                                    .where((s) => s.isNotEmpty)
                                    .toList(),
                                'support': support.text
                                    .split('\n')
                                    .map((s) => s.trim())
                                    .where((s) => s.isNotEmpty)
                                    .toList(),
                                'origin': 'external_reference'
                              };
                              BookExam342.validate([c]);
                              Navigator.pop(context, c);
                            } catch (e) {
                              change(() => error = '$e');
                            }
                          },
                          child: const Text('Salva prova'))
                    ])));
    // The dialog route may still be animating; controllers are no longer modified.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    q.dispose();
    a.dispose();
    refs.dispose();
    support.dispose();
    if (saved == null || !mounted) return;
    setState(() {
      if (index == null) {
        cases.add(saved);
      } else {
        cases[index] = saved;
      }
    });
    await _saveCases();
  }

  Future<void> _saveCases() async {
    try {
      BookLab342.setCases(widget.memory, scope!, cases);
      await widget.onSave();
      message('Domande salvate nell’esame, non nella conoscenza.');
    } catch (e) {
      message('Salvataggio esame fallito: $e');
    }
  }

  Future<void> _import() async {
    if (busy || scope == null) return;
    setState(() => busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          withData: false,
          withReadStream: true);
      if (picked == null) return;
      final f = picked.files.single;
      if (f.size > 8 * 1024 * 1024)
        throw const FormatException(
            'Il file delle domande supera 8 MiB; suddividi l’esame. Questo limite non riguarda i libri.');
      final stream = f.readStream;
      if (stream == null)
        throw const FormatException(
            'Il provider non offre il flusso del file.');
      final bytes = BytesBuilder(copy: false);
      await for (final part in stream) {
        bytes.add(part);
        if (bytes.length > 8 * 1024 * 1024)
          throw const FormatException('Esame troppo grande.');
      }
      final text = utf8.decode(bytes.takeBytes());
      final imported =
          await Isolate.run(() => BookExam342.validate(jsonDecode(text)));
      // IDs are merged deliberately; replacement of a reference is visible in the editor.
      final merged = {
        for (final c in cases) '${c['id']}': c,
        for (final c in imported) '${c['id']}': c
      };
      if (!mounted) return;
      setState(() => cases = merged.values.toList());
      await _saveCases();
    } catch (e) {
      message('Importazione domande non completata: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _export(bool results) async {
    try {
      final content =
          results ? report : {'schema': 1, 'scope': scope, 'cases': cases};
      if (content == null) return;
      final data = Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(content)));
      final path = await FilePicker.platform.saveFile(
          dialogTitle: results ? 'Esporta risultati' : 'Esporta domande',
          fileName:
              results ? 'MGD-esame-risultati.json' : 'MGD-esame-domande.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: data);
      if (path != null) message('File esportato nella posizione scelta.');
    } catch (e) {
      message('Esportazione non completata: $e');
    }
  }

  Widget _response(Map<String, dynamic> r) {
    final evidence = (r['evidence'] as List? ?? []).whereType<Map>().toList();
    final related = (r['related'] as List? ?? []).whereType<Map>().toList();
    final labels = {
      'direct': 'RISPOSTA DAL TESTO',
      'deduction': 'DEDUZIONE',
      'unknown': 'NON DETERMINATA',
      'conflict': 'CONTRADDIZIONE'
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(labels[r['status']] ?? 'RISULTATO',
          style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      SelectableText('${r['answer']}',
          key: const ValueKey('book-answer'),
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text('${r['reason']}'),
      Text(
          'Calcolo nel lettore: ${((r['micros'] as num? ?? 0) / 1000).toStringAsFixed(2)} ms; esclusi avvio, interfaccia e salvataggio.'),
      const SizedBox(height: 12),
      Text(
          evidence.isEmpty
              ? 'Passaggi pertinenti, non una risposta'
              : 'Passaggi utilizzati',
          style: Theme.of(context).textTheme.titleSmall),
      for (final e in evidence.isEmpty ? related : evidence)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SelectableText('«${e['text']}»'),
              Text('${e['title']}'),
              SelectableText('${e['url']}',
                  style: Theme.of(context).textTheme.bodySmall),
            ])),
    ]);
  }

  Widget _questions() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'La risposta deve essere sostenuta dal materiale selezionato. Il lettore può anche dichiarare una lacuna o mostrare una contraddizione.'),
        const SizedBox(height: 12),
        TextField(
            controller: question,
            key: const ValueKey('book-question'),
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Domanda sul libro', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
            controller: assumptions,
            key: const ValueKey('book-hypotheses'),
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Nuova situazione: premesse opzionali',
                hintText: 'Esempio: Zeta è un neride.',
                helperText:
                    'Usate soltanto per questa domanda. Non vengono memorizzate come verità.',
                border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              key: const ValueKey('book-ask'),
              onPressed: busy || worker == null ? null : _ask,
              icon: const Icon(Icons.question_answer_outlined),
              label: const Text('Interroga il libro')),
          OutlinedButton(
              onPressed: busy || scope == null ? null : () => _edit(),
              child: const Text('Aggiungi domanda all’esame')),
        ]),
        const SizedBox(height: 16),
        if (answer != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _response(answer!))),
        const SizedBox(height: 20),
        const Text(
            'Esempi di forme supportate: «Che cosa contiene X?», «Chi aiuta Y?», «Dove si trova X?», «Che cosa è X?», «X è un Y?». Il trasferimento usa regole esplicite del tipo «Ogni X produce Y». Le cause richiedono una motivazione esplicita. Non è ancora comprensione generale di prosa e italiano.'),
      ]);
  Widget _exam() => ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cases.length + 1,
      itemBuilder: (context, i) {
        if (i == 0)
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Esame indipendente: ${cases.length} domande',
                    style: Theme.of(context).textTheme.titleMedium),
                const Text(
                    'Riferimenti corretti e passaggi di supporto sono fissati separatamente. Il motore vede solo domanda e ipotesi, mai la risposta attesa. Un punteggio senza domande non viene inventato.'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton(
                      onPressed: busy || cases.isEmpty || worker == null
                          ? null
                          : () => _run(),
                      child: const Text('Esegui esame indipendente')),
                  OutlinedButton(
                      onPressed: busy || scope == null ? null : () => _edit(),
                      child: const Text('Aggiungi domanda')),
                  OutlinedButton(
                      onPressed: busy || scope == null ? null : _import,
                      child: const Text('Importa domande JSON')),
                  TextButton(
                      onPressed: cases.isEmpty ? null : () => _export(false),
                      child: const Text('Esporta domande')),
                ]),
                const Divider(height: 32),
                const Text(
                    'Autoprove interne: controllano solo le relazioni già riconosciute dallo stesso lettore. Non sono una misura indipendente della comprensione del libro.'),
                OutlinedButton(
                    onPressed:
                        busy || worker == null ? null : () => _run(auto: true),
                    child: const Text('Esegui autoprove diagnostiche')),
                const Divider(height: 32),
              ]);
        final c = cases[i - 1];
        return Card(
            child: ListTile(
                title: Text('${c['question']}'),
                subtitle: Text(
                    '${c['category']} • atteso: ${c['expected']}\n${(c['answers'] as List).join(' / ')}'),
                onTap: busy ? null : () => _edit(i - 1),
                trailing: IconButton(
                    tooltip: 'Elimina solo la prova',
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => cases.removeAt(i - 1));
                            await _saveCases();
                          },
                    icon: const Icon(Icons.delete_outline))));
      });
  Widget _results() {
    final r = report;
    if (r == null)
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'Nessun esame eseguito per questo materiale. Non esiste ancora un punteggio di comprensione.')));
    final results = (r['results'] as List).whereType<Map>().toList();
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: results.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            final auto = r['referenceKind'] != 'external_reference';
            final cats = Map<String, dynamic>.from(r['categories'] as Map);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      auto
                          ? 'AUTOPROVE — NON INDIPENDENTI'
                          : 'ESAME CON RIFERIMENTI SEPARATI',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                      '${r['correct']}/${r['total']} esiti coincidenti con i riferimenti; ${r['answered']} risposte prodotte; ${r['wrongAnswers']} risposte prodotte ma errate rispetto ai riferimenti.'),
                  Text(
                      'Risposte corrette alle domande rispondibili: ${r['correctAnswerable'] ?? 'non misurato'}/${r['answerable']}.'),
                  Text(
                      'Domande non determinabili: ${r['correctUnknown']}/${r['unknownTotal']} riconosciute.'),
                  Text(
                      'Evidenze corrette rispetto ai passaggi indicati: ${r['supportCorrect']}/${r['supportChecked']}. Risposta ed evidenza insieme: ${r['jointCorrect']}/${r['supportChecked']}.'),
                  Text(
                      'Token F1 sulle domande rispondibili: ${r['tokenF1'] == null ? 'non misurato' : ((r['tokenF1'] as num) * 100).toStringAsFixed(1)}. È una metrica testuale, non una percentuale di comprensione.'),
                  for (final c in cats.entries)
                    Text(
                        '${c.key}: ${(c.value as Map)['correct']}/${(c.value as Map)['total']}'),
                  if (r['emptyControl'] is Map)
                    Text(
                        'Controllo a memoria vuota: ${(r['emptyControl'] as Map)['correct']}/${(r['emptyControl'] as Map)['total']} esiti. Include l’astensione corretta; non equivale alla vecchia versione.'),
                  SelectableText('Impronta del materiale: ${r['fingerprint']}',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (worker != null &&
                      r['fingerprint'] != worker!.metadata['fingerprint'])
                    const Text(
                        'ATTENZIONE: il materiale attuale è diverso da quello usato in questo esame.'),
                  Wrap(spacing: 8, children: [
                    TextButton(
                        onPressed: () => _export(true),
                        child: const Text('Esporta report completo')),
                    TextButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(
                              text: const JsonEncoder.withIndent('  ')
                                  .convert(r)));
                          message('Report copiato.');
                        },
                        child: const Text('Copia report')),
                    if (history.length > 1)
                      PopupMenuButton<int>(
                          tooltip: 'Esami precedenti',
                          onSelected: (i) =>
                              setState(() => report = history[i]),
                          itemBuilder: (c) => List.generate(
                              history.length,
                              (i) => PopupMenuItem(
                                  value: i,
                                  child:
                                      Text('${i + 1} • ${history[i]['at']}')))),
                  ]),
                  const Divider(height: 24),
                ]);
          }
          final row = results[i - 1],
              c = Map<String, dynamic>.from(row['case'] as Map),
              value = Map<String, dynamic>.from(row['result'] as Map);
          return Card(
              child: ExpansionTile(
                  key: ValueKey('exam-result-${r['at']}-${c['id']}'),
                  title: Text('${c['question']}'),
                  subtitle: Text(
                      '${row['correct'] == true ? 'Coincide' : 'NON coincide'} con il riferimento • ${c['category']}'),
                  children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Atteso: ${c['expected']} — ${(c['answers'] as List).join(' / ')}'),
                          if ('${c['assumptions']}'.isNotEmpty)
                            Text('Ipotesi: ${c['assumptions']}'),
                          Text(row['supportChecked'] == true
                              ? 'Supporto di riferimento: ${(c['support'] as List).join(' | ')}'
                              : 'Evidenze non valutate: manca un riferimento indipendente.'),
                          const SizedBox(height: 12),
                          _response(value),
                        ]))
              ]));
        });
  }

  @override
  Widget build(BuildContext context) {
    final selected = sources.where((s) => s['key'] == scope).firstOrNull;
    return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
              title: const Text('Verifica del libro'),
              bottom: const TabBar(tabs: [
                Tab(text: 'Interroga'),
                Tab(text: 'Esame'),
                Tab(text: 'Risultati')
              ])),
          body: SafeArea(
              child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sources.isNotEmpty)
                        DropdownButton<String>(
                            key: const ValueKey('book-source'),
                            isExpanded: true,
                            value: scope,
                            items: sources
                                .map((s) => DropdownMenuItem(
                                    value: '${s['key']}',
                                    child: Text(
                                        '${s['title']} • ${s['count']} passaggi',
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: busy
                                ? null
                                : (v) {
                                    if (v != null) _select(v);
                                  }),
                      if (selected?['legacy'] == true)
                        const Text(
                            'Archivio precedente: raggruppato per titolo. File omonimi possono essere mescolati.',
                            style: TextStyle(fontSize: 12)),
                      if (worker != null)
                        Text(
                            '${worker!.metadata['parsedStatements']} enunciati interpretabili; ${worker!.metadata['universalRules']} regole esplicite. Non è la comprensione totale.',
                            style: const TextStyle(fontSize: 12)),
                      Text(status,
                          key: const ValueKey('book-lab-status'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                      if (busy) const LinearProgressIndicator(),
                    ])),
            Expanded(
                child:
                    TabBarView(children: [_questions(), _exam(), _results()]))
          ])),
        ));
  }
}
