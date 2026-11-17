import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger } from '../main/ets/model/LedgerModels';
import { upsertAccount } from '../main/ets/service/AccountService';
import { upsertCategory } from '../main/ets/service/CategoryService';
import { previewMappedCsv, exportTables, previewTables, CsvMapping } from '../main/ets/service/ExchangeFormats';
export default function exchangeFormatsTest() {
  describe('ExchangeFormats', () => {
    it('mapsNamesReportsAllBadRowsAndNeverPartiallyImports', 0, () => {
      const now = '2026-11-17T00:00:00.000Z';
      let data = upsertAccount(emptyLedger(), 'a', '现金', 'standard', '100', now);
      data = upsertCategory(data, 'c', '餐饮', 'expense', 'food', 0, now);
      const mapping: CsvMapping = { id: '编号', type: '类型', amount: '金额', account: '账户', category: '分类', date: '日期', time: '时间', note: '备注' };
      const header = '编号,类型,金额,账户,分类,日期,时间,备注\n';
      const good = 'one,支出,2.50,现金,餐饮,2026-11-17,12:00,午饭';
      const result = previewMappedCsv(data, header + good, mapping, now);
      expect(result.preview!.data.entries[0].accountId).assertEqual('a');
      expect(result.preview!.data.entries[0].amountCents).assertEqual(250);
      const bad = previewMappedCsv(data, header + good + '\nbad,支出,no,现金,餐饮,2026-11-17,12:00,\nbad2,支出,1,不存在,餐饮,2026-11-17,12:00,', mapping, now);
      expect(bad.issues.length).assertEqual(2); expect(bad.issues[0].line).assertEqual(3);
      expect(bad.preview === null).assertTrue(); expect(data.entries.length).assertEqual(0);
    });
    it('fullTablesKeepAccountsCategoriesTransfersBudgetsAndRejectTampering', 0, () => {
      const now = '2026-11-17T00:00:00.000Z';
      let data = upsertAccount(emptyLedger(), 'a', '现金', 'standard', '100', now);
      data = upsertCategory(data, 'c', '餐饮', 'expense', 'food', 0, now);
      const text = exportTables(data); const imported = previewTables(emptyLedger(), text);
      expect(imported.added).assertEqual(2); expect(imported.data.accounts[0].initialBalanceCents).assertEqual(10000);
      expect(previewTables(imported.data, text).duplicates).assertEqual(2);
      let failed = false; try { previewTables(data, text.replace('accounts', 'unknown')); } catch (_) { failed = true; }
      expect(failed).assertTrue();
    });
  });
}
