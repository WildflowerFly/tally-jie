import { DateRange, LedgerData } from '../model/LedgerModels';
import { calendarMonth, calendarWeek } from './DateRange';
import { addCents } from './Money';
import { monthlyTotalBudget } from '../service/BudgetService';

export interface DetailsOverview {
  monthLabel: string;
  incomeCents: number;
  expenseCents: number;
  balanceCents: number;
  budgetCents: number | null;
  remainingCents: number | null;
  budgetPercent: number;
}

// The overview is always the whole calendar month, independent of list filters.
// Weekly/category budgets must not be presented as the month's total budget.
export function detailsOverview(data: LedgerData, today: string): DetailsOverview {
  const month = calendarMonth(today);
  let income = 0;
  let expense = 0;
  data.entries.forEach((row) => {
    if (row.date < month.startDate || row.date > month.endDate) { return; }
    if (row.type === 'income') { income = addCents(income, row.amountCents); }
    else { expense = addCents(expense, row.amountCents); }
  });
  const budget = monthlyTotalBudget(data, today);
  return {
    monthLabel: `${month.startDate.slice(5, 7)}月`, incomeCents: income, expenseCents: expense,
    balanceCents: addCents(income, -expense), budgetCents: budget?.amountCents ?? null,
    remainingCents: budget === undefined ? null : addCents(budget.amountCents, -expense),
    budgetPercent: budget === undefined ? 0 : Math.min(100, Math.round(expense / budget.amountCents * 100))
  };
}

export function detailsMoney(cents: number): string {
  const amount = (Math.abs(cents) / 100).toFixed(2).split('.');
  return `${cents < 0 ? '-' : ''}¥${amount[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',')}.${amount[1]}`;
}

export function detailsRangeLabel(range: DateRange | null, today: string): string {
  if (range === null) { return '全部时间'; }
  const month = calendarMonth(today);
  if (range.startDate === month.startDate && range.endDate === month.endDate) { return '本月'; }
  const week = calendarWeek(today);
  if (range.startDate === week.startDate && range.endDate === week.endDate) { return '本周'; }
  if (range.startDate === `${today.slice(0, 4)}-01-01` && range.endDate === `${today.slice(0, 4)}-12-31`) { return '本年'; }
  return '自定义';
}

export function detailsDayLabel(date: string, today: string): string {
  const weekdays: string[] = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
  const year = date.slice(0, 4) === today.slice(0, 4) ? '' : `${date.slice(0, 4)}年`;
  return `${year}${date.slice(5, 7)}月${date.slice(8, 10)}日   ${weekdays[new Date(`${date}T12:00:00Z`).getUTCDay()]}`;
}

export function detailsEntryTime(date: string, time: string, today: string): string {
  if (date === today) { return `今天${time}`; }
  const day = new Date(`${today}T12:00:00Z`);
  day.setUTCDate(day.getUTCDate() - 1);
  if (date === day.toISOString().slice(0, 10)) { return `昨天${time}`; }
  return time;
}
