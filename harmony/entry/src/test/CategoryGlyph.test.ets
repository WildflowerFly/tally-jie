import { describe, it, expect } from '@ohos/hypium';
import { categoryGlyph } from '../main/ets/domain/CategoryGlyph';
import { statistics } from '../main/ets/service/StatisticsService';
import { emptyLedger } from '../main/ets/model/LedgerModels';

export default function categoryGlyphTest() {
  describe('CategoryGlyph', () => {
    it('recentEntriesAndStatisticsUseSemanticIconsRatherThanDirectionArrows', 0, () => {
      expect(categoryGlyph('餐饮')).assertEqual('food');
      expect(categoryGlyph('零食')).assertEqual('snack');
      expect(categoryGlyph('通讯')).assertEqual('phone');
      expect(categoryGlyph('水电')).assertEqual('water');
      expect(categoryGlyph('旅行')).assertEqual('trip');
      expect(categoryGlyph('交通')).assertEqual('travel');
      expect(categoryGlyph('服饰')).assertEqual('clothing');
      expect(categoryGlyph('报销')).assertEqual('reimburse');
      expect(categoryGlyph('任意分类')).assertEqual('category');
    });
    it('explicitCustomIconWinsOverNameAndGenericLegacyNamesStillWork', 0, () => {
      expect(categoryGlyph('餐饮', 'gift')).assertEqual('gift');
      expect(categoryGlyph('自定义', 'food')).assertEqual('food');
      expect(categoryGlyph('餐饮', 'category')).assertEqual('food');
      expect(categoryGlyph('工资')).assertEqual('salary');
    });
    it('statisticBucketsCarryTheActualCategoryIconWithoutChangingTotals', 0, () => {
      const data = emptyLedger(); const now = '2026-11-18T00:00:00.000Z';
      data.categories.push({ id: 'custom', name: '自定义', type: 'expense', iconKey: 'gift', sortOrder: 0,
        createdAt: now, updatedAt: now });
      data.entries.push({ id: 'e', type: 'expense', categoryId: 'custom', accountId: 'a', amountCents: 2600,
        date: '2026-11-18', time: '12:00', note: '', attachmentIds: [], createdAt: now, updatedAt: now });
      const result = statistics(data, { startDate: '2026-11-01', endDate: '2026-11-30' }, 'expense', 'month');
      expect(result.expenseCents).assertEqual(2600);
      expect(result.categories[0].iconKey).assertEqual('gift');
      expect(categoryGlyph(result.categories[0].name, result.categories[0].iconKey)).assertEqual('gift');
    });
  });
}
