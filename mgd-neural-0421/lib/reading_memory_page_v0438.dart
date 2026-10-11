import 'package:flutter/material.dart';
import 'reading_memory_v0438.dart';
import 'web_knowledge_explorer_v11.dart';

class ReadingMemoryPage438 extends StatefulWidget {
  final ResearchMemory11 memory;
  final String? initialTopic;
  const ReadingMemoryPage438({super.key, required this.memory, this.initialTopic});
  @override
  State<ReadingMemoryPage438> createState() => _ReadingPage438State();
}

class _ReadingPage438State extends State<ReadingMemoryPage438> {
  final input = TextEditingController();
  String query = '';
  int shown = 40;
  @override
  void initState() {
    super.initState();
    input.text = widget.initialTopic ?? '';
    query = input.text;
  }
  @override
  void dispose() { input.dispose(); super.dispose(); }
  void search() => setState(() { query = input.text.trim(); shown = 40; });
  @override
  Widget build(BuildContext context) {
    final all = ReadingMemory438.rows(widget.memory);
    final reply = query.isEmpty ? null : ReadingMemory438.answer(widget.memory,
        'Parlami di $query', limit: 20, explicitSearch: true);
    final q = ReadingMemory438.terms(query);
    final filtered = query.isEmpty ? all : all.where((r) => q.every((t) =>
      ReadingMemory438.terms('${r['text']} ${r['title']} '
        '${(r['topics438'] as List? ?? []).join(' ')}').contains(t))).toList();
    return Scaffold(appBar: AppBar(title: const Text('Letture')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${all.length} passaggi conservati · '
          '${all.map((r) => r['url']).toSet().length} fonti'),
        const Text('Qui trovi anche le informazioni che il lettore non ha '
          'trasformato in relazioni. In chat puoi interrogarle con le fonti.'),
        const SizedBox(height: 12),
        TextField(controller: input, onSubmitted: (_) => search(),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(labelText: 'Argomento o parole nel testo',
            suffixIcon: IconButton(onPressed: search, icon: const Icon(Icons.search)))),
        const SizedBox(height: 12),
        Text('${filtered.length} passaggi pertinenti'),
        if (query.isNotEmpty && reply?.missing == true) Text(reply!.text),
        for (final row in filtered.take(shown)) Card(child: Padding(
          padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['title']}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8), SelectableText('${row['text']}'),
              const SizedBox(height: 8), SelectableText('Fonte: ${row['url']}'),
            ]))),
        if (filtered.length > shown) OutlinedButton(
          onPressed: () => setState(() => shown += 40),
          child: const Text('Mostra altri passaggi')),
        if (filtered.isEmpty) const Text('Nessun passaggio trovato per queste parole.'),
      ]));
  }
}
