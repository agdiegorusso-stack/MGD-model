import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class BookFragment420 {
  final String text;
  // A hard split inside an overlong sentence must NEVER become a new fact.
  final bool semanticSafe;
  const BookFragment420(this.text, this.semanticSafe);
}

class BookText420 {
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
      'mp4',
    }.contains(ext)) {
      throw const FormatException(
        'Questo importatore legge testo TXT. '
        'PDF, EPUB e documenti Word non sono testo grezzo: esportali in TXT. '
        'Il file non è stato interpretato come conoscenza.',
      );
    }
  }

  static void validateHeader(List<int> bytes) {
    bool starts(List<int> magic) =>
        bytes.length >= magic.length &&
        List.generate(
          magic.length,
          (i) => bytes[i] == magic[i],
        ).every((v) => v);
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
      throw const FormatException(
        'Testo binario o codifica non riconosciuta. '
        'Usa TXT UTF-8 oppure UTF-16 con BOM.',
      );
    }
  }

  /// Backpressure is preserved even if the provider emits one enormous block.
  /// No List<int> accumulator, readAsBytes(), or whole-book String is built.
  static Future<int> stage(
    Stream<List<int>> input,
    File destination, {
    required String name,
    bool Function()? cancelled,
    void Function(int)? progress,
  }) async {
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
              part.skip(offset).take(min(end - offset, 512 - header.length)),
            );
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
          units.add(
            le
                ? bytes[i] | (bytes[i + 1] << 8)
                : (bytes[i] << 8) | bytes[i + 1],
          );
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

  static Stream<BookFragment420> fragments(
    Stream<String> input, {
    int limit = blockChars,
  }) async* {
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
          yield BookFragment420(
            carry.substring(0, cut),
            complete && !continued,
          );
          carry = carry.substring(cut);
          continued = !complete;
        }
      }
    }
    if (carry.isNotEmpty) yield BookFragment420(carry, !continued);
  }
}
