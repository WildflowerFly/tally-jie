import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger, LedgerData } from '../main/ets/model/LedgerModels';
import { defaultFilter, queryEntries } from '../main/ets/service/LedgerQueryService';
function fixture(): LedgerData {
  const data = emptyLedger();
  const now = '2026-11-17T00:00:00.000Z';
  data.accounts.push({ id: 'a', name: '零钱', type: 'credit', initialBalanceCents: 0, needsInitialBalance: false, createdAt: now, updatedAt: now });
  data.categories.push({ id: 'c', name: '餐饮', type: 'expense', iconKey: 'food', sortOrder: 0, createdAt: now, updatedAt: now });
  for (let i = 0; i < 103; i++) {
    data.entries.push({ id: `e${i.toString().padStart(3, '0')}`, type: 'expense', amountCents: 100,
      accountId: 'a', categoryId: 'c', date: '2026-11-17', time: '12:30', note: '100%_午餐', attachmentIds: [], createdAt: now, updatedAt: now });
  }
  return data;
}
export default function queryTest() {
  describe('LedgerQuery', () => {
    it('cursorPagesAreStableAndTotalsCoverWholeFilter', 0, () => {
      const data = fixture(); const filter = defaultFilter();
      const first = queryEntries(data, filter);
      expect(first.rows.length).assertEqual(50); expect(first.expenseCents).assertEqual(10300);
      expect(first.rows[0].id).assertEqual('e102'); filter.cursor = first.next;
      const second = queryEntries(data, filter); filter.cursor = second.next;
      const third = queryEntries(data, filter);
      expect(second.rows.length).assertEqual(50); expect(third.rows.length).assertEqual(3);
      const ids = first.rows.concat(second.rows, third.rows).map((row) => row.id);
      expect(new Set(ids).size).assertEqual(103); expect(third.next === null).assertTrue();
    });
    it('combinedInclusiveFiltersAndLiteralKeywordSearch', 0, () => {
      const data = fixture(); const filter = defaultFilter();
      filter.type = 'expense'; filter.accountIds = ['a']; filter.categoryIds = ['c'];
      filter.range = { startDate: '2026-11-17', endDate: '2026-11-17' };
      filter.minAmountCents = 100; filter.maxAmountCents = 100;
      for (const keyword of ['零钱', '餐饮', '100%_', '午餐']) {
        filter.keyword = keyword; expect(queryEntries(data, filter).count).assertEqual(103);
      }
      filter.keyword = '不存在'; expect(queryEntries(data, filter).count).assertEqual(0);
      filter.keyword = ''; filter.type = 'income'; expect(queryEntries(data, filter).count).assertEqual(0);
    });
  });
}
