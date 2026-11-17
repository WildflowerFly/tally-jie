import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
@Component
export struct DepositsPage {
  @ObjectLink state: AppState;
  build() {
    Column({ space: 16 }) {
      Text('存款').fontSize(28).fontWeight(FontWeight.Bold).width('100%')
      Text('账户卡片与转账待接入').fontSize(20)
      Text('余额将从初始余额、收支与转账派生；仅信用卡允许负余额。')
        .fontSize(14).fontColor(FinanceTheme.muted)
    }.padding(20).width('100%').backgroundColor(FinanceTheme.card)
    .borderRadius(FinanceTheme.radius).id('finance-page-deposits')
  }
}
