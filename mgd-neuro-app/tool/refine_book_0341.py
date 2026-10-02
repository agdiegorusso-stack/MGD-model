"""Keep inspector on adopted worker models; retain UI regression coverage."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'lib/mgd_language_v020.dart'
s=p.read_text()
if 'BOOK_IMPORT_BINDINGS_0341' not in s:
    s='// BOOK_IMPORT_BINDINGS_0341\n'+s
    s=s.replace("import 'dart:io';","import 'dart:io';\nimport 'dart:typed_data';",1)
    s=s.replace('class MgdLanguageLab20 extends StatefulWidget {','''class MgdLanguageLab20 extends StatefulWidget {
  final Future<void> Function(Map<String, Uint8List>)? checkpoint341;''',1)
    s=s.replace('    this.onModels341,','    this.onModels341,\n    this.checkpoint341,',1)
    s=s.replace('checkpoint:MgdStateStore26.instance.putEncodedAtomic341,','checkpoint:widget.checkpoint341 ?? MgdStateStore26.instance.putEncodedAtomic341,',1)
    a=s.index('class _MgdLanguageLab20State')
    b=s.index('class _LMetric20',a)
    part=s[a:b]
    part=part.replace('return PopScope(','''return InspectorScope315(
        inspector: MemoryInspector315(brain:_models341?.brain ?? widget.brain,
          world:_models341?.world ?? widget.world,research:_research341,
          language:_language341),
        child: PopScope(''',1)
    anchor='''        ));
  }
}

'''
    assert part.count(anchor)==1
    part=part.replace(anchor,'''        )));
  }
}

''',1)
    s=s[:a]+part+s[b:]
    p.write_text(s)
p=root/'test/product_v0321_test.dart';s=p.read_text()
if 'BOOK_IMPORT_BINDINGS_0341' not in s:
    s='// BOOK_IMPORT_BINDINGS_0341\n'+s
    s=s.replace("import 'dart:convert';","""import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../lib/book_import_v0341.dart';""",1)
    s=s.replace('    var saved = 0;','''    var saved = 0;
    BookModels341? learned;
    final dir = Directory.systemTemp.createTempSync('mgd-language-widget-');
    const pathChannel=MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathChannel, (_) async => dir.path);
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel,null);
      dir.deleteSync(recursive:true);
    });''',1)
    s=s.replace('                onSave: () async {','''                onModels341:(models)=>learned=models,
                checkpoint341:(_) async {},
                onSave: () async {''',1)
    s=s.replace('n < 100 && saved == 0','n < 400 && learned == null',1)
    s=s.replace('    expect(l.sentences, 1);','''    expect(learned,isNotNull);
    expect(learned!.language.sentences, 1);''',1)
    s=s.replace("ResearchSemantics317.answer('Cosa produce il zorvello?', m),\n        contains('lumina'));\n    await tester.scrollUntilVisible", "ResearchSemantics317.answer('Cosa produce il zorvello?', learned!.research),\n        contains('lumina'));\n    await tester.scrollUntilVisible",1)
# Real filesystem setup cannot await an I/O event in testWidgets' FakeAsync.
s=s.replace("await Directory.systemTemp.createTemp('mgd-language-widget-')", "Directory.systemTemp.createTempSync('mgd-language-widget-')")
s=s.replace('await dir.delete(recursive: true);','dir.deleteSync(recursive: true);')
s=s.replace('await dir.delete(recursive:true);','dir.deleteSync(recursive:true);')
if 'BOOK_WIDGET_FINAL_IO_341' not in s:
    marker="        await Future<void>.delayed(const Duration(milliseconds: 20));\n      }\n    });\n    await tester.pumpAndSettle();"
    if marker in s:
        s=s.replace(marker,"        await Future<void>.delayed(const Duration(milliseconds: 20));\n      }\n      // BOOK_WIDGET_FINAL_IO_341: drain staging-file cleanup in the real zone.\n      await Future<void>.delayed(const Duration(milliseconds: 100));\n    });\n    await tester.pumpAndSettle();",1)
p.write_text(s)
print('Book model bindings and widget-test dependencies refined')

# The old Android test must observe persisted knowledge, not an obsolete status.
p=root/'integration_test/runtime_android_v0319_test.dart';s=p.read_text()
if 'BOOK_ANDROID_ASSERTIONS_341' not in s:
    s=s.replace("textContaining('nuove utilizzabili con fonte')", "textContaining('Libro elaborato e salvato')",1)
    old="""    expect(
        find.textContaining('2 nuove utilizzabili con fonte'), findsOneWidget);"""
    new="""    // BOOK_ANDROID_ASSERTIONS_341: preserve and strengthen the data assertions.
    expect(find.textContaining('Libro elaborato e salvato'), findsOneWidget,
        reason: tester.widgetList<Text>(find.byType(Text)).map((t)=>t.data).join(' | '));
    final learned341 = tester.widgetList<InspectorScope315>(
        find.byType(InspectorScope315)).last.inspector;
    expect(learned341.language.sentences, 2);
    expect(learned341.metricRows('Documentate').length, 2);"""
    assert old in s, 'Android import status assertion anchor missing'
    s=s.replace(old,new,1);p.write_text(s)

# If disk recovery itself fails, do not permit another import to overwrite it.
p=root/'lib/mgd_language_v020.dart';s=p.read_text()
if 'BOOK_RECOVERY_GUARD_341' not in s:
    s='// BOOK_RECOVERY_GUARD_341\n'+s
    assert 'bool _cancel341 = false;' in s
    s=s.replace('bool _cancel341 = false;', 'bool _cancel341 = false;\n  bool _recoveryBlocked341 = false;',1)
    a=s.index('Future<void> _import341(')
    b=s.index('Future<void> train(',a)
    part=s[a:b]
    assert 'if (busy) return;' in part and 'restoreFailed = true;' in part
    part=part.replace('if (busy) return;', 'if (busy || _recoveryBlocked341) return;',1)
    part=part.replace('restoreFailed = true;', 'restoreFailed = true;\n          _recoveryBlocked341 = true;',1)
    s=s[:a]+part+s[b:]
    s=s.replace('busy || text.text.trim().isEmpty', 'busy || _recoveryBlocked341 || text.text.trim().isEmpty',1)
    s=s.replace('onPressed: busy ? null : pick', 'onPressed: busy || _recoveryBlocked341 ? null : pick',1)
    s=s.replace('Importa e impara libro/corpus è un’azione completa:', 'Questo percorso legge file TXT; non estrae PDF o EPUB. Importa e impara libro/corpus è un’azione completa:',1)
    p.write_text(s)
p=root/'lib/main.dart';s=p.read_text()
if 'BOOK_RECOVERY_GUARD_341' not in s:
    old='  Future<void> _openLanguage20() async {\n'
    assert old in s
    s=s.replace(old,old+"""    // BOOK_RECOVERY_GUARD_341
    if (_bootError318 != null || _bookImportBusy341) {
      if (mounted) setState(() => _status =
          'Memoria protetta: riapri l’app per completare il recupero prima di importare. Non cancellare i dati.');
      return;
    }
""",1)
    p.write_text(s)
