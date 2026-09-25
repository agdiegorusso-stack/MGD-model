import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import '../lib/corpus_semantic_bridge_v022.dart';
import '../lib/mgd_language_v020.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/reasoning_v0321.dart';
import '../lib/sensory_world_v06.dart';
import '../lib/web_knowledge_explorer_v11.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('held-out questions after one corpus exposure, restart, and repeat', () async {
    final b = PlasticLanguageBrain04(), w = MgdWorld06(), m = ResearchMemory11(), l = MgdLanguage20();
    final rng = Random(3212026);
    String word() => List.generate(10, (_) => String.fromCharCode(97 + rng.nextInt(26))).join();
    final cases = <Map<String, String>>[];
    final sentences = <String>[];
    const verbs = ['produce', 'mangia', 'contiene', 'studia', 'unisce'];
    for (var i = 0; i < 100; i++) {
      final s = 'zor${word()}', o = 'tal${word()}', verb = verbs[i % verbs.length];
      sentences.add('Il $s $verb $o.');
      cases.add({'question': 'Cosa $verb il $s?', 'answer': o, 'kind': 'direct'});
      cases.add({'question': 'Che cosa $verb $s?', 'answer': o, 'kind': 'paraphrase'});
    }
    for (var i = 0; i < 20; i++) {
      final a = 'cla${word()}', c = 'cla${word()}', d = 'cla${word()}';
      sentences.addAll(['Il $a è una sottoclasse di $c.', 'Il $c è una sottoclasse di $d.']);
      cases.add({'question': 'Cosa puoi dedurre su $a?', 'answer': d, 'kind': 'deduction'});
    }
    for (var i = 0; i < 20; i++) {
      cases.add({'question': 'Cosa produce sconosciuto${word()}?', 'answer': '', 'kind': 'abstention'});
    }
    final corpus = sentences.join(' ');
    final training = Stopwatch()..start();
    l.ingestText(corpus);
    final learned = await CorpusSemanticBridge22.learn(text: corpus, sourceName: 'Benchmark sintetico',
        brain: b, world: w, memory: m);
    training.stop();
    String? answer(String q, ResearchMemory11 memory) => Reasoning321.answer(q, memory) ??
        ResearchSemantics317.answer(q, memory, realize: (s,r,o) => l.realizeFact320(s,r,o));
    final latencies = <int>[];
    final results = <Map<String, dynamic>>[];
    for (final c in cases) {
      final clock = Stopwatch()..start();
      final actual = answer(c['question']!, m);
      clock.stop(); latencies.add(clock.elapsedMicroseconds);
      final ok = c['kind'] == 'abstention' ? actual == null :
          actual?.contains(c['answer']!) == true;
      results.add({...c, 'actual': actual, 'passed': ok});
    }
    final restored = ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    final stable = cases.every((c) => answer(c['question']!, restored) == answer(c['question']!, m));
    final evidence = m.evidence.length;
    final repeated = await CorpusSemanticBridge22.learn(text: corpus, sourceName: 'Stesso corpus rinominato',
        brain: b, world: w, memory: m);
    latencies.sort();
    final report = <String,dynamic>{
      'version': '0.32.2', 'seed': 3212026, 'platform': Platform.operatingSystem,
      'scope': 'Structured source-attributed questions and explicit class transitivity; synthetic Italian templates.',
      'trainingSentenceExposures': sentences.length, 'trainingPasses': 1,
      'trainingMs': training.elapsedMicroseconds / 1000,
      'sentencesPerSecond': sentences.length * 1000000 / max(1, training.elapsedMicroseconds),
      'newUsableClaims': learned.accepted,
      'testCases': cases.length, 'passed': results.where((r) => r['passed'] == true).length,
      'queryP50Ms': latencies[(latencies.length * .5).floor()] / 1000,
      'queryP95Ms': latencies[(latencies.length * .95).floor()] / 1000,
      'restartIdenticalAnswers': stable,
      'reimportNewUsable': repeated.accepted, 'reimportNewEvidence': m.evidence.length - evidence,
      'transformerComparison': {'status': 'not_run', 'reason': 'No specified trained baseline with identical task, data and hardware.'},
      'limitations': ['No open-domain language-quality score.', 'Not a Transformer superiority result.', 'Host test timing, not phone timing.'],
      'cases': results,
    };
    final path = Platform.environment['MGD_BENCHMARK_OUT'];
    if (path != null) File(path).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    print(jsonEncode({...report}..remove('cases')));
    expect(results.where((r) => r['passed'] != true), isEmpty);
    expect(stable, true); expect(repeated.accepted, 0); expect(m.evidence.length, evidence);
  });
}
