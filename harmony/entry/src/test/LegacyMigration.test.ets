import { describe, it, expect } from '@ohos/hypium';
import { emptyData, Transaction, Diary } from '../main/ets/model/AppData';
import { buildLegacyMigration, applyInitialBalances } from '../main/ets/service/LegacyMigration';
import { validateLedger } from '../main/ets/domain/LedgerRules';

export default function legacyMigrationTest() {
  describe('LegacyMigration', () => {
    it('emptyLegacyUsesStableMappingsAndZeroPrompt', 0, () => {
      const result = buildLegacyMigration(emptyData(), '2026-11-17T00:00:00.000Z');
      expect(result.data.accounts.length).assertEqual(6);
      expect(result.data.accounts[0].initialBalanceCents).assertEqual(0);
      expect(result.data.accounts[0].needsInitialBalance).assertTrue();
      expect(result.data.categories.filter((item) => item.name === '其他').length).assertEqual(2);
      expect(result.requiredAccountIds.length).assertEqual(0);
      validateLedger(result.data);
    });
    it('negativeStandardHistoryWaitsForRepairWithoutMutatingLegacy', 0, () => {
      const old = emptyData();
      const row: Transaction = { id: 'old1', type: 'expense', amount: 150, account: '现金', category: '餐饮',
        date: '2024-02-29', time: '12:00', note: '中文\n备注', images: ['img_test.jpg'] };
      old.transactions = [row];
      const source = JSON.stringify(old);
      const result = buildLegacyMigration(old, '2026-11-17T00:00:00.000Z');
      expect(result.requiredAccountIds.length).assertEqual(1);
      expect(result.data.entries[0].id).assertEqual('old1');
      expect(result.data.entries[0].createdAt === null).assertTrue();
      const fixed = applyInitialBalances(result, [{ accountId: result.requiredAccountIds[0], amount: '1.50' }]);
      validateLedger(fixed);
      expect(fixed.accounts.find((item) => item.id === result.requiredAccountIds[0])!.needsInitialBalance).assertFalse();
      expect(JSON.stringify(old)).assertEqual(source);
      expect(result.data.accounts.find((item) => item.id === result.requiredAccountIds[0])!.initialBalanceCents).assertEqual(0);
      expect(fixed.attachments[0].relativePath).assertEqual('images/img_test.jpg');
    });
    it('creditHistoryAndDiaryAreNotLiveLedgerEntities', 0, () => {
      const old = emptyData();
      const row: Transaction = { id: 'credit1', type: 'expense', amount: 100, account: '信用卡', category: '餐饮',
        date: '2026-11-17', time: '12:00', note: '', images: [] };
      const diary: Diary = { id: 'diary1', date: '2026-11-17', content: '合成日记', mood: '😊 开心', weather: '☀️ 晴', location: '', images: [] };
      old.transactions = [row]; old.diaries = [diary]; old.budgets = [{ month: '2024-02', amount: 1000 }];
      const result = buildLegacyMigration(old, '2026-11-17T00:00:00.000Z');
      expect(result.requiredAccountIds.length).assertEqual(0);
      expect(result.archivedDiaryCount).assertEqual(1);
      expect(result.data.budgets[0].endDate).assertEqual('2024-02-29');
      validateLedger(result.data);
    });
    it('corruptionAndUnknownVersionsAreNeverTreatedAsEmpty', 0, () => {
      const old = emptyData(); old.version = 99;
      let failed = false;
      try { buildLegacyMigration(old, '2026-11-17T00:00:00.000Z'); } catch (_) { failed = true; }
      expect(failed).assertTrue();
      old.version = 1; old.transactions = [
        { id: 'bad', type: 'expense', amount: 1, account: '现金', category: '餐饮', date: '2026-02-30', time: '12:00', note: '', images: [] }
      ];
      failed = false;
      try { buildLegacyMigration(old, '2026-11-17T00:00:00.000Z'); } catch (_) { failed = true; }
      expect(failed).assertTrue();
    });
  });
}
