import { AppData, validateData, ACCOUNTS, EXPENSE_CATEGORIES, INCOME_CATEGORIES } from '../model/AppData';
import { LedgerData, LedgerError, EntryType, emptyLedger } from '../model/LedgerModels';
import { accountBalance, validateLedger } from '../domain/LedgerRules';
import { parseInitialBalance } from '../domain/Money';
import { calendarMonth } from '../domain/DateRange';

export interface MigrationDraft {
  data: LedgerData;
  requiredAccountIds: string[];
  archivedDiaryCount: number;
}
export interface InitialBalanceInput { accountId: string; amount: string; }
export function buildLegacyMigration(source: AppData, now: string): MigrationDraft {
  // Validate before constructing anything; a malformed source must not become an empty ledger.
  validateData(source);
  const data = emptyLedger();
  ACCOUNTS.forEach((name: string, index: number) => {
    data.accounts.push({ id: `legacy-account-${index}`, name: name, type: name === '信用卡' ? 'credit' : 'standard',
      initialBalanceCents: 0, needsInitialBalance: true, createdAt: null, updatedAt: now });
  });
  const types: EntryType[] = ['expense', 'income'];
  types.forEach((type: EntryType) => {
    const names = type === 'expense' ? EXPENSE_CATEGORIES : INCOME_CATEGORIES;
    names.forEach((name: string, index: number) => {
      data.categories.push({ id: `legacy-${type}-${index}`, type: type, name: name, iconKey: 'category',
        sortOrder: index, createdAt: null, updatedAt: now });
    });
  });
  source.transactions.forEach((row) => {
    const type: EntryType = row.type === 'income' ? 'income' : 'expense';
    const targetAccount = data.accounts.find((item) => item.name === row.account)!;
    const targetCategory = data.categories.find((item) => item.name === row.category && item.type === type)!;
    row.images.forEach((name: string) => {
      if (!data.attachments.some((item) => item.id === name)) {
        data.attachments.push({ id: name, relativePath: `images/${name}` });
      }
    });
    data.entries.push({ id: row.id, type: type, amountCents: row.amount, accountId: targetAccount.id,
      categoryId: targetCategory.id, date: row.date, time: row.time, note: row.note,
      attachmentIds: row.images.slice(), createdAt: null, updatedAt: now });
  });
  source.budgets.forEach((row) => {
    const range = calendarMonth(`${row.month}-01`);
    data.budgets.push({ id: `legacy-budget-${row.month}`, scope: 'total', categoryId: null, amountCents: row.amount,
      period: 'month', startDate: range.startDate, endDate: range.endDate, createdAt: null, updatedAt: now });
  });
  const required = data.accounts.filter((item) => item.type === 'standard' && accountBalance(data, item.id) < 0).map((item) => item.id);
  // Negative standard historical balances are not silently accepted. The draft is not a live ledger.
  if (required.length === 0) { validateLedger(data); }
  return { data: data, requiredAccountIds: required, archivedDiaryCount: source.diaries.length };
}
export function applyInitialBalances(draft: MigrationDraft, inputs: InitialBalanceInput[]): LedgerData {
  const next: LedgerData = JSON.parse(JSON.stringify(draft.data)) as LedgerData;
  const seen: Set<string> = new Set<string>();
  inputs.forEach((input) => {
    if (seen.has(input.accountId)) { throw new LedgerError('DUPLICATE_ID'); }
    seen.add(input.accountId);
    const target = next.accounts.find((item) => item.id === input.accountId);
    if (target === undefined) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
    target.initialBalanceCents = parseInitialBalance(input.amount, target.type);
    target.needsInitialBalance = false;
  });
  validateLedger(next);
  return next;
}
