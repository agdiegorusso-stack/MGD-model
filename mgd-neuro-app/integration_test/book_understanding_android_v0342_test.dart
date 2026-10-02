import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mgd_neuro_mobile/book_understanding_v0342.dart';
import 'package:mgd_neuro_mobile/book_lab_service_v0342.dart';
import 'package:mgd_neuro_mobile/main.dart';
import 'package:mgd_neuro_mobile/mgd_language_v020.dart';
import 'package:mgd_neuro_mobile/mgd_state_store_v026.dart';
import 'package:mgd_neuro_mobile/memory_runtime_v0319.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'package:mgd_neuro_mobile/knowledge_inspector_v0315.dart';

const source342='Ogni neride è un mammifero.\nOgni mammifero produce latte.\nLuma è un neride.';
ResearchMemory11 memory342(){
  final r=ResearchMemory11(enabled:false)..state317.addAll({'migrationComplete':true,'recovery320Complete':true});
  SourceMemory323.retain(r,WebDocument11(provider:'Android fixture',title:'Manuale Android',url:'local://book/android342/1',text:source342,trust:.7));
  BookLab342.state(r)['activeScope']='book:android342';return r;
}
Future<void> waitStatus342(WidgetTester tester,String prefix)async{
  for(var n=0;n<900;n++){
    await tester.pump(const Duration(milliseconds:100));
    final f=find.byKey(const ValueKey('book-lab-status'));
    if(f.evaluate().isNotEmpty){final s=tester.widget<Text>(f).data??'';
      if(s.startsWith(prefix))return;
      if(s.contains('non completat')||s.startsWith('Lettore non pronto'))fail(s);
    }
  }
  fail('Book laboratory did not reach $prefix');
}
void main(){
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: language entry, unseen-entity transfer, exam evidence and SQLite reopen',(tester)async{
    final store=MgdStateStore26.instance;await store.clearAll();
    final brain=PlasticLanguageBrain04(),world=MgdWorld06(),language=MgdLanguage20(),research=memory342();
    final cases=<Map<String,dynamic>>[
      {'id':'new','question':'Che cosa produce Zeta?','assumptions':'Zeta è un neride.','category':'trasferimento','expected':'answer','answers':['latte'],
       'support':['Ogni neride è un mammifero.','Ogni mammifero produce latte.'],'origin':'external_reference'},
      {'id':'absent','question':'Che cosa produce Rivo?','assumptions':'','category':'non determinabile','expected':'unknown','answers':[],'support':[],'origin':'external_reference'}];
    BookLab342.setCases(research,'book:android342',cases);
    Future<void> save()=>MemoryCheckpoint319().save(brain,world,research,language);
    await tester.pumpWidget(MaterialApp(home:MgdLanguageLab20(brain:brain,world:world,language:language,research:research,onSave:save)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('book-lab-open')));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-lab-open')).hitTestable());await waitStatus342(tester,'Pronto.');
    await tester.ensureVisible(find.byKey(const ValueKey('book-question')));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-question')));await tester.enterText(find.byKey(const ValueKey('book-question')),'Che cosa produce Zeta?');
    await tester.ensureVisible(find.byKey(const ValueKey('book-hypotheses')));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-hypotheses')));await tester.enterText(find.byKey(const ValueKey('book-hypotheses')),'Zeta è un neride.');
    FocusManager.instance.primaryFocus?.unfocus();await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('book-ask')));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-ask')).hitTestable());await waitStatus342(tester,'Risposta con');
    await tester.ensureVisible(find.byKey(const ValueKey('book-answer')));await tester.pumpAndSettle();
    expect(tester.widget<SelectableText>(find.byKey(const ValueKey('book-answer'))).data,'latte');
    expect(SourceMemory323.rows(research),hasLength(3));expect(research.claims,isEmpty);
    expect(BookEngine342(BookLab342.rows(research)).answer('Che cosa produce Zeta?').status,'unknown');
    await tester.tap(find.text('Esame'));await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Esegui esame indipendente'));await tester.pumpAndSettle();
    await tester.tap(find.text('Esegui esame indipendente').hitTestable());await waitStatus342(tester,'Esame salvato.');
    await tester.tap(find.text('Risultati'));await tester.pumpAndSettle();
    expect(find.text('ESAME CON RIFERIMENTI SEPARATI'),findsOneWidget);expect(tester.takeException(),isNull);
    final report=BookLab342.reports(research,'book:android342').single;
    expect(report['correct'],2);expect(report['supportCorrect'],1);expect(report['jointCorrect'],1);
    expect(SourceMemory323.rows(research),hasLength(3));
    await tester.pumpWidget(const SizedBox());await tester.pumpAndSettle();await store.close319();
    final restored=ResearchMemory11.fromJson((await store.getMap('research_v11'))!);
    expect(BookLab342.cases(restored,'book:android342'),hasLength(2));expect(BookLab342.reports(restored,'book:android342').single['correct'],2);
    expect(BookEngine342(BookLab342.rows(restored)).answer('Che cosa produce Luma?').answer,'latte');
    print('BOOK342_ANDROID_LAB transfer=latte sources=3 exam=2/2 support=1/1 sqliteReopen=true');
  });
  testWidgets('Android: actual Libro chat uses selected source and does not train on exam queries',(tester)async{
    final store=MgdStateStore26.instance;await store.clearAll();
    await MemoryCheckpoint319().save(PlasticLanguageBrain04(),MgdWorld06(),memory342(),MgdLanguage20());
    await tester.pumpWidget(const MgdNeuro04App());
    for(var n=0;n<300&&find.byType(InspectorScope315).evaluate().isEmpty;n++){await tester.pump(const Duration(milliseconds:100));}
    expect(find.byType(InspectorScope315),findsOneWidget);
    final live=tester.widget<InspectorScope315>(find.byType(InspectorScope315)).inspector;
    final before=live.language.sentences, sourceCount=SourceMemory323.rows(live.research).length;
    final field=find.byType(TextField);await tester.tap(field);await tester.pump();
    await tester.enterText(field,'Libro: Che cosa produce Luma?');
    final send=find.ancestor(of:find.byIcon(Icons.arrow_upward),matching:find.byType(IconButton));
    for(var n=0;n<300&&tester.widget<IconButton>(send).onPressed==null;n++){await tester.pump(const Duration(milliseconds:100));}
    expect(tester.widget<IconButton>(send).onPressed,isNotNull);await tester.tap(send.hitTestable());
    for(var n=0;n<600;n++){
      await tester.pump(const Duration(milliseconds:100));
      if(tester.widget<TextField>(field).controller!.text.isEmpty&&tester.widget<IconButton>(send).onPressed!=null)break;
    }
    await tester.pumpAndSettle();
    final rendered=tester.widgetList<Text>(find.byType(Text)).map((t)=>t.data??'').join('\n');
    expect(rendered,contains('Deduzione dalle premesse'));expect(rendered,contains('latte'));
    expect(live.language.sentences,before);expect(SourceMemory323.rows(live.research).length,sourceCount);
    print('BOOK342_ANDROID_CHAT answer=latte queryNotLearned=true evidence=true');
    await tester.pumpWidget(const SizedBox());await tester.pumpAndSettle();await store.clearAll();await store.close319();
  });
}
