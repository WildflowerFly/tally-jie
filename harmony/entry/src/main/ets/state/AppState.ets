import { ExchangeFiles } from '../service/ExchangeFiles';
import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { LedgerData, emptyLedger, LedgerFilter } from '../model/LedgerModels';
import { LedgerDatabase } from '../database/LedgerDatabase';
import { LedgerRepository, DatabasePage } from '../repository/LedgerRepository';
import { LegacyMigrationService } from '../service/LegacyMigrationService';
import { MigrationDraft, InitialBalanceInput } from '../service/LegacyMigration';

export type LoadStatus = 'loading' | 'ready' | 'repair' | 'error';
@Observed
export class AppState {
  data: LedgerData = emptyLedger();
  status: LoadStatus = 'loading';
  message: string = '';
  revision: number = 0;
  refreshVersion: number = 0;
  saving: boolean = false;
  draft: MigrationDraft | null = null;
  private generation: number = 0;
  private repository: LedgerRepository | undefined;
  private store: relationalStore.RdbStore | undefined;
  private context: common.Context | undefined;
  async load(context: common.Context, inputs: InitialBalanceInput[] = []): Promise<void> {
    if (this.saving || this.status === 'loading' && this.context !== undefined) { return; }
    this.context = context;
    const ticket = ++this.generation;
    this.status = 'loading'; this.message = '';
    try {
      if (this.repository === undefined) {
        const opened = await LedgerDatabase.open(context);
        if (ticket !== this.generation) { opened.close(); return; }
        this.store = opened; this.repository = new LedgerRepository(opened);
      }
      await new ExchangeFiles(context).recover(this.repository);
      const result = await new LegacyMigrationService(context, this.repository).start(inputs);
      if (ticket !== this.generation) { return; }
      if (result.snapshot === null) {
        this.draft = result.draft; this.status = 'repair'; return;
      }
      this.data = result.snapshot.data; this.revision = result.snapshot.revision;
      this.draft = null; this.status = 'ready'; this.refreshVersion++;
    } catch (error) {
      if (ticket !== this.generation) { return; }
      this.status = 'error'; this.message = (error as Error).message || '账本读取失败';
    }
  }
  async queryEntries(filter: LedgerFilter): Promise<DatabasePage> {
    if (this.status !== 'ready' || this.repository === undefined) { throw new Error('NOT_READY'); }
    return this.repository.query(filter);
  }
  async hasImportSource(fingerprint: string): Promise<boolean> {
    if (this.repository === undefined) { throw new Error('NOT_READY'); }
    return this.repository.hasSource(fingerprint);
  }
  async recoverExchange(): Promise<void> {
    if (this.repository === undefined || this.context === undefined) { throw new Error('NOT_READY'); }
    await new ExchangeFiles(this.context).recover(this.repository);
  }
  // Pages never update data optimistically. A failed save keeps the committed view and form input.
  async commit(next: LedgerData, fingerprint: string = ''): Promise<boolean> {
    const repository = this.repository;
    if (this.status !== 'ready' || this.saving || repository === undefined) { return false; }
    const ticket = this.generation;
    this.saving = true; this.message = '';
    try {
      const snapshot = await repository.save(next, this.revision, fingerprint);
      if (ticket !== this.generation) { return false; }
      this.data = snapshot.data; this.revision = snapshot.revision; this.refreshVersion++;
      return true;
    } catch (error) {
      if (ticket === this.generation) { this.message = (error as Error).message || '保存失败，请重试'; }
      return false;
    } finally { if (ticket === this.generation) { this.saving = false; } }
  }
  // The root owns this state for its whole lifetime; no page opens/closes the database.
}
