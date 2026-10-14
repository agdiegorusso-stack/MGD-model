import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/axioms/axiom_page.dart';
import 'package:mgd_neuro_mobile/axioms/axiom_store.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp((){
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(AxiomStore.channel,(call)async{
      if(call.method=='status')return {'models':[{'id':'gemma4-e2b','label':'Gemma 4 E2B','bytes':2588147712,'sha256':'181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c','installed':false,'download':{'status':0,'done':0}}],'loaded':'','backend':'','busy':false,'phase':'idle','freeBytes':12000000000,'availableRam':8000000000,'totalRam':16000000000};
      return null;
    });
  });
  tearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(AxiomStore.channel,null));
  for(final width in [360.0,412.0]){
    testWidgets('map and tutor remain usable at width $width',(tester)async{
      tester.view.physicalSize=Size(width,892);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final store=AxiomStore()..ready=true;store.nodes=store.student.graph();store.status='Memoria pronta per la verifica della UI.';
      await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(useMaterial3:true),home:AxiomStudioPage(store:store)));
      await tester.pumpAndSettle();
      expect(find.text('Assiomi · MGD Studio'),findsOneWidget);expect(tester.takeException(),isNull);
      if(width==412)await expectLater(find.byType(AxiomStudioPage),matchesGoldenFile('goldens/axioms0430-map.png'));
      await tester.tap(find.byTooltip('Mostra elenco completo'));await tester.pumpAndSettle();
      expect(find.byType(ListView),findsWidgets);expect(tester.takeException(),isNull);
      await tester.tap(find.text('Insegnante').first);await tester.pumpAndSettle();
      expect(find.text('Insegna e verifica'),findsOneWidget);expect(tester.takeException(),isNull);
      if(width==412)await expectLater(find.byType(AxiomStudioPage),matchesGoldenFile('goldens/axioms0430-tutor.png'));
      await tester.tap(find.text('Prove').first);await tester.pumpAndSettle();
      expect(find.text('Esegui 276 regressioni note'),findsOneWidget);expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox());store.dispose();
    });
  }
  testWidgets('model manager shows real sizes and Wi-Fi default',(tester)async{
    tester.view.physicalSize=const Size(412,892);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(useMaterial3:true),home:const TeacherModelsPage()));await tester.pumpAndSettle();
    expect(find.text('Gemma 4 E2B · 2.59 GB'),findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,false);
    expect(tester.takeException(),isNull);
    await expectLater(find.byType(TeacherModelsPage),matchesGoldenFile('goldens/axioms0430-models.png'));
    await tester.pumpWidget(const SizedBox());
  });
}
