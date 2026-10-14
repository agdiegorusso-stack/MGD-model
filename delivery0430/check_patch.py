"""Verify that CI uses the corrected source files delivered to the user."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
expected={
 'mgd-neural-0421/lib/source_memory_v0323.dart':'e45f163f5c0a57d84b1a9c6a6b7f9e40ecaef9eb8cbb75b4a3f45f21af08094f',
 'mgd-neural-0421/android/app/src/main/kotlin/it/diegorusso/mgd_neuro_mobile/AxiomTeacherBridge.kt':'5a716ceeaa0ee33d203a56082704ec4e966db1d0f4824adbd4a48f5b0b721b29',
 'mgd-neural-0421/test/axioms0430_source_withdrawal_test.dart':'aa199bc0c647e6915a582d91de51925c14886bddd43c52a1959ac38a9e97c65d'}
for name,digest in expected.items():
 assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest, name
app=root/'mgd-neural-0421'
assert 'if (!processed.every(live.contains)) return false;' in (app/'lib/neural_reading_v0439.dart').read_text()
assert (app/'assets/reader443.json').is_file()
print(json.dumps({'static_patch_checks':'passed','source_sha256':expected}))
