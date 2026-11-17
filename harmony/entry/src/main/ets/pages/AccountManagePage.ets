import { FinanceHeader } from '../components/FinanceHeader';
import { AppState } from '../state/AppState';
import { Account, AccountType } from '../model/LedgerModels';
import { accountBalance } from '../domain/LedgerRules';
import { upsertAccount, removeAccount, accountReferences } from '../service/AccountService';
import { money, newId } from '../model/AppData';
import { FinanceTheme } from '../theme/FinanceTheme';

@Component
export struct AccountManagePage {
  @ObjectLink state: AppState;
  @State editingId: string = '';
  @State name: string = '';
  @State initial: string = '';
  @State credit: boolean = false;
  @State targetId: string = '';
  @State error: string = '';
  onBack: () => void = () => {};
  private targets(): SelectOption[] {
    const options: SelectOption[] = [{ value: '不迁移，关联时拒删' }];
    this.state.data.accounts.forEach((row: Account) => { options.push({ value: row.name }); });
    return options;
  }
  private edit(row: Account): void {
    this.editingId = row.id; this.name = row.name;
    this.initial = money(row.initialBalanceCents); this.credit = row.type === 'credit'; this.error = '';
  }
  private async save(): Promise<void> {
    if (this.state.saving) { return; }
    try {
      const type: AccountType = this.credit ? 'credit' : 'standard';
      const next = upsertAccount(this.state.data, this.editingId || newId(), this.name, type, this.initial, new Date().toISOString());
      if (await this.state.commit(next)) { this.clear(); }
    } catch (error) { this.error = (error as Error).message; }
  }
  private clear(): void { this.editingId = ''; this.name = ''; this.initial = ''; this.credit = false; this.error = ''; }
  private confirmDelete(row: Account): void {
    const refs = accountReferences(this.state.data, row.id);
    const target = this.state.data.accounts.find((item) => item.id === this.targetId);
    this.getUIContext().showAlertDialog({
      title: '确认删除账户？',
      message: `「${row.name}」关联${refs.entries}笔账单、${refs.transfers}笔转账。` +
        (target === undefined ? '有关联将拒绝删除。' : `历史将迁移至「${target.name}」，源初始余额不会转移；直接连接双方的转账须先处理。`),
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确认', action: () => { this.erase(row.id); } }
    });
  }
  private async erase(id: string): Promise<void> {
    try {
      const next = removeAccount(this.state.data, id, this.targetId || null);
      if (await this.state.commit(next)) { if (this.editingId === id) { this.clear(); } this.error = ''; }
    } catch (error) { this.error = (error as Error).message; }
  }
  build() {
    Column({ space: 14 }) {
      FinanceHeader({ title: '账户管理', subtitle: 'ACCOUNTS · 资产的起点', back: true, onBack: () => this.onBack() })
      Text('余额 = 初始余额 + 收入 - 支出 + 转入 - 转出；仅信用卡允许负数。').fontSize(13)
      ForEach(this.state.data.accounts, (row: Account) => {
        Column({ space: 8 }) {
          Text(`${row.name} · ${row.type === 'credit' ? '信用卡' : '普通账户'}`).fontWeight(FontWeight.Bold)
          Text(`¥ ${money(accountBalance(this.state.data, row.id))}`).fontSize(28).fontWeight(FontWeight.Bold).fontColor(FinanceTheme.text)
          Text(`初始余额 ¥${money(row.initialBalanceCents)}`).fontSize(12).fontColor(FinanceTheme.muted)
          if (row.needsInitialBalance) { Text('历史初始余额暂为0，请补录').fontColor(FinanceTheme.expense) }
          Row({ space: 12 }) {
            Button('编辑 / 补录').backgroundColor(FinanceTheme.text).onClick(() => this.edit(row))
            Button('删除').backgroundColor('#F8EDEA').fontColor(FinanceTheme.expense).enabled(!this.state.saving && this.state.status === 'ready').onClick(() => this.confirmDelete(row))
          }
        }.padding(16).width('100%').backgroundColor('#FFFFFF').borderRadius(20)
      }, (row: Account) => row.id)
      Column({ space: 14 }) {
      Text(this.editingId ? '编辑账户' : '新建账户').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
      TextInput({ placeholder: '名称（最多40字）', text: this.name }).maxLength(40).onChange((value: string) => { this.name = value; })
      TextInput({ placeholder: '初始余额，留空为0', text: this.initial }).onChange((value: string) => { this.initial = value; })
      Toggle({ type: ToggleType.Checkbox, isOn: this.credit }).onChange((value: boolean) => { this.credit = value; })
      Text('信用卡账户（勾选后才允许负余额）').fontSize(13)
      if (this.error) { Text(this.error).fontColor(FinanceTheme.expense) }
      Button(this.state.saving ? '保存中…' : '保存账户').width('100%').height(50).backgroundColor(FinanceTheme.text).enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.save())
      if (this.editingId) { Button('取消编辑').backgroundColor('#EAEAEA').fontColor(FinanceTheme.text).onClick(() => this.clear()) }
      }.padding(20).width('100%').backgroundColor('#FFFFFF').borderRadius(24)
      Text('高级操作 · 删除时迁移历史（不转移初始余额）').fontSize(12).fontColor(FinanceTheme.muted)
      Select(this.targets())
        .onSelect((index: number) => { this.targetId = index === 0 ? '' : this.state.data.accounts[index - 1].id; })
    }.width('100%')
  }
}
