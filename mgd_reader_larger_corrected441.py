"""Fixed 4B candidate on the same 40 development cases, with no gold in prompts."""
import hashlib,json,os,pathlib,time,traceback,resource
from huggingface_hub import hf_hub_download
import litert_lm
from mgd_reader_qwen_template441 import TEMPLATE

out=pathlib.Path('mgd-reader-larger-corrected-results');out.mkdir(exist_ok=True)
source=pathlib.Path('mgd_reader_grounding_development441.json')
prompts=json.loads(source.read_text())
gold=json.loads(pathlib.Path('mgd_reader_grounding_development_key441.json').read_text())
assert len(prompts)==40 and set(gold)=={p['id'] for p in prompts}
report=dict(candidate='Qwen3-4B-Instruct-2507 mixed INT4',
    source_commit=os.environ.get('GITHUB_SHA'),workflow_run=os.environ.get('GITHUB_RUN_ID'),
    source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
    model_revision='4d409771b414d86b270ca54d27ffc45032a81142',
    model_sha256='9e48b165836256f5344d9d044930607b9c47f6ef34e27f82e96881664f3ba2fd',
    config=dict(thinking_budget=0,max_context_tokens=2048,max_output_tokens=512,top_k=20,top_p=.8,temperature=.7,seed=439),
    chat_template='canonical content string/list, Qwen im_start/im_end',
    stage='download',results=[],scores={},android_tested=False,
    universal_comprehension_proven=False,semantic_entailment_verified=False)
def save():
    report['peak_process_rss_kib']=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    for cohort in ('development24','diagnostic16'):
        rs=[r for r in report['results'] if r['cohort']==cohort]
        report['scores'][cohort]=dict(total=len(rs),exact_choices_correct=sum(r.get('exact_choice_correct',False) for r in rs),passed=sum(r['passed'] for r in rs))
    (out/'larger-corrected441.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
started=time.monotonic();save()
try:
    path=hf_hub_download('litert-community/Qwen3-4B-Instruct-2507',
        'qwen3_4b_instruct_2507_mixed_int4.litertlm',revision=report['model_revision'])
    report['model_bytes']=pathlib.Path(path).stat().st_size
    with open(path,'rb') as stream:assert hashlib.file_digest(stream,'sha256').hexdigest()==report['model_sha256']
    report['stage']='engine_init';save()
    with litert_lm.Engine(path,max_num_tokens=2048) as engine:
        report['stage']='inference';save()
        for p in prompts:
            before,raw=time.monotonic(),None
            try:
                with engine.create_conversation(extra_context={'enable_thinking':False},
                        thinking_config=litert_lm.ThinkingConfig(enable_thinking=False,thinking_token_budget=0),
                        sampler_config=litert_lm.SamplerConfig(top_k=20,top_p=.8,temperature=.7,seed=439),
                        max_output_tokens=512,automatic_tool_calling=False,chat_template=TEMPLATE) as conv:
                    raw=str(conv.send_message(p['baseline_prompt']))
                a,b=raw.find('{'),raw.rfind('}')
                data=json.loads(raw[a:b+1])
                known={r['id'] for r in p['rows']}
                refs,unknown=data.get('evidence'),data.get('unknown')
                valid=isinstance(refs,list) and all(isinstance(r,str) and r in known for r in refs)
                valid=valid and isinstance(unknown,bool) and (unknown or bool(refs))
                correct=str(data.get('answer','')).strip().upper()==gold[p['id']]['answer']
                calibrated=isinstance(unknown,bool) and unknown==gold[p['id']]['unknown']
                r=dict(id=p['id'],cohort=p['cohort'],raw=raw,expected=gold[p['id']],
                    exact_choice_correct=correct,citation_format_valid=valid,abstention_correct=calibrated,
                    passed=correct and valid and calibrated)
            except Exception as ex:r=dict(id=p['id'],cohort=p['cohort'],raw=raw,error=str(ex),passed=False)
            r['elapsed_seconds']=time.monotonic()-before;report['results'].append(r);save()
            print('CASE',p['id'],r['passed'],flush=True)
    report['stage']='complete';report['runtime_success']=True
except Exception as ex:
    report['runtime_success']=False;report['error']=str(ex);report['traceback']=traceback.format_exc()
finally:
    report['elapsed_seconds']=time.monotonic()-started;save()
    print('FINAL',json.dumps({k:v for k,v in report.items() if k not in ('results','traceback')},ensure_ascii=False),flush=True)
