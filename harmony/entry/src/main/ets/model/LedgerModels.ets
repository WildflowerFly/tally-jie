// v2 contract. v1 AppData remains a read-only migration input, not a v2 alias.
export type AccountType = 'standard' | 'credit';
export type EntryType = 'income' | 'expense';
export type BudgetPeriod = 'month' | 'week' | 'custom';
export type BudgetScope = 'total' | 'category';

// Optional presentation metadata keeps existing v2 ledgers/backups compatible.
export interface AccountAppearance { englishName: string; holder: string; iconKey?: string; }
export interface Account {
  englishName?: string;
  holder?: string;
  iconKey?: string;
  id: string;
  name: string;
  type: AccountType;
  initialBalanceCents: number;
  needsInitialBalance: boolean;
  createdAt: string | null;
  updatedAt: string;
}
export interface Category {
  id: string;
  type: EntryType;
  name: string;
  iconKey: string;
  sortOrder: number;
  createdAt: string | null;
  updatedAt: string;
}
export interface LedgerEntry {
  id: string;
  type: EntryType;
  amountCents: number;
  accountId: string;
  categoryId: string;
  date: string;
  time: string;
  note: string;
  attachmentIds: string[];
  createdAt: string | null;
  updatedAt: string;
}
export interface Transfer {
  id: string;
  fromAccountId: string;
  toAccountId: string;
  amountCents: number;
  date: string;
  time: string;
  note: string;
  createdAt: string | null;
  updatedAt: string;
}
export interface BudgetRule {
  id: string;
  scope: BudgetScope;
  categoryId: string | null;
  amountCents: number;
  period: BudgetPeriod;
  startDate: string;
  endDate: string;
  createdAt: string | null;
  updatedAt: string;
}
export interface LegacyAttachment {
  id: string;
  relativePath: string;
}
export interface LedgerData {
  version: number;
  accounts: Account[];
  categories: Category[];
  entries: LedgerEntry[];
  transfers: Transfer[];
  budgets: BudgetRule[];
  attachments: LegacyAttachment[];
}
export interface DateRange {
  startDate: string;
  endDate: string;
}
// Descending (date, time, id); cursor is exclusive. Query services enforce all filters.
export interface LedgerCursor {
  date: string;
  time: string;
  id: string;
}
export interface LedgerFilter {
  type: EntryType | null;
  accountIds: string[];
  categoryIds: string[];
  range: DateRange | null;
  minAmountCents: number | null;
  maxAmountCents: number | null;
  keyword: string;
  cursor: LedgerCursor | null;
  pageSize: number;
}
export type LedgerErrorCode = 'INVALID_AMOUNT' | 'AMOUNT_OVERFLOW' | 'INVALID_DATE' |
  'INVALID_ENTITY' | 'DUPLICATE_ID' | 'REFERENCE_NOT_FOUND' | 'REFERENCE_IN_USE' |
  'CATEGORY_TYPE_MISMATCH' | 'NEGATIVE_BALANCE' | 'INVALID_TRANSFER' |
  'BUDGET_OVERLAP' | 'IMPORT_CONFLICT';
export class LedgerError extends Error {
  code: LedgerErrorCode;
  constructor(code: LedgerErrorCode) {
    super(code);
    this.name = 'LedgerError';
    this.code = code;
  }
}
export function emptyLedger(): LedgerData {
  return { version: 2, accounts: [], categories: [], entries: [], transfers: [], budgets: [], attachments: [] };
}
