import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger, LedgerData } from '../main/ets/model/LedgerModels';
import { saveBudget, budgetUsage, removeBudget, BudgetInput, monthlyTotalBudget, saveMonthlyBudget } from '../main/ets/service/BudgetService';
function rejects(action: () => void): boolean { try { action(); return false; } catch (_) { return true; } }
export default function budgetTest() {
  describe('Budget', () => {
    it('overlapRejectedButTotalAndCategoryIndependent', 0, () => {
      const now = '2026-11-17T00:00:00.000Z'; const data = emptyLedger();
      data.categories.push({ id: 'c', name: '餐', type: 'expense', iconKey: 'food', sortOrder: 0, createdAt: now, updatedAt: now });
      const input: BudgetInput = { id: 'b', categoryId: null, amount: '1000', period: 'month', startDate: '2024-02-17', endDate: '' };
      const next = saveBudget(data, input, now);
      expect(next.budgets[0].endDate).assertEqual('2024-02-29'); expect(data.budgets.length).assertEqual(0);
      input.id = 'b2'; expect(rejects(() => { saveBudget(next, input, now); })).assertTrue();
      input.categoryId = 'c'; expect(saveBudget(next, input, now).budgets.length).assertEqual(2);
      input.amount = '0'; expect(rejects(() => { saveBudget(data, input, now); })).assertTrue();
      expect(removeBudget(next, 'b').budgets.length).assertEqual(0);
    });
    it('monthlyEditorCreatesThenUpdatesSameRuleWithoutChangingLedger', 0, () => {
      const now = '2026-11-18T00:00:00.000Z';
      const data = emptyLedger();
      data.categories.push({ id: 'c', name: '餐', type: 'expense', iconKey: 'food', sortOrder: 0, createdAt: now, updatedAt: now });
      const categorized = saveBudget(data, { id: 'category', categoryId: 'c', amount: '300', period: 'month',
        startDate: '2024-02-01', endDate: '' }, now);
      const created = saveMonthlyBudget(categorized, '3500.01', '2024-02-17', 'month', now);
      const monthly = monthlyTotalBudget(created, '2024-02-29')!;
      expect(monthly.id).assertEqual('month');
      expect(monthly.startDate).assertEqual('2024-02-01');
      expect(monthly.endDate).assertEqual('2024-02-29');
      expect(monthly.amountCents).assertEqual(350001);
      expect(categorized.budgets.length).assertEqual(1);
      const edited = saveMonthlyBudget(created, '4000', '2024-02-18', 'unused-new-id', '2026-11-19T00:00:00.000Z');
      expect(edited.budgets.length).assertEqual(2);
      expect(monthlyTotalBudget(edited, '2024-02-18')!.id).assertEqual('month');
      expect(monthlyTotalBudget(edited, '2024-02-18')!.amountCents).assertEqual(400000);
      expect(monthlyTotalBudget(edited, '2024-02-18')!.createdAt).assertEqual(now);
      expect(monthlyTotalBudget(edited, '2024-02-18')!.updatedAt).assertEqual('2026-11-19T00:00:00.000Z');
      expect(edited.budgets[0].amountCents).assertEqual(30000);
      expect(JSON.stringify(edited.entries)).assertEqual(JSON.stringify(created.entries));
      expect(JSON.stringify(edited.accounts)).assertEqual(JSON.stringify(created.accounts));
      expect(monthlyTotalBudget(edited, '2024-03-01') === undefined).assertTrue();
    });
    it('monthlyEditorRejectsBadAmountsAndOverlappingTotalBudgetWithoutMutation', 0, () => {
      const now = '2026-11-18T00:00:00.000Z';
      const data = emptyLedger();
      const values: string[] = ['', '0', '-1', '1.234', '1000000000000000000'];
      values.forEach((amount: string) => {
        expect(rejects(() => { saveMonthlyBudget(data, amount, '2026-11-18', 'month', now); })).assertTrue();
        expect(data.budgets.length).assertEqual(0);
      });
      const weekly = saveBudget(data, { id: 'week', categoryId: null, amount: '200', period: 'week',
        startDate: '2026-11-18', endDate: '' }, now);
      expect(monthlyTotalBudget(weekly, '2026-11-18') === undefined).assertTrue();
      expect(rejects(() => { saveMonthlyBudget(weekly, '3500', '2026-11-18', 'month', now); })).assertTrue();
      expect(weekly.budgets.length).assertEqual(1);
      expect(weekly.budgets[0].amountCents).assertEqual(20000);
    });
    it('usageOnlyExpensesUnclampedAndRefreshAfterDelete', 0, () => {
      const now = '2026-11-17T00:00:00.000Z'; let data: LedgerData = emptyLedger();
      data = saveBudget(data, { id: 'b', categoryId: null, amount: '1000', period: 'week', startDate: '2025-01-01', endDate: '' }, now);
      for (let i = 0; i < 4; i++) { data.entries.push({ id: `${i}`, type: 'expense', amountCents: 30000, categoryId: 'c', accountId: 'a',
        date: '2025-01-01', time: '12:00', note: '', attachmentIds: [], createdAt: now, updatedAt: now }); }
      expect(budgetUsage(data, data.budgets[0]).percent).assertEqual(120);
      expect(budgetUsage(data, data.budgets[0]).remainingCents).assertEqual(-20000);
      data.entries.pop(); expect(budgetUsage(data, data.budgets[0]).percent).assertEqual(90);
      expect(budgetUsage(data, data.budgets[0]).remainingCents).assertEqual(10000);
      data.entries[0].type = 'income'; expect(budgetUsage(data, data.budgets[0]).usedCents).assertEqual(60000);
    });
  });
}
