import hashlib, json, pathlib, time, traceback
from huggingface_hub import HfApi, hf_hub_download
import litert_lm

out = pathlib.Path('mgd-reader-probe-results'); out.mkdir(exist_ok=True)
repo, filename = 'litert-community/Qwen3-1.7B', 'Qwen3-1.7B_dynamic_wi4b32_afp32.litertlm'
info = HfApi().model_info(repo, files_metadata=True)
entry = next(x for x in info.siblings if x.rfilename == filename)
print('AVAILABLE QWEN MODELS', [x.id for x in HfApi().list_models(author='litert-community',search='Qwen')],flush=True)
manifest = dict(repo=repo, filename=filename, revision=info.sha, bytes=entry.size, sha256=entry.lfs.sha256)
path = hf_hub_download(repo, filename, revision=info.sha)
with open(path, 'rb') as f: assert hashlib.file_digest(f, 'sha256').hexdigest() == manifest['sha256']
print('CANDIDATE VERIFIED', json.dumps(manifest), flush=True)
prompts = json.loads(pathlib.Path('mgd_reader_assessment_prompts439.json').read_text())
key = json.loads(pathlib.Path('mgd-neural-0421/tool/fixtures/neural_comprehension_439_key.json').read_text())
results, readings = [], []
with litert_lm.Engine(path, max_num_tokens=3072) as engine:
    for p in prompts:
        t = time.monotonic()
        try:
            with engine.create_conversation(extra_context={'enable_thinking': False},
                    thinking_config=litert_lm.ThinkingConfig(enable_thinking=False, thinking_token_budget=0), constrained_decoding_config=litert_lm.ConstrainedDecodingConfig(enable=True, provider=litert_lm.LiteRtLmConstraintProviderType.LL_GUIDANCE),
                    sampler_config=litert_lm.SamplerConfig(top_k=20, top_p=0.8, temperature=0.7, seed=439),
                    max_output_tokens=512, automatic_tool_calling=False) as conv:
                schema = {'type':'object','properties':{'answer':{'type':'string'},'evidence':{'type':'array','items':{'type':'string','enum':['P'+str(i) for i in range(p['context_rows'])]}},'unknown':{'type':'boolean'}},'required':['answer','evidence','unknown'],'additionalProperties':False}
                raw = str(conv.send_message(p['prompt'].replace('/no_think', '') + '\n/no_think', response_format=litert_lm.ResponseFormat.json(schema)))
            a,b=raw.find('{'),raw.rfind('}')
            data=json.loads(raw[a:b+1])
            refs=data.get('evidence',[]); unknown=data.get('unknown')
            valid=isinstance(refs,list) and all(isinstance(x,str) and x.startswith('P') and x[1:].isdigit() and int(x[1:])<p['context_rows'] for x in refs)
            valid=valid and isinstance(unknown,bool) and (unknown or bool(refs))
            correct=str(data.get('answer','')).strip().upper()==key[p['id']]['answer']
            r=dict(id=p['id'],raw=raw,exact_choice_correct=correct,citation_format_valid=valid,
                abstention_correct=unknown==key[p['id']]['unknown'],
                passed=correct and valid and unknown==key[p['id']]['unknown'],seconds=time.monotonic()-t)
        except Exception as ex: r=dict(id=p['id'],passed=False,error=str(ex))
        results.append(r);print('CANDIDATE CASE',p['id'],r['passed'],flush=True)
    for p in prompts[::4]:
        try:
            with engine.create_conversation(extra_context={'enable_thinking': False}, constrained_decoding_config=litert_lm.ConstrainedDecodingConfig(enable=True, provider=litert_lm.LiteRtLmConstraintProviderType.LL_GUIDANCE),
                    sampler_config=litert_lm.SamplerConfig(top_k=20, top_p=0.8, temperature=0.7, seed=439),
                    max_output_tokens=512, automatic_tool_calling=False) as conv:
                reading = p['reading_prompt'].replace('{\"notes\":[{\"text\":\"nota\",\"evidence\":[\"P0\"]}]}', 'un oggetto con campo notes, lista di oggetti con text (contenuto concreto) ed evidence (lista ID)')
                count = len(json.loads(reading.split('DATI:\n')[1]))
                schema = {'type':'object','properties':{'notes':{'type':'array','minItems':1,'maxItems':8,'items':{'type':'object','properties':{'text':{'type':'string','minLength':8,'maxLength':640},'evidence':{'type':'array','minItems':1,'items':{'type':'string','enum':['P'+str(i) for i in range(count)]}}},'required':['text','evidence'],'additionalProperties':False}}},'required':['notes'],'additionalProperties':False}
                raw=str(conv.send_message(reading, response_format=litert_lm.ResponseFormat.json(schema)))
            d=json.loads(raw[raw.find('{'):raw.rfind('}')+1]);notes=d.get('notes',[])
            readings.append(dict(id=p['id'],raw=raw,parsed=bool(notes) and all(n.get('text','').strip().lower() not in ['nota','contenuto concreto','risposta'] for n in notes),semantic_correctness_verified=False))
        except Exception as ex: readings.append(dict(id=p['id'],parsed=False,error=str(ex)))
report=dict(manifest=manifest,total=len(results),passed=sum(r['passed'] for r in results),
    exact_choices_correct=sum(r.get('exact_choice_correct',False) for r in results),
    results=results,readings=readings,model_selection_used_development_suite=True,thinking_budget=0, constrained_json=True,
    universal_comprehension_proven=False)
(out/'candidate-17b-constrained-comprehension-439.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print('CANDIDATE RESULT',json.dumps({k:v for k,v in report.items() if k not in ['results','readings']}),flush=True)
