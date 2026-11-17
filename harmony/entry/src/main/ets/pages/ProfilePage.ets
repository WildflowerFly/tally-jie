import { FinanceHeader, FinanceMenuRow } from '../components/FinanceHeader';
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
      FinanceHeader({ title: '我的', subtitle: 'PERSONAL · 本地账本' })
      Column({ space: 16 }) {
        Text('让每一笔，都有迹可循').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        Text('无需登录 · 数据留在本机').fontSize(13).fontColor('#C8C8C8')
        Row({ space: 24 }) {
          Text(`${this.state.data.accounts.length} 个账户`).fontSize(15).fontColor('#FFFFFF')
          Text(`${this.state.data.categories.length} 个分类`).fontSize(15).fontColor('#FFFFFF')
        }
      }.alignItems(HorizontalAlign.Start).padding(24).width('100%').borderRadius(28)
        .linearGradient({ angle: 120, colors: [['#363636', 0], ['#101010', 1]] })
      Text('账本管理').fontSize(18).fontWeight(FontWeight.Bold).width('100%').margin({ top: 12 })
      FinanceMenuRow({ title: '账户管理', detail: '初始余额、信用卡与账户关联', glyph: '▣', onOpen: () => { this.section = 'accounts'; } })
      FinanceMenuRow({ title: '分类管理', detail: '用自己的方式整理收支', glyph: '▦', onOpen: () => { this.section = 'categories'; } })
      FinanceMenuRow({ title: '预算管理', detail: '为每个周期设定消费边界', glyph: '◷', onOpen: () => { this.section = 'budgets'; } })
      FinanceMenuRow({ title: '导入 / 导出', detail: '预览合并与可移植本地备份', glyph: '⇅', onOpen: () => { this.section = 'exchange'; } })
      Text('离线使用 · 请妥善保管导出的财务文件').fontSize(12).fontColor(FinanceTheme.muted).margin({ top: 12 })
      }
    }.width('100%').id('finance-page-profile')
  }
}
