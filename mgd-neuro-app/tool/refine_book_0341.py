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
    final dir = await Directory.systemTemp.createTemp('mgd-language-widget-');
    const pathChannel=MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathChannel, (_) async => dir.path);
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel,null);
      await dir.delete(recursive:true);
    });''',1)
    s=s.replace('                onSave: () async {','''                onModels341:(models)=>learned=models,
                checkpoint341:(_) async {},
                onSave: () async {''',1)
    s=s.replace('n < 100 && saved == 0','n < 400 && learned == null',1)
    s=s.replace('    expect(l.sentences, 1);','''    expect(learned,isNotNull);
    expect(learned!.language.sentences, 1);''',1)
    s=s.replace("ResearchSemantics317.answer('Cosa produce il zorvello?', m),\n        contains('lumina'));\n    await tester.scrollUntilVisible", "ResearchSemantics317.answer('Cosa produce il zorvello?', learned!.research),\n        contains('lumina'));\n    await tester.scrollUntilVisible",1)
    p.write_text(s)
print('Book model bindings and widget-test dependencies refined')
