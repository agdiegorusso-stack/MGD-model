"""Reviewed integration adjustments, idempotent after dart format."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
p=root/'lib/axioms/axiom_store.dart';s=p.read_text()
if 'knowledgeChanged0430' not in s:
    anchor="    await _db!.transaction((tx) async {"
    assert s.count(anchor)==1
    s=s.replace(anchor,"    final knowledgeChanged0430 = axHash(state['model']) != axHash(next['model']);\n"+anchor)
    old="""      await tx.insert('history', {
        'payload': old,
        'reason': reason,
        'at': DateTime.now().toUtc().toIso8601String()
      });"""
    assert old in s
    s=s.replace(old,"      if (knowledgeChanged0430) {\n"+old+"\n      }")
if 'Future<void> auditAll()' not in s:
    anchor='  Future<void> audit(String id) =>'
    assert anchor in s
    new="""  Future<void> auditAll() => guarded('Ricerca dei componenti superflui su copie della memoria…', () async {
    final revision = student.revision;
    final pending = nodes.where((n) => const ['lexeme','frame','rule','program','guard','write'].contains(n['type']) &&
      (state['audits'] as Map)[n['id']]?['revision'] != revision).take(100).toList();
    final next = copyJ(state);
    var checked = 0, necessary = 0;
    for (final n in pending) {
      if (stopped) break;
      status = 'Audit ${checked+1}/${pending.length}: ${n['label']}. Nessuna cancellazione automatica.'; signal();
      final report = await job('ablate', extra: {'node':n['id']});
      next['audits'][n['id']] = report; checked++;
      if ((report['regressions'] as int) > 0) necessary++;
    }
    (next['events'] as List).add({'kind':'batch_audit','at':DateTime.now().toUtc().toIso8601String(),
      'checked':checked,'necessary_on_tests':necessary,'no_regression_observed':checked-necessary,'revision':revision});
    result = {'tested':checked,'necessary_on_tests':necessary,'no_regression_observed':checked-necessary,
      'absolute_minimality':false,'automatically_deleted':0};
    await _commit(next, 'Audit multiplo senza modificare conoscenze');
    status = 'Audit: $checked componenti; $necessary con controesempi. Nessun nodo cancellato. Le prove completate restano salvate.';
  });
"""
    s=s.replace(anchor,new+anchor)
p.write_text(s)
p=root/'lib/axioms/axiom_page.dart';s=p.read_text()
if "label: const Text('Cerca componenti superflui')" not in s:
    anchor="        OutlinedButton.icon(\n            onPressed: store.busy ? null : store.undo,"
    assert anchor in s
    new="""        OutlinedButton.icon(onPressed: store.busy ? null : store.auditAll,
          icon: const Icon(Icons.manage_search), label: const Text('Cerca componenti superflui')),
        if (store.busy) TextButton.icon(onPressed: store.stop, icon: const Icon(Icons.stop), label: const Text('Interrompi audit')),
"""
    s=s.replace(anchor,new+anchor)
p.write_text(s)
print('Review applied: audits are reversible, cancellable and do not evict knowledge revisions.')
