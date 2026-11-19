import { LedgerData, AccountType, Account, AccountAppearance, LedgerError } from '../model/LedgerModels';
import { validateLedger, assertAccountRemovable } from '../domain/LedgerRules';
import { parseInitialBalance } from '../domain/Money';

export interface AccountReferences { entries: number; transfers: number; }
export function accountReferences(data: LedgerData, id: string): AccountReferences {
  return { entries: data.entries.filter((row) => row.accountId === id).length,
    transfers: data.transfers.filter((row) => row.fromAccountId === id || row.toAccountId === id).length };
}
export function upsertAccount(data: LedgerData, id: string, name: string, type: AccountType,
  initial: string, now: string, appearance?: AccountAppearance): LedgerData {
  const next: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
  const trimmed = name.trim();
  if (trimmed.length === 0 || trimmed.length > 40 || next.accounts.some((row) => row.id !== id && row.name === trimmed)) {
    throw new LedgerError('INVALID_ENTITY');
  }
  const old = next.accounts.find((row) => row.id === id);
  const account: Account = { id: id, name: trimmed, type: type,
    initialBalanceCents: parseInitialBalance(initial, type), needsInitialBalance: false,
    createdAt: old === undefined ? now : old.createdAt, updatedAt: now };
  // Legacy callers editing balances/names must not erase the card metadata.
  const englishName = appearance === undefined ? old?.englishName : appearance.englishName.trim();
  const holder = appearance === undefined ? old?.holder : appearance.holder.trim();
  const iconKey = appearance === undefined ? old?.iconKey : appearance.iconKey;
  if (englishName !== undefined) { account.englishName = englishName; }
  if (holder !== undefined) { account.holder = holder; }
  if (iconKey !== undefined) { account.iconKey = iconKey; }
  if (old === undefined) { next.accounts.push(account); }
  else { next.accounts[next.accounts.findIndex((row) => row.id === id)] = account; }
  validateLedger(next); return next;
}
// Explicit migration moves history, NOT opening balances. The confirmation UI explains this.
export function removeAccount(data: LedgerData, id: string, targetId: string | null = null): LedgerData {
  const next: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
  if (!next.accounts.some((row) => row.id === id)) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
  if (targetId === null) { assertAccountRemovable(next, id); }
  else {
    if (targetId === id || !next.accounts.some((row) => row.id === targetId)) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
    next.entries.forEach((row) => { if (row.accountId === id) { row.accountId = targetId; } });
    next.transfers.forEach((row) => {
      if (row.fromAccountId === id) { row.fromAccountId = targetId; }
      if (row.toAccountId === id) { row.toAccountId = targetId; }
    });
  }
  next.accounts = next.accounts.filter((row) => row.id !== id);
  validateLedger(next); return next;
}
