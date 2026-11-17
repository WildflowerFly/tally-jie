import { cardLayers, nextCard, CardLayer } from '../domain/CardLayout';
import { money } from '../model/AppData';
export interface AccountCardModel { id: string; name: string; credit: boolean; balanceCents: number; }
@Component
export struct AccountCardStack {
  @Prop cards: AccountCardModel[] = [];
  @Prop activeIndex: number = 0;
  @Prop dark: boolean = false;
  onSelect: (index: number) => void = () => {};
  onOpen: () => void = () => {};
  build() {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Center }) {
        ForEach(cardLayers(this.cards.length, this.activeIndex), (layer: CardLayer) => {
          Column({ space: 12 }) {
            Text(`¥${money(this.cards[layer.index].balanceCents)}`).fontSize(layer.depth === 0 ? 32 : 25)
              .fontWeight(FontWeight.Bold).fontColor('#FFFFFF').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Blank()
            Text(this.cards[layer.index].name).fontSize(19).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Row() {
              Text(this.cards[layer.index].credit ? '信用卡 · 本地账本' : '普通账户 · 本地账本').fontSize(12).fontColor('#D5D5D5')
              Blank()
              Circle({ width: 15, height: 15 }).fill('#E16C61')
              Circle({ width: 15, height: 15 }).fill('#D6BD8B').margin({ left: -5 })
            }.width('100%')
          }.alignItems(HorizontalAlign.Start).padding(24).width('82%').height(190).borderRadius(22)
            .linearGradient({ angle: 135, colors: [[layer.depth === 0 ? '#353535' : layer.depth === 1 ? '#686868' : '#A0A0A0', 0], [layer.depth === 0 ? '#101010' : '#777777', 1]] })
            .shadow({ radius: layer.depth === 0 ? 16 : 5, color: '#25000000', offsetY: 8 })
            .rotate({ angle: layer.angle, centerX: '80%', centerY: '80%' })
            .translate({ x: layer.shiftX, y: layer.shiftY })
            .accessibilityLevel(layer.depth === 0 ? 'yes' : 'no-hide-descendants')
            .accessibilityText(`${this.cards[layer.index].name}，余额${money(this.cards[layer.index].balanceCents)}元，点击查看账户详情`)
            .onClick(() => { if (layer.depth === 0) { this.onOpen(); } })
        }, (layer: CardLayer) => `${this.cards[layer.index].id}-${layer.depth}`)
      }.width('100%').height(295)
        .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 20 }).onActionEnd((event: GestureEvent) => {
          if (Math.abs(event.offsetX) >= 30) { this.onSelect(nextCard(this.cards.length, this.activeIndex, event.offsetX < 0 ? 1 : -1)); }
        }))
      Row({ space: 16 }) {
        Button('‹').accessibilityText('上一个账户').enabled(this.cards.length > 1)
          .backgroundColor(this.dark ? '#363636' : '#FFFFFF').fontColor(this.dark ? '#FFFFFF' : '#171717')
          .onClick(() => this.onSelect(nextCard(this.cards.length, this.activeIndex, -1)))
        Text(`${this.cards.length ? this.activeIndex + 1 : 0} / ${this.cards.length}`).fontColor(this.dark ? '#CCCCCC' : '#767676')
        Button('›').accessibilityText('下一个账户').enabled(this.cards.length > 1)
          .backgroundColor(this.dark ? '#363636' : '#FFFFFF').fontColor(this.dark ? '#FFFFFF' : '#171717')
          .onClick(() => this.onSelect(nextCard(this.cards.length, this.activeIndex, 1)))
      }
    }.width('100%')
  }
}
