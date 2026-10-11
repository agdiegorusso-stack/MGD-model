import 'package:flutter/material.dart';
import 'plastic_language_brain_v04.dart';
import 'predictive_memory_v0437.dart';

class PredictiveMemoryPage437 extends StatefulWidget {
  final PlasticLanguageBrain04 brain;
  final Future<void> Function() onSave;
  const PredictiveMemoryPage437({super.key, required this.brain, required this.onSave});
  @override
  State<PredictiveMemoryPage437> createState() => _PredictiveMemoryPage437State();
}

class _PredictiveMemoryPage437State extends State<PredictiveMemoryPage437> {
  final _context = TextEditingController();
  List<TokenPrediction437> _predictions = [];
  bool _training = false;
  String _status = '';
  @override
  void dispose() { _context.dispose(); super.dispose(); }

  void _predict() {
    final ids = widget.brain.predictiveContext437(_context.text);
    setState(() {
      _predictions = widget.brain.predictor437.predict(ids,
          recall: widget.brain.predictionRecall437)
          .where((p) => p.token > 0 && p.token < widget.brain.assemblies.length)
          .take(5).toList();
      _status = widget.brain.predictor437.ready
          ? 'Previsione dal modello appreso.' : 'Il modello richiede ancora allenamento.';
    });
  }

  Future<void> _rehearse() async {
    setState(() { _training = true; _status = 'Ripasso dei testi osservati…'; });
    try {
      // Past agent outputs are deliberately excluded from supervised targets.
      final texts = widget.brain.episodes.reversed.take(128)
          .map((e) => e.userText).toList().reversed.toList();
      var done = 0;
      for (final text in texts) {
        widget.brain.learnPredictiveText437(text);
        done++;
        if (mounted) setState(() => _status = '$done / ${texts.length} testi osservati');
        await Future<void>.delayed(Duration.zero);
      }
      widget.brain.predictor437.replay(cycles: 64);
      await widget.onSave();
      if (mounted) setState(() => _status = '$done testi ripassati. Pesi e replay salvati.');
    } catch (e) {
      if (mounted) setState(() => _status = 'Ripasso o salvataggio incompleto: $e');
    } finally {
      if (mounted) setState(() => _training = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.brain.predictor437;
    final validation = model.validation();
    return PopScope(
      canPop: !_training,
      child: Scaffold(
        appBar: AppBar(title: const Text('Previsioni apprese')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Il modello impara la prossima parola dai testi letti o insegnati. '
              'Usa l’ordine delle parole e i richiami MGD. Ogni errore corregge i pesi.'),
          const SizedBox(height: 16),
          Text('Aggiornamenti: ${model.updates} · Testi osservati: ${model.exposures}'),
          Text('Vocabolario del predittore: ${model.vocabulary} / ${PredictiveMemory437.maxVocabulary - 1}'),
          Text('Esempi nel replay: ${model.replayExamples}'),
          if (model.updates > 0)
            Text('Errore prima degli aggiornamenti: ${model.lossEma.toStringAsFixed(3)}'),
          if (validation.examples > 0) ...[
            Text('Controllo su ${validation.examples} esempi riservati: '
                'errore ${validation.loss.toStringAsFixed(3)}, '
                'corrette ${(validation.accuracy * 100).toStringAsFixed(1)}%'),
            const Text('Il controllo usa sequenze escluse dagli aggiornamenti dei pesi '
                'e richiami di memoria congelati alla prima osservazione.'),
          ] else
            const Text('Controllo disponibile dopo l’acquisizione di altri testi.'),
          if (model.skippedTargets > 0)
            Text('Obiettivi oltre il limite del vocabolario: ${model.skippedTargets}'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _training ? null : _rehearse,
            icon: const Icon(Icons.school_outlined),
            label: const Text('Ripassa testi già osservati')),
          const Text('Per aggiungere testi usa Impara. Anche le nuove letture durante '
              'lo studio allenano il predittore.'),
          if (_training) const LinearProgressIndicator(),
          const SizedBox(height: 24),
          TextField(controller: _context, enabled: !_training,
            decoration: const InputDecoration(labelText: 'Inizio della frase',
                hintText: 'Scrivi un contesto da completare'),
            onSubmitted: (_) => _predict()),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _training ? null : _predict,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Prevedi la prossima parola')),
          for (final p in _predictions) ListTile(
            title: Text(p.token == 1 ? 'Fine della frase' : widget.brain.assemblies[p.token].surface),
            trailing: Text('${(p.probability * 100).toStringAsFixed(1)}%')),
          const SizedBox(height: 12),
          Text(_status),
          const SizedBox(height: 16),
          const Text('Le probabilità riguardano il linguaggio. La verifica dei fatti '
              'continua a usare letture, fonti e memoria relazionale.'),
        ]),
      ),
    );
  }
}
