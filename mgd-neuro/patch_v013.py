from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
main = root / 'lib' / 'main.dart'
pubspec = root / 'pubspec.yaml'

m = main.read_text()

import_anchor = "import 'knowledge_editor_v012.dart';\n"
if import_anchor not in m:
    raise SystemExit('knowledge editor import anchor missing')
m = m.replace(
    import_anchor,
    import_anchor + "import 'navigable_graph_v013.dart';\n",
    1,
)

m = m.replace("    final graph = brain.semanticGraph(limit: 20);\n", "", 1)

old = """        AspectRatio(
          aspectRatio: 1.55,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: _SemanticPainter04(graph),
              child: const SizedBox.expand(),
            ),
          ),
        ),
"""
new = """        NavigableSemanticGraph13(
          brain: brain,
          initialNodeLimit: 80,
        ),
"""
if old not in m:
    raise SystemExit('static semantic graph block missing')
m = m.replace(old, new, 1)

# Also replace the small graph in the alternate/legacy page if present.
m = m.replace(
    "final graph = widget.brain.semanticGraph(limit: 22);",
    "final graph = widget.brain.semanticGraph(limit: 120);",
)

m = m.replace('MGD Neuro 0.12.1', 'MGD Neuro 0.13')
m = m.replace('MGD-Neuro 0.12.1', 'MGD-Neuro 0.13')
m = m.replace('MGD Neuro 0.12', 'MGD Neuro 0.13')
m = m.replace('MGD-Neuro 0.12', 'MGD-Neuro 0.13')
m = m.replace('Nuovo cervello 0.12.1', 'Nuovo cervello 0.13')
m = m.replace('Nuovo cervello 0.12', 'Nuovo cervello 0.13')
m = m.replace('Cervello 0.12.1 ripristinato', 'Cervello 0.13 ripristinato')
m = m.replace('Cervello 0.12 ripristinato', 'Cervello 0.13 ripristinato')
main.write_text(m)

p = pubspec.read_text()
lines = p.splitlines()
changed = False
for i, line in enumerate(lines):
    if line.startswith('version:'):
        lines[i] = 'version: 0.13.0+20'
        changed = True
        break
if not changed:
    raise SystemExit('pubspec version line missing')
pubspec.write_text('\n'.join(lines) + '\n')
