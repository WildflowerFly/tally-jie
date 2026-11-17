// Legacy v1 contract, retained unchanged for existing screens and migration input.
// New ledger/domain code uses LedgerModels.ets (v2); never cast a v1 payload to v2.
// Diary here is compatibility data, not authorization to keep diary UI in the new product.
// Export the new contract explicitly so the application build also compiles the isolated rules.
export { emptyLedger } from './LedgerModels';
export { parseAmount, parseInitialBalance, addCents } from '../domain/Money';
export { calendarWeek, calendarMonth, rangeDays } from '../domain/DateRange';
export { validateLedger, validateFilter } from '../domain/LedgerRules';

export interface Transaction {
  id: string;
  type: string;
  amount: number; // Integer cents; never accumulate floating point currency.
  category: string;
  account: string;
  note: string;
  date: string;
  time: string;
  images: string[];
}

export interface Diary {
  id: string;
  date: string;
  content: string;
  mood: string;
  weather: string;
  location: string;
  images: string[];
}

export interface Budget {
  month: string;
  amount: number;
}

export interface Settings {
  theme: number;
  fontSize: number;
  font: number;
}

export interface AppData {
  version: number;
  transactions: Transaction[];
  diaries: Diary[];
  budgets: Budget[];
  settings: Settings;
}

export interface BackupAsset {
  name: string;
  data: string;
}

export interface Backup {
  format: string;
  version: number;
  createdAt: string;
  data: AppData;
  assets: BackupAsset[];
}

export interface CategoryTotal {
  name: string;
  amount: number;
  count: number;
}

export class Palette {
  name: string;
  background: string;
  accent: string;
  text: string;
  secondary: string;
  constructor(name: string, background: string, accent: string, text: string, secondary: string) {
    this.name = name;
    this.background = background;
    this.accent = accent;
    this.text = text;
    this.secondary = secondary;
  }
}

export const PALETTES: Palette[] = [
  new Palette('奶油纸感', '#FDF8F0', '#D8A47F', '#3D2C1E', '#8A7A6B'),
  new Palette('汝窑天青', '#F2F7F2', '#8CB5A8', '#2D3E3A', '#7A948A'),
  new Palette('经典黑白', '#F5F5F5', '#3D3D3D', '#1A1A1A', '#6B6B6B')
];
export const EXPENSE_CATEGORIES: string[] = ['餐饮', '交通', '购物', '住房', '水电', '通讯', '娱乐', '学习', '医疗', '旅行', '宠物', '礼物', '日用品', '服饰', '美妆', '运动', '数码', '其他'];
export const INCOME_CATEGORIES: string[] = ['工资', '奖金', '分红', '兼职', '收款', '退款', '红包', '利息', '投资', '其他'];
export const ACCOUNTS: string[] = ['微信', '支付宝', '银行卡', '现金', '信用卡', '数字钱包'];
export const MOODS: string[] = ['😊 开心', '😌 平静', '😢 难过', '😤 生气', '😴 疲惫', '🥰 幸福'];
export const WEATHERS: string[] = ['☀️ 晴', '⛅ 多云', '☁️ 阴', '🌧️ 雨', '❄️ 雪', '🌬️ 风'];

export function emptyData(): AppData {
  return { version: 1, transactions: [], diaries: [], budgets: [], settings: { theme: 0, fontSize: 1, font: 0 } };
}

export function dateKey(date: Date = new Date()): string {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export function pad(value: number): string {
  return value.toString().padStart(2, '0');
}

export function validDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T12:00:00`);
  return !isNaN(parsed.getTime()) && dateKey(parsed) === value;
}

export function toCents(value: string): number {
  if (!/^(0|[1-9]\d{0,8})(\.\d{1,2})?$/.test(value)) throw new Error('请输入正确金额，最多两位小数');
  const parts = value.split('.');
  const cents = Number(parts[0]) * 100 + Number((parts[1] ?? '').padEnd(2, '0'));
  if (cents <= 0) throw new Error('金额必须大于零');
  return cents;
}

export function money(cents: number): string {
  return (cents / 100).toFixed(2);
}

export function monthlyTotal(data: AppData, month: string, type: string): number {
  return data.transactions.filter((item: Transaction) => item.date.startsWith(month) && item.type === type)
    .reduce((total: number, item: Transaction) => total + item.amount, 0);
}

export function categoryTotals(items: Transaction[]): CategoryTotal[] {
  const result: CategoryTotal[] = [];
  items.forEach((item: Transaction) => {
    const found = result.find((total: CategoryTotal) => total.name === item.category);
    if (found) {
      found.amount += item.amount;
      found.count++;
    } else {
      result.push({ name: item.category, amount: item.amount, count: 1 });
    }
  });
  return result.sort((a: CategoryTotal, b: CategoryTotal) => b.amount - a.amount);
}

export function newId(): string {
  return `${Date.now()}_${Math.floor(Math.random() * 100000000)}`;
}

// Validate every field before replacing live data. Casts alone do not validate imported JSON.
export function validateData(data: AppData): void {
  if (!data || data.version !== 1 || !Array.isArray(data.transactions) || !Array.isArray(data.diaries) ||
    !Array.isArray(data.budgets) || !data.settings) throw new Error('不是有效的鸿蒙版 TallyJie 数据');
  const s = data.settings;
  if (!Number.isInteger(s.theme) || s.theme < 0 || s.theme > 2 || !Number.isInteger(s.fontSize) ||
    s.fontSize < 0 || s.fontSize > 3 || !Number.isInteger(s.font) || s.font < 0 || s.font > 3) throw new Error('设置数据无效');
  const ids: string[] = [];
  data.transactions.forEach((t: Transaction) => {
    if (!t || typeof t.id !== 'string' || !t.id || ids.includes(t.id) ||
      (t.type !== 'income' && t.type !== 'expense') || !Number.isSafeInteger(t.amount) || t.amount <= 0 || t.amount > 99999999999 ||
      !(t.type === 'income' ? INCOME_CATEGORIES : EXPENSE_CATEGORIES).includes(t.category) || !ACCOUNTS.includes(t.account) ||
      typeof t.note !== 'string' || typeof t.date !== 'string' || !validDate(t.date) || typeof t.time !== 'string' ||
      !/^([01]\d|2[0-3]):[0-5]\d$/.test(t.time)) throw new Error('账单数据无效');
    validateImages(t.images);
    ids.push(t.id);
  });
  const diaryIds: string[] = [];
  data.diaries.forEach((d: Diary) => {
    if (!d || typeof d.id !== 'string' || !d.id || diaryIds.includes(d.id) || typeof d.date !== 'string' || !validDate(d.date) ||
      typeof d.content !== 'string' || typeof d.location !== 'string' || !MOODS.includes(d.mood) || !WEATHERS.includes(d.weather)) {
      throw new Error('日记数据无效');
    }
    validateImages(d.images);
    diaryIds.push(d.id);
  });
  const months: string[] = [];
  data.budgets.forEach((b: Budget) => {
    if (!b || typeof b.month !== 'string' || !validDate(`${b.month}-01`) || months.includes(b.month) ||
      !Number.isSafeInteger(b.amount) || b.amount <= 0 || b.amount > 99999999999) throw new Error('预算数据无效');
    months.push(b.month);
  });
}

export function validateImages(images: string[]): void {
  if (!Array.isArray(images) || images.length > 9 || images.some((name: string) =>
    typeof name !== 'string' || !/^img_[a-zA-Z0-9_]+\.jpg$/.test(name))) throw new Error('附件数据无效');
}
