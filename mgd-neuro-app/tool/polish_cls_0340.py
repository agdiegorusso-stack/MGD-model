"""Validate materialized atlas and adapt the old Android end-to-end contract.
The original cold-restore, multimodal and deletion assertions remain; new UI
learning targets the new store rather than expecting the old one to mutate.
"""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
page=(root/'lib/cls_page_v0340.dart').read_text()
for marker in ['CLS_MEDIA_ATLAS_0340','CLS_LEGACY_READONLY_0340','LegacySnapshotView340']:
    if marker not in page:raise RuntimeError(f'Missing committed atlas refinement: {marker}')
main=(root/'lib/main.dart').read_text()
for marker in ['MGD Neuro $mgdAppVersion319','Memorie MGD $mgdAppVersion319']:
    if marker not in main:raise RuntimeError(f'Missing version integration: {marker}')
p=root/'integration_test/runtime_android_v0319_test.dart';s=p.read_text()
marker='CLS_ANDROID_MIGRATION_0340'
if marker not in s:
    s=s.replace("import 'dart:convert';", "import 'dart:convert';\nimport 'package:mgd_neuro_mobile/cls_bridge_v0340.dart';\nimport 'package:mgd_neuro_mobile/cls_store_v0340.dart';\nimport 'package:mgd_neuro_mobile/cls_core_v0340.dart';",1)
    start=s.index("  testWidgets(\n      'Android multimodal experiences persist, learn in UI and delete coherently'")
    end=s.index("  testWidgets(\n      'Android 0331 rejection and provenance revocation survive SQLite restart and replay'",start)
    replacement=r'''
  // CLS_ANDROID_MIGRATION_0340
  testWidgets(
      'Android multimodal experiences persist, migrate, learn in CLS UI and delete coherently',
      (tester) async {
    final store=MgdStateStore26.instance;
    await store.clearAll();
    final cls=await ClsStore340.shared;
    ClsBridge340.active=cls;
    await ClsBridge340.clear();
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),
      r=ResearchMemory11(enabled:false),l=MgdLanguage20();
    for(final red in [true,false]) {
      for(final hz in [330.0,880.0]) {
        w.experience33.learn({
          'vision:v1':MgdWorld06.encodeVision33(picture33(red)),
          'audio:v1':MgdWorld06.encodeAudio33(tone33(hz))
        },label:'$red $hz');
      }
    }
    r.state317.addAll({'migrationComplete':true,'recovery318Complete':true,
      'languagePassages':0,'languageEvidence':0});
    await MemoryCheckpoint319().save(b,w,r,l);
    await tester.pumpWidget(const MgdNeuro04App());
    await waitBoot319(tester);
    final live=tester.widget<InspectorScope315>(find.byType(InspectorScope315)).inspector;
    expect(live.world.experience33.episodes.length,4);
    final cycles=live.world.thoughtCycles;
    await tester.pump(const Duration(seconds:12));
    expect(live.world.thoughtCycles,cycles);expect(live.world.eventDriven33,true);
    await tester.tap(find.text('Mondo'));await tester.pumpAndSettle();
    await tester.tap(find.text('Impara dall’esperienza').hitTestable());
    await tester.pumpAndSettle();
    expect((await cls.stats())['episodes'],4);
    await tester.enterText(find.byKey(const ValueKey('cls-input')),'saluto breve');
    await tester.enterText(find.byKey(const ValueKey('cls-label')),'ciao');
    FocusManager.instance.primaryFocus?.unfocus();await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('cls-teach')),180,
      scrollable:find.descendant(of:find.byKey(const ValueKey('cls-experience-list')),
        matching:find.byType(Scrollable)).first);
    await tester.tap(find.byKey(const ValueKey('cls-teach')));
    for(var n=0;n<100;n++) {
      await tester.pump(const Duration(milliseconds:100));
      if((await cls.stats())['episodes']==5)break;
    }
    expect((await cls.stats())['episodes'],5);
    expect(live.world.experience33.episodes.length,4,
      reason:'New learning must not diverge into the compatibility snapshot.');
    final cue=<String,Map<String,double>>{'text:v1':Italian340.features('saluto breve')};
    expect((await cls.recall(cue)).best,'ciao');
    await tester.pumpAndSettle();await tester.pageBack();await tester.pumpAndSettle();
    await KnowledgeDeletion33.delete(brain:live.brain,world:live.world,
      research:live.research,language:live.language,mode:'mondo',node:'ciao');
    expect((await cls.stats())['episodes'],4);
    expect((await cls.recall(cue)).accepted,false);
    expect(await cls.db.query('episodes',where:'label=?',whereArgs:['ciao']),isEmpty);
    await MemoryCheckpoint319().save(live.brain,live.world,live.research,live.language);
    await tester.pumpWidget(const SizedBox.shrink());await tester.pumpAndSettle();
    await store.close319();
    final restored=await WorldPersistence06().load();
    expect(restored!.experience33.episodes.length,4);
    expect(restored.experience33.episodes.any((e)=>e.label=='ciao'),false);
    final multimodal=<String,Map<String,double>>{
      'vision:v1':MgdWorld06.encodeVision33(picture33(false)),
      'audio:v1':MgdWorld06.encodeAudio33(tone33(880))};
    expect(restored.experience33.predict(multimodal).best,'false 880.0');
    expect((await cls.recall(multimodal)).best,'false 880.0');
    expect(await cls.migrateLegacy(restored.experience33.episodes.map((e)=>e.toJson())),0);
    expect((await cls.stats())['episodes'],4);
    print('ANDROID340_MIGRATION '+jsonEncode({'realPngPcm':true,'uiLearning':true,
      'legacySqliteRestart':true,'migrationIdempotent':true,'migratedEpisodesRetained':4,
      'newArchiveDeletion':true,'legacyIdleTrainingDisabled':true}));
    await ClsBridge340.clear();await store.clearAll();await store.close319();
  });

'''
    s=s[:start]+replacement+s[end:]
    p.write_text(s)
print('Atlas, version and updated Android migration contract validated')
