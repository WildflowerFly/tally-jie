import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
@Component
export struct DetailsPage {
  @ObjectLink state: AppState;
  build() {
    Column({ space: 16 }) {
      Text('明细').fontSize(28).fontWeight(FontWeight.Bold).width('100%')
      Text('账单列表与筛选待接入').fontSize(20)
      Text('后续支持按日期分组、组合筛选以及编辑删除。当前不展示未经筛选的占位账单。')
        .fontSize(14).fontColor(FinanceTheme.muted)
    }.padding(20).width('100%').backgroundColor(FinanceTheme.card)
    .borderRadius(FinanceTheme.radius).id('finance-page-details')
  }
}
