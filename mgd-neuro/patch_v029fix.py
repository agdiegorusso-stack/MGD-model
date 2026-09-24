from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'test' / 'grounded_world_v07_test.dart'
s = p.read_text()
old = "final visual = world.observeVisionBytes(Uint8List.fromList(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WlG7NsAAAAASUVORK5CYII=')));"
new = "final visual = world.observeVisionBytes(imageBytes(180, 90, 70));"
if old not in s:
    raise SystemExit('0.29 multimodal test image anchor missing')
s = s.replace(old, new, 1)
p.write_text(s)
print('MGD Neuro 0.29 multimodal test image fix applied')
