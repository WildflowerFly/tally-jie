import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
import { AccountManagePage } from './AccountManagePage';
import { CategoryManagePage } from './CategoryManagePage';
import { BudgetManagePage } from './BudgetManagePage';
import { DataExchangePage } from './DataExchangePage';
@Component
export struct ProfilePage {
  @ObjectLink state: AppState;
  @Link section: string;
  build() {
    Column({ space: 16 }) {
      if (this.section === 'accounts') {
        AccountManagePage({ state: this.state, onBack: () => { this.section = ''; } })
      } else if (this.section === 'categories') {
        CategoryManagePage({ state: this.state, onBack: () => { this.section = ''; } })
      } else if (this.section === 'budgets') {
        BudgetManagePage({ state: this.state, onBack: () => { this.section = ''; } })
      } else if (this.section === 'exchange') {
        DataExchangePage({ state: this.state, onBack: () => { this.section = ''; } })
      } else {
      Button('导入 / 导出').onClick(() => { this.section = 'exchange'; })
      Button('预算管理').onClick(() => { this.section = 'budgets'; })
      Button('分类管理').onClick(() => { this.section = 'categories'; })
      Button('账户管理').onClick(() => { this.section = 'accounts'; })
      Text('我的').fontSize(28).fontWeight(FontWeight.Bold).width('100%')
      Text('本地账本，无需登录').fontSize(20)
      Text('账户、分类、预算及数据交换均在本地处理。')
        .fontSize(14).fontColor(FinanceTheme.muted)
      Text('日记与外观设置已下线；旧文件暂保留，不自动删除。')
        .fontSize(14).fontColor(FinanceTheme.muted)
      }
    }.padding(20).width('100%').backgroundColor(FinanceTheme.card)
    .borderRadius(FinanceTheme.radius).id('finance-page-profile')
  }
}
