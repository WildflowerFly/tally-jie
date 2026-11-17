import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger, LedgerData } from '../main/ets/model/LedgerModels';
import { upsertCategory, removeCategory } from '../main/ets/service/CategoryService';
const NOW: string = '2026-11-17T00:00:00.000Z';
function rejects(work: () => void): boolean { try { work(); return false; } catch (_) { return true; } }
function fixture(): LedgerData {
  let data = upsertCategory(emptyLedger(), 'food', ' 餐饮 ', 'expense', 'food', 0, NOW);
  data = upsertCategory(data, 'other', '其他', 'expense', 'category', 1, NOW);
  return upsertCategory(data, 'in', '餐饮', 'income', 'salary', 0, NOW);
}
export default function categoryTest() {
  describe('CategoryService', () => {
    it('dynamicCategoriesTrimAndAllowSameNameAcrossTypes', 0, () => {
      const data = fixture(); expect(data.categories.length).assertEqual(3);
      expect(data.categories[0].name).assertEqual('餐饮');
      expect(rejects(() => upsertCategory(data, 'x', '餐饮', 'expense', 'food', 2, NOW))).assertTrue();
      expect(rejects(() => upsertCategory(data, 'x', ' ', 'expense', 'food', 2, NOW))).assertTrue();
      expect(rejects(() => upsertCategory(data, 'x', '合法名称', 'expense', 'remote-url', 2, NOW))).assertTrue();
      expect(rejects(() => upsertCategory(data, 'x', '合法名称', 'expense', 'food', -1, NOW))).assertTrue();
      const next = upsertCategory(data, 'food', '早餐', 'expense', 'food', 8, NOW);
      expect(next.categories[0].id).assertEqual('food'); expect(next.categories[0].sortOrder).assertEqual(8);
      expect(data.categories[0].name).assertEqual('餐饮');
    });
    it('protectsEntryAndBudgetReferencesAndRejectsTypeChange', 0, () => {
      const data = fixture();
      data.accounts.push({ id: 'a', name: '现金', type: 'standard', initialBalanceCents: 10000,
        needsInitialBalance: false, createdAt: NOW, updatedAt: NOW });
      data.entries.push({ id: 'e', type: 'expense', accountId: 'a', categoryId: 'food', amountCents: 100,
        date: '2026-11-17', time: '12:00', note: '', attachmentIds: [], createdAt: NOW, updatedAt: NOW });
      expect(rejects(() => removeCategory(data, 'food'))).assertTrue();
      expect(rejects(() => upsertCategory(data, 'food', '工资', 'income', 'salary', 0, NOW))).assertTrue();
      expect(rejects(() => removeCategory(data, 'food', 'in'))).assertTrue();
      const moved = removeCategory(data, 'food', 'other');
      expect(moved.entries[0].categoryId).assertEqual('other');
      expect(data.entries[0].categoryId).assertEqual('food');
      data.budgets.push({ id: 'b', scope: 'category', categoryId: 'food', amountCents: 1000,
        period: 'month', startDate: '2026-11-01', endDate: '2026-11-30', createdAt: NOW, updatedAt: NOW });
      expect(rejects(() => removeCategory(data, 'food'))).assertTrue();
      expect(removeCategory(data, 'food', 'other').budgets[0].categoryId).assertEqual('other');
      data.budgets.push({ id: 'b2', scope: 'category', categoryId: 'other', amountCents: 1000,
        period: 'month', startDate: '2026-11-01', endDate: '2026-11-30', createdAt: NOW, updatedAt: NOW });
      expect(rejects(() => removeCategory(data, 'food', 'other'))).assertTrue();
    });
    it('lastCategoryMayBeDeletedWithoutInventingAnother', 0, () => {
      const data = upsertCategory(emptyLedger(), 'a', '餐饮', 'expense', 'food', 0, NOW);
      expect(removeCategory(data, 'a').categories.length).assertEqual(0);
    });
  });
}
