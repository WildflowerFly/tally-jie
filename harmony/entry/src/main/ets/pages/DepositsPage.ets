import { window } from '@kit.ArkUI';
import { AppState } from '../state/AppState';
import { Account, LedgerFilter, LedgerEntry } from '../model/LedgerModels';
import { accountBalance } from '../domain/LedgerRules';
import { defaultFilter } from '../service/LedgerQueryService';
import { money } from '../model/AppData';
import { FinanceTheme } from '../theme/FinanceTheme';
import { categoryImage } from '../components/CategoryIcon';
import { AccountCardStack } from '../components/AccountCardStack';
import { AccountCardModel } from '../components/AccountCardFace';
import { accountEnglishName, accountIconKey } from '../domain/AccountAppearance';
import { ACCOUNT_CARD_FONT, registerAccountCardFont } from '../theme/AccountCardTheme';
import { AccountEditorSheet } from '../components/AccountEditorSheet';
import { accountReferences, removeAccount } from '../service/AccountService';
import { depositHeroHeight, DEPOSIT_RECENT_TOP, DEPOSIT_LINK_GOLD } from '../domain/DepositLayout';

@Component
export struct DepositsPage {
  @ObjectLink state: AppState;
  @Link @Watch('detailChanged') detail: boolean;
  onDetails: (filter: LedgerFilter) => void = () => {};
  onManage: () => void = () => {};
  onBackDetail: () => void = () => { this.detail = false; };
  @State selectedId: string = '';
  @State recentRows: LedgerEntry[] = [];
  @State error: string = '';
  @State showEditor: boolean = false;
  @State editingAccountId: string = '';
  @State detailError: string = '';
  @State pageHeight: number = 600;
  private request: number = 0;
  private barsRequest: number = 0;
  private originalBars: window.SystemBarProperties | undefined;
  aboutToAppear(): void {
    registerAccountCardFont(this.getUIContext()); this.loadRecent(); this.updateSystemBars(this.detail);
  }
  aboutToDisappear(): void { this.request++; this.updateSystemBars(false); }
  private detailChanged(): void { this.updateSystemBars(this.detail); }
  private async updateSystemBars(dark: boolean): Promise<void> {
    const ticket = ++this.barsRequest;
    const context = this.getUIContext().getHostContext();
    if (context === undefined || !dark && this.originalBars === undefined) { return; }
    try {
      const main = await window.getLastWindow(context);
      if (ticket !== this.barsRequest) { return; }
      if (dark) {
        if (this.originalBars === undefined) { this.originalBars = main.getWindowSystemBarProperties(); }
        await main.setWindowSystemBarProperties({ statusBarColor: '#272727', statusBarContentColor: '#FFFFFF',
          navigationBarColor: '#171717', navigationBarContentColor: '#FFFFFF' });
      } else if (this.originalBars !== undefined) {
        await main.setWindowSystemBarProperties(this.originalBars);
      }
    } catch (_) { console.warn('Unable to update account detail system bar colors'); }
  }
  private current(): Account | undefined {
    return this.state.data.accounts.find((row) => row.id === this.selectedId) || this.state.data.accounts[0];
  }
  private activeIndex(): number {
    return Math.max(0, this.state.data.accounts.findIndex((row) => row.id === this.current()?.id));
  }
  private cards(): AccountCardModel[] {
    return this.state.data.accounts.map((row: Account): AccountCardModel => {
      return { id: row.id, name: row.name, englishName: accountEnglishName(row), iconKey: accountIconKey(row),
        balanceCents: accountBalance(this.state.data, row.id) };
    });
  }
  private filter(): LedgerFilter {
    const filter = defaultFilter();
    filter.accountIds = this.current() === undefined ? [] : [this.current()!.id];
    return filter;
  }
  private async loadRecent(): Promise<void> {
    const ticket = ++this.request;
    if (this.current() === undefined) { this.recentRows = []; this.error = ''; return; }
    try {
      const filter = this.filter(); filter.pageSize = 5;
      const result = await this.state.queryEntries(filter);
      if (ticket !== this.request) { return; }
      this.recentRows = result.page.rows; this.error = '';
    } catch (error) { if (ticket === this.request) { this.error = (error as Error).message; } }
  }
  private select(index: number): void {
    this.selectedId = this.state.data.accounts[index]?.id || ''; this.detailError = ''; this.loadRecent();
  }
  private editAccount(id: string = ''): void {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    this.editingAccountId = id; this.detailError = ''; this.showEditor = true;
  }
  private confirmDelete(targetId: string = ''): void {
    const row = this.current();
    if (row === undefined || this.state.saving || this.state.status !== 'ready') { return; }
    const refs = accountReferences(this.state.data, row.id);
    const target = this.state.data.accounts.find((account) => account.id === targetId && account.id !== row.id);
    if ((refs.entries > 0 || refs.transfers > 0) && target === undefined) {
      this.getUIContext().showAlertDialog({
        title: '账户仍有关联记录',
        message: `「${row.name}」关联${refs.entries}笔账单、${refs.transfers}笔历史转账。请在编辑面板选择迁移账户；历史转账数据仅保留用于余额核算。`,
        confirm: { value: '知道了', fontColor: '#333333', action: () => {} }
      });
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '删除账户？',
      message: `将删除「${row.name}」及其初始余额 ¥${money(row.initialBalanceCents)}。` +
        (target === undefined ? '此操作不可撤销。' : `历史记录迁移至「${target.name}」，初始余额不转移；迁移不能合并历史转账的双方账户。`),
      primaryButton: { value: '取消', fontColor: '#666666', action: () => {} },
      secondaryButton: { value: '删除', fontColor: '#333333', action: () => { this.deleteAccount(row.id, target?.id || ''); } }
    });
  }
  private async deleteAccount(id: string, targetId: string = ''): Promise<void> {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    const index = this.state.data.accounts.findIndex((row) => row.id === id);
    this.detailError = '';
    try {
      const next = removeAccount(this.state.data, id, targetId || null);
      if (await this.state.commit(next)) {
        this.showEditor = false;
        this.select(Math.min(index, this.state.data.accounts.length - 1));
      } else { this.detailError = this.state.message || '删除失败，请稍后重试。'; }
    } catch (error) {
      this.detailError = (error as Error).message === 'REFERENCE_IN_USE' ?
        '账户仍有关联记录，请先处理后再删除。' : (error as Error).message;
    }
  }
  @Builder
  accountEditor() {
    AccountEditorSheet({ state: this.state, accountId: this.editingAccountId,
      onCancel: () => { this.showEditor = false; }, onDelete: (targetId: string) => this.confirmDelete(targetId),
      deleteError: this.detailError,
      onSaved: (id: string) => {
        this.selectedId = id; this.showEditor = false; this.detailError = ''; this.loadRecent();
      } })
  }
  @Builder
  quickAction(icon: Resource, label: string, action: () => void) {
    Column({ space: 5 }) {
      Button() {
        Image(icon).width(20).height(20)
      }.width(36).height(36).padding(0).backgroundColor('#FFFFFF')
        .shadow({ radius: 12, color: '#07000000', offsetY: 5 }).onClick(action).accessibilityText(label)
      Text(label).fontSize(10).fontColor('#333333')
    }.width(56)
  }
  @Builder
  recentTransactions() {
    Column({ space: 12 }) {
      Row() {
        Text('最近交易').fontSize(17).fontWeight(FontWeight.Medium).fontColor(FinanceTheme.text)
        Blank()
        Text('查看全部').fontSize(12).fontColor(DEPOSIT_LINK_GOLD)
          .decoration({ type: TextDecorationType.Underline, color: DEPOSIT_LINK_GOLD })
          .padding({ top: 8, bottom: 8 }).onClick(() => this.onDetails(this.filter()))
      }.width('100%')
      if (this.error) { Text(this.error).fontSize(13).fontColor(FinanceTheme.expense) }
      if (!this.recentRows.length) {
        Column() {
          Text('暂无收支记录').fontSize(14).fontColor(FinanceTheme.muted)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.recentRows, (row: LedgerEntry) => {
              Row({ space: 12 }) {
                Row() {
                  Image(categoryImage(this.state.data.categories.find((item) => item.id === row.categoryId)?.name || '',
                    this.state.data.categories.find((item) => item.id === row.categoryId)?.iconKey || 'category'))
                    .width(22).height(22).supportSvg2(true).accessibilityLevel('no')
                    .id(`deposit-recent-icon-${row.id}`)
                }.width(42).height(42).justifyContent(FlexAlign.Center).backgroundColor('#F6F6F6').borderRadius(13)
                Column({ space: 5 }) {
                  Text(this.state.data.categories.find((item) => item.id === row.categoryId)?.name || '未分类')
                    .fontSize(15).fontColor(FinanceTheme.text).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(row.note || this.current()?.name || '').fontSize(11).fontColor('#AEAEAE')
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Column({ space: 5 }) {
                  Text(`${row.type === 'income' ? '+' : '-'} ¥${money(row.amountCents)}`)
                    .fontSize(15).fontWeight(FontWeight.Medium).fontColor(FinanceTheme.text)
                  Text(row.date.slice(5).replace('-', '/')).fontSize(11).fontColor('#AEAEAE')
                }.alignItems(HorizontalAlign.End)
              }.width('100%').onClick(() => {
                const filter = this.filter(); filter.range = { startDate: row.date, endDate: row.date }; this.onDetails(filter);
              })
            }, (row: LedgerEntry) => row.id)
          }.width('100%')
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
      }
    }.padding(16).width('100%').height('100%').borderRadius(24).backgroundColor('#FFFFFF')
      .id('deposit-recent-panel')
  }
  @Builder
  accountDetail() {
    Column() {
      Row() {
        Button('←  返回').height(40).fontSize(16).fontColor('#FFFFFF').backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 16 }).enabled(!this.state.saving)
          .onClick(() => this.onBackDetail()).id('deposit-detail-back')
        Blank()
        Button('＋').width(40).height(40).padding(0).fontSize(26)
          .fontColor('#FFFFFF').backgroundColor(Color.Transparent).accessibilityText('新增账户')
          .enabled(this.state.status === 'ready' && !this.state.saving)
          .onClick(() => this.editAccount()).id('deposit-detail-add')
      }.width('100%').padding({ left: 16, right: 12, top: 6 })
      if (this.current() !== undefined) {
        AccountCardStack({ cards: this.cards(), activeIndex: this.activeIndex(), dark: true, fillHeight: true,
          onSelect: (index: number) => this.select(index),
          onOpen: () => this.editAccount(this.current()!.id) }).layoutWeight(1)
        Column({ space: 14 }) {
          Column({ space: 5 }) {
            Text('账户名称').fontSize(11).fontColor('#939393')
            Text(this.current()!.name).fontSize(16)
              .fontColor('#FFFFFF').fontWeight(FontWeight.Medium).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).id('deposit-account-name-display')
          }.width('100%').alignItems(HorizontalAlign.Start)
          Column({ space: 5 }) {
            Text('账户持有者').fontSize(11).fontColor('#939393')
            Text(this.current()!.holder || '未填写').fontSize(14).fontFamily(ACCOUNT_CARD_FONT)
              .fontColor('#FFFFFF').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .id('deposit-account-holder-display')
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 24, right: 24, top: 4, bottom: 16 })
          .id('deposit-detail-info')
      } else {
        Column({ space: 18 }) {
          Text('还没有账户').fontSize(21).fontColor('#FFFFFF')
          Text('添加账户，从真实初始余额开始记录').fontSize(13).fontColor('#999999')
          Button('新增账户').height(42).fontColor('#171717').backgroundColor('#F2F2F2')
            .enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.editAccount())
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }
      if (this.detailError) {
        Text(this.detailError).fontSize(12).fontColor('#E6E6E6').maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 24, right: 24, bottom: 12 })
      }
    }.width('100%').height('100%').clip(true).id('deposit-account-detail')
      .linearGradient({ angle: 90, colors: [['#343434', 0], ['#181818', 0.55], ['#080808', 1]] })
  }
  build() {
    Column() {
      if (this.detail) {
        this.accountDetail()
      } else if (this.state.data.accounts.length === 0) {
        Column({ space: 20 }) {
          Text('还没有账户，从真实初始余额开始').fontColor(FinanceTheme.muted)
          Button('创建账户').backgroundColor('#252525').onClick(() => this.onManage())
        }.padding(32).width('100%')
      } else {
        Row() {
          Column({ space: 16 }) {
            this.quickAction($r('app.media.deposit_receive'), '收支明细', () => this.onDetails(this.filter()))
            this.quickAction($r('app.media.deposit_bill'), '账户管理', () => this.onManage())
          }.width(60).translate({ y: 20 })
          Column() {
            AccountCardStack({ cards: this.cards(), activeIndex: this.activeIndex(), fillHeight: true,
              onSelect: (index: number) => this.select(index),
              onOpen: () => { this.detail = true; } })
          }.layoutWeight(1).height('100%').justifyContent(FlexAlign.Center).clip(true)
        }.width('100%').height(depositHeroHeight(this.pageHeight)).alignItems(VerticalAlign.Center)
          .padding({ left: 16 }).clip(true).id('deposit-card-half')
        Column() {
          this.recentTransactions()
        }.width('100%').layoutWeight(1).padding({ left: 12, right: 12, top: DEPOSIT_RECENT_TOP, bottom: 0 })
          .id('deposit-recent-half')
      }
    }.width('100%').height('100%').id('finance-page-deposits')
      .onAreaChange((_old: Area, area: Area) => {
        const height = Number(area.height);
        if (height > 0 && height !== this.pageHeight) { this.pageHeight = height; }
      })
      .bindSheet($$this.showEditor, this.accountEditor(), {
        height: SheetSize.LARGE, backgroundColor: '#242424', showClose: false,
        keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY,
        shouldDismiss: (sheet: SheetDismiss) => { if (!this.state.saving) { sheet.dismiss(); } }
      })
  }
}
