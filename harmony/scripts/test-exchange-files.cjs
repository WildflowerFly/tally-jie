#!/usr/bin/env node
// Host adapter executes production ExchangeFiles against a temporary directory.
// This checks orchestration/fault recovery, NOT Harmony file API or power-loss durability.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const ts = require(path.resolve(process.argv[2]));
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'tally-exchange-'));
let fault = false;
const opened = new Map();
const api = {
  OpenMode: { CREATE: 1, WRITE_ONLY: 2, TRUNC: 4, READ_ONLY: 8 },
  accessSync: p => fs.existsSync(p), statSync: p => fs.statSync(p),
  listFileSync: p => fs.readdirSync(p), mkdirSync: p => fs.mkdirSync(p),
  readTextSync: p => fs.readFileSync(p, 'utf8'), unlinkSync: p => fs.unlinkSync(p),
  openSync(p, mode) { const fd = fs.openSync(p, mode & 8 ? 'r' : mode & 4 ? 'w' : 'wx'); opened.set(fd, p); return { fd }; },
  writeSync: (fd, text) => fs.writeSync(fd, text), fsyncSync: fd => fs.fsyncSync(fd),
  closeSync(file) { fs.closeSync(file.fd); opened.delete(file.fd); },
  async open(p, mode) { return api.openSync(p, mode); },
  async close(file) { api.closeSync(file); }, async fsync(fd) { fs.fsyncSync(fd); },
  async read(fd, buffer) { return fs.readSync(fd, new Uint8Array(buffer), 0, Math.min(buffer.byteLength, 17), null); },
  async write(fd, buffer) {
    if (fault && opened.get(fd).includes('img_fail')) { throw new Error('INJECTED_DISK_FAILURE'); }
    return fs.writeSync(fd, new Uint8Array(buffer), 0, Math.min(buffer.byteLength, 13), null);
  }
};
class Base64Helper { encodeToStringSync(bytes) { return Buffer.from(bytes).toString('base64'); } decodeSync(text) { return new Uint8Array(Buffer.from(text, 'base64')); } }
class TextDecoderAdapter { constructor() { this.decoder = new TextDecoder('utf-8', { fatal: true }); } decodeWithStream(bytes) { return this.decoder.decode(bytes); } }
const modules = {
  '@kit.AbilityKit': {}, '@kit.CoreFileKit': { fileIo: api },
  '@kit.ArkTS': { util: { Base64Helper, TextDecoder: TextDecoderAdapter, TextEncoder: class { encodeInto(text) { return new TextEncoder().encode(text); } } } },
  '@kit.CryptoArchitectureKit': { cryptoFramework: { createMd() { const hash = crypto.createHash('sha256'); return { async update(blob) { hash.update(blob.data); }, async digest() { return { data: hash.digest() }; } }; } } },
  '../model/AppData': { validateData(data) { assert.ok(Array.isArray(data.diaries)); } }
};
const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/service/ExchangeFiles.ets'), 'utf8');
const code = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText;
const output = { exports: {} };
vm.runInNewContext(code, { exports: output.exports, require(name) { if (!(name in modules)) throw new Error(name); return modules[name]; }, console, Uint8Array, ArrayBuffer, Map, Set });
const { ExchangeFiles, sourceFingerprint } = output.exports;
const image = (name, text) => ({ path: `images/img_${name}.jpg`, base64: Buffer.from(text).toString('base64') });
(async () => {
  const adapter = new ExchangeFiles({ filesDir: root });
  const fingerprint = await sourceFingerprint('source-one');
  assert.equal(fingerprint, crypto.createHash('sha256').update('source-one').digest('hex'));
  const absent = { async hasSource() { return false; } };
  const committed = { async hasSource() { return true; } };
  const file = image('one', '中文-long-data'.repeat(100));
  await adapter.stage([file], fingerprint);
  assert.equal(fs.readFileSync(path.join(root, file.path)).toString('base64'), file.base64);
  // Simulated process restart without commit removes only newly staged files.
  await new ExchangeFiles({ filesDir: root }).recover(absent);
  assert.equal(fs.existsSync(path.join(root, file.path)), false);
  console.log('PASS uncommitted restart recovery and short writes');
  await adapter.stage([file], fingerprint); await adapter.recover(committed);
  assert.equal(fs.existsSync(path.join(root, file.path)), true);
  await adapter.stage([file], fingerprint); await adapter.recover(absent);
  assert.equal(fs.existsSync(path.join(root, file.path)), true);
  await assert.rejects(() => adapter.stage([image('one', 'different')], fingerprint), /FILE_CONFLICT/);
  assert.equal(fs.existsSync(path.join(root, 'exchange-journal.json')), false);
  console.log('PASS committed restart and existing-file preservation/conflict');
  fault = true;
  await assert.rejects(() => adapter.stage([image('new', 'new'), image('fail', 'fail')], fingerprint), /INJECTED_DISK_FAILURE/);
  fault = false; await adapter.recover(absent);
  assert.equal(fs.existsSync(path.join(root, 'images/img_new.jpg')), false);
  assert.equal(fs.existsSync(path.join(root, 'images/img_fail.jpg')), false);
  assert.equal(fs.existsSync(path.join(root, file.path)), true);
  console.log('PASS disk failure rolls back all newly staged files only');
  const archive = JSON.stringify({ transactions: [], diaries: [{ images: ['img_one.jpg'] }] });
  await adapter.stage([{ path: 'legacy/tallyjie.json', base64: Buffer.from(archive).toString('base64') }, file], fingerprint);
  await adapter.recover(committed);
  assert.equal(fs.existsSync(path.join(root, 'tallyjie.json')), false);
  const collected = await adapter.collect({ attachments: [{ id: 'one', relativePath: file.path }] });
  assert.equal(collected.length, 2); assert.ok(collected.some(row => row.path.startsWith('legacy/')));
  await assert.rejects(() => adapter.stage([{ path: '../secret', base64: 'e30=' }], fingerprint), /UNSAFE_PATH/);
  console.log('PASS legacy round trip remains archived and traversal rejected');
  console.log('4 exchange file fault/recovery scenarios passed (host adapter).');
})().catch(error => { console.error(error); process.exitCode = 1; }).finally(() => { for (const fd of opened.keys()) { try { fs.closeSync(fd); } catch {} } fs.rmSync(root, { recursive: true, force: true }); });
