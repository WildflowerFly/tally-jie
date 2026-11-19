export interface AccountIconOption { key: string; label: string; image: Resource; }
export const ACCOUNT_ICONS: AccountIconOption[] = [
  { key: 'wechat', label: '微信', image: $r('app.media.account_wechat') },
  { key: 'alipay', label: '支付宝', image: $r('app.media.account_alipay') },
  { key: 'unionpay', label: '银联', image: $r('app.media.account_unionpay') },
  { key: 'quickpass', label: '云闪付', image: $r('app.media.account_quickpass') },
  { key: 'icbc', label: '工商银行', image: $r('app.media.account_icbc') },
  { key: 'abc', label: '农业银行', image: $r('app.media.account_abc') },
  { key: 'boc', label: '中国银行', image: $r('app.media.account_boc') },
  { key: 'ccb', label: '建设银行', image: $r('app.media.account_ccb') },
  { key: 'bocom', label: '交通银行', image: $r('app.media.account_bocom') },
  { key: 'psbc', label: '邮储银行', image: $r('app.media.account_psbc') },
  { key: 'cmb', label: '招商银行', image: $r('app.media.account_cmb') },
  { key: 'citic', label: '中信银行', image: $r('app.media.account_citic') },
  { key: 'pab', label: '平安银行', image: $r('app.media.account_pab') }
];
export function accountIconResource(key: string): Resource {
  return ACCOUNT_ICONS.find((option: AccountIconOption) => option.key === key)?.image ?? $r('app.media.record_account');
}
@Component
export struct AccountIcon {
  @Prop iconKey: string = '';
  @Prop iconSize: number = 32;
  build() {
    Image(accountIconResource(this.iconKey)).width(this.iconSize).height(this.iconSize).objectFit(ImageFit.Contain)
      .supportSvg2(true).borderRadius(4).accessibilityLevel('no')
  }
}
@Component
export struct AccountIconPicker {
  @Link iconKey: string;
  @Prop disabled: boolean = false;
  @Prop dark: boolean = true;
  build() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(ACCOUNT_ICONS, (option: AccountIconOption) => {
        Column({ space: 3 }) {
          Button() { AccountIcon({ iconKey: option.key, iconSize: 25 }) }
            .width('100%').height(40).padding(6).borderRadius(12)
            .backgroundColor(this.iconKey === option.key ? '#626262' : '#343434')
            .border({ width: this.iconKey === option.key ? 2 : 0, color: '#FFFFFF' })
            .enabled(!this.disabled).onClick(() => { this.iconKey = option.key; })
            .id(`deposit-icon-${option.key}`).accessibilityText(`${option.label}图标${this.iconKey === option.key ? '，已选择' : ''}`)
          Text(option.label).fontSize(10)
            .fontColor(this.dark ? (this.iconKey === option.key ? '#FFFFFF' : '#BDBDBD') : '#666666').maxLines(1)
        }.width('20%').padding({ left: 3, right: 3, bottom: 6 })
      }, (option: AccountIconOption) => option.key)
    }.width('100%')
  }
}
