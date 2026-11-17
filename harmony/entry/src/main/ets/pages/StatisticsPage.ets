import { FinanceCharts } from '../components/FinanceCharts';
import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
import { DateRange, EntryType, LedgerFilter } from '../model/LedgerModels';
import { calendarMonth, calendarWeek } from '../domain/DateRange';
import { statistics, StatisticsResult, TrendUnit, StatBucket, CategoryStat } from '../service/StatisticsService';
import { defaultFilter } from '../service/LedgerQueryService';
import { dateKey, money } from '../model/AppData';
@Component
export struct StatisticsPage {
  @ObjectLink state: AppState;
  onDetails: (filter: LedgerFilter) => void = () => {};
  @State start: string = calendarMonth(dateKey()).startDate;
  @State end: string = calendarMonth(dateKey()).endDate;
  @State income: boolean = false;
  @State unit: TrendUnit = 'day';
  @State result: StatisticsResult = { incomeCents: 0, expenseCents: 0, netCents: 0, averageExpenseCents: 0, categories: [], trend: [], highestDays: [], highestCategories: [] };
  @State error: string = '';
  private appliedIncome: boolean = false;
  private appliedStart: string = this.start;
  private appliedEnd: string = this.end;
  aboutToAppear(): void { this.refresh(); }
  private refresh(): void {
    try { this.result = statistics(this.state.data, { startDate: this.start, endDate: this.end }, this.income ? 'income' : 'expense', this.unit); this.appliedIncome = this.income; this.appliedStart = this.start; this.appliedEnd = this.end; this.error = ''; }
    catch (error) { this.error = (error as Error).message; }
  }
  private period(index: number): void {
    const today = dateKey();
    const range: DateRange = index === 0 ? calendarWeek(today) : index === 1 ? calendarMonth(today) : { startDate: `${today.slice(0, 4)}-01-01`, endDate: `${today.slice(0, 4)}-12-31` };
    this.start = range.startDate; this.end = range.endDate; this.refresh();
  }
  private drill(type: EntryType, category: string = '', start: string = this.appliedStart, end: string = this.appliedEnd): void {
    const filter = defaultFilter(); filter.type = type; filter.range = { startDate: start, endDate: end };
    filter.categoryIds = category ? [category] : []; this.onDetails(filter);
  }
  build() {
    Column({ space: 12 }) {
      Text('统计').fontSize(28).fontWeight(FontWeight.Bold).width('100%')
      Row({ space: 8 }) {
        Button('本周').onClick(() => this.period(0))
        Button('本月').onClick(() => this.period(1))
        Button('本年').onClick(() => this.period(2))
      }
      TextInput({ text: this.start, placeholder: '开始日期 YYYY-MM-DD' }).onChange((value: string) => { this.start = value; })
      TextInput({ text: this.end, placeholder: '结束日期 YYYY-MM-DD' }).onChange((value: string) => { this.end = value; })
      Button('应用自定义范围').onClick(() => this.refresh())
      Text(`${this.appliedStart} 至 ${this.appliedEnd}`).fontSize(13)
      if (this.error) { Text(this.error).fontColor(FinanceTheme.expense) }
      Button(`收入 ¥${money(this.result.incomeCents)}`).fontColor(FinanceTheme.income).backgroundColor('#FFFFFF').onClick(() => this.drill('income'))
      Button(`支出 ¥${money(this.result.expenseCents)}`).fontColor(FinanceTheme.expense).backgroundColor('#FFFFFF').onClick(() => this.drill('expense'))
      Text(`结余 ¥${money(this.result.netCents)} · 日均支出 ¥${money(this.result.averageExpenseCents)}`)
      Text(`最高消费日：${this.result.highestDays.join('、') || '暂无'}\n最高分类：${this.result.highestCategories.join('、') || '暂无'}`).fontSize(14)
      Row({ space: 8 }) {
        Button('支出分布').onClick(() => { this.income = false; this.refresh(); })
        Button('收入分布').onClick(() => { this.income = true; this.refresh(); })
      }
      Select([{ value: '日趋势' }, { value: '周趋势' }, { value: '月趋势' }]).onSelect((index: number) => {
        this.unit = index === 0 ? 'day' : index === 1 ? 'week' : 'month'; this.refresh();
      })
      if (this.result.categories.length === 0) { Text('当前范围暂无数据').fontColor(FinanceTheme.muted) }
      FinanceCharts({ categories: this.result.categories, trend: this.result.trend,
        onCategory: (id: string) => this.drill(this.appliedIncome ? 'income' : 'expense', id),
        onBucket: (row: StatBucket) => this.drill(this.appliedIncome ? 'income' : 'expense', '', row.startDate, row.endDate) })
      ForEach(this.result.categories, (row: CategoryStat) => {
        Button(`${row.name} · ¥${money(row.amountCents)} · ${row.percent.toFixed(1)}%`).width('100%')
          .onClick(() => this.drill(this.appliedIncome ? 'income' : 'expense', row.id))
      }, (row: CategoryStat) => row.id)

    }.width('100%').id('finance-page-statistics')
  }
}
