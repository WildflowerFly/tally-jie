import { FinanceHeader } from '../components/FinanceHeader';
import { AppState } from '../state/AppState';
import { Category, EntryType } from '../model/LedgerModels';
import { CATEGORY_ICONS, categoryLabel, upsertCategory, removeCategory } from '../service/CategoryService';
import { newId } from '../model/AppData';
import { FinanceTheme } from '../theme/FinanceTheme';

@Component
export struct CategoryManagePage {
  @ObjectLink state: AppState;
  @State editingId: string = '';
  @State name: string = '';
  @State income: boolean = false;
  @State icon: string = 'category';
  @State order: string = '0';
  @State targetId: string = '';
  @State error: string = '';
  onBack: () => void = () => {};
  private sorted(): Category[] {
    return this.state.data.categories.slice().sort((a: Category, b: Category) =>
      a.type.localeCompare(b.type) || a.sortOrder - b.sortOrder || a.id.localeCompare(b.id));
  }
  private targets(): SelectOption[] {
    const result: SelectOption[] = [{ value: '不迁移，关联时拒删' }];
    this.sorted().forEach((row: Category) => { result.push({ value: `${row.type === 'income' ? '收入' : '支出'} · ${row.name}` }); });
    return result;
  }
  private edit(row: Category): void {
    this.editingId = row.id; this.name = row.name; this.income = row.type === 'income';
    this.icon = row.iconKey; this.order = row.sortOrder.toString(); this.error = '';
  }
  private clear(): void { this.editingId = ''; this.name = ''; this.order = '0'; this.icon = 'category'; this.error = ''; }
  private async save(): Promise<void> {
    if (this.state.saving) { return; }
    try {
      if (!/^\d+$/.test(this.order)) { throw new Error('排序请输入非负整数'); }
      const type: EntryType = this.income ? 'income' : 'expense';
      const next = upsertCategory(this.state.data, this.editingId || newId(), this.name, type, this.icon,
        Number(this.order), new Date().toISOString());
      if (await this.state.commit(next)) { this.clear(); }
    } catch (error) { this.error = (error as Error).message; }
  }
  private confirmDelete(row: Category): void {
    const entries = this.state.data.entries.filter((item) => item.categoryId === row.id).length;
    const budgets = this.state.data.budgets.filter((item) => item.categoryId === row.id).length;
    const target = this.state.data.categories.find((item) => item.id === this.targetId);
    this.getUIContext().showAlertDialog({ title: '确认删除分类？',
      message: `「${row.name}」关联${entries}笔账单、${budgets}条预算。` +
        (target === undefined ? '存在关联将拒删。' : `迁移至「${target.name}」；目标类型不符或预算重叠将拒绝整次操作。`),
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确认', action: () => { this.erase(row.id); } }
    });
  }
  private async erase(id: string): Promise<void> {
    try {
      if (await this.state.commit(removeCategory(this.state.data, id, this.targetId || null))) {
        if (this.editingId === id) { this.clear(); } this.error = '';
      }
    } catch (error) { this.error = (error as Error).message; }
  }
  build() {
    Column({ space: 14 }) {
      FinanceHeader({ title: '分类管理', subtitle: 'CATEGORIES · 整理收支习惯', back: true, onBack: () => this.onBack() })
      ForEach(this.sorted(), (row: Category) => {
        Column({ space: 8 }) {
          Row({ space: 12 }) {
            Text(categoryLabel(row.iconKey)).fontSize(20).width(44).height(44).textAlign(TextAlign.Center).backgroundColor('#F2F2F2').borderRadius(14)
            Column({ space: 4 }) {
              Text(row.name).fontSize(17).fontWeight(FontWeight.Bold)
              Text(`${row.type === 'income' ? '收入分类' : '支出分类'} · 排序 ${row.sortOrder}`).fontSize(12).fontColor(FinanceTheme.muted)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%')
          Row({ space: 12 }) {
            Button('编辑').backgroundColor(FinanceTheme.text).onClick(() => this.edit(row))
            Button('删除').backgroundColor('#F8EDEA').fontColor(FinanceTheme.expense).enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.confirmDelete(row))
          }
        }.padding(12).width('100%').backgroundColor('#FFFFFF').borderRadius(20)
      }, (row: Category) => row.id)
      Column({ space: 14 }) {
      Text(this.editingId ? '编辑分类' : '新建分类').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
      TextInput({ placeholder: '名称（最多30字）', text: this.name }).maxLength(30).onChange((value: string) => { this.name = value; })
      Toggle({ type: ToggleType.Checkbox, isOn: this.income }).onChange((value: boolean) => { this.income = value; })
      Text('勾选为收入，未勾选为支出').fontSize(13)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(CATEGORY_ICONS, (key: string) => {
          Button(categoryLabel(key)).fontSize(14).width(40).height(40).margin(3)
            .backgroundColor(this.icon === key ? '#171717' : '#767676').onClick(() => { this.icon = key; })
        }, (key: string) => key)
      }
      TextInput({ placeholder: '排序（非负整数）', text: this.order }).onChange((value: string) => { this.order = value; })
      if (this.error) { Text(this.error).fontColor(FinanceTheme.expense) }
      Button('保存分类').width('100%').height(50).backgroundColor(FinanceTheme.text).enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.save())
      if (this.editingId) { Button('取消编辑').backgroundColor('#EAEAEA').fontColor(FinanceTheme.text).onClick(() => this.clear()) }
      }.padding(20).width('100%').backgroundColor('#FFFFFF').borderRadius(24)
      Text('高级操作 · 删除时迁移历史（需同收支类型）').fontSize(12).fontColor(FinanceTheme.muted)
      Select(this.targets()).onSelect((index: number) => { this.targetId = index === 0 ? '' : this.sorted()[index - 1].id; })
    }.width('100%')
  }
}
