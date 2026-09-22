from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')

admin = root / 'lib' / 'brain_admin_v012.dart'
s = admin.read_text()
s = s.replace("aLabel:candidates.isbrain, e.a),", "aLabel: nodeLabel12(brain, e.a),")
s = s.replace("bLabel:candidates.isbrain, e.b),", "bLabel: nodeLabel12(brain, e.b),")
s = s.replace("a:candi,", "a: node,")
admin.write_text(s)

main = root / 'lib' / 'main.dart'
m = main.read_text()

world_ctor_old = """  const _WorldPage07({
    required this.brain,
    required this.world,
    required this.last,
    required this.busy,
    required this.onImportTeacher,
  });
"""
world_ctor_new = """  const _WorldPage07({
    required this.brain,
    required this.world,
    required this.last,
    required this.busy,
    required this.onImportTeacher,
    required this.onEdit,
  });
"""
if world_ctor_old in m:
    m = m.replace(world_ctor_old, world_ctor_new, 1)

mind_ctor_old = """  const _MindPage07({
    required this.brain,
    required this.world,
    required this.research,
    required this.busy,
    required this.researchBusy,
    required this.onThink,
    required this.onSleep,
    required this.onResearch,
    required this.onResearchEnabled,
    required this.onSave,
    required this.onReset,
  });
"""
mind_ctor_new = """  const _MindPage07({
    required this.brain,
    required this.world,
    required this.research,
    required this.busy,
    required this.researchBusy,
    required this.onThink,
    required this.onSleep,
    required this.onResearch,
    required this.onResearchEnabled,
    required this.onEdit,
    required this.onSave,
    required this.onReset,
  });
"""
if mind_ctor_old in m:
    m = m.replace(mind_ctor_old, mind_ctor_new, 1)

main.write_text(m)
