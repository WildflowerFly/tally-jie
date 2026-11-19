import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
import { CategoryManagePage } from './CategoryManagePage';
import { BudgetManagePage } from './BudgetManagePage';
import { DataExchangePage } from './DataExchangePage';

@Component
export struct ProfilePage {
  @ObjectLink state: AppState;
  @Link section: string;
  onAccounts: () => void = () => {};

  @Builder
  summaryMetric(value: string, label: string, metricId: string) {
    Column({ space: 6 }) {
      Text(value).fontSize(26).fontWeight(FontWeight.Normal).fontColor(FinanceTheme.text).id(metricId)
      Text(label).fontSize(11).fontColor(FinanceTheme.muted)
    }.layoutWeight(1).accessibilityGroup(true).accessibilityText(`${value} 个${label}`)
  }

  @Builder
  overviewCard() {
    Column({ space: 20 }) {
      Row() {
        Row({ space: 6 }) {
          Row().width(5).height(5).borderRadius(3).backgroundColor(FinanceTheme.text).accessibilityLevel('no')
          Text('本地账本').fontSize(13).fontWeight(FontWeight.Medium).fontColor(FinanceTheme.text)
        }
        Blank()
        Text('CNY').fontSize(10).fontColor(FinanceTheme.muted)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(FinanceTheme.background).borderRadius(6).accessibilityText('本位币，人民币')
      }.width('100%')
      Row() {
        this.summaryMetric(`${this.state.data.accounts.length}`, '账户', 'profile-account-count')
        Divider().vertical(true).height(28).color('#EEEEEE')
        this.summaryMetric(`${this.state.data.categories.length}`, '分类', 'profile-category-count')
        Divider().vertical(true).height(28).color('#EEEEEE')
        this.summaryMetric(`${this.state.data.budgets.length}`, '预算', 'profile-budget-count')
      }.width('100%')
    }.padding(20).width('100%').backgroundColor(FinanceTheme.card).borderRadius(22)
      .id('profile-overview')
  }

  @Builder
  managementCard(icon: Resource, title: string, detail: string, target: string) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 16 }) {
        Row() {
          Image(icon).width(20).height(20).accessibilityLevel('no')
        }.width('100%').height(34)
        Column({ space: 5 }) {
          Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(FinanceTheme.text)
          Text(detail).fontSize(11).fontColor(FinanceTheme.muted).lineHeight(16)
        }.alignItems(HorizontalAlign.Start).width('100%')
      }.alignItems(HorizontalAlign.Start).width('100%')
    }.layoutWeight(1).constraintSize({ minHeight: 126 }).padding(16)
      .backgroundColor(FinanceTheme.card).borderRadius(20)
      .accessibilityText(`${title}，${detail}`).id(`profile-manage-${target}`)
      .onClick(() => { if (target === 'accounts') { this.onAccounts(); } else { this.section = target; } })
  }

  @Builder
  dashboard() {
    Column({ space: 20 }) {
      this.overviewCard()
      Column({ space: 12 }) {
        Text('账本管理').fontSize(13).fontWeight(FontWeight.Medium).fontColor(FinanceTheme.muted)
          .width('100%').padding({ left: 2 }).margin({ top: 4, bottom: 2 })
        Row({ space: 12 }) {
          this.managementCard($r('app.media.profile_accounts'), '账户管理', '初始余额与信用卡', 'accounts')
          this.managementCard($r('app.media.profile_categories'), '分类管理', '整理收入与支出', 'categories')
        }.width('100%')
        Row({ space: 12 }) {
          this.managementCard($r('app.media.profile_budgets'), '预算管理', '规划每一份支出', 'budgets')
          this.managementCard($r('app.media.profile_exchange'), '导入 / 导出', '数据合并与本地备份', 'exchange')
        }.width('100%')
      }.width('100%').id('profile-management-grid')
    }.width('100%')
  }

  build() {
    Column() {
      if (this.section === 'categories') {
        CategoryManagePage({ state: this.state, onBack: () => { this.section = ''; } })
      } else if (this.section === 'budgets') {
        BudgetManagePage({ state: this.state, onBack: () => { this.section = ''; } })
      } else if (this.section === 'exchange') {
        DataExchangePage({ state: this.state, onBack: () => { this.section = ''; } })
      } else {
        this.dashboard()
      }
    }.width('100%').id('finance-page-profile')
  }
}
