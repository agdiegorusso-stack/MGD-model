from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'lib' / 'web_knowledge_explorer_v11.dart'
s = p.read_text()

old = """class ResearchGoal11 {
  final String query;
  final String topic;
  final String reason;
  final double value;

  const ResearchGoal11({required this.query, required this.topic, required this.reason, required this.value});
  String get focusLabel => topic;
}
"""
new = """class ResearchGoal11 {
  final String query;
  final String topic;
  final String reason;
  final double value;
  final List<String> contextTerms;

  const ResearchGoal11({
    required this.query,
    required this.topic,
    required this.reason,
    required this.value,
    this.contextTerms = const <String>[],
  });
  String get focusLabel => topic;
}
"""
if old not in s:
    raise SystemExit('ResearchGoal11 v0.12 compatibility block missing')
s = s.replace(old, new, 1)
p.write_text(s)
