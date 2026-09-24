from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')

# Android SQLite fix: PRAGMA journal_mode=WAL returns a row.
# sqflite/Android rejects it through execute()/execSQL(), so use rawQuery().
p = root / 'lib' / 'mgd_state_store_v026.dart'
s = p.read_text()

old = """      onConfigure:(db) async{
        await db.execute('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA synchronous=NORMAL');
        await db.execute('PRAGMA temp_store=MEMORY');
        await db.execute('PRAGMA foreign_keys=ON');
      },
"""

new = """      onConfigure:(db) async{
        // IMPORTANT on Android: journal_mode is a row-returning PRAGMA.
        // execute()/execSQL() throws:
        // "Queries can be performed using SQLiteDatabase query or rawQuery methods only."
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA synchronous=NORMAL');
        await db.execute('PRAGMA temp_store=MEMORY');
        await db.execute('PRAGMA foreign_keys=ON');
      },
"""

if old not in s:
    raise SystemExit('SQLite onConfigure anchor missing')
s = s.replace(old, new, 1)

# Make failed opens fully retryable and never keep a stale db handle.
old = """  Future<Database> _open(){
    final ready=_db;
    if(ready!=null)return Future.value(ready);
    return _opening??=_openInner().whenComplete(()=>_opening=null);
  }
"""
new = """  Future<Database> _open(){
    final ready=_db;
    if(ready!=null && ready.isOpen)return Future.value(ready);
    _db=null;
    return _opening??=_openInner().whenComplete(()=>_opening=null);
  }
"""
if old not in s:
    raise SystemExit('SQLite _open anchor missing')
s = s.replace(old, new, 1)
p.write_text(s)

# Version and visible build identity.
p = root / 'lib' / 'main.dart'
s = p.read_text()
s = s.replace("MGD Neuro 0.27.2", "MGD Neuro 0.27.3")
p.write_text(s)

p = root / 'pubspec.yaml'
s = p.read_text()
if 'version: 0.27.2+44' not in s:
    raise SystemExit('pubspec 0.27.2 version anchor missing')
s = s.replace('version: 0.27.2+44', 'version: 0.27.3+45', 1)
p.write_text(s)

# Regression guard: ensure the Android-incompatible execute() form never returns.
p = root / 'test' / 'sqlite_wal_v0273_test.dart'
p.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WAL pragma uses rawQuery on Android/sqflite', () {
    final source = File('lib/mgd_state_store_v026.dart').readAsStringSync();
    expect(source, contains("rawQuery('PRAGMA journal_mode=WAL')"));
    expect(source, isNot(contains("execute('PRAGMA journal_mode=WAL')")));
  });
}
""")

print('MGD Neuro 0.27.3 Android SQLite WAL fix applied')
