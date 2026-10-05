#!/usr/bin/env python3
"""Offline structural and SQLite checks. This is NOT a Dart compiler/test run."""
import ast
import json
import math
from pathlib import Path
import random
import re
import shutil
import sqlite3
import time

ROOT = Path(__file__).resolve().parents[1]
checks = []

def check(name, f):
    f()
    checks.append({"name": name, "passed": True})

def dart_balanced(text):
    """Check lexical delimiters, including nested ${} in Dart strings."""
    def code(pos=0, interpolation=False):
        stack = []
        while pos < len(text):
            if text.startswith('//', pos):
                end = text.find('\n', pos)
                pos = len(text) if end < 0 else end + 1
                continue
            if text.startswith('/*', pos):
                depth = 1; pos += 2
                while depth and pos < len(text):
                    if text.startswith('/*', pos): depth += 1; pos += 2
                    elif text.startswith('*/', pos): depth -= 1; pos += 2
                    else: pos += 1
                assert depth == 0, 'unclosed comment'
                continue
            c = text[pos]
            raw = c == 'r' and pos + 1 < len(text) and text[pos + 1] in "'\""
            if raw or c in "'\"":
                if raw: pos += 1
                quote = text[pos]
                marker = quote * 3 if text.startswith(quote * 3, pos) else quote
                pos += len(marker)
                while pos < len(text):
                    if not raw and text.startswith('${', pos):
                        pos = code(pos + 2, True)
                    elif not raw and text[pos] == '\\': pos += 2
                    elif text.startswith(marker, pos): pos += len(marker); break
                    else: pos += 1
                else: raise AssertionError('unclosed string')
                continue
            if c in '([{': stack.append(c)
            elif c in ')]}':
                if c == '}' and interpolation and not stack: return pos + 1
                assert stack and {'(': ')', '[': ']', '{': '}'}[stack.pop()] == c, f'delimiter near {pos}'
            pos += 1
        assert not stack and not interpolation, 'unclosed delimiter'
        return pos
    code()

def structure():
    dart_files = list(ROOT.rglob('*.dart'))
    for path in dart_files:
        text = path.read_text()
        try: dart_balanced(text)
        except AssertionError as e: raise AssertionError(f'{path.relative_to(ROOT)}: {e}')
        for imported in re.findall(r"(?:import|export|part)\s+'([^']+)'", text):
            if not imported.startswith(('dart:', 'package:')):
                assert (path.parent / imported).exists(), f'unresolved import: {imported}'
            elif imported.startswith('package:mgd_neuro_mobile/'):
                assert (ROOT / 'lib' / imported.split('/', 1)[1]).exists(), imported
    main = (ROOT / 'lib/main.dart').read_text()
    for banned in ['DialogueBridge410', '_brain.respond', 'BookLab342', 'Timer.periodic', 'canonical_migration']:
        assert banned not in main, banned
    assert 'coordinator!.process(input' in main
    for removed in ['cognitive_core_v0400.dart', 'source_memory_v0323.dart',
                    'memory_runtime_v0319.dart', 'plastic_language_brain_v04.dart',
                    'legacy_main_0410.dart', 'canonical_migration_v0420.dart']:
        assert not (ROOT / 'lib' / removed).exists(), removed

def schema_sql():
    source = (ROOT / 'lib/canonical_memory_v0420.dart').read_text()
    block = source.split('static const schema = <String>[', 1)[1].split('  ];', 1)[0]
    result = [ast.literal_eval(line.strip().rstrip(',')) for line in block.splitlines() if line.strip()]
    social = (ROOT / 'lib/social_memory_v0420.dart').read_text()
    result += [ast.literal_eval(match) for match in re.findall(r"await db.execute\(('(?:\\.|[^'\\])*')\)", social)]
    return result

def newdb():
    db = sqlite3.connect(':memory:')
    db.execute('PRAGMA foreign_keys=ON')
    for sql in schema_sql(): db.execute(sql)
    return db

def seed(db):
    db.execute('INSERT INTO sources(id,title,kind,family,created) VALUES(?,?,?,?,?)', ('s', 'Fonte', 'text', 'user', 1))
    db.execute('INSERT INTO passages VALUES(?,?,?,?,?,?,?,?,?)', ('u', 's', 0, 'h', 'La capsula contiene quarzo.', 1, '{}', 0, 1))

def insert_claim(db, id='c', unit='u', obj='quarzo'):
    db.execute('INSERT INTO claims(id,unit,source,subject,predicate,object,location,target,negative,universal,kind,epistemic,payload) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)',
               (id, unit, 's', 'capsula', 'contiene', obj, '', '', 0, 0, 'fact', 'asserted', '{}'))
    db.execute('INSERT INTO edges VALUES(?,?,?,?,?,?,?)', (id, .8, .1, .2, .1, .01, 1))
    db.execute('INSERT INTO claim_terms VALUES(?,?)', ('capsula', id))

def sqlite_integrity():
    db = newdb(); seed(db); insert_claim(db)
    db.execute('INSERT INTO usage VALUES(?,?,?,?)', ('u', 'predicates', 'contiene', 1))
    db.commit()
    # FK enforcement rejects orphan evidence and leaves the archive unchanged.
    try:
        with db: insert_claim(db, 'orphan', 'missing')
    except sqlite3.IntegrityError: pass
    else: raise AssertionError('orphan accepted')
    assert db.execute('SELECT COUNT(*) FROM claims').fetchone()[0] == 1
    # Revocation rolls back if a later part of the same correction fails.
    try:
        with db:
            db.execute('UPDATE claims SET status="superseded" WHERE id="c"')
            insert_claim(db, 'new', 'missing', 'ferro')
    except sqlite3.IntegrityError: pass
    assert db.execute('SELECT status FROM claims WHERE id="c"').fetchone()[0] == 'asserted'
    with db:
        db.execute('UPDATE claims SET status="superseded" WHERE id="c"')
        insert_claim(db, 'new', 'u', 'ferro')
    assert db.execute('SELECT object FROM claims WHERE status="asserted"').fetchall() == [('ferro',)]
    assert db.execute('SELECT text FROM passages WHERE id="u"').fetchone()[0].endswith('quarzo.')
    with db: db.execute('DELETE FROM sources WHERE id="s"')
    for table in ['passages', 'claims', 'edges', 'claim_terms', 'usage']:
        assert db.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0] == 0
    assert not db.execute('PRAGMA foreign_key_check').fetchall()

def sqlite_query_plans():
    db = newdb(); seed(db); insert_claim(db)
    queries = [
      ('SELECT c.* FROM claim_terms t JOIN claims c ON c.id=t.claim WHERE t.term=?', ('capsula',)),
      ('SELECT c.* FROM claims c WHERE c.subject=? AND c.predicate=? AND c.status="asserted"', ('capsula', 'contiene')),
      ('SELECT * FROM claims WHERE source=? AND status="asserted"', ('s',))]
    for sql, args in queries:
        plan = ' '.join(str(row) for row in db.execute('EXPLAIN QUERY PLAN '+sql, args))
        assert 'INDEX' in plan, plan

def material_root(chi):
    a=.06; b=(1-.92)-.06; c=(1-.92)*chi
    return (2*c/(b+math.sqrt(b*b+4*a*c))) if c else 0.

def reference_step(w,m,material,chi_avg,activation,reward):
    negative=max(0,-reward)
    nm=.86*m+.14*activation*(0 if negative else 1)
    chi=1 if w<=1 else 0
    nc=.97*chi_avg+.03*chi
    nmat=min(1,max(0,.92*material+.08*chi+.06*material*(1-material)))
    mstar=material_root(nc)
    delta=.0045+.065*negative if negative else .0045-.055*activation*(.65+.35*max(0,reward))-.035*nm+.018*(nmat-mstar)
    return min(3.6,max(.05,w+delta)), min(1.5,max(0,nm)), nmat,nc

def math_reference():
    # Explicit reference port, not execution of MgdMath09 Dart.
    random.seed(420)
    for chi in [0,.01,.25,.5,.75,1]:
        root=material_root(chi)
        assert abs(root-(.92*root+.08*chi+.06*root*(1-root))) < 1e-12
    w,m,material,avg=.95,0,0,0
    for _ in range(5000):
        a=random.random(); reward=random.choice([-1,0,1])
        w,m,material,avg=reference_step(w,m,material,avg,a,reward)
        assert .05<=w<=3.6 and 0<=m<=1.5 and 0<=material<=1 and 0<=avg<=1
    w,m,material,avg=.95,0,0,0
    for _ in range(100):
        w,m,material,avg=reference_step(w,m,material,avg,1/(1+4*material),0)
    assert material>.7 and w<=1

check('Dart lexical delimiters and local imports (not type checking)', structure)
check('SQLite schema, FK integrity, correction rollback and cascades', sqlite_integrity)
check('SQLite lookup query plans use indices', sqlite_query_plans)
check('Python reference: material fixed points and bounded local dynamics', math_reference)

report = {
  'version': '0.42.0', 'at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
  'checks': checks,
  'flutter_available': bool(shutil.which('flutter')),
  'dart_available': bool(shutil.which('dart')),
  'flutter_tests': 'not_run', 'dart_analyzer': 'not_run', 'apk_build': 'not_run',
  'limitations': 'Offline structural/SQLite/reference checks do not establish that the Dart program compiles or that the Flutter tests pass.'
}
out = ROOT / 'tool/reports/offline_checks.json'
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
