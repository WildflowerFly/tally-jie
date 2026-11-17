import { common } from '@kit.AbilityKit';
import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
import { FloatingNavBar } from '../components/FloatingNavBar';
import { StatisticsPage } from './StatisticsPage';
import { DetailsPage } from './DetailsPage';
import { RecordPage } from './RecordPage';
import { DepositsPage } from './DepositsPage';
import { ProfilePage } from './ProfilePage';
import { InitialBalanceInput } from '../service/LegacyMigration';
import { LedgerFilter } from '../model/LedgerModels';
import { defaultFilter } from '../service/LedgerQueryService';

@Entry
@Component
struct Index {
  @State app: AppState = new AppState();
  @State selected: number = 2;
  @State amount: string = '';
  @State note: string = '';
  @State dirty: boolean = false;
  @State profileSection: string = '';
  @State detailsFilter: LedgerFilter = defaultFilter();
  @State repairAmounts: string[] = [];
  aboutToAppear(): void { this.reload(); }
  private reload(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.app.load(context);
  }
  private changeTab(index: number): void {
    if (index === this.selected) { return; }
    if (this.selected === 2 && this.dirty) {
      this.getUIContext().showAlertDialog({
        title: '保留未保存的输入？', message: '切换页面不会保存账单，返回记账时仍可继续编辑。',
        primaryButton: { value: '继续编辑', action: () => {} },
        secondaryButton: { value: '保留并切换', action: () => { this.selected = index; } }
      });
      return;
    }
    if (index === 1) { this.detailsFilter = defaultFilter(); }
    this.selected = index;
  }
  onBackPress(): boolean {
    if (!this.dirty) { return false; }
    this.getUIContext().showAlertDialog({
      title: '尚有未保存的输入', message: '继续编辑，或清空输入后再次返回退出。',
      primaryButton: { value: '继续编辑', action: () => {} },
      secondaryButton: { value: '清空输入', action: () => { this.amount = ''; this.note = ''; this.dirty = false; } }
    });
    return true;
  }
  private repair(): void {
    const draft = this.app.draft;
    if (draft === null) { return; }
    const inputs: InitialBalanceInput[] = [];
    draft.requiredAccountIds.forEach((id: string, index: number) => {
      inputs.push({ accountId: id, amount: this.repairAmounts[index] || '' });
    });
    this.app.load(this.getUIContext().getHostContext() as common.UIAbilityContext, inputs);
  }
  @Builder
  statusCard() {
    Column({ space: 12 }) {
      if (this.app.status === 'loading') {
        Text('正在载入本地账本…').fontColor(FinanceTheme.muted)
      } else if (this.app.status === 'error') {
        Text('账本载入失败，已禁止写入').fontColor(FinanceTheme.expense)
        Text(this.app.message).fontSize(13).fontColor(FinanceTheme.muted)
        Button('重试').onClick(() => this.reload())
      } else if (this.app.status === 'repair' && this.app.draft !== null) {
        Text('迁移前请补录初始余额').fontSize(20).fontWeight(FontWeight.Bold)
        Text('历史净支出使普通账户低于0，不能直接启用。原文件未修改；不推算或伪造余额。').fontSize(14)
        ForEach(this.app.draft.requiredAccountIds, (id: string, index: number) => {
          Text(this.app.draft!.data.accounts.find((account) => account.id === id)!.name)
          TextInput({ placeholder: '真实初始余额', text: this.repairAmounts[index] || '' })
            .onChange((value: string) => { this.repairAmounts[index] = value; })
        }, (id: string) => id)
        Button('验证并迁移').onClick(() => this.repair())
      } else if (this.app.data.accounts.some((account) => account.needsInitialBalance)) {
        Text('历史账户初始余额暂为0，请在账户管理接入后补录；当前余额不代表真实资产。')
          .fontSize(14).fontColor(FinanceTheme.muted)
      }
      if (this.app.status === 'ready' && this.app.message.length > 0) {
        Text(this.app.message).fontColor(FinanceTheme.expense)
      }
    }.padding(16).width('100%').backgroundColor(FinanceTheme.card).borderRadius(FinanceTheme.radius)
  }
  build() {
    Column({ space: 0 }) {
      Scroll() {
        Column({ space: 16 }) {
          if (this.app.status !== 'ready' || this.app.message.length > 0 ||
            this.app.data.accounts.some((account) => account.needsInitialBalance)) { this.statusCard() }
          if (this.selected === 0) { StatisticsPage({ state: this.app,
            onDetails: (filter: LedgerFilter) => { this.detailsFilter = filter; this.selected = 1; } }) }
          else if (this.selected === 1) { DetailsPage({ state: this.app, initialFilter: this.detailsFilter,
            onBudgets: () => { this.profileSection = 'budgets'; this.selected = 4; } }) }
          else if (this.selected === 3) { DepositsPage({ state: this.app,
            onDetails: (filter: LedgerFilter) => { this.detailsFilter = filter; this.selected = 1; },
            onManage: () => { this.profileSection = 'accounts'; this.selected = 4; } }) }
          else if (this.selected === 4) { ProfilePage({ state: this.app, section: $profileSection }) }
          RecordPage({ state: this.app, amount: $amount, note: $note,
            onDirty: () => { this.dirty = this.amount.length > 0 || this.note.length > 0; },
            onManageAccounts: () => { this.profileSection = 'accounts'; this.selected = 4; },
            onManageCategories: () => { this.profileSection = 'categories'; this.selected = 4; } })
            .visibility(this.selected === 2 ? Visibility.Visible : Visibility.None)
        }.padding(20).width('100%')
      }.layoutWeight(1).width('100%').align(Alignment.Top)
      FloatingNavBar({ selected: this.selected, onSelect: (index: number) => this.changeTab(index) })
        .margin({ left: 16, right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor(FinanceTheme.background)
  }
}
