import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { AppData } from '../model/AppData';
import { emptyLedger } from '../model/LedgerModels';
import { LedgerRepository, LedgerSnapshot, MigrationArchive } from '../repository/LedgerRepository';
import { MigrationDraft, InitialBalanceInput, buildLegacyMigration, applyInitialBalances } from './LegacyMigration';

export interface MigrationStatus {
  snapshot: LedgerSnapshot | null;
  draft: MigrationDraft | null;
}
export class LegacyMigrationService {
  private context: common.Context;
  private repository: LedgerRepository;
  constructor(context: common.Context, repository: LedgerRepository) { this.context = context; this.repository = repository; }
  async start(inputs: InitialBalanceInput[] = []): Promise<MigrationStatus> {
    const existing = await this.repository.load();
    if (existing !== undefined) { return { snapshot: existing, draft: null }; }
    const path = `${this.context.filesDir}/tallyjie.json`;
    if (!fs.accessSync(path)) {
      return { snapshot: await this.repository.initialize(emptyLedger(), null), draft: null };
    }
    if (fs.statSync(path).size > 64 * 1024 * 1024) { throw new Error('LEGACY_FILE_TOO_LARGE'); }
    const text = fs.readTextSync(path);
    const source: AppData = JSON.parse(text) as AppData;
    const now = new Date().toISOString();
    const draft = buildLegacyMigration(source, now);
    // No DB marker/rows are written while ordinary historical accounts still need repair.
    if (draft.requiredAccountIds.length > 0 && inputs.length === 0) { return { snapshot: null, draft: draft }; }
    const data = applyInitialBalances(draft, inputs);
    // Verify all referenced legacy files before switching; no renaming/copying/deleting source assets.
    const paths: string[] = [];
    source.transactions.forEach((row) => row.images.forEach((name: string) => { if (!paths.includes(name)) { paths.push(name); } }));
    source.diaries.forEach((row) => row.images.forEach((name: string) => { if (!paths.includes(name)) { paths.push(name); } }));
    for (const name of paths) {
      if (!fs.accessSync(`${this.context.filesDir}/images/${name}`)) { throw new Error('LEGACY_ATTACHMENT_MISSING'); }
    }
    const md = cryptoFramework.createMd('SHA256');
    await md.update({ data: new util.TextEncoder().encodeInto(text) });
    const digest = await md.digest();
    const hash = Array.from(digest.data).map((value: number) => value.toString(16).padStart(2, '0')).join('');
    // Catch legacy writes occurring during asynchronous hashing; source is never modified by migration.
    if (fs.readTextSync(path) !== text) { throw new Error('LEGACY_SOURCE_CHANGED'); }
    const archive: MigrationArchive = { sourcePath: 'tallyjie.json', sourceSha256: hash,
      diaryCount: source.diaries.length, attachmentCount: paths.length, migratedAt: now };
    return { snapshot: await this.repository.initialize(data, archive), draft: null };
  }
}
