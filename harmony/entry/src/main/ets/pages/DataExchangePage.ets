import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { ManagementHeader } from '../components/ManagementHeader';
import { AppState } from '../state/AppState';
import { DateRange } from '../model/LedgerModels';
import { exportCsv, exportJson, previewJson, ImportPreview } from '../service/DataExchangeService';
import { exportTables, previewTables, previewMappedCsv, CsvMapping, RowIssue } from '../service/ExchangeFormats';
import { encodePortable, previewPortable, PortableFile } from '../service/PortableBackup';
import { ExchangeFiles, sourceFingerprint } from '../service/ExchangeFiles';
import { decodeCsv } from '../domain/CsvCodec';
import { FinanceTheme } from '../theme/FinanceTheme';
@Component
export struct DataExchangePage {
  @ObjectLink state: AppState;
  onBack: () => void = () => {};
  @State mode: number = 0;
  @State start: string = '';
  @State end: string = '';
  @State message: string = '';
  @State preview: ImportPreview | null = null;
  @State busy: boolean = false;
  @State headers: string[] = [];
  @State mapping: string[] = ['id', 'type', 'amount', 'accountId', 'categoryId', 'date', 'time', 'note'];
  @State issues: RowIssue[] = [];
  @State issueOffset: number = 0;
  private raw: string = '';
  private previewRevision: number = -1;
  private fingerprint: string = '';
  private files: PortableFile[] = [];
  private clear(): void { this.preview = null; this.files = []; this.raw = ''; this.headers = []; this.issues = []; this.issueOffset = 0; }
  private adapter(): ExchangeFiles { return new ExchangeFiles(this.getUIContext().getHostContext() as common.UIAbilityContext); }
  private async read(uri: string): Promise<string> {
    const file = await fs.open(uri, fs.OpenMode.READ_ONLY);
    try {
      const size = (await fs.stat(file.fd)).size;
      const limit = (this.mode === 0 ? 64 : this.mode === 3 ? 8 : 16) * 1024 * 1024;
      if (size > limit) { throw new Error(`文件超过${limit / 1024 / 1024}MB限制`); }
      const decoder = new util.TextDecoder('utf-8', { fatal: true }); let text = ''; let offset = 0;
      while (offset < size) {
        const chunk = new ArrayBuffer(Math.min(65536, size - offset)); const count = await fs.read(file.fd, chunk);
        if (count <= 0) { throw new Error('UNEXPECTED_EOF'); }
        text += decoder.decodeWithStream(new Uint8Array(chunk, 0, count), { stream: true }); offset += count;
      }
      return text + decoder.decodeWithStream(new Uint8Array(0));
    } finally { await fs.close(file); }
  }
  private async output(): Promise<void> {
    if (this.busy || this.state.saving || this.state.status !== 'ready') { return; }
    this.busy = true; this.message = '';
    try {
      const range: DateRange | null = this.start || this.end ? { startDate: this.start, endDate: this.end } : null;
      if (this.mode !== 3 && range !== null) { throw new Error('日期范围仅用于CSV收支；备份及关联表必须全量以保持余额与引用完整'); }
      const text = this.mode === 0 ? encodePortable(this.state.data, await this.adapter().collect(this.state.data)) :
        this.mode === 1 ? exportJson(this.state.data) : this.mode === 2 ? exportTables(this.state.data) : exportCsv(this.state.data, range);
      const bytes = new util.TextEncoder().encodeInto(text);
      const byteLimit = (this.mode === 0 ? 64 : this.mode === 3 ? 8 : 16) * 1024 * 1024;
      if (bytes.length > byteLimit) { throw new Error('EXPORT_TOO_LARGE：请缩小收支范围或拆分附件归档'); }
      const options = new picker.DocumentSaveOptions(); options.newFileNames = [`TallyJie-${Date.now()}.${this.mode >= 2 ? 'csv' : 'json'}`];
      const uris = await new picker.DocumentViewPicker(this.getUIContext().getHostContext() as common.UIAbilityContext).save(options);
      if (!uris.length) { this.message = '已取消导出'; return; }
      const file = await fs.open(uris[0], fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      try {
        for (let offset = 0; offset < bytes.length; offset += 65536) {
          const chunk = bytes.slice(offset, Math.min(offset + 65536, bytes.length)); let written = 0;
          while (written < chunk.length) { const count = await fs.write(file.fd, chunk.slice(written).buffer); if (count <= 0) { throw new Error('SHORT_WRITE'); } written += count; }
        }
        await fs.fsync(file.fd);
      } catch (error) { this.message = '导出失败，目标文件可能不完整，请删除后重试'; throw error as Error; }
      finally { await fs.close(file); }
      this.message = '导出成功；请妥善保管含财务数据的文件';
    } catch (error) { this.message = `${this.message.startsWith('导出失败') ? this.message + '：' : ''}${(error as Error).message}`; }
    finally { this.busy = false; }
  }
  private mapped(): CsvMapping {
    return { id: this.mapping[0], type: this.mapping[1], amount: this.mapping[2], account: this.mapping[3], category: this.mapping[4], date: this.mapping[5], time: this.mapping[6], note: this.mapping[7] };
  }
  private async validate(): Promise<void> {
    this.preview = null; this.issues = []; this.issueOffset = 0; this.files = [];
    this.previewRevision = this.state.revision;
    if (this.mode === 0) { const result = previewPortable(this.state.data, this.raw); this.preview = result.preview; this.files = result.files; }
    else if (this.mode === 1) { this.preview = previewJson(this.state.data, this.raw); }
    else if (this.mode === 2) { this.preview = previewTables(this.state.data, this.raw); }
    else { const result = previewMappedCsv(this.state.data, this.raw, this.mapped(), new Date().toISOString()); this.preview = result.preview; this.issues = result.issues; }
    this.fingerprint = await sourceFingerprint(this.raw);
    if (await this.state.hasImportSource(this.fingerprint)) { this.preview = null; this.message = '该来源文件已成功导入，无需重复写入'; }
    else { this.message = this.issues.length ? `发现${this.issues.length}处错误，未写入任何数据；行号为CSV逻辑记录号。` : '预览完成，未写入；确认后原子合并，不覆盖现有记录。'; }
  }
  private async remap(): Promise<void> {
    if (this.busy || this.state.saving || this.state.status !== 'ready') { return; } this.busy = true;
    try { await this.validate(); } catch (error) { this.message = (error as Error).message; } finally { this.busy = false; }
  }
  private async input(): Promise<void> {
    if (this.busy || this.state.saving || this.state.status !== 'ready') { return; }
    this.busy = true; this.clear(); this.message = '';
    try {
      const options = new picker.DocumentSelectOptions(); options.maxSelectNumber = 1; options.fileSuffixFilters = [this.mode >= 2 ? '.csv' : '.json'];
      const uris = await new picker.DocumentViewPicker(this.getUIContext().getHostContext() as common.UIAbilityContext).select(options);
      if (!uris.length) { this.message = '已取消导入'; return; }
      this.raw = await this.read(uris[0]);
      if (this.mode === 3) {
        this.headers = decodeCsv(this.raw)[0] || [];
        if (!this.mapping.every((name: string) => this.headers.includes(name))) { this.message = '请选择每个字段对应列，再点击校验映射'; return; }
      }
      await this.validate();
    } catch (error) { this.preview = null; this.message = (error as Error).message; } finally { this.busy = false; }
  }
  private async apply(): Promise<void> {
    if (this.preview === null || this.busy || this.state.saving || this.state.status !== 'ready') { return; }
    if (this.previewRevision !== this.state.revision) { this.preview = null; this.message = '账本已变化，请重新预览'; return; }
    this.busy = true;
    try {
      await this.state.recoverExchange();
      if (await this.state.hasImportSource(this.fingerprint)) { this.clear(); this.message = '来源文件已导入'; return; }
      await this.adapter().stage(this.files, this.fingerprint);
      if (this.previewRevision !== this.state.revision) { this.preview = null; throw new Error('账本已变化，请重新预览'); }
      if (await this.state.commit(this.preview.data, this.fingerprint)) { this.clear(); this.message = '导入成功'; }
      else { this.message = this.state.message || '写入未完成'; }
    } catch (error) { this.message = (error as Error).message; }
    finally {
      try { await this.state.recoverExchange(); } catch (error) { this.message += `；恢复失败，请重启：${(error as Error).message}`; }
      this.busy = false;
    }
  }
  private headerOptions(): SelectOption[] { const options: SelectOption[] = []; this.headers.forEach((name: string) => { options.push({ value: name }); }); return options; }
  private formatOptions(): SelectOption[] {
    return [{ value: '完整备份 · JSON' }, { value: '账本数据 · JSON' },
      { value: '关联数据 · CSV' }, { value: '收支明细 · CSV' }];
  }
  private formatHint(): string {
    return ['含账本、附件与归档', '仅账本，不含附件文件', '全量关联表，不含附件文件', '收支明细，支持自定义列'][this.mode];
  }
  @Builder
  actionCard(icon: Resource, label: string, detail: string, id: string, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 10 }) {
        Image(icon).width(24).height(24).accessibilityLevel('no').margin({ bottom: 12 })
        Text(label).fontSize(18).fontWeight(FontWeight.Medium).fontColor(FinanceTheme.text)
        Text(detail).fontSize(12).fontColor(FinanceTheme.muted)
      }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
    }.layoutWeight(1).padding(0).borderRadius(22).backgroundColor('#FFFFFF')
      .enabled(!this.busy && !this.state.saving && this.state.status === 'ready')
      .onClick(action).id(id).accessibilityText(`${label}，${detail}`)
  }
  build() {
    Column({ space: 20 }) {
      ManagementHeader({ title: '数据与备份', disabled: this.busy || this.state.saving,
        onBack: () => this.onBack() })
      Row({ space: 12 }) {
        this.actionCard($r('app.media.exchange_export'), '导出文件', '选择保存位置', 'exchange-export', () => this.output())
        this.actionCard($r('app.media.deposit_receive'), '导入文件', '预览后再确认', 'exchange-import', () => this.input())
      }.width('100%')
      Column({ space: 12 }) {
        Row() {
          Text('文件格式').fontSize(14).fontColor(FinanceTheme.text).layoutWeight(1)
          Select(this.formatOptions()).selected(this.mode).value(this.formatOptions()[this.mode].value)
            .font({ size: 13 }).fontColor(FinanceTheme.text).backgroundColor('#F5F5F5')
            .enabled(!this.busy && !this.state.saving).id('exchange-format')
            .onSelect((index: number) => {
              this.mode = index; this.clear(); this.message = ''; this.start = ''; this.end = '';
            })
        }.width('100%')
        Text(this.formatHint()).fontSize(12).fontColor(FinanceTheme.muted).width('100%').id('exchange-format-hint')
        if (this.mode === 3) {
          Row({ space: 8 }) {
            TextInput({ text: this.start, placeholder: '开始日期（选填）' }).fontSize(12).layoutWeight(1)
              .enabled(!this.busy).onChange((value: string) => { this.start = value; }).id('exchange-start')
            TextInput({ text: this.end, placeholder: '结束日期（选填）' }).fontSize(12).layoutWeight(1)
              .enabled(!this.busy).onChange((value: string) => { this.end = value; }).id('exchange-end')
          }.width('100%')
          Text('日期格式 YYYY-MM-DD').fontSize(11).fontColor(FinanceTheme.muted).width('100%')
        }
      }.padding(20).width('100%').backgroundColor('#FFFFFF').borderRadius(22)
      if (this.mode === 3 && this.headers.length) {
        Column({ space: 12 }) {
          Text('匹配列名').fontSize(17).fontWeight(FontWeight.Medium).width('100%')
          Text('账户与分类需已存在').fontSize(12).fontColor(FinanceTheme.muted).width('100%')
          ForEach(['编号', '收支类型', '金额', '账户', '分类', '日期', '时间', '备注'], (label: string, index: number) => {
            Row() {
              Text(label).layoutWeight(1).fontSize(13)
              Select(this.headerOptions()).value(this.mapping[index]).enabled(!this.busy && !this.state.saving)
                .onSelect((column: number) => {
                  const next = this.mapping.slice(); next[index] = this.headers[column]; this.mapping = next; this.preview = null;
                })
            }.width('100%')
          }, (label: string) => label)
          Button('校验映射').width('100%').backgroundColor(FinanceTheme.text)
            .enabled(!this.busy && !this.state.saving).onClick(() => this.remap())
        }.padding(20).width('100%').backgroundColor('#FFFFFF').borderRadius(22)
      }
      if (this.issues.length) {
        Column({ space: 12 }) {
          Text(`发现 ${this.issues.length} 处问题，未导入`).fontSize(15).width('100%')
          ForEach(this.issues.slice(this.issueOffset, this.issueOffset + 50), (issue: RowIssue) => {
            Text(`${issue.line === 0 ? '整体账本' : '记录 ' + issue.line}：${issue.message}`)
              .fontColor(FinanceTheme.expense).fontSize(12).width('100%')
          }, (issue: RowIssue) => `${issue.line}-${issue.message}`)
          Row({ space: 12 }) {
            Button('上一页').backgroundColor('#EAEAEA').fontColor(FinanceTheme.text).enabled(this.issueOffset > 0)
              .onClick(() => { this.issueOffset = Math.max(0, this.issueOffset - 50); })
            Button('下一页').backgroundColor(FinanceTheme.text).enabled(this.issueOffset + 50 < this.issues.length)
              .onClick(() => { this.issueOffset += 50; })
          }
        }.padding(20).width('100%').backgroundColor('#FFFFFF').borderRadius(22)
      }
      if (this.preview !== null) {
        Column({ space: 16 }) {
          Text('导入预览').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
          Text(`新增 ${this.preview.added} 项 · 跳过重复 ${this.preview.duplicates} 项`).fontSize(14).width('100%')
          Text('合并到当前账本，不覆盖已有记录').fontSize(12).fontColor(FinanceTheme.muted).width('100%')
          Button('确认导入').width('100%').height(46).backgroundColor(FinanceTheme.text)
            .enabled(!this.busy && !this.state.saving).onClick(() => this.apply()).id('exchange-confirm-import')
          Button('取消').backgroundColor(Color.Transparent).fontColor(FinanceTheme.muted).enabled(!this.busy)
            .onClick(() => { this.clear(); this.message = '已取消，账本未修改'; })
        }.padding(20).width('100%').backgroundColor('#FFFFFF').borderRadius(22)
      }
      if (this.busy) { Text('处理中…').fontSize(13).fontColor(FinanceTheme.muted) }
      if (this.message) { Text(this.message).fontSize(13).fontColor(FinanceTheme.muted).width('100%') }
      Text('导入前预览，备份请妥善保管').fontSize(11).fontColor('#999999')
    }.width('100%').id('finance-page-exchange')
  }
}
