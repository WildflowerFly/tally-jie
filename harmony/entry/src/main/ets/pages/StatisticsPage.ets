import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
@Component
export struct StatisticsPage {
  @ObjectLink state: AppState;
  build() {
    Column({ space: 16 }) {
      Text('统计').fontSize(28).fontWeight(FontWeight.Bold).width('100%')
      Text('统计图表待接入').fontSize(20)
      Text('按周、月、年及自定义范围查看真实收支；当前不生成演示图表。')
        .fontSize(14).fontColor(FinanceTheme.muted)
    }.padding(20).width('100%').backgroundColor(FinanceTheme.card)
    .borderRadius(FinanceTheme.radius).id('finance-page-statistics')
  }
}
