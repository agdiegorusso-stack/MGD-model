from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'lib' / 'web_knowledge_explorer_v11.dart'
s = p.read_text()

if 'int get independentSourceCount => independentSources;' not in s:
    old = "  int get independentSources => sourceFamilies.length;\n"
    if old not in s:
        raise SystemExit('ResearchClaim11 compatibility anchor missing')
    s = s.replace(
        old,
        old + "  int get independentSourceCount => independentSources;\n",
        1,
    )

if 'String get focusLabel => topic;' not in s:
    old = "  const ResearchGoal11({required this.query, required this.topic, required this.reason, required this.value});\n"
    if old not in s:
        raise SystemExit('ResearchGoal11 compatibility anchor missing')
    s = s.replace(
        old,
        old + "  String get focusLabel => topic;\n",
        1,
    )

p.write_text(s)
