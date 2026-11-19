import { CategoryStat, StatBucket, TrendUnit } from '../service/StatisticsService';
import { ringHit } from '../domain/ChartGeometry';
import { money } from '../model/AppData';
import { FinanceTheme } from '../theme/FinanceTheme';
import { categoryImage } from './CategoryIcon';

@Component
export struct FinanceCharts {
  @Prop @Watch('redraw') categories: CategoryStat[] = [];
  @Prop @Watch('reset') trend: StatBucket[] = [];
  @Prop income: boolean = false;
  @Prop unit: TrendUnit = 'month';
  @Prop selectedKey: string = '';
  @Prop categoryPeriod: string = '';
  @State bucketOffset: number = 0;
  private ring: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  onCategory: (id: string) => void = () => {};
  onBucket: (bucket: StatBucket) => void = () => {};
  onUnit: (unit: TrendUnit) => void = () => {};
  private palette: string[] = ['#918B82', '#D8A77F', '#D97C70', '#C0AA59', '#A48AAF', '#7EA6AE', '#87A38B', '#8C98B6'];

  private reset(): void {
    // Open at the latest six buckets; previous periods remain available via paging.
    this.bucketOffset = Math.max(0, this.trend.length - 6);
    this.redraw();
  }
  aboutToAppear(): void { this.reset(); }
  private visible(): StatBucket[] { return this.trend.slice(this.bucketOffset, this.bucketOffset + 6); }
  private redraw(): void { this.drawRing(); }
  private color(index: number): string { return this.palette[index % this.palette.length]; }
  private total(): number { return this.categories.reduce((sum: number, row: CategoryStat) => sum + row.amountCents, 0); }
  private max(): number { return Math.max(0, ...this.visible().map((row: StatBucket) => row.amountCents)); }
  private barHeight(row: StatBucket): number {
    return row.amountCents > 0 && this.max() > 0 ? Math.max(8, row.amountCents / this.max() * 116) : 3;
  }
  private label(row: StatBucket): string {
    return this.unit === 'month' ? `${Number(row.startDate.slice(5, 7))}月` :
      `${Number(row.startDate.slice(5, 7))}/${Number(row.startDate.slice(8, 10))}`;
  }
  private drawRing(): void {
    const ctx = this.ring;
    ctx.clearRect(0, 0, 200, 200);
    const total = this.total();
    let angle = -Math.PI / 2;
    ctx.beginPath(); ctx.arc(100, 100, 74, 0, Math.PI * 2);
    ctx.lineWidth = 24; ctx.strokeStyle = '#F0F0F0'; ctx.stroke();
    this.categories.forEach((row: CategoryStat, index: number) => {
      const end = angle + (total > 0 ? row.amountCents / total : 0) * 2 * Math.PI;
      if (row.amountCents > 0) {
        ctx.beginPath(); ctx.arc(100, 100, 74, angle, end); ctx.lineWidth = 24;
        ctx.strokeStyle = this.color(index); ctx.stroke();
      }
      angle = end;
    });
  }

  @Builder
  unitChip(label: string, value: TrendUnit) {
    Button(label, { type: ButtonType.Normal }).height(28).padding({ left: 10, right: 10 }).fontSize(11)
      .backgroundColor(this.unit === value ? '#EEEEEE' : Color.Transparent)
      .fontColor(this.unit === value ? FinanceTheme.text : FinanceTheme.muted).borderRadius(8)
      .onClick(() => this.onUnit(value))
  }

  @Builder
  trendCard() {
    Column({ space: 16 }) {
      Row() {
        Text(`${this.unit === 'month' ? '每月' : this.unit === 'week' ? '每周' : '每日'}${this.income ? '收入' : '支出'}趋势`)
          .fontSize(17).fontWeight(FontWeight.Medium).fontColor(FinanceTheme.text).layoutWeight(1)
        Row({ space: 2 }) {
          this.unitChip('日', 'day')
          this.unitChip('周', 'week')
          this.unitChip('月', 'month')
        }
      }.width('100%')
      Row() {
        Text(`最高 ¥${money(this.max())}`).fontSize(10).fontColor(FinanceTheme.muted)
        Blank()
        if (this.trend.length > 6) {
          Button('‹', { type: ButtonType.Normal }).width(28).height(26).padding(0).fontSize(20)
            .backgroundColor(Color.Transparent).fontColor(FinanceTheme.text).enabled(this.bucketOffset > 0)
            .accessibilityText('查看更早的趋势').onClick(() => { this.bucketOffset = Math.max(0, this.bucketOffset - 6); })
          Text(`${this.bucketOffset + 1}–${Math.min(this.bucketOffset + 6, this.trend.length)}`)
            .fontSize(10).fontColor(FinanceTheme.muted)
          Button('›', { type: ButtonType.Normal }).width(28).height(26).padding(0).fontSize(20)
            .backgroundColor(Color.Transparent).fontColor(FinanceTheme.text).enabled(this.bucketOffset + 6 < this.trend.length)
            .accessibilityText('查看更近的趋势').onClick(() => { this.bucketOffset = Math.min(this.trend.length - 6, this.bucketOffset + 6); })
        }
      }.width('100%')
      Row({ space: 6 }) {
        ForEach(this.visible(), (row: StatBucket) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: 12 }) {
              Column() {
                Blank()
                Row().width(15).height(this.barHeight(row)).borderRadius(8)
                  .backgroundColor(this.income ? FinanceTheme.income :
                    row.key === this.selectedKey ? FinanceTheme.text : '#D0D0D0')
                  .opacity(this.income && row.key !== this.selectedKey ? 0.28 : 1)
              }.height(124).width('100%').padding({ bottom: 0 })
              Text(this.label(row)).fontSize(11).fontColor(row.key === this.selectedKey ? FinanceTheme.text : FinanceTheme.muted)
                .fontWeight(row.key === this.selectedKey ? FontWeight.Medium : FontWeight.Normal)
            }.width('100%')
          }.layoutWeight(1).padding({ top: 8, bottom: 10 }).borderRadius(12)
            .backgroundColor(row.key === this.selectedKey ? '#F8F8F8' : Color.Transparent)
            .accessibilityText(`${row.startDate} 至 ${row.endDate}，${this.income ? '收入' : '支出'} ${money(row.amountCents)} 元，点击更新下方分类统计`)
            .onClick(() => this.onBucket(row))
        }, (row: StatBucket) => row.key)
      }.width('100%').alignItems(VerticalAlign.Bottom).id('statistics-trend-bars')
      Row({ space: 6 }) {
        Row().width(6).height(6).borderRadius(3).backgroundColor(this.income ? FinanceTheme.income : FinanceTheme.text)
        Text(this.income ? '收入' : '支出').fontSize(11).fontColor(FinanceTheme.muted)
      }.justifyContent(FlexAlign.Center).width('100%')
    }.padding(20).width('100%').backgroundColor(FinanceTheme.card).borderRadius(22)
  }

  @Builder
  categoryCard() {
    Column({ space: 12 }) {
      Text(`${this.income ? '收入' : '支出'}分类`).fontSize(17).fontWeight(FontWeight.Medium)
        .fontColor(FinanceTheme.text).width('100%')
      if (this.categoryPeriod) {
        Text(this.categoryPeriod).fontSize(11).fontColor(FinanceTheme.muted).width('100%')
      }
      Stack() {
        Canvas(this.ring).width(200).height(200).onReady(() => this.drawRing())
          .accessibilityText('分类环形图，下方分类列表可查看相同明细')
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Up && event.changedTouches.length) {
              const point = event.changedTouches[0];
              // Narrow the geometry helper's hit area to the rendered 24vp ring.
              const hit = ringHit(this.categories.map((row: CategoryStat) => row.amountCents), point.x, point.y, 200);
              const radius = Math.sqrt((point.x - 100) * (point.x - 100) + (point.y - 100) * (point.y - 100));
              if (hit >= 0 && radius >= 62 && radius <= 86) { this.onCategory(this.categories[hit].id); }
            }
          })
        Column({ space: 5 }) {
          Text(`¥${money(this.total())}`).fontSize(18).fontWeight(FontWeight.Medium).fontColor(FinanceTheme.text)
            .width(116).maxLines(1).minFontSize(10).maxFontSize(18).textAlign(TextAlign.Center)
          Text(this.income ? '总收入' : '总支出').fontSize(10).fontColor(FinanceTheme.muted)
        }.hitTestBehavior(HitTestMode.None)
      }.width('100%').height(200)
      if (!this.categories.length) {
        Text('当前范围暂无数据').fontSize(13).fontColor(FinanceTheme.muted).margin({ bottom: 12 })
      }
      ForEach(this.categories, (row: CategoryStat, index: number) => {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 12 }) {
            Row() {
              // Do not use fillColor on outline SVGs: it fills their hollow paths.
              Image(categoryImage(row.name, row.iconKey || 'category')).width(21).height(21)
                .supportSvg2(true).accessibilityLevel('no').id(`statistics-category-icon-${row.id}`)
            }.width(36).height(36).justifyContent(FlexAlign.Center).backgroundColor('#F5F5F5').borderRadius(12)
            Text(row.name).fontSize(14).fontColor(FinanceTheme.text).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`¥${money(row.amountCents)}`).fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.color(index))
            Text(`${row.percent.toFixed(1)}%`).fontSize(12).fontColor(this.color(index)).width(48).textAlign(TextAlign.End)
          }.width('100%')
        }.width('100%').constraintSize({ minHeight: 44 }).padding({ top: 5, bottom: 5 })
          .backgroundColor(Color.Transparent).borderRadius(10)
          .accessibilityText(`${row.name}，${money(row.amountCents)} 元，占比 ${row.percent.toFixed(1)}%，查看明细`)
          .onClick(() => this.onCategory(row.id))
      }, (row: CategoryStat) => row.id)
    }.padding(20).width('100%').backgroundColor(FinanceTheme.card).borderRadius(22).id('statistics-categories')
  }

  build() {
    Column({ space: 16 }) {
      this.trendCard()
      this.categoryCard()
    }.width('100%')
  }
}
