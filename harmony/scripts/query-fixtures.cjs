// Emits actual query-builder output for SQLite host integration (no substitute for device RdbStore).
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const cache = new Map();
function load(file) {
  file = path.resolve(file);
  if (cache.has(file)) return cache.get(file);
  const module = { exports: {} }; cache.set(file, module.exports);
  const js = ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText;
  vm.runInNewContext(js, { module, exports: module.exports, require: name => load(path.resolve(path.dirname(file), name + '.ets')), Date, Math, JSON, Number, Array, Error, Set, Map });
  return module.exports;
}
const { entryQueries } = load(path.join(__dirname, '../entry/src/main/ets/repository/EntryQuery.ets'));
const base = { type: null, accountIds: [], categoryIds: [], range: null, minAmountCents: null, maxAmountCents: null, keyword: '', cursor: null, pageSize: 50 };
const filters = [base,
  { ...base, accountIds: ['a'], type: 'expense' },
  { ...base, categoryIds: ['c'], type: 'expense' },
  { ...base, keyword: "100%_' OR 1=1" },
  { ...base, range: { startDate: '2026-11-17', endDate: '2026-11-17' }, minAmountCents: 2, maxAmountCents: 2 },
  { ...base, cursor: { date: '2026-11-17', time: '12:00', id: 'e09950' } }
];
console.log(JSON.stringify(filters.map(filter => entryQueries(filter))));
