import 'dart:async';
import 'package:flutter/material.dart';
import 'neural_reading_v0439.dart';
import 'web_knowledge_explorer_v11.dart';

class NeuralReadingPage439 extends StatefulWidget {
  final ResearchMemory11 memory;
  final Future<void> Function() onProcess;
  final Future<void> Function() onSave;
  const NeuralReadingPage439({super.key, required this.memory,
    required this.onProcess, required this.onSave});
  @override
  State<NeuralReadingPage439> createState() => _NeuralReadingPage439State();
}
class _NeuralReadingPage439State extends State<NeuralReadingPage439> {
  bool working = false;
  Timer? _refresh;
  String _seenStatus = '';
  bool _seenBusy = false;
  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (_seenStatus != NeuralReading439.status || _seenBusy != NeuralReading439.busy)) {
        setState(() { _seenStatus = NeuralReading439.status; _seenBusy = NeuralReading439.busy; });
      }
    });
  }
  @override
  void dispose() { _refresh?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final active = working || NeuralReading439.busy;
    final s = NeuralReading439.stats(widget.memory);
    final notes = NeuralReading439.notes(widget.memory).expand((r) =>
      (r['notes'] as List? ?? []).whereType<Map>()).toList();
    return Scaffold(appBar: AppBar(title: const Text('Lettore MGD sperimentale')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Il lettore MGD riconosce ruoli, negazioni e condizioni e cerca '
          'risposte nei brani acquisiti. I suoi pesi sono stati addestrati da zero. '
          'Le capacità sono sperimentali: può sbagliare o non riconoscere una domanda. '
          'Le letture restano disponibili con le loro fonti.'),
        const SizedBox(height: 12),
        Text('${s['examined']}/${s['batches']} gruppi esaminati · ${s['notes']} note · ${s['failed']} da riesaminare'),
        Text(NeuralReading439.status),
        const Text('Il riesame riprende dalle letture salvate mentre l’app è aperta. '
          'Puoi chiedere in Vivi spiegazioni e confronti sui testi acquisiti. '
          'Ogni risposta mostra quanti brani sono stati esaminati rispetto a quelli conservati.'),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: active ? null : () async {
          setState(() => working = true);
          try { await widget.onProcess(); }
          finally { if (mounted) setState(() => working = false); }
        }, icon: const Icon(Icons.psychology_outlined),
          label: Text(active ? 'Riesame in corso…' : 'Esamina il prossimo gruppo')),
        if (active) TextButton(onPressed: () => NeuralReading439.cancel(), child: const Text('Interrompi')),
        OutlinedButton(onPressed: active ? null : () async {
          NeuralReading439.retry(widget.memory); await widget.onSave();
          if (mounted) setState(() {});
        }, child: const Text('Riprova i gruppi senza note')),
        const SizedBox(height: 16),
        ...notes.reversed.take(100).map((n) => Card(child: ExpansionTile(
          title: Text('${n['text']}'), subtitle: const Text('Interpretazione proposta'),
          children: [for (final e in (n['evidence'] as List? ?? []).whereType<Map>())
            Padding(padding: const EdgeInsets.all(12), child: SelectableText(
              '«${e['quote']}»\n${e['title']}\n${e['url']}')),
            if (n['scope443'] != null) Padding(padding:const EdgeInsets.all(12),child:Text(
              'Stato proposto: ${ {'asserted':'affermato','negated':'negato','conditional':'condizionato','planned':'promesso o previsto'}[n['scope443']] ?? n['scope443']}')),
            for (final role in (n['roles443'] as List? ?? []).whereType<Map>())
              Padding(padding:const EdgeInsets.all(8),child:Text(
                '${ {'agent':'Chi agisce','predicate':'Azione','object':'Oggetto','recipient':'Destinatario','time':'Quando','location':'Dove','negation':'Negazione','condition':'Condizione','modal':'Previsione o promessa','reference':'Riferimento','predicate_reference':'Azione con riferimento'}[role['role']] ?? role['role']}: ${role['text']}')),
          ],
        ))),
        if (notes.length > 100) const Text('Sono mostrate le 100 note più recenti. Tutti i brani restano nelle Letture.'),
      ]));
  }
}
