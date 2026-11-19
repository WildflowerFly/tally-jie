import { AppState } from '../state/AppState';
import { monthlyTotalBudget, saveMonthlyBudget } from '../service/BudgetService';
import { keypadAmount } from '../service/TransactionService';
import { money, newId } from '../model/AppData';
import { DetailsPalette } from '../theme/DetailsPalette';

// Mounted inside the navigation surface, not a separate page or system dialog.
@Component
export struct MonthlyBudgetSheet {
  @ObjectLink state: AppState;
  @Prop monthDate: string = '';
  onClose: () => void = () => {};
  @State amount: string = '';
  @State error: string = '';
  private budgetId: string = '';

  aboutToAppear(): void {
    const budget = monthlyTotalBudget(this.state.data, this.monthDate);
    this.budgetId = budget?.id || '';
    this.amount = budget === undefined ? '' : money(budget.amountCents);
    this.error = '';
  }
  private close(): void {
    if (this.state.saving) { return; }
    this.onClose();
  }
  private enterAmountKey(key: string): void {
    if (this.state.saving) { return; }
    this.amount = key === 'clear' ? '' : keypadAmount(this.amount, key);
    this.error = '';
  }
  private async save(): Promise<void> {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    this.error = '';
    if (this.budgetId && monthlyTotalBudget(this.state.data, this.monthDate)?.id !== this.budgetId) {
      this.error = '此预算已发生变化，请关闭后重试。'; return;
    }
    try {
      const next = saveMonthlyBudget(this.state.data, this.amount, this.monthDate, newId(), new Date().toISOString());
      if (await this.state.commit(next)) { this.close(); }
      else { this.error = this.state.message || '暂时无法保存，请稍后重试。'; }
    } catch (error) {
      const code = (error as Error).message;
      if (code === 'BUDGET_OVERLAP') { this.error = '本月已有重叠的总预算，请先在预算管理中调整。'; }
      else if (code === 'INVALID_AMOUNT' || code === 'AMOUNT_OVERFLOW') { this.error = '请输入大于0的金额，最多保留两位小数。'; }
      else { this.error = code || '保存失败，请重试。'; }
    }
  }
  build() {
    Scroll() {
      Column({ space: 10 }) {
        Column() {}.width(32).height(4).borderRadius(2).backgroundColor(DetailsPalette.handle).accessibilityLevel('no')
        Row() {
          Text(this.budgetId ? '编辑本月预算' : '设置本月预算').fontSize(21).fontWeight(FontWeight.Medium).fontColor(DetailsPalette.text)
          Blank()
          Button('取消', { type: ButtonType.Normal }).height(32).fontSize(14).fontColor(DetailsPalette.secondary)
            .padding({ left: 12, right: 0 }).backgroundColor(Color.Transparent).enabled(!this.state.saving)
            .id('details-budget-cancel').onClick(() => this.close())
        }.width('100%')
        Text(`${this.monthDate.slice(0, 4)}年${this.monthDate.slice(5, 7)}月 · 月度总预算`)
          .width('100%').fontSize(13).fontColor(DetailsPalette.muted)
        Row({ space: 10 }) {
          Text('¥').fontSize(26).fontColor(DetailsPalette.secondary)
          Text(this.amount || '0.00').layoutWeight(1).fontSize(26)
            .fontColor(this.amount ? DetailsPalette.text : DetailsPalette.faint).maxLines(1).minFontSize(16).maxFontSize(26)
            .id('details-budget-amount').accessibilityText(`预算金额 ${this.amount || '0.00'}元`)
          Button('×', { type: ButtonType.Normal }).width(32).height(32).padding(0).fontSize(22)
            .fontColor(DetailsPalette.muted).backgroundColor(Color.Transparent).borderRadius(16)
            .enabled(!this.state.saving && this.amount.length > 0).accessibilityText('清空预算金额')
            .id('details-budget-clear').onClick(() => this.enterAmountKey('clear'))
        }.width('100%').height(56).padding({ left: 16, right: 12 }).borderRadius(14)
          .backgroundColor(DetailsPalette.surfaceMuted).id('details-budget-amount-surface')
        Column({ space: 8 }) {
          ForEach(['123', '456', '789', '.0←'], (keys: string) => {
            Row({ space: 8 }) {
              ForEach(keys.split(''), (key: string) => {
                Button(key, { type: ButtonType.Normal }).layoutWeight(1).height(44).padding(0)
                  .fontSize(24).fontColor(DetailsPalette.text).backgroundColor(DetailsPalette.surfaceMuted).borderRadius(12)
                  .enabled(!this.state.saving).accessibilityText(key === '←' ? '删除一位' : key === '.' ? '小数点' : key)
                  .id(`details-budget-key-${key === '←' ? 'back' : key === '.' ? 'decimal' : key}`)
                  .onClick(() => this.enterAmountKey(key === '←' ? 'back' : key))
              }, (key: string) => key)
            }.width('100%')
          }, (keys: string) => keys)
        }.width('100%').id('details-budget-keypad')
        if (this.error) {
          Text(this.error).width('100%').fontSize(12).fontColor(DetailsPalette.secondary).lineHeight(18)
            .id('details-budget-message').accessibilityGroup(true)
        }
        Button(this.state.saving ? '保存中…' : '保存预算').width('100%').height(46).fontSize(15)
          .fontColor('#FFFFFF').backgroundColor(DetailsPalette.strongBackground).borderRadius(23)
          .enabled(this.state.status === 'ready' && !this.state.saving)
          .id('details-budget-save').onClick(() => this.save())
      }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 20 })
    }.width('100%').height('100%').scrollBar(BarState.Off).id('details-budget-sheet')
  }
}
