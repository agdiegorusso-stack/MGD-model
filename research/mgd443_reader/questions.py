"""Factorized learned question head. The previous tests are development now.
Sentence roles stay recurrent. Question meaning uses learned lexical and
ordered ngram evidence. No runtime keyword-to-answer mapping is used.
"""
import json,hashlib
from pathlib import Path
import numpy as np
from scipy.sparse import csr_matrix
from train import question_data,QUESTIONS
from reader import Reader,SourceReader,Coreference,question_features,softmax
from advance import TRAIN_Q,FRESH_Q,QA

ROOT=Path(__file__).parent
FRESH={
 'agent':'Di chi parla il testo come autore della consegna?',
 'object':'Qual è l’oggetto che passa da una persona all’altra?',
 'recipient':'A quale destinatario va il pacco?',
 'time':'Quando avverrà quanto promesso?',
 'location':'Quale luogo contiene il quaderno?',
 'condition':'In che circostanze l’azione è ammessa?',
 'status':'È davvero avvenuto quanto viene raccontato?',
 'summary':'Dammi una breve descrizione di quanto ho letto.'}

def main(out=None):
    out=out or ROOT/'results';rows=[];classes=QUESTIONS+['unsupported']
    for part in question_data():rows += [(r['text'],r['question']) for r in part]
    prefixes=['','Dimmi: ','Vorrei sapere: ','Puoi spiegare: ','Nel testo, ','Secondo il brano, ']
    for kind,qs in TRAIN_Q.items():
        for q in qs+[FRESH_Q[kind]]:
            for prefix in prefixes:rows.append((prefix+q,classes.index(kind)))
    for c in QA:
        if not c.get('expected_unknown'):
            kind='status' if 'expected' not in c else ('agent' if c['id'] in {'new_names','passive','realistic_long'} else 'recipient' if c['id']=='recipient' else 'time' if c['id'] in {'time','clitic_time'} else 'condition' if c['id']=='conditional' else 'location' if c['id']=='location' else 'object')
            rows.append((c['question'],classes.index(kind)))
    unsupported=['Perché è necessaria la dialisi?','Perché succede?','Come funziona la dialisi?','Spiega il meccanismo biologico.','Confronta questi due processi.','Dimostra questo teorema.','Tutti i documenti sono firmati?','Nessun documento è firmato?','Non tutti sono presenti?','Calcola il costo totale.','Quale terapia è migliore?','Che cosa significa questo concetto?','Qual è la causa?','Quanti pazienti sono presenti?']
    for q in unsupported:
        for prefix in prefixes:rows.append((prefix+q,8))
    trainset={q for q,y in rows};assert not (set(FRESH.values())&trainset)
    protocol={'fresh_questions':FRESH,'training_rows':rows,'prior_question_tests_and_QA_are_development':True,'first_UD_external_test_not_used_for_this_head':True}
    raw=json.dumps(protocol,ensure_ascii=False,sort_keys=True).encode();(out/'questions-protocol.json').write_bytes(raw)
    indices=[];columns=[];values=[]
    for i,(q,y) in enumerate(rows):
        for k,v in question_features(q).items():indices.append(i);columns.append(k);values.append(v)
    x=csr_matrix((values,(indices,columns)),shape=(len(rows),4096));y=np.array([y for q,y in rows])
    w=np.zeros((4096,len(classes)));b=np.zeros(len(classes))
    for _ in range(2500):
        p=softmax(x@w+b);p[np.arange(len(y)),y]-=1;p/=len(y)
        w-=1.5*(x.T@p+.00005*w);b-=1.5*p.sum(0)
    original=json.loads((out/'reader443.json').read_text());original['questions']=classes
    original['question_bag']={'buckets':4096,'weight':w.tolist(),'bias':b.tolist(),'architecture':'trained hashed character and ordered word ngram classifier','trained_examples':len(rows)}
    rawmodel=json.dumps(original,ensure_ascii=False,separators=(',',':')).encode();(out/'reader443-final.json').write_bytes(rawmodel)
    model=Reader(out/'reader443-final.json');source=SourceReader(model,Coreference(out/'coreference443.json'))
    qresults=[]
    for kind,q in FRESH.items():
        a=model.inspect(q);qresults.append({'question':q,'expected':kind,'predicted':a['question_type'],'confidence':a['question_confidence'],'correct':a['question_type']==kind})
    dev=[]
    for c in QA:
        a=source.answer(c['text'],c['question']);ok=bool(a['unknown']) if c.get('expected_unknown') else not a['unknown']
        # Whole-passage copying is NOT accepted as an object/agent answer.
        if 'expected' in c:ok=ok and c['expected'].lower()==a.get('answer','').lower()
        if 'expected_scope' in c:ok=ok and c['expected_scope']==a.get('scope')
        dev.append({**c,'result':a,'correct':ok})
    result={'fresh_questions':qresults,'fresh_correct':sum(q['correct'] for q in qresults),'fresh_total':len(qresults),
      'development_QA':dev,'development_correct':sum(c['correct'] for c in dev),'development_total':len(dev),
      'protocol_sha256':hashlib.sha256(raw).hexdigest(),'model_sha256':hashlib.sha256(rawmodel).hexdigest(),
      'general_comprehension_solved':False,'free_text_decoder_trained':False,'energy_measured':False}
    (out/'questions-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print(json.dumps({k:v for k,v in result.items() if k!='development_QA'},ensure_ascii=False))
    print(json.dumps([{'id':c['id'],'ok':c['correct'],'answer':c['result'].get('answer'),'unknown':c['result']['unknown'],'scope':c['result'].get('scope')} for c in dev],ensure_ascii=False))

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path)
    main(p.parse_args().output)
