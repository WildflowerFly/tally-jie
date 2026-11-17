// Execute the platform-independent Hypium suite with Node, without installing dependencies.
// Usage: node scripts/test-domain.cjs <path-to-typescript/lib/typescript.js>
// This tests domain logic, not ArkUI rendering or HarmonyOS filesystem/picker APIs.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const ts = require(path.resolve(process.argv[2]));
const root = path.resolve(__dirname, '..');
let count = 0;
const hypium = {
  describe: (name, run) => { console.log(name); run(); },
  it: (name, _flags, run) => { run(); count++; console.log(`  PASS ${name}`); },
  expect: value => ({
    assertEqual: expected => assert.equal(value, expected),
    assertTrue: () => assert.equal(value, true),
    assertFalse: () => assert.equal(value, false)
  })
};
function load(relative, dependencies) {
  const filename = path.join(root, relative);
  const source = fs.readFileSync(filename, 'utf8');
  const result = ts.transpileModule(source, {
    fileName: filename.replace(/\.ets$/, '.ts'),
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  });
  const module = { exports: {} };
  vm.runInNewContext(result.outputText, {
    exports: module.exports, module,
    require: name => {
      if (!(name in dependencies)) throw new Error(`Unexpected import: ${name}`);
      return dependencies[name];
    }, console, Date, Math, JSON, Number, Array, Error
  }, { filename });
  return module.exports;
}
const models = load('entry/src/main/ets/model/LedgerModels.ets', {});
const money = load('entry/src/main/ets/domain/Money.ets', { '../model/LedgerModels': models });
const dates = load('entry/src/main/ets/domain/DateRange.ets', { '../model/LedgerModels': models });
const rules = load('entry/src/main/ets/domain/LedgerRules.ets', {
  '../model/LedgerModels': models, './Money': money, './DateRange': dates
});
const domain = load('entry/src/main/ets/model/AppData.ets', {
  './LedgerModels': models, '../domain/Money': money, '../domain/DateRange': dates,
  '../domain/LedgerRules': rules
});
load('entry/src/test/LocalUnit.test.ets', {
  '@ohos/hypium': hypium,
  '../main/ets/model/AppData': domain
}).default();
load('entry/src/test/LedgerDomain.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/model/LedgerModels': models,
  '../main/ets/domain/Money': money, '../main/ets/domain/DateRange': dates,
  '../main/ets/domain/LedgerRules': rules
}).default();
const migration = load('entry/src/main/ets/service/LegacyMigration.ets', {
  '../model/AppData': domain, '../model/LedgerModels': models, '../domain/LedgerRules': rules,
  '../domain/Money': money, '../domain/DateRange': dates
});
load('entry/src/test/LegacyMigration.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/model/AppData': domain,
  '../main/ets/service/LegacyMigration': migration, '../main/ets/domain/LedgerRules': rules
}).default();
const accounts = load('entry/src/main/ets/service/AccountService.ets', {
  '../model/LedgerModels': models, '../domain/LedgerRules': rules, '../domain/Money': money
});
load('entry/src/test/Account.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/model/LedgerModels': models,
  '../main/ets/domain/LedgerRules': rules, '../main/ets/service/AccountService': accounts
}).default();
const categories = load('entry/src/main/ets/service/CategoryService.ets', {
  '../model/LedgerModels': models, '../domain/LedgerRules': rules
});
load('entry/src/test/Category.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/model/LedgerModels': models,
  '../main/ets/service/CategoryService': categories
}).default();
const transactions = load('entry/src/main/ets/service/TransactionService.ets', {
  '../model/LedgerModels': models, '../domain/LedgerRules': rules, '../domain/Money': money
});
load('entry/src/test/Transaction.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/model/LedgerModels': models,
  '../main/ets/service/TransactionService': transactions
}).default();
const queries = load('entry/src/main/ets/service/LedgerQueryService.ets', {
  '../model/LedgerModels': models, '../domain/LedgerRules': rules, '../domain/Money': money
});
load('entry/src/test/Query.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/model/LedgerModels': models,
  '../main/ets/service/LedgerQueryService': queries
}).default();
const stats = load('entry/src/main/ets/service/StatisticsService.ets', {
  '../model/LedgerModels': models, '../domain/DateRange': dates, '../domain/Money': money
});
load('entry/src/test/Statistics.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/model/LedgerModels': models,
  '../main/ets/service/StatisticsService': stats
}).default();
const budget = load('entry/src/main/ets/service/BudgetService.ets', {
  '../model/LedgerModels': models, '../domain/DateRange': dates, '../domain/Money': money, '../domain/LedgerRules': rules
});
load('entry/src/test/Budget.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/model/LedgerModels': models,
  '../main/ets/service/BudgetService': budget
}).default();
const transfers = load('entry/src/main/ets/service/TransferService.ets', {
  '../model/LedgerModels': models, '../domain/Money': money, '../domain/LedgerRules': rules
});
load('entry/src/test/Transfer.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/model/LedgerModels': models,
  '../main/ets/service/TransferService': transfers, '../main/ets/domain/LedgerRules': rules
}).default();
const csvCodec = load('entry/src/main/ets/domain/CsvCodec.ets', {});
const exchange = load('entry/src/main/ets/service/DataExchangeService.ets', {
  '../model/LedgerModels': models, '../domain/Money': money, '../domain/LedgerRules': rules,
  '../domain/DateRange': dates, '../domain/CsvCodec': csvCodec
});
load('entry/src/test/Exchange.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/model/LedgerModels': models,
  '../main/ets/domain/CsvCodec': csvCodec, '../main/ets/service/DataExchangeService': exchange
}).default();
load('entry/src/test/LedgerIntegration.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/model/LedgerModels': models,
  '../main/ets/service/AccountService': accounts, '../main/ets/service/CategoryService': categories,
  '../main/ets/service/TransactionService': transactions, '../main/ets/service/TransferService': transfers,
  '../main/ets/service/BudgetService': budget, '../main/ets/domain/LedgerRules': rules,
  '../main/ets/service/DataExchangeService': exchange, '../main/ets/service/LedgerQueryService': queries,
  '../main/ets/service/StatisticsService': stats
}).default();
const entrySql = load('entry/src/main/ets/repository/EntryQuery.ets', {
  '../model/LedgerModels': models, '../domain/LedgerRules': rules
});
load('entry/src/test/EntryQuery.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/repository/EntryQuery': entrySql,
  '../main/ets/service/LedgerQueryService': queries
}).default();
const geometry = load('entry/src/main/ets/domain/ChartGeometry.ets', {});
load('entry/src/test/Charts.test.ets', { '@ohos/hypium': hypium, '../main/ets/domain/ChartGeometry': geometry }).default();
const cards = load('entry/src/main/ets/domain/CardLayout.ets', {});
load('entry/src/test/Cards.test.ets', { '@ohos/hypium': hypium, '../main/ets/domain/CardLayout': cards }).default();
const formats = load('entry/src/main/ets/service/ExchangeFormats.ets', {
  '../model/LedgerModels': models, './DataExchangeService': exchange,
  '../domain/CsvCodec': csvCodec, '../domain/LedgerRules': rules, '../domain/Money': money, '../domain/DateRange': dates
});
load('entry/src/test/ExchangeFormats.test.ets', {
  '@ohos/hypium': hypium, '../main/ets/model/LedgerModels': models,
  '../main/ets/service/AccountService': accounts, '../main/ets/service/CategoryService': categories,
  '../main/ets/service/ExchangeFormats': formats
}).default();
const portable = load('entry/src/main/ets/service/PortableBackup.ets', { '../model/LedgerModels': models, './DataExchangeService': exchange, '../domain/LedgerRules': rules });
load('entry/src/test/PortableBackup.test.ets', { '@ohos/hypium': hypium, '../main/ets/model/LedgerModels': models, '../main/ets/service/PortableBackup': portable }).default();
console.log(`${count} domain tests passed.`);
