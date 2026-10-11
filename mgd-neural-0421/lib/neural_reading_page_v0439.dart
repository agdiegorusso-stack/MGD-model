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
  @override
  Widget build(BuildContext context) {
    final s = NeuralReading439.stats(widget.memory);
    final notes = NeuralReading439.notes(widget.memory).expand((r) =>
      (r['notes'] as List? ?? []).whereType<Map>()).toList();
    return Scaffold(appBar: AppBar(title: const Text('Lettore neurale locale')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Qwen3 0.6B interpreta i brani sul dispositivo. '
          'MGD conserva fonti e letture; i pesi di Qwen restano fissi. '
          'Le note sono interpretazioni proposte: un riferimento valido non prova '
          'che la nota sia corretta.'),
        const SizedBox(height: 12),
        Text('${s['examined']}/${s['batches']} gruppi esaminati · ${s['notes']} note · ${s['failed']} da riesaminare'),
        Text(NeuralReading439.status),
        const Text('Il riesame riprende dalle letture salvate mentre l’app è aperta. '
          'Puoi chiedere in Vivi spiegazioni e confronti sui testi acquisiti.'),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: working ? null : () async {
          setState(() => working = true);
          try { await widget.onProcess(); }
          finally { if (mounted) setState(() => working = false); }
        }, icon: const Icon(Icons.psychology_outlined),
          label: Text(working ? 'Riesame in corso…' : 'Esamina il prossimo gruppo')),
        if (working) TextButton(onPressed: () => NeuralReading439.cancel(), child: const Text('Interrompi')),
        OutlinedButton(onPressed: working ? null : () async {
          NeuralReading439.retry(widget.memory); await widget.onSave();
          if (mounted) setState(() {});
        }, child: const Text('Riprova i gruppi senza note')),
        const SizedBox(height: 16),
        ...notes.reversed.take(100).map((n) => Card(child: ExpansionTile(
          title: Text('${n['text']}'), subtitle: const Text('Interpretazione proposta'),
          children: [for (final e in (n['evidence'] as List? ?? []).whereType<Map>())
            Padding(padding: const EdgeInsets.all(12), child: SelectableText(
              '«${e['quote']}»\n${e['title']}\n${e['url']}'))],
        ))),
        if (notes.length > 100) const Text('Sono mostrate le 100 note più recenti. Tutti i brani restano nelle Letture.'),
      ]));
  }
}
