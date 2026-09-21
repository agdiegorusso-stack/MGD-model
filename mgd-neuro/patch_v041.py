from pathlib import Path
import sys

p = Path(sys.argv[1] if len(sys.argv) > 1 else "mgd-neuro-app/lib/plastic_language_brain_v04.dart")
s = p.read_text()

s = s.replace(
    "      assemblies[id]\n        ..count++\n        ..lastSeen = step;",
    "      final assembly = assemblies[id];\n      assembly.count += 1;\n      assembly.lastSeen = step;",
)
s = s.replace(
    "    entities[subjectId]\n      ..mentions++\n      ..lastSeen = step;",
    "    final subjectEntity = entities[subjectId];\n    subjectEntity.mentions += 1;\n    subjectEntity.lastSeen = step;",
)

start = s.index("  String? _semanticFamilyOf(String raw) {")
end = s.index("\n  int _ensureSemanticRelation(", start)
semantic = """  String? _semanticFamilyOf(String raw) {
    final n = normalizeText(raw);
    final stem = _stem(n);

    final exactSurface = <String>{};
    for (final entry in _semanticCueFamilies.entries) {
      if (entry.value.contains(n)) exactSurface.add(entry.key);
    }
    if (exactSurface.length == 1) return exactSurface.first;
    if (exactSurface.length > 1) return null;

    final exactStem = <String>{};
    for (final entry in _semanticCueFamilies.entries) {
      if (entry.value.contains(stem)) exactStem.add(entry.key);
    }
    if (exactStem.length == 1) return exactStem.first;
    if (exactStem.length > 1) return null;

    final forward = <String>{};
    for (final entry in _semanticCueFamilies.entries) {
      for (final cue in entry.value) {
        if (cue.length < 4) continue;
        final surfaceExtension =
            n.startsWith(cue) && n.length >= cue.length + 2;
        final stemExtension =
            stem.startsWith(cue) && stem.length >= cue.length + 2;
        if (surfaceExtension || stemExtension) forward.add(entry.key);
      }
    }
    if (forward.length == 1) return forward.first;
    if (forward.length > 1) return null;

    if (n.length >= 5 || stem.length >= 5) {
      final reverse = <String>{};
      for (final entry in _semanticCueFamilies.entries) {
        for (final cue in entry.value) {
          if (cue.startsWith(n) || cue.startsWith(stem)) {
            reverse.add(entry.key);
          }
        }
      }
      if (reverse.length == 1) return reverse.first;
    }
    return null;
  }
"""
s = s[:start] + semantic + s[end:]

# Migration/retrieval fallback: old 0.4 relations such as rel:compan can still
# be matched to their new semantic family even if a legacy slot escaped
# normalization. This makes persisted user brains forward-compatible.
old = """    if (ra.key.startsWith('sem:') && ra.key == rb.key) return 1.0;
    final ca = ra.cues.keys.toSet();
"""
new = """    if (ra.key.startsWith('sem:') && ra.key == rb.key) return 1.0;

    String? semanticFamily(RelationMemory04 r) {
      if (r.key.startsWith('sem:')) return r.key.substring(4);
      final byLabel = _semanticFamilyOf(r.label);
      if (byLabel != null) return byLabel;
      final found = <String>{};
      for (final cue in r.cues.keys) {
        final family = _semanticFamilyOf(cue);
        if (family != null) found.add(family);
      }
      return found.length == 1 ? found.first : null;
    }

    final fa = semanticFamily(ra);
    final fb = semanticFamily(rb);
    if (fa != null && fb != null && fa == fb) return 1.0;

    final ca = ra.cues.keys.toSet();
"""
if old not in s:
    raise SystemExit("relation similarity anchor not found")
s = s.replace(old, new, 1)

p.write_text(s)
