import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/knowledge_chat_v0423.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/teacher_bridge_v08.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';

const location424 = 'ha localizzazione o associazione cellulare annotata in';
void teach424(PlasticLanguageBrain04 b, String s, String r, String o) =>
    b.importTeacherFact08(subject: s, relation: r, object: o, confidence: .9);

void screenshotFacts424(PlasticLanguageBrain04 b) {
  teach424(b, 'Cellula eucariotica', 'contiene o ospita', 'nucleo');
  teach424(b, 'Cellula eucariotica', 'contiene o ospita', 'mitocondrio');
  teach424(b, 'Proteina AOX2 (Arabidopsis thaliana)', location424, 'cloroplasto');
  teach424(b, 'Proteina AOX2 (Arabidopsis thaliana)', location424, 'mitocondrio');
}

void main() {
  test('both screenshot cases retain every compatible object without conflict', () {
    final b = PlasticLanguageBrain04();
    screenshotFacts424(b);
    final edges = KnowledgeChat423.links(b, ResearchMemory11());
    expect(edges.length, 4);
    expect(edges.every((e) => !e.conflict), true);
    final answer = KnowledgeChat423.answer(b, ResearchMemory11(), 'mitocondrio')!;
    expect(answer, contains('Cellula eucariotica'));
    expect(answer, contains('Proteina aox2'));
    expect(answer, isNot(contains('IN CONFLITTO')));
    expect(KnowledgeChat423.answer(b, ResearchMemory11(), 'cellula eucariotica'),
        allOf(contains('Nucleo'), contains('Mitocondrio')));
  });

  test('typed ha predicates survive maintenance and persisted restart intact', () {
    var b = PlasticLanguageBrain04();
    screenshotFacts424(b);
    teach424(b, 'Proteina Alfa', 'ha funzione', 'attività di chinasi');
    teach424(b, 'Proteina Alfa', 'ha come cofattore documentato', 'ione magnesio');
    teach424(b, 'Proteina Alfa', 'ha un ruolo biologico annotato in',
        'regolazione di A e B, durante la fase C');
    final before = b.semanticGraph(limit: 100).toSet();
    b.repairTeacherFacts082();
    b.repairSemanticMemory();
    b = PlasticLanguageBrain04.fromJson(jsonDecode(b.encodeJson()));
    b.repairTeacherFacts082();
    b.repairSemanticMemory();
    expect(b.semanticGraph(limit: 100).toSet(), before);
    expect(KnowledgeChat423.links(b, null).every((e) => !e.conflict), true);
    expect(b.semanticGraph(limit: 100).any((e) => e.relation == 'ha'), false);
  });

  test('known single-valued properties still expose incompatible alternatives', () {
    final b = PlasticLanguageBrain04();
    teach424(b, 'Arven', 'posizione', 'Nord');
    teach424(b, 'Arven', 'posizione', 'Sud');
    expect(KnowledgeChat423.answer(b, ResearchMemory11(), 'arven'),
        contains('IN CONFLITTO'));
    teach424(b, 'Carbonio', 'ha numero atomico', '6');
    teach424(b, 'Carbonio', 'ha numero atomico', '7');
    expect(KnowledgeChat423.links(b, null)
        .where((e) => e.from == 'Carbonio').single.conflict, true);
  });

  test('positive and negative assertions conflict only on their exact triple', () {
    final b = PlasticLanguageBrain04();
    teach424(b, 'Cellula X', 'contiene', 'mitocondrio');
    teach424(b, 'Cellula X', 'contiene', 'nucleo');
    teach424(b, 'Cellula X', 'non contiene', 'mitocondrio');
    final edges = KnowledgeChat423.links(b, null);
    expect(edges.where((e) => e.to == 'Mitocondrio').every((e) => e.conflict), true);
    expect(edges.singleWhere((e) => e.to == 'Nucleo').conflict, false);
  });

  test('both real 5000-fact packs retain all 10000 triples after restart', () {
    final raw = jsonDecode(utf8.decode(gzip.decode(
        File('test/fixtures/biology_10000_v0424.json.gz').readAsBytesSync())));
    final pack = TeacherPack08.fromJson(raw);
    expect(pack.facts.length, 10000);
    var b = PlasticLanguageBrain04();
    final result = importTeacherPack08(b, MgdWorld06(), pack);
    expect(result.facts, 10000);
    String key(String s) => PlasticLanguageBrain04.normalizeText(
        PlasticLanguageBrain04.canonicalObject(s));
    final expected = pack.facts.map((f) =>
        '${key(f.subject)}|${key(f.relation)}|${key(f.object)}').toSet();
    void verify() {
      final edges = KnowledgeChat423.links(b, ResearchMemory11());
      final actual = edges.map((e) =>
          '${key(e.from)}|${key(e.relation)}|${key(e.to)}').toSet();
      expect(expected.difference(actual), isEmpty);
      expect(actual.length, expected.length);
      expect(edges.every((e) => !e.conflict), true);
    }
    verify();
    b = PlasticLanguageBrain04.fromJson(jsonDecode(b.encodeJson()));
    b.repairTeacherFacts082();
    b.repairSemanticMemory();
    verify();
  }, timeout: const Timeout(Duration(minutes: 8)));
}
