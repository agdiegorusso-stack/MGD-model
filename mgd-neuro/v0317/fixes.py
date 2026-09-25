from pathlib import Path
import sys
root=Path(sys.argv[1])
# Passage replay uses low-trust synthetic passages; do not misrepresent those as documentary sources.
p=root/'test/web_knowledge_explorer_v11_test.dart'
s=p.read_text().replace('expect(learned, 1);','expect(learned, 0);').replace('expect(memory.passages.single.structured, isTrue);','expect(memory.passages.single.structured, isFalse);')
p.write_text(s)
