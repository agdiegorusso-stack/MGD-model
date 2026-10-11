import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/reading_memory_v0438.dart';
import '../lib/learning_service_v0321.dart';
import '../lib/mgd_language_v020.dart';
import '../lib/learning_verification_v0428.dart';
import '../lib/verification_reader_v0428.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';
import '../lib/web_knowledge_explorer_v11.dart';

WebDocument11 document(String text, {String title = 'Procedura Merlo',
    String url = 'local://merlo'}) => WebDocument11(provider: 'Testo esterno',
    family: 'locale:lettura', title: title, url: url, text: text, trust: .9);

const paragraph = 'La procedura Merlo utilizza un filtro in fibra. '
    'Il filtro rimuove impurità dal liquido. '
    'Il sistema richiede energia elettrica. '
    'La pompa trasporta il liquido al filtro. '
    'La valvola regola il flusso. '
    'Il sensore misura la pressione. '
    'Il tecnico collega il tubo alla pompa. '
    'Il separatore separa i componenti. '
    'La membrana scambia molecole con il liquido. '
    'Il filtro riduce le impurità. '
    'Il ciclo si basa su una differenza di pressione. '
    'La procedura elimina i residui dal liquido.';

void intake(ResearchMemory11 memory, WebDocument11 doc, {String? topic}) {
  final brain = PlasticLanguageBrain04(), world = MgdWorld06();
  WebKnowledgeExplorer11().integrate(brain, world, memory, ResearchDraft11(
    goal: ResearchGoal11(query: topic ?? doc.title, topic: topic ?? doc.title,
      reason: 'Documento nuovo', value: 1), documents: [doc],
    claims: const [], passages: const [], sentencesRead: 0));
  while (ResearchSemantics317.getPending(memory) > 0) {
    ResearchSemantics317.processQueue(brain, world, memory);
  }
}

void main() {
  sqfliteFfiInit();
  test('teaching and TXT intake use the same broader action reader as web documents', () async {
    final m = ResearchMemory11(), b = PlasticLanguageBrain04(), w = MgdWorld06();
    await LearningService321.learnText(b, w, MgdLanguage20(), paragraph,
        memory: m, observeCls: false, source: 'Procedura Merlo');
    expect(m.claims.values.where((c) => c.meta317['usable'] == true).length,
      greaterThanOrEqualTo(12));
    expect(ReadingMemory438.stats(m)['passages'], 12);
  });
  test('old completed documents are re-read once by the upgraded extractor', () {
    final m = ResearchMemory11();
    final d = document(paragraph);
    intake(m, d);
    m.claims.clear(); m.evidence.clear();
    m.state317['recovery320Complete'] = true;
    m.state317.remove('readingRecovery438');
    m.state317['documentsRead'] = [ResearchSemantics317.digest([
      'reader320', ResearchSemantics317.canonicalUrl(d.url), d.text,
      ResearchSemantics317.concept(d.title)])];
    expect(ResearchSemantics317.needsRecovery318(m), true);
    expect(ResearchSemantics317.recoverTexts318(m), 1);
    final b = PlasticLanguageBrain04(), w = MgdWorld06();
    while (ResearchSemantics317.getPending(m) > 0) {
      ResearchSemantics317.processQueue(b, w, m);
    }
    expect(m.claims.length, greaterThanOrEqualTo(12));
    expect(ResearchSemantics317.recoverTexts318(m), 0);
    expect(ResearchSemantics317.needsRecovery318(m), false);
  });
  test('legacy study context is recovered without altering the saved memory during queries', () {
    final m = ResearchMemory11();
    intake(m, document('Il sensore misura la pressione.', title: 'Scheda tecnica'), topic: 'Merlo');
    final state = m.state317['sourceMemory323'] as Map;
    state['recovered'] = true; state.remove('completeRecovery438');
    for (final row in (state['rows'] as Map).values.whereType<Map>()) {
      row.remove('topics438');
    }
    final before = jsonEncode(m.toJson());
    expect(ReadingMemory438.answer(m, 'Che cosa misura Merlo?')!.text,
      contains('Il sensore misura la pressione.'));
    expect(jsonEncode(m.toJson()), before);
  });
  test('new document supplies twelve different sourced actions, not two taxonomy edges', () {
    final m = ResearchMemory11();
    expect(m.claims, isEmpty);
    intake(m, document(paragraph));
    final usable = m.claims.values.where((c) =>
      {'documentata', 'accettata'}.contains(c.status) && !c.conflict).toList();
    expect(usable.length, greaterThanOrEqualTo(12));
    expect(usable.map((c) => c.relation).toSet(), containsAll([
      'utilizza', 'rimuove', 'richiede', 'trasporta', 'regola', 'misura',
      'collega', 'separa', 'scambia', 'riduce', 'si basa su', 'elimina']));
    expect(ReadingMemory438.stats(m)['passages'], 12);
    expect(ReadingMemory438.answer(m, 'Descrivi la procedura Merlo')!.available, 12);
  });
  test('document context retrieves sentences whose subject differs from the study topic', () {
    final m = ResearchMemory11();
    SourceMemory323.retain(m, document(paragraph), topic: 'Merlo');
    final a = ReadingMemory438.answer(m, 'Che cosa misura Merlo?')!;
    expect(a.text, contains('Il sensore misura la pressione.'));
    expect(a.proof['semanticValidation'], false);
    expect(a.passages.single['url'], 'local://merlo');
    expect(m.claims, isEmpty);
  });
  test('lexical paraphrase and plural forms retrieve original text without rewriting it', () {
    final m = ResearchMemory11();
    SourceMemory323.retain(m, document(paragraph));
    final a = ReadingMemory438.answer(m, 'Che cosa usa la procedura Merlo?')!;
    expect(a.text, contains('La procedura Merlo utilizza un filtro in fibra.'));
    final b = ReadingMemory438.answer(m, 'Che cosa rimuovono i filtri?')!;
    expect(b.text, contains('Il filtro rimuove impurità dal liquido.'));
  });
  test('unknown properties and unrelated named objects cannot be silently dropped', () {
    final m = ResearchMemory11();
    SourceMemory323.retain(m, document(paragraph));
    final a = ReadingMemory438.answer(m, 'Quanto pesa la procedura Merlo?')!;
    expect(a.missing, true); expect(a.passages, isEmpty);
    expect(ReadingMemory438.answer(m, 'Merlo utilizza plutonio?')!.missing, true);
    expect(ReadingMemory438.answer(m, 'Che cosa sai di Saturno?'), isNull);
  });
  test('complete long sentences and short notes survive with their final conditions', () {
    final m = ResearchMemory11();
    final long = 'La procedura Merlo ' + List.filled(1100, 'testo').join(' ') +
        ' funziona soltanto se la porta è chiusa.';
    final text = 'Sì. No. $long';
    SourceMemory323.retain(m, document(text));
    final rows = ReadingMemory438.rows(m);
    expect(rows, hasLength(3));
    expect(rows.last['text'], long);
    expect(ReadingMemory438.answer(m, 'Descrivi Merlo')!.text, contains('soltanto se la porta è chiusa'));
    expect(m.claims, isEmpty);
  });
  test('negation, modality, numbers and source disagreement remain visible', () {
    final m = ResearchMemory11();
    SourceMemory323.retain(m, document('Merlo non rimuove il sale.'));
    SourceMemory323.retain(m, document('Merlo potrebbe rimuovere il sale dopo 7 ore, se la valvola è aperta.',
      url: 'local://merlo-b'));
    final a = ReadingMemory438.answer(m, 'Merlo elimina il sale?')!;
    expect(a.text, contains('non rimuove'));
    expect(a.text, contains('potrebbe rimuovere'));
    expect(a.text, contains('dopo 7 ore, se la valvola è aperta'));
    expect(a.passages, hasLength(2));
    expect(m.claims, isEmpty);
  });
  test('reading and queries do not add answers or independent source evidence', () {
    final m = ResearchMemory11();
    SourceMemory323.retain(m, document(paragraph));
    final before = jsonEncode(m.toJson());
    for (var i = 0; i < 10; i++) {
      ReadingMemory438.answer(m, 'Descrivi Merlo');
      ReadingMemory438.answer(m, 'Quanto pesa Merlo?');
      ReadingMemory438.stats(m);
    }
    expect(jsonEncode(m.toJson()), before);
  });
  test('retention survives restart and repeated exposure does not multiply passages', () {
    final m = ResearchMemory11();
    SourceMemory323.retain(m, document(paragraph));
    SourceMemory323.retain(m, document(paragraph));
    final restored = ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(ReadingMemory438.stats(restored)['passages'], 12);
    expect(ReadingMemory438.answer(restored, 'Che cosa rimuovono i filtri?')!.text,
      contains('impurità dal liquido'));
  });
  test('legacy recovered flags do not prevent recovery of previously omitted long text', () {
    final m = ResearchMemory11();
    m.state317['sourceMemory323'] = {'recovered': true, 'rows': <String, dynamic>{}};
    final long = 'Merlo ' + List.filled(1100, 'testo').join(' ') + ' solo se acceso.';
    m.passages.add(ResearchPassage11(id: 'old', topic: 'Merlo', provider: 'Test',
      sourceFamily: 'test', sourceTitle: 'Merlo', sourceUrl: 'local://old', text: long,
      trust: .8));
    final before = jsonEncode(m.toJson());
    expect(ReadingMemory438.answer(m, 'Descrivi Merlo')!.text, contains('solo se acceso.'));
    expect(jsonEncode(m.toJson()), before);
  });
  test('new intake and deletion refresh an already queried index', () {
    final m = ResearchMemory11();
    SourceMemory323.retain(m, document('Merlo utilizza il filtro.'));
    ReadingMemory438.answer(m, 'Descrivi Merlo');
    SourceMemory323.retain(m, document('Merlo richiede energia.'));
    expect(ReadingMemory438.answer(m, 'Che cosa richiede Merlo?')!.text, contains('energia'));
    SourceMemory323.forget33(m, (s) => s.contains('energia'));
    expect(ReadingMemory438.answer(m, 'Che cosa richiede Merlo?')!.missing, true);
  });
  test('a new study context invalidates cached retrieval for existing passages', () {
    final m = ResearchMemory11();
    final d = document('Il filtro elimina impurità.', title: 'Scheda Filtro');
    SourceMemory323.retain(m, d);
    expect(ReadingMemory438.answer(m, 'Descrivi Merlo'), isNull);
    SourceMemory323.retain(m, d, topic: 'Merlo');
    expect(ReadingMemory438.answer(m, 'Descrivi Merlo')!.available, 1);
  });
  test('source withdrawal blocks quotation even when index is cached', () {
    final m = ResearchMemory11();
    intake(m, document('Merlo utilizza un filtro.'));
    expect(ReadingMemory438.answer(m, 'Descrivi Merlo')!.missing, false);
    for (final c in m.claims.values) { c.status = 'ritirata'; }
    expect(ReadingMemory438.answer(m, 'Descrivi Merlo')!.missing, true);
  });
  test('production verification reader uses new source recall before the small map', () async {
    final reader = await VerificationReader428.open(factory: databaseFactoryFfi,
      temporaryRoot: Directory.systemTemp.path);
    try {
      final before = await reader.answer('Descrivi la procedura Merlo');
      expect(before.proof, isNull);
      expect(before.text, isNot(contains('local://merlo')));
      await reader.read([document(paragraph)]);
      final after = await reader.answer('Descrivi la procedura Merlo');
      expect(after.route, 'passaggi');
      expect(after.proof?['available'], 12);
      expect(after.text, contains('local://merlo'));
      expect(after.text, contains('passaggi mostrati'));
    } finally { await reader.close(); }
  });
  test('reading generalizes across unseen identifiers, with measurable retention and recall', () {
    var passed = 0;
    for (final name in ['Neriva', 'Torlano', 'Vespira', 'Xandora', 'Luvante']) {
      final m = ResearchMemory11();
      final text = paragraph.replaceAll('Merlo', name);
      SourceMemory323.retain(m, document(text, title: 'Procedura $name', url: 'local://$name'));
      for (final pair in [('utilizza', 'filtro in fibra'), ('richiede', 'energia elettrica'),
          ('trasporta', 'liquido al filtro'), ('misura', 'pressione')]) {
        final a = ReadingMemory438.answer(m, 'Che cosa ${pair.$1} $name?');
        expect(a, isNotNull);
        expect(a!.text, contains(pair.$2));
        passed++;
      }
    }
    final out = Directory('tool/reports')..createSync(recursive: true);
    File('${out.path}/reading-0.42.18.json').writeAsStringSync(jsonEncode({
      'version': '0.42.18', 'new_identifier_queries_passed': passed,
      'new_identifier_queries_total': 20, 'retained_sentences_per_document': 12,
      'assessment': 'Exact source retrieval with morphology and document context',
      'general_comprehension_demonstrated': false,
    }));
    expect(passed, 20);
  });
  test('dialysis prose is retained beyond taxonomy, with original source on each answer', () {
    // Italian paraphrase of NIDDK's patient information, not a clinical plan.
    const source = 'https://www.niddk.nih.gov/health-information/kidney-disease/kidney-failure/hemodialysis';
    const text = 'L’emodialisi rimuove rifiuti e acqua dal sangue. '
      'Il trattamento contribuisce al controllo della pressione e dell’equilibrio dei minerali. '
      'Il sangue attraversa un filtro chiamato dializzatore, fuori dal corpo. '
      'La macchina trasporta il sangue attraverso il filtro e poi lo restituisce al corpo. '
      'Nel filtro il sangue scorre nelle fibre cave e la soluzione di dialisi scorre fuori dalle fibre in direzione opposta. '
      'I prodotti di scarto passano dal sangue alla soluzione di dialisi. '
      'L’emodialisi sostituisce soltanto parte delle funzioni renali.';
    final m = ResearchMemory11();
    intake(m, document(text, title: 'Emodialisi · NIDDK', url: source), topic: 'dialisi');
    expect(ReadingMemory438.stats(m, topic: 'dialisi')['passages'], 7);
    final overview = ReadingMemory438.answer(m, 'Spiegami la dialisi')!;
    expect(overview.available, 7);
    expect(overview.text, contains('prodotti di scarto'));
    final specific = ReadingMemory438.answer(m, 'Che cosa elimina l’emodialisi?')!;
    expect(specific.text, contains('rifiuti e acqua dal sangue'));
    expect(specific.text, contains(source));
    expect(ReadingMemory438.answer(m, 'Quale dose di eparina richiede la dialisi?')!.missing, true);
  });
}
