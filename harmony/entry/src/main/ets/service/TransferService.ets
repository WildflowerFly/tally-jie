import { LedgerData, Transfer, LedgerError } from '../model/LedgerModels';
import { parseAmount } from '../domain/Money';
import { validateLedger } from '../domain/LedgerRules';
export interface TransferInput { id: string; fromAccountId: string; toAccountId: string; amount: string; date: string; time: string; note: string; }
export function saveTransfer(data: LedgerData, input: TransferInput, now: string): LedgerData {
  const next: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
  const old = next.transfers.find((row) => row.id === input.id);
  if (input.note.length > 500) { throw new LedgerError('INVALID_ENTITY'); }
  const row: Transfer = { id: input.id, fromAccountId: input.fromAccountId, toAccountId: input.toAccountId,
    amountCents: parseAmount(input.amount), date: input.date, time: input.time, note: input.note,
    createdAt: old === undefined ? now : old.createdAt, updatedAt: now };
  if (old === undefined) { next.transfers.push(row); } else { next.transfers[next.transfers.findIndex((item) => item.id === row.id)] = row; }
  validateLedger(next); return next;
}
export function deleteTransfer(data: LedgerData, id: string): LedgerData {
  if (!data.transfers.some((row) => row.id === id)) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
  const next: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
  next.transfers = next.transfers.filter((row) => row.id !== id); validateLedger(next); return next;
}
