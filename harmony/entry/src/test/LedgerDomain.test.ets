import { describe, it, expect } from '@ohos/hypium';
import { Account, BudgetRule, Category, LedgerData, LedgerEntry, LedgerError, LedgerFilter, Transfer, emptyLedger } from '../main/ets/model/LedgerModels';
import { MAX_AMOUNT_CENTS, addCents, parseAmount, parseInitialBalance } from '../main/ets/domain/Money';
import { calendarMonth, calendarWeek, containsDate, isLedgerDate, rangeDays } from '../main/ets/domain/DateRange';
import { accountBalance, assertAccountRemovable, assertCategoryRemovable, validateFilter, validateLedger } from '../main/ets/domain/LedgerRules';

const STAMP: string = '2026-11-17T00:00:00.000Z';
function rejects(action: () => void, code: string): void {
  let actual: string = '';
  try { action(); } catch (error) { actual = (error as LedgerError).code; }
  expect(actual).assertEqual(code);
}
function sample(): LedgerData {
  const data = emptyLedger();
  const cash: Account = { id: 'cash', name: '现金', type: 'standard', initialBalanceCents: 10000,
    needsInitialBalance: false, createdAt: STAMP, updatedAt: STAMP };
  const card: Account = { id: 'card', name: '信用卡', type: 'credit', initialBalanceCents: -2000,
    needsInitialBalance: false, createdAt: STAMP, updatedAt: STAMP };
  const expense: Category = { id: 'expense', type: 'expense', name: '其他', iconKey: 'other', sortOrder: 0,
    createdAt: STAMP, updatedAt: STAMP };
  const income: Category = { id: 'income', type: 'income', name: '其他', iconKey: 'other', sortOrder: 0,
    createdAt: STAMP, updatedAt: STAMP };
  const entry: LedgerEntry = { id: 'e1', type: 'expense', amountCents: 1000, accountId: 'cash',
    categoryId: 'expense', date: '2026-11-17', time: '12:30', note: '测试', attachmentIds: [],
    createdAt: null, updatedAt: STAMP };
  data.accounts = [cash, card]; data.categories = [expense, income]; data.entries = [entry];
  return data;
}
function transfer(): Transfer {
  return { id: 't1', fromAccountId: 'cash', toAccountId: 'card', amountCents: 3000,
    date: '2026-11-17', time: '13:00', note: '', createdAt: STAMP, updatedAt: STAMP };
}
function budget(id: string): BudgetRule {
  return { id: id, scope: 'total', categoryId: null, amountCents: 10000, period: 'month',
    startDate: '2026-11-01', endDate: '2026-11-30', createdAt: STAMP, updatedAt: STAMP };
}
export default function ledgerDomainTest() {
  describe('LedgerDomain', () => {
    it('decimalAmountsAreIntegerCents', 0, () => {
      expect(addCents(parseAmount('0.10'), parseAmount('0.20'))).assertEqual(30);
      expect(parseAmount('999999999.99')).assertEqual(MAX_AMOUNT_CENTS);
    });
    it('rejectsInvalidAmountSyntaxAndOverflow', 0, () => {
      const invalid: string[] = ['', '0', '-1', '1.001', '1e2', ' 1', '+1', '01', '1000000000'];
      invalid.forEach((value: string) => rejects(() => { parseAmount(value); }, 'INVALID_AMOUNT'));
      rejects(() => { addCents(Number.MAX_SAFE_INTEGER, 1); }, 'AMOUNT_OVERFLOW');
      rejects(() => { addCents(0.1, 1); }, 'AMOUNT_OVERFLOW');
      rejects(() => { addCents(-Number.MAX_SAFE_INTEGER, -1); }, 'AMOUNT_OVERFLOW');
    });
    it('onlyCreditInitialBalanceMayBeNegative', 0, () => {
      expect(parseInitialBalance('', 'standard')).assertEqual(0);
      expect(parseInitialBalance('0.00', 'standard')).assertEqual(0);
      expect(parseInitialBalance('-0.01', 'credit')).assertEqual(-1);
      rejects(() => { parseInitialBalance('-1', 'standard'); }, 'NEGATIVE_BALANCE');
      rejects(() => { parseInitialBalance('-1e2', 'credit'); }, 'INVALID_AMOUNT');
    });
    it('calendarDatesAndMondayWeekAreStable', 0, () => {
      expect(isLedgerDate('2024-02-29')).assertTrue();
      expect(isLedgerDate('2023-02-29')).assertFalse();
      expect(isLedgerDate('2026-13-01')).assertFalse();
      expect(isLedgerDate('2026-2-01')).assertFalse();
      expect(calendarWeek('2021-01-01').startDate).assertEqual('2020-12-28');
      expect(calendarWeek('2021-01-03').endDate).assertEqual('2021-01-03');
      expect(calendarWeek('2021-01-04').startDate).assertEqual('2021-01-04');
      expect(calendarMonth('2024-02-29').endDate).assertEqual('2024-02-29');
      expect(rangeDays(calendarMonth('2024-02-10'))).assertEqual(29);
      expect(containsDate(calendarMonth('2024-02-10'), '2024-02-01')).assertTrue();
      expect(containsDate(calendarMonth('2024-02-10'), '2024-03-01')).assertFalse();
      rejects(() => { rangeDays({ startDate: '2024-03-01', endDate: '2024-02-29' }); }, 'INVALID_DATE');
    });
    it('balancesTransfersAndRenameUseStableIds', 0, () => {
      const data = sample(); validateLedger(data);
      expect(accountBalance(data, 'cash')).assertEqual(9000);
      data.transfers.push(transfer()); validateLedger(data);
      expect(accountBalance(data, 'cash')).assertEqual(6000);
      expect(accountBalance(data, 'card')).assertEqual(1000);
      data.accounts[0].name = '重命名'; data.categories[0].name = '改名';
      expect(accountBalance(data, 'cash')).assertEqual(6000);
      data.transfers = [];
      expect(accountBalance(data, 'card')).assertEqual(-2000);
    });
    it('rejectsReferencesDuplicatesAndCategoryMismatch', 0, () => {
      let data = sample(); data.entries[0].accountId = 'missing';
      rejects(() => validateLedger(data), 'REFERENCE_NOT_FOUND');
      data = sample(); data.entries[0].categoryId = 'income';
      rejects(() => validateLedger(data), 'CATEGORY_TYPE_MISMATCH');
      data = sample(); data.entries.push(data.entries[0]);
      rejects(() => validateLedger(data), 'DUPLICATE_ID');
      data = sample(); data.accounts.push(data.accounts[0]);
      rejects(() => validateLedger(data), 'DUPLICATE_ID');
      data = sample(); data.entries[0].attachmentIds = ['missing'];
      rejects(() => validateLedger(data), 'REFERENCE_NOT_FOUND');
      rejects(() => assertAccountRemovable(sample(), 'cash'), 'REFERENCE_IN_USE');
      rejects(() => assertCategoryRemovable(sample(), 'expense'), 'REFERENCE_IN_USE');
    });
    it('negativeStandardBalanceIsRejectedAfterEveryMutation', 0, () => {
      let data = sample(); data.entries[0].amountCents = 10001;
      rejects(() => validateLedger(data), 'NEGATIVE_BALANCE');
      data = sample(); data.accounts[0].initialBalanceCents = -1;
      rejects(() => validateLedger(data), 'NEGATIVE_BALANCE');
      data = sample(); const move = transfer(); move.amountCents = 9001; data.transfers = [move];
      rejects(() => validateLedger(data), 'NEGATIVE_BALANCE');
      data = sample(); data.accounts[1].type = 'standard';
      rejects(() => validateLedger(data), 'NEGATIVE_BALANCE');
      data = sample(); data.accounts[1].initialBalanceCents = 0; data.accounts[1].type = 'standard';
      data.entries[0].accountId = 'card';
      rejects(() => validateLedger(data), 'NEGATIVE_BALANCE');
    });
    it('removingIncomeOrIncomingTransferCannotOverdrawStandardAccount', 0, () => {
      const data = sample(); data.accounts[0].initialBalanceCents = 0;
      const income: LedgerEntry = { id: 'e2', type: 'income', amountCents: 1000, accountId: 'cash',
        categoryId: 'income', date: '2026-11-17', time: '11:00', note: '', attachmentIds: [],
        createdAt: STAMP, updatedAt: STAMP };
      data.entries.push(income); validateLedger(data);
      data.entries.pop(); rejects(() => validateLedger(data), 'NEGATIVE_BALANCE');
      const move = transfer(); move.fromAccountId = 'card'; move.toAccountId = 'cash';
      data.transfers = [move]; validateLedger(data);
      data.transfers = []; rejects(() => validateLedger(data), 'NEGATIVE_BALANCE');
    });
    it('entityIdentityAndHistoricalAttachmentsArePreserved', 0, () => {
      const data = sample();
      data.attachments = [{ id: 'asset1', relativePath: 'images/img_test_1.jpg' }];
      data.entries[0].attachmentIds = ['asset1']; validateLedger(data);
      expect(data.entries[0].createdAt === null).assertTrue();
      data.attachments[0].relativePath = '../secret.jpg';
      rejects(() => validateLedger(data), 'INVALID_ENTITY');
      data.attachments[0].relativePath = 'images/img_test_1.jpg';
      data.accounts[0].updatedAt = '2026-02-30T00:00:00.000Z';
      rejects(() => validateLedger(data), 'INVALID_ENTITY');
    });
    it('transferAndBalanceOverflowAreRejected', 0, () => {
      let data = sample(); const move = transfer(); move.toAccountId = 'cash'; data.transfers = [move];
      rejects(() => validateLedger(data), 'INVALID_TRANSFER');
      data = sample(); data.accounts[0].initialBalanceCents = Number.MAX_SAFE_INTEGER;
      rejects(() => validateLedger(data), 'INVALID_AMOUNT');
      data = sample(); data.entries[0].amountCents = 0;
      rejects(() => validateLedger(data), 'INVALID_AMOUNT');
    });
    it('budgetPeriodShapeIsCheckedWithoutFreezingPendingOverlapPolicy', 0, () => {
      const data = sample(); data.budgets = [budget('b1')]; validateLedger(data);
      data.budgets[0].startDate = '2026-11-02';
      rejects(() => validateLedger(data), 'INVALID_DATE');
      data.budgets[0] = budget('b1'); data.budgets[0].scope = 'category'; data.budgets[0].categoryId = 'income';
      rejects(() => validateLedger(data), 'CATEGORY_TYPE_MISMATCH');
      data.budgets[0] = budget('b1'); data.budgets[0].period = 'week';
      data.budgets[0].startDate = '2026-11-16'; data.budgets[0].endDate = '2026-11-22'; validateLedger(data);
    });
    it('legacyInitialZeroRequiresExplicitPromptAndDoesNotBypassBalanceRule', 0, () => {
      const data = sample(); data.accounts[0].initialBalanceCents = 0; data.accounts[0].needsInitialBalance = true;
      rejects(() => validateLedger(data), 'NEGATIVE_BALANCE');
      data.entries = []; validateLedger(data);
      expect(data.accounts[0].needsInitialBalance).assertTrue();
    });
    it('filterRangeCursorAndAmountsAreValidated', 0, () => {
      const filter: LedgerFilter = { type: null, accountIds: [], categoryIds: [], range: null,
        minAmountCents: null, maxAmountCents: null, keyword: '', cursor: null, pageSize: 50 };
      validateFilter(filter); filter.minAmountCents = 100; filter.maxAmountCents = 50;
      rejects(() => validateFilter(filter), 'INVALID_AMOUNT');
      filter.maxAmountCents = 200; filter.cursor = { date: '2026-11-17', time: '25:00', id: 'e1' };
      rejects(() => validateFilter(filter), 'INVALID_DATE');
    });
  });
}
