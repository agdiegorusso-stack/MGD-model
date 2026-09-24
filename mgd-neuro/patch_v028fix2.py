from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'lib' / 'plastic_language_brain_v04.dart'
s = p.read_text()

old = """class ResponseSlot028 {
  final String promptKey;
  String promptSurface;
  final Map<String, ResponseCandidate028> candidates;

  ResponseSlot028({
    required this.promptKey,
    required this.promptSurface,
    Map<String, ResponseCandidate028>? candidates,
  }) : candidates = candidates ?? <String, ResponseCandidate028>{};

  Map<String, dynamic> toJson() => {
        'promptKey': promptKey,
        'promptSurface': promptSurface,
        'candidates': candidates.values.map((e) => e.toJson()).toList(),
      };

  factory ResponseSlot028.fromJson(Map<String, dynamic> j) => ResponseSlot028(
        promptKey: (j['promptKey'] ?? '').toString(),
        promptSurface: (j['promptSurface'] ?? '').toString(),
        candidates: {
          for (final raw in ((j['candidates'] as List?) ?? const []))
            if (raw is Map)
              ResponseCandidate028.fromJson(Map<String, dynamic>.from(raw)).key:
                  ResponseCandidate028.fromJson(Map<String, dynamic>.from(raw)),
        },
      );
}
"""

new = """class ResponseSlot028 {
  final String promptKey;
  String promptSurface;
  final Map<String, ResponseCandidate028> candidates;
  int responseTick;

  ResponseSlot028({
    required this.promptKey,
    required this.promptSurface,
    Map<String, ResponseCandidate028>? candidates,
    this.responseTick = 0,
  }) : candidates = candidates ?? <String, ResponseCandidate028>{};

  Map<String, dynamic> toJson() => {
        'promptKey': promptKey,
        'promptSurface': promptSurface,
        'responseTick': responseTick,
        'candidates': candidates.values.map((e) => e.toJson()).toList(),
      };

  factory ResponseSlot028.fromJson(Map<String, dynamic> j) {
    final parsed = <String, ResponseCandidate028>{};
    for (final raw in ((j['candidates'] as List?) ?? const [])) {
      if (raw is! Map) continue;
      final candidate = ResponseCandidate028.fromJson(Map<String, dynamic>.from(raw));
      parsed[candidate.key] = candidate;
    }
    final storedTick = (j['responseTick'] as num?)?.toInt() ?? 0;
    final maxUsed = parsed.values.fold<int>(0, (m, c) => c.lastUsed > m ? c.lastUsed : m);
    return ResponseSlot028(
      promptKey: (j['promptKey'] ?? '').toString(),
      promptSurface: (j['promptSurface'] ?? '').toString(),
      candidates: parsed,
      responseTick: storedTick > maxUsed ? storedTick : maxUsed,
    );
  }
}
"""

if old not in s:
    raise SystemExit('ResponseSlot028 anchor missing')
s = s.replace(old, new, 1)

old = """  String? _responseFromAttractor028(String prompt) {
    final slot = _bestResponseSlot028(prompt);
    if (slot == null || slot.candidates.isEmpty) return null;
    final q = _responseCues028(prompt);
    final xs = slot.candidates.values.toList();
    xs.sort((a, b) {
      double score(ResponseCandidate028 x) {
        final overlap = q.isEmpty ? 0.0 : q.intersection(x.contextCues).length / max(1, q.union(x.contextCues).length);
        final age = max(0, step - x.lastUsed);
        final recencyPenalty = age <= 2 ? 0.22 : (age <= 6 ? 0.08 : 0.0);
        return x.strength + 0.035 * min(4, x.supports) + 0.12 * overlap - recencyPenalty;
      }
      return score(b).compareTo(score(a));
    });
    final chosen = xs.first;
    chosen.lastUsed = step;
    return chosen.text;
  }
"""

new = """  String? _responseFromAttractor028(String prompt) {
    final slot = _bestResponseSlot028(prompt);
    if (slot == null || slot.candidates.isEmpty) return null;
    final q = _responseCues028(prompt);

    // Response attractors have their own entropic clock. The language-learning
    // step is advanced by token edges and is therefore the wrong timebase for
    // lateral inhibition between alternative replies.
    slot.responseTick++;
    final tick = slot.responseTick;

    final xs = slot.candidates.values.toList();
    xs.sort((a, b) {
      double score(ResponseCandidate028 x) {
        final overlap = q.isEmpty
            ? 0.0
            : q.intersection(x.contextCues).length /
                max(1, q.union(x.contextCues).length);
        final age = max(0, tick - x.lastUsed);
        // Short refractory period: a recently emitted attractor is temporarily
        // inhibited, allowing other plausible states to become active.
        final recencyPenalty = age <= 1
            ? 0.30
            : (age <= 3 ? 0.14 : (age <= 6 ? 0.05 : 0.0));
        return x.strength +
            0.035 * min(4, x.supports) +
            0.12 * overlap -
            recencyPenalty;
      }

      final byScore = score(b).compareTo(score(a));
      if (byScore != 0) return byScore;
      return a.key.compareTo(b.key);
    });

    final chosen = xs.first;
    chosen.lastUsed = tick;
    return chosen.text;
  }
"""

if old not in s:
    raise SystemExit('_responseFromAttractor028 anchor missing')
s = s.replace(old, new, 1)

p.write_text(s)
print('MGD Neuro 0.28 response-attractor clock fix applied')
