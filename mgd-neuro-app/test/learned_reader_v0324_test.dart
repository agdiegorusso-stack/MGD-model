import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/learned_reader_v0324.dart';
import 'package:mgd_neuro_mobile/relational_memory_v0324.dart';
import 'package:mgd_neuro_mobile/relational_memory_page_v0324.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'package:mgd_neuro_mobile/navigable_graph_v013.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/mgd_language_v020.dart';

void main() {
  test('learned roles: active, passive, multiword novel entities and negation',() {
    for(final text in ['Il gatto insegue il topo.','Il topo è inseguito dal gatto.',
      'Il topo viene rincorso dal gatto.']) {
      final f=LearnedReader324.parse(text);
      expect(f,isNotNull,reason:text);
      expect(f!.agent,'gatto');expect(f.relation,'insegue');expect(f.patient,'topo');
    }
    final inverse=LearnedReader324.parse('Il topo insegue il gatto.')!;
    expect(inverse.agent,'topo');expect(inverse.patient,'gatto');
    final multi=LearnedReader324.parse('Il norvente rosso aiuta il talverio verde.')!;
    expect(multi.agent,'norvente rosso');expect(multi.patient,'talverio verde');
    expect(LearnedReader324.parse('Il gatto non insegue il topo.')!.negative,isTrue);
  });
  test('conditional, modal, reported, coordinated and ambiguous clauses abstain',() {
    for(final text in ['Se il gatto insegue il topo, il cane corre.',
      'Il gatto potrebbe inseguire il topo.','Il gatto non insegue mai il topo.',
      'Il cane dice che il gatto insegue il topo.',
      'Il gatto insegue il topo e il cane.','Il gatto lo insegue.',
      'Lui aiuta lei.','Il gatto non non insegue il topo.',
      'Il gatto insegue il topo quando piove.']) {
      expect(LearnedReader324.parse(text),isNull,reason:text);
    }
  });
  test('only a unique immediately preceding mention resolves a pronoun',() {
    final m=ResearchMemory11();
    final r=RelationalMemory324.learn(m,'Il topo corre. Il gatto lo insegue.');
    expect(r.added,1);
    expect(RelationalMemory324.rows(m).single['patient'],'topo');
    expect(RelationalMemory324.rows(m).single['contextText'],contains('Il topo corre.'));
    final m2=ResearchMemory11();
    RelationalMemory324.learn(m2,'Il topo aiuta il cane. Il gatto lo insegue.');
    expect(RelationalMemory324.rows(m2).where((r)=>r['relation']=='insegue'),isEmpty);
  });
  test('one read, paraphrased question, correction and serialized restore',() {
    final m=ResearchMemory11();
    expect(RelationalMemory324.learn(m,'Il gatto insegue il topo.').added,1);
    expect(RelationalMemory324.answer(m,'Da chi viene rincorso il topo?'),contains('gatto insegue topo'));
    final old=RelationalMemory324.rows(m).single;
    expect(RelationalMemory324.learn(m,'Correggi: Il gatto insegue la lepre.').corrected,1);
    expect(RelationalMemory324.answer(m,'Il gatto rincorre chi?'),contains('lepre'));
    expect(RelationalMemory324.answer(m,'Chi rincorre il topo?'),startsWith('Non ho'));
    expect(RelationalMemory324.rows(m).first['status'],'superseded');
    expect(RelationalMemory324.rows(m).last['replaces'],old['id']);
    final restored=ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(RelationalMemory324.answer(restored,'Chi rincorre la lepre?'),contains('gatto insegue lepre'));
    expect(RelationalMemory324.learn(restored,'Il gatto insegue il topo.').duplicate,1);
    expect(RelationalMemory324.rows(restored,includeHistory:false).single['patient'],'lepre');
  });
  test('questions and repetitions never add assertions or MGD activation',() {
    final m=ResearchMemory11();
    RelationalMemory324.learn(m,'Il gatto insegue il topo.');
    final before=jsonEncode(RelationalMemory324.rows(m));
    for(var i=0;i<20;i++) {
      RelationalMemory324.answer(m,'Chi rincorre il topo?');
      RelationalMemory324.learn(m,'Il gatto insegue il topo.');
      RelationalMemory324.learn(m,'Il gatto insegue la lepre?');
    }
    expect(jsonEncode(RelationalMemory324.rows(m)),before);
    expect(m.evidence,isEmpty);expect(m.claims,isEmpty);
  });
  test('question wording without punctuation never creates invented facts',() {
    final m=ResearchMemory11();
    for(final text in ['Cosa contiene la cassa','Come aiuta il cane',
      'Dimmi chi insegue il topo','Quale animale insegue il topo',
      'Puoi dirmi cosa contiene la cassa']) {
      expect(LearnedReader324.isQuestion(text),isTrue,reason:text);
      RelationalMemory324.learn(m,text);
    }
    expect(RelationalMemory324.rows(m),isEmpty);
    expect(RelationalMemory324.answer(m,'Cosa contiene la cassa'),contains('Non interpreto'));
  });
  test('negation and conflicting assertions do not become positive truth',() {
    final m=ResearchMemory11();
    RelationalMemory324.learn(m,'Il gatto non insegue il topo.');
    expect(RelationalMemory324.answer(m,'Il gatto insegue il topo?'),contains('non insegue'));
    expect(RelationalMemory324.answer(m,'Chi insegue il topo?'),startsWith('Non ho'));
    RelationalMemory324.learn(m,'Il gatto insegue il topo.');
    expect(RelationalMemory324.answer(m,'Il gatto insegue il topo?'),contains('conflitto'));
  });
  test('ambiguous correction changes nothing; targeted correction preserves unrelated facts',() {
    final m=ResearchMemory11();
    RelationalMemory324.learn(m,'Il gatto insegue il topo. Il gatto insegue la lepre. Il cane aiuta il custode.');
    final before=jsonEncode(RelationalMemory324.rows(m));
    expect(RelationalMemory324.learn(m,'Correggi: Il gatto insegue la volpe.').corrected,0);
    expect(jsonEncode(RelationalMemory324.rows(m)),before);
    final id=RelationalMemory324.rows(m).first['id'].toString();
    expect(RelationalMemory324.correct(m,id,'Il gatto insegue il norvente.').corrected,1);
    expect(RelationalMemory324.answer(m,'Chi supporta il custode?'),contains('cane aiuta custode'));
    expect(RelationalMemory324.answer(m,'Chi rincorre la lepre?'),contains('gatto'));
  });
  test('identical reader, facts and correction semantics with MGD disabled',() {
    final m=ResearchMemory11();
    RelationalMemory324.learn(m,'Il norvente aiuta il talverio.');
    for(final q in ['Chi supporta il talverio?','Da chi è aiutato il talverio?']) {
      expect(RelationalMemory324.answer(m,q,mgd:true),
        RelationalMemory324.answer(m,q,mgd:false));
    }
    final row=RelationalMemory324.rows(m).single;
    expect(row['memory'],greaterThan(0));expect(row['weight'],lessThan(.98));
    expect(row['material'],greaterThan(0));
  });
  testWidgets('small phone inspector counts, sources and correction history are usable',(tester) async {
    tester.view.physicalSize=const Size(360,800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final m=ResearchMemory11();
    RelationalMemory324.learn(m,'Il gatto insegue il topo.');
    RelationalMemory324.learn(m,'Correggi: Il gatto insegue la lepre.');
    await tester.pumpWidget(MaterialApp(home:RelationalMemoryPage324(memory:m,onSave:()async{})));
    expect(find.text('1 attuali · 1 sostituite'),findsOneWidget);
    expect(find.textContaining('gatto → insegue → lepre'),findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));await tester.pumpAndSettle();
    expect(find.textContaining('Sostituita da'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('learned entity is searchable in world map',(tester) async {
    final m=ResearchMemory11();
    RelationalMemory324.learn(m,'Il norvente insegue il talverio.');
    await tester.pumpWidget(MaterialApp(home:SemanticMapPage14(
      brain:PlasticLanguageBrain04(),research:m,language:MgdLanguage20())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'norvente');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.textContaining('Nessun nodo trovato'),findsNothing);
    expect(find.textContaining('norvente'),findsWidgets);
    expect(tester.takeException(),isNull);
  });
}
