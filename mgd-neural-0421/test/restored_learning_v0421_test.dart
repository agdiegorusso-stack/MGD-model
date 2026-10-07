import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mgd_neuro_mobile/cognitive_core_v0400.dart';
import 'package:mgd_neuro_mobile/dialogue_engine_v0410.dart';
import 'package:mgd_neuro_mobile/social_cognition_v0410.dart';
import 'package:mgd_neuro_mobile/learning_bridge_v0421.dart';
import 'package:mgd_neuro_mobile/learning_service_v0321.dart';
import 'package:mgd_neuro_mobile/mgd_language_v020.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/relational_memory_v0324.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/text_learning_v0421.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'package:mgd_neuro_mobile/knowledge_deletion_v0330.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late CognitiveStore400 cognitive;
  late SocialStore410 social;
  late DialogueEngine410 engine;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mgd421-');
    cognitive = await CognitiveStore400.openAt('${dir.path}/c.db',
        factory: databaseFactoryFfi);
    social = await SocialStore410.openAt('${dir.path}/s.db',
        factory: databaseFactoryFfi);
    engine = DialogueEngine410(
        CognitiveCore400(cognitive), TheoryOfMind410(social), social);
    LearningBridge421.observe = (text, source) async {
      await engine.observeExternal(text, source: source);
    };
    LearningBridge421.forget = (node) => engine.forgetWhere(
        (text) => PlasticLanguageBrain04.containsLabel33(text, node));
  });
  tearDown(() async {
    LearningBridge421.observe = null;
    LearningBridge421.forget = null;
    await social.close();
    await cognitive.close();
    await dir.delete(recursive: true);
  });

  test('teaching reaches relational, linguistic and cognitive memory',
      () async {
    final b = PlasticLanguageBrain04(), w = MgdWorld06();
    final r = ResearchMemory11(enabled: false), l = MgdLanguage20();
    await LearningService321.learnText(
        b, w, l, 'Il zorvello contiene cristalli. Marta apre la porta.',
        memory: r);
    expect(RelationalMemory324.answerIfKnown(r, 'Cosa contiene il zorvello?'),
        contains('cristalli'));
    expect(l.tokenCount.containsKey('zorvello'), true);
    final rows = await cognitive.db.query('relations');
    expect(rows.length, 2);
    expect(
        rows.any((x) =>
            '${x['subject']}'.contains('marta') &&
            '${x['object']}'.contains('porta')),
        true);
    expect(RelationalMemory324.rows(r, includeHistory: false).length,
        greaterThanOrEqualTo(1),
        reason: 'The recognized relation reaches the live map.');
  });

  test('paragraph events stay separate and questions are excluded', () async {
    await engine.observeExternal(
        'Marta apre la porta. Luca chiude la finestra. Chi apre la porta?');
    final rows = await cognitive.db.query('relations');
    expect(rows.length, 2);
    expect(rows.any((r) => '${r['subject']}'.contains('chi')), false);
    expect(
        rows.any((r) =>
            '${r['object']}'.contains('finestra') &&
            '${r['subject']}'.contains('luca')),
        true);
  });

  test('UTF16 TXT reaches the live map and engine', () async {
    const text = 'Il zorvello contiene cristalli. Marta apre la porta.';
    final file = File('${dir.path}/manuale.txt');
    await file.writeAsBytes([
      255,
      254,
      for (final c in text.codeUnits) ...[c & 255, c >> 8]
    ]);
    final b = PlasticLanguageBrain04(), w = MgdWorld06();
    final r = ResearchMemory11(enabled: false), l = MgdLanguage20();
    final imported = await TextLearning421.importFile(file,
        name: 'manuale.txt', brain: b, world: w, research: r, language: l);
    expect(imported.exposures, 2);
    expect(RelationalMemory324.answerIfKnown(r, 'Cosa contiene il zorvello?'),
        contains('cristalli'));
    expect((await cognitive.db.query('relations')).length, 2);
  });

  test('interrupted TXT does not admit later fragments', () async {
    final file = File('${dir.path}/manuale.txt');
    await file.writeAsString(List.filled(400, 'Marta apre la porta. ').join());
    final b = PlasticLanguageBrain04(), w = MgdWorld06();
    final r = ResearchMemory11(enabled: false), l = MgdLanguage20();
    var stopped = false;
    final imported = await TextLearning421.importFile(file,
        name: 'manuale.txt',
        brain: b,
        world: w,
        research: r,
        language: l,
        cancelled: () => stopped,
        progress: (blocks, sentences) => stopped = true);
    expect(imported.cancelled, true);
    expect(imported.fragments, 1);
    expect(imported.exposures, lessThan(400));
  });

  test('stopped pasted teaching only commits acquired sentences', () async {
    final b = PlasticLanguageBrain04(), w = MgdWorld06();
    final r = ResearchMemory11(enabled: false), l = MgdLanguage20();
    var stopped = false;
    final n = await LearningService321.learnText(b, w, l,
        'Il zorvello contiene cristalli. Il talverio contiene quarzo.',
        passes: 5, memory: r, shouldContinue: () => !stopped,
        progress: (done, total) => stopped = done == 1);
    expect(n, 1);
    expect(l.tokenCount.containsKey('talverio'), false);
    expect(RelationalMemory324.answerIfKnown(r, 'Cosa contiene il zorvello?'),
        contains('cristalli'));
    expect(RelationalMemory324.answerIfKnown(r, 'Cosa contiene il talverio?'),
        isNull);
    expect((await cognitive.db.query('relations')).length, 1);
    expect(SourceMemory323.rows(r).any((x) =>
        '${x['text']}'.contains('talverio')), false);
  });

  test('stopped replay preserves facts without repeating source evidence',
      () async {
    final b = PlasticLanguageBrain04(), w = MgdWorld06();
    final r = ResearchMemory11(enabled: false), l = MgdLanguage20();
    var stopped = false;
    final n = await LearningService321.learnText(b, w, l,
        'Il zorvello contiene cristalli. Il talverio contiene quarzo.',
        passes: 5, memory: r, shouldContinue: () => !stopped,
        progress: (done, total) => stopped = done == 3);
    expect(n, 3);
    final rows = await cognitive.db.query('relations');
    expect(rows.length, 2);
    expect(rows.every((x) => x['count'] == 1), true);
    expect(RelationalMemory324.answerIfKnown(r, 'Cosa contiene il talverio?'),
        contains('quarzo'));
  });

  test('map deletion forgets cognitive and social references across restart',
      () async {
    final b = PlasticLanguageBrain04(), w = MgdWorld06();
    final r = ResearchMemory11(enabled: false), l = MgdLanguage20();
    await LearningService321.learnText(b, w, l,
        'Marta apre la porta. Martabella chiude la finestra.', memory: r);
    for (final holder in ['marta', 'martabella']) {
      await social.putBelief(MentalBelief410(holder: holder, subject: holder,
          predicate: 'vede', object: 'libro', location: '', negative: false,
          confidence: .8, source: 'test'));
      await social.putGoal(holder, 'leggere');
    }
    await KnowledgeDeletion33.delete(brain: b, world: w, research: r,
        language: l, mode: 'mondo', node: 'Marta');
    expect(await cognitive.concept('marta'), isNull);
    expect(await cognitive.concept('martabella'), isNotNull);
    final rows = await cognitive.db.query('relations');
    expect(rows.length, 1);
    expect('${rows.single['subject']}', contains('martabella'));
    expect(await cognitive.answerRelation('Chi apre la porta?'), isNull);
    expect(await social.beliefsOf('marta'), isEmpty);
    expect(await social.goalsOf('marta'), isEmpty);
    expect(await social.beliefsOf('martabella'), hasLength(1));
    expect(engine.core.workingMemory.any((f) => f.subject == 'marta'), false);
    expect(l.tokenCount.containsKey('marta'), false);
    expect(l.tokenCount.containsKey('martabella'), true);
    await cognitive.close();
    cognitive = await CognitiveStore400.openAt('${dir.path}/c.db',
        factory: databaseFactoryFfi);
    await social.close();
    social = await SocialStore410.openAt('${dir.path}/s.db',
        factory: databaseFactoryFfi);
    expect(await cognitive.answerRelation('Chi apre la porta?'), isNull);
    expect(await social.beliefsOf('marta'), isEmpty);
    expect(await cognitive.concept('martabella'), isNotNull);
  });
}
