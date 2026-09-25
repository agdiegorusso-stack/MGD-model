from pathlib import Path
import sys
root=Path(sys.argv[1])
p=root/'lib/main.dart';s=p.read_text()
def edit(old,new):
 global s
 assert old in s,old[:120]
 s=s.replace(old,new,1)
edit('  Future<void> _saveAllSilent22() async {', '  Future<void> _saveAllSilent22() async {\n    if(_bootError318!=null||!_ready)return;')
edit('if (_autoSaveInFlight17 || !_ready) return;', 'if (_autoSaveInFlight17 || !_ready || _bootError318!=null) return;')
edit('    if (!_ready) return;\n    if (state == AppLifecycleState.paused', '    if (!_ready || _bootError318!=null) return;\n    if (state == AppLifecycleState.paused')
edit('  Future<void> _save([String? label]) async {', '  Future<void> _save([String? label]) async {\n    if(_bootError318!=null||!_ready)return;')
edit('    if (!_ready || _researchBusy || _maintenance317 || !_researchMemory.enabled) return;', '    if (!_ready || _bootError318!=null || _researchBusy || _maintenance317 || !_researchMemory.enabled) return;')
p.write_text(s)
p=root/'test/research_v0318_test.dart';s=p.read_text();old="    expect(s.substring(catchStart,end),isNot(contains('_startMindTimer19();')));";assert old in s
s=s.replace(old,old+"\n    final lifecycle=s.substring(s.indexOf('  void didChangeAppLifecycleState'),s.indexOf('  Future<void> _save([String? label]'));\n    expect(lifecycle,contains('if (!_ready || _bootError318!=null) return;'));",1);p.write_text(s)
