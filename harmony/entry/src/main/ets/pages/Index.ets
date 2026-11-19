import { common } from '@kit.AbilityKit';
import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
import { DetailsPalette } from '../theme/DetailsPalette';
import { FloatingNavBar } from '../components/FloatingNavBar';
import { StatisticsPage } from './StatisticsPage';
import { DetailsPage } from './DetailsPage';
import { MonthlyBudgetSheet } from '../components/MonthlyBudgetSheet';
import { RecordPage } from './RecordPage';
import { DepositsPage } from './DepositsPage';
import { ProfilePage } from './ProfilePage';
import { InitialBalanceInput } from '../service/LegacyMigration';
import { LedgerFilter } from '../model/LedgerModels';
import { defaultFilter } from '../service/LedgerQueryService';
import { keypadAmount } from '../service/TransactionService';
import { calendarMonth } from '../domain/DateRange';
import { dateKey } from '../model/AppData';
import { DEPOSIT_NAV_CLEARANCE } from '../domain/DepositLayout';

@Entry
@Component
struct Index {
  @State app: AppState = new AppState();
  @State selected: number = 2;
  @State depositDetail: boolean = false;
  private accountReturnTab: number = 3;
  @State amount: string = '';
  @State note: string = '';
  @State dirty: boolean = false;
  @State profileSection: string = '';
  @State detailsFilter: LedgerFilter = defaultFilter();
  @State repairAmounts: string[] = [];
  @State keypadOpen: boolean = false;
  @State keypadProgress: number = 0;
  private keypadTimer: number = -1;
  @State budgetOpen: boolean = false;
  @State budgetProgress: number = 0;
  @State budgetMonth: string = '';
  private pageScroller: Scroller = new Scroller();
  private budgetTimer: number = -1;
  aboutToAppear(): void { this.reload(); }
  aboutToDisappear(): void { this.stopKeypadMotion(); this.stopBudgetMotion(); }
  private stopBudgetMotion(): void {
    if (this.budgetTimer !== -1) { clearInterval(this.budgetTimer); this.budgetTimer = -1; }
  }
  private showBudget(open: boolean): void {
    if (this.app.saving || open && (this.selected !== 1 || this.app.status !== 'ready' ||
      this.budgetOpen || this.budgetProgress > 0 || this.keypadOpen || this.keypadProgress > 0)) { return; }
    if (open) { this.budgetMonth = dateKey(); }
    this.stopBudgetMotion();
    this.budgetOpen = open;
    const start = this.budgetProgress;
    const target = open ? 1 : 0;
    const startedAt = Date.now();
    this.budgetTimer = setInterval(() => {
      const t = Math.min(1, (Date.now() - startedAt) / 420);
      const eased = t * t * (3 - 2 * t);
      this.budgetProgress = start + (target - start) * eased;
      if (t === 1) { this.stopBudgetMotion(); }
    }, 16);
  }
  @Builder
  budgetEditor() {
    MonthlyBudgetSheet({ state: this.app, monthDate: this.budgetMonth, onClose: () => this.showBudget(false) })
  }
  private stopKeypadMotion(): void {
    if (this.keypadTimer !== -1) { clearInterval(this.keypadTimer); this.keypadTimer = -1; }
  }
  private showKeypad(open: boolean): void {
    this.stopKeypadMotion();
    this.keypadOpen = open;
    const start = this.keypadProgress;
    const target = open ? 1 : 0;
    const startedAt = Date.now();
    this.keypadTimer = setInterval(() => {
      const t = Math.min(1, (Date.now() - startedAt) / 420);
      const eased = t * t * (3 - 2 * t);
      this.keypadProgress = start + (target - start) * eased;
      if (t === 1) { this.stopKeypadMotion(); }
    }, 16);
  }
  private reload(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.app.load(context);
  }
  private changeTab(index: number): void {
    if (this.keypadOpen || this.keypadProgress > 0 || this.budgetOpen || this.budgetProgress > 0) { return; }
    if (index === this.selected) { return; }
    if (this.selected === 2 && this.dirty) {
      this.getUIContext().showAlertDialog({
        title: '放弃未保存的输入？', message: '切换页面不会保存账单，放弃后将清空当前输入。',
        primaryButton: { value: '继续编辑', fontColor: '#777777', action: () => {} },
        secondaryButton: { value: '放弃编辑', fontColor: '#777777', action: () => {
          this.amount = ''; this.note = ''; this.dirty = false; this.selected = index;
        } }
      });
      return;
    }
    if (index === 1) {
      this.detailsFilter = defaultFilter();
      this.detailsFilter.range = calendarMonth(dateKey());
    }
    this.selected = index;
  }
  private openAccounts(): void {
    this.accountReturnTab = this.selected;
    this.profileSection = '';
    this.selected = 3;
    this.depositDetail = true;
  }
  private closeAccounts(): void {
    this.depositDetail = false;
    this.selected = this.accountReturnTab;
    this.accountReturnTab = 3;
  }
  onBackPress(): boolean {
    if (this.budgetOpen || this.budgetProgress > 0) { this.showBudget(false); return true; }
    if (this.keypadOpen || this.keypadProgress > 0) { this.showKeypad(false); return true; }
    if (this.selected === 3 && this.depositDetail) {
      if (!this.app.saving) { this.closeAccounts(); }
      return true;
    }
    if (!this.dirty) { return false; }
    this.getUIContext().showAlertDialog({
      title: '尚有未保存的输入', message: '继续编辑，或放弃编辑后再次返回退出。',
      primaryButton: { value: '继续编辑', fontColor: '#777777', action: () => {} },
      secondaryButton: { value: '放弃编辑', fontColor: '#777777',
        action: () => { this.amount = ''; this.note = ''; this.dirty = false; } }
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
        Button('重试').backgroundColor(FinanceTheme.text).onClick(() => this.reload())
      } else if (this.app.status === 'repair' && this.app.draft !== null) {
        Text('迁移前请补录初始余额').fontSize(20).fontWeight(FontWeight.Bold)
        Text('历史净支出使普通账户低于0，不能直接启用。原文件未修改；不推算或伪造余额。').fontSize(14)
        ForEach(this.app.draft.requiredAccountIds, (id: string, index: number) => {
          Text(this.app.draft!.data.accounts.find((account) => account.id === id)!.name)
          TextInput({ placeholder: '真实初始余额', text: this.repairAmounts[index] || '' })
            .onChange((value: string) => { this.repairAmounts[index] = value; })
        }, (id: string) => id)
        Button('验证并迁移').backgroundColor(FinanceTheme.text).onClick(() => this.repair())
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
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.selected === 3) {
        Column() {
          if (!this.depositDetail && (this.app.status !== 'ready' || this.app.message.length > 0 ||
            this.app.data.accounts.some((account) => account.needsInitialBalance))) { this.statusCard() }
          DepositsPage({ state: this.app, detail: $depositDetail, onBackDetail: () => this.closeAccounts(),
            onDetails: (filter: LedgerFilter) => {
              this.depositDetail = false; this.accountReturnTab = 3; this.detailsFilter = filter; this.selected = 1;
            }, onManage: () => this.openAccounts() })
            .layoutWeight(1)
        }.width('100%').height('100%').padding({ bottom: this.depositDetail ? 0 : DEPOSIT_NAV_CLEARANCE })
      }
      Scroll(this.pageScroller) {
        Column({ space: 16 }) {
          if (!this.depositDetail && (this.app.status !== 'ready' || this.app.message.length > 0 ||
            this.app.data.accounts.some((account) => account.needsInitialBalance))) { this.statusCard() }
          if (this.selected === 0) { StatisticsPage({ state: this.app, refreshVersion: this.app.refreshVersion,
            onDetails: (filter: LedgerFilter) => { this.detailsFilter = filter; this.selected = 1; } }) }
          else if (this.selected === 1) { DetailsPage({ state: this.app, initialFilter: this.detailsFilter,
            refreshVersion: this.app.refreshVersion, onBudgets: () => this.showBudget(true),
            onOpenEditor: () => { this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0 }); } }) }
          else if (this.selected === 4) { ProfilePage({ state: this.app, section: $profileSection,
            onAccounts: () => this.openAccounts() }) }
          RecordPage({ state: this.app, amount: $amount, note: $note,
            onAmount: () => this.showKeypad(true),
            onSaved: () => { this.showKeypad(false); this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0 }); },
            onDirty: () => { this.dirty = this.amount.length > 0 || this.note.length > 0; },
            onManageAccounts: () => this.openAccounts(),
            onManageCategories: () => { this.profileSection = 'categories'; this.selected = 4; } })
            .visibility(this.selected === 2 ? Visibility.Visible : Visibility.None)
        }.padding({ left: this.depositDetail || this.selected === 3 ? 0 : 20,
          right: this.depositDetail || this.selected === 3 ? 0 : 20,
          top: this.depositDetail || this.selected === 3 ? 0 : 20, bottom: this.depositDetail ? 0 : 132 })
          .constraintSize({ minHeight: this.depositDetail ? '100%' : 0 }).width('100%')
      }.height('100%').width('100%').align(Alignment.Top)
        .visibility(this.selected === 3 ? Visibility.None : Visibility.Visible)
        .enabled(!this.budgetOpen && this.budgetProgress === 0)
        .accessibilityLevel(this.budgetOpen || this.budgetProgress > 0 ? 'no-hide-descendants' : 'auto')
      if (this.budgetOpen || this.budgetProgress > 0) {
        Column() {}.width('100%').height('100%').backgroundColor('#000000').opacity(0.24 * this.budgetProgress)
          .id('details-budget-backdrop').accessibilityText('关闭预算设置')
          .onClick(() => {
            if (!this.app.saving) { this.getUIContext().getFocusController().clearFocus(); this.showBudget(false); }
          })
      }
      if (this.keypadProgress > 0 || this.keypadOpen) {
        Column() {}.width('100%').height('100%')
          .backgroundColor('#000000').opacity(0.16 * this.keypadProgress)
          .onClick(() => this.showKeypad(false))
          .accessibilityText('关闭金额键盘')
      }
      if (!this.depositDetail) {
        FloatingNavBar({ selected: this.selected, onSelect: (index: number) => this.changeTab(index),
          keypadProgress: this.keypadProgress, keypadOpen: this.keypadOpen, amount: this.amount,
          sheetOpen: this.budgetOpen, sheetProgress: this.budgetProgress, sheetHeight: 480,
          sheetContent: () => { this.budgetEditor() },
          onClose: () => this.showKeypad(false),
          onKey: (key: string) => {
            this.amount = keypadAmount(this.amount, key);
            this.dirty = this.amount.length > 0 || this.note.length > 0;
          } })
          .margin({ left: 16, right: 16, top: 8, bottom: 16 })
      }
    }.width('100%').height('100%').backgroundColor(this.depositDetail ? '#171717' :
      this.selected === 1 ? DetailsPalette.background : FinanceTheme.background)
      .expandSafeArea(this.depositDetail ? [SafeAreaType.SYSTEM] : [], this.depositDetail ? [SafeAreaEdge.BOTTOM] : [])
  }
}
