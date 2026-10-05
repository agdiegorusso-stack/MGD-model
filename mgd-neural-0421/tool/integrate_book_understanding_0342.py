from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
def patch(path, marker, changes):
    p=root/path;s=p.read_text()
    if marker in s:return
    for old,new in changes:
        assert s.count(old)==1,(path,old[:100],s.count(old))
        s=s.replace(old,new,1)
    p.write_text('// '+marker+'\n'+s)
patch('lib/mgd_language_v020.dart','BOOK_LAB_WIRING_0342',[
    ("import 'book_import_v0341.dart';","import 'book_import_v0341.dart';\nimport 'book_lab_page_v0342.dart';"),
    ("                  const SizedBox(height: 16),\n                  TextField(\n                    controller: text,",'''                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    key: const ValueKey('book-lab-open'),
                    onPressed: busy || _recoveryBlocked341 ? null : () async {
                      setState(() => busy = true);
                      try {
                        await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => BookLabPage342(memory: _research341, onSave: widget.onSave)));
                      } finally { if (mounted) setState(() => busy = false); }
                    },
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Verifica del libro'),
                  ),
                  const Text('Interroga i passaggi, prova deduzioni e nuove situazioni, misura le risposte con riferimenti separati.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: text,'''),
])
patch('lib/main.dart','BOOK_CHAT_WIRING_0342',[
    ("import 'book_import_v0341.dart';","import 'book_import_v0341.dart';\nimport 'book_lab_service_v0342.dart';"),
    ("      await ClsBridge340.observeText(text, source: 'Chat utente');",'''      final bookReply342 = await BookLab342.chat(_researchMemory, text);
      if (bookReply342 != null) {
        final guarded = _brain.guardResponse331(text, bookReply342);
        if (!mounted) return;
        setState(() {
          _messages.add(ChatMessage04(user: false, text: guarded, prompt: text));
          _status = 'Risposta dal libro selezionato, con evidenze.';
        });
        _scrollDown();
        await _save('Domanda al libro completata; nessuna risposta appresa come nuova conoscenza');
        return;
      }
      await ClsBridge340.observeText(text, source: 'Chat utente');'''),
    ("  void dispose() {\n", "  void dispose() {\n    BookLab342.closeChat();\n"),
])
patch('lib/corpus_semantic_bridge_v022.dart','BOOK_SOURCE_IDENTITY_0342',[
    ("    bool inlineExtraction341 = false,","    bool inlineExtraction341 = false,\n    String? sourceUrl342,"),
    ("        url: 'local://corpus/$digest',","        url: sourceUrl342 ?? 'local://corpus/$digest',"),
])
patch('lib/book_import_v0341.dart','BOOK_SOURCE_IDENTITY_0342',[
    ("              inlineExtraction341: true);","              inlineExtraction341: true,\n              sourceUrl342: 'local://book/$identity/$blocks');"),
    ("'version': '0.34.1',","'version': '0.34.2',"),
])
patch('lib/knowledge_deletion_v0330.dart','BOOK_EXAM_DELETION_0342',[
    ("import 'cls_bridge_v0340.dart';","import 'cls_bridge_v0340.dart';\nimport 'book_lab_service_v0342.dart';"),
    ("    SourceMemory323.forget33(research, matches);",'''    SourceMemory323.forget33(research, matches);
    BookLab342.closeChat();
    final lab = research.state317['bookLab342'];
    if (lab is Map) {
      final tests = lab['cases'];
      if (tests is Map) {
        for (final value in tests.values) { if (value is List) value.removeWhere(deep); }
      }
      final reports = lab['reports'];
      if (reports is List) reports.removeWhere(deep);
    }'''),
])
p=root/'lib/book_lab_page_v0342.dart';s=p.read_text()
if "import 'dart:typed_data';" not in s:s=s.replace("import 'dart:convert';","import 'dart:convert';\nimport 'dart:typed_data';")
p.write_text(s)
p=root/'lib/memory_runtime_v0319.dart';s=p.read_text().replace("const mgdAppVersion319 = '0.34.1';","const mgdAppVersion319 = '0.34.2';");p.write_text(s)
p=root/'pubspec.yaml';s=p.read_text().replace('version: 0.34.1+67','version: 0.34.2+68');p.write_text(s)
print('Book reader, source identity, independent exams and explicit chat route integrated.')
