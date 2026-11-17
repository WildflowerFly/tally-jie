import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { LedgerData } from '../model/LedgerModels';
import { LedgerRepository } from '../repository/LedgerRepository';
import { PortableFile } from './PortableBackup';
import { AppData, validateData } from '../model/AppData';
interface FileJournal { fingerprint: string; paths: string[]; }
export async function sourceFingerprint(text: string): Promise<string> {
  const digest = cryptoFramework.createMd('SHA256');
  await digest.update({ data: new util.TextEncoder().encodeInto(text) });
  return Array.from((await digest.digest()).data).map((byte: number) => byte.toString(16).padStart(2, '0')).join('');
}
export class ExchangeFiles {
  private root: string;
  private codec: util.Base64Helper = new util.Base64Helper();
  constructor(context: common.Context) { this.root = context.filesDir; }
  private async read(path: string): Promise<Uint8Array> {
    const size = fs.statSync(path).size;
    if (size > 16 * 1024 * 1024) { throw new Error('ASSET_TOO_LARGE'); }
    const file = await fs.open(path, fs.OpenMode.READ_ONLY); const buffer = new ArrayBuffer(size);
    try {
      let offset = 0;
      while (offset < size) {
        const chunk = new ArrayBuffer(Math.min(65536, size - offset)); const count = await fs.read(file.fd, chunk);
        if (count <= 0) { throw new Error('UNEXPECTED_EOF'); }
        new Uint8Array(buffer).set(new Uint8Array(chunk, 0, count), offset); offset += count;
      }
    } finally { await fs.close(file); }
    return new Uint8Array(buffer);
  }
  async collect(data: LedgerData): Promise<PortableFile[]> {
    const paths = new Set(data.attachments.map((asset) => asset.relativePath));
    const files: PortableFile[] = [];
    const archives: string[] = [];
    if (fs.accessSync(`${this.root}/tallyjie.json`)) { archives.push(`${this.root}/tallyjie.json`); }
    if (fs.accessSync(`${this.root}/imported-legacy`)) {
      fs.listFileSync(`${this.root}/imported-legacy`).filter((name: string) => /^[a-f0-9]{64}\.json$/.test(name)).sort()
        .forEach((name: string) => { archives.push(`${this.root}/imported-legacy/${name}`); });
    }
    const seen: Set<string> = new Set();
    for (const legacy of archives) {
      if (fs.statSync(legacy).size > 16 * 1024 * 1024) { throw new Error('ASSET_TOO_LARGE'); }
      const source = fs.readTextSync(legacy); const old = JSON.parse(source) as AppData; validateData(old);
      old.transactions.forEach((row) => row.images.forEach((name: string) => { paths.add(`images/${name}`); }));
      old.diaries.forEach((row) => row.images.forEach((name: string) => { paths.add(`images/${name}`); }));
      const hash = await sourceFingerprint(source);
      if (!seen.has(hash)) { files.push({ path: `legacy/${hash}.json`, base64: this.codec.encodeToStringSync(await this.read(legacy)) }); seen.add(hash); }
    }
    let total = 0;
    for (const path of paths) {
      if (!/^images\/img_[A-Za-z0-9_-]+\.jpg$/.test(path)) { throw new Error('UNSAFE_PATH'); }
      const bytes = await this.read(`${this.root}/${path}`); total += bytes.length;
      if (total > 40 * 1024 * 1024 || files.length >= 2000) { throw new Error('ASSET_TOTAL_LIMIT'); }
      files.push({ path: path, base64: this.codec.encodeToStringSync(bytes) });
    }
    return files;
  }
  private journalPath(): string { return `${this.root}/exchange-journal.json`; }
  async recover(repository: LedgerRepository): Promise<void> {
    if (!fs.accessSync(this.journalPath())) { return; }
    const journal = JSON.parse(fs.readTextSync(this.journalPath())) as FileJournal;
    if (!/^[a-f0-9]{64}$/.test(journal.fingerprint) || !Array.isArray(journal.paths)) { throw new Error('INVALID_EXCHANGE_JOURNAL'); }
    for (const path of journal.paths) {
      if (!/^(images\/img_[A-Za-z0-9_-]+\.jpg|imported-legacy\/[a-f0-9]{64}\.json)$/.test(path)) { throw new Error('INVALID_EXCHANGE_JOURNAL'); }
    }
    if (!(await repository.hasSource(journal.fingerprint))) { this.rollback(journal.paths); }
    fs.unlinkSync(this.journalPath());
  }
  private rollback(paths: string[]): void { for (const path of paths) { if (fs.accessSync(`${this.root}/${path}`)) { fs.unlinkSync(`${this.root}/${path}`); } } }
  async stage(files: PortableFile[], fingerprint: string): Promise<void> {
    if (!/^[a-f0-9]{64}$/.test(fingerprint) || fs.accessSync(this.journalPath())) { throw new Error('EXCHANGE_RECOVERY_REQUIRED'); }
    const writes: PortableFile[] = [];
    for (const file of files) {
      const relative = file.path.startsWith('legacy/') ? `imported-legacy/${await sourceFingerprint(new util.TextDecoder().decodeWithStream(this.codec.decodeSync(file.base64)))}.json` : file.path;
      if (!/^(images\/img_[A-Za-z0-9_-]+\.jpg|imported-legacy\/[a-f0-9]{64}\.json)$/.test(relative)) { throw new Error('UNSAFE_PATH'); }
      if (fs.accessSync(`${this.root}/${relative}`)) {
        if (this.codec.encodeToStringSync(await this.read(`${this.root}/${relative}`)) !== file.base64) { throw new Error('FILE_CONFLICT'); }
      } else { writes.push({ path: relative, base64: file.base64 }); }
    }
    for (const legacy of files.filter((file) => file.path.startsWith('legacy/'))) {
      const data = JSON.parse(new util.TextDecoder().decodeWithStream(this.codec.decodeSync(legacy.base64))) as AppData;
      validateData(data);
      const names = new Set(files.map((file) => file.path));
      data.transactions.forEach((row) => row.images.forEach((name: string) => { if (!names.has(`images/${name}`)) { throw new Error('LEGACY_ASSET_MISSING'); } }));
      data.diaries.forEach((row) => row.images.forEach((name: string) => { if (!names.has(`images/${name}`)) { throw new Error('LEGACY_ASSET_MISSING'); } }));
    }
    const journal: FileJournal = { fingerprint: fingerprint, paths: writes.map((file) => file.path) };
    const marker = fs.openSync(this.journalPath(), fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try { fs.writeSync(marker.fd, JSON.stringify(journal)); fs.fsyncSync(marker.fd); } finally { fs.closeSync(marker); }
    for (const file of writes) {
      const directory = `${this.root}/${file.path.split('/')[0]}`; if (!fs.accessSync(directory)) { fs.mkdirSync(directory); }
      const out = await fs.open(`${this.root}/${file.path}`, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      try {
        const bytes = this.codec.decodeSync(file.base64);
        for (let offset = 0; offset < bytes.length; offset += 65536) {
          const chunk = bytes.slice(offset, Math.min(offset + 65536, bytes.length)); let written = 0;
          while (written < chunk.length) {
            const count = await fs.write(out.fd, chunk.slice(written).buffer); if (count <= 0) { throw new Error('SHORT_WRITE'); } written += count;
          }
        }
        await fs.fsync(out.fd);
      } finally { await fs.close(out); }
    }
  }
}
