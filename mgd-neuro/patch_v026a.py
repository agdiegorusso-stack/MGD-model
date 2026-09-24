from pathlib import Path
import sys
root=Path(sys.argv[1])

# -----------------------------------------------------------------------------
# MGD 0.26 persistent graph store: SQLite WAL + compact binary snapshots.
# JSON remains only as a one-time legacy migration format.
# -----------------------------------------------------------------------------
store = r'''import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class _Writer26 {
  final BytesBuilder out = BytesBuilder(copy: false);
  void b(int x) => out.addByte(x);
  void u32(int x) {
    final d = ByteData(4)..setUint32(0, x, Endian.little);
    out.add(d.buffer.asUint8List());
  }
  void i64(int x) {
    final d = ByteData(8)..setInt64(0, x, Endian.little);
    out.add(d.buffer.asUint8List());
  }
  void f64(double x) {
    final d = ByteData(8)..setFloat64(0, x, Endian.little);
    out.add(d.buffer.asUint8List());
  }
  void str(String s) {
    final bytes = utf8.encode(s);
    u32(bytes.length);
    out.add(bytes);
  }
  void value(dynamic v) {
    if (v == null) { b(0); return; }
    if (v is bool) { b(v ? 2 : 1); return; }
    if (v is int) { b(3); i64(v); return; }
    if (v is double) { b(4); f64(v); return; }
    if (v is num) { b(4); f64(v.toDouble()); return; }
    if (v is String) { b(5); str(v); return; }
    if (v is List) {
      b(6); u32(v.length);
      for (final x in v) value(x);
      return;
    }
    if (v is Map) {
      b(7); u32(v.length);
      for (final e in v.entries) { str(e.key.toString()); value(e.value); }
      return;
    }
    b(5); str(v.toString());
  }
}

class _Reader26 {
  final Uint8List bytes;
  late final ByteData data = ByteData.sublistView(bytes);
  int p = 0;
  _Reader26(this.bytes);
  int b() => bytes[p++];
  int u32() { final x=data.getUint32(p,Endian.little); p+=4; return x; }
  int i64() { final x=data.getInt64(p,Endian.little); p+=8; return x; }
  double f64() { final x=data.getFloat64(p,Endian.little); p+=8; return x; }
  String str() { final n=u32(); final s=utf8.decode(bytes.sublist(p,p+n)); p+=n; return s; }
  dynamic value() {
    switch (b()) {
      case 0: return null;
      case 1: return false;
      case 2: return true;
      case 3: return i64();
      case 4: return f64();
      case 5: return str();
      case 6:
        final n=u32(); return List<dynamic>.generate(n,(_)=>value(),growable:false);
      case 7:
        final n=u32(); final m=<String,dynamic>{};
        for(var i=0;i<n;i++){ final k=str(); m[k]=value(); }
        return m;
      default: throw const FormatException('MGD binary tag non valido');
    }
  }
}

Uint8List _encodeSnapshot26(Map<String,dynamic> map) {
  final w=_Writer26();
  w.out.add(const [0x4d,0x47,0x44,0x32,0x36,0x01]);
  w.value(map);
  return w.out.takeBytes();
}

Map<String,dynamic> _decodeSnapshot26(Uint8List bytes) {
  if(bytes.length<6 || bytes[0]!=0x4d || bytes[1]!=0x47 || bytes[2]!=0x44 || bytes[3]!=0x32 || bytes[4]!=0x36){
    throw const FormatException('Snapshot MGD26 non valido');
  }
  final redacted_base64_due_to_length_limit=true;
  // This placeholder is not part of the real file.
  throw UnimplementedError();
}
