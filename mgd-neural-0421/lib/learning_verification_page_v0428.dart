import 'package:flutter/material.dart';
import 'learning_verification_v0428.dart';
import 'study_goal_v0426.dart';
import 'web_knowledge_explorer_v11.dart';

typedef VerificationRun428 = Future<Map<String, dynamic>> Function(String mode,
    bool Function() cancelled, void Function(int, int, String) progress);

class LearningVerificationCard428 extends StatelessWidget {
  final ResearchMemory11 memory;
  final bool busy;
  final VoidCallback onOpen;
  const LearningVerificationCard428({super.key, required this.memory,
      required this.busy, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final reports = LearningVerification428.reports(memory);
    final id = StudyGoal426.state(memory)?['id'];
    final sources = reports.where((r) => r['mode'] == 'sources' && r['goalId'] == id).firstOrNull;
    final controls = reports.where((r) => r['mode'] == 'controlled').firstOrNull;
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Verifica dell’apprendimento', style: Theme.of(context).textTheme.titleMedium),
      Text(sources == null ? 'Letture conservate: ancora da verificare.'
          : 'Recupero delle letture: ${sources['passed']}/${sources['total']} prove superate.'),
      if (controls != null) ...[
        Text('Casi nuovi simulati: ${controls['passed']}/${controls['total']} prove superate.'),
        const Text('Il risultato riguarda le capacità provate nel modello simulato.'),
      ],
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: busy ? null : onOpen,
          icon: const Icon(Icons.fact_check_outlined), label: const Text('Verifica ciò che ha letto')),
    ])));
  }
}

class LearningVerificationPage428 extends StatefulWidget {
  final ResearchMemory11 memory;
  final VerificationRun428 onRun;
  final Future<void> Function(List<String> topics) onReview;
  const LearningVerificationPage428({super.key, required this.memory,
      required this.onRun, required this.onReview});
  @override
  State<LearningVerificationPage428> createState() => _Page428State();
}

class _Page428State extends State<LearningVerificationPage428> {
  bool running = false, cancelled = false;
  int done = 0, total = 0;
  String stage = '', filter = 'all';
  String? error;
  Map<String, dynamic>? selected;
  @override
  void initState() {
    super.initState();
    selected = LearningVerification428.reports(widget.memory).firstOrNull;
  }
  @override
  void dispose() { cancelled = true; super.dispose(); }

  Future<void> run(String mode) async {
    setState(() { running = true; cancelled = false; error = null; done = 0; total = 0; });
    try {
      final result = await widget.onRun(mode, () => cancelled, (d, t, s) {
        if (mounted) setState(() { done = d; total = t; stage = s; });
      });
      if (mounted && !cancelled) setState(() { selected = result; filter = 'all'; });
    } on VerificationCancelled428 {
      if (mounted) setState(() => error = 'Verifica interrotta. Nessun risultato parziale è stato registrato.');
    } catch (e) {
      if (mounted) setState(() => error = 'Verifica non completata: $e');
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = selected;
    final rows = report == null ? <Map<String, dynamic>>[] : LearningVerification428.rows(report);
    final failures = report == null ? <String>[] : LearningVerification428.failedSubjects(report);
    final history = LearningVerification428.reports(widget.memory);
    return PopScope(canPop: !running, onPopInvokedWithResult: (didPop, _) {
      if (!didPop && running) setState(() => cancelled = true);
    }, child: Scaffold(
      appBar: AppBar(title: const Text('Verifica dell’apprendimento')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('MGD risponde senza nuove ricerche e senza imparare le domande o le risposte attese. '
            'Lo studio automatico riprende quando esci da questa pagina.'),
        const SizedBox(height: 12),
        _choice('Letture conservate',
            'Fino a 8 domande sui fatti documentati dell’obiettivo attuale. '
            'Verifica il recupero e la riformulazione rispetto alle fonti conservate.', 'sources'),
        _choice('Comprensione su casi nuovi',
            '28 prove in 4 mondi simulati, con nomi e condizioni nuovi a ogni esecuzione. '
            'Confronta le risposte prima e dopo la lettura. I testi simulati restano separati dalla tua memoria.', 'controlled'),
        if (running) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: total == 0 ? null : done / total),
          Text('$stage · $done/$total'),
          TextButton(onPressed: () => setState(() => cancelled = true), child: const Text('Interrompi verifica')),
        ],
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (report != null) ...[
          const SizedBox(height: 16),
          Text(report['mode'] == 'controlled' ? 'Risultati sui mondi simulati' : 'Risultati sulle letture conservate',
              style: Theme.of(context).textTheme.titleLarge),
          Text('${report['passed']}/${report['total']} prove superate · versione ${report['version']}'),
          if (report['beforePassed'] != null)
            Text('Prima della lettura: ${report['beforePassed']}/${report['total']}.'),
          Text('Esecuzione: ${report['at']}'),
          if (report['topic'] != null) Text('Obiettivo al momento della prova: ${report['topic']}'),
          if (rows.isEmpty) const Text('Non ci sono ancora fatti documentati idonei per questo obiettivo. '
              'Continua lo studio oppure esegui la prova sui mondi simulati.'),
          if (report['mode'] == 'sources' && rows.isNotEmpty)
            const Text('La risposta attesa deriva dalla proposizione estratta: controlla anche il passaggio originale. '
                'Il punteggio misura il recupero delle fonti, non certifica la loro correttezza scientifica.'),
          if (report['mode'] == 'controlled')
            const Text('Un punteggio alto nel recupero dei fatti non compensa gli errori di applicazione. '
                'Il modello descritto è inventato; queste prove non certificano competenza biologica generale.'),
          const SizedBox(height: 8),
          for (final entry in LearningVerification428.capabilities.entries)
            if (rows.any((r) => r['capability'] == entry.key))
              ListTile(contentPadding: EdgeInsets.zero, title: Text(entry.value),
                trailing: Text('${rows.where((r) => r['capability'] == entry.key && r['passed'] == true).length}'
                    '/${rows.where((r) => r['capability'] == entry.key).length}')),
          if (failures.isNotEmpty && report['goalId'] != null &&
              report['goalId'] == StudyGoal426.state(widget.memory)?['id'])
            OutlinedButton.icon(onPressed: running ? null : () async {
            await widget.onReview(failures);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lacune aggiunte alle priorità dell’obiettivo.')));
          }, icon: const Icon(Icons.school_outlined), label: const Text('Studia le lacune rilevate')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('Tutte le prove'), selected: filter == 'all',
                onSelected: running ? null : (_) => setState(() => filter = 'all')),
            ChoiceChip(label: const Text('Errori e lacune'), selected: filter == 'failed',
                onSelected: running ? null : (_) => setState(() => filter = 'failed')),
          ]),
          for (final row in rows.where((r) => filter == 'all' || r['passed'] != true)) _result(row),
        ],
        if (history.length > 1) ExpansionTile(title: const Text('Esecuzioni precedenti'), children: [
          for (final r in history) ListTile(
            title: Text('${r['mode'] == 'controlled' ? 'Mondi simulati' : 'Letture'} · ${r['passed']}/${r['total']}'),
            subtitle: Text('${r['at']}'),
            onTap: running ? null : () => setState(() { selected = r; filter = 'all'; })),
        ]),
      ]),
    ));
  }

  Widget _choice(String title, String description, String mode) => Card(
    child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium), Text(description),
        const SizedBox(height: 8), FilledButton(onPressed: running ? null : () => run(mode),
            child: const Text('Avvia verifica')),
    ])));

  Widget _result(Map<String, dynamic> row) {
    final answer = row['answer'] as Map? ?? {};
    final before = row['before'] as Map?;
    return ExpansionTile(
      leading: Icon(row['passed'] == true ? Icons.check_circle_outline : Icons.error_outline),
      title: Text('${row['prompt']}'), subtitle: Text('${row['reason']}'),
      childrenPadding: const EdgeInsets.all(12), expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText('Risposta di MGD: ${answer['text']}'),
        if (before != null) SelectableText('Prima della lettura: ${before['text']}'),
        SelectableText('Risposta attesa: ${row['expected'] == 'unknown' ? 'Non determinabile' : row['expected']}'),
        const SizedBox(height: 8),
        for (final source in (row['sources'] as List? ?? []).whereType<Map>())
          SelectableText('Fonte: ${source['title']}\n${source['text']}\n${source['url']}'),
      ]);
  }
}
