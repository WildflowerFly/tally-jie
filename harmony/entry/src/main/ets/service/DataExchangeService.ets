import { LedgerData, LedgerEntry, DateRange } from '../model/LedgerModels';
import { validateLedger } from '../domain/LedgerRules';
import { assertRange } from '../domain/DateRange';
import { parseAmount } from '../domain/Money';
import { encodeCsv, decodeCsv } from '../domain/CsvCodec';
export interface ExchangeDocument { format: string; version: number; data: LedgerData; }
export interface ImportPreview { data: LedgerData; added: number; duplicates: number; }
interface Identified { id: string; }
function equalEntity<T extends Identified>(left: T, right: T): boolean {
  // Parsing into the same field order avoids false conflicts from JSON object key order.
  const keys = Object.keys(left).sort();
  if (JSON.stringify(keys) !== JSON.stringify(Object.keys(right).sort())) { return false; }
  return JSON.stringify(left, keys) === JSON.stringify(right, keys);
}
function mergeRows<T extends Identified>(target: T[], source: T[]): number {
  let duplicates = 0;
  const existing = new Map<string, T>(); target.forEach((row: T) => { existing.set(row.id, row); });
  source.forEach((row: T) => {
    const old = existing.get(row.id);
    if (old !== undefined) {
      if (!equalEntity(old, row)) { throw new Error(`IMPORT_CONFLICT:${row.id}`); }
      duplicates++;
    } else { target.push(row); existing.set(row.id, row); }
  }); return duplicates;
}
export function exportJson(data: LedgerData, range: DateRange | null = null): string {
  validateLedger(data);
  const copy: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
  if (range !== null) {
    assertRange(range);
    copy.entries = copy.entries.filter((row) => row.date >= range.startDate && row.date <= range.endDate);
    copy.transfers = copy.transfers.filter((row) => row.date >= range.startDate && row.date <= range.endDate);
  }
  const doc: ExchangeDocument = { format: 'TallyJie-Ledger', version: 2, data: copy };
  return JSON.stringify(doc, null, 2);
}
export function previewJson(current: LedgerData, text: string): ImportPreview {
  if (text.length > 16 * 1024 * 1024) { throw new Error('IMPORT_TOO_LARGE'); }
  const doc = JSON.parse(text) as ExchangeDocument;
  if (doc.format !== 'TallyJie-Ledger' || doc.version !== 2) { throw new Error('UNSUPPORTED_IMPORT'); }
  validateLedger(doc.data);
  // Metadata-only export cannot recreate external attachment bytes: never silently import broken references.
  if (doc.data.attachments.some((asset) => !current.attachments.some((old) => old.id === asset.id && old.relativePath === asset.relativePath))) {
    throw new Error('ATTACHMENT_BYTES_REQUIRED');
  }
  const next: LedgerData = JSON.parse(JSON.stringify(current)) as LedgerData;
  let duplicates = 0;
  duplicates += mergeRows(next.accounts, doc.data.accounts); duplicates += mergeRows(next.categories, doc.data.categories);
  duplicates += mergeRows(next.entries, doc.data.entries); duplicates += mergeRows(next.transfers, doc.data.transfers);
  duplicates += mergeRows(next.budgets, doc.data.budgets); duplicates += mergeRows(next.attachments, doc.data.attachments);
  validateLedger(next);
  // Budget overlap rules also apply to data exchange, not only the editor.
  next.budgets.forEach((row, index: number) => {
    if (next.budgets.some((other, otherIndex: number) => otherIndex > index && row.categoryId === other.categoryId && row.startDate <= other.endDate && row.endDate >= other.startDate)) {
      throw new Error('BUDGET_OVERLAP');
    }
  });
  return { data: next, added: doc.data.accounts.length + doc.data.categories.length + doc.data.entries.length + doc.data.transfers.length + doc.data.budgets.length + doc.data.attachments.length - duplicates, duplicates: duplicates };
}
function spreadsheetSafe(value: string): string { return /^[=+@\-\t\r']/.test(value) ? "'" + value : value; }
function spreadsheetRestore(value: string): string { return /^'[=+@\-\t\r']/.test(value) ? value.slice(1) : value; }
const HEADER: string[] = ['id', 'type', 'amount', 'accountId', 'categoryId', 'date', 'time', 'note'];
export function exportCsv(data: LedgerData, range: DateRange | null = null): string {
  if (range !== null) { assertRange(range); }
  const rows: string[][] = [HEADER];
  data.entries.filter((row) => range === null || (row.date >= range.startDate && row.date <= range.endDate)).forEach((row) => {
    rows.push([row.id, row.type, (row.amountCents / 100).toFixed(2), row.accountId, row.categoryId, row.date, row.time, row.note].map((cell: string) => spreadsheetSafe(cell)));
  }); return encodeCsv(rows);
}
export function previewCsv(current: LedgerData, text: string, now: string): ImportPreview {
  if (text.length > 8 * 1024 * 1024) { throw new Error('IMPORT_TOO_LARGE'); }
  const rows = decodeCsv(text);
  if (rows.length === 0 || JSON.stringify(rows[0]) !== JSON.stringify(HEADER)) { throw new Error('CSV_HEADER_REQUIRED'); }
  const next: LedgerData = JSON.parse(JSON.stringify(current)) as LedgerData;
  let duplicates = 0;
  rows.slice(1).forEach((raw: string[], index: number) => {
    const cells = raw.map((cell: string) => spreadsheetRestore(cell));
    if (cells.length !== 8 || (cells[1] !== 'income' && cells[1] !== 'expense')) { throw new Error(`CSV_ROW:${index + 2}`); }
    const amount = parseAmount(cells[2]);
    const old = next.entries.find((row) => row.id === cells[0]);
    if (old !== undefined) {
      if (old.type !== cells[1] || old.amountCents !== amount || old.accountId !== cells[3] || old.categoryId !== cells[4] || old.date !== cells[5] || old.time !== cells[6] || old.note !== cells[7]) {
        throw new Error(`IMPORT_CONFLICT:${cells[0]}`);
      }
      duplicates++; return;
    }
    const entry: LedgerEntry = { id: cells[0], type: cells[1] === 'income' ? 'income' : 'expense', amountCents: amount,
      accountId: cells[3], categoryId: cells[4], date: cells[5], time: cells[6], note: cells[7], attachmentIds: [], createdAt: null, updatedAt: now };
    if (entry.note.length > 500) { throw new Error(`CSV_ROW:${index + 2}`); }
    next.entries.push(entry);
  });
  validateLedger(next); return { data: next, added: rows.length - 1 - duplicates, duplicates: duplicates };
}
