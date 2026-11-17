import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
@Component
export struct ProfilePage {
  @ObjectLink state: AppState;
  build() {
    Column({ space: 16 }) {
      Text('我的').fontSize(28).fontWeight(FontWeight.Bold).width('100%')
      Text('本地账本，无需登录').fontSize(20)
      Text('账户、分类、预算及导入导出将在后续任务接入。')
        .fontSize(14).fontColor(FinanceTheme.muted)
      Text('日记与外观设置已下线；旧文件暂保留，不自动删除。')
        .fontSize(14).fontColor(FinanceTheme.muted)
    }.padding(20).width('100%').backgroundColor(FinanceTheme.card)
    .borderRadius(FinanceTheme.radius).id('finance-page-profile')
  }
}
