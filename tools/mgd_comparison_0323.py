"""Audit the degenerate first baseline without changing the frozen test set."""
import gc, hashlib, json, os, platform, re, statistics, time, traceback
from pathlib import Path
import torch, transformers
from transformers import AutoTokenizer, AutoModelForCausalLM
from huggingface_hub import model_info
ROOT=Path(__file__).resolve().parent.parent/"mgd-neuro-app"
OUT=ROOT/"comparison-audit-0.32.3.json"
dataset=json.loads((ROOT/"tool/source_eval_v0323.json").read_text())
mgd=json.loads((ROOT/"source-eval-mgd-0.32.3.json").read_text())
torch.set_num_threads(2)
health=[
 ("What color is the square?",["The square is blue.","The circle is red.","The triangle is green."],1),
 ("Where is the key?",["The coin is in the drawer.","The key is in the box.","The pen is on the desk."],2),
 ("What does Mira drink?",["Timo drinks water.","Lina drinks milk.","Mira drinks tea."],3),
 ("How heavy is the box?",["The box is green.","The box is on a shelf.","The box contains a key."],0),
]
def task(q,docs):
 return "\n".join(f"{i+1}: {d}" for i,d in enumerate(docs))+"\nQuestion: "+q+"\nSource number:"
def summary(rows):
 ts=sorted(r["queryMs"] for r in rows)
 categories={}
 for r in rows:
  x=categories.setdefault(r["category"],{"correct":0,"total":0})
  x["correct"]+=int(r["correct"]);x["total"]+=1
 return {"correct":sum(r["correct"] for r in rows),"total":len(rows),
  "queryMedianMs":statistics.median(ts),"queryP95Ms":ts[min(len(ts)-1,int(len(ts)*.95))],
  "categories":categories}
report={"status":"running","originalBaseline":"Qwen3-0.6B returned 0 on all 24 cases; not accepted as superiority evidence.",
 "appCommit":"9725c1fda0e024afd52550fe79e425d9ede8253e",
 "evaluationCommit":os.environ.get("GITHUB_SHA"),"scope":dataset["scope"],
 "datasetFileSha256":hashlib.sha256((ROOT/"tool/source_eval_v0323.json").read_bytes()).hexdigest(),
 "protocolAmendment":"After observing constant output, select prompt only on four separate health checks. Frozen 24 evaluation cases and MGD implementation remain unchanged. Not a blind test.",
 "healthThreshold":"At least 3/4 correct and nonconstant predictions, otherwise baseline invalid.",
 "platform":platform.platform(),"torch":torch.__version__,"transformers":transformers.__version__,
 "threads":2,"mgd":summary(mgd["cases"]),"models":[]}
try:
 for model_id in ["Qwen/Qwen3-0.6B","Qwen/Qwen2.5-0.5B-Instruct"]:
  row={"model":model_id,"revision":model_info(model_id).sha,"status":"running"}
  report["models"].append(row)
  clock=time.perf_counter()
  tokenizer=AutoTokenizer.from_pretrained(model_id,revision=row["revision"])
  model=AutoModelForCausalLM.from_pretrained(model_id,revision=row["revision"],
    torch_dtype=torch.float32,attn_implementation="eager").eval()
  row["downloadAndLoadSeconds"]=time.perf_counter()-clock
  def run(q,docs,mode):
   messages=[{"role":"system","content":
     "Find the source that answers the question. Return its number (1, 2, or 3). "
     "Return 0 only if no source answers the question. Output a single digit."}]
   if mode=="two_examples":
    messages.extend([
     {"role":"user","content":task("Where is Nora?",["Adam is at home.","Nora is at school.","Pia is outside."])},
     {"role":"assistant","content":"2"},
     {"role":"user","content":task("What is the bird's name?",["A bird is singing.","A cat is sleeping.","A dog is running."])},
     {"role":"assistant","content":"0"}])
   messages.append({"role":"user","content":task(q,docs)})
   text=tokenizer.apply_chat_template(messages,tokenize=False,
      add_generation_prompt=True,enable_thinking=False)
   start=time.perf_counter(); inputs=tokenizer(text,return_tensors="pt")
   with torch.inference_mode():
    output=model.generate(**inputs,max_new_tokens=32,do_sample=False,
      pad_token_id=tokenizer.eos_token_id)
   raw=tokenizer.decode(output[0,inputs.input_ids.shape[1]:],skip_special_tokens=True).strip()
   ms=(time.perf_counter()-start)*1000
   match=re.fullmatch(r"\s*([0-3])[\s.]*",raw)
   return int(match.group(1)) if match else -1,raw,ms
  calibration=[]
  for mode in ["simple","two_examples"]:
   checks=[]
   for q,docs,expected in health:
    selected,raw,ms=run(q,docs,mode)
    checks.append({"question":q,"expected":expected,"selected":selected,
      "raw":raw,"correct":selected==expected,"queryMs":ms})
   calibration.append({"mode":mode,"correct":sum(x["correct"] for x in checks),"checks":checks})
  row["calibration"]=calibration
  chosen=max(calibration,key=lambda x:x["correct"])
  row["promptMode"]=chosen["mode"]
  row["healthValid"]=chosen["correct"]>=3 and len(set(x["selected"] for x in chosen["checks"]))>1
  print("HEALTH323 "+json.dumps(row),flush=True)
  if row["healthValid"]:
   cases=[]
   for case in dataset["cases"]:
    selected,raw,ms=run(case["question"],case["documents"],chosen["mode"])
    cases.append({"id":case["id"],"category":case["category"],"question":case["question"],
      "selected":selected,"expected":case["expected"],"raw":raw,
      "correct":selected==case["expected"],"queryMs":ms})
    print("CASE323 "+json.dumps(cases[-1]),flush=True)
   row.update(status="completed",summary=summary(cases),cases=cases)
  else:
   row.update(status="invalid_baseline",reason="Failed independent control questions; no superiority claim allowed.")
  OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2))
  del model,tokenizer;gc.collect()
 report["status"]="completed"
except Exception as exc:
 report.update(status="failed",error=type(exc).__name__+": "+str(exc))
 traceback.print_exc()
finally:
 OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2))
 compact={**report,"models":[{k:v for k,v in r.items() if k not in ["cases","calibration"]} for r in report["models"]]}
 print("AUDIT323 "+json.dumps(compact,ensure_ascii=False),flush=True)
if report["status"]=="failed": raise SystemExit(1)
