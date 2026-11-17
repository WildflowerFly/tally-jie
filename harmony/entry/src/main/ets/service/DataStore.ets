import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { util } from '@kit.ArkTS';
import { AppData, Backup, BackupAsset, emptyData, newId, validateData } from '../model/AppData';

// New finance entry point uses these services; legacy save is not called after v2 activation.
export { LedgerDatabase } from '../database/LedgerDatabase';
export { LedgerRepository } from '../repository/LedgerRepository';
export { LegacyMigrationService } from './LegacyMigrationService';

const MAX_BACKUP_BYTES: number = 64 * 1024 * 1024;

export class DataStore {
  private context: common.UIAbilityContext;
  private root: string;
  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.root = context.filesDir;
    if (!fs.accessSync(`${this.root}/images`)) fs.mkdirSync(`${this.root}/images`);
  }

  load(): AppData {
    const path = `${this.root}/tallyjie.json`;
    if (!fs.accessSync(path)) return emptyData();
    const data: AppData = JSON.parse(fs.readTextSync(path)) as AppData;
    validateData(data);
    return data;
  }

  save(data: AppData): void {
    validateData(data);
    const temp = `${this.root}/tallyjie.tmp`;
    this.writeText(temp, JSON.stringify(data));
    fs.renameSync(temp, `${this.root}/tallyjie.json`);
  }

  imagePath(name: string): string {
    return `${this.root}/images/${name}`;
  }

  async pickImages(remaining: number): Promise<string[]> {
    if (remaining <= 0) return [];
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = remaining;
    const result = await new photoAccessHelper.PhotoViewPicker().select(options);
    const names: string[] = [];
    for (const uri of result.photoUris) {
      const source = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const name = `img_${newId()}.jpg`;
      try {
        if (fs.statSync(source.fd).size > 8 * 1024 * 1024) throw new Error('每张图片不能超过 8 MB');
        fs.copyFileSync(source.fd, this.imagePath(name));
        names.push(name);
      } finally {
        fs.closeSync(source);
      }
    }
    return names;
  }

  async exportBackup(data: AppData): Promise<boolean> {
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [`TallyJie-Harmony-${Date.now()}.json`];
    options.fileSuffixChoices = ['JSON 备份|.json'];
    const uris = await new picker.DocumentViewPicker(this.context).save(options);
    if (uris.length === 0) return false;
    const names: string[] = [];
    data.transactions.forEach(t => t.images.forEach(name => { if (!names.includes(name)) names.push(name); }));
    data.diaries.forEach(d => d.images.forEach(name => { if (!names.includes(name)) names.push(name); }));
    const assets: BackupAsset[] = [];
    const base64 = new util.Base64Helper();
    let total = 0;
    for (const name of names) {
      const path = this.imagePath(name);
      const size = fs.statSync(path).size;
      total += size;
      if (total > 40 * 1024 * 1024) throw new Error('附件总量过大，单次备份最多支持 40 MB 附件');
      const buffer = new ArrayBuffer(size);
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      try { fs.readSync(file.fd, buffer); } finally { fs.closeSync(file); }
      assets.push({ name: name, data: base64.encodeToStringSync(new Uint8Array(buffer)) });
    }
    const backup: Backup = { format: 'TallyJie-Harmony', version: 1, createdAt: new Date().toISOString(), data: data, assets: assets };
    this.writeText(uris[0], JSON.stringify(backup));
    return true;
  }

  async importBackup(): Promise<AppData | undefined> {
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    options.fileSuffixFilters = ['.json'];
    const uris = await new picker.DocumentViewPicker(this.context).select(options);
    if (uris.length === 0) return undefined;
    const file = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
    let text = '';
    try {
      const size = fs.statSync(file.fd).size;
      if (size > MAX_BACKUP_BYTES) throw new Error('备份文件不能超过 64 MB');
      text = fs.readTextSync(uris[0]);
    } finally { fs.closeSync(file); }
    const backup = JSON.parse(text) as Backup;
    if (!backup || backup.format !== 'TallyJie-Harmony' || backup.version !== 1 || !Array.isArray(backup.assets)) {
      throw new Error('请选择鸿蒙版 JSON 备份；暂不支持 Flutter ZIP/JSON');
    }
    validateData(backup.data);
    const required: string[] = [];
    backup.data.transactions.forEach(t => t.images.forEach(n => { if (!required.includes(n)) required.push(n); }));
    backup.data.diaries.forEach(d => d.images.forEach(n => { if (!required.includes(n)) required.push(n); }));
    // New names prevent failed imports from overwriting attachments of live records.
    const oldNames: string[] = [];
    const newNames: string[] = [];
    const created: string[] = [];
    try {
      for (const name of required) {
        const asset = backup.assets.find((a: BackupAsset) => a.name === name);
        if (!asset || typeof asset.data !== 'string') throw new Error('备份附件缺失');
        const bytes = new util.Base64Helper().decodeSync(asset.data);
        if (bytes.byteLength > 8 * 1024 * 1024) throw new Error('备份图片超过大小限制');
        const nextName = `img_${newId()}.jpg`;
        const path = this.imagePath(nextName);
        created.push(path);
        const out = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try { fs.writeSync(out.fd, bytes.buffer); fs.fsyncSync(out.fd); } finally { fs.closeSync(out); }
        oldNames.push(name);
        newNames.push(nextName);
      }
      backup.data.transactions.forEach(t => { t.images = t.images.map(n => newNames[oldNames.indexOf(n)]); });
      backup.data.diaries.forEach(d => { d.images = d.images.map(n => newNames[oldNames.indexOf(n)]); });
      this.save(backup.data);
      return backup.data;
    } catch (error) {
      created.forEach(path => { if (fs.accessSync(path)) fs.unlinkSync(path); });
      throw new Error((error as Error).message);
    }
  }

  private writeText(path: string, text: string): void {
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try { fs.writeSync(file.fd, text); fs.fsyncSync(file.fd); } finally { fs.closeSync(file); }
  }
}
