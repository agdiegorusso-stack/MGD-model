import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mgd_neuro_mobile/cognitive_core_v0400.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Cognitive Core persists learned semantics and answers after reopen', (tester) async {
    final dir = await getTemporaryDirectory();
    final path='${dir.path}/cognitive-core-android-test.db';
    try { await File(path).delete(); } catch (_) {}
    var store=await CognitiveStore400.openAt(path);
    var core=CognitiveCore400(store);
    await core.experience('Marta apre la porta. Luca guarda Marta. La glarpa beve acqua.');
    expect((await core.answer('Chi apre la porta?'))?.toLowerCase(), contains('marta'));
    expect((await core.describeConcept('glarpa')).toLowerCase(), contains('glarpa'));
    await store.close();

    store=await CognitiveStore400.openAt(path);
    core=CognitiveCore400(store);
    expect((await core.answer('Chi apre la porta?'))?.toLowerCase(), contains('marta'));
    final stats=await store.stats();
    expect(stats['concepts'], greaterThan(0));
    expect(stats['relations'], greaterThan(0));
    await store.close();
  });
}
