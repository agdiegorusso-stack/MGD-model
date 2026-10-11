"""Necessary-condition audit, not a new comprehension model.

The oracle intervention is diagnostic only, is explicitly reported, and is
never deployed. It supplies the true question intent to isolate later errors.
This does not count as improved autonomous performance.
"""
import hashlib,json,sys
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'research/mgd443_reader'))
from reader import Reader,SourceReader,Coreference

REPORT=next(p for p in [ROOT/'research/mgd443_reader/results',
    ROOT.parent/'mgd443-build-verification/research/mgd443_reader/results']
    if (p/'reader443-delivered.json').is_file())
INTENTS=['agent','recipient','time','status','condition','location','agent',
 'recipient','object','agent','object','time','object','time','status','agent',
 'status','object','unsupported','status','unsupported']

def fingerprint(reader):
    h=hashlib.sha256()
    for k,v in sorted(reader.p.items()):h.update(k.encode());h.update(v.tobytes())
    h.update(reader.qw.tobytes());h.update(reader.qb.tobytes())
    return h.hexdigest()

def correct(case,answer):
    ok=bool(answer['unknown']) if case.get('unknown') else not answer['unknown']
    if 'answer' in case:ok=ok and answer.get('answer','').lower()==case['answer'].lower()
    if 'scope' in case:ok=ok and answer.get('scope')==case['scope']
    return bool(ok)

class OracleIntentReader(Reader):
    def __init__(self,path,intents):super().__init__(path);self.intents=intents
    def inspect(self,text):
        result=super().inspect(text)
        if text in self.intents:
            result['question_type']=self.intents[text];result['question_confidence']=1.
        return result

def main():
    model=REPORT/'reader443-delivered.json';coref=REPORT/'coreference443-delivered.json'
    data=json.loads((REPORT/'final-audit-results.json').read_text());cases=data['cases']
    reader=Reader(model);source=SourceReader(reader,Coreference(coref));before=fingerprint(reader)
    # Repeated reading does not update the semantics of this deployed reader.
    for _ in range(10):
        for c in cases:source.events(c['text'])
    after=fingerprint(reader);assert before==after
    intents={c['question']:kind for c,kind in zip(cases,INTENTS)}
    oracle=SourceReader(OracleIntentReader(model,intents),Coreference(coref));details=[]
    for c in cases:
        actual=source.answer(c['text'],c['question']);injected=oracle.answer(c['text'],c['question'])
        details.append({'id':c['id'],'actual_correct':correct(c,actual),
          'oracle_intent_correct':correct(c,injected),'actual_unknown':actual['unknown'],
          'oracle_unknown':injected['unknown'],'actual_reason':actual.get('reason'),
          'oracle_reason':injected.get('reason'),'oracle_answer':injected.get('answer')})
    p1=np.array(reader.inspect('Anna aiuta Marco.')['scope_distribution'])
    p2=np.array(reader.inspect('Marco aiuta Anna.')['scope_distribution'])
    # EXACT theoretical counterexample, separate from the approximate model.
    # Q_scope sees two asserted episodes: TV=0. Expanding Q with "Who helps?"
    # sees delta_Anna vs delta_Marco: TV=1. These are task-dependent categories.
    theoretical={'scope_only_distance':0.,'scope_and_agent_distance':1.,
       'agent_ground_truth_supplied_for_counterexample_only':True,
       'symmetric_metric_does_not_prohibit_encoding_ordered_roles':True}
    result={'deployed_semantic_weights_changed_by_210_readings':False,
      'weights_before':before,'weights_after':after,'observations':len(cases)*10,
      'actual_correct':sum(x['actual_correct'] for x in details),'total':len(details),
      'oracle_intent_correct':sum(x['oracle_intent_correct'] for x in details),
      'oracle_is_not_autonomous_performance':True,'cases':details,
      'empirical_scope_distance_role_swap':float(.5*np.abs(p1-p2).sum()),
      'theoretical_Q_counterexample':theoretical,
      'conclusion':'Need learned persistent event bindings and a semantic outcome learning signal; scope geometry alone is insufficient.',
      'general_comprehension_solved':False,'app_changed':False}
    out=Path(__file__).parent/'diagnosis-results.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print(json.dumps({k:v for k,v in result.items() if k!='cases'},ensure_ascii=False))
    print(json.dumps(details,ensure_ascii=False))

if __name__=='__main__':main()
