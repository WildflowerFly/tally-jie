import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger, LedgerData } from '../main/ets/model/LedgerModels';
import { saveBudget, budgetUsage, removeBudget, BudgetInput } from '../main/ets/service/BudgetService';
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
