import { AppState } from '../state/AppState';
import { Category, EntryType } from '../model/LedgerModels';
import { CATEGORY_ICONS, upsertCategory, removeCategory } from '../service/CategoryService';
import { newId } from '../model/AppData';
import { FinanceTheme } from '../theme/FinanceTheme';
import { categoryKeyIcon } from './CategoryIcon';

@Component
export struct CategoryEditorSheet {
  @ObjectLink state: AppState;
  @Prop categoryId: string = '';
  @Prop initialType: EntryType = 'expense';
  @State name: string = '';
  @State type: EntryType = 'expense';
  @State icon: string = 'category';
  @State order: string = '0';
  @State advanced: boolean = false;
  @State targetId: string = '';
  @State error: string = '';
  onCancel: () => void = () => {};
  onSaved: (type: EntryType) => void = () => {};

  aboutToAppear(): void {
    const row = this.state.data.categories.find((item) => item.id === this.categoryId);
    this.name = row?.name || ''; this.type = row?.type || this.initialType;
    this.icon = row?.iconKey || 'category';
    const orders = this.state.data.categories.filter((item) => item.type === this.type).map((item) => item.sortOrder);
    this.order = (row === undefined ? Math.max(-1, ...orders) + 1 : row.sortOrder).toString();
    this.error = ''; this.targetId = ''; this.advanced = false;
  }
  private targets(): Category[] {
    const source = this.state.data.categories.find((row) => row.id === this.categoryId);
    return this.state.data.categories.filter((row) => row.id !== this.categoryId && row.type === source?.type);
  }
  private targetOptions(): SelectOption[] {
    const result: SelectOption[] = [{ value: '不迁移' }];
    this.targets().forEach((row) => { result.push({ value: row.name }); });
    return result;
  }
  private fail(error: Error): void {
    switch (error.message) {
      case 'INVALID_ENTITY': this.error = '名称不能为空或与同类型分类重名。'; break;
      case 'REFERENCE_IN_USE': this.error = '分类仍有关联记录，请选择迁移分类。'; break;
      case 'BUDGET_OVERLAP': this.error = '两个分类的预算周期重叠，请先调整预算。'; break;
      case 'CATEGORY_TYPE_MISMATCH': this.error = '迁移分类须为同一收支类型。'; break;
      default: this.error = error.message || '操作失败，请重试。';
    }
  }
  private async save(): Promise<void> {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    this.error = '';
    if (this.categoryId && !this.state.data.categories.some((row) => row.id === this.categoryId)) {
      this.error = '分类已不存在，请关闭后重试。'; return;
    }
    if (!/^\d+$/.test(this.order) || !Number.isSafeInteger(Number(this.order))) {
      this.error = '排序请输入非负整数。'; return;
    }
    try {
      const next = upsertCategory(this.state.data, this.categoryId || newId(), this.name, this.type,
        this.icon, Number(this.order), new Date().toISOString());
      if (await this.state.commit(next)) { this.onSaved(this.type); }
      else { this.error = this.state.message || '保存失败，请重试。'; }
    } catch (error) { this.fail(error as Error); }
  }
  private confirmDelete(): void {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    const row = this.state.data.categories.find((item) => item.id === this.categoryId);
    if (row === undefined) { return; }
    const entries = this.state.data.entries.filter((item) => item.categoryId === row.id).length;
    const budgets = this.state.data.budgets.filter((item) => item.categoryId === row.id).length;
    const target = this.targets().find((item) => item.id === this.targetId);
    if ((entries || budgets) && target === undefined) {
      this.advanced = true; this.error = `关联 ${entries} 笔账单、${budgets} 条预算，请先选择迁移分类。`; return;
    }
    this.getUIContext().showAlertDialog({ title: `删除「${row.name}」？`,
      message: target === undefined ? '删除后无法撤销。' :
        `${entries} 笔账单、${budgets} 条预算将迁移至「${target.name}」。预算周期重叠时不会删除。`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '删除', fontColor: FinanceTheme.expense, action: () => this.erase() }
    });
  }
  private async erase(): Promise<void> {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    try {
      if (await this.state.commit(removeCategory(this.state.data, this.categoryId, this.targetId || null))) {
        this.onSaved(this.type);
      } else { this.error = this.state.message || '删除失败，请重试。'; }
    } catch (error) { this.fail(error as Error); }
  }
  @Builder
  typeButton(type: EntryType, label: string) {
    Button(label, { type: ButtonType.Normal }).layoutWeight(1).height(40).borderRadius(12).fontSize(14)
      .backgroundColor(this.type === type ? FinanceTheme.text : '#F0F0F0')
      .fontColor(this.type === type ? '#FFFFFF' : FinanceTheme.text).enabled(!this.state.saving)
      .onClick(() => { this.type = type; }).id(`category-editor-${type}`)
  }
  build() {
    Scroll() {
      Column({ space: 20 }) {
        Row() {
          Text(this.categoryId ? '编辑分类' : '新增分类').fontSize(21).fontWeight(FontWeight.Medium)
          Blank()
          Button('取消').fontSize(14).backgroundColor(Color.Transparent).fontColor(FinanceTheme.muted)
            .enabled(!this.state.saving).onClick(() => this.onCancel()).id('category-editor-cancel')
        }.width('100%')
        TextInput({ text: this.name, placeholder: '分类名称' }).maxLength(30).height(48).borderRadius(14)
          .backgroundColor('#F5F5F5').enabled(!this.state.saving).id('category-editor-name')
          .onChange((value: string) => { this.name = value; })
        Row({ space: 10 }) {
          this.typeButton('expense', '支出')
          this.typeButton('income', '收入')
        }.width('100%')
        Column({ space: 12 }) {
          Text('图标').fontSize(12).fontColor(FinanceTheme.muted).width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(CATEGORY_ICONS, (key: string, index: number) => {
              Button({ type: ButtonType.Normal }) {
                Image(categoryKeyIcon(key)).width(22).height(22).accessibilityLevel('no')
              }.width(44).height(44).padding(0).borderRadius(13).margin({ right: 6, bottom: 6 })
                .backgroundColor(this.icon === key ? '#E1E1E1' : '#F7F7F7')
                .border({ width: this.icon === key ? 1 : 0, color: '#171717', radius: 13 })
                .accessibilityText(['通用', '餐饮', '出行', '住房', '购物', '薪资', '礼物'][index])
                .accessibilityDescription(this.icon === key ? '已选中' : '未选中')
                .enabled(!this.state.saving).onClick(() => { this.icon = key; })
            }, (key: string) => key)
          }.width('100%')
        }.width('100%')
        Button(this.advanced ? '收起更多设置' : '更多设置').height(32).fontSize(12)
          .backgroundColor(Color.Transparent).fontColor(FinanceTheme.muted).enabled(!this.state.saving)
          .onClick(() => { this.advanced = !this.advanced; }).id('category-editor-more')
        if (this.advanced) {
          Row() {
            Text('排序').fontSize(14).layoutWeight(1)
            TextInput({ text: this.order, placeholder: '0' }).width(110).height(40).type(InputType.Number)
              .enabled(!this.state.saving).onChange((value: string) => { this.order = value; })
          }.width('100%')
          if (this.categoryId) {
            Row() {
              Text('删除时迁移至').fontSize(13).layoutWeight(1)
              Select(this.targetOptions()).selected(this.targets().findIndex((row) => row.id === this.targetId) + 1)
                .value(this.targets().find((row) => row.id === this.targetId)?.name || '不迁移')
                .font({ size: 13 }).enabled(!this.state.saving)
                .onSelect((index: number) => { this.targetId = index === 0 ? '' : this.targets()[index - 1]?.id || ''; })
            }.width('100%')
          }
        }
        if (this.error) { Text(this.error).fontSize(13).fontColor(FinanceTheme.expense).width('100%') }
        Button(this.state.saving ? '保存中…' : '保存').height(48).width('100%').fontSize(16)
          .backgroundColor(FinanceTheme.text).enabled(this.state.status === 'ready' && !this.state.saving)
          .onClick(() => this.save()).id('category-editor-save')
        if (this.categoryId) {
          Button('删除分类').fontSize(13).height(36).fontColor(FinanceTheme.expense).backgroundColor(Color.Transparent)
            .enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.confirmDelete())
            .id('category-editor-delete')
        }
      }.width('100%').padding({ left: 24, right: 24, top: 12, bottom: 28 })
    }.width('100%').scrollBar(BarState.Off).id('category-editor')
  }
}
