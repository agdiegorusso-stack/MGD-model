"""Summarize measured results using unchanged predeclared selection rules."""
import json,pathlib,hashlib
from mgd_reader_selection441 import qualify
base=pathlib.Path(__file__).resolve().parent
root=base.parent
paths={'premises':root/'mgd441-premises/grounding-premises.json','guided':root/'mgd441-guided/grounding-guided.json','larger_corrected':root/'mgd441-larger-corrected/larger-corrected441.json'}
result={'all_prior_40_cases_are_development':True,'universal_comprehension_proven':False,'candidates':{}}
for name,p in paths.items():
    if not p.is_file():result['candidates'][name]={'status':'not_completed'};continue
    r=json.loads(p.read_text());ok=qualify(r['scores'],quotes=name in ('premises','guided'))
    result['candidates'][name]={'scores':r['scores'],'eligible':ok,'report_sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
out=root/'mgd441-report/comparison441.json';out.parent.mkdir(exist_ok=True);out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
