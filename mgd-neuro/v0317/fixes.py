from pathlib import Path
# Apply the complete checked-in production patch before fixture assertions.
base=Path(__file__).with_name('base_fixes.py')
exec(compile(base.read_text(),str(base),'exec'))
# This legacy fixture has an empty document and a synthetic preliminary count.
# Keep the preliminary count in the audit, not in the actually-read counter.
edit('test/web_knowledge_explorer_v11_test.dart',
     'expect(memory.lastSession!.sentencesRead, 3);',
     "expect(memory.lastSession!.sentencesRead, 0);\n    expect(memory.lastSession!.audit315['preliminarySentencesRead'], 3);\n    expect(memory.lastSession!.audit315['sentences'] ?? [], isEmpty);")
