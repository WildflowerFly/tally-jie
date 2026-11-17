import { FinanceTheme, FINANCE_TABS, FINANCE_TAB_IDS } from '../theme/FinanceTheme';

@Component
export struct FloatingNavBar {
  @Prop selected: number = 2;
  onSelect: (index: number) => void = () => {};
  build() {
    Row({ space: 0 }) {
      ForEach(FINANCE_TABS, (label: string, index: number) => {
        Button(label)
          .id(`finance-nav-${FINANCE_TAB_IDS[index]}`)
          .accessibilityText(label)
          .fontSize(14).fontWeight(this.selected === index ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.selected === index ? FinanceTheme.text : '#C8C8C8')
          .backgroundColor(this.selected === index ? '#FFFFFF' : '#171717')
          .borderRadius(20).height(44).layoutWeight(1)
          .onClick(() => this.onSelect(index))
      }, (label: string) => label)
    }
    .padding(8).width('100%').backgroundColor(FinanceTheme.text).borderRadius(30)
  }
}
