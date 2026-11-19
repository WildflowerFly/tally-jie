import { ManagementHeader } from '../components/ManagementHeader';
import { CategoryEditorSheet } from '../components/CategoryEditorSheet';
import { categoryIcon } from '../components/CategoryIcon';
import { AppState } from '../state/AppState';
import { Category, EntryType } from '../model/LedgerModels';
import { FinanceTheme } from '../theme/FinanceTheme';

@Component
export struct CategoryManagePage {
  @ObjectLink state: AppState;
  @State type: EntryType = 'expense';
  @State editingId: string = '';
  @State editorOpen: boolean = false;
  onBack: () => void = () => {};

  private sorted(): Category[] {
    return this.state.data.categories.filter((row) => row.type === this.type)
      .sort((a: Category, b: Category) => a.sortOrder - b.sortOrder || a.id.localeCompare(b.id));
  }
  private edit(id: string = ''): void {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    this.editingId = id; this.editorOpen = true;
  }
  @Builder
  editor() {
    CategoryEditorSheet({ state: this.state, categoryId: this.editingId, initialType: this.type,
      onCancel: () => { this.editorOpen = false; },
      onSaved: (type: EntryType) => { this.type = type; this.editorOpen = false; } })
  }
  @Builder
  typeTab(type: EntryType, label: string) {
    Button(label, { type: ButtonType.Normal }).height(40).layoutWeight(1).fontSize(15).borderRadius(12)
      .backgroundColor(this.type === type ? FinanceTheme.text : Color.Transparent)
      .fontColor(this.type === type ? '#FFFFFF' : FinanceTheme.muted)
      .onClick(() => { this.type = type; }).id(`category-tab-${type}`)
      .accessibilityDescription(this.type === type ? '已选中' : '未选中')
  }
  build() {
    Column({ space: 18 }) {
      ManagementHeader({ title: '分类管理', add: true, disabled: this.state.saving || this.state.status !== 'ready',
        onBack: () => this.onBack(), onAdd: () => this.edit() })
      Row({ space: 4 }) {
        this.typeTab('expense', '支出')
        this.typeTab('income', '收入')
      }.padding(4).width('100%').backgroundColor('#EAEAEA').borderRadius(16)
      if (this.sorted().length === 0) {
        Column({ space: 16 }) {
          Text('暂无分类').fontSize(15).fontColor(FinanceTheme.muted)
          Button('新增分类').fontSize(14).backgroundColor(FinanceTheme.text)
            .enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.edit())
        }.width('100%').padding(40).backgroundColor('#FFFFFF').borderRadius(22)
      } else {
        Column() {
          ForEach(this.sorted(), (row: Category, index: number) => {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 14 }) {
                Image(categoryIcon(row)).width(23).height(23).accessibilityLevel('no')
                Text(row.name).fontSize(16).fontColor(FinanceTheme.text).layoutWeight(1)
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Start)
                Text('编辑').fontSize(12).fontColor('#999999').accessibilityLevel('no')
              }.width('100%').constraintSize({ minHeight: 62 }).padding({ left: 18, right: 18, top: 8, bottom: 8 })
            }.width('100%').padding(0).borderRadius(0).backgroundColor('#FFFFFF')
              .id(`category-row-${row.id}`).accessibilityText(`编辑${row.name}`)
              .enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.edit(row.id))
            if (index < this.sorted().length - 1) {
              Divider().color('#F2F2F2').margin({ left: 55, right: 18 }).width('calc(100% - 73vp)')
            }
          }, (row: Category) => row.id)
        }.width('100%').backgroundColor('#FFFFFF').borderRadius(22).clip(true)
      }
    }.width('100%').id('finance-page-categories')
      .bindSheet($$this.editorOpen, this.editor(), {
        height: '80%', backgroundColor: '#FFFFFF', showClose: false,
        shouldDismiss: (sheet: SheetDismiss) => { if (!this.state.saving) { sheet.dismiss(); } }
      })
  }
}
