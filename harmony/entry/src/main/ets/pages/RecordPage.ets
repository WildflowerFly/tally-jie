import { LengthMetrics } from '@kit.ArkUI';
import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';
import { Account, Category, EntryType } from '../model/LedgerModels';
import { saveEntry, EntryInput } from '../service/TransactionService';
import { dateKey, newId } from '../model/AppData';
import { upsertCategory } from '../service/CategoryService';
import { displayAmount } from '../domain/AmountDisplay';
import { recordCategories } from '../domain/RecordCategories';
import { RecordChip } from '../components/RecordChip';
import { categoryIcon } from '../components/CategoryIcon';
import { accountIconKey } from '../domain/AccountAppearance';
import { accountIconResource } from '../components/AccountIcon';

@Component
export struct RecordPage {
  @ObjectLink state: AppState;
  @Link amount: string;
  @Link note: string;
  @State income: boolean = false;
  @State accountId: string = '';
  @State categoryId: string = '';
  @State error: string = '';
  @State submissionId: string = newId();
  onDirty: () => void = () => {};
  onAmount: () => void = () => {};
  onSaved: () => void = () => {};
  onManageAccounts: () => void = () => {};
  onManageCategories: () => void = () => {};
  private categories(): Category[] {
    const type: EntryType = this.income ? 'income' : 'expense';
    return recordCategories(this.state.data.categories, type);
  }
  private async selectCategory(row: Category): Promise<void> {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    if (!this.state.data.categories.some((item) => item.id === row.id)) {
      try {
        let next = this.state.data;
        const now = new Date().toISOString();
        this.categories().forEach((preset: Category) => {
          next = upsertCategory(next, preset.id, preset.name, preset.type, preset.iconKey, preset.sortOrder, now);
        });
        if (!await this.state.commit(next)) { return; }
      } catch (error) { this.error = (error as Error).message; return; }
    }
    this.categoryId = row.id;
  }
  private async save(): Promise<void> {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    this.error = '';
    try {
      // Capture the save tap once so local date, time and audit timestamps stay in sync.
      const savedAt = new Date();
      const type: EntryType = this.income ? 'income' : 'expense';
      const input: EntryInput = { id: this.submissionId, type: type, amount: this.amount,
        accountId: this.accountId, categoryId: this.categoryId, date: dateKey(savedAt),
        time: `${savedAt.getHours().toString().padStart(2, '0')}:${savedAt.getMinutes().toString().padStart(2, '0')}`,
        note: this.note };
      if (await this.state.commit(saveEntry(this.state.data, input, savedAt.toISOString()))) {
        // Reset only after the persisted commit succeeds; failed saves keep the draft.
        this.amount = ''; this.note = ''; this.income = false; this.accountId = ''; this.categoryId = '';
        this.submissionId = newId(); this.getUIContext().getFocusController().clearFocus();
        this.onDirty(); this.onSaved();
      }
    } catch (error) { this.error = (error as Error).message; }
  }
  build() {
    Column({ space: 22 }) {
      Column({ space: 8 }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          Text('¥').fontSize(26).fontWeight(FontWeight.Normal)
          Text(displayAmount(this.amount)).fontSize(this.amount.length > 10 ? 34 : 44)
            .fontWeight(FontWeight.Normal).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 16, bottom: 4 })
      }.id('record-amount').width('100%').backgroundColor(Color.Transparent).fontColor(FinanceTheme.text)
        .accessibilityText(`金额 ${displayAmount(this.amount)} 元，点击输入`)
        .onClick(() => { this.getUIContext().getFocusController().clearFocus(); this.onAmount(); })
      Row({ space: 12 }) {
        Button('支出', { type: ButtonType.Normal }).layoutWeight(1).height(44).borderRadius(10)
          .fontSize(17).fontWeight(FontWeight.Medium)
          .fontColor(!this.income ? '#FFFFFF' : FinanceTheme.text)
          .backgroundColor(!this.income ? FinanceTheme.text : '#EAEAEA')
          .onClick(() => { if (this.income) { this.income = false; this.categoryId = ''; } })
        Button('收入', { type: ButtonType.Normal }).layoutWeight(1).height(44).borderRadius(10)
          .fontSize(17).fontWeight(FontWeight.Medium)
          .fontColor(this.income ? '#FFFFFF' : FinanceTheme.text)
          .backgroundColor(this.income ? FinanceTheme.text : '#EAEAEA')
          .onClick(() => { if (!this.income) { this.income = true; this.categoryId = ''; } })
      }.width('100%').justifyContent(FlexAlign.Center)
      }.width('100%')
      Column({ space: 12 }) {
        Text('分类').fontSize(12).fontWeight(FontWeight.Normal).fontColor(FinanceTheme.muted).width('100%')
        if (this.categories().length === 0) {
          Button('＋ 创建当前类型分类').fontSize(14).backgroundColor('#EAEAEA').fontColor(FinanceTheme.text)
            .onClick(() => this.onManageCategories())
        } else {
          // Keep four equal columns, but let each row grow if a full name wraps.
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(8) } }) {
            ForEach(this.categories(), (row: Category) => {
              Column() {
                RecordChip({ label: row.name, icon: categoryIcon(row), selected: this.categoryId === row.id,
                  onSelect: () => { this.selectCategory(row); } })
              }.width('calc((100% - 18vp) / 4)').flexShrink(0)
            }, (row: Category) => row.id)
          }.width('100%')
        }
      }.alignItems(HorizontalAlign.Start).width('100%')
      Column({ space: 12 }) {
        Text('账户').fontSize(12).fontWeight(FontWeight.Normal).fontColor(FinanceTheme.muted).width('100%')
        if (this.state.data.accounts.length === 0) {
          Button('＋ 先创建账户').fontSize(14).backgroundColor('#EAEAEA').fontColor(FinanceTheme.text)
            .onClick(() => this.onManageAccounts())
        } else {
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(8) } }) {
            ForEach(this.state.data.accounts, (row: Account) => {
              Column() {
                RecordChip({ label: row.name, icon: accountIconResource(accountIconKey(row)), providerMark: true,
                  selected: this.accountId === row.id,
                  onSelect: () => { this.accountId = row.id; } })
              }.width('calc((100% - 18vp) / 4)').flexShrink(0)
            }, (row: Account) => row.id)
          }.width('100%')
        }
      }.alignItems(HorizontalAlign.Start).width('100%')
      Column({ space: 12 }) {
        Text('备注').fontSize(12).fontWeight(FontWeight.Normal).fontColor(FinanceTheme.muted).width('100%')
        TextInput({ placeholder: '添加备注（选填）', text: this.note }).maxLength(500).height(36).id('record-note')
          .fontSize(12).fontWeight(FontWeight.Normal).fontColor('#777777')
          .placeholderFont({ size: 12, weight: FontWeight.Normal }).placeholderColor('#AAAAAA')
          .padding({ left: 12, right: 12, top: 0, bottom: 0 }).backgroundColor('#EFEFEF').borderRadius(10)
          .onChange((value: string) => { this.note = value; this.onDirty(); })
      }.width('100%')
      if (this.error) { Text(this.error).fontColor(FinanceTheme.expense) }
      Button(this.state.saving ? '保存中…' : '保存账单', { type: ButtonType.Normal })
        .width('100%').height(54).borderRadius(10).fontSize(17).fontWeight(FontWeight.Medium)
        .enabled(this.state.status === 'ready' && !this.state.saving)
        .backgroundColor(FinanceTheme.text).fontColor('#FFFFFF').onClick(() => this.save()).id('record-save')
      if (this.state.status !== 'ready') { Text('账本尚未就绪，禁止写入').fontColor(FinanceTheme.expense).fontSize(14) }
    }.width('100%').id('finance-page-record')
  }
}
