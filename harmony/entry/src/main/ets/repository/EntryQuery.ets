import { LedgerFilter } from '../model/LedgerModels';
import { validateFilter } from '../domain/LedgerRules';
export interface SqlQuery { sql: string; args: (string | number)[]; }
export interface EntryQueries { page: SqlQuery; totals: SqlQuery; daily: SqlQuery; }
// All user input is bound, including IDs and LIMIT. Literal substring search intentionally avoids LIKE.
export function entryQueries(filter: LedgerFilter): EntryQueries {
  validateFilter(filter);
  const clauses: string[] = [];
  const args: (string | number)[] = [];
  if (filter.type !== null) { clauses.push('e.type=?'); args.push(filter.type); }
  if (filter.accountIds.length) {
    clauses.push(`e.account_id IN (${filter.accountIds.map(() => '?').join(',')})`); args.push(...filter.accountIds);
  }
  if (filter.categoryIds.length) {
    clauses.push(`e.category_id IN (${filter.categoryIds.map(() => '?').join(',')})`); args.push(...filter.categoryIds);
  }
  if (filter.range !== null) { clauses.push('e.date>=? AND e.date<=?'); args.push(filter.range.startDate, filter.range.endDate); }
  if (filter.minAmountCents !== null) { clauses.push('e.amount>=?'); args.push(filter.minAmountCents); }
  if (filter.maxAmountCents !== null) { clauses.push('e.amount<=?'); args.push(filter.maxAmountCents); }
  const keyword = filter.keyword.trim();
  if (keyword) {
    clauses.push('(instr(lower(e.note),lower(?))>0 OR instr(lower(a.name),lower(?))>0 OR instr(lower(c.name),lower(?))>0)');
    args.push(keyword, keyword, keyword);
  }
  const base = ' FROM entries e JOIN accounts a ON a.id=e.account_id JOIN categories c ON c.id=e.category_id';
  const where = clauses.length ? ` WHERE ${clauses.join(' AND ')}` : '';
  const aggregate = 'SUM(CASE WHEN e.type=\'income\' THEN e.amount ELSE 0 END),SUM(CASE WHEN e.type=\'expense\' THEN e.amount ELSE 0 END),COUNT(*)';
  const totals: SqlQuery = { sql: `SELECT ${aggregate}${base}${where}`, args: args.slice() };
  const daily: SqlQuery = { sql: `SELECT e.date,${aggregate}${base}${where} GROUP BY e.date ORDER BY e.date DESC`, args: args.slice() };
  if (filter.cursor !== null) {
    clauses.push('(e.date,e.time,e.id) < (?,?,?)'); args.push(filter.cursor.date, filter.cursor.time, filter.cursor.id);
  }
  args.push(filter.pageSize + 1);
  const page: SqlQuery = { sql: `SELECT e.payload${base}${clauses.length ? ' WHERE ' + clauses.join(' AND ') : ''} ORDER BY e.date DESC,e.time DESC,e.id DESC LIMIT ?`, args: args };
  return { page: page, totals: totals, daily: daily };
}
