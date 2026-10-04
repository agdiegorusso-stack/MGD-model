#!/usr/bin/env python3
import base64, hashlib, json, lzma, sys
from pathlib import Path

EXPECTED = '57d13ae5add381ab8c956fa402748e04711115129353d2391facb581b6d79b79'

def sha(b): return hashlib.sha256(b).hexdigest()

def replace_once(text, old, new, label):
    if new in text:
        return text
    if old not in text:
        raise ValueError(f'0.40 materialize anchor missing: {label}')
    return text.replace(old, new, 1)

def main():
    here=Path(__file__).resolve().parent
    root=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else here.parents[1]/'mgd-neuro-app'
    b64=''.join((here/f'payload.{i:02d}').read_text().strip() for i in range(3))
    raw=lzma.decompress(base64.b64decode(b64,validate=True))
    if sha(raw)!=EXPECTED: raise ValueError('0.40 payload digest mismatch')
    payload=json.loads(raw)
    for entry in payload['files']:
        rel=Path(entry['path'])
        if rel.is_absolute() or '..' in rel.parts or rel.parts[0] not in {'lib','test','integration_test'}:
            raise ValueError(f'unsafe path {rel}')
        data=entry['text'].encode()
        if sha(data)!=entry['after']: raise ValueError(f'after digest mismatch {rel}')
        target=root/rel
        if target.exists() and sha(target.read_bytes())!=entry['after']:
            raise ValueError(f'unexpected existing 0.40 file {rel}')
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(data)

    p=root/'lib/main.dart'
    s=p.read_text()
    s=replace_once(s,"import 'closed_book_page_v0350.dart';","import 'closed_book_page_v0350.dart';\nimport 'cognitive_core_v0400.dart';\nimport 'cognitive_core_page_v0400.dart';",'imports')
    s=replace_once(s,"    ClosedBookBridge350.close();","    ClosedBookBridge350.close();\n    unawaited(CognitiveCoreBridge400.close());",'dispose')
    s=replace_once(s,"      await ClsBridge340.observeText(text, source: 'Chat utente');\n      _language20.ingestText(text, reward: 0.38);","      final cognitiveReply400 = await CognitiveCoreBridge400.processChat(text);\n      await ClsBridge340.observeText(text, source: 'Chat utente');\n      _language20.ingestText(text, reward: 0.38);",'chat observe')
    s=replace_once(s,"      final semanticAnswer =\n          sourced317 ?? episodic340 ?? grounded ?? languageAnswer;","      final semanticAnswer =\n          sourced317 ?? cognitiveReply400 ?? episodic340 ?? grounded ?? languageAnswer;",'semantic')
    s=replace_once(s,"    await ClsBridge340.clear();","    await ClsBridge340.clear();\n    await CognitiveCoreBridge400.reset();",'reset')
    s=s.replace("Nuova memoria MGD 0.35.2 creata","Nuova memoria MGD 0.40.0 creata")
    button="""                  FilledButton.tonalIcon(
                    key: const ValueKey('closed-open350'),
                    onPressed: busy ? null : onLanguage20,
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Impara / esplora lingua'),
                  ),"""
    button_new=button+"""
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    key: const ValueKey('cognitive-open400'),
                    onPressed: busy ? null : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CognitiveCorePage400())),
                    icon: const Icon(Icons.psychology_alt_outlined),
                    label: const Text('Cognitive Core 0.40'),
                  ),"""
    s=replace_once(s,button,button_new,'button')
    p.write_text(s)

    p=root/'lib/memory_runtime_v0319.dart'
    s=p.read_text().replace("const mgdAppVersion319 = '0.35.2';","const mgdAppVersion319 = '0.40.0';")
    p.write_text(s)
    p=root/'pubspec.yaml'
    s=p.read_text().replace('version: 0.35.2+71','version: 0.40.0+80')
    p.write_text(s)
    print('MGD Cognitive Core 0.40.0 materialized')

if __name__=='__main__':
    main()
