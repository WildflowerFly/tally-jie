import { LedgerData, BudgetRule, BudgetPeriod, LedgerError, DateRange } from '../model/LedgerModels';
import { parseAmount, addCents } from '../domain/Money';
import { validateLedger } from '../domain/LedgerRules';
import { calendarMonth, calendarWeek } from '../domain/DateRange';
export interface BudgetInput { id: string; categoryId: string | null; amount: string; period: BudgetPeriod; startDate: string; endDate: string; }
export interface BudgetUsage { usedCents: number; remainingCents: number; percent: number; }
// A month card and its editor must select the same full-month total rule.
export function monthlyTotalBudget(data: LedgerData, today: string): BudgetRule | undefined {
  const month = calendarMonth(today);
  return data.budgets.find((row) => row.scope === 'total' && row.categoryId === null &&
    row.startDate === month.startDate && row.endDate === month.endDate);
}
export function saveMonthlyBudget(data: LedgerData, amount: string, today: string, newId: string, now: string): LedgerData {
  const existing = monthlyTotalBudget(data, today);
  return saveBudget(data, { id: existing?.id || newId, categoryId: null, amount: amount, period: 'month',
    startDate: today, endDate: '' }, now);
}
export function saveBudget(data: LedgerData, input: BudgetInput, now: string): LedgerData {
  const next: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
  const range: DateRange = input.period === 'month' ? calendarMonth(input.startDate) : input.period === 'week' ? calendarWeek(input.startDate) : { startDate: input.startDate, endDate: input.endDate };
  const old = next.budgets.find((row) => row.id === input.id);
  const row: BudgetRule = { id: input.id, scope: input.categoryId === null ? 'total' : 'category', categoryId: input.categoryId,
    amountCents: parseAmount(input.amount), period: input.period, startDate: range.startDate, endDate: range.endDate,
    createdAt: old === undefined ? now : old.createdAt, updatedAt: now };
  if (next.budgets.some((item) => item.id !== row.id && item.categoryId === row.categoryId && item.startDate <= row.endDate && item.endDate >= row.startDate)) {
    throw new LedgerError('BUDGET_OVERLAP');
  }
  if (old === undefined) { next.budgets.push(row); } else { next.budgets[next.budgets.findIndex((item) => item.id === row.id)] = row; }
  validateLedger(next); return next;
}
export function budgetUsage(data: LedgerData, budget: BudgetRule): BudgetUsage {
  let used = 0;
  data.entries.filter((row) => row.type === 'expense' && row.date >= budget.startDate && row.date <= budget.endDate &&
    (budget.categoryId === null || row.categoryId === budget.categoryId)).forEach((row) => { used = addCents(used, row.amountCents); });
  return { usedCents: used, remainingCents: addCents(budget.amountCents, -used), percent: used / budget.amountCents * 100 };
}
export function removeBudget(data: LedgerData, id: string): LedgerData {
  if (!data.budgets.some((row) => row.id === id)) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
  const next: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
  next.budgets = next.budgets.filter((row) => row.id !== id); validateLedger(next); return next;
}
