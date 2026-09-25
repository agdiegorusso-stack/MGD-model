import 'package:flutter/material.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';

/// These controls belong to a specific question, not a missing QA prompt.
class CuriosityActions316 extends StatefulWidget {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final String questionKey;
  final bool busy;
  final ValueChanged<bool> onBusy;
  final Future<void> Function(String, String) onResult;
  const CuriosityActions316({super.key, required this.brain, required this.world,
    required this.questionKey, required this.busy, required this.onBusy, required this.onResult});
  @override
  State<CuriosityActions316> createState() => _CuriosityActions316State();
}

class _CuriosityActions316State extends State<CuriosityActions316> {
  bool _running = false;
  bool get _active => widget.world.pendingCuriosityKey316 == widget.questionKey;
  Future<void> _act(String action) async {
    if (_running || widget.busy || !_active) return;
    final releaseBusy = widget.onBusy;
    setState(() => _running = true);
    widget.onBusy(true);
    try {
      _CuriosityReply316? reply;
      if (action == 'Salta') {
        reply = const _CuriosityReply316(skip: true);
      } else {
        final ids = List<int>.from(widget.world.pendingCuriosityEntities09);
        final relation = widget.world.pendingCuriosityType09 == 'relation';
        if (relation && (ids.length != 2 || ids.any((id) => id < 0 || id >= widget.brain.entities.length))) {
          throw StateError('Gli elementi della domanda non sono più disponibili.');
        }
        reply = await showDialog<_CuriosityReply316>(context: context,
          builder: (_) => _CuriosityDialog316(action: action, relation: relation,
            a: relation ? widget.brain.entities[ids[0]].label : '',
            b: relation ? widget.brain.entities[ids[1]].label : ''));
      }
      if (!mounted || reply == null || !_active) return;
      late String acknowledgement;
      late String userText;
      if (reply.skip || reply.reject) {
        widget.world.dismissCuriosity316(expectedKey: widget.questionKey);
        userText = reply.reject ? 'Scarta questa associazione' : 'Salta';
        acknowledgement = reply.reject
            ? 'Ho ritirato la domanda. Non ho cancellato fatti e non ho aggiunto categorie o relazioni.'
            : 'Domanda saltata. Non ho aggiunto categorie o relazioni.';
      } else if (reply.relation != null) {
        userText = 'Relazione indicata: ${reply.relation}${reply.reverse ? ' (verso invertito)' : ''}';
        acknowledgement = widget.world.teachCuriosityRelation316(widget.brain,
          expectedKey: widget.questionKey, relation: reply.relation!, reverse: reply.reverse);
      } else {
        userText = reply.label;
        acknowledgement = widget.world.consumeCuriosityAnswer316(widget.brain, reply.label) ??
            'Non ho riconosciuto una risposta. La domanda resta aperta.';
      }
      await widget.onResult(userText, acknowledgement);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Operazione o salvataggio non completato: $e')));
    } finally {
      if (mounted) setState(() => _running = false);
      // Appending replies may recycle this ListView item while saving.
      releaseBusy(false);
    }
  }
  @override
  Widget build(BuildContext context) {
    if (!_active) return const Padding(padding: EdgeInsets.only(top: 8),
        child: Text('Domanda chiusa', key: ValueKey('curiosity-closed')));
    return Wrap(spacing: 4, runSpacing: 2, children: [
      for (final item in const <String, IconData>{
        'Rispondi': Icons.reply, 'Salta': Icons.skip_next_outlined,
        'Correggi': Icons.edit_outlined, 'Aggiungi variazione': Icons.add_circle_outline,
      }.entries)
        TextButton.icon(key: ValueKey('curiosity-${item.key}'),
          onPressed: (_running || widget.busy) ? null : () => _act(item.key),
          icon: Icon(item.value, size: 18), label: Text(item.key)),
    ]);
  }
}

class _CuriosityReply316 {
  final String? relation;
  final String label;
  final bool reverse, skip, reject;
  const _CuriosityReply316({this.relation, this.label = '', this.reverse = false,
      this.skip = false, this.reject = false});
}
class _CuriosityDialog316 extends StatefulWidget {
  final String action, a, b;
  final bool relation;
  const _CuriosityDialog316({required this.action, required this.relation,
      required this.a, required this.b});
  @override
  State<_CuriosityDialog316> createState() => _CuriosityDialog316State();
}
class _CuriosityDialog316State extends State<_CuriosityDialog316> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  String? _relation;
  bool _reverse = false;
  @override
  void dispose() { _label.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.action == 'Rispondi' ? 'Rispondi alla domanda' : widget.action),
    scrollable: true,
    content: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.relation
          ? 'Indica una relazione esplicita. Non darò un nome di categoria al gruppo.'
          : 'Dai un nome alla percezione. La domanda non diventerà una coppia domanda/risposta appresa.'),
      const SizedBox(height: 14),
      if (widget.relation) ...[
        Text(_reverse ? widget.b : widget.a, key: const ValueKey('relation-subject')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: _relation, isExpanded: true,
          key: const ValueKey('relation-kind'),
          decoration: const InputDecoration(labelText: 'Relazione', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'is_a', child: Text('È un tipo di')),
            DropdownMenuItem(value: 'part_of', child: Text('È parte di')),
            DropdownMenuItem(value: 'ha', child: Text('Ha')),
            DropdownMenuItem(value: 'related_to', child: Text('È collegato a')),
            DropdownMenuItem(value: 'used_for', child: Text('Serve a')),
          ],
          validator: (v) => v == null ? 'Scegli una relazione prima di salvare.' : null,
          onChanged: (v) => setState(() => _relation = v)),
        const SizedBox(height: 8),
        Text(_reverse ? widget.a : widget.b, key: const ValueKey('relation-object')),
        SwitchListTile(contentPadding: EdgeInsets.zero,
          title: const Text('Inverti il verso'), value: _reverse,
          onChanged: (v) => setState(() => _reverse = v)),
      ] else TextFormField(controller: _label, autofocus: true,
        key: const ValueKey('perception-label'), maxLines: 3, minLines: 1,
        decoration: const InputDecoration(labelText: 'Nome della percezione', border: OutlineInputBorder()),
        validator: (v) => v == null || v.trim().isEmpty ? 'Scrivi un nome.' : null),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
      if (widget.action == 'Correggi') TextButton(
        onPressed: () => Navigator.pop(context, const _CuriosityReply316(reject: true)),
        child: const Text('Scarta associazione')),
      FilledButton(onPressed: () {
        if (_form.currentState!.validate()) Navigator.pop(context,
          _CuriosityReply316(relation: widget.relation ? _relation : null,
              reverse: _reverse, label: _label.text.trim()));
      }, child: const Text('Salva')),
    ],
  );
}

/// Controller lifetime belongs to the route, including its closing animation.
Future<String?> showTextDialog316(BuildContext context, {required String title,
    required String hint, String initial = '', String confirm = 'Impara'}) =>
  showDialog<String>(context: context, builder: (_) => _TextDialog316(
    title: title, hint: hint, initial: initial, confirm: confirm));
class _TextDialog316 extends StatefulWidget {
  final String title, hint, initial, confirm;
  const _TextDialog316({required this.title, required this.hint, required this.initial, required this.confirm});
  @override
  State<_TextDialog316> createState() => _TextDialog316State();
}
class _TextDialog316State extends State<_TextDialog316> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(widget.title),
    scrollable: true,
    content: TextField(controller: _controller, autofocus: true, minLines: 2, maxLines: 6,
      decoration: InputDecoration(hintText: widget.hint, border: const OutlineInputBorder())),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
      FilledButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: Text(widget.confirm))]);
}
