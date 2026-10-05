import 'package:flutter/material.dart';
import 'web_knowledge_explorer_v11.dart';

class SourceMemoryPage323 extends StatefulWidget {
  final ResearchMemory11 memory;
  const SourceMemoryPage323({super.key, required this.memory});
  @override
  State<SourceMemoryPage323> createState() => _SourceMemoryPage323State();
}

class _SourceMemoryPage323State extends State<SourceMemoryPage323> {
  final controller = TextEditingController();
  late List<Map<String, dynamic>> all;
  String query = '';
  @override
  void initState() {
    super.initState();
    all = SourceMemory323.rows(widget.memory);
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final hits = query.isEmpty ? null : SourceMemory323.search(query, widget.memory, limit: 100);
    final shown = hits == null ? all : hits.map((h) =>
      <String,dynamic>{'text':h.text,'title':h.title,'url':h.url,'provider':h.provider}).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Passaggi e fonti')),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Testi conservati, anche quando non diventano fatti. '
                'La presenza di un passaggio non ne certifica la correttezza.'),
            const SizedBox(height: 12),
            TextField(controller: controller,
              decoration: const InputDecoration(labelText: 'Cerca nel testo',
                prefixIcon: Icon(Icons.search)),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => setState(() => query = value.trim())),
            const SizedBox(height: 8),
            Text(query.isEmpty ? all.length.toString() + ' passaggi conservati' :
              shown.length.toString() + ' risultati (massimo 100)'),
          ])),
        Expanded(child: shown.isEmpty
          ? const Center(child: Text('Nessun passaggio pertinente trovato.'))
          : ListView.builder(itemCount: shown.length, itemBuilder: (context, i) {
              final row = shown[i];
              return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row['title'].toString(), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SelectableText(row['text'].toString()),
                      const SizedBox(height: 8),
                      SelectableText(row['provider'].toString() + '\n' + row['url'].toString()),
                    ])));
            })),
      ])),
    );
  }
}
