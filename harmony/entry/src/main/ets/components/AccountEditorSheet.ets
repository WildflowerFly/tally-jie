import { window } from '@kit.ArkUI';
import { AppState } from '../state/AppState';
import { AccountType } from '../model/LedgerModels';
import { upsertAccount } from '../service/AccountService';
import { money, newId } from '../model/AppData';
import { accountIconEnglishName, accountIconKey } from '../domain/AccountAppearance';
import { AccountIconPicker } from './AccountIcon';

// Uses the same account validation and transactional persistence as account management.
@Component
export struct AccountEditorSheet {
  @ObjectLink state: AppState;
  @Prop accountId: string = '';
  @State name: string = '';
  @State initial: string = '';
  @State holder: string = '';
  @State iconKey: string = '';
  @State credit: boolean = false;
  @State error: string = '';
  @State deleteOptions: boolean = false;
  @State bottomInset: number = 0;
  @State targetId: string = '';
  @Prop deleteError: string = '';
  onSaved: (id: string) => void = () => {};
  onCancel: () => void = () => {};
  onDelete: (targetId: string) => void = () => {};

  private async measureBottomInset(): Promise<void> {
    const ui = this.getUIContext();
    const context = ui.getHostContext();
    if (!context) { return; }
    try {
      const main = await window.getLastWindow(context);
      const area = main.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.bottomInset = ui.px2vp(area.bottomRect.height);
    } catch (_) { /* A floating window may have no system gesture area. */ }
  }
  aboutToAppear(): void {
    this.measureBottomInset();
    const row = this.state.data.accounts.find((account) => account.id === this.accountId);
    this.name = row?.name || '';
    this.initial = row === undefined ? '' : money(row.initialBalanceCents);
    this.credit = row?.type === 'credit';
    this.holder = row?.holder || '';
    this.iconKey = row === undefined ? '' : accountIconKey(row);
    this.error = ''; this.deleteOptions = false; this.targetId = '';
  }
  private cardEnglishName(): string {
    return accountIconEnglishName(this.iconKey) ||
      this.state.data.accounts.find((account) => account.id === this.accountId)?.englishName || '';
  }
  private deletionTargets(): SelectOption[] {
    const result: SelectOption[] = [{ value: '不迁移' }];
    this.state.data.accounts.filter((row) => row.id !== this.accountId)
      .forEach((row) => { result.push({ value: row.name }); });
    return result;
  }
  private async save(): Promise<void> {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    this.error = '';
    if (this.accountId && !this.state.data.accounts.some((row) => row.id === this.accountId)) {
      this.error = '此账户已不存在，请关闭后重试。'; return;
    }
    try {
      const id = this.accountId || newId();
      const type: AccountType = this.credit ? 'credit' : 'standard';
      const next = upsertAccount(this.state.data, id, this.name, type, this.initial, new Date().toISOString(),
        { englishName: this.cardEnglishName(), holder: this.holder, iconKey: this.iconKey || undefined });
      if (await this.state.commit(next)) { this.onSaved(id); }
      else { this.error = this.state.message || '暂时无法保存，请稍后重试。'; }
    } catch (error) {
      const code = (error as Error).message;
      if (code === 'INVALID_ENTITY') { this.error = '请输入1–40字的账户名称，且不能与其他账户重名。'; }
      else if (code === 'NEGATIVE_BALANCE') { this.error = '普通账户余额不能为负，请检查初始余额或选择信用账户。'; }
      else if (code === 'INVALID_AMOUNT' || code === 'AMOUNT_OVERFLOW') { this.error = '请输入有效金额，最多保留两位小数。'; }
      else { this.error = code || '保存失败，请重试。'; }
    }
  }
  @Builder
  formFields() {
    Column({ space: 8 }) {
      Column({ space: 8 }) {
        Text('账户名称').fontSize(12).fontColor('#9B9B9B')
        TextInput({ placeholder: '请输入账户名称', text: this.name }).maxLength(40)
          .fontColor('#FFFFFF').placeholderColor('#808080').backgroundColor('#343434').borderRadius(12)
          .enabled(!this.state.saving).onChange((value: string) => { this.name = value; })
          .id('deposit-account-name').caretColor('#FFFFFF').selectedBackgroundColor('#666666')
      }.width('100%').alignItems(HorizontalAlign.Start)
      Text(this.cardEnglishName() || '选择账户类型后自动生成英文名称')
        .fontSize(15).minFontSize(11).maxFontSize(15).maxLines(1)
        .fontColor(this.cardEnglishName() ? '#FFFFFF' : '#808080')
        .width('100%').height(40).padding({ left: 16, right: 16 })
        .backgroundColor('#343434').borderRadius(12).id('deposit-account-english-name')
        .accessibilityText(`卡面英文名称，自动生成：${this.cardEnglishName() || '尚未选择账户类型'}`)
      TextInput({ placeholder: '账户持有者（选填，最多40字）', text: this.holder }).maxLength(40)
        .fontColor('#FFFFFF').placeholderColor('#808080').backgroundColor('#343434').borderRadius(12)
        .enabled(!this.state.saving).onChange((value: string) => { this.holder = value; })
        .id('deposit-account-holder').caretColor('#FFFFFF').selectedBackgroundColor('#666666')
        .accessibilityText('账户持有者')
      Column({ space: 8 }) {
        Text('账户类型').fontSize(12).fontColor('#9B9B9B')
        AccountIconPicker({ iconKey: $iconKey, disabled: this.state.saving })
      }.width('100%').alignItems(HorizontalAlign.Start)
      Column({ space: 8 }) {
        Text('初始余额（元）').fontSize(12).fontColor('#9B9B9B')
        TextInput({ placeholder: '留空为 0.00', text: this.initial })
          .fontColor('#FFFFFF').placeholderColor('#808080').backgroundColor('#343434').borderRadius(12)
          .enabled(!this.state.saving).onChange((value: string) => { this.initial = value; })
          .id('deposit-account-initial').caretColor('#FFFFFF').selectedBackgroundColor('#666666')
      }.width('100%').alignItems(HorizontalAlign.Start)
      Row({ space: 10 }) {
        Button('储蓄账户').layoutWeight(1).height(40).fontSize(14)
          .backgroundColor(this.credit ? '#343434' : '#F2F2F2').fontColor(this.credit ? '#CCCCCC' : '#181818')
          .enabled(!this.state.saving).onClick(() => { this.credit = false; })
        Button('信用账户').layoutWeight(1).height(40).fontSize(14)
          .backgroundColor(this.credit ? '#F2F2F2' : '#343434').fontColor(this.credit ? '#181818' : '#CCCCCC')
          .enabled(!this.state.saving).onClick(() => { this.credit = true; })
      }.width('100%')
      if (this.accountId) {
        Button('删除账户').width('100%').height(38).fontSize(13).fontColor('#BDBDBD')
          .backgroundColor(Color.Transparent).enabled(this.state.status === 'ready' && !this.state.saving)
          .onClick(() => { this.deleteOptions = !this.deleteOptions; }).id('deposit-account-delete')
        if (this.deleteOptions) {
          Row() {
            Text('历史记录迁移至').fontSize(12).fontColor('#BDBDBD')
            Blank()
            Select(this.deletionTargets())
              .selected(this.state.data.accounts.filter((row) => row.id !== this.accountId)
                .findIndex((row) => row.id === this.targetId) + 1)
              .value(this.state.data.accounts.find((row) => row.id === this.targetId)?.name || '不迁移')
              .font({ size: 13 }).fontColor('#FFFFFF').backgroundColor('#343434').enabled(!this.state.saving)
              .onSelect((index: number) => {
                this.targetId = index === 0 ? '' :
                  this.state.data.accounts.filter((row) => row.id !== this.accountId)[index - 1]?.id || '';
              })
          }.width('100%')
          if (this.deleteError) { Text(this.deleteError).fontSize(12).fontColor('#FFFFFF').width('100%') }
          Button('确认删除…').width('100%').height(40).backgroundColor('#343434').fontColor('#FFFFFF')
            .enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.onDelete(this.targetId))
        }
      }
    }.width('100%').padding({ top: 4, bottom: 8 })
  }
  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.accountId ? '编辑账户' : '新增账户').fontSize(21).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
        Blank()
        Button('取消').fontSize(14).fontColor('#BDBDBD').backgroundColor(Color.Transparent)
          .enabled(!this.state.saving).onClick(() => this.onCancel())
      }.width('100%')
      Scroll() { this.formFields() }
        .layoutWeight(1).width('100%').align(Alignment.Top).scrollBar(BarState.Auto).id('deposit-editor-scroll')
      if (this.error) { Text(this.error).fontSize(13).fontColor('#F2F2F2').width('100%') }
      Button(this.state.saving ? '保存中…' : '保存账户').width('100%').height(44)
        .backgroundColor('#F2F2F2').fontColor('#181818').fontSize(15)
        .enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.save())
        .id('deposit-account-save')
    }.width('100%').height('100%').padding({ left: 24, right: 24, top: 8, bottom: this.bottomInset + 12 }).backgroundColor('#242424')
  }
}
