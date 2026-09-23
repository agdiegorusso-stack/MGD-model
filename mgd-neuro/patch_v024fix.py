from pathlib import Path
import sys
root=Path(sys.argv[1])

p=root/'lib'/'corpus_semantic_bridge_v022.dart'
s=p.read_text()
s=s.replace('  const CorpusSemanticOutcome22({required this.sentences,required this.candidates,required this.accepted,required this.doubtful,required this.conflicts,required this.reinforced,required this.entitiesTouched});',
            '  CorpusSemanticOutcome22({required this.sentences,required this.candidates,required this.accepted,required this.doubtful,required this.conflicts,required this.reinforced,required this.entitiesTouched});',1)
p.write_text(s)

p=root/'lib'/'cognitive_induction_v024.dart'
s=p.read_text()
s=s.replace("'era','è','e','sono'","'era','è','sono'",1)
p.write_text(s)
