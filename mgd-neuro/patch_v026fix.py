from pathlib import Path
import sys
root=Path(sys.argv[1])
p=root/'lib'/'mgd_language_v020.dart'
s=p.read_text()
if "import 'dart:async';" not in s:
    s=s.replace("import 'dart:convert';","import 'dart:async';\nimport 'dart:convert';",1)
p.write_text(s)
