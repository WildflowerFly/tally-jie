import { FinanceTheme } from '../theme/FinanceTheme';

@Component
export struct RecordChip {
  @Prop label: string = '';
  @Prop icon: Resource = $r('app.media.record_category');
  // A reactive prop keeps both foregrounds in sync with the button background.
  // A boolean passed to a value-parameter @Builder can retain its initial value.
  @Prop selected: boolean = false;
  @Prop providerMark: boolean = false;
  onSelect: () => void = () => {};

  // Preserve SVG transparency and stroke geometry; fillColor would fill the outlines.
  private readonly selectedIconFilter: ColorFilter = new ColorFilter([
    0, 0, 0, 0, 255,
    0, 0, 0, 0, 255,
    0, 0, 0, 0, 255,
    0, 0, 0, 1, 0
  ]);
  private readonly normalIconFilter: ColorFilter = new ColorFilter([
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0
  ]);

  // Tint the colored ink only. White lettering (e.g. UnionPay) becomes a cutout
  // instead of merging with the plate when the mark is rendered in one color.
  private providerTint(tone: number): ColorFilter {
    return new ColorFilter([0, 0, 0, 0, tone, 0, 0, 0, 0, tone, 0, 0, 0, 0, tone, -1, -1, -1, 3, 0]);
  }
  private readonly providerGray: ColorFilter = this.providerTint(0.4); // #666666; ArkUI offsets are normalized.
  private readonly providerWhite: ColorFilter = this.providerTint(1);

  build() {
    Button({ type: ButtonType.Capsule }) {
      Row({ space: 4 }) {
        Image(this.icon).width(15).height(15).flexShrink(0)
          .supportSvg2(true)
          .colorFilter(this.providerMark ? (this.selected ? this.providerWhite : this.providerGray) :
            (this.selected ? this.selectedIconFilter : this.normalIconFilter))
          .accessibilityLevel('no')
        // Keep the full name: normal four-character labels fit on one line;
        // longer custom names wrap instead of being replaced by an ellipsis.
        Text(this.label).fontSize(12).fontWeight(FontWeight.Normal)
          .wordBreak(WordBreak.BREAK_ALL).flexShrink(1).textAlign(TextAlign.Center)
          .fontColor(this.selected ? '#FFFFFF' : '#555555')
      }.width('100%').justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
        .padding({ left: 4, right: 4, top: 7, bottom: 7 })
    }.padding(0).width('100%').borderRadius(12)
      .backgroundColor(this.selected ? FinanceTheme.text : '#EAEAEA')
      .accessibilityText(this.label).accessibilityDescription(this.selected ? '已选中' : '未选中')
      .onClick(() => this.onSelect())
  }
}
