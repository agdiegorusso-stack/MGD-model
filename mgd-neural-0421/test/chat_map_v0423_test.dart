import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mgd_neuro_mobile/knowledge_chat_v0423.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'package:mgd_neuro_mobile/relational_memory_v0324.dart';
import 'package:mgd_neuro_mobile/cls_store_v0340.dart';
import 'package:mgd_neuro_mobile/cls_bridge_v0340.dart';
import 'package:mgd_neuro_mobile/cognitive_core_v0400.dart';
import 'package:mgd_neuro_mobile/dialogue_engine_v0410.dart';
import 'package:mgd_neuro_mobile/social_cognition_v0410.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  void teach(PlasticLanguageBrain04 b, String s, String r, String o) {
    b.importTeacherFact08(subject: s, relation: r, object: o,
        confidence: .95, source: 'fixture');
  }
  test('bare topics read both directions from the actual original graph', () {
    for (final fixture in [
      ('Muscolo scheletrico', 'Movimento volontario'),
      ('Generatore di flusso', 'Trasporto controllato'),
    ]) {
      final b = PlasticLanguageBrain04(), m = ResearchMemory11();
      teach(b, fixture.$1, 'ha funzione', fixture.$2);
      teach(b, fixture.$2, 'è funzione associata a', fixture.$1);
      final before = b.encodeJson();
      final graph = KnowledgeChat423.links(b, m);
      expect(graph.any((e) => e.to == fixture.$2), true);
      final answer = KnowledgeChat423.answer(b, m, fixture.$2.toLowerCase())!;
      expect(answer, contains('${fixture.$1} — ha funzione → ${fixture.$2}'));
      expect(answer, contains('${fixture.$2} — è funzione associata a → ${fixture.$1}'));
      expect(answer, isNot(contains('Passaggio richiamato')));
      expect(b.encodeJson(), before, reason: 'Retrieval must not learn the query.');
    }
  });
  test('description variants, articles and aliases use graph knowledge', () {
    final b = PlasticLanguageBrain04(), m = ResearchMemory11();
    teach(b, 'Rattus', 'tipo di', 'Roditore');
    b.entities.firstWhere((e) => e.label == 'Rattus').aliases.add('ratto');
    for (final q in ['RATTUS', 'rattus?', 'Cos’è il rattus?', 'Che cosa è Rattus?',
      'Parlami del rattus', 'Spiegami rattus', 'ratto']) {
      expect(KnowledgeChat423.answer(b, m, q), contains('Roditore'), reason: q);
      expect(KnowledgeChat423.queryOnly(q, b, m), true, reason: q);
    }
  });
  test('known noun phrases cannot become bootstrap subject-verb frames', () {
    final b = PlasticLanguageBrain04(), m = ResearchMemory11();
    teach(b, 'Sistema muscolare scheletrico', 'ha funzione', 'Movimento volontario');
    expect(FrameInducer400.induce('Sistema muscolare scheletrico').valid, true);
    expect(KnowledgeChat423.queryOnly('Sistema muscolare scheletrico', b, m), true);
    expect(KnowledgeChat423.queryOnly('Marta apre la porta.', b, m), false);
  });
  test('unrelated relation is not an answer to a specific question', () {
    final b = PlasticLanguageBrain04(), m = ResearchMemory11();
    teach(b, 'Rattus', 'tipo di', 'Roditore');
    expect(KnowledgeChat423.answer(b, m, 'Cosa mangia Rattus?'), isNull);
    expect(KnowledgeChat423.answer(b, m, 'Dove vive Rattus?'), isNull);
  });
  test('an isolated node is acknowledged without inventing a definition', () {
    final b = PlasticLanguageBrain04(), m = ResearchMemory11();
    b.ensureSemanticEntity06('Solo un nome');
    expect(KnowledgeChat423.answer(b, m, 'Solo un nome'), contains('non ho ancora relazioni'));
    expect(KnowledgeChat423.answer(b, m, 'Sconosciuto'), isNull);
  });
  test('current negative teaching supersedes the duplicate positive graph edge', () async {
    final b = PlasticLanguageBrain04(), m = ResearchMemory11();
    teach(b, 'Zorvello', 'contiene', 'Cristalli');
    await RelationalMemory324.learnAsync(m, 'Il zorvello non contiene cristalli.', source: 'Correzione');
    final answer = KnowledgeChat423.answer(b, m, 'zorvello')!;
    expect(answer, contains('non contiene'));
    expect(answer, isNot(contains('— contiene →')));
    expect(answer, contains('Correzione'));
  });
  test('a conflicted legacy slot is not silently answered by its winner', () {
    final b = PlasticLanguageBrain04(), m = ResearchMemory11();
    teach(b, 'Arven', 'posizione', 'Nord');
    final slot = b.slots.values.first;
    slot.candidates['sud'] = FactCandidate04(objectKey: 'sud', display: 'Sud', confidence: .8);
    expect(KnowledgeChat423.answer(b, m, 'Arven'), contains('IN CONFLITTO'));
  });
  test('historical topic echoes are excluded from episodic evidence', () async {
    final dir = await Directory.systemTemp.createTemp('echo423-');
    final cls = await ClsStore340.open(path: '${dir.path}/cls.db', factory: databaseFactoryFfi);
    ClsBridge340.active = cls;
    try {
      await ClsBridge340.observeText('movimento volontario', source: 'Chat utente');
      expect(await ClsBridge340.quote('Movimento volontario'), isNull);
      expect(await ClsBridge340.quote('movimento volontario?'), isNull);
    } finally {
      ClsBridge340.active = null;
      await cls.close();
      await dir.delete(recursive: true);
    }
  });
  test('query-only dialogue updates focus without acquiring facts or episodes', () async {
    final dir = await Directory.systemTemp.createTemp('dialogue423-');
    final cognitive = await CognitiveStore400.openAt('${dir.path}/c.db', factory: databaseFactoryFfi);
    final social = await SocialStore410.openAt('${dir.path}/s.db', factory: databaseFactoryFfi);
    try {
      final engine = DialogueEngine410(CognitiveCore400(cognitive), TheoryOfMind410(social), social);
      await engine.process('Sistema muscolare scheletrico', queryOnly: true);
      expect(await cognitive.db.query('relations'), isEmpty);
      expect(await cognitive.db.query('episodes'), isEmpty);
      expect(engine.state.turns, 1);
    } finally {
      await social.close();
      await cognitive.close();
      await dir.delete(recursive: true);
    }
  });
}
