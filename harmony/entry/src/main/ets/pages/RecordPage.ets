import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
import { Account, Category, EntryType } from '../model/LedgerModels';
import { saveEntry, EntryInput, keypadAmount } from '../service/TransactionService';
import { categoryLabel } from '../service/CategoryService';
import { dateKey, newId } from '../model/AppData';

@Component
export struct RecordPage {
  @ObjectLink state: AppState;
  @Link amount: string;
  @Link note: string;
  @State income: boolean = false;
  @State accountId: string = '';
  @State categoryId: string = '';
  @State date: string = dateKey();
  @State time: string = `${new Date().getHours().toString().padStart(2, '0')}:${new Date().getMinutes().toString().padStart(2, '0')}`;
  @State error: string = '';
  @State feedback: string = '';
  @State submissionId: string = newId();
  onDirty: () => void = () => {};
  onManageAccounts: () => void = () => {};
  onManageCategories: () => void = () => {};
  private categories(): Category[] {
    return this.state.data.categories.filter((row) => row.type === (this.income ? 'income' : 'expense'))
      .sort((a: Category, b: Category) => a.sortOrder - b.sortOrder || a.id.localeCompare(b.id));
  }
  private accounts(): SelectOption[] {
    const options: SelectOption[] = [{ value: '请选择账户' }];
    this.state.data.accounts.forEach((row: Account) => { options.push({ value: row.name }); }); return options;
  }
  private async save(): Promise<void> {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    this.error = ''; this.feedback = '';
    try {
      const type: EntryType = this.income ? 'income' : 'expense';
      const input: EntryInput = { id: this.submissionId, type: type, amount: this.amount,
        accountId: this.accountId, categoryId: this.categoryId, date: this.date, time: this.time, note: this.note };
      if (await this.state.commit(saveEntry(this.state.data, input, new Date().toISOString()))) {
        this.amount = ''; this.note = ''; this.submissionId = newId(); this.date = dateKey();
        this.time = `${new Date().getHours().toString().padStart(2, '0')}:${new Date().getMinutes().toString().padStart(2, '0')}`;
        this.feedback = '已保存'; this.onDirty();
      }
    } catch (error) { this.error = (error as Error).message; }
  }
  private pickDate(): void {
    this.getUIContext().showDatePickerDialog({ start: new Date(1, 0, 1), end: new Date(9999, 11, 31),
      selected: new Date(`${this.date}T12:00:00`),
      onAccept: (value: DatePickerResult) => {
        this.date = `${value.year}-${(value.month! + 1).toString().padStart(2, '0')}-${value.day!.toString().padStart(2, '0')}`;
      }
    });
  }
  private pickTime(): void {
    this.getUIContext().showTimePickerDialog({ selected: new Date(`${this.date}T${this.time}:00`), useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        this.time = `${value.hour!.toString().padStart(2, '0')}:${value.minute!.toString().padStart(2, '0')}`;
      }
    });
  }
  build() {
    Column({ space: 16 }) {
      Text('记一笔').fontSize(28).fontWeight(FontWeight.Bold).width('100%')
      Row({ space: 12 }) {
        Button('支出').backgroundColor(!this.income ? FinanceTheme.text : '#767676')
          .onClick(() => { this.income = false; this.categoryId = ''; })
        Button('收入').backgroundColor(this.income ? FinanceTheme.text : '#767676')
          .onClick(() => { this.income = true; this.categoryId = ''; })
      }
      Column({ space: 16 }) {
        TextInput({ placeholder: '金额 0.00', text: this.amount }).id('record-amount').type(InputType.Normal).fontSize(30)
          .onChange((value: string) => { this.amount = value; this.onDirty(); })
        if (this.state.data.accounts.length === 0) {
          Button('先创建账户').onClick(() => this.onManageAccounts())
        } else {
          Select(this.accounts()).value(this.state.data.accounts.find((row) => row.id === this.accountId)?.name || '请选择账户')
            .onSelect((index: number) => { this.accountId = index === 0 ? '' : this.state.data.accounts[index - 1].id; })
        }
        if (this.categories().length === 0) {
          Button('创建当前类型分类').onClick(() => this.onManageCategories())
        } else {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.categories(), (row: Category) => {
              Button(`${categoryLabel(row.iconKey)} ${row.name}`).margin(4).fontSize(14)
                .backgroundColor(this.categoryId === row.id ? FinanceTheme.text : '#767676')
                .onClick(() => { this.categoryId = row.id; })
            }, (row: Category) => row.id)
          }
        }
        Row({ space: 12 }) {
          Button(this.date).fontSize(14).onClick(() => this.pickDate())
          Button(this.time).fontSize(14).onClick(() => this.pickTime())
        }
        TextInput({ placeholder: '备注（选填，最多500字）', text: this.note }).maxLength(500)
          .onChange((value: string) => { this.note = value; this.onDirty(); })
        Column({ space: 6 }) {
          ForEach(['123', '456', '789', '.0←'], (keys: string) => {
            Row({ space: 6 }) {
              ForEach(keys.split(''), (key: string) => {
                Button(key).layoutWeight(1).backgroundColor('#EEEEEE').fontColor(FinanceTheme.text)
                  .onClick(() => { this.amount = keypadAmount(this.amount, key === '←' ? 'back' : key); this.onDirty(); })
              }, (key: string) => key)
            }
          }, (keys: string) => keys)
        }
        if (this.error) { Text(this.error).fontColor(FinanceTheme.expense) }
        if (this.feedback) { Text(this.feedback).fontColor(FinanceTheme.income) }
        Button(this.state.saving ? '保存中…' : '保存').width('100%')
          .enabled(this.state.status === 'ready' && !this.state.saving)
          .backgroundColor(FinanceTheme.text).fontColor('#FFFFFF').onClick(() => this.save())
      }.padding(20).backgroundColor(FinanceTheme.card).borderRadius(FinanceTheme.radius)
      if (this.state.status !== 'ready') { Text('账本尚未就绪，禁止写入').fontColor(FinanceTheme.expense).fontSize(14) }
    }.width('100%').id('finance-page-record')
  }
}
