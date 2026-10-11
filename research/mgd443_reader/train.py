"""From-scratch recurrent Italian reader; no pretrained weights or transformer.

UD labels are converted to SILVER event roles, not semantic truth. Curriculum
and question supervision are generated here, never from an external LLM.
The immutable UD train/dev/test partitions are respected. The external test is
evaluated once after checkpoint selection on dev. End-to-end QA is separate.
"""
import argparse, hashlib, json, random, re, time, urllib.request
from pathlib import Path

UD_COMMIT = 'ff2447f6b21e03adbbbed5eff306f79b8857286b'
ROLES = ['other','agent','predicate','object','recipient','time','negation',
         'condition','modal','location','reference','predicate_reference']
QUESTIONS = ['agent','object','recipient','time','location','condition','status','summary']
SCOPES = ['asserted','negated','conditional','planned']
TOKEN = re.compile(r"[\wÀ-ÿ]+(?:['’][\wÀ-ÿ]+)?|[^\w\s]", re.UNICODE)
BUCKETS, EMBED, HIDDEN = 2048, 32, 48

def tokenize(text):
    return [m.group() for m in TOKEN.finditer(text)]

def fnv(s):
    h=2166136261
    for c in s:
        h=((h ^ ord(c))*16777619) & 0xffffffff
    return h

def features(word):
    w='^'+word.lower()+'$'
    grams=[w]+[w[i:i+n] for n in (2,3,4) for i in range(len(w)-n+1)]
    # No single UNK slot: previously unseen names and verbs retain character features.
    return [fnv(g)%BUCKETS for g in grams[:40]], [float(word[:1].isupper()),
        float(word.isupper() and len(word)>1),float(any(c.isdigit() for c in word)),float(not any(c.isalpha() for c in word))]

def curriculum(seed=443, count=3600):
    rng=random.Random(seed)
    names=['Anna','Marco','Giulia','Paolo','Luca','Sara','Elena','Davide','Nora','Marta','Giorgio','Irene']
    objects=['il libro','la chiave','il pacco','la lettera','il quaderno','la cartella','il documento','la scatola','la borsa','il giornale']
    verb_pairs=[('consegna','consegnare'),('porta','portare'),('restituisce','restituire'),('presta','prestare'),('invia','inviare'),('passa','passare'),('regala','regalare'),('mostra','mostrare'),('legge','leggere'),('apre','aprire'),('chiude','chiudere'),('controlla','controllare'),('sposta','spostare'),('trova','trovare'),('prende','prendere'),('conserva','conservare')]
    times=['oggi','domani','ieri','lunedì','questa mattina','nel pomeriggio','alle cinque']
    locations=['nel cassetto','sul tavolo','in biblioteca','in ufficio','sullo scaffale','nel cortile']
    rows=[]
    def make(parts,scope,family):
        words=[];labels=[]
        for text,label in parts:
            ts=tokenize(text);words+=ts;labels += [ROLES.index(label)]*len(ts)
        return {'tokens':words,'labels':labels,'scope':SCOPES.index(scope),'family':family}
    for i in range(count):
        a,b=rng.sample(names,2);o=rng.choice(objects);v,inf=rng.choice(verb_pairs);t=rng.choice(times);l=rng.choice(locations)
        family=i%9
        if family==0: parts=[(a,'agent'),(v,'predicate'),(o,'object'),('a','other'),(b,'recipient'),(t,'time')];s='asserted'
        elif family==1:parts=[(t,'time'),(',', 'other'),(a,'agent'),(v,'predicate'),(o,'object')];s='asserted'
        elif family==2:parts=[(a,'agent'),('non','negation'),(v,'predicate'),(o,'object'),('a','other'),(b,'recipient')];s='negated'
        elif family==3:parts=[('Se la porta è aperta','condition'),(',', 'other'),(a,'agent'),(v,'predicate'),(o,'object')];s='conditional'
        elif family==4:parts=[(a,'agent'),('promette di','modal'),(inf,'predicate'),(o,'object'),(t,'time')];s='planned'
        elif family==5:parts=[(a,'agent'),('mette','predicate'),(o,'object'),(l,'location')];s='asserted'
        elif family==6:parts=[(o.capitalize(),'object'),('viene consegnato da','predicate'),(a,'agent'),('a','other'),(b,'recipient')];s='asserted'
        elif family==7:parts=[(a,'agent'),('lo','reference'),('restituisce','predicate'),(t,'time')];s='asserted'
        else:parts=[(a,'agent'),('promette di','modal'),('restituirlo','predicate_reference'),(t,'time')];s='planned'
        rows.append(make(parts+[('.', 'other')],s,f'curriculum_{family}'))
    return rows

def question_data():
    forms={
      'agent':['Chi consegna il libro?','Chi ha portato il pacco?','Chi compie questa azione?','Da chi viene consegnata la lettera?','Quale persona legge il giornale?','Chi è il soggetto della consegna?'],
      'object':['Che cosa consegna Anna?','Cosa ha portato Marco?','Quale oggetto viene restituito?','Che cosa legge Sara?','Qual è la cosa spostata?','Quale oggetto è stato consegnato?'],
      'recipient':['A chi consegna il libro Anna?','Chi riceve il pacco?','Qual è il destinatario della lettera?','A quale persona viene passato il quaderno?','A chi è indirizzata la consegna?','Chi è la persona che riceve?'],
      'time':['Quando consegna il libro?','In quale momento Marco porta il pacco?','A che ora avviene la consegna?','Quando è prevista la restituzione?','Qual è il giorno della consegna?','Quale momento è indicato nel testo?'],
      'location':['Dove si trova la chiave?','In quale luogo Anna mette il libro?','Dove viene spostata la scatola?','Qual è la posizione del pacco?','In che posto viene messo il quaderno?','Dove è conservato il giornale?'],
      'condition':['A quale condizione Anna consegna il libro?','Che cosa deve accadere perché Marco parta?','Qual è la condizione della consegna?','In quale caso Sara restituisce la chiave?','Che condizione viene richiesta?','Da quale condizione dipende questo evento?'],
      'status':['La consegna è già avvenuta?','Anna consegna davvero il libro?','Si tratta di un fatto o di una promessa?','Il testo nega questa azione?','La restituzione è soltanto prevista?','Qual è lo stato di questo evento?'],
      'summary':['Riassumi il testo.','Che cosa racconta il brano?','Spiega ciò che è scritto.','Quali eventi sono descritti?','Descrivi il contenuto del testo.','Che cosa si dice in questo passaggio?']}
    train=[];dev=[];test=[]
    for label,strings in forms.items():
        for i,s in enumerate(strings):
            target=(train if i<4 else dev if i==4 else test)
            target.append({'tokens':tokenize(s),'question':QUESTIONS.index(label),'text':s})
    # Entity substitutions do not turn these into independent paraphrase tests.
    return train,dev,test

def read_ud(path):
    rows=[]
    for block in path.read_text().split('\n\n'):
        fields=[l.split('\t') for l in block.splitlines() if l and not l.startswith('#') and l.split('\t')[0].isdigit()]
        if not fields or len(fields)>80:continue
        labels={};byid={int(f[0]):f for f in fields}
        for f in fields:
            dep=f[7];head=byid.get(int(f[6]));role='other'
            if dep.startswith('nsubj'):role='object' if ':pass' in dep else 'agent'
            elif dep=='obj':role='object'
            elif dep=='iobj':role='recipient'
            elif f[3]=='VERB':role='predicate'
            elif dep=='obl:tmod' or (f[3]=='ADV' and f[2] in {'ieri','oggi','domani'}):role='time'
            elif f[2] in {'non','mai','neppure','nemmeno'}:role='negation'
            # obl is NOT automatically a recipient/location; its semantics are unknown.
            labels[int(f[0])]=role
        for _ in range(3):
            for f in fields:
                if f[7] in {'det','amod','flat','flat:name','compound','case','nummod'} and labels.get(int(f[6])) in {'agent','object','recipient','time'}:
                    labels[int(f[0])]=labels[int(f[6])]
        words=[];ys=[]
        for f in fields:
            ts=tokenize(f[1]);words+=ts;ys += [ROLES.index(labels[int(f[0])])]*len(ts)
        if words and len(words)<=100:rows.append({'tokens':words,'labels':ys,'scope':-1,'family':'UD_silver'})
    return rows

def train(output,epochs=12):
    import numpy as np
    import torch
    from torch import nn
    from torch.nn.utils.rnn import pack_padded_sequence,pad_packed_sequence
    torch.set_num_threads(2);torch.manual_seed(443);random.seed(443);np.random.seed(443)
    output.mkdir(parents=True,exist_ok=True)
    data=output/'data';data.mkdir(exist_ok=True)
    hashes={}
    for split in ['train','dev','test']:
        file=data/f'it_isdt-ud-{split}.conllu'
        if not file.exists():
            url=f'https://raw.githubusercontent.com/UniversalDependencies/UD_Italian-ISDT/{UD_COMMIT}/{file.name}'
            with urllib.request.urlopen(url,timeout=90) as r:file.write_bytes(r.read())
        hashes[split]=hashlib.sha256(file.read_bytes()).hexdigest()
    ud={s:read_ud(data/f'it_isdt-ud-{s}.conllu') for s in hashes}
    synthetic=curriculum();rng=random.Random(443);rng.shuffle(synthetic)
    trainrows=ud['train']+synthetic[:3000];devrows=ud['dev']+synthetic[3000:3300]
    qs,qdev,qtest=question_data()
    class Net(nn.Module):
        def __init__(self):
            super().__init__();self.embedding=nn.Embedding(BUCKETS,EMBED)
            nn.init.normal_(self.embedding.weight,std=.15)
            self.rnn=nn.RNN(EMBED+4,HIDDEN,batch_first=True,bidirectional=True)
            self.tag=nn.Linear(HIDDEN*2,len(ROLES));self.scope=nn.Linear(HIDDEN*2,len(SCOPES));self.question=nn.Linear(HIDDEN*2,len(QUESTIONS))
        def forward(self,grams,chars,extra,lengths):
            emb=self.embedding(grams)*chars.unsqueeze(-1)
            emb=emb.sum(-2)/chars.sum(-1).clamp(min=1).unsqueeze(-1)
            x=torch.cat([emb,extra],-1)
            packed=pack_padded_sequence(x,lengths.cpu(),batch_first=True,enforce_sorted=False)
            y,last=self.rnn(packed);y,_=pad_packed_sequence(y,batch_first=True,total_length=x.shape[1])
            pooled=torch.cat([last[0],last[1]],-1)
            return self.tag(y),self.scope(pooled),self.question(pooled)
    def batch(rows):
        n=len(rows);t=max(len(r['tokens']) for r in rows);g=np.zeros((n,t,40),np.int64);mask=np.zeros((n,t,40),np.float32);ex=np.zeros((n,t,4),np.float32)
        y=np.full((n,t),-1,np.int64);lens=[]
        for i,r in enumerate(rows):
            lens.append(len(r['tokens']))
            for j,w in enumerate(r['tokens']):
                ids,extras=features(w);g[i,j,:len(ids)]=ids;mask[i,j,:len(ids)]=1;ex[i,j]=extras
            if 'labels' in r:y[i,:len(r['labels'])]=r['labels']
        return (torch.tensor(g),torch.tensor(mask),torch.tensor(ex),torch.tensor(lens)),torch.tensor(y)
    net=Net();opt=torch.optim.Adam(net.parameters(),lr=.003)
    weights=torch.tensor([.6,1.5,1.1,1.5,2,2,2,2,2,2,2,2])
    cached={id(r):None for r in trainrows}
    def evaluate(rows):
        confusion=np.zeros((len(ROLES),len(ROLES)),np.int64);exact=total=0
        net.eval()
        with torch.no_grad():
            for start in range(0,len(rows),64):
                sub=rows[start:start+64];inputs,y=batch(sub);pred=net(*inputs)[0].argmax(-1)
                for i,r in enumerate(sub):
                    p=pred[i,:len(r['labels'])].numpy();gold=np.array(r['labels']);exact+=int(np.array_equal(p,gold));total+=1
                    np.add.at(confusion,(gold,p),1)
        diagonal=confusion.diagonal();f1=2*diagonal/(confusion.sum(0)+confusion.sum(1)).clip(min=1)
        return {'tokens':int(confusion.sum()),'accuracy':float(diagonal.sum()/confusion.sum()),'role_f1':dict(zip(ROLES,map(float,f1))),
                'sentence_exact':exact,'sentences':total,'active_role_macro_f1':float(np.mean(f1[1:7])), 'confusion':confusion.tolist()}
    best=-1;history=[];started=time.time()
    for epoch in range(epochs):
        net.train();rng.shuffle(trainrows);losses=[]
        for start in range(0,len(trainrows),64):
            rows=trainrows[start:start+64];inputs,y=batch(rows);tag,scope,q=net(*inputs)
            loss=nn.functional.cross_entropy(tag.transpose(1,2),y,weight=weights,ignore_index=-1)
            sy=torch.tensor([r['scope'] for r in rows]);known=sy>=0
            if known.any():loss+=.4*nn.functional.cross_entropy(scope[known],sy[known])
            qr=rng.choices(qs,k=24);qi,_=batch(qr);_,_,qp=net(*qi)
            loss+=.45*nn.functional.cross_entropy(qp,torch.tensor([r['question'] for r in qr]))
            opt.zero_grad();loss.backward();nn.utils.clip_grad_norm_(net.parameters(),2);opt.step();losses.append(float(loss.detach()))
        dev=evaluate(devrows)
        metric=dev['active_role_macro_f1']
        record={'epoch':epoch+1,'loss':sum(losses)/len(losses),'dev':dev,'seconds':time.time()-started};history.append(record)
        print(json.dumps({'epoch':epoch+1,'loss':record['loss'],'dev_f1':metric,'seconds':record['seconds']}),flush=True)
        if metric>best:
            best=metric;torch.save(net.state_dict(),output/'checkpoint.pt');selected=epoch+1
    net.load_state_dict(torch.load(output/'checkpoint.pt',weights_only=True));net.eval()
    def qscore(rows):
        inputs,_=batch(rows)
        with torch.no_grad():probs=net(*inputs)[2].softmax(-1).numpy()
        return [{'question':r['text'],'expected':QUESTIONS[r['question']],'predicted':QUESTIONS[int(p.argmax())],'confidence':float(p.max())} for r,p in zip(rows,probs)]
    params={k:v.detach().numpy().astype(float).tolist() for k,v in net.state_dict().items()}
    model={'schema':443,'architecture':'bidirectional tanh recurrent network; trained from scratch',
           'transformer':False,'buckets':BUCKETS,'embedding':EMBED,'hidden':HIDDEN,'roles':ROLES,'questions':QUESTIONS,'scopes':SCOPES,'parameters':params,
           'ud_commit':UD_COMMIT,'ud_license':'CC BY-NC-SA 3.0','selected_epoch':selected}
    raw=json.dumps(model,ensure_ascii=False,separators=(',',':')).encode();(output/'reader443.json').write_bytes(raw)
    result={'seed':443,'epochs':epochs,'selected_epoch':selected,'ud_commit':UD_COMMIT,'ud_sha256':hashes,
      'training_ud_sentences':len(ud['train']),'synthetic_training':3000,'model_sha256':hashlib.sha256(raw).hexdigest(),
      'parameters':sum(p.numel() for p in net.parameters()),'model_json_bytes':len(raw),'history':history,
      'ud_external_test':evaluate(ud['test']),'synthetic_reserved_test':evaluate(synthetic[3300:]),
      'question_dev':qscore(qdev),'question_reserved_test':qscore(qtest),'training_seconds':time.time()-started,
      'general_comprehension_solved':False,'semantic_labels_from_ud_are_silver':True,
      'question_split_only_eight_reserved_paraphrases':True,'no_author_generalization_claim':True,'phone_energy_measured':False}
    (output/'training-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    (output/'reserved_curriculum.json').write_text(json.dumps(synthetic[3300:],ensure_ascii=False))
    print(json.dumps({k:v for k,v in result.items() if k not in {'history','reserved_curriculum'}}),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path('research/mgd443_reader/results'));p.add_argument('--epochs',type=int,default=12)
    a=p.parse_args();train(a.output,a.epochs)
