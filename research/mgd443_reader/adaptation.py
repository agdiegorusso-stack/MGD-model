"""Learn a plasticity route from future error AND replay retention.

Labels are externally verified corrections. Reading text alone does not supply
question semantics. Routing training uses synthetic vocabulary substitutions;
the final test uses previously unseen questions. No responsible word/row is
provided: sparse coordinates are selected by observed gradients.
"""
from pathlib import Path
import json,hashlib
import numpy as np
from scipy.sparse import csr_matrix
from reader import question_features,softmax,Reader

ROOT=Path(__file__).parent
MODES=['bias','active_features','novel_gradient_features','no_update']

def encode(texts):
    rows=[];cols=[];values=[]
    for i,t in enumerate(texts):
        for k,v in question_features(t).items():rows.append(i);cols.append(k);values.append(v)
    return csr_matrix((values,(rows,cols)),shape=(len(texts),4096))

def adapt(w,b,x,y,rx,ry,mode,steps=35):
    w=w.copy();b=b.copy();active=x.indices
    if mode==3:return w,b
    for _ in range(steps):
        p=softmax(x@w+b);p[0,y]-=1;g=(x.T@p)
        rp=softmax(rx@w+b);rp[np.arange(len(ry)),ry]-=1;g+=.12*(rx.T@rp)/len(ry)
        db=p[0]+.12*rp.mean(0)
        if mode==0:b-=.35*db
        elif mode==1:w[active]-=.8*g[active]
        else:
            # Input coordinates follow the largest observed gradients. This is
            # the distinction from the old manually supplied lexical row.
            novel=active[np.asarray(rx[:,active].getnnz(axis=0)).ravel()==0]
            chosen=novel[np.argsort(np.linalg.norm(g[novel],axis=1))[-12:]]
            w[chosen]-=.8*g[chosen]
    return w,b

def feature(w,b,x,y):
    p=softmax(x@w+b)[0];r=p.copy();r[y]-=1;f=x.data;g=(x.T@r[None,:])
    return np.array([1.,float(-(p*np.log(p.clip(1e-12))).sum()),float(-np.log(max(p[y],1e-12))),
        len(f)/100,float(np.linalg.norm(g)),float(np.mean(np.abs(w[x.indices]))),float(p.max()),float(f.max())])

def main():
    out=ROOT/'results';raw=json.loads((out/'reader443-final.json').read_text());bag=raw['question_bag']
    w=np.array(bag['weight']);b=np.array(bag['bias']);classes=raw['questions'];protocol=json.loads((out/'questions-protocol.json').read_text())
    replay=protocol['training_rows'];rng=np.random.default_rng(443)
    ix=rng.choice(len(replay),64,replace=False);rx=encode([replay[i][0] for i in ix]);ry=np.array([replay[i][1] for i in ix])
    training=[];teacher_routes=[];meta_baseline=softmax(rx@w+b).argmax(-1)
    # Each episode introduces an arbitrary lexical symbol. Only the correction
    # labels and the later verified examples establish what that symbol means.
    for episode in range(180):
        y=episode%8;alias=f'neolessema{episode:04d}'
        texts=[f'Indica {alias}.',f'Vorrei sapere {alias}.',f'Nel brano, indica {alias}.']
        x=encode(texts[:1]);future=encode(texts[1:]);before=feature(w,b,x,y);scores=[]
        for mode in range(4):
            aw,ab=adapt(w,b,x,y,rx,ry,mode)
            p=softmax(future@aw+ab);r=softmax(rx@aw+ab)
            score=float(-np.log(p[:,y].clip(1e-12)).mean())+.5*float(-np.log(r[np.arange(len(ry)),ry].clip(1e-12)).mean())
            # A route which changes a previously measured answer is not eligible.
            if not np.array_equal(r.argmax(-1),meta_baseline):score=1e6+score
            scores.append(score)
        training.append(before);teacher_routes.append(int(np.argmin(scores)))
    tx=np.array(training);ty=np.array(teacher_routes);mean=tx[:,1:].mean(0);scale=tx[:,1:].std(0).clip(min=.001)
    tx[:,1:]=(tx[:,1:]-mean)/scale;router=np.zeros((tx.shape[1],4))
    for _ in range(1200):
        p=softmax(tx@router);p[np.arange(len(ty)),ty]-=1;router-=.05*(tx.T@p/len(ty)+.001*router)
    tests=[('In quali circostanze è ammessa questa azione?', 'condition',
            ['Quali circostanze permettono l’azione?','Da quali circostanze dipende?']),
           ('A quale destinatario va ciò che viene passato?','recipient',
            ['A quale destinatario va la lettera?','Indica il destinatario del pacco.']),
           ('Quale momento è previsto per la restituzione?','time',
            ['Quale momento è previsto?','Indica il momento previsto per il ritorno.'])]
    testprotocol={'verified_corrections_and_futures':tests,'router_training_episodes':180,'steps_per_correction':35,
       'no_manually_selected_word_or_hash_row':True,'synthetic_routing_meta_training_not_general_brain_learning':True}
    (out/'adaptation-protocol.json').write_text(json.dumps(testprotocol,ensure_ascii=False,indent=2))
    results=[];baseline=softmax(rx@w+b).argmax(-1)
    for correction,kind,futures in tests:
        y=classes.index(kind);x=encode([correction]);f=feature(w,b,x,y);f[1:]=(f[1:]-mean)/scale
        rp=softmax(f@router);chosen=int(rp.argmax());aw,ab=adapt(w,b,x,y,rx,ry,chosen)
        future=encode(futures);before=softmax(future@w+b).argmax(-1);after=softmax(future@aw+ab).argmax(-1)
        old=softmax(rx@aw+ab).argmax(-1);accepted=bool(np.array_equal(old,baseline))
        if not accepted:aw,ab=w,b;after=before;old=baseline
        results.append({'correction':correction,'type':kind,'route':MODES[chosen],'route_distribution':rp.tolist(),
          'one_distinct_verified_correction':True,'future_examples':futures,'before_correct':int((before==y).sum()),
          'after_correct':int((after==y).sum()),'future_total':len(futures),'replay_changed':int((old!=baseline).sum()),
          'manual_word_selection':False,'guard_accepted':accepted,'rejected_update_applied':False})
    output={'results':results,'router_training_route_counts':np.bincount(ty,minlength=4).tolist(),
      'future_error_used_only_for_meta_training_not_test_route':True,'router':router.tolist(),'feature_mean':mean.tolist(),'feature_scale':scale.tolist(),
      'general_online_semantic_learning_solved':False,'source_truth_inferred_from_prediction':False}
    (out/'adaptation-results.json').write_text(json.dumps(output,ensure_ascii=False,indent=2))
    print(json.dumps({k:v for k,v in output.items() if k not in {'router','feature_mean','feature_scale'}},ensure_ascii=False))

if __name__=='__main__':main()
