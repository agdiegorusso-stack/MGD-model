#!/usr/bin/env bash
set -euo pipefail
bash tool/android_verify_421.sh
# A reused release can be signed by another CI machine's debug key. Start the
# test package fresh rather than asking Flutter to update an incompatible key.
if adb shell pm path it.diegorusso.mgdneurostable | grep -q '^package:'; then
  timeout 30 adb uninstall it.diegorusso.mgdneurostable
fi
mgd_export_fixture425() {
  local mgd_deadline425=$((SECONDS + 900))
  while (( SECONDS < mgd_deadline425 )); do
    if timeout 15 adb shell run-as it.diegorusso.mgdneurostable test -f cache/large-memory425-ready.txt >/dev/null 2>&1; then
      timeout 60 adb exec-out run-as it.diegorusso.mgdneurostable cat cache/large-memory425.db > /tmp/mgd-large-memory425.db
      timeout 15 adb exec-out run-as it.diegorusso.mgdneurostable cat cache/large-memory425.json > tool/reports/large-memory425.json
      timeout 15 adb exec-out run-as it.diegorusso.mgdneurostable cat cache/large-memory425-path.txt > tool/reports/large-memory425-path.txt
      python3 - <<'PY'
import json,sqlite3
from pathlib import Path
p=Path('/tmp/mgd-large-memory425.db')
with p.open('rb') as f: assert f.read(16)==b'SQLite format 3\x00'
records=json.loads(Path('tool/reports/large-memory425.json').read_text())
assert len(records)==2 and all(x['facts']==50000 for x in records)
db=sqlite3.connect(p)
assert db.execute('PRAGMA integrity_check').fetchone()==('ok',)
db.close()
PY
      timeout 15 adb shell run-as it.diegorusso.mgdneurostable touch cache/large-memory425-exported.txt
      return 0
    fi
    sleep 2
  done
  echo 'Test database was not made available for export.' >&2
  return 1
}
mgd_export_fixture425 &
mgd_export_pid425=$!
trap 'kill "$mgd_export_pid425" 2>/dev/null || true' EXIT
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
raise SystemExit(0 if any(x in s for x in ['Connecting to the VM Service timed out',
    'registerService: (-32000) Service connection disposed']) and
    '50000 saved facts:' not in s else 1)
PY
  then
    adb reconnect offline || true
    timeout 30 adb wait-for-device
    adb shell am force-stop it.diegorusso.mgdneurostable
    continue
  fi
  adb shell screencap -p > tool/reports/large-memory425-failure.png
  exit "$mgd_status"
done
wait "$mgd_export_pid425"
trap - EXIT
python3 - <<'PY'
import sqlite3, hashlib, json
from pathlib import Path
p=Path('/tmp/mgd-large-memory425.db')
db=sqlite3.connect(p)
assert db.execute('PRAGMA integrity_check').fetchone()==('ok',)
assert db.execute('SELECT COUNT(*) FROM snapshot_parts425').fetchone()[0]>250
assert db.execute("SELECT bytes FROM snapshot_manifests425 WHERE k='brain_v051'").fetchone()[0]>40000000
assert db.execute("SELECT bytes FROM snapshot_manifests425 WHERE k='language_v20'").fetchone()[0]>1000000
db.close()
target=Path('tool/reports/large-memory425-path.txt').read_text().strip()
assert target.startswith(('/data/user/0/it.diegorusso.mgdneurostable/',
    '/data/data/it.diegorusso.mgdneurostable/')) and target.endswith('/mgd_neuro_v026.db')
Path('tool/reports/large-db425.json').write_text(json.dumps({'bytes':p.stat().st_size,
    'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'target':target},indent=2))
PY
# Install the actual release, then restore the exact committed test database.
# adb root is available on this Google APIs emulator; the delivered app does
# not request root. A full process stop follows, with no test widgets running.
if adb shell pm path it.diegorusso.mgdneurostable | grep -q '^package:'; then
  timeout 30 adb uninstall it.diegorusso.mgdneurostable
fi
timeout 60 adb install build/app/outputs/flutter-apk/app-release.apk
adb shell am force-stop it.diegorusso.mgdneurostable
timeout 30 adb root
timeout 30 adb wait-for-device
mgd_db_target425="$(cat tool/reports/large-memory425-path.txt)"
mgd_uid425="$(adb shell cmd package list packages -U it.diegorusso.mgdneurostable | sed -n 's/.*uid:\([0-9]*\).*/\1/p' | tr -d '\r')"
[[ "$mgd_uid425" =~ ^[0-9]+$ ]]
timeout 15 adb shell mkdir -p "$(dirname "$mgd_db_target425")"
timeout 15 adb shell rm -f "${mgd_db_target425}-wal" "${mgd_db_target425}-shm"
timeout 60 adb push /tmp/mgd-large-memory425.db "$mgd_db_target425"
timeout 15 adb shell chown "${mgd_uid425}:${mgd_uid425}" "$mgd_db_target425"
timeout 15 adb shell chown "${mgd_uid425}:${mgd_uid425}" "$(dirname "$mgd_db_target425")"
timeout 15 adb shell chmod 600 "$mgd_db_target425"
timeout 15 adb shell restorecon "$mgd_db_target425"
adb shell am force-stop it.diegorusso.mgdneurostable
adb logcat -c
timeout 30 adb shell am start -W -n it.diegorusso.mgdneurostable/it.diegorusso.mgd_neuro_mobile.MainActivity \
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
