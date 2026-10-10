import 'package:flutter/material.dart';
import 'learning_verification_v0428.dart';
import 'study_goal_v0426.dart';
import 'web_knowledge_explorer_v11.dart';

typedef VerificationRun428 = Future<Map<String, dynamic>> Function(String mode,
    bool Function() cancelled, void Function(int, int, String) progress);
typedef CustomVerificationRun430 = Future<Map<String, dynamic>> Function(String text,
    List<String> questions, bool Function() cancelled, void Function(int, int, String) progress);

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
    final transfer = reports.where((r) => r['mode'] == 'transfer').firstOrNull;
    final prose = reports.where((r) => r['mode'] == 'prose').firstOrNull;
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Verifica dell’apprendimento', style: Theme.of(context).textTheme.titleMedium),
      Text(sources == null ? 'Letture conservate: ancora da verificare.'
          : 'Recupero delle letture: ${sources['passed']}/${sources['total']} prove superate.'),
      if (controls != null) ...[
        Text('Casi nuovi simulati: ${controls['passed']}/${controls['total']} prove superate.'),
        if (controls['version'] != null) Text('Misurati con la versione ${controls['version']}.'),
        if (controls['version'] != null && controls['version'] != '0.42.11')
          const Text('Ripeti la verifica per misurare il motore aggiornato.'),
        const Text('Il risultato riguarda le capacità provate nel modello simulato.'),
      ],
      if (transfer != null) Text('Regole in contesti nuovi: ${transfer['passed']}/${transfer['total']} prove superate.'),
      if (prose != null) Text('Esempio sull’osmosi: ${prose['passed']}/${prose['total']} prove superate.'),
      const Text('Recuperare fatti e applicare regole sono capacità diverse. Controlla le risposte e le fonti.'),
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
  final CustomVerificationRun430? onCustom;
  const LearningVerificationPage428({super.key, required this.memory,
      required this.onRun, required this.onReview, this.onCustom});
  @override
  State<LearningVerificationPage428> createState() => _Page428State();
}

class _Page428State extends State<LearningVerificationPage428> {
  bool running = false, cancelled = false;
  int done = 0, total = 0;
  String stage = '', filter = 'all';
  String? error;
  Map<String, dynamic>? selected;
  final customText = TextEditingController(), customQuestions = TextEditingController();
  @override
  void initState() {
    super.initState();
    selected = LearningVerification428.reports(widget.memory).firstOrNull;
  }
  @override
  void dispose() { cancelled = true; customText.dispose(); customQuestions.dispose(); super.dispose(); }

  Future<void> runCustom() async {
    final text = customText.text.trim();
    final questions = customQuestions.text.split('\n').map((s) => s.trim())
        .where((s) => s.isNotEmpty).toList();
    if (text.isEmpty || questions.isEmpty || text.length > 12000 ||
        questions.length > 10 || questions.any((q) => q.length > 1000 || !q.endsWith('?'))) {
      setState(() => error = 'Inserisci un testo (massimo 12.000 caratteri) e da 1 a 10 domande, '
          'una per riga, ciascuna con il punto interrogativo.');
      return;
    }
    setState(() { running = true; cancelled = false; error = null; done = 0; total = questions.length; });
    try {
      final report = await widget.onCustom!(text, questions, () => cancelled, (d, t, s) {
        if (mounted) setState(() { done = d; total = t; stage = s; });
      });
      if (mounted && !cancelled) setState(() { selected = report; filter = 'all'; });
    } on VerificationCancelled428 {
      if (mounted) setState(() => error = 'Verifica interrotta. Nessun risultato parziale è stato registrato.');
    } catch (e) {
      if (mounted) setState(() => error = 'Verifica non completata: $e');
    } finally { if (mounted) setState(() => running = false); }
  }

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
    final passages = rows.isEmpty ? <Map>[] :
        (rows.first['sources'] as List? ?? []).whereType<Map>().toList();
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
        _choice('Regole su cellule simulate',
            '28 prove in 4 mondi simulati, con nomi e condizioni nuovi a ogni esecuzione. '
            'Confronta le risposte prima e dopo la lettura. I testi simulati restano separati dalla tua memoria.', 'controlled'),
        _choice('Regole in contesti nuovi',
            '24 prove su dispositivi simulati: catene di regole, condizioni mancanti, '
            'negazioni e conflitti. Le risposte mostrano le premesse usate.', 'transfer'),
        _choice('Testo sull’osmosi',
            'Legge un paragrafo didattico e risponde a 12 domande su ingresso e uscita dell’acqua, '
            'cambio di condizioni e spiegazione dei passaggi. Il risultato riguarda questo esempio.', 'prose'),
        if (widget.onCustom != null) Card(child: ExpansionTile(
          title: const Text('Prova un testo tuo'),
          subtitle: const Text('Scegli tu il testo e le domande. Le risposte restano da valutare.'),
          childrenPadding: const EdgeInsets.all(12),
          children: [
            TextField(controller: customText, enabled: !running, minLines: 4, maxLines: 8,
                decoration: const InputDecoration(labelText: 'Testo da leggere', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: customQuestions, enabled: !running, minLines: 3, maxLines: 6,
                decoration: const InputDecoration(labelText: 'Domande: una per riga', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            const Text('Inserisci soltanto il testo e le domande. Le risposte attese non vengono date al motore. '
                'La prova usa una memoria temporanea e mostra il confronto prima e dopo la lettura.'),
            FilledButton(onPressed: running ? null : runCustom, child: const Text('Leggi e rispondi')),
          ],
        )),
        if (running) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: total == 0 ? null : done / total),
          Text('$stage · $done/$total'),
          TextButton(onPressed: () => setState(() => cancelled = true), child: const Text('Interrompi verifica')),
        ],
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (report != null) ...[
          const SizedBox(height: 16),
          Text(report['mode'] == 'custom' ? 'Risposte al tuo testo' : report['mode'] == 'prose'
              ? 'Risultati sul testo didattico' : report['mode'] != 'sources'
              ? 'Risultati sui mondi simulati' : 'Risultati sulle letture conservate',
              style: Theme.of(context).textTheme.titleLarge),
          Text(report['mode'] == 'custom' ? '${report['total']} risposte da valutare · versione ${report['version']}'
              : '${report['passed']}/${report['total']} prove superate · versione ${report['version']}'),
          if (report['beforePassed'] != null)
            Text('Prima della lettura: ${report['beforePassed']}/${report['total']}.'),
          Text('Esecuzione: ${report['at']}'),
          if (report['mode'] == 'sources' && report['topic'] != null)
            Text('Obiettivo al momento della prova: ${report['topic']}'),
          if (rows.isEmpty) const Text('Non ci sono ancora fatti documentati idonei per questo obiettivo. '
              'Continua lo studio oppure esegui la prova sui mondi simulati.'),
          if (report['mode'] == 'sources' && rows.isNotEmpty)
            const Text('La risposta attesa deriva dalla proposizione estratta: controlla anche il passaggio originale. '
                'Il punteggio misura il recupero delle fonti, non certifica la loro correttezza scientifica.'),
          if (report['mode'] == 'prose' || report['mode'] == 'custom')
            ExpansionTile(title: const Text('Testo letto'), initiallyExpanded: true,
              children: [SelectableText('${passages.firstOrNull?['text'] ?? ''}')]),
          if (report['mode'] == 'controlled' || report['mode'] == 'transfer')
            const Text('Un punteggio alto nel recupero dei fatti non compensa gli errori di applicazione. '
                'Il modello descritto è inventato; queste prove non certificano competenza biologica generale.'),
          const SizedBox(height: 8),
          for (final entry in LearningVerification428.capabilities.entries)
            if (rows.any((r) => r['capability'] == entry.key))
              ListTile(contentPadding: EdgeInsets.zero, title: Text(report['mode'] == 'sources' &&
                  entry.key == 'paraphrase' ? 'Recupero con domanda specifica' : entry.value),
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
            if (report['mode'] != 'custom') ChoiceChip(label: const Text('Errori e lacune'), selected: filter == 'failed',
                onSelected: running ? null : (_) => setState(() => filter = 'failed')),
          ]),
          for (final row in rows.where((r) => filter == 'all' || r['passed'] != true)) _result(row),
        ],
        if (history.length > 1) ExpansionTile(title: const Text('Esecuzioni precedenti'), children: [
          for (final r in history) ListTile(
            title: Text(r['mode'] == 'custom' ? 'Testo tuo · ${r['total']} risposte da valutare'
                : '${r['mode'] == 'prose' ? 'Osmosi' : r['mode'] == 'transfer' ? 'Regole nuove' : r['mode'] == 'controlled' ? 'Mondi simulati' : 'Letture'} · ${r['passed']}/${r['total']}'),
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
    final names = (row['names'] as Map? ?? {}).map((k, v) => MapEntry('$k', '$v'));
    String readable(Object? input) {
      var text = '$input';
      final keys = names.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
      for (final key in keys) { text = text.replaceAll(key, names[key]!); }
      return text;
    }
    final expected = switch (row['expected']) {
      'unknown' => 'Non determinabile', 'conflict' => 'Premesse in conflitto',
      'si' => 'Sì', 'no' => 'No', _ => readable(row['expected']),
    };
    final fullAnswer = readable(answer['text'] ?? 'Nessuna risposta registrata.');
    final preview = fullAnswer.split('\n').firstWhere((line) => line.trim().isNotEmpty &&
        !line.startsWith('Fatti documentati') && !line.startsWith('Dal testo,'), orElse: () => fullAnswer);
    return ExpansionTile(
      leading: Icon(row['passed'] == null ? Icons.rate_review_outlined
          : row['passed'] == true ? Icons.check_circle_outline : Icons.error_outline),
      title: Text(readable(row['prompt'])), subtitle: Text('MGD: $preview'),
      childrenPadding: const EdgeInsets.all(12), expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${row['reason']}'),
        SelectableText('Risposta di MGD: $fullAnswer'),
        if (before != null) SelectableText('Prima della lettura: ${readable(before['text'])}'),
        if (row['expected'] != null) SelectableText('Risposta attesa: $expected'),
        const SizedBox(height: 8),
        for (final source in (row['sources'] as List? ?? []).whereType<Map>())
          SelectableText(readable('Fonte: ${source['title']}\n${source['text']}\n${source['url']}')),
      ]);
  }
}
