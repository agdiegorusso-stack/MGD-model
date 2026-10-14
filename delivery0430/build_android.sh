#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/mgd-neural-0421"
for command in flutter java python3; do
  command -v "$command" >/dev/null || { printf 'Requisito mancante: %s\n' "$command" >&2; exit 2; }
done
export MGD_APPLICATION_ID=it.diegorusso.mgdneurostable.studio.axioms
export MGD_APPLICATION_LABEL='MGD Studio Assiomi'
export OPENBLAS_NUM_THREADS=1
cd "$APP"
chmod +x android/gradlew
export FLUTTER_ROOT="$(python3 -c 'import pathlib,shutil; print(pathlib.Path(shutil.which("flutter")).resolve().parent.parent)')"
mkdir -p tool/reports
[ -s assets/reader443.json ] || { echo 'Checkpoint originale mancante.' >&2; exit 3; }
[ -s tool/fixtures/runtime-reference443.json ] || { echo 'Fixture originali mancanti.' >&2; exit 3; }
python3 ../delivery0430/check_patch.py | tee tool/reports/source-integrity0430.json
flutter --version | tee tool/reports/toolchain0430.txt
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tee tool/reports/analyze0430.log
# Compare the retained reference images. Never rewrite golden images here.
flutter test --machine 2>&1 | tee tool/reports/full-tests0430.jsonl
flutter build apk --release --target-platform android-arm64 2>&1 | tee tool/reports/build0430.log
APK=build/app/outputs/flutter-apk/app-release.apk
[ -s "$APK" ]
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[ -n "$ANDROID_SDK" ] || { echo 'Android SDK mancante.' >&2; exit 4; }
TOOLS="$(python3 - "$ANDROID_SDK" <<'PYTOOLS'
from pathlib import Path
import sys
p=Path(sys.argv[1])/'build-tools'
choices=[x for x in p.iterdir() if (x/'apksigner').is_file() and (x/'aapt').is_file()]
if not choices: raise SystemExit('Android build-tools non trovati')
print(sorted(choices, key=lambda x:[int(n) if n.isdigit() else 0 for n in x.name.split('.')])[-1])
PYTOOLS
)"
"$TOOLS/apksigner" verify --verbose --print-certs "$APK" > tool/reports/apk-signature0430.txt
"$TOOLS/aapt" dump badging "$APK" > tool/reports/apk-identity0430.txt
python3 - <<'PYVERIFY'
from pathlib import Path
import zipfile,hashlib,json,os
p=Path('build/app/outputs/flutter-apk/app-release.apk')
s=Path('tool/reports/apk-identity0430.txt').read_text()
assert "name='it.diegorusso.mgdneurostable.studio.axioms'" in s
assert "versionName='0.43.0'" in s and "versionCode='110'" in s
with zipfile.ZipFile(p) as z:
    assert z.testzip() is None
    assert 'assets/flutter_assets/assets/reader443.json' in z.namelist()
    assert any(n.startswith('lib/arm64-v8a/') for n in z.namelist())
    assert not any(n.endswith(('.litertlm','.gguf','.safetensors')) for n in z.namelist())
Path('tool/reports/apk0430.json').write_text(json.dumps({
 'application_id':os.environ['MGD_APPLICATION_ID'], 'version':'0.43.0', 'build':110,
 'bytes':p.stat().st_size, 'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
 'teacher_weights_bundled':False, 'physical_phone_inference_tested':False},indent=2))
PYVERIFY
mkdir -p "$ROOT/delivery0430/output"
cp "$APK" "$ROOT/delivery0430/output/MGD-Studio-Assiomi-0.43.0-arm64.apk"
printf '\nAPK compilato, test e firma verificati: %s\n' "$ROOT/delivery0430/output/MGD-Studio-Assiomi-0.43.0-arm64.apk"
