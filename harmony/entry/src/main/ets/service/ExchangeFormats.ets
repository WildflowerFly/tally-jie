import { LedgerData, LedgerEntry, emptyLedger, Account, Category, Transfer, BudgetRule, LegacyAttachment } from '../model/LedgerModels';
import { ImportPreview, previewJson, exportJson } from './DataExchangeService';
import { decodeCsv, encodeCsv } from '../domain/CsvCodec';
import { validateLedger } from '../domain/LedgerRules';
import { parseAmount } from '../domain/Money';
import { isLedgerDate } from '../domain/DateRange';
export interface CsvMapping { id: string; type: string; amount: string; account: string; category: string; date: string; time: string; note: string; }
export interface RowIssue { line: number; message: string; }
export interface CsvReport { preview: ImportPreview | null; issues: RowIssue[]; }
function restore(value: string): string { return /^'[=+@\-\t\r']/.test(value) ? value.slice(1) : value; }
export function previewMappedCsv(data: LedgerData, text: string, mapping: CsvMapping, now: string): CsvReport {
  if (text.length > 8 * 1024 * 1024) { throw new Error('IMPORT_TOO_LARGE'); }
  const rows = decodeCsv(text); if (rows.length > 100001) { throw new Error('ROW_LIMIT'); }
  const columns = [mapping.id, mapping.type, mapping.amount, mapping.account, mapping.category, mapping.date, mapping.time, mapping.note];
  const indexes = columns.map((name: string) => rows[0]?.indexOf(name) ?? -1);
  if (indexes.some((index: number) => index < 0) || new Set(indexes).size !== 8 || new Set(rows[0]).size !== rows[0].length) { throw new Error('CSV_MAPPING_REQUIRED'); }
  const next: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
  const issues: RowIssue[] = []; let duplicates = 0;
  const ids = new Map(next.entries.map((row: LedgerEntry): [string, LedgerEntry] => [row.id, row]));
  rows.slice(1).forEach((raw: string[], index: number) => {
    try {
      if (raw.length !== rows[0].length) { throw new Error('COLUMN_COUNT'); }
      const cells = indexes.map((column: number) => restore(raw[column]));
      const type = cells[1] === '收入' || cells[1] === 'income' ? 'income' : cells[1] === '支出' || cells[1] === 'expense' ? 'expense' : '';
      if (!type || !cells[0].trim() || !isLedgerDate(cells[5]) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(cells[6]) || cells[7].length > 500) { throw new Error('INVALID_ROW'); }
      const accounts = data.accounts.filter((row) => row.id === cells[3] || row.name === cells[3]);
      const categories = data.categories.filter((row) => row.type === type && (row.id === cells[4] || row.name === cells[4]));
      if (accounts.length !== 1 || categories.length !== 1) { throw new Error('REFERENCE_MISSING_OR_AMBIGUOUS'); }
      const row: LedgerEntry = { id: cells[0], type: type === 'income' ? 'income' : 'expense', amountCents: parseAmount(cells[2]),
        accountId: accounts[0].id, categoryId: categories[0].id, date: cells[5], time: cells[6], note: cells[7], attachmentIds: [], createdAt: null, updatedAt: now };
      const old = ids.get(row.id);
      if (old !== undefined) {
        if (old.type !== row.type || old.amountCents !== row.amountCents || old.accountId !== row.accountId || old.categoryId !== row.categoryId || old.date !== row.date || old.time !== row.time || old.note !== row.note) { throw new Error('IMPORT_CONFLICT'); }
        duplicates++;
      } else { next.entries.push(row); ids.set(row.id, row); }
    } catch (error) { issues.push({ line: index + 2, message: (error as Error).message }); }
  });
  if (!issues.length) { try { validateLedger(next); } catch (error) { issues.push({ line: 0, message: (error as Error).message }); } }
  const preview: ImportPreview | null = issues.length ? null : { data: next, added: next.entries.length - data.entries.length, duplicates: duplicates };
  return { preview: preview, issues: issues };
}
// One portable CSV document with typed rows preserves every field, relation and integer amount.
export function exportTables(data: LedgerData): string {
  validateLedger(data);
  const rows: string[][] = [['schema', 'entity', 'payload']];
  data.accounts.forEach((row) => rows.push(['2', 'accounts', JSON.stringify(row)]));
  data.categories.forEach((row) => rows.push(['2', 'categories', JSON.stringify(row)]));
  data.entries.forEach((row) => rows.push(['2', 'entries', JSON.stringify(row)]));
  data.transfers.forEach((row) => rows.push(['2', 'transfers', JSON.stringify(row)]));
  data.budgets.forEach((row) => rows.push(['2', 'budgets', JSON.stringify(row)]));
  data.attachments.forEach((row) => rows.push(['2', 'attachments', JSON.stringify(row)]));
  return encodeCsv(rows);
}
export function previewTables(data: LedgerData, text: string): ImportPreview {
  if (text.length > 16 * 1024 * 1024) { throw new Error('IMPORT_TOO_LARGE'); }
  const rows = decodeCsv(text); const imported = emptyLedger();
  if (rows.length > 100001 || JSON.stringify(rows[0]) !== JSON.stringify(['schema', 'entity', 'payload'])) { throw new Error('CSV_TABLE_HEADER'); }
  rows.slice(1).forEach((row: string[], index: number) => {
    if (row.length !== 3 || row[0] !== '2') { throw new Error(`CSV_ROW:${index + 2}`); }
    switch (row[1]) {
      case 'accounts': imported.accounts.push(JSON.parse(row[2]) as Account); break;
      case 'categories': imported.categories.push(JSON.parse(row[2]) as Category); break;
      case 'entries': imported.entries.push(JSON.parse(row[2]) as LedgerEntry); break;
      case 'transfers': imported.transfers.push(JSON.parse(row[2]) as Transfer); break;
      case 'budgets': imported.budgets.push(JSON.parse(row[2]) as BudgetRule); break;
      case 'attachments': imported.attachments.push(JSON.parse(row[2]) as LegacyAttachment); break;
      default: throw new Error(`CSV_ENTITY:${index + 2}`);
    }
  });
  return previewJson(data, exportJson(imported));
}
