import { Category, EntryType } from '../model/LedgerModels';

interface RecordCategoryPreset { key: number; name: string; }

// Keys are persistent ID suffixes, not display positions. Never renumber existing keys.
// Retire 12 (宠物) and 15 (美妆); 游戏 gets a new key instead of reusing either ID.
const EXPENSE_PRESETS: RecordCategoryPreset[] = [
  { key: 0, name: '餐饮' }, { key: 1, name: '交通' }, { key: 2, name: '住房' }, { key: 3, name: '水电' },
  { key: 4, name: '零食' }, { key: 5, name: '购物' }, { key: 6, name: '日用' }, { key: 7, name: '通讯' },
  { key: 8, name: '娱乐' }, { key: 20, name: '游戏' }, { key: 9, name: '学习' }, { key: 10, name: '医疗' },
  { key: 11, name: '旅行' }, { key: 13, name: '礼物' }, { key: 14, name: '服饰' },
  { key: 16, name: '运动' }, { key: 17, name: '数码' }, { key: 18, name: '社交' }, { key: 19, name: '其他支出' }
];
const INCOME_NAMES: string[] = ['工资', '奖金', '兼职', '红包', '理财', '利息', '分红', '报销',
  '退款', '收款', '礼金', '其他收入'];

// Suggestions stay virtual until selected. Hide retired names only in the record-page
// expense picker, without deleting stored categories or changing historical bill references.
export function recordCategories(categories: Category[], type: EntryType): Category[] {
  const existing = categories.filter((row) => row.type === type &&
    (type !== 'expense' || (row.name !== '宠物' && row.name !== '美妆')))
    .sort((a: Category, b: Category) => a.sortOrder - b.sortOrder || a.id.localeCompare(b.id));
  const presets: RecordCategoryPreset[] = type === 'income' ?
    INCOME_NAMES.map((name: string, index: number): RecordCategoryPreset => { return { key: index, name: name }; }) :
    EXPENSE_PRESETS;
  const suggestions: Category[] = [];
  presets.forEach((preset: RecordCategoryPreset, index: number) => {
    if (!existing.some((row) => row.name === preset.name)) {
      suggestions.push({ id: `record-preset-${type}-${preset.key}`, name: preset.name, type: type,
        iconKey: 'category', sortOrder: existing.length + index, createdAt: '', updatedAt: '' });
    }
  });
  return existing.concat(suggestions);
}
