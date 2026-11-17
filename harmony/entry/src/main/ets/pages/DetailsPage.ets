import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
import { LedgerFilter, LedgerEntry, LedgerCursor, EntryType } from '../model/LedgerModels';
import { defaultFilter, queryEntries } from '../service/LedgerQueryService';
import { saveEntry, deleteEntry, EntryInput } from '../service/TransactionService';
import { parseAmount } from '../domain/Money';
import { money } from '../model/AppData';

@Component
export struct DetailsPage {
  @ObjectLink state: AppState;
  @Prop initialFilter: LedgerFilter = defaultFilter();
  @State keyword: string = '';
  @State typeIndex: number = 0;
  @State accountId: string = '';
  @State categoryId: string = '';
  @State start: string = '';
  @State end: string = '';
  @State min: string = '';
  @State max: string = '';
  @State rows: LedgerEntry[] = [];
  @State income: number = 0;
  @State expense: number = 0;
  @State count: number = 0;
  @State next: LedgerCursor | null = null;
  @State error: string = '';
  @State selected: string = '';
  @State editAmount: string = '';
  @State editDate: string = '';
  @State editTime: string = '';
  @State editNote: string = '';
  @State editAccount: string = '';
  @State editCategory: string = '';
  @State editIncome: boolean = false;
  private active: LedgerFilter = defaultFilter();
  aboutToAppear(): void {
    this.keyword = this.initialFilter.keyword;
    this.typeIndex = this.initialFilter.type === null ? 0 : this.initialFilter.type === 'expense' ? 1 : 2;
    this.accountId = this.initialFilter.accountIds[0] || ''; this.categoryId = this.initialFilter.categoryIds[0] || '';
    this.start = this.initialFilter.range?.startDate || ''; this.end = this.initialFilter.range?.endDate || '';
    this.min = this.initialFilter.minAmountCents === null ? '' : money(this.initialFilter.minAmountCents);
    this.max = this.initialFilter.maxAmountCents === null ? '' : money(this.initialFilter.maxAmountCents);
    this.search();
  }
  private options(account: boolean, all: boolean): SelectOption[] {
    const result: SelectOption[] = all ? [{ value: '全部' }] : [{ value: '请选择' }];
    if (account) { this.state.data.accounts.forEach((row) => { result.push({ value: row.name }); }); }
    else { this.state.data.categories.forEach((row) => { result.push({ value: `${row.type === 'income' ? '收' : '支'} · ${row.name}` }); }); }
    return result;
  }
  private filter(): LedgerFilter {
    const filter = defaultFilter();
    filter.keyword = this.keyword; filter.type = this.typeIndex === 0 ? null : this.typeIndex === 1 ? 'expense' : 'income';
    filter.accountIds = this.accountId ? [this.accountId] : []; filter.categoryIds = this.categoryId ? [this.categoryId] : [];
    if (this.start || this.end) { filter.range = { startDate: this.start, endDate: this.end }; }
    filter.minAmountCents = this.min ? parseAmount(this.min) : null; filter.maxAmountCents = this.max ? parseAmount(this.max) : null;
    return filter;
  }
  private search(): void {
    try { this.active = this.filter(); this.fetch(false); } catch (error) { this.error = (error as Error).message; }
  }
  private fetch(append: boolean): void {
    try {
      this.active.cursor = append ? this.next : null;
      const page = queryEntries(this.state.data, this.active);
      this.rows = append ? this.rows.concat(page.rows) : page.rows;
      this.income = page.incomeCents; this.expense = page.expenseCents; this.count = page.count; this.next = page.next; this.error = '';
    } catch (error) { this.error = (error as Error).message; }
  }
  private open(row: LedgerEntry): void {
    this.selected = row.id; this.editAmount = money(row.amountCents); this.editDate = row.date;
    this.editTime = row.time; this.editNote = row.note; this.editAccount = row.accountId;
    this.editCategory = row.categoryId; this.editIncome = row.type === 'income'; this.error = '';
  }
  private async save(): Promise<void> {
    try {
      const type: EntryType = this.editIncome ? 'income' : 'expense';
      const input: EntryInput = { id: this.selected, type: type, amount: this.editAmount, date: this.editDate,
        time: this.editTime, note: this.editNote, accountId: this.editAccount, categoryId: this.editCategory };
      if (await this.state.commit(saveEntry(this.state.data, input, new Date().toISOString()))) { this.selected = ''; this.fetch(false); }
    } catch (error) { this.error = (error as Error).message; }
  }
  private confirmDelete(): void {
    const id = this.selected;
    this.getUIContext().showAlertDialog({ title: '删除这笔账单？', message: '删除后余额与统计会同步更新。若导致普通账户负余额将拒绝。',
      primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: '删除', action: () => { this.erase(id); } } });
  }
  private async erase(id: string): Promise<void> {
    try { if (await this.state.commit(deleteEntry(this.state.data, id))) { this.selected = ''; this.fetch(false); } }
    catch (error) { this.error = (error as Error).message; }
  }
  private dayTotal(date: string): string {
    const filter: LedgerFilter = JSON.parse(JSON.stringify(this.active)) as LedgerFilter;
    filter.cursor = null; filter.range = { startDate: date, endDate: date };
    const page = queryEntries(this.state.data, filter);
    return `收 ¥${money(page.incomeCents)} / 支 ¥${money(page.expenseCents)}`;
  }
  build() {
    Column({ space: 12 }) {
      Text('明细').fontSize(28).fontWeight(FontWeight.Bold).width('100%')
      if (this.selected) {
        Text('账单详情 / 编辑').fontSize(20)
        Text(`创建时间：${this.state.data.entries.find((row) => row.id === this.selected)?.createdAt || '历史数据未记录'}`).fontSize(13)
        TextInput({ text: this.editAmount, placeholder: '金额' }).onChange((value: string) => { this.editAmount = value; })
        Toggle({ type: ToggleType.Checkbox, isOn: this.editIncome }).onChange((value: boolean) => { this.editIncome = value; this.editCategory = ''; })
        Text('勾选为收入，未勾选为支出').fontSize(13)
        Select(this.options(true, false)).value(this.state.data.accounts.find((row) => row.id === this.editAccount)?.name || '选择账户')
          .onSelect((index: number) => { this.editAccount = index === 0 ? '' : this.state.data.accounts[index - 1].id; })
        Select(this.options(false, false)).value(this.state.data.categories.find((row) => row.id === this.editCategory)?.name || '选择同类型分类')
          .onSelect((index: number) => { this.editCategory = index === 0 ? '' : this.state.data.categories[index - 1].id; })
        TextInput({ text: this.editDate, placeholder: 'YYYY-MM-DD' }).onChange((value: string) => { this.editDate = value; })
        TextInput({ text: this.editTime, placeholder: 'HH:mm' }).onChange((value: string) => { this.editTime = value; })
        TextInput({ text: this.editNote, placeholder: '备注' }).maxLength(500).onChange((value: string) => { this.editNote = value; })
        Button('保存修改').enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.save())
        Button('删除账单').enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.confirmDelete())
        Button('返回列表').onClick(() => {
          this.getUIContext().showAlertDialog({ title: '放弃未保存的修改？', message: '原账单不会变化。',
            primaryButton: { value: '继续编辑', action: () => {} },
            secondaryButton: { value: '放弃修改', action: () => { this.selected = ''; } } });
        })
      } else {
        TextInput({ text: this.keyword, placeholder: '搜索分类、备注或账户' }).onChange((value: string) => { this.keyword = value; })
        Select([{ value: '全部收支' }, { value: '支出' }, { value: '收入' }]).onSelect((index: number) => { this.typeIndex = index; })
        Select(this.options(true, true)).onSelect((index: number) => { this.accountId = index === 0 ? '' : this.state.data.accounts[index - 1].id; })
        Select(this.options(false, true)).onSelect((index: number) => { this.categoryId = index === 0 ? '' : this.state.data.categories[index - 1].id; })
        TextInput({ text: this.start, placeholder: '开始日期 YYYY-MM-DD（含）' }).onChange((value: string) => { this.start = value; })
        TextInput({ text: this.end, placeholder: '结束日期 YYYY-MM-DD（含）' }).onChange((value: string) => { this.end = value; })
        TextInput({ text: this.min, placeholder: '最小金额（元）' }).onChange((value: string) => { this.min = value; })
        TextInput({ text: this.max, placeholder: '最大金额（元）' }).onChange((value: string) => { this.max = value; })
        Button('应用筛选').onClick(() => this.search())
        Button('重置筛选').onClick(() => {
          this.keyword = ''; this.typeIndex = 0; this.accountId = ''; this.categoryId = '';
          this.start = ''; this.end = ''; this.min = ''; this.max = ''; this.search();
        })
        Text(`共${this.count}笔 · 收¥${money(this.income)} · 支¥${money(this.expense)}`).fontSize(14)
        if (this.rows.length === 0) { Text('暂无符合条件的账单').fontColor(FinanceTheme.muted) }
        ForEach(this.rows, (row: LedgerEntry, index: number) => {
          if (index === 0 || this.rows[index - 1].date !== row.date) {
            Text(`${row.date} · ${this.dayTotal(row.date)}`).fontSize(13).width('100%')
          }
          Button(`${row.time} ${this.state.data.categories.find((item) => item.id === row.categoryId)?.name || ''} · ${this.state.data.accounts.find((item) => item.id === row.accountId)?.name || ''} · ${row.type === 'income' ? '+' : '-'}¥${money(row.amountCents)}`)
            .fontSize(14).width('100%').backgroundColor('#FFFFFF')
            .fontColor(row.type === 'income' ? FinanceTheme.income : FinanceTheme.expense).onClick(() => this.open(row))
        }, (row: LedgerEntry) => row.id)
        if (this.next !== null) { Button('加载更多').onClick(() => this.fetch(true)) }
      }
      if (this.error) { Text(this.error).fontColor(FinanceTheme.expense) }
    }.width('100%').id('finance-page-details')
  }
}
