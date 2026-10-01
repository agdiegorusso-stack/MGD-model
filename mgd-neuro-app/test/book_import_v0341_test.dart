import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/book_import_v0341.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../lib/mgd_language_v020.dart';
import '../lib/relational_memory_v0324.dart';

BookModels341 fresh341() => BookModels341(PlasticLanguageBrain04(),
    MgdWorld06(), ResearchMemory11(enabled: false), MgdLanguage20());
Map<String, dynamic> normalized341(dynamic x) =>
    (x as Map).map((k, v) => MapEntry(k.toString(), value341(v)));
dynamic value341(dynamic x) => x is Map
    ? normalized341(x)
    : x is List
        ? x.map(value341).toList()
        : x;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mgd-book341-');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test(
      'streaming preserves every character; bounds chunks regardless of upstream size',
      () async {
    final original =
        List.generate(18000, (i) => 'Capitolo $i. L’acqua è liquida.\n').join();
    final pieces = await BookText341.fragments(Stream.value(original)).toList();
    expect(pieces.map((p) => p.text).join(), original);
    expect(pieces.every((p) => p.text.length <= 4096), true);
    expect(pieces.every((p) => p.semanticSafe), true);
    print(
        'BOOK341_STREAM chars=${original.length} fragments=${pieces.length} max=4096');
  });
  test(
      'overlong unpunctuated sentence is retained but never treated as independent facts',
      () async {
    final text = 'Se ' +
        List.filled(18000, 'la condizione ').join() +
        'allora non è confermato.\n';
    final xs = await BookText341.fragments(Stream.value(text)).toList();
    expect(xs.map((p) => p.text).join(), text);
    expect(xs.every((p) => !p.semanticSafe), true);
    expect(xs.every((p) => p.text.length <= 4096), true);
  });
  test('small provider chunks, UTF8 apostrophes and emoji are preserved',
      () async {
    final content = List.filled(900, 'È un’esperienza 🧠.\n').join();
    final file = File('${dir.path}/utf8.txt');
    final bytes = utf8.encode(content);
    await BookText341.stage(
        Stream.fromIterable(List.generate(bytes.length, (i) => [bytes[i]])),
        file,
        name: 'italiano.txt');
    expect((await BookText341.decode(file).toList()).join(), content);
    final parts =
        await BookText341.fragments(BookText341.decode(file)).toList();
    expect(parts.map((p) => p.text).join(), content);
  });
  test('UTF16 LE and BE preserve Italian and supplementary characters',
      () async {
    const content = 'La memoria è un’esperienza 🧠.\n';
    for (final little in [true, false]) {
      final data = <int>[
        if (little) ...[255, 254] else ...[254, 255]
      ];
      for (final u in content.codeUnits)
        data.addAll(little ? [u & 255, u >> 8] : [u >> 8, u & 255]);
      final f = File('${dir.path}/utf16.txt');
      await f.writeAsBytes(data);
      expect((await BookText341.decode(f).toList()).join(), content);
    }
  });
  test('PDF and renamed binary fail explicitly, before learning', () async {
    expect(() => BookText341.validateName('book.PDF'), throwsFormatException);
    final f = File('${dir.path}/renamed.txt');
    await expectLater(
        BookText341.stage(Stream.value(utf8.encode('%PDF-1.7 binary')), f,
            name: 'renamed.txt'),
        throwsFormatException);
  });
  test('cancelling streaming intake does not accumulate the remaining file',
      () async {
    var cancel = false, produced = 0;
    Stream<List<int>> data() async* {
      for (var i = 0; i < 1000; i++) {
        produced++;
        yield Uint8List.fromList(List.filled(1024, 65));
      }
    }

    final f = File('${dir.path}/cancel.txt');
    final n = await BookText341.stage(data(), f,
        name: 'book.txt',
        cancelled: () => cancel,
        progress: (n) {
          if (n >= 4096) cancel = true;
        });
    expect(n, 4096);
    expect(produced, lessThan(8));
    expect(await f.length(), 4096);
  });
  test(
      'worker imports real prose, keeps main isolate alive, checkpoints and resumes without double-learning',
      () async {
    final f = File('${dir.path}/biology.txt');
    final text = List.generate(
                500,
                (i) =>
                    'La membrana cellulare separa l’ambiente interno da quello esterno. '
                    'Il laboratorio annota il campione $i e confronta le osservazioni.\n')
            .join() +
        'Il norvente insegue il talverio.\n';
    await f.writeAsString(text);
    var ticks = 0, cancel = false, checkpoints = 0, archived = 0;
    var largestGap = 0;
    final watch = Stopwatch()..start();
    var last = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      ticks++;
      final now = watch.elapsedMilliseconds;
      if (now - last > largestGap) largestGap = now - last;
      last = now;
    });
    Map<String, Map<String, dynamic>> saved = {};
    Future<void> save(Map<String, Uint8List> bytes) async {
      checkpoints++;
      saved = bytes.map((k, v) => MapEntry(
          k,
          normalized341(const StandardMessageCodec()
              .decodeMessage(ByteData.sublistView(v)))));
    }

    Future<void> archive(String text, String source) async {
      archived++;
    }

    try {
      final partial = await BookImporter341.run(
          file: f,
          source: 'Biologia',
          models: fresh341(),
          checkpoint: save,
          archive: archive,
          cancelled: () => cancel,
          progress: (n, c, p) {
            if (n >= 3) cancel = true;
          });
      expect(partial.cancelled, true);
      expect(partial.blocks, 3);
      expect(checkpoints, greaterThan(0));
      final recovered = BookModels341.fromMaps(saved);
      cancel = false;
      final complete = await BookImporter341.run(
          file: f,
          source: 'Biologia',
          models: recovered,
          checkpoint: save,
          archive: archive);
      expect(complete.error, isNull);
      expect(complete.cancelled, false);
      expect(complete.skipped, 3);
      expect(complete.characters, text.length);
      expect(
          RelationalMemory324.rows(complete.models.research)
              .any((r) => r['agent'] == 'norvente'),
          true);
      final sentences = complete.models.language.sentences;
      final archiveBefore = archived;
      final repeated = await BookImporter341.run(
          file: f,
          source: 'Biologia rinominata',
          models: complete.models,
          checkpoint: save,
          archive: archive);
      expect(repeated.models.language.sentences, sentences);
      expect(repeated.skipped, repeated.blocks);
      expect(archived, archiveBefore);
      expect(ticks, greaterThan(2));
      expect(largestGap, lessThan(2000));
      print('BOOK341_WORKER chars=${text.length} blocks=${complete.blocks} '
          'mainTimerTicks=$ticks maxGapMs=$largestGap checkpoints=$checkpoints '
          'elapsedMs=${watch.elapsedMilliseconds} rssBytes=${ProcessInfo.currentRss}');
    } finally {
      timer.cancel();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
  test('failed checkpoint aborts rather than silently reporting success',
      () async {
    final f = File('${dir.path}/failure.txt');
    await f.writeAsString('Il norvente insegue il talverio.');
    await expectLater(
        BookImporter341.run(
            file: f,
            source: 'book',
            models: fresh341(),
            checkpoint: (_) async {
              throw StateError('disk full');
            },
            archive: (_, __) async {}),
        throwsStateError);
  });
  test(
      'the semantic queue tokenizes a document once rather than once per sentence',
      () async {
    final m = fresh341();
    final doc = WebDocument11(
        provider: 'test',
        family: 'local',
        title: 'Appunti',
        url: 'local://queue-341',
        text: List.generate(
                120,
                (i) =>
                    'Questa pagina raccoglie la descrizione del campione $i.')
            .join(' '),
        trust: .75);
    final before = ResearchSemantics317.queueTokenizations341;
    ResearchSemantics317.enqueue(m.research, [doc],
        topic: 'Appunti', session: 'test');
    var batches = 0;
    while (ResearchSemantics317.getPending(m.research) > 0 && batches < 500) {
      ResearchSemantics317.processQueue(m.brain, m.world, m.research,
          maxUnits: 1);
      batches++;
    }
    expect(ResearchSemantics317.getPending(m.research), 0);
    expect(ResearchSemantics317.queueTokenizations341 - before, 1);
    expect(batches, greaterThan(100));
  });
}
