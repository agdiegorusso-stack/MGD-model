from pathlib import Path
import sys
root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'test' / 'web_knowledge_explorer_v10_test.dart'
s = p.read_text()
s = s.replace("final now = DateTime(2026, 9, 22, 9, 0);", "final now = DateTime.now();")
p.write_text(s)
