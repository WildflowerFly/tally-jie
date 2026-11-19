import { FinanceTheme } from '../theme/FinanceTheme';

// Short management-page title without a second line or marketing copy.
@Component
export struct ManagementHeader {
  @Prop title: string = '';
  @Prop add: boolean = false;
  @Prop disabled: boolean = false;
  onBack: () => void = () => {};
  onAdd: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Button('‹').width(40).height(40).padding(0).fontSize(28)
        .fontColor(FinanceTheme.text).backgroundColor(FinanceTheme.card)
        .accessibilityText('返回').enabled(!this.disabled).onClick(() => this.onBack())
      Text(this.title).fontSize(23).fontWeight(FontWeight.Medium).fontColor(FinanceTheme.text).layoutWeight(1)
      if (this.add) {
        Button('＋').width(40).height(40).padding(0).fontSize(26)
          .fontColor(FinanceTheme.text).backgroundColor(FinanceTheme.card)
          .accessibilityText('新增分类').id('category-add').enabled(!this.disabled).onClick(() => this.onAdd())
      }
    }.width('100%').padding({ top: 4, bottom: 8 })
  }
}
