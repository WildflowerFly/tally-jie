import { AppState } from '../state/AppState';
import { Account, LedgerFilter, LedgerEntry } from '../model/LedgerModels';
import { accountBalance } from '../domain/LedgerRules';
import { addCents } from '../domain/Money';
import { defaultFilter } from '../service/LedgerQueryService';
import { money } from '../model/AppData';
import { FinanceTheme } from '../theme/FinanceTheme';
import { TransferPage } from './TransferPage';
import { AccountCardStack, AccountCardModel } from '../components/AccountCardStack';
@Component
export struct DepositsPage {
  @ObjectLink state: AppState;
  onDetails: (filter: LedgerFilter) => void = () => {};
  onManage: () => void = () => {};
  @State selectedId: string = '';
  @State showTransfers: boolean = false;
  @State detail: boolean = false;
  @State recentRows: LedgerEntry[] = [];
  @State income: number = 0;
  @State expense: number = 0;
  @State error: string = '';
  private request: number = 0;
  aboutToAppear(): void { this.loadRecent(); }
  private current(): Account | undefined { return this.state.data.accounts.find((row) => row.id === this.selectedId) || this.state.data.accounts[0]; }
  private activeIndex(): number { return Math.max(0, this.state.data.accounts.findIndex((row) => row.id === this.current()?.id)); }
  private cards(): AccountCardModel[] {
    return this.state.data.accounts.map((row: Account): AccountCardModel => {
      return { id: row.id, name: row.name, credit: row.type === 'credit', balanceCents: accountBalance(this.state.data, row.id) };
    });
  }
  private total(): number { return this.cards().reduce((sum: number, row: AccountCardModel) => addCents(sum, row.balanceCents), 0); }
  private filter(): LedgerFilter { const filter = defaultFilter(); filter.accountIds = this.current() === undefined ? [] : [this.current()!.id]; return filter; }
  private async loadRecent(): Promise<void> {
    const ticket = ++this.request;
    if (this.current() === undefined) { this.recentRows = []; return; }
    try {
      const filter = this.filter(); filter.pageSize = 5;
      const result = await this.state.queryEntries(filter);
      if (ticket !== this.request) { return; }
      this.recentRows = result.page.rows; this.income = result.page.incomeCents; this.expense = result.page.expenseCents; this.error = '';
    } catch (error) { if (ticket === this.request) { this.error = (error as Error).message; } }
  }
  private select(index: number): void {
    this.selectedId = this.state.data.accounts[index]?.id || ''; this.loadRecent();
  }
  private transferTotal(incoming: boolean): number {
    const id = this.current()?.id;
    return this.state.data.transfers.filter((row) => incoming ? row.toAccountId === id : row.fromAccountId === id)
      .reduce((sum: number, row) => addCents(sum, row.amountCents), 0);
  }
  build() {
    Column({ space: 16 }) {
      if (this.showTransfers) {
        TransferPage({ state: this.state, accountId: this.current()?.id || '', onBack: () => { this.showTransfers = false; this.loadRecent(); } })
      } else {
        Row() {
          Column({ space: 4 }) {
            Text(this.detail ? '账户详情' : '我的资产').fontSize(27).fontWeight(FontWeight.Bold)
              .fontColor(this.detail ? '#FFFFFF' : FinanceTheme.text)
            Text(this.detail ? this.current()?.name || '' : '本地账本 · 安心记录每一笔').fontSize(13)
              .fontColor(this.detail ? '#BDBDBD' : FinanceTheme.muted)
          }.alignItems(HorizontalAlign.Start)
          Blank()
          Button(this.detail ? '返回' : '管理').backgroundColor(this.detail ? '#353535' : '#FFFFFF')
            .fontColor(this.detail ? '#FFFFFF' : '#171717').onClick(() => { if (this.detail) { this.detail = false; } else { this.onManage(); } })
        }.width('100%')
        if (!this.detail) {
          Column({ space: 6 }) {
            Text('总资产余额').fontSize(13).fontColor(FinanceTheme.muted)
            Text(`¥${money(this.total())}`).fontSize(34).fontWeight(FontWeight.Bold)
            Text(`${this.state.data.accounts.length} 个账户 · 信用卡欠款计入净额`).fontSize(12).fontColor(FinanceTheme.muted)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }
        if (this.state.data.accounts.length === 0) {
          Text('还没有账户，从真实初始余额开始').fontColor(FinanceTheme.muted)
          Button('创建账户').onClick(() => this.onManage())
        } else {
          AccountCardStack({ cards: this.cards(), activeIndex: this.activeIndex(), dark: this.detail,
            onSelect: (index: number) => this.select(index), onOpen: () => { this.detail = true; } })
          Row({ space: 12 }) {
            Button('⇄ 转账').layoutWeight(1).backgroundColor(this.detail ? '#353535' : '#FFFFFF')
              .fontColor(this.detail ? '#FFFFFF' : '#171717').onClick(() => { this.showTransfers = true; })
            Button('☷ 明细').layoutWeight(1).backgroundColor(this.detail ? '#353535' : '#FFFFFF')
              .fontColor(this.detail ? '#FFFFFF' : '#171717').onClick(() => this.onDetails(this.filter()))
            Button('✎ 管理').layoutWeight(1).backgroundColor(this.detail ? '#353535' : '#FFFFFF')
              .fontColor(this.detail ? '#FFFFFF' : '#171717').onClick(() => this.onManage())
          }.width('100%')
          if (this.detail) {
            Column({ space: 10 }) {
              Text(`初始余额  ¥${money(this.current()?.initialBalanceCents || 0)}`).fontColor('#FFFFFF')
              Text(`累计收入  ¥${money(this.income)}    支出  ¥${money(this.expense)}`).fontColor('#FFFFFF')
              Text(`转入  ¥${money(this.transferTotal(true))}    转出  ¥${money(this.transferTotal(false))}`).fontColor('#FFFFFF')
              Text(this.current()?.type === 'credit' ? '信用卡账户 · 允许负余额，还款请使用转账' : '普通账户 · 不允许负余额').fontSize(12).fontColor('#CCCCCC')
            }.alignItems(HorizontalAlign.Start).width('100%')
          }
          if (this.current()?.needsInitialBalance) { Text('初始余额暂为0，请补录真实值').fontColor(FinanceTheme.expense) }
          Column({ space: 16 }) {
            Row() {
              Text('最近交易').fontSize(18).fontWeight(FontWeight.Medium)
              Blank()
              Button('查看全部').fontSize(12).backgroundColor('#F3F3F3').fontColor('#171717').onClick(() => this.onDetails(this.filter()))
            }.width('100%')
            if (this.error) { Text(this.error).fontColor(FinanceTheme.expense) }
            if (!this.recentRows.length) { Text('暂无收支记录').fontColor(FinanceTheme.muted).padding(20) }
            ForEach(this.recentRows, (row: LedgerEntry) => {
              Row({ space: 12 }) {
                Text(row.type === 'income' ? '↙' : '↗').fontSize(20).width(38).height(38).textAlign(TextAlign.Center)
                  .backgroundColor('#F5F5F5').borderRadius(12)
                Column({ space: 4 }) {
                  Text(this.state.data.categories.find((item) => item.id === row.categoryId)?.name || '').fontSize(15)
                  Text(row.note || row.date).fontSize(12).fontColor(FinanceTheme.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Column({ space: 4 }) {
                  Text(`${row.type === 'income' ? '+' : '-'}¥${money(row.amountCents)}`).fontSize(15).fontWeight(FontWeight.Medium)
                    .fontColor(row.type === 'income' ? FinanceTheme.income : FinanceTheme.text)
                  Text(`${row.date.slice(5)} ${row.time}`).fontSize(11).fontColor(FinanceTheme.muted)
                }.alignItems(HorizontalAlign.End)
              }.width('100%').onClick(() => { const filter = this.filter(); filter.range = { startDate: row.date, endDate: row.date }; this.onDetails(filter); })
            }, (row: LedgerEntry) => row.id)
          }.padding(18).width('100%').borderRadius(24).backgroundColor('#FFFFFF')
        }
      }
    }.padding(this.detail ? 16 : 0).width('100%').borderRadius(28)
      .backgroundColor(this.detail ? '#171717' : FinanceTheme.background).id('finance-page-deposits')
  }
}
