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
const domain = load('entry/src/main/ets/model/AppData.ets', {});
load('entry/src/test/LocalUnit.test.ets', {
  '@ohos/hypium': hypium,
  '../main/ets/model/AppData': domain
}).default();
console.log(`${count} domain tests passed.`);
