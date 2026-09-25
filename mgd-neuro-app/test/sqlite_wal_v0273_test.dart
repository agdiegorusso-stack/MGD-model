import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WAL pragma uses rawQuery on Android/sqflite', () {
    final source = File('lib/mgd_state_store_v026.dart').readAsStringSync();
    expect(source, contains("rawQuery('PRAGMA journal_mode=WAL')"));
    expect(source, isNot(contains("execute('PRAGMA journal_mode=WAL')")));
  });
}
