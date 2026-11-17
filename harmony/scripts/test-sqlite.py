"""Host SQLite integration against actual emitted SQL and DDL; not a Harmony runtime test.
Usage: python3 harmony/scripts/test-sqlite.py <Windows-node-under-WSL> <Windows-typescript-path>
"""
import json
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fixtures = json.loads(subprocess.check_output([sys.argv[1], 'scripts/query-fixtures.cjs', sys.argv[2]], text=True, cwd=root))
source = (root / 'entry/src/main/ets/database/SchemaMigrations.ets').read_text()
db = sqlite3.connect(':memory:')
db.execute('PRAGMA foreign_keys=ON')
# SQL literals from production schema, including all v1/v2 indexes and columns.
for literal in re.findall(r"executeSql\(('(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\")\)", source):
    sql = literal[1:-1].replace("\\'", "'")
    if sql.startswith(('CREATE ', 'ALTER ')):
        db.execute(sql)
db.execute("INSERT INTO accounts VALUES ('a','{}','现金')")
db.execute("INSERT INTO categories VALUES ('c','{}','餐饮')")
needle = "100%_' OR 1=1"
for i in range(10000):
    key = f'e{i:05d}'
    payload = json.dumps({'id': key})
    db.execute('INSERT INTO entries VALUES (?,?,?,?,?,?,?,?,?)', (key, 'a', 'c', '2026-11-17', '12:00', 1 if i % 2 else 2, 'expense', payload, needle if i == 0 else ''))
db.commit()
first = fixtures[0]
assert len(db.execute(first['page']['sql'], first['page']['args']).fetchall()) == 51
assert db.execute(first['totals']['sql'], first['totals']['args']).fetchone() == (0, 15000, 10000)
assert db.execute(first['daily']['sql'], first['daily']['args']).fetchone() == ('2026-11-17', 0, 15000, 10000)
for index in [0, 1, 2]:
    q = fixtures[index]['page']
    plan = str(db.execute('EXPLAIN QUERY PLAN ' + q['sql'], q['args']).fetchall())
    assert 'USE TEMP B-TREE FOR ORDER BY' not in plan, plan
    expected = ['entry_order', 'entry_account_type_order', 'entry_category_type_order'][index]
    assert expected in plan, plan
    print('INDEX:', expected)
q = fixtures[3]
assert db.execute(q['totals']['sql'], q['totals']['args']).fetchone()[2] == 1
q = fixtures[4]
assert db.execute(q['totals']['sql'], q['totals']['args']).fetchone() == (0, 10000, 5000)
# 200 pages with exclusive tuple cursor, tied date/time, no OFFSET.
seen = set()
q = first['page']
sql, args = q['sql'], q['args']
while True:
    rows = db.execute(sql, args).fetchall()
    more = len(rows) > 50
    page = [json.loads(row[0])['id'] for row in rows[:50]]
    assert not seen.intersection(page)
    seen.update(page)
    if not more:
        break
    sql = fixtures[5]['page']['sql']
    args = ['2026-11-17', '12:00', page[-1], 51]
assert len(seen) == 10000
# New writes are incremental, foreign-key-safe UPSERT rather than REPLACE.
repo = (root / 'entry/src/main/ets/repository/LedgerRepository.ets').read_text()
upserts = re.findall(r"executeSql\('(INSERT INTO accounts[^']+ON CONFLICT[^']+)'", repo)
assert len(upserts) == 1
before = db.total_changes
db.execute(upserts[0], ['a', '{}', '改名'])
assert db.total_changes - before == 1
assert db.execute('SELECT COUNT(*) FROM entries').fetchone()[0] == 10000
# Rollback of actual incremental entry update restores searchable field and envelope together.
entry_upsert = re.findall(r"executeSql\('(INSERT INTO entries[^']+ON CONFLICT[^']+)'", repo)[0]
db.commit()
db.execute('BEGIN')
db.execute(entry_upsert, ['e00000', 'a', 'c', '2026-11-18', '13:00', 5, 'income', '{"id":"edited"}', 'edit'])
db.rollback()
assert db.execute("SELECT date,amount,note FROM entries WHERE id='e00000'").fetchone() == ('2026-11-17', 2, needle)
print('PASS: production SQL, v2 DDL, 10000-row pagination, aggregates, literal search, index plans, incremental UPSERT and rollback')
