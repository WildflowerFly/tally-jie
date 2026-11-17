import { relationalStore } from '@kit.ArkData';
import { Account, Category, LedgerEntry, Transfer, BudgetRule, LegacyAttachment, LedgerData, emptyLedger } from '../model/LedgerModels';
import { validateLedger } from '../domain/LedgerRules';

export interface LedgerSnapshot { data: LedgerData; revision: number; }
export interface MigrationArchive {
  sourcePath: string;
  sourceSha256: string;
  diaryCount: number;
  attachmentCount: number;
  migratedAt: string;
}
// A single repository instance owns a store. Never share the raw store with UI code.
export class LedgerRepository {
  private store: relationalStore.RdbStore;
  private tail: Promise<void> = Promise.resolve();
  private fault: (() => void) | undefined;
  constructor(store: relationalStore.RdbStore, fault?: () => void) { this.store = store; this.fault = fault; }
  private enqueue<T>(work: () => Promise<T>): Promise<T> {
    const next = this.tail.then(work);
    this.tail = next.then(() => {}, () => {});
    return next;
  }
  private async meta(key: string): Promise<string | undefined> {
    const rows = await this.store.querySql('SELECT value FROM ledger_meta WHERE key=?', [key]);
    try { return rows.goToFirstRow() ? rows.getString(0) : undefined; }
    finally { rows.close(); }
  }
  private async payloads(table: string): Promise<string[]> {
    // table comes only from the fixed internal list, never from a query/filter/import.
    const rows = await this.store.querySql(`SELECT payload FROM ${table} ORDER BY id`);
    const result: string[] = [];
    try { while (rows.goToNextRow()) { result.push(rows.getString(0)); } }
    finally { rows.close(); }
    return result;
  }
  private async read(): Promise<LedgerSnapshot | undefined> {
    const revision = await this.meta('revision');
    if (revision === undefined) { return undefined; }
    const data = emptyLedger();
    data.accounts = (await this.payloads('accounts')).map((row: string) => JSON.parse(row) as Account);
    data.categories = (await this.payloads('categories')).map((row: string) => JSON.parse(row) as Category);
    data.entries = (await this.payloads('entries')).map((row: string) => JSON.parse(row) as LedgerEntry);
    data.transfers = (await this.payloads('transfers')).map((row: string) => JSON.parse(row) as Transfer);
    data.budgets = (await this.payloads('budgets')).map((row: string) => JSON.parse(row) as BudgetRule);
    data.attachments = (await this.payloads('attachments')).map((row: string) => JSON.parse(row) as LegacyAttachment);
    validateLedger(data);
    const value = Number(revision);
    if (!Number.isSafeInteger(value) || value < 1) { throw new Error('INVALID_REVISION'); }
    return { data: data, revision: value };
  }
  load(): Promise<LedgerSnapshot | undefined> {
    return this.enqueue(async () => {
      this.store.beginTransaction();
      try { const result = await this.read(); this.store.commit(); return result; }
      catch (error) { this.store.rollBack(); throw error as Error; }
    });
  }
  archive(): Promise<string | undefined> { return this.enqueue(() => this.meta('legacy_archive')); }
  private async replace(data: LedgerData): Promise<void> {
    const tables: string[] = ['entry_assets', 'entries', 'transfers', 'budgets', 'attachments', 'categories', 'accounts'];
    for (const table of tables) { await this.store.executeSql(`DELETE FROM ${table}`); }
    for (const row of data.accounts) { await this.store.executeSql('INSERT INTO accounts VALUES (?,?)', [row.id, JSON.stringify(row)]); }
    for (const row of data.categories) { await this.store.executeSql('INSERT INTO categories VALUES (?,?)', [row.id, JSON.stringify(row)]); }
    for (const row of data.attachments) { await this.store.executeSql('INSERT INTO attachments VALUES (?,?)', [row.id, JSON.stringify(row)]); }
    for (const row of data.entries) {
      await this.store.executeSql('INSERT INTO entries VALUES (?,?,?,?,?,?,?,?)',
        [row.id, row.accountId, row.categoryId, row.date, row.time, row.amountCents, row.type, JSON.stringify(row)]);
      for (const asset of row.attachmentIds) {
        await this.store.executeSql('INSERT INTO entry_assets VALUES (?,?)', [row.id, asset]);
      }
    }
    for (const row of data.transfers) {
      await this.store.executeSql('INSERT INTO transfers VALUES (?,?,?,?,?,?,?)',
        [row.id, row.fromAccountId, row.toAccountId, row.date, row.time, row.amountCents, JSON.stringify(row)]);
    }
    for (const row of data.budgets) {
      await this.store.executeSql('INSERT INTO budgets VALUES (?,?,?,?,?)', [row.id, row.categoryId, row.startDate, row.endDate, JSON.stringify(row)]);
    }
  }
  // Candidate copy is taken before awaiting, so caller edits cannot race an in-flight write.
  save(data: LedgerData, expectedRevision: number): Promise<LedgerSnapshot> {
    const candidate: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
    validateLedger(candidate);
    return this.enqueue(async () => {
      this.store.beginTransaction();
      try {
        const current = await this.meta('revision');
        if (current === undefined || Number(current) !== expectedRevision) { throw new Error('STALE_WRITE'); }
        await this.replace(candidate);
        if (this.fault !== undefined) { this.fault(); }
        const revision = expectedRevision + 1;
        if (!Number.isSafeInteger(revision)) { throw new Error('INVALID_REVISION'); }
        await this.store.executeSql('UPDATE ledger_meta SET value=? WHERE key=?', [revision.toString(), 'revision']);
        const snapshot: LedgerSnapshot = { data: candidate, revision: revision };
        this.store.commit(); return snapshot;
      } catch (error) { this.store.rollBack(); throw error as Error; }
    });
  }
  initialize(data: LedgerData, archive: MigrationArchive | null): Promise<LedgerSnapshot> {
    const candidate: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
    validateLedger(candidate);
    return this.enqueue(async () => {
      this.store.beginTransaction();
      try {
        const existing = await this.read();
        if (existing !== undefined) { this.store.commit(); return existing; }
        await this.replace(candidate);
        if (this.fault !== undefined) { this.fault(); }
        if (archive !== null) {
          await this.store.executeSql('INSERT INTO ledger_meta VALUES (?,?)', ['legacy_archive', JSON.stringify(archive)]);
        }
        await this.store.executeSql('INSERT INTO ledger_meta VALUES (?,?)', ['revision', '1']);
        const snapshot: LedgerSnapshot = { data: candidate, revision: 1 };
        this.store.commit(); return snapshot;
      } catch (error) { this.store.rollBack(); throw error as Error; }
    });
  }
}
