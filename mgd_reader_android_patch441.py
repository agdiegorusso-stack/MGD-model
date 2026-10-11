"""Apply an isolated 4B Android feasibility experiment inside a CI checkout only."""
import pathlib,hashlib
from mgd_reader_qwen_template441 import TEMPLATE
root=pathlib.Path('mgd-neural-0421')
k=root/'android/app/src/main/kotlin/it/diegorusso/mgd_neuro_mobile/NeuralReader439.kt'
s=k.read_text()
def once(old,new):
 global s
 assert s.count(old)==1,(old,s.count(old))
 s=s.replace(old,new)
once('val reasoning = call.argument<Boolean>("reasoning") ?: false','val reasoning = false // fixed nonthinking 4B experiment')
once('automaticToolCalling = false,','automaticToolCalling = false,\n                                    chatTemplate = """'+TEMPLATE+'""",')
once('maxNumTokens = 3072','maxNumTokens = 2048')
once('"qwen3-1.7b-int4.litertlm"','"qwen3-4b-instruct-2507-int4.litertlm"')
s=s.replace('977184032L','2659057664L')
s=s.replace('2a72330b504a6596d53a2c00923c57173b10f1b83e6a541213ffec08d1fc5de8','9e48b165836256f5344d9d044930607b9c47f6ef34e27f82e96881664f3ba2fd')
s=s.replace('1600L * 1024 * 1024','6100L * 1024 * 1024')
k.write_text(s)
f=root/'tool/prepare_neural439.py'
s=f.read_text()
s=s.replace('litert-community/Qwen3-1.7B','litert-community/Qwen3-4B-Instruct-2507').replace('Qwen/Qwen3-1.7B','Qwen/Qwen3-4B-Instruct-2507')
s=s.replace('79bf0667b32ae025b972e5fe555fe72ca6e8816c','4d409771b414d86b270ca54d27ffc45032a81142').replace('Qwen3-1.7B_dynamic_wi4b32_afp32.litertlm','qwen3_4b_instruct_2507_mixed_int4.litertlm')
s=s.replace('2a72330b504a6596d53a2c00923c57173b10f1b83e6a541213ffec08d1fc5de8','9e48b165836256f5344d9d044930607b9c47f6ef34e27f82e96881664f3ba2fd').replace('977184032','2659057664')
s=s.replace('Qwen3-1.7B','Qwen3-4B-Instruct-2507').replace('MGD Studio 0.42.20','MGD 4B feasibility experiment')
f.write_text(s)
reports=root/'tool/reports';reports.mkdir(exist_ok=True)
(reports/'android441-prototype-source-sha256.txt').write_text('\n'.join(hashlib.sha256(q.read_bytes()).hexdigest()+' '+str(q) for q in [k,f]))
print('4B Android feasibility checkout prepared; released files in Git remain unchanged.')
