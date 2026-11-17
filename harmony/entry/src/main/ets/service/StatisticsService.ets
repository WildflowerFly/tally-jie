import { LedgerData, DateRange, EntryType } from '../model/LedgerModels';
import { assertRange, rangeDays, calendarWeek, calendarMonth } from '../domain/DateRange';
import { addCents } from '../domain/Money';
export type TrendUnit = 'day' | 'week' | 'month';
export interface StatBucket { key: string; startDate: string; endDate: string; amountCents: number; }
export interface CategoryStat { id: string; name: string; amountCents: number; percent: number; }
export interface StatisticsResult {
  incomeCents: number; expenseCents: number; netCents: number; averageExpenseCents: number;
  categories: CategoryStat[]; trend: StatBucket[]; highestDays: string[]; highestCategories: string[];
}
function nextDate(value: string): string {
  const date = new Date(`${value}T12:00:00Z`); date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
}
export function statistics(data: LedgerData, range: DateRange, type: EntryType, unit: TrendUnit): StatisticsResult {
  assertRange(range);
  const days = rangeDays(range);
  if (days > 3660) { throw new Error('RANGE_TOO_LARGE'); }
  const result: StatisticsResult = { incomeCents: 0, expenseCents: 0, netCents: 0, averageExpenseCents: 0,
    categories: [], trend: [], highestDays: [], highestCategories: [] };
  const daily: StatBucket[] = [];
  let date = range.startDate;
  for (let i = 0; i < days; i++) {
    const period: DateRange = unit === 'day' ? { startDate: date, endDate: date } : unit === 'week' ? calendarWeek(date) : calendarMonth(date);
    const start = period.startDate < range.startDate ? range.startDate : period.startDate;
    const end = period.endDate > range.endDate ? range.endDate : period.endDate;
    if (!result.trend.some((row) => row.startDate === start)) {
      result.trend.push({ key: start, startDate: start, endDate: end, amountCents: 0 });
    }
    daily.push({ key: date, startDate: date, endDate: date, amountCents: 0 });
    if (i + 1 < days) { date = nextDate(date); }
  }
  data.entries.filter((row) => row.date >= range.startDate && row.date <= range.endDate).forEach((row) => {
    if (row.type === 'income') { result.incomeCents = addCents(result.incomeCents, row.amountCents); }
    else { result.expenseCents = addCents(result.expenseCents, row.amountCents);
      const day = daily.find((item) => item.key === row.date)!; day.amountCents = addCents(day.amountCents, row.amountCents); }
    if (row.type !== type) { return; }
    const bucket = result.trend.find((item) => row.date >= item.startDate && row.date <= item.endDate)!;
    bucket.amountCents = addCents(bucket.amountCents, row.amountCents);
    let category = result.categories.find((item) => item.id === row.categoryId);
    if (category === undefined) {
      category = { id: row.categoryId, name: data.categories.find((item) => item.id === row.categoryId)!.name, amountCents: 0, percent: 0 };
      result.categories.push(category);
    }
    category.amountCents = addCents(category.amountCents, row.amountCents);
  });
  result.netCents = addCents(result.incomeCents, -result.expenseCents);
  result.averageExpenseCents = Math.round(result.expenseCents / days);
  const total = type === 'income' ? result.incomeCents : result.expenseCents;
  result.categories.forEach((row) => { row.percent = total === 0 ? 0 : row.amountCents / total * 100; });
  result.categories.sort((a: CategoryStat, b: CategoryStat) => b.amountCents - a.amountCents || a.id.localeCompare(b.id));
  const maxDay = daily.reduce((max: number, row: StatBucket) => Math.max(max, row.amountCents), 0);
  result.highestDays = maxDay === 0 ? [] : daily.filter((row) => row.amountCents === maxDay).map((row) => row.key);
  // Highest category is always expense, regardless of visible income/expense chart.
  const expenses: CategoryStat[] = [];
  data.entries.filter((row) => row.type === 'expense' && row.date >= range.startDate && row.date <= range.endDate).forEach((row) => {
    let item = expenses.find((value) => value.id === row.categoryId);
    if (item === undefined) { item = { id: row.categoryId, name: data.categories.find((value) => value.id === row.categoryId)!.name, amountCents: 0, percent: 0 }; expenses.push(item); }
    item.amountCents = addCents(item.amountCents, row.amountCents);
  });
  const maxCategory = expenses.reduce((max: number, row: CategoryStat) => Math.max(max, row.amountCents), 0);
  result.highestCategories = expenses.filter((row) => row.amountCents === maxCategory).map((row) => row.name);
  return result;
}
