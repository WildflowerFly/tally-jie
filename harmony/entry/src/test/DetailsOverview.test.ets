import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger, EntryType, LedgerEntry } from '../main/ets/model/LedgerModels';
import { detailsOverview, detailsMoney, detailsDayLabel, detailsRangeLabel, detailsEntryTime } from '../main/ets/domain/DetailsOverview';

function entry(id: string, type: EntryType, amount: number, date: string): LedgerEntry {
  return { id: id, type: type, amountCents: amount, accountId: 'account', categoryId: 'category',
    date: date, time: '13:46', note: '', attachmentIds: [], createdAt: null, updatedAt: '' };
}

export default function detailsOverviewTest() {
  describe('DetailsOverview', () => {
    it('emptyLedgerDoesNotInventBudgetOrTransactions', 0, () => {
      const result = detailsOverview(emptyLedger(), '2026-08-19');
      expect(result.monthLabel).assertEqual('08月');
      expect(result.balanceCents).assertEqual(0);
      expect(result.budgetCents).assertEqual(null);
      expect(result.remainingCents).assertEqual(null);
      expect(result.budgetPercent).assertEqual(0);
    });
    it('calendarMonthSummaryAndOverBudgetMatchReference', 0, () => {
      const data = emptyLedger();
      data.entries = [entry('a', 'income', 819313, '2026-08-01'), entry('b', 'expense', 810082, '2026-08-31'),
        entry('old', 'expense', 990000, '2026-07-31'), entry('future', 'income', 990000, '2026-09-01')];
      data.budgets.push({ id: 'b', scope: 'total', categoryId: null, amountCents: 350000, period: 'month',
        startDate: '2026-08-01', endDate: '2026-08-31', createdAt: null, updatedAt: '' });
      const result = detailsOverview(data, '2026-08-19');
      expect(result.incomeCents).assertEqual(819313);
      expect(result.expenseCents).assertEqual(810082);
      expect(result.balanceCents).assertEqual(9231);
      expect(result.remainingCents).assertEqual(-460082);
      expect(result.budgetPercent).assertEqual(100);
      expect(detailsMoney(result.remainingCents!)).assertEqual('-¥4,600.82');
      data.entries.pop(); data.entries[1].amountCents = 175000;
      expect(detailsOverview(data, '2026-08-19').budgetPercent).assertEqual(50);
      expect(detailsOverview(data, '2026-08-19').remainingCents).assertEqual(175000);
    });
    it('doesNotConfuseWeeklyCategoryOrOldBudgetsWithMonthTotal', 0, () => {
      const data = emptyLedger();
      data.budgets = [
        { id: 'weekly', scope: 'total', categoryId: null, amountCents: 10000, period: 'week', startDate: '2026-08-17', endDate: '2026-08-23', createdAt: null, updatedAt: '' },
        { id: 'category', scope: 'category', categoryId: 'category', amountCents: 10000, period: 'month', startDate: '2026-08-01', endDate: '2026-08-31', createdAt: null, updatedAt: '' },
        { id: 'old', scope: 'total', categoryId: null, amountCents: 10000, period: 'month', startDate: '2026-07-01', endDate: '2026-07-31', createdAt: null, updatedAt: '' }
      ];
      expect(detailsOverview(data, '2026-08-19').budgetCents).assertEqual(null);
    });
    it('dateLabelsAreCalendarBasedAndKeepHistoricalYear', 0, () => {
      expect(detailsDayLabel('2026-07-19', '2026-08-01')).assertEqual('07月19日   星期日');
      expect(detailsDayLabel('2024-02-29', '2026-08-01')).assertEqual('2024年02月29日   星期四');
      expect(detailsEntryTime('2026-08-19', '13:46', '2026-08-19')).assertEqual('今天13:46');
      expect(detailsEntryTime('2025-12-31', '13:46', '2026-01-01')).assertEqual('昨天13:46');
      expect(detailsEntryTime('2026-07-19', '13:46', '2026-08-19')).assertEqual('13:46');
    });
    it('rangeAndMoneyLabelsHandleAllTimeAndNegativeBalance', 0, () => {
      expect(detailsRangeLabel(null, '2026-08-19')).assertEqual('全部时间');
      expect(detailsRangeLabel({ startDate: '2026-08-01', endDate: '2026-08-31' }, '2026-08-19')).assertEqual('本月');
      expect(detailsRangeLabel({ startDate: '2026-08-17', endDate: '2026-08-23' }, '2026-08-19')).assertEqual('本周');
      expect(detailsRangeLabel({ startDate: '2026-01-01', endDate: '2026-12-31' }, '2026-08-19')).assertEqual('本年');
      expect(detailsRangeLabel({ startDate: '2026-07-19', endDate: '2026-07-19' }, '2026-08-19')).assertEqual('自定义');
      expect(detailsMoney(0)).assertEqual('¥0.00');
      expect(detailsMoney(-100001)).assertEqual('-¥1,000.01');
      expect(detailsMoney(99999999999)).assertEqual('¥999,999,999.99');
    });
  });
}
