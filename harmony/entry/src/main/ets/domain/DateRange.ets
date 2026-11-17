import { DateRange, LedgerError } from '../model/LedgerModels';

const DAY_MS: number = 86400000;
// Date-only arithmetic uses UTC to avoid DST/host timezone changing a calendar day.
function utcDate(value: string): Date {
  const parts = value.split('-');
  const result = new Date(0);
  result.setUTCFullYear(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  result.setUTCHours(0, 0, 0, 0);
  return result;
}
function key(date: Date): string {
  return `${date.getUTCFullYear().toString().padStart(4, '0')}-${(date.getUTCMonth() + 1).toString().padStart(2, '0')}-${date.getUTCDate().toString().padStart(2, '0')}`;
}
export function isLedgerDate(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value) && value.slice(0, 4) !== '0000' && key(utcDate(value)) === value;
}
function assertDate(value: string): void {
  if (!isLedgerDate(value)) { throw new LedgerError('INVALID_DATE'); }
}
export function assertRange(range: DateRange): void {
  assertDate(range.startDate); assertDate(range.endDate);
  if (range.startDate > range.endDate) { throw new LedgerError('INVALID_DATE'); }
}
export function calendarWeek(date: string): DateRange {
  assertDate(date);
  const start = utcDate(date);
  start.setUTCDate(start.getUTCDate() - (start.getUTCDay() + 6) % 7);
  const end = new Date(start.getTime() + 6 * DAY_MS);
  const range: DateRange = { startDate: key(start), endDate: key(end) };
  assertRange(range);
  return range;
}
export function calendarMonth(date: string): DateRange {
  assertDate(date);
  const end = utcDate(date);
  end.setUTCMonth(end.getUTCMonth() + 1, 0);
  return { startDate: `${date.slice(0, 7)}-01`, endDate: key(end) };
}
export function containsDate(range: DateRange, date: string): boolean {
  assertRange(range); assertDate(date);
  return date >= range.startDate && date <= range.endDate;
}
export function rangeDays(range: DateRange): number {
  assertRange(range);
  return (utcDate(range.endDate).getTime() - utcDate(range.startDate).getTime()) / DAY_MS + 1;
}
