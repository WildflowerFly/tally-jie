import { money } from '../model/AppData';
import { cardToneColor } from '../domain/CardLayout';
import { ACCOUNT_CARD_FONT, registerAccountCardFont } from '../theme/AccountCardTheme';
import { AccountIcon } from './AccountIcon';

export interface AccountCardModel {
  id: string; name: string; englishName: string; iconKey: string; balanceCents: number;
}
@Component
export struct AccountCardFace {
  @Prop card: AccountCardModel = { id: '', name: '', englishName: '', iconKey: '', balanceCents: 0 };
  @Prop dark: boolean = false;
  @Prop tone: number = 0;
  @Prop nameId: string = '';
  aboutToAppear(): void { registerAccountCardFont(this.getUIContext()); }
  build() {
    Column() {
      Text(`¥${money(this.card.balanceCents)}`).fontFamily(ACCOUNT_CARD_FONT)
        .fontSize(this.dark ? 38 : 32).minFontSize(this.dark ? 18 : 16)
        .maxFontSize(this.dark ? 38 : 32).height(this.dark ? 62 : 52).maxLines(1).fontColor('#FFFFFF')
        .textOverflow({ overflow: TextOverflow.Ellipsis }).fontWeight(FontWeight.Medium)
        .id(this.nameId.replace('-name', '-balance'))
      Blank()
      Row({ space: 12 }) {
        Text(this.card.englishName).fontFamily(ACCOUNT_CARD_FONT).fontSize(this.dark ? 16 : 13)
          .minFontSize(this.dark ? 11 : 9).maxFontSize(this.dark ? 16 : 13)
          .height(this.dark ? 34 : 29).align(Alignment.Start)
          .fontColor('#F5F5F5').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1).id(this.nameId)
        AccountIcon({ iconKey: this.card.iconKey, iconSize: this.dark ? 34 : 29 })
      }.width('100%').alignItems(VerticalAlign.Center)
    }.alignItems(HorizontalAlign.Start)
      .padding({ left: this.dark ? 28 : 20, right: this.dark ? 52 : 56,
        top: this.dark ? 46 : 34, bottom: this.dark ? 28 : 26 })
      .width('100%').height('100%').borderRadius(22).clip(true)
      .linearGradient({ angle: 160, colors: [
        [cardToneColor(this.tone, false), 0], [cardToneColor(this.tone, true), 1]] })
  }
}
