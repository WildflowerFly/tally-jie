import { FinanceCharts } from '../components/FinanceCharts';
import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
import { DateRange, LedgerFilter } from '../model/LedgerModels';
import { calendarMonth } from '../domain/DateRange';
import { statistics, StatisticsResult, TrendUnit, StatBucket, CategoryStat } from '../service/StatisticsService';
import { defaultFilter } from '../service/LedgerQueryService';
import { dateKey, money } from '../model/AppData';

function recentMonths(): DateRange {
  const today = dateKey();
  const date = new Date(`${today.slice(0, 7)}-01T12:00:00Z`);
  date.setUTCMonth(date.getUTCMonth() - 5);
  return { startDate: date.toISOString().slice(0, 10), endDate: calendarMonth(today).endDate };
}

@Component
export struct StatisticsPage {
  @ObjectLink state: AppState;
  @Prop @Watch('refresh') refreshVersion: number = 0;
  onDetails: (filter: LedgerFilter) => void = () => {};
  @State unit: TrendUnit = 'month';
  @State result: StatisticsResult = { incomeCents: 0, expenseCents: 0, netCents: 0, averageExpenseCents: 0, categories: [], trend: [], highestDays: [], highestCategories: [] };
  @State count: number = 0;
  @State categories: CategoryStat[] = [];
  @State selectedKey: string = '';
  @State categoryStart: string = '';
  @State categoryEnd: string = '';
  @State categoryPeriod: string = '';
  private range: DateRange = recentMonths();

  aboutToAppear(): void { this.refresh(); }

  private refresh(): void {
    this.range = recentMonths();
    this.result = statistics(this.state.data, this.range, 'expense', this.unit);
    this.count = this.state.data.entries.filter((row) => row.type === 'expense' && row.date >= this.range.startDate && row.date <= this.range.endDate).length;
    // The initial highlight and category breakdown always refer to the same bucket.
    if (this.result.trend.length) {
      this.selectBucket(this.result.trend[this.result.trend.length - 1]);
    } else {
      this.categories = [];
      this.selectedKey = '';
      this.categoryStart = this.range.startDate;
      this.categoryEnd = this.range.endDate;
      this.categoryPeriod = '';
    }
  }

  private selectBucket(row: StatBucket): void {
    this.categories = statistics(this.state.data, { startDate: row.startDate, endDate: row.endDate }, 'expense', this.unit).categories;
    this.selectedKey = row.key;
    this.categoryStart = row.startDate;
    this.categoryEnd = row.endDate;
    this.categoryPeriod = this.unit === 'month' ? `${row.startDate.slice(0, 4)}年${Number(row.startDate.slice(5, 7))}月` :
      this.unit === 'day' ? row.startDate.replace(/-/g, '.') :
      `${row.startDate.replace(/-/g, '.')} — ${row.endDate.replace(/-/g, '.')}`;
  }

  private drill(category: string = '', start: string = this.range.startDate, end: string = this.range.endDate): void {
    const filter = defaultFilter();
    filter.type = 'expense';
    filter.range = { startDate: start, endDate: end };
    filter.categoryIds = category ? [category] : [];
    this.onDetails(filter);
  }

  build() {
    Column({ space: 16 }) {
      Button({ type: ButtonType.Normal }) {
        Column({ space: 10 }) {
          Text(`共支出 ${this.count} 笔`).fontSize(13).fontColor(FinanceTheme.muted)
          Text(`合计 ¥${money(this.result.expenseCents)}`)
            .fontSize(27).fontWeight(FontWeight.Medium).fontColor(FinanceTheme.text)
            .maxLines(1).minFontSize(16).maxFontSize(27).width('100%').textAlign(TextAlign.Center)
        }.width('100%')
      }.width('100%').padding(24).backgroundColor(FinanceTheme.card).borderRadius(22)
        .id('statistics-summary').onClick(() => this.drill())

      FinanceCharts({ categories: this.categories, trend: this.result.trend, unit: this.unit,
        selectedKey: this.selectedKey, categoryPeriod: this.categoryPeriod,
        onUnit: (unit: TrendUnit) => { this.unit = unit; this.refresh(); },
        onCategory: (id: string) => this.drill(id, this.categoryStart, this.categoryEnd),
        onBucket: (row: StatBucket) => this.selectBucket(row) })
    }.width('100%').id('finance-page-statistics')
  }
}
