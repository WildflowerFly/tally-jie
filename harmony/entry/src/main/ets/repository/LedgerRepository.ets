import { relationalStore } from '@kit.ArkData';
import { Account, Category, LedgerEntry, Transfer, BudgetRule, LegacyAttachment, LedgerData, emptyLedger, LedgerFilter } from '../model/LedgerModels';
import { validateLedger } from '../domain/LedgerRules';
import { entryQueries } from './EntryQuery';
import { LedgerPage } from '../service/LedgerQueryService';
export interface DailyTotal { date: string; incomeCents: number; expenseCents: number; }
export interface DatabasePage { page: LedgerPage; days: DailyTotal[]; revision: number; }

interface StoredEntity { id: string; }
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
  private committed: LedgerSnapshot | undefined;
  private remember(snapshot: LedgerSnapshot): void {
    this.committed = JSON.parse(JSON.stringify(snapshot)) as LedgerSnapshot;
  }
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
      try { const result = await this.read(); this.store.commit(); if (result !== undefined) { this.remember(result); } return result; }
      catch (error) { this.store.rollBack(); throw error as Error; }
    });
  }
  query(filter: LedgerFilter): Promise<DatabasePage> {
    const queries = entryQueries(filter);
    return this.enqueue(async () => {
      this.store.beginTransaction();
      try {
        const revision = Number(await this.meta('revision'));
        const entries: LedgerEntry[] = [];
        const rows = await this.store.querySql(queries.page.sql, queries.page.args);
        try { while (rows.goToNextRow()) { entries.push(JSON.parse(rows.getString(0)) as LedgerEntry); } }
        finally { rows.close(); }
        const totals = await this.store.querySql(queries.totals.sql, queries.totals.args);
        let income = 0; let expense = 0; let count = 0;
        try { if (totals.goToFirstRow()) { income = totals.getLong(0); expense = totals.getLong(1); count = totals.getLong(2); } }
        finally { totals.close(); }
        if (!Number.isSafeInteger(income) || !Number.isSafeInteger(expense)) { throw new Error('AMOUNT_OVERFLOW'); }
        const days: DailyTotal[] = [];
        const daily = await this.store.querySql(queries.daily.sql, queries.daily.args);
        try { while (daily.goToNextRow()) { days.push({ date: daily.getString(0), incomeCents: daily.getLong(1), expenseCents: daily.getLong(2) }); } }
        finally { daily.close(); }
        const more = entries.length > filter.pageSize;
        if (more) { entries.pop(); }
        const last = entries[entries.length - 1];
        const page: LedgerPage = { rows: entries, count: count, incomeCents: income, expenseCents: expense,
          next: more ? { date: last.date, time: last.time, id: last.id } : null };
        const result: DatabasePage = { page: page, days: days, revision: revision };
        this.store.commit(); return result;
      } catch (error) { this.store.rollBack(); throw error as Error; }
    });
  }
  archive(): Promise<string | undefined> { return this.enqueue(() => this.meta('legacy_archive')); }
  private async replace(data: LedgerData): Promise<void> {
    const tables: string[] = ['entry_assets', 'entries', 'transfers', 'budgets', 'attachments', 'categories', 'accounts'];
    for (const table of tables) { await this.store.executeSql(`DELETE FROM ${table}`); }
    for (const row of data.accounts) { await this.store.executeSql('INSERT INTO accounts(id,payload,name) VALUES (?,?,?)', [row.id, JSON.stringify(row), row.name]); }
    for (const row of data.categories) { await this.store.executeSql('INSERT INTO categories(id,payload,name) VALUES (?,?,?)', [row.id, JSON.stringify(row), row.name]); }
    for (const row of data.attachments) { await this.store.executeSql('INSERT INTO attachments VALUES (?,?)', [row.id, JSON.stringify(row)]); }
    for (const row of data.entries) {
      await this.store.executeSql('INSERT INTO entries(id,account_id,category_id,date,time,amount,type,payload,note) VALUES (?,?,?,?,?,?,?,?,?)',
        [row.id, row.accountId, row.categoryId, row.date, row.time, row.amountCents, row.type, JSON.stringify(row), row.note]);
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
  private async removeMissing<T extends StoredEntity>(table: string, before: T[], after: T[]): Promise<void> {
    const ids = new Set(after.map((row: T) => row.id));
    for (const row of before) {
      if (!ids.has(row.id)) { await this.store.executeSql(`DELETE FROM ${table} WHERE id=?`, [row.id]); }
    }
  }
  private changed<T extends StoredEntity>(before: T[], after: T[]): T[] {
    const previous = new Map<string, string>();
    before.forEach((row: T) => { previous.set(row.id, JSON.stringify(row)); });
    return after.filter((row: T) => previous.get(row.id) !== JSON.stringify(row));
  }
  // Incremental upserts never use REPLACE (which would delete a referenced parent).
  private async update(before: LedgerData, after: LedgerData): Promise<void> {
    const entries = this.changed(before.entries, after.entries);
    const changedIds = new Set(entries.map((row) => row.id));
    const retainedIds = new Set(after.entries.map((row) => row.id));
    for (const row of before.entries) {
      if (changedIds.has(row.id) || !retainedIds.has(row.id)) { await this.store.executeSql('DELETE FROM entry_assets WHERE entry_id=?', [row.id]); }
    }
    await this.removeMissing('entries', before.entries, after.entries);
    await this.removeMissing('transfers', before.transfers, after.transfers);
    await this.removeMissing('budgets', before.budgets, after.budgets);
    for (const row of this.changed(before.accounts, after.accounts)) {
      await this.store.executeSql('INSERT INTO accounts(id,payload,name) VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,name=excluded.name', [row.id, JSON.stringify(row), row.name]);
    }
    for (const row of this.changed(before.categories, after.categories)) {
      await this.store.executeSql('INSERT INTO categories(id,payload,name) VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,name=excluded.name', [row.id, JSON.stringify(row), row.name]);
    }
    for (const row of this.changed(before.attachments, after.attachments)) {
      await this.store.executeSql('INSERT INTO attachments(id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload', [row.id, JSON.stringify(row)]);
    }
    for (const row of entries) {
      await this.store.executeSql('INSERT INTO entries(id,account_id,category_id,date,time,amount,type,payload,note) VALUES (?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET account_id=excluded.account_id,category_id=excluded.category_id,date=excluded.date,time=excluded.time,amount=excluded.amount,type=excluded.type,payload=excluded.payload,note=excluded.note',
        [row.id, row.accountId, row.categoryId, row.date, row.time, row.amountCents, row.type, JSON.stringify(row), row.note]);
      for (const asset of row.attachmentIds) { await this.store.executeSql('INSERT INTO entry_assets VALUES (?,?)', [row.id, asset]); }
    }
    for (const row of this.changed(before.transfers, after.transfers)) {
      await this.store.executeSql('INSERT INTO transfers VALUES (?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET from_id=excluded.from_id,to_id=excluded.to_id,date=excluded.date,time=excluded.time,amount=excluded.amount,payload=excluded.payload',
        [row.id, row.fromAccountId, row.toAccountId, row.date, row.time, row.amountCents, JSON.stringify(row)]);
    }
    for (const row of this.changed(before.budgets, after.budgets)) {
      await this.store.executeSql('INSERT INTO budgets VALUES (?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET category_id=excluded.category_id,start_date=excluded.start_date,end_date=excluded.end_date,payload=excluded.payload',
        [row.id, row.categoryId, row.startDate, row.endDate, JSON.stringify(row)]);
    }
    // References have now moved. Delete old parents last.
    await this.removeMissing('attachments', before.attachments, after.attachments);
    await this.removeMissing('categories', before.categories, after.categories);
    await this.removeMissing('accounts', before.accounts, after.accounts);
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
        const before = this.committed?.revision === expectedRevision ? this.committed : await this.read();
        if (before === undefined) { throw new Error('NOT_INITIALIZED'); }
        await this.update(before.data, candidate);
        if (this.fault !== undefined) { this.fault(); }
        const revision = expectedRevision + 1;
        if (!Number.isSafeInteger(revision)) { throw new Error('INVALID_REVISION'); }
        await this.store.executeSql('UPDATE ledger_meta SET value=? WHERE key=?', [revision.toString(), 'revision']);
        const snapshot: LedgerSnapshot = { data: candidate, revision: revision };
        this.store.commit(); this.remember(snapshot); return snapshot;
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
        this.store.commit(); this.remember(snapshot); return snapshot;
      } catch (error) { this.store.rollBack(); throw error as Error; }
    });
  }
}
