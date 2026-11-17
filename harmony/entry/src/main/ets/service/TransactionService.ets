import { LedgerData, EntryType, LedgerEntry, LedgerError } from '../model/LedgerModels';
import { validateLedger } from '../domain/LedgerRules';
import { parseAmount } from '../domain/Money';
export interface EntryInput {
  id: string; type: EntryType; amount: string; accountId: string; categoryId: string;
  date: string; time: string; note: string;
}
export function saveEntry(data: LedgerData, input: EntryInput, now: string): LedgerData {
  const next: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
  const old = next.entries.find((row) => row.id === input.id);
  if (input.note.length > 500) { throw new LedgerError('INVALID_ENTITY'); }
  const row: LedgerEntry = { id: input.id, type: input.type, amountCents: parseAmount(input.amount),
    accountId: input.accountId, categoryId: input.categoryId, date: input.date, time: input.time, note: input.note,
    attachmentIds: old === undefined ? [] : old.attachmentIds.slice(),
    createdAt: old === undefined ? now : old.createdAt, updatedAt: now };
  if (old === undefined) { next.entries.push(row); }
  else { next.entries[next.entries.findIndex((item) => item.id === input.id)] = row; }
  validateLedger(next); return next;
}
export function deleteEntry(data: LedgerData, id: string): LedgerData {
  if (!data.entries.some((row) => row.id === id)) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
  const next: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
  next.entries = next.entries.filter((row) => row.id !== id);
  validateLedger(next); return next;
}
export function keypadAmount(value: string, key: string): string {
  if (key === 'back') { return value.slice(0, -1); }
  if (key === '.') { return value.includes('.') ? value : (value || '0') + '.'; }
  if (!/^\d$/.test(key)) { return value; }
  const next = value === '0' ? key : value + key;
  return /^\d{1,9}(\.\d{0,2})?$/.test(next) ? next : value;
}
