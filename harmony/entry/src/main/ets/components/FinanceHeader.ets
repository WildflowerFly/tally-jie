import { FinanceTheme } from '../theme/FinanceTheme';

@Component
export struct FinanceHeader {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop back: boolean = false;
  onBack: () => void = () => {};
  build() {
    Row({ space: 12 }) {
      if (this.back) {
        Button('‹').width(44).height(44).fontSize(28).fontColor(FinanceTheme.text)
          .backgroundColor(FinanceTheme.card).accessibilityText('返回').onClick(() => this.onBack())
      }
      Column({ space: 4 }) {
        Text(this.subtitle).fontSize(12).fontColor(FinanceTheme.muted).letterSpacing(1)
        Text(this.title).fontSize(28).fontWeight(FontWeight.Bold).fontColor(FinanceTheme.text)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (!this.back) {
        Text('●').fontSize(14).fontColor(FinanceTheme.text).width(44).height(44)
          .textAlign(TextAlign.Center).backgroundColor(FinanceTheme.card).borderRadius(22)
          .accessibilityText('离线本地账本')
      }
    }.width('100%').padding({ top: 8, bottom: 12 })
  }
}

@Component
export struct FinanceMenuRow {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop glyph: string = '↗';
  onOpen: () => void = () => {};
  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Text(this.glyph).fontSize(20).fontColor(FinanceTheme.text).width(46).height(46)
          .textAlign(TextAlign.Center).backgroundColor(FinanceTheme.background).borderRadius(16)
        Column({ space: 5 }) {
          Text(this.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(FinanceTheme.text)
          Text(this.detail).fontSize(12).fontColor(FinanceTheme.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('›').fontSize(24).fontColor(FinanceTheme.muted)
      }.width('100%').padding(16)
    }.width('100%').backgroundColor(FinanceTheme.card).borderRadius(20).onClick(() => this.onOpen())
  }
}
