#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p tool/reports
if ! command -v python3 >/dev/null; then
  echo 'Manca Python 3, necessario per registrare il risultato della build.' >&2
  exit 127
fi
mgd_build_stage='prerequisites'
trap 'mgd_build_code=$?; python3 - "$mgd_build_stage" "$mgd_build_code" <<'"'"'PY'"'"'
import json, pathlib, sys, time
pathlib.Path("tool/reports/build_status.json").write_text(json.dumps({
  "version": "0.42.9", "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
  "stage": sys.argv[1], "exit_code": int(sys.argv[2]),
  "apk_built": sys.argv[1] == "complete" and sys.argv[2] == "0"
}, indent=2))
PY
' EXIT
if ! command -v flutter >/dev/null || ! command -v dart >/dev/null; then
  echo 'Compilazione bloccata: installa Flutter 3.44 o successivo, con Dart 3.12 e SDK Android.' >&2
  exit 127
fi
flutter --version --machine > tool/reports/flutter_version.json
python3 - <<'PY'
import json, re
v = json.load(open('tool/reports/flutter_version.json'))
def version(x): return tuple(map(int, re.match(r'(\d+)\.(\d+)\.(\d+)', x).groups()))
if version(v['frameworkVersion']) < (3,44,0) or version(v['dartSdkVersion']) < (3,12,0):
    raise SystemExit('SDK troppo vecchio: servono Flutter >=3.44.0 e Dart >=3.12.0.')
PY
mgd_build_stage='dependencies'
flutter pub get 2>&1 | tee tool/reports/pub_get.log
mgd_build_stage='format'
dart format lib test 2>&1 | tee tool/reports/format.log
mgd_build_stage='analyze'
flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tee tool/reports/analyze.log
mgd_build_stage='tests'
flutter test --machine 2>&1 | tee tool/reports/flutter_tests.jsonl
mgd_build_stage='live-study'
flutter test tool/live_study_v0427_test.dart --reporter expanded 2>&1 | tee tool/reports/live-study.log
mgd_build_stage='apk'
flutter build apk --release 2>&1 | tee tool/reports/build.log
python3 - <<'PY'
import hashlib, pathlib
apk = pathlib.Path('build/app/outputs/flutter-apk/app-release.apk')
if not apk.is_file(): raise SystemExit('APK assente dopo il comando di build.')
digest = hashlib.sha256(apk.read_bytes()).hexdigest()
pathlib.Path('tool/reports/APK-SHA256.txt').write_text(digest+'  app-release.apk\n')
print('APK:', apk.resolve())
PY
mgd_build_stage='complete'
