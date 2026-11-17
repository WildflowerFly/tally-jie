import { FinanceHeader } from '../components/FinanceHeader';
import { AppState } from '../state/AppState';
import { BudgetRule, BudgetPeriod, Category } from '../model/LedgerModels';
import { saveBudget, removeBudget, budgetUsage, BudgetInput } from '../service/BudgetService';
import { money, dateKey, newId } from '../model/AppData';
import { FinanceTheme } from '../theme/FinanceTheme';
@Component
export struct BudgetManagePage {
  @ObjectLink state: AppState;
  onBack: () => void = () => {};
  @State budgetId: string = '';
  @State amount: string = '';
  @State categoryId: string = '';
  @State period: BudgetPeriod = 'month';
  @State start: string = dateKey();
  @State end: string = dateKey();
  @State editing: boolean = false;
  @State message: string = '';
  private categories(): Category[] { return this.state.data.categories.filter((row) => row.type === 'expense'); }
  private options(): SelectOption[] {
    const result: SelectOption[] = [{ value: '总预算' }];
    this.categories().forEach((row) => { result.push({ value: row.name }); }); return result;
  }
  private open(row?: BudgetRule): void {
    this.budgetId = row?.id || newId(); this.amount = row === undefined ? '' : money(row.amountCents);
    this.categoryId = row?.categoryId || ''; this.period = row?.period || 'month'; this.start = row?.startDate || dateKey(); this.end = row?.endDate || dateKey();
    this.editing = true; this.message = '';
  }
  private async save(): Promise<void> {
    try {
      const input: BudgetInput = { id: this.budgetId, categoryId: this.categoryId || null, amount: this.amount,
        period: this.period, startDate: this.start, endDate: this.end };
      if (await this.state.commit(saveBudget(this.state.data, input, new Date().toISOString()))) { this.editing = false; this.message = '预算已保存'; }
    } catch (error) { this.message = (error as Error).message; }
  }
  private async erase(id: string): Promise<void> {
    try { if (await this.state.commit(removeBudget(this.state.data, id))) { this.message = '预算已删除'; } }
    catch (error) { this.message = (error as Error).message; }
  }
  build() {
    Column({ space: 12 }) {
      FinanceHeader({ title: '预算计划', subtitle: 'BUDGETS · 为消费留出边界', back: true, onBack: () => this.onBack() })
      Text('周期为独立预算，不自动循环；同范围对象的日期不可重叠。').fontSize(13)
      if (this.editing) {
        Column({ space: 14 }) {
        Text('预算信息').fontSize(19).fontWeight(FontWeight.Bold).width('100%')
        TextInput({ text: this.amount, placeholder: '预算金额（元）' }).onChange((value: string) => { this.amount = value; })
        Select(this.options()).value(this.state.data.categories.find((row) => row.id === this.categoryId)?.name || '总预算')
          .onSelect((index: number) => { this.categoryId = index === 0 ? '' : this.categories()[index - 1].id; })
        Select([{ value: '自然月' }, { value: '周一至周日' }, { value: '自定义' }]).value(this.period === 'month' ? '自然月' : this.period === 'week' ? '周一至周日' : '自定义')
          .onSelect((index: number) => { this.period = index === 0 ? 'month' : index === 1 ? 'week' : 'custom'; })
        TextInput({ text: this.start, placeholder: '所在日期 / 开始日期 YYYY-MM-DD' }).onChange((value: string) => { this.start = value; })
        if (this.period === 'custom') { TextInput({ text: this.end, placeholder: '结束日期 YYYY-MM-DD（含）' }).onChange((value: string) => { this.end = value; }) }
        Button('保存预算').width('100%').height(50).backgroundColor(FinanceTheme.text).enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.save())
        Button('取消编辑').backgroundColor('#EAEAEA').fontColor(FinanceTheme.text).onClick(() => { this.editing = false; })
        }.padding(20).width('100%').backgroundColor('#FFFFFF').borderRadius(24)
      } else {
        Button('＋ 新增预算').width('100%').height(50).backgroundColor(FinanceTheme.text).onClick(() => this.open())
        ForEach(this.state.data.budgets, (row: BudgetRule) => {
          Column({ space: 8 }) {
            Text(`${row.categoryId === null ? '总预算' : this.state.data.categories.find((item) => item.id === row.categoryId)?.name} · ${row.startDate} ~ ${row.endDate}`)
            Text(`预算¥${money(row.amountCents)} · 已用¥${money(budgetUsage(this.state.data, row).usedCents)}`)
            Text(`剩余¥${money(budgetUsage(this.state.data, row).remainingCents)} · ${budgetUsage(this.state.data, row).percent.toFixed(1)}%`)
              .fontColor(budgetUsage(this.state.data, row).percent > 100 ? FinanceTheme.expense : FinanceTheme.text)
            Progress({ value: Math.min(100, budgetUsage(this.state.data, row).percent), total: 100, type: ProgressType.Linear }).width('100%').color(budgetUsage(this.state.data, row).percent > 100 ? FinanceTheme.expense : FinanceTheme.text).backgroundColor('#EEEEEE')
            Button('修改').backgroundColor(FinanceTheme.text).onClick(() => this.open(row))
            Button('删除').backgroundColor('#F8EDEA').fontColor(FinanceTheme.expense).enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => {
              this.getUIContext().showAlertDialog({ title: '删除预算？', message: '不影响账单和账户余额。', primaryButton: { value: '取消', action: () => {} },
                secondaryButton: { value: '删除', action: () => { this.erase(row.id); } } });
            })
          }.padding(20).width('100%').backgroundColor('#FFFFFF').borderRadius(24)
        }, (row: BudgetRule) => row.id)
      }
      if (this.message) { Text(this.message).fontColor(FinanceTheme.muted) }
      if (!this.editing && this.state.data.budgets.length === 0) { Text('还没有预算，从一个小目标开始。').fontSize(14).fontColor(FinanceTheme.muted).padding(24) }
    }.width('100%')
  }
}
