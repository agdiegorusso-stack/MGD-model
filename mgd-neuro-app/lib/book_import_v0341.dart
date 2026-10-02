// BOOK_SOURCE_IDENTITY_0342
// Bounded book ingestion. The UI never owns a second in-memory book or parses
// the complete corpus. Worker checkpoints are committed before acknowledging.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';
import 'mgd_language_v020.dart';
import 'corpus_semantic_bridge_v022.dart';

class BookModels341 {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final ResearchMemory11 research;
  final MgdLanguage20 language;
  BookModels341(this.brain, this.world, this.research, this.language);

  Map<String, Map<String, dynamic>> maps() => {
        'brain_v051': brain.toJson(),
        'world_v06': world.toJson(),
        'research_v11': research.toJson(),
        'language_v20': language.toJson(),
        'checkpoint_v0319': {
          'version': '0.34.2',
          'at': DateTime.now().toIso8601String(),
          'brainEpisodes': brain.episodes.length,
          'worldCycles': world.thoughtCycles,
          'worldEdges': world.edges.length,
          'worldAge': world.entropicAge,
          'claims': research.claims.length,
          'evidence': research.evidence.length,
          'languageSentences': language.sentences
        },
      };
  static BookModels341 fromMaps(Map<String, Map<String, dynamic>> maps) =>
      BookModels341(
          PlasticLanguageBrain04.fromJson(maps['brain_v051']!),
          MgdWorld06.fromJson(maps['world_v06']!),
          ResearchMemory11.fromJson(maps['research_v11']!),
          MgdLanguage20.fromJson(maps['language_v20']!));
}

class BookFragment341 {
  final String text;
  // A hard split inside an overlong sentence must NEVER become a new fact.
  final bool semanticSafe;
  const BookFragment341(this.text, this.semanticSafe);
}

class BookText341 {
  static const blockChars = 4096;
  static final _boundary = RegExp(r'[.!?]\s+|\n+');

  static void validateName(String name) {
    final ext = name.toLowerCase().split('.').last;
    if ({
      'pdf',
      'epub',
      'doc',
      'docx',
      'zip',
      'gz',
      'png',
      'jpg',
      'jpeg',
      'mp3',
      'mp4'
    }.contains(ext)) {
      throw const FormatException('Questo importatore legge testo TXT. '
          'PDF, EPUB e documenti Word non sono testo grezzo: esportali in TXT. '
          'Il file non è stato interpretato come conoscenza.');
    }
  }

  static void validateHeader(List<int> bytes) {
    bool starts(List<int> magic) =>
        bytes.length >= magic.length &&
        List.generate(magic.length, (i) => bytes[i] == magic[i])
            .every((v) => v);
    if (starts([0x25, 0x50, 0x44, 0x46]) ||
        starts([0x50, 0x4b, 3, 4]) ||
        starts([0x1f, 0x8b]) ||
        starts([0x89, 0x50, 0x4e, 0x47]) ||
        starts([0xff, 0xd8, 0xff]) ||
        starts([0xd0, 0xcf, 0x11, 0xe0])) {
      throw const FormatException('Il contenuto è binario, non un libro TXT.');
    }
    final utf16 = starts([0xff, 0xfe]) || starts([0xfe, 0xff]);
    if (!utf16 && bytes.contains(0)) {
      throw const FormatException('Testo binario o codifica non riconosciuta. '
          'Usa TXT UTF-8 oppure UTF-16 con BOM.');
    }
  }

  /// Backpressure is preserved even if the provider emits one enormous block.
  /// No List<int> accumulator, readAsBytes(), or whole-book String is built.
  static Future<int> stage(Stream<List<int>> input, File destination,
      {required String name,
      bool Function()? cancelled,
      void Function(int)? progress}) async {
    validateName(name);
    final out = await destination.open(mode: FileMode.write);
    final header = <int>[];
    var n = 0;
    try {
      await for (final part in input) {
        for (var offset = 0; offset < part.length; offset += 65536) {
          if (cancelled?.call() ?? false) return n;
          final end = min(offset + 65536, part.length);
          if (header.length < 512) {
            header.addAll(
                part.skip(offset).take(min(end - offset, 512 - header.length)));
            validateHeader(header);
          }
          await out.writeFrom(part, offset, end);
          n += end - offset;
          progress?.call(n);
        }
      }
      if (n == 0) throw const FormatException('Il documento è vuoto.');
      return n;
    } finally {
      await out.close();
    }
  }

  static Stream<String> decode(File file) async* {
    final f = await file.open();
    late Uint8List head;
    try {
      head = await f.read(4096);
    } finally {
      await f.close();
    }
    validateHeader(head);
    final le = head.length >= 2 && head[0] == 0xff && head[1] == 0xfe;
    final be = head.length >= 2 && head[0] == 0xfe && head[1] == 0xff;
    if (le || be) {
      int? odd, high;
      await for (final bytes in file.openRead(2)) {
        final units = <int>[];
        var i = 0;
        if (high != null) {
          units.add(high);
          high = null;
        }
        if (odd != null && bytes.isNotEmpty) {
          units.add(le ? odd | (bytes[0] << 8) : (odd << 8) | bytes[0]);
          odd = null;
          i = 1;
        }
        for (; i + 1 < bytes.length; i += 2) {
          units.add(le
              ? bytes[i] | (bytes[i + 1] << 8)
              : (bytes[i] << 8) | bytes[i + 1]);
        }
        if (i < bytes.length) odd = bytes[i];
        if (units.isNotEmpty && units.last >= 0xd800 && units.last <= 0xdbff) {
          high = units.removeLast();
        }
        if (units.isNotEmpty) yield String.fromCharCodes(units);
      }
      if (odd != null || high != null) {
        throw const FormatException('Sequenza UTF-16 incompleta a fine file.');
      }
      return;
    }
    // Do not test the truncated last multibyte sequence of the sample.
    var sampleEnd = head.length;
    if (sampleEnd == 4096) {
      while (sampleEnd > 0 && (head[sampleEnd - 1] & 0xc0) == 0x80) sampleEnd--;
      if (sampleEnd > 0 && head[sampleEnd - 1] >= 0xc0) sampleEnd--;
    }
    var latin = false;
    try {
      utf8.decode(head.sublist(0, sampleEnd));
    } on FormatException {
      latin = true;
    }
    final Stream<String> decoded = latin
        ? file.openRead().transform(latin1.decoder)
        : file.openRead().transform(utf8.decoder);
    var first = true;
    await for (var text in decoded) {
      if (first) {
        text = text.replaceFirst(RegExp(r'^\uFEFF'), '');
        first = false;
      }
      yield text;
    }
  }

  static Stream<BookFragment341> fragments(Stream<String> input,
      {int limit = blockChars}) async* {
    if (limit < 32) throw ArgumentError.value(limit, 'limit');
    var carry = '', continued = false;
    await for (final incoming in input) {
      // Restrict temporary text independently of the upstream stream's size.
      for (var at = 0; at < incoming.length; at += limit) {
        carry += incoming.substring(at, min(at + limit, incoming.length));
        while (carry.length >= limit) {
          var cut = 0;
          for (final match in _boundary.allMatches(carry.substring(0, limit))) {
            cut = match.end;
          }
          final complete = cut > 0;
          if (!complete) {
            cut = limit;
            final last = carry.codeUnitAt(cut - 1);
            if (last >= 0xd800 && last <= 0xdbff) cut--;
          }
          yield BookFragment341(
              carry.substring(0, cut), complete && !continued);
          carry = carry.substring(cut);
          continued = !complete;
        }
      }
    }
    if (carry.isNotEmpty) yield BookFragment341(carry, !continued);
  }
}

class BookImportResult341 {
  final BookModels341 models;
  final int blocks, characters, skipped, oversized;
  final bool cancelled;
  final String? error;
  const BookImportResult341(this.models, this.blocks, this.characters,
      this.skipped, this.oversized, this.cancelled, this.error);
}

/// Every message that carries data requires an acknowledgement. There can be
/// only one outstanding block/checkpoint, preventing unbounded isolate mailboxes.
class BookImporter341 {
  static Future<BookImportResult341> run({
    required File file,
    required String source,
    required BookModels341 models,
    required Future<void> Function(Map<String, Uint8List>) checkpoint,
    required Future<void> Function(String, String) archive,
    bool Function()? cancelled,
    void Function(int blocks, int characters, String phase)? progress,
  }) async {
    final events = ReceivePort();
    Isolate? worker;
    SendPort? commands;
    try {
      worker = await Isolate.spawn(
          _bookWorker341, [events.sendPort, file.path, source, models],
          onError: events.sendPort,
          onExit: events.sendPort,
          errorsAreFatal: true);
      await for (final event in events) {
        if (event == null)
          throw StateError(
              'Il processo di importazione si è chiuso inaspettatamente.');
        if (event is! List || event.isEmpty)
          throw StateError('Messaggio importazione non valido.');
        final kind = event[0];
        if (kind == 'ready') {
          commands = event[1] as SendPort;
        } else if (kind == 'archive') {
          final keep = !(cancelled?.call() ?? false);
          if (keep) await archive(event[1] as String, source);
          commands!.send(keep);
        } else if (kind == 'progress') {
          progress?.call(event[1] as int, event[2] as int, event[3] as String);
          commands!.send(!(cancelled?.call() ?? false));
        } else if (kind == 'checkpoint') {
          final data = (event[1] as Map).map((k, v) => MapEntry(k as String,
              (v as TransferableTypedData).materialize().asUint8List()));
          await checkpoint(data);
          commands!.send(!(cancelled?.call() ?? false));
        } else if (kind == 'failure') {
          throw StateError('Importazione: ${event[1]}');
        } else if (kind == 'done') {
          return event[1] as BookImportResult341;
        } else {
          throw StateError(
              'Errore nel processo di importazione: ${event.first}');
        }
      }
      throw StateError('Importazione senza risultato.');
    } finally {
      worker?.kill(priority: Isolate.immediate);
      events.close();
    }
  }
}

Future<void> _bookWorker341(List<Object> args) async {
  final reply = args[0] as SendPort, file = File(args[1] as String);
  final source = args[2] as String, models = args[3] as BookModels341;
  final port = ReceivePort();
  // The actual command iterator is separate so it has precisely one listener.
  final commands = StreamIterator<dynamic>(port);
  reply.send(['ready', port.sendPort]);
  var blocks = 0, characters = 0, skipped = 0, oversized = 0;
  var stopped = false;
  String? error;
  Future<bool> ack() async =>
      await commands.moveNext() && commands.current == true;
  Future<bool> save() async {
    final packed = <String, TransferableTypedData>{};
    for (final entry in models.maps().entries) {
      final data = const StandardMessageCodec().encodeMessage(entry.value)!;
      packed[entry.key] = TransferableTypedData.fromList(
          [data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)]);
    }
    reply.send(['checkpoint', packed]);
    return ack();
  }

  try {
    reply.send(
        ['progress', 0, 0, 'Verifica del file e ricerca del punto di ripresa']);
    stopped = !await ack();
    if (!stopped) {
      final identity = (await sha256.bind(file.openRead()).first).toString();
      final journal = Map<String, dynamic>.from(
          models.research.state317['bookImports341'] as Map? ?? {});
      models.research.state317['bookImports341'] = journal;
      final old = Map<String, dynamic>.from(journal[identity] as Map? ?? {});
      final completed = (old['blocks'] as num? ?? 0).toInt();
      oversized = (old['oversized'] as num? ?? 0).toInt();
      var sinceSave = 0;
      final saveClock = Stopwatch()..start();
      await for (final fragment
          in BookText341.fragments(BookText341.decode(file))) {
        blocks++;
        characters += fragment.text.length;
        if (blocks <= completed) {
          skipped++;
          if (blocks % 64 == 0) {
            reply.send([
              'progress',
              blocks,
              characters,
              'Ripresa dei blocchi già salvati'
            ]);
            if (!await ack()) {
              stopped = true;
              blocks = completed;
              characters = (old['characters'] as num? ?? characters).toInt();
              break;
            }
          }
          continue;
        }
        reply.send(['archive', fragment.text]);
        if (!await ack()) {
          blocks--;
          characters -= fragment.text.length;
          stopped = true;
          break;
        }
        if (fragment.semanticSafe) {
          models.language.ingestText(fragment.text, reward: .42);
          await CorpusSemanticBridge22.learn(
              text: fragment.text,
              sourceName: source,
              brain: models.brain,
              world: models.world,
              memory: models.research,
              inlineExtraction341: true,
              sourceUrl342: 'local://book/$identity/$blocks');
        } else {
          oversized++;
          // Raw text is already archived; avoid inferring facts from a severed
          // conditional or a fragment of a very long sentence.
          models.language
              .ingestText(fragment.text, reward: .42, learnFrames341: false);
        }
        journal[identity] = {
          'source': source,
          'blocks': blocks,
          'characters': characters,
          'status': 'in corso',
          'oversized': oversized,
          'at': DateTime.now().toIso8601String()
        };
        sinceSave++;
        reply.send([
          'progress',
          blocks,
          characters,
          'Estrazione incrementale della conoscenza'
        ]);
        if (!await ack()) {
          stopped = true;
          break;
        }
        if (sinceSave >= 16 || saveClock.elapsedMilliseconds >= 3000) {
          if (!await save()) {
            stopped = true;
            break;
          }
          sinceSave = 0;
          saveClock.reset();
        }
      }
      journal[identity] = {
        'source': source,
        'blocks': blocks,
        'characters': characters,
        'status': stopped ? 'interrotto' : 'completo',
        'oversized': oversized,
        'at': DateTime.now().toIso8601String()
      };
    }
  } catch (e, st) {
    error = '$e';
    models.world.runtime319['bookImportError341'] = {
      'error': '$e',
      'stack': '$st',
      'blocks': blocks,
      'at': DateTime.now().toIso8601String()
    };
  }
  if (error != null) {
    await commands.cancel();
    port.close();
    Isolate.exit(reply, ['failure', error]);
  }
  // Even cancellation preserves a coherent completed prefix. A failed SQLite
  // commit is NOT acknowledged; the caller restores the last durable snapshot.
  await save();
  await commands.cancel();
  port.close();
  Isolate.exit(reply, [
    'done',
    BookImportResult341(
        models, blocks, characters, skipped, oversized, stopped, error)
  ]);
}
