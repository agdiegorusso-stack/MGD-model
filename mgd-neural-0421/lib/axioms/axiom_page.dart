import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'axiom_core.dart';
import 'axiom_store.dart';

class AxiomStudioPage extends StatefulWidget {
  final AxiomStore? store;
  const AxiomStudioPage({super.key, this.store});
  @override
  State<AxiomStudioPage> createState() => _AxiomStudioPageState();
}

class _AxiomStudioPageState extends State<AxiomStudioPage> {
  late final AxiomStore store;
  final text = TextEditingController(text: 'Luca giunge a Pisa.');
  final search = TextEditingController();
  bool list = false;
  String? focus;
  String error = '';
  int rounds = 3;
  J world = {
    'location': {'luca': 'roma', 'sofia': 'roma', 'chiave': null},
    'holder': {'chiave': 'luca'},
    'owner': {'chiave': 'luca'}
  };
  @override
  void initState() {
    super.initState();
    store = widget.store ?? AxiomStore();
    if (!store.ready)
      store.open().catchError((Object e) {
        if (mounted) setState(() => error = '$e');
      });
  }

  @override
  void dispose() {
    text.dispose();
    search.dispose();
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  void message(String s) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> export() async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(store.export()));
      await FilePicker.platform.saveFile(
          dialogTitle: 'Esporta mappa e registro',
          fileName: 'MGD_assiomi_${DateTime.now().millisecondsSinceEpoch}.json',
          bytes: bytes);
    } catch (e) {
      message('Esportazione non completata: $e');
    }
  }

  Future<void> import() async {
    try {
      final f = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['json'], withData: false);
      if (f == null) return;
      final path = f.files.single.path;
      if (path == null) throw StateError('File non accessibile.');
      final file = File(path);
      if (await file.length() > 8000000)
        throw const FormatException('Backup oltre 8 MB.');
      await store.import(await file.readAsString());
    } catch (e) {
      message('Importazione non completata: $e');
    }
  }

  Future<void> editWorld() async {
    final values = ['luca', 'sofia', 'chiave', 'roma', 'roma', 'luca', 'luca']
        .map((v) => TextEditingController(text: v))
        .toList();
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Mondo di prova'),
                content: SizedBox(
                    width: 400,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'Un nome per entità. Un luogo lasciato vuoto significa informazione mancante. “nessuno” indica assenza di detentore.'),
                      for (var i = 0; i < values.length; i++)
                        TextField(
                            controller: values[i],
                            decoration: InputDecoration(
                                labelText: const [
                              'Persona che agisce',
                              'Altra persona',
                              'Oggetto',
                              'Luogo prima persona',
                              'Luogo altra persona',
                              'Chi tiene l’oggetto',
                              'Proprietario'
                            ][i])),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Annulla')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Applica'))
                ]));
    if (ok == true && mounted) {
      final v = values.map((c) => c.text.trim().toLowerCase()).toList();
      if (v.take(3).toSet().length != 3 || !v.take(3).every(entity)) {
        message('Usa tre nomi distinti, di una sola parola.');
      } else {
        setState(() => world = {
              'location': {
                if (v[3].isNotEmpty) v[0]: v[3],
                if (v[4].isNotEmpty) v[1]: v[4],
                v[2]: v[5] == 'nessuno' ? (v[3].isEmpty ? null : v[3]) : null
              },
              'holder': {
                if (v[5].isNotEmpty) v[2]: v[5] == 'nessuno' ? null : v[5]
              },
              'owner': {if (v[6].isNotEmpty) v[2]: v[6]}
            });
      }
    }
    for (final c in values) c.dispose();
  }

  Future<void> node(J n) async {
    final id = n['id'] as String,
        audit = (store.state['audits'] as Map)[id] as Map?;
    final mutable = const [
      'lexeme',
      'frame',
      'rule',
      'program',
      'guard',
      'write'
    ].contains(n['type']);
    final action = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(n['label'] as String),
                content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          Text(typeName(n['type'] as String),
                              style: Theme.of(c).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          Text(n['minimality'] as String),
                          const SizedBox(height: 14),
                          const Text('Dipende da',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          for (final dep in n['depends'] as List)
                            ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(store.nodes
                                        .where((x) => x['id'] == dep)
                                        .map((x) => x['label'])
                                        .firstOrNull
                                        ?.toString() ??
                                    dep.toString()),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.pop(c);
                                  setState(() => focus = dep as String);
                                }),
                          if (audit != null) ...[
                            const Divider(),
                            Text(
                                'Ultima rimozione su copia: ${audit['tested']} prove, ${audit['regressions']} regressioni.'),
                            if (audit['regressions'] == 0)
                              const Text(
                                  'Non dimostra che il componente sia superfluo in ogni contesto.'),
                            for (final w in audit['witnesses'] as List? ?? [])
                              Text('Controesempio: ${w['text']}')
                          ],
                          ExpansionTile(
                              title: const Text(
                                  'Definizione eseguibile e provenienza'),
                              children: [
                                SelectableText(
                                    const JsonEncoder.withIndent('  ')
                                        .convert(n['data']))
                              ]),
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, 'focus'),
                      child: const Text('Collegamenti')),
                  if (mutable)
                    TextButton(
                        onPressed:
                            store.busy ? null : () => Navigator.pop(c, 'test'),
                        child: const Text('Prova rimozione')),
                  if (mutable &&
                      audit?['regressions'] == 0 &&
                      audit?['tested'] != 0)
                    TextButton(
                        onPressed: store.busy
                            ? null
                            : () => Navigator.pop(c, 'archive'),
                        child: const Text('Disattiva in prova')),
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Chiudi'))
                ]));
    if (!mounted) return;
    if (action == 'focus') setState(() => focus = id);
    if (action == 'test') await store.audit(id);
    if (action == 'archive') {
      final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Disattivazione sperimentale'),
                  content: const Text(
                      'Un test finito non prova inutilità assoluta. Il componente sarà rimosso dalla memoria attiva solo dopo un nuovo controllo. La revisione precedente resterà recuperabile. Continuare?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Annulla')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Disattiva e conserva backup'))
                  ]));
      if (confirm == true) await store.archive(id);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) => DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
                title: const Text('Assiomi · MGD Studio'),
                actions: [
                  IconButton(
                      tooltip: 'Modelli insegnanti',
                      icon: const Icon(Icons.memory),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const TeacherModelsPage()))),
                  PopupMenuButton<String>(
                      onSelected: (s) {
                        if (s == 'export') export();
                        if (s == 'import' && !store.busy) import();
                        if (s == 'undo' && !store.busy) store.undo();
                      },
                      itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'export',
                                child: Text('Esporta mappa e registro')),
                            PopupMenuItem(
                                value: 'import',
                                enabled: !store.busy,
                                child: const Text('Importa backup')),
                            PopupMenuItem(
                                value: 'undo',
                                enabled: !store.busy,
                                child: const Text(
                                    'Ripristina revisione precedente'))
                          ])
                ],
                bottom: const TabBar(tabs: [
                  Tab(icon: Icon(Icons.hub), text: 'Mappa'),
                  Tab(icon: Icon(Icons.school), text: 'Insegnante'),
                  Tab(icon: Icon(Icons.fact_check), text: 'Prove')
                ])),
            body: SafeArea(
                child: !store.ready
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(error.isEmpty
                                ? 'Apertura memoria…'
                                : 'Memoria non aperta. Nessun dato è stato cancellato.\n$error')))
                    : Column(children: [
                        if (store.busy) const LinearProgressIndicator(),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                            child: Text(store.status,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall)),
                        Expanded(
                            child: TabBarView(children: [
                          mapTab(),
                          teacherTab(),
                          testsTab()
                        ])),
                      ])),
          )));
  Widget mapTab() {
    var shown = store.nodes;
    final query = search.text.trim().toLowerCase();
    if (query.isNotEmpty)
      shown = shown
          .where((n) => '${n['label']} ${n['id']} ${n['type']}'
              .toLowerCase()
              .contains(query))
          .toList();
    if (focus != null) {
      final selected = store.nodes.where((n) => n['id'] == focus).firstOrNull;
      final connected = {
        focus,
        if (selected != null) ...(selected['depends'] as List).cast<String>(),
        ...store.nodes
            .where((n) => (n['depends'] as List).contains(focus))
            .map((n) => n['id'] as String)
      };
      shown = shown.where((n) => connected.contains(n['id'])).toList();
    }
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
                child: TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Cerca assiomi e collegamenti'))),
            IconButton(
                tooltip: list ? 'Mostra grafo' : 'Mostra elenco completo',
                onPressed: () => setState(() => list = !list),
                icon: Icon(list ? Icons.hub : Icons.list))
          ])),
      Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${shown.length} / ${store.nodes.length} componenti'),
                const Text('Freccia: composto → componente'),
                if (focus != null)
                  ActionChip(
                      label: const Text('Tutta la mappa'),
                      onPressed: () => setState(() => focus = null))
              ])),
      Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('Nessun componente corrispondente.'))
              : list
                  ? ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (c, i) {
                        final n = shown[i];
                        return ListTile(
                            leading: Icon(n['type'] == 'primitive'
                                ? Icons.circle_outlined
                                : Icons.account_tree_outlined),
                            title: Text(n['label'] as String),
                            subtitle: Text(
                                '${typeName(n['type'] as String)} · ${(n['depends'] as List).length} dipendenze'),
                            onTap: () => node(n));
                      })
                  : AxiomGraph(nodes: shown, onNode: node)),
      const Padding(
          padding: EdgeInsets.all(10),
          child: Text(
              'Base operativa dichiarata ≠ minimo assoluto dimostrato. Usa due dita per zoomare e tocca un nodo.',
              style: TextStyle(fontSize: 12))),
    ]);
  }

  Widget teacherTab() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'Il maestro propone. Il discepolo deve dimostrare il trasferimento.',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Le nuove lezioni modificano il nucleo simbolico degli assiomi. Il vecchio lettore MGD e le sue memorie restano separati e non vengono riscritti.'),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const TeacherModelsPage())),
            icon: const Icon(Icons.download),
            label: const Text('Scarica / carica Gemma 4')),
        const SizedBox(height: 16),
        TextField(
            controller: text,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
                labelText: 'Frase da capire o da insegnare',
                border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Contesto osservato',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(describeWorld(world)),
                      TextButton.icon(
                          onPressed: store.busy ? null : editWorld,
                          icon: const Icon(Icons.edit),
                          label: const Text('Modifica i fatti del mondo'))
                    ]))),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed:
                  store.busy ? null : () => store.inspect(text.text, world),
              icon: const Icon(Icons.psychology),
              label: const Text('Chiedi al discepolo')),
          FilledButton.icon(
              onPressed: store.busy
                  ? null
                  : () => store.teach(text.text, world, rounds),
              icon: const Icon(Icons.school),
              label: const Text('Insegna e verifica')),
          if (store.busy)
            OutlinedButton.icon(
                onPressed: store.stop,
                icon: const Icon(Icons.stop),
                label: const Text('Interrompi'))
        ]),
        Row(children: [
          const Text('Massimo cicli per richiesta'),
          const SizedBox(width: 16),
          DropdownButton<int>(
              value: rounds,
              items: List.generate(
                  5,
                  (i) =>
                      DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
              onChanged:
                  store.busy ? null : (v) => setState(() => rounds = v ?? 3))
        ]),
        const Text(
            'Nessun addestramento dichiarato concluso: il tutor deve distinguere lacune, errori di composizione e fatti mancanti. Le sue etichette sono proposte formative, non verità certificate.'),
        if (store.result != null) resultCard(store.result!),
      ]);
  Widget testsTab() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Comprensione e superfluità',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Le prove verificano interpretazione, effetti, negazione e informazioni mancanti nel simulatore. Rimuovere un nodo da una copia produce controesempi riproducibili; non dimostra minimalità universale.'),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: store.busy ? null : store.testAll,
            icon: const Icon(Icons.play_arrow),
            label: Text('Esegui ${store.probes.length} regressioni note')),
        OutlinedButton.icon(
            onPressed: store.busy ? null : store.auditAll,
            icon: const Icon(Icons.manage_search),
            label: const Text('Cerca componenti superflui')),
        if (store.busy)
          TextButton.icon(
              onPressed: store.stop,
              icon: const Icon(Icons.stop),
              label: const Text('Interrompi audit')),
        OutlinedButton.icon(
            onPressed: store.busy ? null : store.undo,
            icon: const Icon(Icons.restore),
            label: const Text('Ripristina revisione precedente')),
        if (store.result != null) resultCard(store.result!),
        const SizedBox(height: 16),
        const Text('Registro delle lezioni e delle verifiche',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final e in (store.state['events'] as List).reversed.take(30))
          ExpansionTile(
              title: Text(
                  '${e['kind']} · ${e['request'] ?? e['node'] ?? e['at']}'),
              subtitle: e['diagnosis'] == null
                  ? null
                  : Text('${e['diagnosis']}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
              children: [
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                        const JsonEncoder.withIndent('  ').convert(e)))
              ]),
        if ((store.state['events'] as List).isEmpty)
          const Padding(
              padding: EdgeInsets.all(14),
              child:
                  Text('Nessuna verifica eseguita in questa installazione.')),
      ]);
  Widget resultCard(J r) {
    final reading = r['reading'] as Map?, parts = <Widget>[];
    if (reading != null) {
      parts.add(Text('Interpretazione: ${reading['status']}'));
      if (reading['intent'] != null)
        parts.add(Text('Azione: ${reading['intent']} · ${reading['args']}'));
      if (r['world'] is Map) parts.add(Text(describeWorld(r['world'] as Map)));
      if (r['missing_facts'] != null)
        parts.add(Text(
            'Informazioni mancanti: ${(r['missing_facts'] as List).join(', ')}'));
      parts.add(Wrap(spacing: 6, children: [
        for (final id in reading['proof'] as List? ?? [])
          ActionChip(
              label: Text(store.nodes
                      .where((n) => n['id'] == id)
                      .firstOrNull?['label']
                      ?.toString() ??
                  '$id'),
              onPressed: () {
                setState(() => focus = id as String);
              })
      ]));
    }
    if (r['total'] != null)
      parts.add(Text('${r['passed']} / ${r['total']} prove superate',
          style: const TextStyle(fontWeight: FontWeight.bold)));
    if (r['accepted'] != null)
      parts.add(Text(r['accepted'] == true
          ? 'Lezione accettata nelle prove formative.'
          : 'Lezione non accettata: ${r['reason']}'));
    if (r['regressions'] != null)
      parts.add(Text(
          'Rimozione: ${r['regressions']} regressioni su ${r['tested']} prove.'));
    final summary = copyJ(r)..remove('model');
    if (summary['results'] is List)
      summary['results'] = (summary['results'] as List)
          .where((q) => q['passed'] != true)
          .take(20)
          .toList();
    parts.add(ExpansionTile(
        title: const Text('Traccia e risultati tecnici'),
        children: [
          SelectableText(const JsonEncoder.withIndent('  ').convert(summary))
        ]));
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: parts)));
  }
}

String typeName(String t) =>
    const {
      'primitive': 'Primitiva dichiarata nel DSL',
      'expression': 'Espressione',
      'guard': 'Condizione',
      'write': 'Scrittura',
      'program': 'Composizione semantica',
      'frame': 'Struttura di ruoli',
      'lexeme': 'Collegamento lessicale',
      'rule': 'Costruzione riutilizzabile'
    }[t] ??
    t;
String describeWorld(Map world) {
  final lines = <String>[];
  for (final e in (world['location'] as Map? ?? {}).entries) {
    if (e.value != null) lines.add('${e.key} si trova a ${e.value}.');
  }
  for (final e in (world['holder'] as Map? ?? {}).entries) {
    lines.add(e.value == null
        ? '${e.key}: nessun detentore.'
        : '${e.key} è in mano a ${e.value}.');
  }
  for (final e in (world['owner'] as Map? ?? {}).entries) {
    if (e.value != null) lines.add('${e.key} appartiene a ${e.value}.');
  }
  return lines.isEmpty ? 'Nessun fatto disponibile.' : lines.join(' ');
}

class AxiomGraph extends StatefulWidget {
  final List<J> nodes;
  final void Function(J) onNode;
  const AxiomGraph({super.key, required this.nodes, required this.onNode});
  @override
  State<AxiomGraph> createState() => _AxiomGraphState();
}

class _AxiomGraphState extends State<AxiomGraph> {
  final transform = TransformationController();
  @override
  void initState() {
    super.initState();
    transform.value = Matrix4.identity()..scale(0.6);
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = <int, int>{}, positions = <String, Rect>{};
    const stage = {
      'primitive': 0,
      'expression': 1,
      'guard': 2,
      'write': 2,
      'program': 3,
      'frame': 4,
      'rule': 4,
      'lexeme': 5
    };
    for (final n in widget.nodes) {
      final column = stage[n['type']] ?? 5, row = counts[column] ?? 0;
      counts[column] = row + 1;
      positions[n['id'] as String] =
          Rect.fromLTWH(24 + column * 250, 24 + row * 90, 214, 62);
    }
    final size = Size(1520,
        math.max(420.0, (counts.values.fold<int>(0, math.max)) * 90.0 + 50));
    return Stack(children: [
      InteractiveViewer(
          transformationController: transform,
          constrained: false,
          minScale: 0.05,
          maxScale: 3,
          boundaryMargin: const EdgeInsets.all(250),
          child: GestureDetector(
              onTapUp: (d) {
                for (final n in widget.nodes) {
                  if (positions[n['id']]!.contains(d.localPosition)) {
                    widget.onNode(n);
                    break;
                  }
                }
              },
              child: CustomPaint(
                  size: size,
                  painter: _AxiomPainter(widget.nodes, positions,
                      Theme.of(context).colorScheme)))),
      Positioned(
          right: 8,
          bottom: 8,
          child: FloatingActionButton.small(
              heroTag: 'axiom-map-reset',
              tooltip: 'Ripristina zoom',
              onPressed: () => transform.value = Matrix4.identity()..scale(0.6),
              child: const Icon(Icons.center_focus_strong)))
    ]);
  }
}

class _AxiomPainter extends CustomPainter {
  final List<J> nodes;
  final Map<String, Rect> positions;
  final ColorScheme colors;
  _AxiomPainter(this.nodes, this.positions, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final edge = Paint()
      ..color = colors.outlineVariant
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final n in nodes) {
      final from = positions[n['id']]!;
      for (final id in n['depends'] as List) {
        final to = positions[id];
        if (to == null) continue;
        final a = from.centerLeft, b = to.centerRight;
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(a.dx - 70, a.dy, b.dx + 70, b.dy, b.dx, b.dy);
        canvas.drawPath(path, edge);
        canvas.drawLine(b, b + const Offset(7, -4), edge);
        canvas.drawLine(b, b + const Offset(7, 4), edge);
      }
    }
    for (final n in nodes) {
      final rect = positions[n['id']]!;
      final color = n['type'] == 'primitive'
          ? colors.tertiaryContainer
          : colors.secondaryContainer;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)),
          Paint()..color = color);
      final label = TextPainter(
          text: TextSpan(
              text: '${n['label']}\n${typeName(n['type'] as String)}',
              style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  height: 1.25,
                  color: colors.onSurface)),
          textDirection: TextDirection.ltr,
          maxLines: 3,
          ellipsis: '…')
        ..layout(maxWidth: 194);
      label.paint(canvas, rect.topLeft + const Offset(10, 8));
    }
  }

  @override
  bool shouldRepaint(covariant _AxiomPainter old) =>
      old.nodes != nodes || old.colors != colors;
}

class TeacherModelsPage extends StatefulWidget {
  const TeacherModelsPage({super.key});
  @override
  State<TeacherModelsPage> createState() => _TeacherModelsPageState();
}

class _TeacherModelsPageState extends State<TeacherModelsPage> {
  Timer? timer;
  J data = {};
  bool polling = false, working = false, metered = false;
  String status = '', backend = 'GPU';
  @override
  void initState() {
    super.initState();
    poll();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => poll());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> poll() async {
    if (polling) return;
    polling = true;
    try {
      final d =
          await AxiomStore.channel.invokeMapMethod<String, dynamic>('status');
      if (mounted) setState(() => data = d ?? {});
    } catch (e) {
      if (mounted)
        setState(() => status = 'Runtime Android non disponibile: $e');
    } finally {
      polling = false;
    }
  }

  Future<void> call(String method, [J args = const {}]) async {
    if (working) return;
    setState(() {
      working = true;
      status = 'Operazione: $method…';
    });
    try {
      await AxiomStore.channel.invokeMethod<dynamic>(method, args);
      if (mounted) setState(() => status = 'Operazione completata: $method.');
    } catch (e) {
      if (mounted) setState(() => status = '$e');
    } finally {
      if (mounted) setState(() => working = false);
      await poll();
    }
  }

  Future<void> import() async {
    try {
      final f = await FilePicker.platform
          .pickFiles(type: FileType.any, withData: false);
      if (f?.files.single.path != null)
        await call('import', {'path': f!.files.single.path});
    } catch (e) {
      if (mounted) setState(() => status = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final models = data['models'] as List? ?? [],
        blocked = working || data['busy'] == true;
    String gb(dynamic bytes) =>
        bytes is num ? '${(bytes / 1000000000).toStringAsFixed(2)} GB' : '—';
    return Scaffold(
        appBar: AppBar(title: const Text('Insegnante locale')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Gemma 4 sul dispositivo',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
              'Il modello propone lezioni e controesempi. Il discepolo e il validatore restano separati. Nessun contenuto della mappa viene inviato a un servizio di inferenza remoto.'),
          const SizedBox(height: 8),
          Text(
              'Spazio libero: ${gb(data['freeBytes'])} · RAM disponibile: ${gb(data['availableRam'])}'),
          Text(
              'In RAM: ${data['loaded'] == '' ? 'nessuno' : data['loaded'] ?? 'nessuno'} · ${data['backend'] ?? ''}'),
          if (blocked)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: LinearProgressIndicator()),
          Text(status),
          if (data['phase'] != null) Text('Stato runtime: ${data['phase']}'),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Consenti rete a consumo'),
              subtitle: const Text(
                  'Disattivato: solo Wi-Fi. Il download Android riprende automaticamente dopo interruzioni di rete.'),
              value: metered,
              onChanged: blocked ? null : (v) => setState(() => metered = v)),
          Row(children: [
            const Text('Esecuzione'),
            const SizedBox(width: 16),
            DropdownButton<String>(
                value: backend,
                items: const [
                  DropdownMenuItem(value: 'GPU', child: Text('GPU')),
                  DropdownMenuItem(value: 'CPU', child: Text('CPU'))
                ],
                onChanged: blocked
                    ? null
                    : (v) => setState(() => backend = v ?? 'CPU'))
          ]),
          const Text(
              'Se la GPU non è compatibile, scegli CPU. File, cache e memoria di esecuzione richiedono più spazio del solo modello. Prestazioni e stabilità sul tuo telefono vanno verificate.'),
          for (final m in models)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${m['label']} · ${gb(m['bytes'])}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(m['id'] == 'custom'
                              ? 'File importato: provenienza non certificata.'
                              : 'Apache 2.0 · LiteRT Community · versione e SHA-256 fissati'),
                          if (m['download'] is Map &&
                              ((m['download']['done'] as num? ?? 0) > 0)) ...[
                            LinearProgressIndicator(
                                value: ((m['download']['done'] as num) /
                                        (m['bytes'] as num))
                                    .clamp(0.0, 1.0)),
                            Text(
                                '${gb(m['download']['done'])} / ${gb(m['bytes'])} · stato ${m['download']['status']}'),
                          ],
                          if (m['download']?['status'] == 16)
                            Text(
                                'Download fallito: codice ${m['download']['reason']}. Riparti con Scarica.'),
                          Wrap(spacing: 8, runSpacing: 4, children: [
                            if (m['id'] != 'custom' && m['installed'] != true)
                              FilledButton.icon(
                                  onPressed: blocked
                                      ? null
                                      : () => call('download',
                                          {'id': m['id'], 'metered': metered}),
                                  icon: const Icon(Icons.download),
                                  label: const Text('Scarica')),
                            if (m['download']?['status'] == 8)
                              FilledButton.tonal(
                                  onPressed: blocked
                                      ? null
                                      : () => call('verify', {'id': m['id']}),
                                  child: const Text('Verifica SHA-256')),
                            if (m['installed'] == true)
                              FilledButton.tonal(
                                  onPressed: blocked
                                      ? null
                                      : () => call('load',
                                          {'id': m['id'], 'backend': backend}),
                                  child: const Text('Carica come insegnante')),
                            if (m['download']?['status'] != null &&
                                m['download']?['status'] != 0)
                              TextButton(
                                  onPressed: () =>
                                      call('cancelDownload', {'id': m['id']}),
                                  child: const Text('Annulla download')),
                          ]),
                          ExpansionTile(
                              title: const Text('Fonte e integrità'),
                              children: [
                                SelectableText(
                                    '${m['url'] ?? 'Importazione locale'}\nSHA-256: ${m['sha256']}')
                              ]),
                        ]))),
          OutlinedButton.icon(
              onPressed: blocked ? null : import,
              icon: const Icon(Icons.folder_open),
              label: const Text('Importa altro modello .litertlm')),
          TextButton(
              onPressed: blocked ? null : () => call('unload'),
              child: const Text('Libera il modello dalla RAM')),
          if (blocked)
            OutlinedButton.icon(
                onPressed: () async {
                  await AxiomStore.channel.invokeMethod<void>('cancel');
                  if (mounted)
                    setState(() => status = 'Interruzione richiesta.');
                },
                icon: const Icon(Icons.stop),
                label: const Text('Interrompi operazione')),
          const Text(
              'L’importazione non garantisce compatibilità: servono formato e architettura supportati da LiteRT-LM 0.18.0. GGUF e safetensors non sono accettati da questo runtime.'),
        ])));
  }
}
