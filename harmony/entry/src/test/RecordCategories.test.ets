import { describe, it, expect } from '@ohos/hypium';
import { Category, EntryType, emptyLedger } from '../main/ets/model/LedgerModels';
import { recordCategories } from '../main/ets/domain/RecordCategories';
import { upsertCategory } from '../main/ets/service/CategoryService';

const NOW: string = '2026-11-18T00:00:00.000Z';
function category(id: string, name: string, type: EntryType = 'expense', order: number = 0): Category {
  return { id: id, name: name, type: type, iconKey: 'category', sortOrder: order, createdAt: NOW, updatedAt: NOW };
}

export default function recordCategoriesTest() {
  describe('RecordCategories', () => {
    it('expensePresetsReplacePetAndBeautyWithGameWithoutRenumberingIds', 0, () => {
      const rows = recordCategories([], 'expense');
      expect(rows.length).assertEqual(19);
      expect(rows.some((row) => row.name === '宠物' || row.name === '美妆')).assertFalse();
      expect(rows.filter((row) => row.name === '游戏').length).assertEqual(1);
      expect(rows.find((row) => row.name === '游戏')!.id).assertEqual('record-preset-expense-20');
      expect(rows.find((row) => row.name === '礼物')!.id).assertEqual('record-preset-expense-13');
      expect(rows.find((row) => row.name === '服饰')!.id).assertEqual('record-preset-expense-14');
      expect(rows.find((row) => row.name === '运动')!.id).assertEqual('record-preset-expense-16');
      expect(rows.find((row) => row.name === '其他支出')!.id).assertEqual('record-preset-expense-19');
    });
    it('hidesPreviouslySavedRetiredExpensesWithoutMutatingStoredCategories', 0, () => {
      const stored: Category[] = [category('pet', '宠物'), category('beauty', '美妆'),
        category('custom', '咖啡', 'expense', 8), category('gift', '礼物', 'expense', 3),
        category('income', '工资', 'income')];
      const before = JSON.stringify(stored);
      const rows = recordCategories(stored, 'expense');
      expect(rows.some((row) => row.name === '宠物' || row.name === '美妆')).assertFalse();
      expect(rows.some((row) => row.type !== 'expense')).assertFalse();
      expect(rows[0].id).assertEqual('gift');
      expect(rows[1].id).assertEqual('custom');
      expect(rows.find((row) => row.name === '礼物')!.id).assertEqual('gift');
      expect(JSON.stringify(stored)).assertEqual(before);
    });
    it('persistingUpdatedPresetsNeverReusesHistoricalCategoryIds', 0, () => {
      const oldNames: string[] = ['餐饮', '交通', '住房', '水电', '零食', '购物', '日用', '通讯',
        '娱乐', '学习', '医疗', '旅行', '宠物', '礼物', '服饰', '美妆', '运动', '数码', '社交', '其他支出'];
      const original = emptyLedger();
      original.categories = oldNames.map((name: string, index: number): Category => {
        return category(`record-preset-expense-${index}`, name, 'expense', index);
      });
      let next = original;
      recordCategories(original.categories, 'expense').forEach((row: Category) => {
        next = upsertCategory(next, row.id, row.name, row.type, row.iconKey, row.sortOrder, NOW);
      });
      original.categories.forEach((row: Category) => {
        expect(next.categories.find((item) => item.id === row.id)!.name).assertEqual(row.name);
      });
      expect(next.categories.length).assertEqual(21);
      expect(original.categories.length).assertEqual(20);
      expect(recordCategories(next.categories, 'expense').length).assertEqual(19);
      expect(recordCategories(next.categories, 'expense').filter((row) => row.name === '游戏').length).assertEqual(1);
    });
    it('keepsCustomGameCategoryAndIncomePresetsUnchanged', 0, () => {
      const stored: Category[] = [category('my-game', '游戏'), category('my-income', '宠物', 'income')];
      const expense = recordCategories(stored, 'expense');
      expect(expense.filter((row) => row.name === '游戏').length).assertEqual(1);
      expect(expense.find((row) => row.name === '游戏')!.id).assertEqual('my-game');
      const income = recordCategories(stored, 'income');
      expect(income.length).assertEqual(13);
      expect(income[0].id).assertEqual('my-income');
      expect(income.some((row) => row.name === '游戏')).assertFalse();
      expect(income.find((row) => row.name === '工资')!.id).assertEqual('record-preset-income-0');
    });
  });
}
