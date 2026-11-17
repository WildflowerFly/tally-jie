import { AccountType, LedgerError } from '../model/LedgerModels';

export const MAX_AMOUNT_CENTS: number = 99999999999;
function unsignedCents(value: string): number {
  if (!/^(0|[1-9]\d{0,8})(\.\d{1,2})?$/.test(value)) {
    throw new LedgerError('INVALID_AMOUNT');
  }
  const parts = value.split('.');
  const fraction = parts.length === 2 ? (parts[1] + '00').slice(0, 2) : '00';
  const cents = Number(parts[0]) * 100 + Number(fraction);
  if (!Number.isSafeInteger(cents) || cents > MAX_AMOUNT_CENTS) {
    throw new LedgerError('INVALID_AMOUNT');
  }
  return cents;
}
export function assertAmount(value: number): void {
  if (!Number.isSafeInteger(value) || value <= 0 || value > MAX_AMOUNT_CENTS) {
    throw new LedgerError('INVALID_AMOUNT');
  }
}
export function parseAmount(value: string): number {
  const cents = unsignedCents(value);
  assertAmount(cents);
  return cents;
}
export function parseInitialBalance(value: string, type: AccountType): number {
  if (type !== 'standard' && type !== 'credit') { throw new LedgerError('INVALID_ENTITY'); }
  if (value === '') { return 0; }
  const negative = value.startsWith('-');
  const cents = unsignedCents(negative ? value.slice(1) : value);
  if (negative && cents > 0 && type !== 'credit') { throw new LedgerError('NEGATIVE_BALANCE'); }
  return cents === 0 ? 0 : (negative ? -cents : cents);
}
export function addCents(left: number, right: number): number {
  const sum = left + right;
  if (!Number.isSafeInteger(left) || !Number.isSafeInteger(right) || !Number.isSafeInteger(sum)) {
    throw new LedgerError('AMOUNT_OVERFLOW');
  }
  return sum;
}
