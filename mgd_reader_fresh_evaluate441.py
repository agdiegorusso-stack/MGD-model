"""Fixed selected reader on 16 frozen fresh cases; gold remains outside model prompts."""
import hashlib,json,os,pathlib,time,traceback,resource
from huggingface_hub import hf_hub_download
import litert_lm
from mgd_reader_qwen_template441 import TEMPLATE

out=pathlib.Path('mgd-reader-fresh-results-'+os.environ.get('MGD_FRESH_ROLE','candidate'));out.mkdir(exist_ok=True)
role=os.environ.get('MGD_FRESH_ROLE','candidate')
assert role in ('baseline','candidate')
selection=json.loads(pathlib.Path('mgd_reader_fresh_selected441.json').read_text())
assert selection['selected'] is True
assert selection['model_sha256']=='9e48b165836256f5344d9d044930607b9c47f6ef34e27f82e96881664f3ba2fd'
a,b=selection['scores']['development24'],selection['scores']['diagnostic16']
assert a['total']==24 and b['total']==16
assert a['exact_choices_correct']>=21 and a['passed']>=17 and b['exact_choices_correct']>=11 and b['passed']>=9
assert a['exact_choices_correct']>=23 or b['exact_choices_correct']>=13
source=pathlib.Path('mgd-neural-0421/tool/reports/fresh441-production-prompts.json')
prompts=json.loads(source.read_text())
for p in prompts:p['cohort']='fresh16'
gold=json.loads(pathlib.Path('mgd_reader_fresh_key441.json').read_text())
assert len(prompts)==16 and set(gold)=={p['id'] for p in prompts}
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
    for cohort in ('fresh16',):
        rs=[r for r in report['results'] if r['cohort']==cohort]
        report['scores'][cohort]=dict(total=len(rs),exact_choices_correct=sum(r.get('exact_choice_correct',False) for r in rs),passed=sum(r['passed'] for r in rs))
    (out / ('fresh441-'+role+'.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2))
report['selection']=selection
report['role']=role
report['heldout_frozen_before_candidate_results']=True
report['source_fixture_sha256']='c93bd5eaebd25a60718c6b0281cc26b9f1cf0c5ce48917d721f993896d348418'
repo='litert-community/Qwen3-4B-Instruct-2507';filename='qwen3_4b_instruct_2507_mixed_int4.litertlm'
if role=='baseline':
    repo='litert-community/Qwen3-1.7B';filename='Qwen3-1.7B_dynamic_wi4b32_afp32.litertlm'
    report.update(candidate='Released Qwen3-1.7B',model_revision='79bf0667b32ae025b972e5fe555fe72ca6e8816c',model_sha256='2a72330b504a6596d53a2c00923c57173b10f1b83e6a541213ffec08d1fc5de8',chat_template='original model template')
    report['config']=dict(thinking_budget=256,max_context_tokens=3072,max_output_tokens=768,top_k=20,top_p=.95,temperature=.6,seed=439)
started=time.monotonic();save()
try:
    path=hf_hub_download(repo,filename,revision=report['model_revision'])
    report['model_bytes']=pathlib.Path(path).stat().st_size
    with open(path,'rb') as stream:assert hashlib.file_digest(stream,'sha256').hexdigest()==report['model_sha256']
    report['stage']='engine_init';save()
    with litert_lm.Engine(path,max_num_tokens=report['config']['max_context_tokens']) as engine:
        report['stage']='inference';save()
        for p in prompts:
            before,raw=time.monotonic(),None
            try:
                with engine.create_conversation(extra_context={'enable_thinking':role=='baseline'},
                        thinking_config=litert_lm.ThinkingConfig(enable_thinking=role=='baseline',thinking_token_budget=report['config']['thinking_budget']),
                        sampler_config=litert_lm.SamplerConfig(top_k=20,top_p=report['config']['top_p'],temperature=report['config']['temperature'],seed=439),
                        max_output_tokens=report['config']['max_output_tokens'],automatic_tool_calling=False,**({'chat_template':TEMPLATE} if role=='candidate' else {})) as conv:
                    raw=str(conv.send_message(p['prompt']))
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
