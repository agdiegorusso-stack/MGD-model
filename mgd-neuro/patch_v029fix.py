from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'test' / 'grounded_world_v07_test.dart'
s = p.read_text()

old_image = "final visual = world.observeVisionBytes(Uint8List.fromList(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WlG7NsAAAAASUVORK5CYII=')));"
new_image = "final visual = world.observeVisionBytes(imageBytes(180, 90, 70));"
if old_image not in s:
    raise SystemExit('0.29 multimodal test image anchor missing')
s = s.replace(old_image, new_image, 1)

old_audio = "List<int>.filled(640, 8)"
new_audio = "List<int>.filled(1600, 8)"
if old_audio not in s:
    raise SystemExit('0.29 multimodal test audio anchor missing')
s = s.replace(old_audio, new_audio, 1)

p.write_text(s)
print('MGD Neuro 0.29 multimodal regression fixtures fixed')
