"""Small pretrained baseline on the same frozen synthetic cases.
Not a test of general Transformer superiority or equal pretraining budgets.
"""
import json, os, re, time, statistics
from pathlib import Path
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
torch.set_num_threads(2)
os.environ["HF_HUB_DISABLE_TELEMETRY"]="1"
MODEL="Qwen/Qwen2.5-0.5B-Instruct"
REVISION="7ae557604adf67be50417f59c2c2f167def9a775"
tokenizer=AutoTokenizer.from_pretrained(MODEL,revision=REVISION)
model=AutoModelForCausalLM.from_pretrained(MODEL,revision=REVISION,torch_dtype=torch.float32)
model.eval()
def ask(history, question, options):
    prompt=("Leggi le affermazioni. Una correzione esplicita sostituisce il vecchio fatto. "
        "Non invertire agente e oggetto. Le condizioni non sono fatti incondizionati. "
        "Scegli la relazione che risponde alla domanda. null significa che non puoi rispondere. "
        "Rispondi soltanto con il numero dell'opzione, da 1 a 4.\n"
        +"Affermazioni:\n"+"\n".join(history)+"\nDomanda: "+question+"\nOpzioni:\n"
        +"\n".join(f"{i+1}: {json.dumps(x,ensure_ascii=False)}" for i,x in enumerate(options)))
    inputs=tokenizer.apply_chat_template([{"role":"user","content":prompt}],
        tokenize=True,add_generation_prompt=True,return_tensors="pt")
    start=time.perf_counter()
    with torch.inference_mode():
        output=model.generate(inputs,attention_mask=torch.ones_like(inputs),
            max_new_tokens=6,do_sample=False,pad_token_id=tokenizer.eos_token_id)
    ms=(time.perf_counter()-start)*1000
    text=tokenizer.decode(output[0,inputs.shape[1]:],skip_special_tokens=True).strip()
    match=re.fullmatch(r"\s*([1-4])[\s.]*",text)
    return int(match[1])-1 if match else -1,text,ms
controls=[]
for i,(a,b) in enumerate([("mario","anna"),("luca","sara"),("rita","marco"),("piero","elsa")]):
    fact={"agent":a,"relation":"aiuta","patient":b,"negative":False}
    options=[None,{"agent":b,"relation":"aiuta","patient":a,"negative":False},
        {**fact,"negative":True}]
    options.insert(i,fact)
    pred,raw,ms=ask([f"{a} aiuta {b}."],f"Chi aiuta {b}?",options)
    controls.append({"expected":i,"prediction":pred,"raw":raw})
health=sum(c["prediction"]==c["expected"] for c in controls)
dataset=json.loads(Path("tool/relational_eval_v0324.json").read_text())
rows=[]
for c in dataset["cases"]:
    pred,raw,ms=ask(c["history"],c["question"],c["options"])
    rows.append({"id":c["id"],"category":c["category"],"expected":c["answerIndex"],
        "prediction":pred,"raw":raw,"correct":pred==c["answerIndex"],"ms":ms})
    if len(rows)%48==0:print(f"Baseline cases {len(rows)}/{len(dataset['cases'])}",flush=True)
times=sorted(r["ms"] for r in rows)
valid=health>=3 and len(set(c["prediction"] for c in controls))>=3
summary={"model":MODEL,"revision":REVISION,"healthCorrect":health,
    "healthTotal":len(controls),"validBaseline":valid,
    "correct":sum(r["correct"] for r in rows),"total":len(rows),
    "medianMs":statistics.median(times),"p95Ms":times[int(len(times)*.95)],
    "invalidFormats":sum(r["prediction"]==-1 for r in rows),
    "categories":{cat:{"correct":sum(r["correct"] for r in rows if r["category"]==cat),
      "total":sum(r["category"]==cat for r in rows)} for cat in sorted(set(r["category"] for r in rows))}}
report={"scope":dataset["scope"],"summary":summary,"controls":controls,"cases":rows,
    "limits":"Small pretrained model and synthetic relation vocabulary. Prompt fixed before run. Reader training and Transformer pretraining are not equal budgets; timings include different computations. No general superiority conclusion."}
Path("relational-transformer-0.32.4.json").write_text(json.dumps(report,indent=2,ensure_ascii=False))
print("TRANSFORMER324 "+json.dumps(summary),flush=True)
