import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/reading_context_v0440.dart';
import '../lib/neural_reading_v0439.dart';
import '../lib/web_knowledge_explorer_v11.dart';

Map<String, dynamic> row(int i, String text, {String url = 'local://book'}) =>
    {'rid439': 'R$i', 'text': text, 'url': url, 'title': 'Archivio'};
void main() {
  test('a strong late hit survives the character budget and earlier neighbours', () {
    final rows = [for (var i = 0; i < 30; i++) row(i,
      i == 24 ? 'Il progetto Orbena trasferisce il cristallo Nival nel contenitore Tersio. ' + List.filled(240, 'vicenda').join(' ') :
      'Il progetto $i riguarda ' + List.filled(90, 'materiale').join(' '))];
    final selected = ReadingContext440.select(rows, 'Dove trasferisce il progetto Orbena il cristallo Nival?');
    expect(selected.any((r) => r['rid439'] == 'R24'), true);
    expect(selected.fold<int>(0, (n, r) => n + '${r['text']}'.length), lessThanOrEqualTo(4400));
    expect(selected.length, lessThanOrEqualTo(16));
  });
  test('a rare association retrieves original evidence across documents', () {
    final rows = [row(0, 'Il progetto Orbena passa attraverso il ponte Nival.', url: 'local://A'),
      ...[for (var i = 1; i < 25; i++) row(i, 'La scheda $i descrive un paesaggio.')],
      row(25, 'Il ponte Nival termina al deposito Tersio.', url: 'local://B')];
    final selected = ReadingContext440.select(rows, 'Dove conduce Orbena?');
    expect(selected.any((r) => r['rid439'] == 'R0'), true);
    expect(selected.any((r) => r['rid439'] == 'R25'), true);
    expect(selected.every(rows.contains), true);
  });
  test('small archives retain a needed premise without surface query words', () {
    final rows = [row(0, 'La nave Orbena contiene una lampada.'),
      row(1, 'Tutti gli oggetti del carico richiedono controllo.'),
      row(2, 'La lampada è parte del carico.')];
    expect(ReadingContext440.select(rows, 'La lampada va controllata?'), rows);
  });
  test('duplicate notes cannot consume all seed positions or enter the answer context', () {
    final rows = [for (var i = 0; i < 22; i++) row(i,
      i == 21 ? 'Il cristallo Nival è al deposito Tersio.' : 'La nave Orbena resta nel porto.')];
    final records = [<String,dynamic>{'notes': [for (var j = 0; j < 40; j++)
      {'text': 'Orbena Nival nel mare inventato', 'evidence': [{'id': 'R0'}]}]}];
    final picked = ReadingContext440.select(rows, 'Dove si trova Nival?', noteRecords: records);
    expect(picked.any((r) => r['rid439'] == 'R21'), true);
    expect(picked.map((r) => r['rid439']).toSet().length, picked.length);
    expect(jsonEncode(picked), isNot(contains('mare inventato')));
  });
  test('query and association ranking do not mutate source memory', () async {
    final m = ResearchMemory11();
    for (var i = 0; i < 30; i++) {
      SourceMemory323.retain(m, WebDocument11(provider: 'Fixture', family: 'local',
        title: 'Archivio', url: 'local://$i', trust: .9,
        text: i == 27 ? 'Orbena conserva il cristallo Nival nel deposito Tersio.' :
          'La scheda $i descrive un paesaggio.'));
    }
    final before = jsonEncode(m.toJson());
    final a = await NeuralReading439.answer(m, 'Dove conserva Orbena il cristallo Nival?',
      run: (p) async => '{"answer":"al deposito Tersio","evidence":["P0"],"unknown":false}');
    expect(a, isNotNull);
    expect(a!.proof['available'], 30);
    expect(a.proof['semanticValidation'], false);
    expect(a.text, contains('su 30 conservati'));
    expect(jsonEncode(m.toJson()), before);
  });
}
