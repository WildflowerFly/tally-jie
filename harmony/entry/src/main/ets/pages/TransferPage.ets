import { AppState } from '../state/AppState';
import { Transfer } from '../model/LedgerModels';
import { saveTransfer, deleteTransfer, TransferInput } from '../service/TransferService';
import { money, dateKey, newId } from '../model/AppData';
import { FinanceTheme } from '../theme/FinanceTheme';
@Component
export struct TransferPage {
  @ObjectLink state: AppState;
  @Prop accountId: string = '';
  onBack: () => void = () => {};
  @State transferId: string = '';
  @State from: string = '';
  @State to: string = '';
  @State amount: string = '';
  @State date: string = dateKey();
  @State time: string = '12:00';
  @State note: string = '';
  @State editing: boolean = false;
  @State message: string = '';
  private options(): SelectOption[] {
    const result: SelectOption[] = [{ value: '请选择账户' }];
    this.state.data.accounts.forEach((row) => { result.push({ value: row.name }); }); return result;
  }
  private name(id: string): string { return this.state.data.accounts.find((row) => row.id === id)?.name || '请选择账户'; }
  private records(): Transfer[] {
    return this.state.data.transfers.filter((row) => !this.accountId || row.fromAccountId === this.accountId || row.toAccountId === this.accountId)
      .sort((a: Transfer, b: Transfer) => `${b.date}|${b.time}|${b.id}`.localeCompare(`${a.date}|${a.time}|${a.id}`));
  }
  private open(row?: Transfer): void {
    this.transferId = row?.id || newId(); this.from = row?.fromAccountId || this.accountId; this.to = row?.toAccountId || '';
    this.amount = row === undefined ? '' : money(row.amountCents); this.date = row?.date || dateKey();
    const now = new Date();
    this.time = row?.time || `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    this.note = row?.note || ''; this.editing = true; this.message = '';
  }
  private async save(): Promise<void> {
    try {
      const input: TransferInput = { id: this.transferId, fromAccountId: this.from, toAccountId: this.to, amount: this.amount, date: this.date, time: this.time, note: this.note };
      if (await this.state.commit(saveTransfer(this.state.data, input, new Date().toISOString()))) { this.editing = false; this.message = '转账已保存'; }
    } catch (error) { this.message = (error as Error).message; }
  }
  private async erase(id: string): Promise<void> {
    try { if (await this.state.commit(deleteTransfer(this.state.data, id))) { this.message = '转账已删除'; } }
    catch (error) { this.message = (error as Error).message; }
  }
  build() {
    Column({ space: 12 }) {
      Text('账户转账').fontSize(26).fontWeight(FontWeight.Bold)
      Text('仅账户间调拨，信用卡还款使用转账；不计收入、支出或预算。').fontSize(14)
      if (this.editing) {
        Text('转出账户').fontSize(14)
        Select(this.options()).value(this.name(this.from)).onSelect((index: number) => { this.from = index === 0 ? '' : this.state.data.accounts[index - 1].id; })
        Text('转入账户').fontSize(14)
        Select(this.options()).value(this.name(this.to)).onSelect((index: number) => { this.to = index === 0 ? '' : this.state.data.accounts[index - 1].id; })
        TextInput({ text: this.amount, placeholder: '金额（元）' }).onChange((value: string) => { this.amount = value; })
        TextInput({ text: this.date, placeholder: 'YYYY-MM-DD' }).onChange((value: string) => { this.date = value; })
        TextInput({ text: this.time, placeholder: 'HH:mm' }).onChange((value: string) => { this.time = value; })
        TextInput({ text: this.note, placeholder: '备注' }).maxLength(500).onChange((value: string) => { this.note = value; })
        Text(`创建时间：${this.state.data.transfers.find((row) => row.id === this.transferId)?.createdAt || '新转账 / 历史未记录'}`).fontSize(13)
        Button('确认保存').enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => {
          this.getUIContext().showAlertDialog({ title: '确认转账变更？', message: `${this.name(this.from)} → ${this.name(this.to)}，¥${this.amount}`,
            primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: '保存', action: () => { this.save(); } } });
        })
        Button('取消编辑').onClick(() => { this.editing = false; })
      } else {
        Button('发起转账').enabled(this.state.data.accounts.length >= 2).onClick(() => this.open())
        ForEach(this.records(), (row: Transfer) => {
          Column({ space: 8 }) {
            Text(`${row.date} ${row.time} · ${row.toAccountId === this.accountId ? '转入' : '转出'} ¥${money(row.amountCents)}`)
            Text(`${this.name(row.fromAccountId)} → ${this.name(row.toAccountId)} · ${row.note}`)
            Button('详情 / 编辑').onClick(() => this.open(row))
            Button('删除').enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => {
              this.getUIContext().showAlertDialog({ title: '删除转账？', message: '将同时撤销双方余额变化，若普通账户低于0则拒绝。',
                primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: '删除', action: () => { this.erase(row.id); } } });
            })
          }.padding(12).backgroundColor('#FFFFFF').borderRadius(16)
        }, (row: Transfer) => row.id)
      }
      if (this.message) { Text(this.message).fontColor(FinanceTheme.muted) }
      Button('返回账户').onClick(() => this.onBack())
    }.width('100%')
  }
}
