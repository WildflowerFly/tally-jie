import { CategoryStat, StatBucket } from '../service/StatisticsService';
import { ringHit, trendHit, trendY } from '../domain/ChartGeometry';
import { money } from '../model/AppData';

@Component
export struct FinanceCharts {
  @Prop @Watch('redraw') categories: CategoryStat[] = [];
  @Prop @Watch('reset') trend: StatBucket[] = [];
  @State bucketOffset: number = 0;
  @State chartWidth: number = 300;
  private ring: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private line: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  onCategory: (id: string) => void = () => {};
  onBucket: (bucket: StatBucket) => void = () => {};
  private palette: string[] = ['#171717', '#269B73', '#E16C61', '#536878', '#81736A', '#707070', '#466351', '#A56551'];
  private reset(): void { this.bucketOffset = 0; this.redraw(); }
  private visible(): StatBucket[] { return this.trend.slice(this.bucketOffset, this.bucketOffset + 14); }
  private redraw(): void { this.drawRing(); this.drawTrend(); }
  private drawRing(): void {
    const ctx = this.ring; ctx.clearRect(0, 0, 220, 220);
    const total = this.categories.reduce((sum: number, row: CategoryStat) => sum + row.amountCents, 0);
    let angle = -Math.PI / 2;
    if (total === 0) {
      ctx.beginPath(); ctx.arc(110, 110, 81.4, 0, Math.PI * 2); ctx.lineWidth = 39.6; ctx.strokeStyle = '#EEEEEE'; ctx.stroke();
    }
    this.categories.forEach((row: CategoryStat, index: number) => {
      const end = angle + (total > 0 ? row.amountCents / total : 0) * 2 * Math.PI;
      ctx.beginPath(); ctx.arc(110, 110, 81.4, angle, end); ctx.lineWidth = 39.6;
      ctx.strokeStyle = this.palette[index % this.palette.length]; ctx.stroke(); angle = end;
    });
    ctx.fillStyle = '#171717'; ctx.font = 'bold 17vp sans-serif'; ctx.textAlign = 'center';
    ctx.fillText(`¥${money(total)}`, 110, 114);
  }
  private drawTrend(): void {
    const ctx = this.line; const rows = this.visible(); const max = Math.max(0, ...rows.map((row: StatBucket) => row.amountCents));
    ctx.clearRect(0, 0, this.chartWidth, 180);
    ctx.strokeStyle = '#DDDDDD'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(20, 160); ctx.lineTo(this.chartWidth - 20, 160); ctx.stroke();
    ctx.strokeStyle = '#171717'; ctx.lineWidth = 2; ctx.beginPath();
    rows.forEach((row: StatBucket, index: number) => {
      const x = rows.length === 1 ? this.chartWidth / 2 : 20 + index * (this.chartWidth - 40) / (rows.length - 1);
      const y = trendY(row.amountCents, max, 180);
      if (index === 0) { ctx.moveTo(x, y); } else { ctx.lineTo(x, y); }
    }); ctx.stroke();
    ctx.fillStyle = '#269B73';
    rows.forEach((row: StatBucket, index: number) => {
      const x = rows.length === 1 ? this.chartWidth / 2 : 20 + index * (this.chartWidth - 40) / (rows.length - 1);
      ctx.beginPath(); ctx.arc(x, trendY(row.amountCents, max, 180), 4, 0, Math.PI * 2); ctx.fill();
    });
  }
  build() {
    Column({ space: 10 }) {
      Text('分类占比 · 点按扇区查看明细').fontSize(16)
      Canvas(this.ring).width(220).height(220).onReady(() => this.drawRing())
        .accessibilityText('分类环形图。下方每个分类按钮提供相同明细操作。')
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Up && event.changedTouches.length) {
            const point = event.changedTouches[0];
            const hit = ringHit(this.categories.map((row: CategoryStat) => row.amountCents), point.x, point.y, 220);
            if (hit >= 0) { this.onCategory(this.categories[hit].id); }
          }
        })
      Text('趋势 · 点按数据点查看明细').fontSize(16)
      Text(`最高 ¥${money(Math.max(0, ...this.visible().map((row: StatBucket) => row.amountCents)))}`).fontSize(12)
      Canvas(this.line).width('100%').height(180).onReady(() => this.drawTrend())
        .onAreaChange((_old: Area, area: Area) => { this.chartWidth = Number(area.width); this.drawTrend(); })
        .accessibilityText('收支折线图。下方日期按钮提供相同明细操作，零值也可点选。')
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Up && event.changedTouches.length) {
            const point = event.changedTouches[0]; const rows = this.visible();
            const hit = trendHit(rows.map((row: StatBucket) => row.amountCents), point.x, point.y, this.chartWidth, 180);
            if (hit >= 0) { this.onBucket(rows[hit]); }
          }
        })
      Row({ space: 8 }) {
        Button('前14项').enabled(this.bucketOffset > 0).onClick(() => { this.bucketOffset = Math.max(0, this.bucketOffset - 14); this.drawTrend(); })
        Text(`${this.trend.length ? this.bucketOffset + 1 : 0}–${Math.min(this.bucketOffset + 14, this.trend.length)} / ${this.trend.length}`).fontSize(12)
        Button('后14项').enabled(this.bucketOffset + 14 < this.trend.length).onClick(() => { this.bucketOffset += 14; this.drawTrend(); })
      }
      ForEach(this.visible(), (row: StatBucket) => {
        Button(`${row.startDate} ~ ${row.endDate} · ¥${money(row.amountCents)}`)
          .width('100%').fontSize(13).onClick(() => this.onBucket(row))
      }, (row: StatBucket) => row.key)
    }.width('100%')
  }
}
