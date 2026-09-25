"""Audit after the 0.5B baseline failed independent health controls.
App, weights, dataset, labels and MGD predictions are unchanged.
Only select prompt representation on the eight separate controls.
"""
import json,time,statistics,hashlib
from pathlib import Path
import torch
from huggingface_hub import model_info
from transformers import AutoTokenizer, AutoModelForCausalLM
torch.set_num_threads(2)
model_id="Qwen/Qwen2.5-1.5B-Instruct"
revision=model_info(model_id).sha
tokenizer=AutoTokenizer.from_pretrained(model_id,revision=revision)
model=AutoModelForCausalLM.from_pretrained(model_id,revision=revision,torch_dtype=torch.float32)
model.eval()
def render(option,mode):
    if option is None:return "Nessuna relazione utilizzabile: il testo non permette di rispondere."
    if mode=="json":return json.dumps(option,ensure_ascii=False)
    return f"{option['agent']} {'non ' if option['negative'] else ''}{option['relation']} {option['patient']}."
def ask(case,mode):
    content=("Usa soltanto le affermazioni fornite. Scegli quale opzione risponde alla domanda. "
        "Una correzione esplicita sostituisce la precedente affermazione sullo stesso soggetto e azione. "
        "Una frase ipotetica con 'se' non dimostra che il fatto sia accaduto. "
        "Conserva negazioni e ruoli: chi compie l'azione e chi la riceve. "
        "Le opzioni descrivono relazioni intere, anche se la domanda chiede soltanto chi agisce. "
        "Rispondi esclusivamente con il numero 1, 2, 3 o 4.\n\nTesto:\n"
        +"\n".join(case["history"])+"\n\nDomanda: "+case["question"]+"\n\nOpzioni:\n"
        +"\n".join(f"{i+1}. {render(o,mode)}" for i,o in enumerate(case["options"])))
    x=tokenizer.apply_chat_template([{"role":"user","content":content}],
        tokenize=True,add_generation_prompt=True,return_tensors="pt")
    start=time.perf_counter()
    with torch.inference_mode():
        logits=model(x,attention_mask=torch.ones_like(x)).logits[0,-1]
    # Forced-choice likelihood avoids judging harmless answer punctuation.
    token_ids=[tokenizer.encode(str(i),add_special_tokens=False) for i in range(1,5)]
    assert all(len(t)==1 for t in token_ids)
    scores=[float(logits[t[0]]) for t in token_ids]
    pred=max(range(4),key=lambda i:scores[i])
    return pred,(time.perf_counter()-start)*1000,scores
def fact(a,r,b,neg=False):return {"agent":a,"relation":r,"patient":b,"negative":neg}
def control(history,question,answer,slot):
    base=fact("mario","aiuta","anna")
    if answer is None:
        choices=[base,fact("anna","aiuta","mario"),fact("mario","aiuta","anna",True)]
    else:
        choices=[None,{**answer,"agent":answer["patient"],"patient":answer["agent"]},
            {**answer,"negative":not answer["negative"]}]
    choices.insert(slot,answer)
    return {"history":history,"question":question,"options":choices,"answerIndex":slot}
controls=[]
for i,(a,b) in enumerate([("mario","anna"),("luca","sara"),("rita","marco"),("piero","elsa")]):
    controls.append(control([f"{a} aiuta {b}."],f"Chi aiuta {b}?",fact(a,"aiuta",b),i))
controls.extend([
    control(["Il gatto non insegue il topo."],"Il gatto insegue il topo?",fact("gatto","insegue","topo",True),2),
    control(["Se Mario aiuta Anna, la porta si apre."],"Chi aiuta Anna?",None,1),
    control(["Marco aiuta Anna.","Correggi: Marco aiuta Sara."],"Chi aiuta Sara?",fact("marco","aiuta","sara"),0),
    control(["Anna è aiutata da Mario."],"Chi aiuta Anna?",fact("mario","aiuta","anna"),3),
])
health={}
for mode in ["text","json"]:
    records=[]
    for c in controls:
        p,ms,s=ask(c,mode)
        records.append({"expected":c["answerIndex"],"prediction":p,"correct":p==c["answerIndex"],"scores":s})
    health[mode]={"correct":sum(r["correct"] for r in records),"total":len(records),"cases":records}
    print("HEALTH324 "+json.dumps({"mode":mode,**health[mode]}),flush=True)
mode=max(health,key=lambda x:health[x]["correct"])
valid=health[mode]["correct"]>=7
path=Path("mgd-neuro-app/tool/relational_eval_v0324.json")
dataset=json.loads(path.read_text())
rows=[]
if valid:
    for c in dataset["cases"]:
        p,ms,s=ask(c,mode)
        rows.append({"id":c["id"],"category":c["category"],"expected":c["answerIndex"],
            "prediction":p,"correct":p==c["answerIndex"],"ms":ms,"scores":s})
        if len(rows)%48==0:print(f"Audit cases {len(rows)}/{len(dataset['cases'])}",flush=True)
times=sorted(r["ms"] for r in rows)
summary={"model":model_id,"revision":revision,"mode":mode,"validBaseline":valid,
    "healthCorrect":health[mode]["correct"],"healthTotal":8,
    "correct":sum(r["correct"] for r in rows),"total":len(rows),
    "medianMs":statistics.median(times) if times else None,
    "p95Ms":times[int(len(times)*.95)] if times else None,
    "categories":{cat:{"correct":sum(r["correct"] for r in rows if r["category"]==cat),
      "total":sum(r["category"]==cat for r in rows)} for cat in sorted(set(r["category"] for r in rows))}}
report={"summary":summary,"health":health,"cases":rows,"datasetSha256":hashlib.sha256(path.read_bytes()).hexdigest(),
    "appCommit":"a305498d59fc1933c3f40dff0dac6f79bcfc5eb1",
    "protocol":"Post-hoc audit of invalid 0.5B baseline; 1.5B prompt selected using only eight separate controls. Fixed four-choice likelihood; dataset and app unchanged. Synthetic development templates, not blind evaluation.",
    "limits":"Pretraining budgets differ; forced choice is not general generation. No general Transformer or MGD architecture superiority claim."}
Path("relational-audit-0.32.4.json").write_text(json.dumps(report,indent=2,ensure_ascii=False))
print("AUDIT324 "+json.dumps(summary),flush=True)
