from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'lib' / 'mgd_language_v020.dart'
s = p.read_text()

s = s.replace(
    "e.a==from && e.cost<=1.35",
    "e.a == from && e.cost <= 2.35",
)
s = s.replace(
    "e.a == from && e.cost <= 1.35",
    "e.a == from && e.cost <= 2.35",
)

# Do not allow an empty sentence to terminate directly from BOS.
anchor = "final starts=_next('<bos>');"
if anchor in s and "starts.removeWhere((e)=>e.b=='<eos>');" not in s:
    s = s.replace(
        anchor,
        anchor + "\n    starts.removeWhere((e)=>e.b=='<eos>');",
        1,
    )

# If EOS wins too early, continue through the strongest non-EOS path.
old = "cand.sort((a,b)=>_scoreCandidate(b,wanted,used).compareTo(_scoreCandidate(a,wanted,used)));\n      final e=cand.first;"
new = """cand.sort((a,b)=>_scoreCandidate(b,wanted,used).compareTo(_scoreCandidate(a,wanted,used)));
      var e=cand.first;
      if(e.b=='<eos>' && out.length<4){
        final alt=cand.where((x)=>x.b!='<eos>').toList();
        if(alt.isNotEmpty)e=alt.first;
      }"""
if old in s:
    s = s.replace(old, new, 1)

p.write_text(s)
