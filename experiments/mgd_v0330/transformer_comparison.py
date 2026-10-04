"""Controlled comparison, NOT a claim against pretrained state-of-the-art AI.
Same encoded stimuli, labels, order and retained examples as the mobile core.
Transformer updates at use time, with all previous samples available for replay.
The memory-equipped control is a separate fixed-kernel episodic classifier;
its score must not be attributed to the Transformer or to MGD curvature.
"""
import json, math, os, time
from pathlib import Path
import numpy as np
import torch
from torch import nn

torch.set_num_threads(1)
ROOT=Path(__file__).parent/'results'
MODES=['text:v1','vision:v1','audio:v1']

class OnlineTransformer(nn.Module):
    def __init__(self,dims):
        super().__init__()
        self.encoders=nn.ModuleList([nn.Linear(d,32) for d in dims])
        self.types=nn.Parameter(torch.zeros(3,32))
        layer=nn.TransformerEncoderLayer(32,4,64,dropout=0.,batch_first=True)
        self.sequence=nn.TransformerEncoder(layer,2,enable_nested_tensor=False)
        self.head=nn.Linear(32,8)
    def forward(self,x):
        x=torch.stack([encode(part) for encode,part in zip(self.encoders,x)],1)+self.types
        return self.head(self.sequence(x).mean(1))

def run(seed):
    torch.manual_seed(3300+seed); rng=np.random.default_rng(3300+seed)
    data=json.loads((ROOT/f'dataset-{seed}.json').read_text())
    # Unsupervised feature vocabulary; this only fixes column positions.
    keys=[sorted({k for s in data['train'] for k in s['features'][m]}) for m in MODES]
    def encode(samples):
        parts=[]
        for m,ks in zip(MODES,keys):
            x=np.array([[s['features'][m].get(k,0) for k in ks] for s in samples],dtype=np.float32)
            x/=np.maximum(np.linalg.norm(x,axis=1,keepdims=True),1e-12)
            parts.append(torch.tensor(x))
        y=torch.tensor([int(s['label'].split()[-1]) for s in samples])
        return parts,y
    train,y=encode(data['train']);test,ty=encode(data['test'])
    model=OnlineTransformer([len(k) for k in keys])
    optimizer=torch.optim.AdamW(model.parameters(),lr=.002,weight_decay=.001)
    latencies=[];before=None
    def score(mask=None):
        with torch.no_grad():
            logits=model(test)
        if mask is None: mask=torch.ones(len(ty),dtype=torch.bool)
        return float((logits[mask].argmax(1)==ty[mask]).float().mean())
    for i in range(len(y)):
        start=time.perf_counter_ns()
        # Two steps per arriving labelled observation. Equal memory availability
        # does not imply equal FLOPs or joules; report the budget explicitly.
        for step in range(2):
            replay=rng.choice(i+1,size=min(16,i+1),replace=False).tolist()
            if i not in replay: replay.append(i)
            pred=model([x[replay] for x in train])
            loss=nn.functional.cross_entropy(pred,y[replay])
            optimizer.zero_grad();loss.backward();optimizer.step()
        latencies.append((time.perf_counter_ns()-start)/1e6)
        if i==31: before=score(ty<4)
    with torch.no_grad():
        logits=model(test);loss=float(nn.functional.cross_entropy(logits,ty))
    prediction_latency=[]
    with torch.no_grad():
        for i in range(len(ty)):
            start=time.perf_counter_ns();model([x[i:i+1] for x in test])
            prediction_latency.append((time.perf_counter_ns()-start)/1e6)
    # Memory control: exactly the mobile kernel without its learned metric.
    distances=sum(torch.cdist(a,b).square() for a,b in zip(test,train))/3
    kernels=torch.exp(-12*distances)
    classes=torch.stack([kernels[:,y==c].mean(1) for c in range(8)],1)
    memory_accuracy=float((classes.argmax(1)==ty).float().mean())
    return {'seed':seed,'model':'2-layer online Transformer + replay',
        'parameters':sum(p.numel() for p in model.parameters()),'updates':2*len(y),
        'memoryEpisodes':len(y),'accuracy':score(),'nll':loss,
        'oldHoldoutBefore':before,'oldHoldoutAfter':score(ty<4),
        'oldHoldoutForgetting':before-score(ty<4),
        'learningP50Ms':float(np.median(latencies)),
        'learningP95Ms':float(np.quantile(latencies,.95)),
        'predictionP50Ms':float(np.median(prediction_latency)),
        'predictionP95Ms':float(np.quantile(prediction_latency,.95)),
        'fixedEpisodicKernelAccuracy':memory_accuracy,'energyJoules':None}

if __name__=='__main__':
    rows=[]
    for seed in range(6,12):
        rows.append(run(seed));print(json.dumps(rows[-1]),flush=True)
    (ROOT/'transformer-results.json').write_text(json.dumps({
        'scope':'Small from-scratch Transformer, synthetic complementary cues; not a pretrained or general intelligence comparison.',
        'torch':torch.__version__,'numpy':np.__version__,'threads':1,
        'optimizer':{'name':'AdamW','lr':.002,'weight_decay':.001,'updatesPerInput':2,'replayBatch':16},
        'seeds':rows},indent=2))
