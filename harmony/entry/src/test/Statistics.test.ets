import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger } from '../main/ets/model/LedgerModels';
import { statistics } from '../main/ets/service/StatisticsService';
export default function statisticsTest() {
  describe('Statistics', () => {
    it('emptyLeapMonthHasZeroFilledBuckets', 0, () => {
      const result = statistics(emptyLedger(), { startDate: '2024-02-01', endDate: '2024-02-29' }, 'expense', 'day');
      expect(result.trend.length).assertEqual(29); expect(result.averageExpenseCents).assertEqual(0);
      expect(result.highestDays.length).assertEqual(0); expect(result.categories.length).assertEqual(0);
    });
    it('totalsTiesClippedWeeksAndCalendarDayAverage', 0, () => {
      const data = emptyLedger(); const now = '2026-11-17T00:00:00.000Z';
      data.categories.push({ id: 'c', type: 'expense', name: '餐', iconKey: 'food', sortOrder: 0, createdAt: now, updatedAt: now });
      for (const date of ['2024-12-31', '2025-01-01']) {
        data.entries.push({ id: date, type: 'expense', amountCents: 100, categoryId: 'c', accountId: 'a', date: date,
          time: '12:00', note: '', attachmentIds: [], createdAt: now, updatedAt: now });
      }
      const result = statistics(data, { startDate: '2024-12-31', endDate: '2025-01-03' }, 'expense', 'week');
      expect(result.expenseCents).assertEqual(200); expect(result.averageExpenseCents).assertEqual(50);
      expect(result.highestDays.length).assertEqual(2); expect(result.categories[0].percent).assertEqual(100);
      expect(result.trend[0].startDate).assertEqual('2024-12-31'); expect(result.trend[0].endDate).assertEqual('2025-01-03');
      expect(statistics(data, { startDate: '2024-12-31', endDate: '2025-01-03' }, 'income', 'day').categories.length).assertEqual(0);
    });
  });
}
