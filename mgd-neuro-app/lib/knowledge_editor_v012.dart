import 'package:flutter/material.dart';

import 'brain_admin_v012.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';

class KnowledgeEditor12 extends StatefulWidget {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final ResearchMemory11 research;
  final Future<void> Function(String status) onChanged;
  final Future<void> Function() onExportPack;
  final Future<void> Function() onExportSnapshot;
  final Future<void> Function() onImportSnapshot;

  const KnowledgeEditor12({
    super.key,
    required this.brain,
    required this.world,
    required this.research,
    required this.onChanged,
    required this.onExportPack,
    required this.onExportSnapshot,
    required this.onImportSnapshot,
  });

  @override
  State<KnowledgeEditor12> createState() => _KnowledgeEditor12State();
}

class _KnowledgeEditor12State extends State<KnowledgeEditor12> {
  Future<void> _persist(String message) async {
    setState(() {});
    await widget.onChanged(message);
  }

  Future<List<String>?> _tripleDialog({
    String title = 'Collegamento semantico',
    String subject = '',
    String relation = '',
    String object = '',
  }) async {
    final s = TextEditingController(text: subject);
    final r = TextEditingController(text: relation);
    final o = TextEditingController(text: object);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: s, decoration: const InputDecoration(labelText: 'Soggetto')),
              const SizedBox(height: 8),
              TextField(controller: r, decoration: const InputDecoration(labelText: 'Relazione')),
              const SizedBox(height: 8),
              TextField(controller: o, decoration: const InputDecoration(labelText: 'Oggetto')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(context, [s.text.trim(), r.text.trim(), o.text.trim()]),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    s.dispose();
    r.dispose();
    o.dispose();
    return result;
  }

  Future<void> _addFact() async {
    final v = await _tripleDialog(title: 'Nuovo collegamento');
    if (v == null || v.any((x) => x.isEmpty)) return;
    widget.brain.upsertManualFact12(subject: v[0], relation: v[1], object: v[2]);
    await _persist('Collegamento aggiunto: ${v[0]} — ${v[1]} → ${v[2]}');
  }

  Future<void> _editFact(EditableFact12 fact) async {
    final v = await _tripleDialog(
      title: 'Modifica collegamento',
      subject: fact.subject,
      relation: fact.relation,
      object: fact.object,
    );
    if (v == null || v.any((x) => x.isEmpty)) return;
    widget.brain.replaceFact12(
      fact,
      subject: v[0],
      relation: v[1],
      object: v[2],
    );
    await _persist('Collegamento corretto.');
  }

  Future<void> _deleteFact(EditableFact12 fact) async {
    final ok = await _confirm('Eliminare “${fact.subject} — ${fact.relation} → ${fact.object}”?');
    if (!ok) return;
    widget.brain.deleteFact12(
      subjectId: fact.subjectId,
      relationId: fact.relationId,
      object: fact.object,
      deleteSourceEpisodes: true,
    );
    await _persist('Collegamento eliminato.');
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Conferma'),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sì')),
          ],
        ),
      ) ??
      false;

  Future<void> _renameEntity(EntityMemory04 entity) async {
    final c = TextEditingController(text: entity.label);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rinomina entità'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Nome')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Salva')),
        ],
      ),
    );
    c.dispose();
    if (value == null || value.isEmpty) return;
    widget.brain.renameEntity12(entity.id, value);
    for (final p in widget.world.prototypes) {
      if (p.semanticEntityId == entity.id) p.label = value;
    }
    await _persist('Entità rinominata in “$value”.');
  }

  Future<void> _removeEntityFacts(EntityMemory04 entity) async {
    final ok = await _confirm('Rimuovere tutti i fatti che coinvolgono “${entity.label}”? L’entità resterà disponibile per non spezzare gli ID persistenti.');
    if (!ok) return;
    final n = widget.brain.removeFactsForEntity12(entity.id);
    widget.world.edges.removeWhere((_, e) => e.a == 'e:${entity.id}' || e.b == 'e:${entity.id}');
    await _persist('$n fatti rimossi da ${entity.label}.');
  }

  Future<void> _worldLinkDialog({EditableWorldEdge12? edge}) async {
    final a = TextEditingController(text: edge?.aLabel ?? '');
    final b = TextEditingController(text: edge?.bLabel ?? '');
    var strength = edge?.strength ?? 0.72;
    final result = await showDialog<({String a, String b, double strength})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(edge == null ? 'Nuovo legame geometrico MGD' : 'Modifica legame MGD'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: a, enabled: edge == null, decoration: const InputDecoration(labelText: 'Entità A')),
                const SizedBox(height: 8),
                TextField(controller: b, enabled: edge == null, decoration: const InputDecoration(labelText: 'Entità B')),
                const SizedBox(height: 12),
                Text('Forza ${(strength * 100).round()}%'),
                Slider(value: strength, onChanged: (v) => setLocal(() => strength = v)),
                const Text('Questo modifica direttamente il peso geometrico w e la memoria del legame.'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
            FilledButton(
              onPressed: () => Navigator.pop(context, (a: a.text.trim(), b: b.text.trim(), strength: strength)),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    a.dispose();
    b.dispose();
    if (result == null || result.a.isEmpty || result.b.isEmpty) return;
    if (edge != null) widget.world.deleteWorldEdge12(edge.key);
    widget.world.setEntityWorldEdge12(
      widget.brain,
      entityA: result.a,
      entityB: result.b,
      strength: result.strength,
    );
    await _persist('Legame geometrico MGD aggiornato.');
  }

  Future<void> _rebind(SensoryPrototype06 p) async {
    final c = TextEditingController(text: p.label ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ricollega ${p.modality} #${p.id}'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Entità')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Collega')),
        ],
      ),
    );
    c.dispose();
    if (value == null || value.isEmpty) return;
    widget.world.rebindPrototype12(widget.brain, p.id, value);
    await _persist('Pattern ${p.modality} #${p.id} collegato a $value.');
  }

  Future<void> _editClaim(ResearchClaim11 claim) async {
    final v = await _tripleDialog(
      title: 'Correggi conoscenza ricercata',
      subject: claim.subject,
      relation: claim.relation,
      object: claim.object,
    );
    if (v == null || v.any((x) => x.isEmpty)) return;
    correctResearchClaim12(
      widget.brain,
      widget.research,
      claim,
      subject: v[0],
      relation: v[1],
      object: v[2],
    );
    await _persist('Conoscenza web corretta dall’utente e promossa a fonte umana.');
  }

  Future<void> _quarantineClaim(ResearchClaim11 claim) async {
    quarantineResearchClaim12(widget.brain, claim);
    await _persist('Conoscenza spostata in quarantena.');
  }

  Future<void> _deleteClaim(ResearchClaim11 claim) async {
    final ok = await _confirm('Eliminare la conoscenza ricercata e il corrispondente fatto dal cervello?');
    if (!ok) return;
    widget.brain.deleteFactByLabels12(claim.subject, claim.relation, claim.object, deleteSourceEpisodes: true);
    widget.research.claims.remove(claim.key);
    await _persist('Conoscenza ricercata eliminata.');
  }

  Future<void> _cleanUnsafeWeb() async {
    final n = quarantineUnsafeResearch12(widget.brain, widget.research);
    await _persist('$n conoscenze web deboli/ambigue spostate in quarantena.');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editor MGD'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Fatti'),
              Tab(text: 'Entità'),
              Tab(text: 'Legami'),
              Tab(text: 'Sensori'),
              Tab(text: 'Ricerca'),
              Tab(text: 'Pensieri'),
              Tab(text: 'Backup'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _factsTab(),
            _entitiesTab(),
            _edgesTab(),
            _sensesTab(),
            _researchTab(),
            _thoughtsTab(),
            _backupTab(),
          ],
        ),
      ),
    );
  }

  Widget _factsTab() {
    final facts = widget.brain.editableFacts12();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton.icon(onPressed: _addFact, icon: const Icon(Icons.add_link), label: const Text('Aggiungi nuovo collegamento')),
        const SizedBox(height: 8),
        const Text('Questi sono i fatti semantici usati dal cervello per rispondere e ragionare.'),
        const Divider(),
        ...facts.map((f) => ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text('${f.subject} — ${f.relation} → ${f.object}'),
              subtitle: Text('Confidenza ${(f.confidence * 100).round()}%'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _editFact(f);
                  if (v == 'delete') _deleteFact(f);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifica')),
                  PopupMenuItem(value: 'delete', child: Text('Elimina')),
                ],
              ),
            )),
      ],
    );
  }

  Widget _entitiesTab() {
    final entities = widget.brain.entities.where((e) => e.kind != 'self' && e.kind != 'user').toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Rinomina le entità o rimuovi i fatti collegati senza spezzare gli ID persistenti del cervello.'),
        const Divider(),
        ...entities.map((e) => ListTile(
              leading: const Icon(Icons.circle_outlined),
              title: Text(e.label),
              subtitle: Text('id ${e.id} • ${e.mentions} menzioni • ${e.aliases.length} alias'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'rename') _renameEntity(e);
                  if (v == 'removeFacts') _removeEntityFacts(e);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rinomina')),
                  PopupMenuItem(value: 'removeFacts', child: Text('Rimuovi fatti e legami')),
                ],
              ),
            )),
      ],
    );
  }

  Widget _edgesTab() {
    final edges = widget.world.editableWorldEdges12(widget.brain);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton.icon(onPressed: () => _worldLinkDialog(), icon: const Icon(Icons.add), label: const Text('Aggiungi legame geometrico')),
        const SizedBox(height: 8),
        const Text('I legami MGD controllano prossimità, attivazione, memoria m, materia M e propagazione nel world model.'),
        const Divider(),
        ...edges.map((e) => ListTile(
              leading: Icon(e.active ? Icons.link : Icons.link_off),
              title: Text('${e.aLabel} ↔ ${e.bLabel}'),
              subtitle: Text('forza ${(e.strength * 100).round()}% • w ${e.cost.toStringAsFixed(2)} • m ${e.memory.toStringAsFixed(2)} • M ${e.material.toStringAsFixed(2)} • κ ${e.curvature.toStringAsFixed(2)}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit' && e.a.startsWith('e:') && e.b.startsWith('e:')) await _worldLinkDialog(edge: e);
                  if (v == 'delete') {
                    widget.world.deleteWorldEdge12(e.key);
                    await _persist('Legame MGD eliminato.');
                  }
                },
                itemBuilder: (_) => [
                  if (e.a.startsWith('e:') && e.b.startsWith('e:')) const PopupMenuItem(value: 'edit', child: Text('Modifica forza')),
                  const PopupMenuItem(value: 'delete', child: Text('Elimina')),
                ],
              ),
            )),
      ],
    );
  }

  Widget _sensesTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Puoi correggere direttamente quale entità è associata a ogni pattern visivo o uditivo.'),
        const Divider(),
        ...widget.world.prototypes.map((p) => ListTile(
              leading: Icon(p.modality == 'vision' ? Icons.visibility : Icons.hearing),
              title: Text(p.label ?? '${p.modality} #${p.id}'),
              subtitle: Text('${p.observations} osservazioni • stabilità ${(p.stability * 100).round()}% • entity ${p.semanticEntityId ?? '—'}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'rebind') await _rebind(p);
                  if (v == 'unlink') {
                    widget.world.unlinkPrototype12(p.id);
                    await _persist('Binding sensoriale rimosso.');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rebind', child: Text('Ricollega')),
                  PopupMenuItem(value: 'unlink', child: Text('Scollega')),
                ],
              ),
            )),
      ],
    );
  }

  Widget _researchTab() {
    final claims = widget.research.claims.values.toList()..sort((a, b) => b.lastSeenIso.compareTo(a.lastSeenIso));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton.tonalIcon(onPressed: _cleanUnsafeWeb, icon: const Icon(Icons.cleaning_services), label: const Text('Quarantena conoscenza web debole/ambigua')),
        const SizedBox(height: 8),
        Text('Testi non strutturati conservati: ${widget.research.unresolvedPassages}'),
        const Divider(),
        ...claims.map((c) => ListTile(
              leading: Icon(c.status == 'quarantena' || c.status == 'dubbia' ? Icons.warning_amber : Icons.manage_search),
              title: Text('${c.subject} — ${c.relation} → ${c.object}'),
              subtitle: Text('${c.status.toUpperCase()} • ${(c.confidence * 100).round()}% • ${c.independentSourceCount} famiglie di fonte • ${c.evidenceCount} evidenze'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _editClaim(c);
                  if (v == 'quarantine') _quarantineClaim(c);
                  if (v == 'delete') _deleteClaim(c);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Correggi manualmente')),
                  PopupMenuItem(value: 'quarantine', child: Text('Metti in quarantena')),
                  PopupMenuItem(value: 'delete', child: Text('Elimina')),
                ],
              ),
            )),
      ],
    );
  }

  Widget _thoughtsTab() {
    final thoughts = widget.world.thoughts.reversed.toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            widget.world.clearThoughts12();
            await _persist('Tracce di pensiero ripulite.');
          },
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Pulisci tutti i pensieri'),
        ),
        const Divider(),
        ...thoughts.map((t) => ListTile(
              leading: const Icon(Icons.psychology_alt_outlined),
              title: Text(t.hypothesis),
              subtitle: Text('focus: ${t.focus.join(' · ')} • ${(t.coherence * 100).round()}%'),
              trailing: IconButton(
                onPressed: () async {
                  widget.world.deleteThought12(t);
                  await _persist('Ipotesi eliminata.');
                },
                icon: const Icon(Icons.delete_outline),
              ),
            )),
      ],
    );
  }

  Widget _backupTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Esporta la conoscenza per riutilizzarla o salva l’intero cervello con mondo, sensori, ricerca e stato MGD.'),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: widget.onExportPack, icon: const Icon(Icons.ios_share), label: const Text('Esporta knowledge pack (.mgdpack)')),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(onPressed: widget.onExportSnapshot, icon: const Icon(Icons.backup_outlined), label: const Text('Esporta snapshot completo (.mgdbrain)')),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            await widget.onImportSnapshot();
          },
          icon: const Icon(Icons.restore),
          label: const Text('Importa / ripristina snapshot'),
        ),
        const SizedBox(height: 16),
        const Text('Il knowledge pack contiene fatti e legami semantici ed è portabile. Lo snapshot completo conserva anche episodi, pesi MGD, memoria m/M, pattern sensoriali, pensieri e provenienza della ricerca.'),
      ],
    );
  }
}
