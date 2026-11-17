import { Account, Category, LedgerData, LedgerError, LedgerFilter } from '../model/LedgerModels';
import { MAX_AMOUNT_CENTS, addCents, assertAmount } from './Money';
import { assertRange, calendarMonth, calendarWeek, isLedgerDate } from './DateRange';

function entity(condition: boolean): void {
  if (!condition) { throw new LedgerError('INVALID_ENTITY'); }
}
function uniqueIds(ids: string[]): void {
  const seen: Set<string> = new Set<string>();
  ids.forEach((id: string) => {
    entity(typeof id === 'string' && id.trim().length > 0);
    if (seen.has(id)) { throw new LedgerError('DUPLICATE_ID'); }
    seen.add(id);
  });
}
function stamp(value: string): boolean {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value) &&
    isLedgerDate(value.slice(0, 10)) && Number.isFinite(Date.parse(value)) && new Date(value).toISOString() === value;
}
function timestamps(created: string | null, updated: string): void {
  entity(stamp(updated) && (created === null || (stamp(created) && created <= updated)));
}
function dateTime(date: string, time: string): void {
  if (!isLedgerDate(date) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(time)) {
    throw new LedgerError('INVALID_DATE');
  }
}
function account(data: LedgerData, id: string): Account {
  const result = data.accounts.find((item: Account) => item.id === id);
  if (result === undefined) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
  return result;
}
function category(data: LedgerData, id: string): Category {
  const result = data.categories.find((item: Category) => item.id === id);
  if (result === undefined) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
  return result;
}
export function accountBalance(data: LedgerData, accountId: string): number {
  let balance = account(data, accountId).initialBalanceCents;
  data.entries.forEach((item) => {
    if (item.accountId === accountId) {
      assertAmount(item.amountCents);
      balance = addCents(balance, item.type === 'income' ? item.amountCents : -item.amountCents);
    }
  });
  data.transfers.forEach((item) => {
    assertAmount(item.amountCents);
    if (item.fromAccountId === accountId) { balance = addCents(balance, -item.amountCents); }
    if (item.toAccountId === accountId) { balance = addCents(balance, item.amountCents); }
  });
  return addCents(balance, 0);
}
// Validate the proposed complete snapshot before a transaction commits, not only the edited row.
export function validateLedger(data: LedgerData): void {
  entity(data.version === 2);
  uniqueIds(data.accounts.map((item) => item.id));
  uniqueIds(data.categories.map((item) => item.id));
  uniqueIds(data.entries.map((item) => item.id));
  uniqueIds(data.transfers.map((item) => item.id));
  uniqueIds(data.budgets.map((item) => item.id));
  uniqueIds(data.attachments.map((item) => item.id));
  const accounts = new Map<string, Account>();
  const categories = new Map<string, Category>();
  const balances = new Map<string, number>();
  const assets = new Set(data.attachments.map((item) => item.id));
  data.accounts.forEach((item) => {
    accounts.set(item.id, item); balances.set(item.id, item.initialBalanceCents);
    entity(item.type === 'standard' || item.type === 'credit');
    entity(typeof item.name === 'string' && item.name.trim().length > 0 && typeof item.needsInitialBalance === 'boolean');
    if (!Number.isSafeInteger(item.initialBalanceCents) || Math.abs(item.initialBalanceCents) > MAX_AMOUNT_CENTS) {
      throw new LedgerError('INVALID_AMOUNT');
    }
    if (item.type !== 'credit' && item.initialBalanceCents < 0) { throw new LedgerError('NEGATIVE_BALANCE'); }
    timestamps(item.createdAt, item.updatedAt);
  });
  data.categories.forEach((item) => {
    categories.set(item.id, item);
    entity(item.type === 'income' || item.type === 'expense');
    entity(item.name.trim().length > 0 && item.iconKey.trim().length > 0 && Number.isSafeInteger(item.sortOrder) && item.sortOrder >= 0);
    timestamps(item.createdAt, item.updatedAt);
  });
  data.attachments.forEach((item) => {
    entity(/^images\/img_[A-Za-z0-9_-]+\.jpg$/.test(item.relativePath));
  });
  data.entries.forEach((item) => {
    entity(item.type === 'income' || item.type === 'expense');
    assertAmount(item.amountCents);
    if (!accounts.has(item.accountId) || !categories.has(item.categoryId)) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
    balances.set(item.accountId, addCents(balances.get(item.accountId)!, item.type === 'income' ? item.amountCents : -item.amountCents));
    if (categories.get(item.categoryId)!.type !== item.type) { throw new LedgerError('CATEGORY_TYPE_MISMATCH'); }
    dateTime(item.date, item.time); timestamps(item.createdAt, item.updatedAt);
    entity(typeof item.note === 'string' && item.attachmentIds.length <= 9);
    uniqueIds(item.attachmentIds);
    item.attachmentIds.forEach((id: string) => {
      if (!assets.has(id)) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
    });
  });
  data.transfers.forEach((item) => {
    if (item.fromAccountId === item.toAccountId) { throw new LedgerError('INVALID_TRANSFER'); }
    if (!accounts.has(item.fromAccountId) || !accounts.has(item.toAccountId)) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
    assertAmount(item.amountCents);
    balances.set(item.fromAccountId, addCents(balances.get(item.fromAccountId)!, -item.amountCents));
    balances.set(item.toAccountId, addCents(balances.get(item.toAccountId)!, item.amountCents));
    dateTime(item.date, item.time); timestamps(item.createdAt, item.updatedAt); entity(typeof item.note === 'string');
  });
  data.budgets.forEach((item) => {
    assertAmount(item.amountCents);
    assertRange({ startDate: item.startDate, endDate: item.endDate });
    timestamps(item.createdAt, item.updatedAt);
    entity(item.scope === 'total' || item.scope === 'category');
    entity(item.period === 'month' || item.period === 'week' || item.period === 'custom');
    if (item.scope === 'total') { entity(item.categoryId === null); }
    else {
      if (item.categoryId === null) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
      if (!categories.has(item.categoryId)) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
      if (categories.get(item.categoryId)!.type !== 'expense') { throw new LedgerError('CATEGORY_TYPE_MISMATCH'); }
    }
    if (item.period !== 'custom') {
      const range = item.period === 'month' ? calendarMonth(item.startDate) : calendarWeek(item.startDate);
      if (item.startDate !== range.startDate || item.endDate !== range.endDate) { throw new LedgerError('INVALID_DATE'); }
    }
  });
  data.accounts.forEach((item) => {
    const balance = balances.get(item.id)!;
    if (balance < 0 && item.type !== 'credit') { throw new LedgerError('NEGATIVE_BALANCE'); }
  });
}
export function assertAccountRemovable(data: LedgerData, id: string): void {
  account(data, id);
  if (data.entries.some((item) => item.accountId === id) ||
    data.transfers.some((item) => item.fromAccountId === id || item.toAccountId === id)) {
    throw new LedgerError('REFERENCE_IN_USE');
  }
}
export function assertCategoryRemovable(data: LedgerData, id: string): void {
  category(data, id);
  if (data.entries.some((item) => item.categoryId === id) || data.budgets.some((item) => item.categoryId === id)) {
    throw new LedgerError('REFERENCE_IN_USE');
  }
}
export function validateFilter(filter: LedgerFilter): void {
  entity(filter.type === null || filter.type === 'income' || filter.type === 'expense');
  uniqueIds(filter.accountIds); uniqueIds(filter.categoryIds);
  entity(Number.isInteger(filter.pageSize) && filter.pageSize > 0 && filter.pageSize <= 200);
  entity(typeof filter.keyword === 'string');
  if (filter.range !== null) { assertRange(filter.range); }
  if (filter.minAmountCents !== null) { assertAmount(filter.minAmountCents); }
  if (filter.maxAmountCents !== null) { assertAmount(filter.maxAmountCents); }
  if (filter.minAmountCents !== null && filter.maxAmountCents !== null && filter.minAmountCents > filter.maxAmountCents) {
    throw new LedgerError('INVALID_AMOUNT');
  }
  if (filter.cursor !== null) {
    dateTime(filter.cursor.date, filter.cursor.time); entity(filter.cursor.id.trim().length > 0);
  }
}
