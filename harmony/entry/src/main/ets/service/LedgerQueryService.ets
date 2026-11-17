import { LedgerData, LedgerFilter, LedgerEntry, LedgerCursor } from '../model/LedgerModels';
import { validateFilter } from '../domain/LedgerRules';
import { addCents } from '../domain/Money';
export interface LedgerPage { rows: LedgerEntry[]; incomeCents: number; expenseCents: number; count: number; next: LedgerCursor | null; }
export function defaultFilter(): LedgerFilter {
  return { type: null, accountIds: [], categoryIds: [], range: null, minAmountCents: null,
    maxAmountCents: null, keyword: '', cursor: null, pageSize: 50 };
}
function key(row: LedgerEntry): string { return `${row.date}|${row.time}|${row.id}`; }
export function queryEntries(data: LedgerData, filter: LedgerFilter): LedgerPage {
  validateFilter(filter);
  const keyword = filter.keyword.trim().toLocaleLowerCase();
  // Literal substring matching: %, _, quotes are not SQL operators. No user input is interpolated into SQL.
  const matches = data.entries.filter((row) => {
    if (filter.type !== null && row.type !== filter.type) { return false; }
    if (filter.accountIds.length > 0 && !filter.accountIds.includes(row.accountId)) { return false; }
    if (filter.categoryIds.length > 0 && !filter.categoryIds.includes(row.categoryId)) { return false; }
    if (filter.range !== null && (row.date < filter.range.startDate || row.date > filter.range.endDate)) { return false; }
    if (filter.minAmountCents !== null && row.amountCents < filter.minAmountCents) { return false; }
    if (filter.maxAmountCents !== null && row.amountCents > filter.maxAmountCents) { return false; }
    if (!keyword) { return true; }
    const account = data.accounts.find((item) => item.id === row.accountId);
    const category = data.categories.find((item) => item.id === row.categoryId);
    return `${row.note}\n${account?.name || ''}\n${category?.name || ''}`.toLocaleLowerCase().includes(keyword);
  });
  let income = 0; let expense = 0;
  matches.forEach((row) => {
    if (row.type === 'income') { income = addCents(income, row.amountCents); }
    else { expense = addCents(expense, row.amountCents); }
  });
  matches.sort((a: LedgerEntry, b: LedgerEntry) => key(a) < key(b) ? 1 : key(a) > key(b) ? -1 : 0);
  const cursor = filter.cursor;
  const cursorKey = cursor === null ? '' : `${cursor.date}|${cursor.time}|${cursor.id}`;
  const remaining = cursor === null ? matches : matches.filter((row) => key(row) < cursorKey);
  const rows = remaining.slice(0, filter.pageSize);
  const last = rows.length === 0 ? undefined : rows[rows.length - 1];
  let next: LedgerCursor | null = null;
  if (remaining.length > rows.length && last !== undefined) { next = { date: last.date, time: last.time, id: last.id }; }
  return { rows: rows, incomeCents: income, expenseCents: expense, count: matches.length, next: next };
}
