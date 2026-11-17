import { AppState } from '../state/AppState';
import { FinanceTheme } from '../theme/FinanceTheme';

@Component
export struct RecordPage {
  @ObjectLink state: AppState;
  @Link amount: string;
  @Link note: string;
  onDirty: () => void = () => {};
  build() {
    Column({ space: 16 }) {
      Text('记一笔').fontSize(28).fontWeight(FontWeight.Bold).width('100%')
      Text('支出 / 收入').fontSize(16).fontColor(FinanceTheme.muted).width('100%')
      Column({ space: 16 }) {
        TextInput({ placeholder: '金额 0.00', text: this.amount })
          .id('record-amount').type(InputType.Normal).fontSize(30)
          .onChange((value: string) => { this.amount = value; this.onDirty(); })
        Text('账户与分类将在管理功能完成后接入').fontSize(14).fontColor(FinanceTheme.muted)
        TextInput({ placeholder: '备注（选填）', text: this.note })
          .onChange((value: string) => { this.note = value; this.onDirty(); })
        Button('保存（记账服务待接入）').width('100%').enabled(false)
          .backgroundColor(FinanceTheme.text).fontColor('#FFFFFF')
        Text('当前为页面骨架，不会保存未完成的表单。').fontSize(13).fontColor(FinanceTheme.muted)
      }.padding(20).backgroundColor(FinanceTheme.card).borderRadius(FinanceTheme.radius)
      if (this.state.status !== 'ready') {
        Text('账本尚未就绪，禁止写入').fontColor(FinanceTheme.expense).fontSize(14)
      }
    }.width('100%').id('finance-page-record')
  }
}
