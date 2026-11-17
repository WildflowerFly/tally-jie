import { AppState } from '../state/AppState';
import { Account, LedgerFilter, LedgerEntry } from '../model/LedgerModels';
import { accountBalance } from '../domain/LedgerRules';
import { addCents } from '../domain/Money';
import { defaultFilter, queryEntries } from '../service/LedgerQueryService';
import { money } from '../model/AppData';
import { FinanceTheme } from '../theme/FinanceTheme';
import { TransferPage } from './TransferPage';
@Component
export struct DepositsPage {
  @ObjectLink state: AppState;
  onDetails: (filter: LedgerFilter) => void = () => {};
  onManage: () => void = () => {};
  @State index: number = 0;
  @State showTransfers: boolean = false;
  private current(): Account | undefined { return this.state.data.accounts[Math.min(this.index, this.state.data.accounts.length - 1)]; }
  private total(): number {
    return this.state.data.accounts.reduce((sum: number, row: Account) => addCents(sum, accountBalance(this.state.data, row.id)), 0);
  }
  private filter(): LedgerFilter { const filter = defaultFilter(); filter.accountIds = this.current() === undefined ? [] : [this.current()!.id]; return filter; }
  private recent(): LedgerEntry[] { const filter = this.filter(); filter.pageSize = 5; return queryEntries(this.state.data, filter).rows; }
  private transferTotal(incoming: boolean): number {
    const id = this.current()?.id;
    return this.state.data.transfers.filter((row) => incoming ? row.toAccountId === id : row.fromAccountId === id)
      .reduce((sum: number, row) => addCents(sum, row.amountCents), 0);
  }
  build() {
    Column({ space: 16 }) {
      if (this.showTransfers) {
        TransferPage({ state: this.state, accountId: this.current()?.id || '', onBack: () => { this.showTransfers = false; } })
      } else {
      Text('存款').fontSize(28).fontWeight(FontWeight.Bold).width('100%')
      Text(`总余额 ¥${money(this.total())}`).fontSize(26)
      Text(`${this.state.data.accounts.length}个账户 · 含信用卡负余额`).fontColor(FinanceTheme.muted)
      Button('管理账户').onClick(() => this.onManage())
      if (this.state.data.accounts.length === 0) { Text('暂无账户，请先创建账户') }
      else {
        Swiper() {
          ForEach(this.state.data.accounts, (row: Account) => {
            Column({ space: 16 }) {
              Text(row.name).fontSize(24).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor('#FFFFFF')
              Text(`¥ ${money(accountBalance(this.state.data, row.id))}`).fontSize(32).fontColor('#FFFFFF')
              Text(row.type === 'credit' ? '信用卡账户' : '普通账户').fontColor('#DDDDDD')
            }.padding(28).width('100%').height(205).borderRadius(28)
              .linearGradient({ angle: 135, colors: [['#303030', 0], ['#111111', 1]] })
          }, (row: Account) => row.id)
        }.index(this.index).loop(false).itemSpace(12).prevMargin(12).nextMargin(12)
          .height(235).onChange((index: number) => { this.index = index; })
        Text(`${this.current()?.name || ''} · 账户详情`).fontSize(20)
        Text(`初始 ¥${money(this.current()?.initialBalanceCents || 0)} · 当前 ¥${money(this.current() === undefined ? 0 : accountBalance(this.state.data, this.current()!.id))}`)
        Text(`累计收入 ¥${money(queryEntries(this.state.data, this.filter()).incomeCents)} · 累计支出 ¥${money(queryEntries(this.state.data, this.filter()).expenseCents)}`)
        Text(`累计转入 ¥${money(this.transferTotal(true))} · 累计转出 ¥${money(this.transferTotal(false))}`)
        if (this.current()?.needsInitialBalance) { Text('初始余额暂为0，请补录真实值').fontColor(FinanceTheme.expense) }
        Text('最近收支').fontSize(18)
        ForEach(this.recent(), (row: LedgerEntry) => {
          Text(`${row.date} ${row.time} · ${this.state.data.categories.find((item) => item.id === row.categoryId)?.name || ''} · ${row.type === 'income' ? '+' : '-'}¥${money(row.amountCents)}`)
        }, (row: LedgerEntry) => row.id)
        Button('转账 / 转账记录').onClick(() => { this.showTransfers = true; })
        Button('查看全部账单').onClick(() => this.onDetails(this.filter()))
      }
      }
    }.width('100%').id('finance-page-deposits')
  }
}
