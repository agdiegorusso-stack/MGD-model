import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';
import '../lib/source_memory_page_v0323.dart';
import '../lib/reasoning_v0321.dart';

WebDocument11 doc(String text, {String title = 'Talverio', String url = 'https://example.invalid/a'}) =>
  WebDocument11(provider:'Test', family:'test', title:title, url:url, text:text, trust:.9);

void intake(ResearchMemory11 m, WebDocument11 d) {
  final b=PlasticLanguageBrain04(), w=MgdWorld06();
  WebKnowledgeExplorer11().integrate(b,w,m,ResearchDraft11(
    goal:ResearchGoal11(topic:d.title,query:d.title,reason:'test',value:1),
    documents:[d],claims:[],passages:[],sentencesRead:0));
  while(ResearchSemantics317.getPending(m)>0) {
    ResearchSemantics317.processQueue(b,w,m);
  }
}

void main() {
  test('conditional descriptive definition keeps head, tail and exact sentence', () {
    const text='Un talverio è una regione artificiale, classificata per vegetazione se terrestre e per fauna se acquatica.';
    final d=doc(text), xs=ResearchSemantics317.extractAny321(text, doc(text));
    expect(xs,hasLength(1));
    expect(xs.single.object,'regione artificiale');
    expect(xs.single.sentence,text);
    expect(xs.single.meta317['qualifiers'],containsPair('descriptiveContext323',
      'classificata per vegetazione se terrestre e per fauna se acquatica.'));
    expect(ResearchSemantics317.assess(text,subject:'talverio',rel:'tipo di',
      object:'regione artificiale'), 'unknown');
    final m=ResearchMemory11(); intake(m,d);
    expect(m.claims.values.where((c)=>c.meta317['usable']==true),hasLength(1));
    expect(ResearchSemantics317.answer('Che cosa è un talverio?',m),contains('se acquatica'));
    expect(Reasoning321.infer(m,'talverio'),isEmpty);
  });

  test('negation, hypothetical subjects and main conditional clauses are not definitions', () {
    for(final text in [
      'Se il talverio è una regione, classificata per vegetazione.',
      'Il talverio non è una regione, classificata per vegetazione.',
      'Un talverio è forse una regione, classificata per vegetazione.',
      'Un talverio è una regione se piove, classificata per vegetazione.',
    ]) {
      expect(ScopedDefinition323.extract('talverio',text,doc(text)),isEmpty,reason:text);
    }
  });

  test('unparsed source answers without adding evidence or facts', () {
    const text='Il talverio viene osservato soltanto quando il rilevatore è acceso.';
    final m=ResearchMemory11(); intake(m,doc(text));
    final claims=m.claims.length, evidence=m.evidence.length;
    final answer=SourceMemory323.answer('Che cosa è il talverio?',m);
    expect(answer,contains(text));
    expect(answer,contains('non equivale a una relazione verificata'));
    expect(answer,contains('https://example.invalid/a'));
    expect(m.claims.length,claims); expect(m.evidence.length,evidence);
  });

  test('source memory deduplicates and survives serialization and audit trimming', () {
    final m=ResearchMemory11(); final d=doc('Il talverio funziona solo se il circuito è chiuso.');
    expect(SourceMemory323.retain(m,d),1); expect(SourceMemory323.retain(m,d),0);
    final expected=SourceMemory323.search('talverio',m).single.text;
    m.sessions.clear(); m.passages.clear(); m.evidence.clear();
    final restored=ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(SourceMemory323.search('talverio',restored).single.text,expected);
    expect(SourceMemory323.stats(restored)['passages'],1);
  });

  test('index refreshes after new intake and does not match through title alone', () {
    final m=ResearchMemory11(); SourceMemory323.retain(m,doc('Il lorvante viene osservato al buio.'));
    expect(SourceMemory323.search('talverio',m),isEmpty);
    SourceMemory323.retain(m,doc('Il talverio viene osservato alla luce.'));
    expect(SourceMemory323.search('talverio',m),hasLength(1));
    expect(SourceMemory323.search('talverio plutonio',m),isEmpty);
    expect(SourceMemory323.answer('ciao',m),isNull);
  });

  test('contradictory sources remain distinct quotations, repeated lookup adds no evidence', () {
    final m=ResearchMemory11();
    SourceMemory323.retain(m,doc('Il talverio è presente nel campione.'));
    SourceMemory323.retain(m,doc('Il talverio non è presente nel campione.',url:'https://example.invalid/b'));
    for(var i=0;i<10;i++) {
      expect(SourceMemory323.search('talverio campione',m),hasLength(2));
    }
    expect(SourceMemory323.stats(m)['sources'],2);
    expect(m.evidence,isEmpty); expect(m.claims,isEmpty);
  });

  test('long sentences are not truncated into condition-free assertions', () {
    final m=ResearchMemory11(); SourceMemory323.retain(m,doc('Talverio '+List.filled(1000,'testo').join(' ')));
    expect(SourceMemory323.stats(m)['passages'],0);
    expect(SourceMemory323.stats(m)['lastIntakeSkippedLongSentences'],1);
  });

  testWidgets('all displayed passage counts open searchable source contents on a small screen', (tester) async {
    tester.view.physicalSize=const Size(360,640); tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final m=ResearchMemory11();
    SourceMemory323.retain(m,doc('Il talverio viene osservato soltanto quando il rilevatore è acceso.'));
    await tester.pumpWidget(MaterialApp(home:SourceMemoryPage323(memory:m)));
    expect(find.text('1 passaggi conservati'),findsOneWidget);
    await tester.enterText(find.byType(TextField),'talverio');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 risultati'),findsOneWidget);
    expect(find.textContaining('soltanto quando'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
