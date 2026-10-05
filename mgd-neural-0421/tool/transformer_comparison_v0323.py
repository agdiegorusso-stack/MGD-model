"""Frozen development evaluation, not a claim of universal superiority."""
import hashlib, json, os, platform, re, statistics, time, traceback
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/"transformer-comparison-0.32.3.json"
dataset=json.loads((ROOT/"tool/source_eval_v0323.json").read_text())
mgd=json.loads((ROOT/"source-eval-mgd-0.32.3.json").read_text())
report={"status":"running","model":"Qwen/Qwen3-0.6B","dataset":dataset["name"],
        "scope":dataset["scope"],"platform":platform.platform(),
        "cpu":platform.processor(),"threads":2,
        "datasetFileSha256":hashlib.sha256((ROOT/"tool/source_eval_v0323.json").read_bytes()).hexdigest(),
        "limitations":["24 authored development cases; not a blind or public benchmark.",
          "One small multilingual Transformer, not all Transformers or frontier models.",
          "Same runner CPU and input passages; MGD index versus pretrained in-context inference.",
          "Pretraining costs are not comparable to storing new source passages.",
          "Passage-selection accuracy, not free-form answer quality or calibrated truth.",
          "No phone latency or energy measurement; failures remain in the result."]}
try:
    import torch, transformers
    from transformers import AutoTokenizer, AutoModelForCausalLM
    from huggingface_hub import model_info
    torch.set_num_threads(2)
    model_id=report["model"]
    revision=model_info(model_id).sha
    report.update(revision=revision,torchVersion=torch.__version__,
                  transformersVersion=transformers.__version__)
    started=time.perf_counter()
    tokenizer=AutoTokenizer.from_pretrained(model_id,revision=revision)
    model=AutoModelForCausalLM.from_pretrained(model_id,revision=revision,
        torch_dtype=torch.float32,attn_implementation="eager").eval()
    report["downloadAndLoadSeconds"]=time.perf_counter()-started
    report["parameterCount"]=sum(p.numel() for p in model.parameters())
    def run(question,docs):
        prompt=("Select the ONE numbered source passage that directly answers the question. "
          "The passage may answer with a negation or a condition. Do not reverse subject and object. "
          "Return 0 if the requested information is not in any passage. "
          "Return only one digit: 0, 1, 2, or 3.\n\n"+
          "\n".join(f"{i+1}. {d}" for i,d in enumerate(docs))+
          "\n\nQuestion: "+question)
        text=tokenizer.apply_chat_template([{"role":"user","content":prompt}],
                tokenize=False,add_generation_prompt=True,enable_thinking=False)
        clock=time.perf_counter()
        inputs=tokenizer(text,return_tensors="pt")
        with torch.inference_mode():
            output=model.generate(**inputs,max_new_tokens=12,do_sample=False,
                pad_token_id=tokenizer.eos_token_id)
        answer=tokenizer.decode(output[0,inputs.input_ids.shape[1]:],skip_special_tokens=True).strip()
        elapsed=(time.perf_counter()-clock)*1000
        match=re.fullmatch(r"\s*([0-3])[\s.]*",answer)
        return (int(match.group(1)) if match else -1),answer,elapsed
    run("What is a lamp?",["A lamp is a light source.","A box is a container.","A cup holds water."])
    rows=[]
    for case in dataset["cases"]:
        selected,answer,elapsed=run(case["question"],case["documents"])
        rows.append({"id":case["id"],"category":case["category"],
          "expected":case["expected"],"selected":selected,"raw":answer,
          "correct":selected==case["expected"],"queryMs":elapsed})
        print(json.dumps(rows[-1]),flush=True)
        report["cases"]=rows
        OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2))
    def summary(rows):
        times=sorted(r["queryMs"] for r in rows)
        categories={}
        for r in rows:
            s=categories.setdefault(r["category"],{"correct":0,"total":0})
            s["total"]+=1
            s["correct"]+=int(r["correct"])
        return {"correct":sum(r["correct"] for r in rows),"total":len(rows),
          "queryMedianMs":statistics.median(times),
          "queryP95Ms":times[min(len(times)-1,int(len(times)*.95))],"categories":categories}
    report.update(status="completed",mgd=summary(mgd["cases"]),transformer=summary(rows),
      sameMachine=True,sourceCommit=os.environ.get("GITHUB_SHA"),
      result="Scope-limited measured comparison; no universal architecture claim.")
except Exception as exc:
    report.update(status="failed",error=type(exc).__name__+": "+str(exc))
    traceback.print_exc()
finally:
    OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2))
    print("COMPARISON323 "+json.dumps({k:v for k,v in report.items() if k!="cases"},ensure_ascii=False),flush=True)
if report["status"]!="completed":
    raise SystemExit(1)
