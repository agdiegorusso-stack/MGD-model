#!/usr/bin/env bash
set -euo pipefail
bash tool/android_verify_421.sh
for mgd_attempt in 1 2; do
  set +e
  flutter test integration_test/large_memory_android_v0425_test.dart \
    -d emulator-5554 --reporter expanded 2>&1 \
    | tee "tool/reports/large-memory425-attempt-${mgd_attempt}.log"
  mgd_status=${PIPESTATUS[0]}
  set -e
  cp "tool/reports/large-memory425-attempt-${mgd_attempt}.log" tool/reports/large-memory425.log
  if (( mgd_status == 0 )); then break; fi
  if (( mgd_attempt == 1 )) && python3 - <<'PY'
from pathlib import Path
s=Path('tool/reports/large-memory425.log').read_text()
raise SystemExit(0 if 'Connecting to the VM Service timed out' in s and
    '50000 saved facts:' not in s else 1)
PY
  then
    adb shell am force-stop it.diegorusso.mgdneurostable
    continue
  fi
  adb shell screencap -p > tool/reports/large-memory425-failure.png
  exit "$mgd_status"
done
adb exec-out run-as it.diegorusso.mgdneurostable cat cache/large-memory425.json \
  > tool/reports/large-memory425.json
# Installing the actual release over the same signed debug package retains the
# real populated database; force-stop destroys the previous Flutter process.
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am force-stop it.diegorusso.mgdneurostable
adb logcat -c
adb shell am start -W -n it.diegorusso.mgdneurostable/it.diegorusso.mgd_neuro_mobile.MainActivity \
  > tool/reports/large-release425-start.txt
python3 - <<'PY'
import json, subprocess, time
from pathlib import Path
deadline=time.monotonic()+120
ready=None
while time.monotonic()<deadline:
    logs=subprocess.run(['adb','logcat','-d'],capture_output=True,text=True,timeout=15).stdout
    for line in logs.splitlines():
        if 'MGD_BOOT425 ' in line:
            ready=json.loads(line.split('MGD_BOOT425 ',1)[1])
    if ready is not None: break
    # Send real Android input while the populated release is restoring.
    subprocess.run(['adb','shell','input','tap','100','200'],check=True,timeout=15)
    time.sleep(1)
if ready is None: raise SystemExit('Release cold startup did not finish within 120 seconds.')
assert ready['status']=='ready' and ready['slots']==50000,ready
assert ready['episodes']==50000,ready
assert ready['ui_gap_ms']<1500,ready
Path('tool/reports/large-release425.json').write_text(json.dumps(ready,indent=2))
print('RELEASE_COLD_START425',json.dumps(ready))
PY
adb shell pidof it.diegorusso.mgdneurostable > tool/reports/large-release425-pid.txt
adb logcat -d > tool/reports/large-release425-logcat.txt
adb shell screencap -p > tool/reports/large-release425.png
python3 - <<'PY'
from pathlib import Path
s=Path('tool/reports/large-release425-logcat.txt').read_text()
assert 'ANR in it.diegorusso.mgdneurostable' not in s
assert 'FATAL EXCEPTION' not in s
assert 'E/flutter' not in s
assert Path('tool/reports/large-release425-pid.txt').read_text().strip().isdigit()
PY
