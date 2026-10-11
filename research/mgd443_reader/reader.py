"""Portable NumPy inference, learned coreference and provenance-preserving QA.

This is an extractive reader with a learned question interpreter. It is not a
general language generator. UD accuracy, question classification, coreference,
end-to-end QA and continual learning must be reported separately.
"""
import hashlib,json,re
from pathlib import Path
import numpy as np
from train import features,tokenize,ROLES,QUESTIONS,SCOPES,fnv

def question_features(text,buckets=4096):
    words=[w.lower() for w in tokenize(text)];counts={}
    def add(s,weight):
        k=fnv(s)%buckets;counts[k]=counts.get(k,0)+weight
    for n in (1,2,3):
        for i in range(len(words)-n+1):add('w'+str(n)+':'+ ' '.join(words[i:i+n]),1.)
    for w in words:
        t='^'+w+'$'
        for n in (3,4):
            for i in range(len(t)-n+1):add('c:'+t[i:i+n],.18)
    norm=np.sqrt(sum(v*v for v in counts.values())) or 1
    return {k:v/norm for k,v in counts.items()}

def softmax(a):
    z=np.exp(a-a.max(axis=-1,keepdims=True));return z/z.sum(axis=-1,keepdims=True)

class Reader:
    def __init__(self,path):
        self.path=Path(path);raw=self.path.read_bytes();self.revision=hashlib.sha256(raw).hexdigest()
        self.model=json.loads(raw);self.p={k:np.array(v) for k,v in self.model['parameters'].items()}
        self.hidden=self.model['hidden']
        if 'question_bag' in self.model:
            self.qw=np.array(self.model['question_bag']['weight']);self.qb=np.array(self.model['question_bag']['bias'])
    def forward(self,text,latent=False):
        words=tokenize(text)
        if not words:return words,np.empty((0,len(ROLES))),np.zeros(4),np.zeros(8)
        x=[]
        for w in words:
            ids,extra=features(w);x.append(np.r_[self.p['embedding.weight'][ids].mean(0),extra])
        x=np.array(x)
        if 'entity.weight' in self.p:
            entity=1/(1+np.exp(-(x@self.p['entity.weight'].T+self.p['entity.bias'])))
            x[:,:self.model['embedding']]=x[:,:self.model['embedding']]*(1-entity)+self.p['entity_embedding']*entity
        states=[];final=[]
        for reverse in (False,True):
            suffix='_reverse' if reverse else '';h=np.zeros(self.hidden);hs=np.zeros((len(x),self.hidden))
            wi=self.p['rnn.weight_ih_l0'+suffix];wh=self.p['rnn.weight_hh_l0'+suffix]
            bias=self.p['rnn.bias_ih_l0'+suffix]+self.p['rnn.bias_hh_l0'+suffix]
            for j in (range(len(x)-1,-1,-1) if reverse else range(len(x))):
                h=np.tanh(wi@x[j]+wh@h+bias);hs[j]=h
            states.append(hs);final.append(h)
        y=np.concatenate(states,axis=-1);pooled=np.concatenate(final)
        if 'question_bag' in self.model:
            bag=self.model['question_bag'];f=question_features(text,bag['buckets']);qp=softmax(sum((self.qw[k]*v for k,v in f.items()),start=self.qb.copy()))
        else:qp=softmax(self.p['question.weight']@pooled+self.p['question.bias'])
        result=(words,softmax(y@self.p['tag.weight'].T+self.p['tag.bias']),softmax(self.p['scope.weight']@pooled+self.p['scope.bias']),qp)
        return (*result,pooled) if latent else result
    def inspect(self,text):
        words,probs,scope,question=self.forward(text);labels=probs.argmax(-1)
        spans=[];start=0
        while start<len(words):
            label=int(labels[start]);end=start+1
            while end<len(words) and labels[end]==label:end+=1
            if label:
                spans.append({'role':ROLES[label],'text':' '.join(words[start:end]),'confidence':float(probs[start:end,label].min()),'token_start':start,'token_end':end})
            start=end
        return {'text':text,'tokens':words,'spans':spans,'scope':SCOPES[int(scope.argmax())],
            'scope_confidence':float(scope.max()),'question_type':self.model['questions'][int(question.argmax())],
            'question_confidence':float(question.max()),'scope_distribution':scope.tolist(),'model_revision':self.revision}

def coref_features(ref,candidate,distance):
    role=candidate['role'];text=candidate['text'];last=text.split()[-1].lower()
    ref=ref.lower();female=ref.endswith('la') or ref in {'lei','ella','la'}
    male=ref.endswith('lo') or ref in {'lui','egli','lo'}
    first=text.split()[0].lower()
    feminine=first in {'la','una'} or (first not in {'il','lo','un','uno'} and last.endswith('a'))
    masculine=first in {'il','lo','un','uno'} or (first not in {'la','una'} and last.endswith('o'))
    return np.array([1.,role=='object',role=='agent',role=='recipient',
        1/(1+distance),float(female and feminine),float(male and masculine),
        float((ref in {'lei','ella','lui','egli'}) and text[:1].isupper()),float((ref in {'lo','la','li','le'} or len(ref)>5) and not text[:1].isupper())])

def fit_coreference(output):
    # Candidate-based supervision; inference is a learned comparison, never a
    # supplied table of two entities. Human agreement is an explicit prior.
    rng=np.random.default_rng(443);weight=rng.normal(0,.02,9);examples=[]
    for i in range(1500):
        personal=i%3==0;female=i%2==1
        ref=('lei' if female else 'lui') if personal else (('restituirla' if i%4 else 'la') if female else ('restituirlo' if i%4 else 'lo'))
        candidates=[{'role':'agent','text':'Anna' if female else 'Marco'}, {'role':'object','text':'la cartella' if female else 'il libro'}, {'role':'recipient','text':'Giulia' if female else 'Paolo'}]
        distances=rng.integers(1,8,3);target=0 if personal else 1
        # Here personal cases explicitly reference the subject; an equally
        # compatible second person is AMBIGUOUS, not safe to resolve by recency.
        candidates[2]['text']='Paolo' if i%2 else 'Giulia'
        examples.append((np.array([coref_features(ref,c,int(d)) for c,d in zip(candidates,distances)]),target))
    for _ in range(100):
        rng.shuffle(examples)
        for x,target in examples:
            p=softmax(x@weight);p[target]-=1;weight-=.025*(x.T@p+.0001*weight)
    result={'weights':weight.tolist(),'features':9,'training_examples':len(examples),'ambiguity_margin':.30,
      'agreement_features_are_explicit_prior':True,'full_coreference_solved':False}
    Path(output).write_text(json.dumps(result,ensure_ascii=False,indent=2));return result

class Coreference:
    def __init__(self,path):self.m=json.loads(Path(path).read_text());self.w=np.array(self.m['weights'])
    def resolve(self,ref,candidates):
        if not candidates:return None
        x=np.array([coref_features(ref,c,len(candidates)-i) for i,c in enumerate(candidates)])
        p=softmax(x@self.w);order=np.argsort(p)[::-1]
        if len(order)>1 and p[order[0]]-p[order[1]]<self.m['ambiguity_margin']:return None
        best=dict(candidates[int(order[0])]);best['reference_confidence']=float(p[order[0]]);return best

class SourceReader:
    def __init__(self,reader,coreference):self.reader=reader;self.coreference=coreference
    def events(self,text):
        candidates=[];events=[]
        for i,sentence in enumerate(re.split(r'(?<=[.!?])\s+',text.strip())):
            if not sentence:continue
            event=self.reader.inspect(sentence);event['sentence_index']=i;event['source_sentences']=[sentence]
            event['scope_conflict']=event['scope']=='asserted' and any(s['role']=='negation' for s in event['spans'])
            for span in list(event['spans']):
                if span['role'] in {'reference','predicate_reference'}:
                    resolved=self.coreference.resolve(span['text'],candidates)
                    if resolved:
                        event['spans'].append({**resolved,'role':'object','resolved_from':span['text']})
                        if resolved['source_sentence'] not in event['source_sentences']:event['source_sentences'].append(resolved['source_sentence'])
                    else:event['unresolved_reference']=True
            for span in event['spans']:
                if span['role'] in {'agent','object','recipient'} and 'resolved_from' not in span:
                    candidates.append({**span,'source_sentence':sentence})
            events.append(event)
        return events
    def answer(self,text,query):
        q=self.reader.inspect(query);kind=q['question_type'];events=self.events(text)
        words={w.lower() for w in tokenize(query) if len(w)>3};rank=[]
        for e in events:
            ew={w.lower() for w in e['tokens'] if len(w)>3}
            if 'event_ranker' in self.reader.model:
                score=float(rank_features(query,e,kind,len(events))@np.array(self.reader.model['event_ranker']['weight']))
            else:score=len(words & ew)
            rank.append((score,e['sentence_index'],e))
        rank.sort(key=lambda item:(item[0],item[1]),reverse=True)
        if not rank or q['question_confidence']<.55 or kind=='unsupported':return {'unknown':True,'reason':'question_outside_verified_support','query':q}
        e=rank[0][2]
        if kind=='summary':return {'unknown':False,'answer':text,'source_sentences':[x['text'] for x in events],'extractive':True,'query':q}
        if e['scope_confidence']<.55 or e.get('scope_conflict'):return {'unknown':True,'reason':'scope_uncertain_or_inconsistent','query':q,'event':e}
        if kind=='status':answer={'asserted':'Il testo presenta l’evento come affermato.','negated':'Il testo nega l’evento.','conditional':'Il testo presenta l’evento sotto una condizione.','planned':'Il testo presenta una promessa o un evento previsto.'}[e['scope']]
        else:
            spans=[s for s in e['spans'] if s['role']==kind and s['confidence']>=.55]
            if not spans:return {'unknown':True,'reason':'requested_argument_missing_or_uncertain','query':q,'event':e}
            answer='; '.join(dict.fromkeys(s['text'] for s in spans))
        # Scope is copied alongside the answer: a condition or promise never
        # becomes evidence that the described action actually occurred.
        return {'unknown':False,'answer':answer,'scope':e['scope'],'source_sentences':e['source_sentences'],
                'extractive':True,'query':q,'event':e,'semantic_validation':False}

class PredictiveGeometry:
    """Geometry for the DECLARED question: four-way event scope only.

    These categories cannot answer entity/role questions. All episodes remain
    intact. Expanding Q or changing the reader invalidates the whole index.
    """
    def __init__(self):self.episodes=[];self.revision=None;self.edges=[]
    def add(self,text,source):self.episodes.append({'text':text,'source':source})
    def rebuild(self,reader,epsilon=.18):
        self.revision=reader.revision;self.edges=[]
        profiles=[np.array(reader.inspect(e['text'])['scope_distribution']) for e in self.episodes]
        for i in range(len(profiles)):
            for j in range(i):
                tv=float(.5*np.abs(profiles[i]-profiles[j]).sum());cost=.05+tv
                if cost<=epsilon:self.edges.append({'a':j,'b':i,'cost':cost,'distance':tv})
        return {'episodes_retained':len(self.episodes),'edges':self.edges,'revision':self.revision,
          'Q':['event_scope'],'c0':.05,'epsilon':epsilon,'entity_equivalence_claim':False}
    def require(self,reader):
        if self.revision!=reader.revision:raise ValueError('Predictor changed; rebuild geometry from retained original episodes.')

def rank_features(query,event,kind,count):
    qw={w.lower() for w in tokenize(query) if len(w)>3};ew={w.lower() for w in event['tokens'] if len(w)>3}
    def grams(word):return {word[i:i+3] for i in range(max(1,len(word)-2))}
    matches=[]
    for q in qw:
        g=grams(q);matches.append(max([2*len(g&grams(w))/(len(g)+len(grams(w))) for w in ew] or [0]))
    spans=[s for s in event['spans'] if s['role']==kind]
    return np.array([1.,len(qw&ew)/max(1,len(qw)),np.mean(matches) if matches else 0.,
        max([s['confidence'] for s in spans] or [0]),event.get('sentence_index',0)/max(1,count-1)])

def fit_ranker(reader,path):
    from train_v2 import curriculum
    rng=np.random.default_rng(443);rows=curriculum(seed=918,count=1800);examples=[]
    for i in range(400):
        choices=rng.choice(len(rows),3,replace=False);events=[]
        for j,ix in enumerate(choices):
            e=reader.inspect(' '.join(rows[ix]['tokens']));e['sentence_index']=j;events.append(e)
        target=int(rng.integers(3));row=rows[int(choices[target])]
        agent=[t for t,k in zip(row['tokens'],row['labels']) if k==1]
        kind=['agent','object','recipient','time','location'][i%5]
        templates={'agent':'Chi compie l’azione?','object':'Che cosa sposta {a}?','recipient':'A chi consegna il libro {a}?','time':'Quando agisce {a}?','location':'Dove mette il libro {a}?'}
        q=templates[kind].format(a=' '.join(agent))
        examples.append((np.array([rank_features(q,e,kind,3) for e in events]),target))
    x=np.array([e[0] for e in examples]);y=np.array([e[1] for e in examples]);w=np.zeros(5)
    for _ in range(1800):
        p=softmax(x@w);p[np.arange(len(y)),y]-=1;w-=.12*(np.einsum('nc,ncf->f',p,x)/len(y)+.0001*w)
    result={'weight':w.tolist(),'features':['bias','word_overlap','character_overlap','requested_role_confidence','recency'],
      'training_examples':400,'no_external_entity_table':True,'ranking_truth_verified':False}
    Path(path).write_text(json.dumps(result,indent=2));return result

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--model',type=Path,required=True);p.add_argument('--text',required=True);p.add_argument('--question',required=True);p.add_argument('--coref',type=Path,required=True)
    a=p.parse_args();print(json.dumps(SourceReader(Reader(a.model),Coreference(a.coref)).answer(a.text,a.question),ensure_ascii=False,indent=2))
