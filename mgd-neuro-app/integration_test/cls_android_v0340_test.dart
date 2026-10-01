import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mgd_neuro_mobile/cls_core_v0340.dart';
import 'package:mgd_neuro_mobile/cls_store_v0340.dart';
import 'package:mgd_neuro_mobile/cls_page_v0340.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import '../test/experience_v0330_test.dart' show picture33,tone33;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android CLS stores original PNG and PCM, corrects and reopens',(tester) async {
    final path='${await getDatabasesPath()}/cls_integration_0340.sqlite';
    await deleteDatabase(path);
    var store=await ClsStore340.open(path:path);
    final image=picture33(true),audio=tone33(330);
    final cue=<String,Map<String,double>>{'vision:v1':MgdWorld06.encodeVision33(image),
      'audio:v1':MgdWorld06.encodeAudio33(audio)};
    final id=await store.learn(cue,label:'vecchio',image:image,audio:audio,text:'Il suono accompagna la figura.');
    await store.consolidate();await store.correct(id,'corretto');await store.consolidate();
    await store.close();store=await ClsStore340.open(path:path);
    expect((await store.recall(cue)).best,'corretto');
    final row=(await store.get(id))!;expect(row['image'],image);expect(row['audio'],audio);
    await store.delete(id);await store.close();store=await ClsStore340.open(path:path);
    expect((await store.stats())['episodes'],0);expect((await store.recall(cue)).accepted,false);
    await store.close();await deleteDatabase(path);
  });
  testWidgets('Android experience UI teaches an episode and opens the atlas',(tester) async {
    final path='${await getDatabasesPath()}/cls_ui_0340.sqlite';await deleteDatabase(path);
    final store=await ClsStore340.open(path:path);
    await tester.pumpWidget(MaterialApp(home:ClsPage340(world:MgdWorld06(),onSave:() async {},store:store)));
    for(var i=0;i<50;i++) {
      await tester.pump(const Duration(milliseconds:100));
      final button=tester.widget<FilledButton>(find.byKey(const ValueKey('cls-teach')));
      if(button.onPressed!=null)break;
    }
    await tester.enterText(find.byKey(const ValueKey('cls-input')),'Il gatto dorme sul divano.');
    await tester.enterText(find.byKey(const ValueKey('cls-label')),'gatto');
    await tester.ensureVisible(find.byKey(const ValueKey('cls-teach')));await tester.tap(find.byKey(const ValueKey('cls-teach')));
    for(var i=0;i<50;i++) {
      await tester.pump(const Duration(milliseconds:100));if((await store.stats())['episodes']==1)break;
    }
    expect((await store.stats())['episodes'],1);
    await tester.tap(find.text('Atlante'));await tester.pumpAndSettle();
    expect(find.text('gatto · #1'),findsOneWidget);
    await tester.tap(find.text('gatto · #1'));await tester.pump(const Duration(seconds:1));
    await tester.pumpAndSettle();expect(find.byType(ExperienceAtlas340),findsOneWidget);
    await tester.pumpWidget(const SizedBox());await store.close();await deleteDatabase(path);
  });
  testWidgets('Android native PCM playback and stop channel is available',(tester) async {
    const channel=MethodChannel('mgd.cls/audio');
    await channel.invokeMethod<void>('play',Uint8List(3200));
    await channel.invokeMethod<void>('stop');
    await expectLater(channel.invokeMethod<void>('play',Uint8List(3)),throwsA(isA<PlatformException>()));
  });
}
