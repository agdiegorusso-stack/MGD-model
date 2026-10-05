#!/usr/bin/env bash
set -euo pipefail
mkdir -p tool/reports
for mgd_attempt in 1 2; do
  set +e
  flutter test integration_test/restored_app_android_v0421_test.dart \
    -d emulator-5554 --reporter expanded 2>&1 \
    | tee "tool/reports/android-test-attempt-${mgd_attempt}.log"
  mgd_test_status=${PIPESTATUS[0]}
  set -e
  cp "tool/reports/android-test-attempt-${mgd_attempt}.log" tool/reports/android-test.log
  adb shell screencap -p > tool/reports/android-last-screen.png
  if (( mgd_test_status == 0 )); then break; fi
  if (( mgd_attempt == 1 )) && python3 - <<'PY'
from pathlib import Path
s = Path('tool/reports/android-test.log').read_text()
raise SystemExit(0 if 'Connecting to the VM Service timed out' in s and
    'teach, map, answer, engine controls and persisted restart' not in s else 1)
PY
  then
    # Retry only a debugger connection failure before any UI test has run.
    adb shell am force-stop it.diegorusso.mgdneurostable
    continue
  fi
  adb exec-out run-as it.diegorusso.mgdneurostable cat cache/restored-map421.png \
    > tool/reports/restored-map421.png || true
  exit "$mgd_test_status"
done
adb exec-out run-as it.diegorusso.mgdneurostable cat cache/restored-map421.png \
  > tool/reports/restored-map421.png
python3 - <<'PY'
from pathlib import Path
assert Path('tool/reports/restored-map421.png').read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
PY
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb logcat -c
adb shell am force-stop it.diegorusso.mgdneurostable
adb shell am start -W -n it.diegorusso.mgdneurostable/it.diegorusso.mgd_neuro_mobile.MainActivity \
  > tool/reports/release-start.txt
sleep 4
adb shell pidof it.diegorusso.mgdneurostable > tool/reports/release-pid.txt
adb logcat -d -s AndroidRuntime:E flutter:E > tool/reports/release-runtime.txt
adb shell screencap -p > tool/reports/release-launch.png
