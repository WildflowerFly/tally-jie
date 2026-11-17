import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger } from '../main/ets/model/LedgerModels';
import { encodeCsv, decodeCsv } from '../main/ets/domain/CsvCodec';
import { exportJson, previewJson, exportCsv, previewCsv } from '../main/ets/service/DataExchangeService';
function rejects(action: () => void): boolean { try { action(); return false; } catch (_) { return true; } }
export default function exchangeTest() {
  describe('Exchange', () => {
    it('csvRoundTripsQuotesNewlinesBOMAndRejectsMalformed', 0, () => {
      const rows: string[][] = [['中文', '逗号,双"引号', '多\r\n行', ''], ['', '末尾', '', '']];
      expect(JSON.stringify(decodeCsv(encodeCsv(rows)))).assertEqual(JSON.stringify(rows));
      expect(rejects(() => { decodeCsv('"未闭合'); })).assertTrue();
      expect(rejects(() => { decodeCsv('"值"坏'); })).assertTrue();
    });
    it('previewIsAtomicDedupesAndRejectsConflictingIds', 0, () => {
      const data = emptyLedger(); const now = '2026-11-17T00:00:00.000Z';
      data.accounts.push({ id: 'a', name: '现金', type: 'standard', initialBalanceCents: 100000, needsInitialBalance: false, createdAt: now, updatedAt: now });
      data.categories.push({ id: 'c', type: 'expense', name: '餐', iconKey: 'food', sortOrder: 0, createdAt: now, updatedAt: now });
      data.entries.push({ id: 'e', type: 'expense', amountCents: 100, accountId: 'a', categoryId: 'c', date: '2026-11-17', time: '12:00', note: '带,号\n换行', attachmentIds: [], createdAt: null, updatedAt: now });
      const text = exportJson(data); const first = previewJson(emptyLedger(), text);
      expect(first.added).assertEqual(3); expect(previewJson(first.data, text).duplicates).assertEqual(3);
      expect(previewCsv(data, exportCsv(data), now).duplicates).assertEqual(1);
      const before = JSON.stringify(data); const bad = text.replace('现金', '冲突');
      expect(rejects(() => { previewJson(data, bad); })).assertTrue(); expect(JSON.stringify(data)).assertEqual(before);
      expect(rejects(() => { previewCsv(emptyLedger(), exportCsv(data), now); })).assertTrue();
      expect(rejects(() => { previewJson(data, '{"format":"bad"}'); })).assertTrue();
      expect(previewJson(data, text).added).assertEqual(0);
    });
  });
}
