import 'package:flutter/material.dart';
import 'study_goal_v0426.dart';
import 'web_knowledge_explorer_v11.dart';

class StudyGoalCard426 extends StatelessWidget {
  final ResearchMemory11 memory;
  final bool busy;
  final Future<void> Function(String) onStart;
  final Future<void> Function(bool) onPause;
  final Future<void> Function() onRetry;
  const StudyGoalCard426({super.key, required this.memory,
    required this.busy, required this.onStart, required this.onPause,
    required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final g = StudyGoal426.state(memory);
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Obiettivo di studio', style: Theme.of(context).textTheme.titleMedium),
        Text(StudyGoal426.summary(memory)),
        if (busy) ...[
          const LinearProgressIndicator(),
          const Text('Ricerca e lettura in corso…'),
        ],
        if (g?['lastLookup'] != null)
          Text('Ultima ricerca: ${g!['lastLookup']} · '
              '${g['lastDocuments']} documenti leggibili.'),
        if (g?['lastArea'] != null) Text('Area: ${g!['lastArea']}'),
        if (g != null && (g['lastError'] ?? memory.lastError) != null)
          Text('Ultimo tentativo senza letture: '
              '${g['lastError'] ?? memory.lastError}',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (g != null && g['lastError'] != null && g['paused'] != true)
          const Text('Il piano prosegue con le altre aree disponibili e riprova quelle mancanti.'),
        const Text('Studia mentre l’app è aperta. Salva il piano e riprende '
          'alla riapertura. Le letture non certificano di sapere tutto.'),
        if (g != null) ExpansionTile(title: const Text('Piano e lacune'),
          children: StudyGoal426.items(g).map((i) => ListTile(
            title: Text('${i['label']}'),
            subtitle: Text('${StudyGoal426.count(i, 'documents')} letture, '
              '${StudyGoal426.count(i, 'novel')} testi nuovi; '
              '${(i['families'] as List).length} famiglie di fonti. '
              'Comprensione da verificare.'
              '${i['lastError'] == null ? '' : '\nUltimo errore: ${i['lastError']}'}'),
          )).toList()),
        if (g?['diagnostics'] is List)
          ExpansionTile(title: const Text('Esito delle fonti'), children:
            (g!['diagnostics'] as List).whereType<Map>().map((d) => ListTile(
              title: Text('${d['provider']}: ${d['status']}'),
              subtitle: d['error'] == null && d['title'] == null ? null
                  : Text('${d['error'] ?? d['title']}'),
            )).toList()),
        Wrap(spacing: 8, children: [
          FilledButton.icon(onPressed: busy ? null : () async {
            var input = ''; 
            final topic = await showDialog<String>(context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Dagli un obiettivo'),
                content: TextField(maxLength: 240, onChanged: (value) => input = value,
                  decoration: const InputDecoration(
                    hintText: 'Studia tutto ciò che riguarda la cellula'),
                  onSubmitted: (s) => Navigator.of(ctx).pop(s)),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Annulla')),
                  FilledButton(onPressed: () => Navigator.of(ctx).pop(input),
                    child: const Text('Avvia studio')),
                ]));
            if (topic != null && topic.trim().isNotEmpty) {
              await onStart(StudyGoal426.command(topic) ?? topic.trim());
            }
          }, icon: const Icon(Icons.flag), label: const Text('Nuovo obiettivo')),
          if (g != null) OutlinedButton(
            onPressed: busy ? null : () => onPause(g['paused'] != true),
            child: Text(g['paused'] == true ? 'Riprendi' : 'Pausa')),
          if (g != null && (g['lastError'] ?? memory.lastError) != null)
            OutlinedButton(onPressed: busy || g['paused'] == true ? null : onRetry,
              child: const Text('Riprova ora')),
        ]),
      ])));
  }
}
