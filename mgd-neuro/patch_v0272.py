from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')

# Robust teacher-pack decoding: plain JSON, gzip JSON, and ZIP bundles.
p = root / 'lib' / 'teacher_bridge_v08.dart'
s = p.read_text()

if "package:archive/archive.dart" not in s:
    s = s.replace(
        "import 'package:flutter/foundation.dart';\n",
        "import 'package:flutter/foundation.dart';\nimport 'package:archive/archive.dart';\n",
        1,
    )

old = """Map<String, dynamic> _decodeTeacherPackJson08(Uint8List bytes) {
  final raw = jsonDecode(utf8.decode(bytes));
  if (raw is! Map) {
    throw const FormatException(
      'Il knowledge pack deve essere un oggetto JSON.',
    );
  }
  return Map<String, dynamic>.from(raw);
}
"""

new = r"""bool _hasPrefix08(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

Uint8List _stripUtf8Bom08(Uint8List bytes) {
  if (_hasPrefix08(bytes, const [0xEF, 0xBB, 0xBF])) {
    return Uint8List.sublistView(bytes, 3);
  }
  return bytes;
}

Map<String, dynamic> _decodeTeacherJsonMap08(
  Uint8List bytes, {
  String sourceName = 'knowledge pack',
}) {
  try {
    final text = utf8.decode(_stripUtf8Bom08(bytes));
    final raw = jsonDecode(text);
    if (raw is! Map) {
      throw FormatException(
        '$sourceName: il knowledge pack deve essere un oggetto JSON.',
      );
    }
    return Map<String, dynamic>.from(raw);
  } on FormatException catch (e) {
    throw FormatException('$sourceName: ${e.message}');
  }
}

Map<String, dynamic> _decodeTeacherZip08(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final jsonFiles = archive
      .where((f) {
        if (!f.isFile) return false;
        final name = f.name.toLowerCase();
        return name.endsWith('.mgd.json') ||
            (name.endsWith('.json') && !name.endsWith('manifest.json'));
      })
      .toList();

  if (jsonFiles.isEmpty) {
    throw const FormatException(
      'Archivio ZIP valido, ma non contiene alcun file .mgd.json.',
    );
  }

  // Prefer the canonical all-in-one pack when present. This is exactly the
  // layout used by MGD_Biology_GigaPack_v2.zip.
  jsonFiles.sort((a, b) {
    int score(String name) {
      final n = name.toLowerCase();
      if (n.contains('all_in_one') || n.contains('all-in-one')) return 3;
      if (n.endsWith('.mgd.json')) return 2;
      return 1;
    }

    final byScore = score(b.name).compareTo(score(a.name));
    if (byScore != 0) return byScore;
    return b.size.compareTo(a.size);
  });

  final best = jsonFiles.first;
  return _decodeTeacherJsonMap08(
    best.content,
    sourceName: 'ZIP/${best.name}',
  );
}

Map<String, dynamic> _decodeTeacherPackJson08(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const FormatException('Knowledge pack vuoto.');
  }

  // ZIP local-file signature: 50 4B 03 04.
  if (_hasPrefix08(bytes, const [0x50, 0x4B, 0x03, 0x04])) {
    return _decodeTeacherZip08(bytes);
  }

  // GZIP: 1F 8B.
  if (_hasPrefix08(bytes, const [0x1F, 0x8B])) {
    final decoded = GZipDecoder().decodeBytes(bytes, verify: true);
    return _decodeTeacherJsonMap08(
      decoded,
      sourceName: 'knowledge pack GZIP',
    );
  }

  return _decodeTeacherJsonMap08(bytes);
}
"""

if old not in s:
    raise SystemExit('teacher decoder anchor missing')
s = s.replace(old, new, 1)
p.write_text(s)

# File picker: explicitly allow ZIP bundles too, and show the detected container.
p = root / 'lib' / 'main.dart'
s = p.read_text()
s = s.replace("MGD Neuro 0.27.1", "MGD Neuro 0.27.2")
s = s.replace(
    "allowedExtensions: const ['json', 'mgdpack'],",
    "allowedExtensions: const ['json', 'mgdpack', 'zip', 'gz'],",
    1,
)

old = """      if (mounted) {
        setState(() => _status = 'Decodifica knowledge pack in background…');
      }
      final pack = await TeacherPack08.fromBytesAsync(bytes);
"""
new = """      if (mounted) {
        final isZip = bytes.length >= 4 &&
            bytes[0] == 0x50 &&
            bytes[1] == 0x4B &&
            bytes[2] == 0x03 &&
            bytes[3] == 0x04;
        final isGzip =
            bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B;
        setState(() {
          _status = isZip
              ? 'Apertura archivio ZIP e ricerca pack ALL_IN_ONE…'
              : isGzip
                  ? 'Decompressione knowledge pack GZIP…'
                  : 'Decodifica knowledge pack JSON in background…';
        });
      }
      final pack = await TeacherPack08.fromBytesAsync(bytes);
"""
if old not in s:
    raise SystemExit('main decode status anchor missing')
s = s.replace(old, new, 1)
p.write_text(s)

# Add archive dependency and bump version.
p = root / 'pubspec.yaml'
s = p.read_text()
if '  archive:' not in s:
    s = s.replace('  sqflite: ^2.4.2\n', '  sqflite: ^2.4.2\n  archive: ^4.3.0\n', 1)
if 'version: 0.27.1+43' not in s:
    raise SystemExit('pubspec 0.27.1 version anchor missing')
s = s.replace('version: 0.27.1+43', 'version: 0.27.2+44', 1)
p.write_text(s)

# Extend tests with the exact failure mode: a ZIP whose offset 11 is non-UTF8.
p = root / 'test' / 'teacher_bridge_v08_test.dart'
s = p.read_text()
if "package:archive/archive.dart" not in s:
    s = s.replace(
        "import 'package:flutter_test/flutter_test.dart';\n",
        "import 'package:flutter_test/flutter_test.dart';\nimport 'package:archive/archive.dart';\nimport 'dart:convert';\nimport 'dart:typed_data';\n",
        1,
    )

if "decodes MGD ZIP bundle and prefers ALL_IN_ONE" not in s:
    marker = "\n}\n"
    idx = s.rfind(marker)
    if idx < 0:
        raise SystemExit('test file closing brace missing')
    test = r"""

  test('decodes MGD ZIP bundle and prefers ALL_IN_ONE', () async {
    const payload = {
      'format': 'mgd-teacher-pack-v1',
      'teacher': {'model': 'zip-test', 'source': 'unit'},
      'facts': [
        {
          'subject': 'cellula',
          'relation': 'contiene',
          'object': 'DNA',
          'confidence': 0.9
        }
      ],
      'links': []
    };

    final archive = Archive()
      ..addFile(ArchiveFile.string('manifest.json', '{"kind":"manifest"}'))
      ..addFile(
        ArchiveFile.string(
          'BIOLOGY_GIGAPACK_ALL_IN_ONE.mgd.json',
          jsonEncode(payload),
        ),
      );
    final zipped = ZipEncoder().encode(archive);
    final pack = await TeacherPack08.fromBytesAsync(Uint8List.fromList(zipped));

    expect(pack.model, 'zip-test');
    expect(pack.facts.length, 1);
    expect(pack.facts.single.subject, 'cellula');
    expect(pack.facts.single.object, 'DNA');
  });
"""
    s = s[:idx] + test + s[idx:]
p.write_text(s)

print('MGD Neuro 0.27.2 ZIP/GZIP teacher-pack patch applied')
