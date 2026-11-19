import { curves, PathShape } from '@kit.ArkUI';
import { FINANCE_TABS, FINANCE_TAB_IDS } from '../theme/FinanceTheme';
import { makeNavOutline, makeNavCapsule, navContentInset, navTabCenter } from '../domain/NavGeometry';
import { displayAmount } from '../domain/AmountDisplay';

@Component
export struct FloatingNavBar {
  @Prop @Watch('moveNotch') selected: number = 2;
  onSelect: (index: number) => void = () => {};
  @Prop keypadProgress: number = 0;
  @Prop keypadOpen: boolean = false;
  @Prop amount: string = '';
  @Prop sheetProgress: number = 0;
  @Prop sheetOpen: boolean = false;
  @Prop sheetHeight: number = 360;
  @BuilderParam sheetContent: () => void = this.emptySheet;
  onKey: (key: string) => void = () => {};
  onClose: () => void = () => {};
  @State private barWidth: number = 0;
  @State private notchIndex: number = 2;
  private motionTimer: number = -1;

  aboutToAppear(): void { this.notchIndex = this.selected; }
  aboutToDisappear(): void { this.stopMotion(); }

  private stopMotion(): void {
    if (this.motionTimer !== -1) { clearInterval(this.motionTimer); this.motionTimer = -1; }
  }

  private moveNotch(): void {
    this.stopMotion();
    const start = this.notchIndex;
    const target = this.selected;
    const startedAt = Date.now();
    this.motionTimer = setInterval(() => {
      const t = Math.min(1, (Date.now() - startedAt) / 520);
      const progress = t === 1 ? 1 : 1 - Math.exp(-7 * t) * (1 + 7 * t);
      this.notchIndex = start + (target - start) * progress;
      if (t === 1) { this.stopMotion(); }
    }, 16);
  }
  private readonly icons: Resource[] = [
    $r('app.media.nav_statistics'), $r('app.media.nav_details'),
    $r('app.media.nav_add'), $r('app.media.nav_deposits'), $r('app.media.nav_profile')
  ];

  // The silhouette and selected button share the same continuous position.
  private center(): number {
    return navTabCenter(this.barWidth, this.notchIndex, FINANCE_TABS.length);
  }

  @Builder
  emptySheet() {}

  private expansion(): number { return Math.max(this.keypadProgress, this.sheetProgress); }
  private expandedHeight(): number { return this.sheetOpen || this.sheetProgress > 0 ? this.sheetHeight : 360; }
  private surfaceHeight(): number { return 88 + (this.expandedHeight() - 88) * this.expansion(); }

  private surfaceColor(): string {
    const channel = Math.round(23 + 232 * this.expansion());
    return `rgb(${channel}, ${channel}, ${channel})`;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Path()
        .commands(makeNavOutline(this.center(), this.barWidth, this.getUIContext().vp2px(1), this.expansion(), this.expandedHeight()))
        .fill(this.surfaceColor()).strokeWidth(0)
        .width('100%').height(this.surfaceHeight())
        .clipShape(new PathShape().commands(makeNavCapsule(this.barWidth,
          this.getUIContext().vp2px(1), this.expansion(), this.expandedHeight())))
        .accessibilityLevel('no')
      Row() {}
        .width(48).height(48).borderRadius(24).backgroundColor('#FFFFFF')
        .shadow({ radius: 8, color: '#18000000', offsetY: 3 })
        .position({ x: this.center() - 24, y: 4 })
        .opacity(1 - this.expansion())
        .accessibilityLevel('no')
      Row({ space: 0 }) {
        ForEach(FINANCE_TABS, (label: string, index: number) => {
          Button({ type: ButtonType.Normal, stateEffect: false }) {
            Image(this.icons[index])
              .width(index === 2 ? 28 : 24).height(index === 2 ? 28 : 24)
              .fillColor(this.selected === index ? '#171717' : '#BEBEBE')
              .translate({ y: this.selected === index ? -16 : 12 })
              .scale({ x: this.selected === index ? 1.08 : 1, y: this.selected === index ? 1.08 : 1 })
              .animation({ curve: curves.springMotion(0.42, 0.86) })
              .accessibilityLevel('no')
          }
          .id(`finance-nav-${FINANCE_TAB_IDS[index]}`)
          .accessibilityText(label)
          .accessibilityDescription(this.selected === index ? '已选中' : '未选中')
          .backgroundColor(Color.Transparent)
          .borderRadius(24).height(88).layoutWeight(1).padding(0)
          .onClick(() => this.onSelect(index))
        }, (label: string) => label)
      }.width('100%').height(88)
        .padding({ left: navContentInset(this.barWidth, FINANCE_TABS.length),
          right: navContentInset(this.barWidth, FINANCE_TABS.length) })
        .opacity(1 - Math.min(1, this.expansion() * 3))
        .enabled(!this.keypadOpen && !this.sheetOpen && this.expansion() === 0)
        .accessibilityLevel(this.expansion() > 0 ? 'no-hide-descendants' : 'auto')
      Column({ space: 8 }) {
        Row() {
          Column({ space: 2 }) {
            Text('输入金额').fontSize(11).fontColor('#888888')
            Text(`¥ ${displayAmount(this.amount)}`).fontSize(20).fontWeight(FontWeight.Normal)
              .fontColor('#171717').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('完成').height(36).fontSize(14).backgroundColor('#171717').fontColor('#FFFFFF')
            .onClick(() => this.onClose())
        }.width('100%').margin({ bottom: 4 })
        ForEach(['123', '456', '789', '.0←'], (keys: string) => {
          Row({ space: 8 }) {
            ForEach(keys.split(''), (key: string) => {
              Button(key, { type: ButtonType.Normal }).layoutWeight(1).height(58)
                .fontSize(25).fontColor('#171717').backgroundColor('#F3F3F3').borderRadius(14)
                .accessibilityText(key === '←' ? '删除一位' : key === '.' ? '小数点' : key)
                .onClick(() => this.onKey(key === '←' ? 'back' : key))
            }, (key: string) => key)
          }.width('100%')
        }, (keys: string) => keys)
      }.padding(20).width('100%').height(360)
        .opacity(Math.max(0, (this.keypadProgress - 0.35) / 0.65))
        .translate({ y: 20 * (1 - this.keypadProgress) })
        .visibility(this.keypadProgress > 0 ? Visibility.Visible : Visibility.Hidden)
        .enabled(this.keypadOpen && this.keypadProgress > 0.9)
      if (this.sheetOpen || this.sheetProgress > 0) {
        Column() { this.sheetContent() }.width('100%').height(this.sheetHeight)
          .opacity(Math.max(0, (this.sheetProgress - 0.25) / 0.75))
          .translate({ y: 24 * (1 - this.sheetProgress) })
          .enabled(this.sheetOpen && this.sheetProgress > 0.9)
      }
    }
    .width('100%').height(this.surfaceHeight()).clip(true)
    .id('finance-nav-surface')
    .onAreaChange((_old: Area, area: Area) => { this.barWidth = Number(area.width); })
  }
}
