"""MGD-inspired memory versus a trained causal Transformer on a bounded task.

This is a synthetic noisy associative-memory experiment, not a language-model
benchmark and not a faithful simulation of the papers' infinite lattice.
Run from this directory: python benchmark.py --out results
"""
import argparse, copy, hashlib, itertools, json, math, os, platform, time
from pathlib import Path
import numpy as np
import torch
from torch import nn

K,V,T=8,4,128
SCENARIOS={'stationary':(0.,.2),'changing':(.06,.2),'fast_changes':(.2,.2)}
BURN=16

def json_text(obj,indent=None):
    def safe(x):
        if isinstance(x,np.generic):return safe(x.item())
        if isinstance(x,dict):return {k:safe(v) for k,v in x.items()}
        if isinstance(x,(list,tuple)):return [safe(v) for v in x]
        if isinstance(x,float) and not math.isfinite(x):return 'unbounded'
        return x
    return json.dumps(safe(obj),indent=indent,allow_nan=False)

def stream(seed,n,hazard,noise,length=T):
    rng=np.random.default_rng(seed)
    latent=rng.integers(V,size=(n,K)); keys=rng.integers(K,size=(n,length))
    obs=np.zeros_like(keys); targets=np.zeros_like(keys); changed=np.zeros_like(keys,dtype=bool)
    indices=np.arange(n)
    for t in range(length):
        k=keys[:,t]; old=latent[indices,k]
        shift=rng.random(n)<hazard
        latent[indices,k]=(old+shift*rng.integers(1,V,size=n))%V
        targets[:,t]=latent[indices,k]
        err=rng.random(n)<noise
        obs[:,t]=(targets[:,t]+err*rng.integers(1,V,size=n))%V
        changed[:,t]=shift
    return {'keys':keys,'obs':obs,'target':targets,'changed':changed}

def fixed_sets(seed,n):
    return {name:stream(seed+i,n,*p) for i,(name,p) in enumerate(SCENARIOS.items())}

def root(rho,xi,chi):
    if xi==0:return chi
    b=1-rho-xi
    return 2*(1-rho)*chi/(b+np.sqrt(b*b+4*xi*(1-rho)*chi)+1e-30)

def memory(data,mode,params=None):
    p=params or {}; keys=data['keys'];obs=data['obs']; n,length=keys.shape;idx=np.arange(n)
    pred=np.zeros_like(keys); state=np.zeros((n,K,V))
    if mode=='bayes':state.fill(1/V)
    if mode.startswith('mgd'):
        base=np.full((n,K,V),1.0);m=np.zeros_like(base);material=np.zeros_like(base);co=np.zeros_like(base)
        cost=base.copy()
    for t in range(length):
        key=keys[:,t];value=obs[:,t];a=np.eye(V)[value]
        if mode=='last':pred[:,t]=value;continue
        if mode=='constant':pred[:,t]=0;continue
        if mode in ('ema','count'):
            alpha=p.get('alpha',1.)
            state[idx,key]=alpha*state[idx,key]+a
            pred[:,t]=state[idx,key].argmax(-1)
        elif mode=='bayes':
            old=state[idx,key];h=p['hazard'];noise=p['noise']
            prior=(1-h)*old+h*(1-old)/(V-1)
            likelihood=np.full_like(prior,noise/(V-1))
            likelihood[idx,value]=1-noise
            posterior=prior*likelihood;posterior/=posterior.sum(-1,keepdims=True)
            state[idx,key]=posterior;pred[:,t]=posterior.argmax(-1)
        elif mode.startswith('mgd'):
            # Per-key clock, edge memories, optional bounded costs: explicitly
            # declared engineering adaptations of paper Eq.(1),(2),(6),(10).
            oldm=m[idx,key].copy()
            chi=(cost[idx,key]<=1.).astype(float)
            m[idx,key]=p['alpha']*oldm+(1-p['alpha'])*a
            eta_memory=0. if mode=='mgd_no_memory' else .1
            base[idx,key]=np.clip(base[idx,key]+p['nu']-.4*a-eta_memory*oldm,.05,p['cap'])
            if mode=='mgd_no_material':
                cost[idx,key]=base[idx,key]
            else:
                M=material[idx,key]
                material[idx,key]=.8*M+.2*chi+.1*M*(1-M)
                co[idx,key]=.97*co[idx,key]+.03*chi
                eq=root(.8,.1,co[idx,key])
                cost[idx,key]=np.maximum(.05,base[idx,key]+p['eta_material']*(material[idx,key]-eq))
            pred[:,t]=cost[idx,key].argmin(-1)
    return pred

def accuracy(pred,data):return float((pred[:,BURN:]==data['target'][:,BURN:]).mean())
def score_sets(mode,p,sets):return float(np.mean([accuracy(memory(d,mode,p),d) for d in sets.values()]))

class TinyTransformer(nn.Module):
    def __init__(self):
        super().__init__();d=48
        self.ke=nn.Embedding(K,d);self.ve=nn.Embedding(V,d)
        self.layers=nn.ModuleList([nn.TransformerEncoderLayer(d,4,96,dropout=0.,
            batch_first=True,norm_first=True,activation='gelu') for _ in range(2)])
        self.norm=nn.LayerNorm(d);self.out=nn.Linear(d,V)
        pos=torch.arange(T).float()[:,None];freq=torch.exp(torch.arange(0,d,2)*(-math.log(10000)/d))
        pe=torch.zeros(T,d);pe[:,0::2]=torch.sin(pos*freq);pe[:,1::2]=torch.cos(pos*freq)
        self.register_buffer('pe',pe)
        self.register_buffer('mask',torch.triu(torch.ones(T,T,dtype=torch.bool),diagonal=1))
    def forward(self,k,v):
        l=k.shape[1];x=self.ke(k)+self.ve(v)+self.pe[:l]
        for layer in self.layers:x=layer(x,src_mask=self.mask[:l,:l],is_causal=True)
        return self.out(self.norm(x))

@torch.inference_mode()
def transformer_predictions(model,data):
    model.eval();parts=[]
    for start in range(0,len(data['keys']),32):
        k=torch.from_numpy(data['keys'][start:start+32]);v=torch.from_numpy(data['obs'][start:start+32])
        parts.append(model(k,v).argmax(-1).numpy())
    return np.concatenate(parts)

def train(seed,validation,out):
    torch.manual_seed(seed);rng=np.random.default_rng(seed+40000);model=TinyTransformer()
    optim=torch.optim.AdamW(model.parameters(),lr=.002,weight_decay=.01)
    best=-1.;best_state=None;log=[];start=time.perf_counter()
    for step in range(800):
        model.train()
        h=float(rng.choice([0.,.03,.06,.2]));noise=float(rng.choice([0.,.1,.2,.35]))
        data=stream(int(rng.integers(1000000,2**31)),32,h,noise)
        logits=model(torch.from_numpy(data['keys']),torch.from_numpy(data['obs']))
        loss=nn.functional.cross_entropy(logits[:,BURN:].reshape(-1,V),torch.from_numpy(data['target'][:,BURN:].copy()).reshape(-1))
        optim.zero_grad();loss.backward();nn.utils.clip_grad_norm_(model.parameters(),1.);optim.step()
        if (step+1)%100==0:
            val=float(np.mean([accuracy(transformer_predictions(model,d),d) for d in validation.values()]))
            log.append({'step':step+1,'loss':float(loss.detach()),'validationAccuracy':val})
            print('TRAIN',seed,step+1,round(val,5),flush=True)
            if val>best:best=val;best_state=copy.deepcopy(model.state_dict())
    model.load_state_dict(best_state)
    torch.save({'state':best_state,'seed':seed,'log':log},out/f'transformer_{seed}.pt')
    # Controls of interface and causality, not a requirement to win the task.
    clean=stream(993000+seed,64,0.,0.)
    health=accuracy(transformer_predictions(model,clean),clean)
    k=torch.from_numpy(clean['keys'][:2]);v=torch.from_numpy(clean['obs'][:2]);v2=v.clone();v2[:,64:]=(v2[:,64:]+1)%V
    model.eval()
    with torch.inference_mode():causal_error=float((model(k,v)[:,:64]-model(k,v2)[:,:64]).abs().max())
    info={'seed':seed,'parameters':sum(p.numel() for p in model.parameters()),'trainingSteps':800,
        'trainingEvents':800*32*T,'trainingSeconds':time.perf_counter()-start,'bestValidationAccuracy':best,
        'noiselessControlAccuracy':health,'futureLeakMaxAbsLogitDifference':causal_error,
        'validControl':health>=.95 and causal_error<1e-5,'log':log}
    print('MODEL_CONTROL',json.dumps({k:v for k,v in info.items() if k!='log'}),flush=True)
    return model,info

def paired_interval(a,b,seed=88654):
    # Independent unit is an entire episode, not a correlated individual event.
    delta=np.concatenate([x-y for x,y in zip(a,b)])
    rng=np.random.default_rng(seed)
    samples=np.mean([d[rng.integers(len(d),size=(3000,len(d)))].mean(1)
        for d in [x-y for x,y in zip(a,b)]],axis=0)
    return {'deltaPercentagePoints':100*float(delta.mean()),'ci95Percentile':list(100*np.quantile(samples,[.025,.975]))}

def main():
    args=argparse.ArgumentParser();args.add_argument('--out',default='results');args.add_argument('--resume-evaluation',action='store_true');a=args.parse_args();out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
    torch.set_num_threads(2);torch.use_deterministic_algorithms(True)
    validation=fixed_sets(62000,64)
    grid=[{'alpha':alpha,'nu':.5*pc,'eta_material':eta,'cap':cap}
        for alpha,pc,eta,cap in itertools.product([.2,.7,.95],[.15,.35,.6],[.2,.8,1.6],[2.,float('inf')])]
    tuning=[]
    for p in grid:tuning.append({'params':p,'score':score_sets('mgd',p,validation)})
    chosen=max(tuning,key=lambda x:x['score']);p=chosen['params']
    ema_grid=[{'alpha':x} for x in [0.,.2,.4,.6,.7,.8,.85,.9,.95,.98,1.]]
    ema=max(ema_grid,key=lambda p:score_sets('ema',p,validation))
    no_material=max(grid,key=lambda p:score_sets('mgd_no_material',p,validation))
    best_unbounded=max((x for x in tuning if math.isinf(x['params']['cap'])),key=lambda x:x['score'])
    selection={'mgd':chosen,'ema':ema,'retunedNoMaterial':no_material,'unbounded':best_unbounded,
        'mgdGridSize':len(grid),'emaGridSize':len(ema_grid)}
    (out/'validation_selection.json').write_text(json_text(selection,indent=2))
    print('VALIDATION_SELECTION',json_text(selection),flush=True)
    models=[];training=[]
    for seed in [21,22,23]:
        if a.resume_evaluation:
            saved=torch.load(out/f'transformer_{seed}.pt',weights_only=False)
            model=TinyTransformer();model.load_state_dict(saved['state']);model.eval()
            info=next(r for r in json.loads((out/'training_metadata.json').read_text()) if r['seed']==seed)
            info['log']=saved['log']
        else:
            model,info=train(seed,validation,out)
        models.append(model);training.append(info)
    (out/'training_metadata.json').write_text(json_text(training,indent=2))
    # Evaluation data are first generated only after all selections/training.
    test=fixed_sets(72000,256)
    test_hash=hashlib.sha256(b''.join(d[k].tobytes() for d in test.values() for k in ['keys','obs','target'])).hexdigest()
    np.savez_compressed(out/'test_streams.npz',**{name+'_'+k:v for name,d in test.items() for k,v in d.items()})
    variants={'MGD':('mgd',p),'MGD_no_material_same_params':('mgd_no_material',p),
        'MGD_no_memory_same_params':('mgd_no_memory',p),'MGD_no_material_retuned':('mgd_no_material',no_material),
        'MGD_unbounded':('mgd',best_unbounded['params']),'EMA':('ema',ema),'counts':('count',{}),
        'last_observation':('last',{}),'no_state':('constant',{})}
    results={};per_episode={};predictions={}
    for name,(mode,params) in variants.items():
        results[name]={};per_episode[name]=[]
        for scenario,data in test.items():
            start=time.perf_counter();pred=memory(data,mode,params);ms=1000*(time.perf_counter()-start)
            correct=pred[:,BURN:]==data['target'][:,BURN:]
            results[name][scenario]={'accuracy':float(correct.mean()),'batch256TotalMs':ms}
            per_episode[name].append(correct.mean(1));predictions[name+'_'+scenario]=pred
    # Oracle HMM: privileged true generator parameters, explicitly an upper-reference,
    # not a deployable trained SOTA baseline and not used to choose other models.
    results['Bayes_known_generator']={};per_episode['Bayes_known_generator']=[]
    for scenario,data in test.items():
        h,n=SCENARIOS[scenario];pred=memory(data,'bayes',{'hazard':h,'noise':n})
        correct=pred[:,BURN:]==data['target'][:,BURN:]
        results['Bayes_known_generator'][scenario]={'accuracy':float(correct.mean())}
        per_episode['Bayes_known_generator'].append(correct.mean(1))
    per_episode['Transformer_mean']=[];results['Transformer_mean']={}
    for scenario,data in test.items():
        corrects=[];ms=[]
        for model,seed in zip(models,[21,22,23]):
            start=time.perf_counter();pred=transformer_predictions(model,data);ms.append(1000*(time.perf_counter()-start))
            corrects.append(pred[:,BURN:]==data['target'][:,BURN:]);predictions[f'Transformer{seed}_'+scenario]=pred
        avg=np.mean(corrects,axis=0)
        per_episode['Transformer_mean'].append(avg.mean(1))
        results['Transformer_mean'][scenario]={'accuracy':float(avg.mean()),'seedAccuracies':[float(x.mean()) for x in corrects],
            'batch256TotalMs':ms}
    comparisons={name:paired_interval(per_episode['MGD'],per_episode[name]) for name in per_episode if name!='MGD'}
    genuine=bool(all(x['validControl'] for x in training) and comparisons['Transformer_mean']['ci95Percentile'][0]>0 and comparisons['EMA']['ci95Percentile'][0]>0 and comparisons['MGD_no_material_retuned']['ci95Percentile'][0]>0)
    report={'scope':'Synthetic noisy changing key-value memory, 8 keys/4 values/128 events. Not language fluency or frontier LLM superiority.',
        'environment':{'python':platform.python_version(),'numpy':np.__version__,'torch':torch.__version__,'threads':2,'cpu':platform.processor()},
        'selection':selection,'training':training,'testSha256':test_hash,'episodesPerScenario':256,
        'scoredEventsPerEpisode':T-BURN,'results':results,'pairedComparisonsMGDMinusOther':comparisons,
        'predeclaredSuccessCriterionMet':genuine,
        'limitations':['Original papers do not define this prediction objective, token encoding, per-key clock, cost cap, or decoder.',
          'MGD structural slot addressing and Transformer learned addressing have different inductive biases and offline budgets.',
          'Bootstrap conditions on the three trained checkpoints; it does not quantify all training-run variability.',
          'Timing is batch-throughput on CPU with optimized parallel Transformer evaluation; not phone latency or energy.',
          'This does not implement or compare complete Titans, TTT, all Transformer variants, or general language models.']}
    (out/'results.json').write_text(json_text(report,indent=2));np.savez_compressed(out/'predictions.npz',**predictions)
    short={name:{s:round(v['accuracy'],5) for s,v in row.items()} for name,row in results.items()}
    print('FINAL_BENCHMARK',json.dumps({'accuracy':short,'comparisons':comparisons,'success':genuine}),flush=True)

if __name__=='__main__':main()
