import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger } from '../main/ets/model/LedgerModels';
import { upsertAccount } from '../main/ets/service/AccountService';
import { upsertCategory } from '../main/ets/service/CategoryService';
import { saveEntry, deleteEntry } from '../main/ets/service/TransactionService';
import { saveBudget, budgetUsage } from '../main/ets/service/BudgetService';
import { validateLedger, accountBalance } from '../main/ets/domain/LedgerRules';
import { exportJson, previewJson } from '../main/ets/service/DataExchangeService';
import { queryEntries, defaultFilter } from '../main/ets/service/LedgerQueryService';
import { statistics } from '../main/ets/service/StatisticsService';
export default function ledgerIntegrationTest() {
  describe('LedgerIntegration', () => {
    it('wholeDomainWorkflowMatchesIndependentIntegerExpectations', 0, () => {
      const now = '2026-11-17T00:00:00.000Z';
      let data = upsertAccount(emptyLedger(), 'a', '现金', 'standard', '1000', now);
      data = upsertAccount(data, 'b', '储蓄', 'standard', '200', now);
      data = upsertCategory(data, 'c', '餐饮', 'expense', 'food', 0, now);
      data = upsertCategory(data, 'salary', '工资', 'income', 'salary', 0, now);
      data = saveBudget(data, { id: 'budget', categoryId: null, amount: '80', period: 'month', startDate: '2026-11-17', endDate: '' }, now);
      data = saveEntry(data, { id: 'expense', type: 'expense', amount: '100', accountId: 'a', categoryId: 'c', date: '2026-11-17', time: '12:00', note: '' }, now);
      expect(accountBalance(data, 'a')).assertEqual(90000); expect(budgetUsage(data, data.budgets[0]).percent).assertEqual(125);
      data = saveEntry(data, { id: 'expense', type: 'expense', amount: '80', accountId: 'b', categoryId: 'c', date: '2026-12-01', time: '12:00', note: '' }, now);
      expect(accountBalance(data, 'a')).assertEqual(100000); expect(accountBalance(data, 'b')).assertEqual(12000);
      expect(budgetUsage(data, data.budgets[0]).usedCents).assertEqual(0);
      data = saveEntry(data, { id: 'income', type: 'income', amount: '50', accountId: 'a', categoryId: 'salary', date: '2026-11-17', time: '12:00', note: '' }, now);
      // Existing backups can still contain transfers; they are not editable in the app.
      data.transfers.push({ id: 'legacy-transfer', fromAccountId: 'a', toAccountId: 'b', amountCents: 50000,
        date: '2026-11-17', time: '12:00', note: '', createdAt: now, updatedAt: now });
      validateLedger(data);
      expect(accountBalance(data, 'a')).assertEqual(55000); expect(accountBalance(data, 'b')).assertEqual(62000);
      const filter = defaultFilter(); filter.range = { startDate: '2026-11-01', endDate: '2026-11-30' };
      expect(queryEntries(data, filter).incomeCents).assertEqual(5000); expect(queryEntries(data, filter).expenseCents).assertEqual(0);
      expect(statistics(data, filter.range, 'expense', 'day').incomeCents).assertEqual(5000);
      data = deleteEntry(data, 'expense'); expect(accountBalance(data, 'b')).assertEqual(70000);
      const imported = previewJson(emptyLedger(), exportJson(data)).data;
      expect(accountBalance(imported, 'a') + accountBalance(imported, 'b')).assertEqual(125000);
      expect(previewJson(imported, exportJson(data)).added).assertEqual(0);
    });
    it('validatesHundredThousandRowsWithManyReferencesAndRejectsOverdraft', 0, () => {
      const data = emptyLedger(); const now = '2026-11-17T00:00:00.000Z';
      for (let i = 0; i < 20; i++) {
        data.accounts.push({ id: `a${i}`, name: `账户${i}`, type: 'standard', initialBalanceCents: 1000000, needsInitialBalance: false, createdAt: now, updatedAt: now });
      }
      for (let i = 0; i < 100; i++) {
        data.categories.push({ id: `c${i}`, name: `分类${i}`, type: 'expense', iconKey: 'food', sortOrder: i, createdAt: now, updatedAt: now });
      }
      for (let i = 0; i < 100000; i++) {
        data.entries.push({ id: `e${i}`, type: 'expense', amountCents: 1, accountId: `a${i % 20}`, categoryId: `c${i % 100}`, date: '2026-11-17', time: '12:00', note: '', attachmentIds: [], createdAt: now, updatedAt: now });
      }
      validateLedger(data); expect(accountBalance(data, 'a0')).assertEqual(995000);
      data.accounts[0].initialBalanceCents = 0;
      let rejected = false; try { validateLedger(data); } catch (_) { rejected = true; }
      expect(rejected).assertTrue();
    });
    it('tenThousandEntriesPageWithoutLossAndStatisticsReconcile', 0, () => {
      const now = '2026-11-17T00:00:00.000Z';
      let data = upsertAccount(emptyLedger(), 'a', '现金', 'standard', '1000', now);
      data = upsertCategory(data, 'c', '餐饮', 'expense', 'food', 0, now);
      for (let i = 0; i < 10000; i++) {
        data.entries.push({ id: `entry-${i.toString().padStart(5, '0')}`, type: 'expense', amountCents: 1, accountId: 'a', categoryId: 'c', date: '2026-11-17', time: '12:00', note: '', attachmentIds: [], createdAt: now, updatedAt: now });
      }
      const filter = defaultFilter(); let count = 0; const seen: Set<string> = new Set();
      for (let i = 0; i < 200; i++) {
        const page = queryEntries(data, filter); count += page.rows.length;
        page.rows.forEach((row) => { seen.add(row.id); }); filter.cursor = page.next;
      }
      expect(count).assertEqual(10000); expect(seen.size).assertEqual(10000);
      expect(accountBalance(data, 'a')).assertEqual(90000);
      expect(statistics(data, { startDate: '2026-11-01', endDate: '2026-11-30' }, 'expense', 'day').expenseCents).assertEqual(10000);
    });
  });
}
