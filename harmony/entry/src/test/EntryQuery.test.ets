import { describe, it, expect } from '@ohos/hypium';
import { entryQueries } from '../main/ets/repository/EntryQuery';
import { defaultFilter } from '../main/ets/service/LedgerQueryService';
export default function entryQueryTest() {
  describe('EntryQuery', () => {
    it('bindsFiltersAndUsesExclusiveCompositeCursorOnlyOnPage', 0, () => {
      const filter = defaultFilter(); filter.keyword = "100%_\\' OR 1=1";
      filter.accountIds = ['a', 'b']; filter.categoryIds = ['c']; filter.type = 'expense';
      filter.range = { startDate: '2026-01-01', endDate: '2026-12-31' };
      filter.minAmountCents = 1; filter.maxAmountCents = 500;
      filter.cursor = { date: '2026-11-17', time: '12:00', id: 'e050' };
      const query = entryQueries(filter);
      expect(query.page.sql.includes('(e.date,e.time,e.id) < (?,?,?)')).assertTrue();
      expect(query.page.sql.includes(filter.keyword)).assertFalse();
      expect(query.page.args[query.page.args.length - 1]).assertEqual(51);
      expect(query.totals.sql.includes('LIMIT')).assertFalse();
      expect(query.totals.sql.includes('(e.date,e.time,e.id) <')).assertFalse();
      expect(query.daily.sql.includes('GROUP BY e.date')).assertTrue();
      expect(query.page.sql.includes('instr(lower(e.note),lower(?))')).assertTrue();
    });
    it('rejectsInvalidLimitsAndDefaultsToIndexedOrder', 0, () => {
      const filter = defaultFilter(); const query = entryQueries(filter);
      expect(query.page.sql.includes('ORDER BY e.date DESC,e.time DESC,e.id DESC LIMIT ?')).assertTrue();
      expect(query.page.args[0]).assertEqual(51);
      filter.pageSize = 0; let failed = false;
      try { entryQueries(filter); } catch (_) { failed = true; }
      expect(failed).assertTrue();
    });
  });
}
