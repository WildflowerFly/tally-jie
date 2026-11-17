import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
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
    if (this.busy) { return; } this.busy = true;
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
    if (this.busy) { return; } this.busy = true;
    try { await this.validate(); } catch (error) { this.message = (error as Error).message; } finally { this.busy = false; }
  }
  private async input(): Promise<void> {
    if (this.busy || this.state.status !== 'ready') { return; } this.busy = true; this.clear();
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
    if (this.preview === null || this.busy || this.state.saving) { return; }
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
  build() {
    Column({ space: 12 }) {
      Text('数据导入导出').fontSize(26).fontWeight(FontWeight.Bold)
      Text('完整备份含账户/分类/收支/转账/预算、附件及旧日记归档。归档只保存，不恢复日记页面。导入前校验，失败不合并；已有ID异内容及同路径异字节拒绝覆盖。').fontSize(13)
      Select([{ value: '完整可移植备份 JSON' }, { value: '账本元数据 JSON' }, { value: '全实体关联表 CSV' }, { value: '收支 CSV / 自定义列映射' }])
        .enabled(!this.busy).onSelect((index: number) => { this.mode = index; this.clear(); })
      TextInput({ text: this.start, placeholder: '收支CSV导出开始日期（可空）' }).enabled(!this.busy).onChange((value: string) => { this.start = value; })
      TextInput({ text: this.end, placeholder: '收支CSV导出结束日期（可空）' }).enabled(!this.busy).onChange((value: string) => { this.end = value; })
      Button('选择位置并导出').enabled(!this.busy && this.state.status === 'ready').onClick(() => this.output())
      Button('选择文件并预览').enabled(!this.busy && !this.state.saving && this.state.status === 'ready').onClick(() => this.input())
      if (this.mode === 3 && this.headers.length) {
        Text('账户/分类支持已有ID或唯一名称；不自动创建。同ID同业务内容跳过。').fontSize(12)
        ForEach(['编号ID', '类型（income/expense或收入/支出）', '金额', '账户', '分类', '日期', '时间', '备注'], (label: string, index: number) => {
          Row() {
            Text(label).layoutWeight(1).fontSize(12)
            Select(this.headerOptions()).value(this.mapping[index]).enabled(!this.busy)
              .onSelect((column: number) => { const next = this.mapping.slice(); next[index] = this.headers[column]; this.mapping = next; this.preview = null; })
          }.width('100%')
        }, (label: string) => label)
        Button('校验映射').enabled(!this.busy).onClick(() => this.remap())
      }
      if (this.issues.length) {
        ForEach(this.issues.slice(this.issueOffset, this.issueOffset + 50), (issue: RowIssue) => {
          Text(`${issue.line === 0 ? '整体账本' : '记录 ' + issue.line}：${issue.message}`).fontColor(FinanceTheme.expense).fontSize(12)
        }, (issue: RowIssue) => `${issue.line}-${issue.message}`)
        Button('下一页错误').enabled(this.issueOffset + 50 < this.issues.length).onClick(() => { this.issueOffset += 50; })
        Button('重看错误').onClick(() => { this.issueOffset = 0; })
      }
      if (this.preview !== null) {
        Text(`新增 ${this.preview.added} 项；重复跳过 ${this.preview.duplicates} 项（含关联实体）`)
        Button('确认合并导入').enabled(!this.busy && !this.state.saving).onClick(() => this.apply())
        Button('取消预览').enabled(!this.busy).onClick(() => { this.clear(); this.message = '已取消，账本未修改'; })
      }
      if (this.busy) { Text('处理中，请勿退出…').fontColor(FinanceTheme.muted) }
      if (this.message) { Text(this.message).fontColor(FinanceTheme.muted) }
      Button('返回').enabled(!this.busy).onClick(() => this.onBack())
    }.width('100%')
  }
}
