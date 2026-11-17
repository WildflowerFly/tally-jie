import { LedgerData, EntryType, Category, LedgerError } from '../model/LedgerModels';
import { validateLedger, assertCategoryRemovable } from '../domain/LedgerRules';
export const CATEGORY_ICONS: string[] = ['category', 'food', 'travel', 'home', 'shopping', 'salary', 'gift'];
export const CATEGORY_GLYPHS: string[] = ['●', '餐', '行', '家', '购', '薪', '礼'];
export function categoryLabel(icon: string): string {
  const index = CATEGORY_ICONS.indexOf(icon); return index < 0 ? '●' : CATEGORY_GLYPHS[index];
}
export function upsertCategory(data: LedgerData, id: string, name: string, type: EntryType,
  icon: string, order: number, now: string): LedgerData {
  const next: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
  const trimmed = name.trim();
  if (!trimmed || trimmed.length > 30 || !CATEGORY_ICONS.includes(icon) || !Number.isSafeInteger(order) || order < 0 ||
    next.categories.some((row) => row.id !== id && row.type === type && row.name === trimmed)) { throw new LedgerError('INVALID_ENTITY'); }
  const old = next.categories.find((row) => row.id === id);
  if (old !== undefined && old.type !== type &&
    (next.entries.some((row) => row.categoryId === id) || next.budgets.some((row) => row.categoryId === id))) {
    throw new LedgerError('REFERENCE_IN_USE');
  }
  const row: Category = { id: id, name: trimmed, type: type, iconKey: icon, sortOrder: order,
    createdAt: old === undefined ? now : old.createdAt, updatedAt: now };
  if (old === undefined) { next.categories.push(row); }
  else { next.categories[next.categories.findIndex((item) => item.id === id)] = row; }
  validateLedger(next); return next;
}
export function removeCategory(data: LedgerData, id: string, targetId: string | null = null): LedgerData {
  const next: LedgerData = JSON.parse(JSON.stringify(data)) as LedgerData;
  const source = next.categories.find((row) => row.id === id);
  if (source === undefined) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
  if (targetId === null) { assertCategoryRemovable(next, id); }
  else {
    const target = next.categories.find((row) => row.id === targetId);
    if (target === undefined || targetId === id) { throw new LedgerError('REFERENCE_NOT_FOUND'); }
    if (target.type !== source.type) { throw new LedgerError('CATEGORY_TYPE_MISMATCH'); }
    // Reject intersecting budget scopes, including different period labels; never silently combine money.
    const sourceBudgets = next.budgets.filter((row) => row.categoryId === id);
    const targetBudgets = next.budgets.filter((row) => row.categoryId === targetId);
    if (sourceBudgets.some((left) => targetBudgets.some((right) => left.startDate <= right.endDate && right.startDate <= left.endDate))) {
      throw new LedgerError('BUDGET_OVERLAP');
    }
    next.entries.forEach((row) => { if (row.categoryId === id) { row.categoryId = targetId; } });
    next.budgets.forEach((row) => { if (row.categoryId === id) { row.categoryId = targetId; } });
  }
  next.categories = next.categories.filter((row) => row.id !== id);
  validateLedger(next); return next;
}
