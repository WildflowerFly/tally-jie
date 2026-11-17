import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { AppState } from '../state/AppState';
import { DateRange } from '../model/LedgerModels';
import { exportCsv, exportJson, previewCsv, previewJson, ImportPreview } from '../service/DataExchangeService';
import { FinanceTheme } from '../theme/FinanceTheme';
@Component
export struct DataExchangePage {
  @ObjectLink state: AppState;
  onBack: () => void = () => {};
  @State csv: boolean = false;
  @State start: string = '';
  @State end: string = '';
  @State message: string = '';
  @State preview: ImportPreview | null = null;
  @State busy: boolean = false;
  private previewRevision: number = -1;
  private async output(): Promise<void> {
    if (this.busy) { return; } this.busy = true;
    try {
      const range: DateRange | null = this.start || this.end ? { startDate: this.start, endDate: this.end } : null;
      if (!this.csv && range !== null) { throw new Error('JSON仅支持全量导出；范围导出请使用CSV'); }
      const text = this.csv ? exportCsv(this.state.data, range) : exportJson(this.state.data);
      const options = new picker.DocumentSaveOptions(); options.newFileNames = [`TallyJie-${Date.now()}.${this.csv ? 'csv' : 'json'}`];
      const uris = await new picker.DocumentViewPicker(this.getUIContext().getHostContext() as common.UIAbilityContext).save(options);
      if (uris.length === 0) { this.message = '已取消导出'; return; }
      const file = fs.openSync(uris[0], fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      try { fs.writeSync(file.fd, text); fs.fsyncSync(file.fd); } finally { fs.closeSync(file); }
      this.message = '导出成功';
    } catch (error) { this.message = (error as Error).message; } finally { this.busy = false; }
  }
  private async input(): Promise<void> {
    if (this.busy || this.state.status !== 'ready') { return; } this.busy = true; this.preview = null;
    try {
      const options = new picker.DocumentSelectOptions(); options.maxSelectNumber = 1; options.fileSuffixFilters = [this.csv ? '.csv' : '.json'];
      const uris = await new picker.DocumentViewPicker(this.getUIContext().getHostContext() as common.UIAbilityContext).select(options);
      if (uris.length === 0) { this.message = '已取消导入'; return; }
      const file = fs.openSync(uris[0], fs.OpenMode.READ_ONLY); let text = '';
      try {
        if (fs.statSync(file.fd).size > 8 * 1024 * 1024) { throw new Error('文件超过8MB限制'); }
        text = fs.readTextSync(uris[0]);
      } finally { fs.closeSync(file); }
      this.preview = this.csv ? previewCsv(this.state.data, text, new Date().toISOString()) : previewJson(this.state.data, text);
      this.previewRevision = this.state.revision; this.message = '已校验，尚未写入；请核对新增与重复数量。';
    } catch (error) { this.message = (error as Error).message; } finally { this.busy = false; }
  }
  private async apply(): Promise<void> {
    if (this.preview === null || this.busy || this.state.saving) { return; }
    if (this.previewRevision !== this.state.revision) { this.preview = null; this.message = '账本已变化，请重新预览'; return; }
    this.busy = true;
    try { if (await this.state.commit(this.preview.data)) { this.preview = null; this.message = '导入成功'; } }
    finally { this.busy = false; }
  }
  build() {
    Column({ space: 12 }) {
      Text('数据导入导出').fontSize(26).fontWeight(FontWeight.Bold)
      Text('CSV仅收支；JSON包含账户/分类/收支/转账/预算关联，不含旧图片字节，不是完整附件备份。跨设备缺附件时拒绝导入。').fontSize(13)
      Text('导入只合并不覆盖，同ID不同内容拒绝；CSV固定表头，账户/分类使用本账本ID，暂不支持第三方列映射。').fontSize(13)
      Select([{ value: 'JSON账本' }, { value: 'CSV收支' }]).onSelect((index: number) => { this.csv = index === 1; this.preview = null; })
      TextInput({ text: this.start, placeholder: 'CSV导出开始日期（可空）' }).onChange((value: string) => { this.start = value; })
      TextInput({ text: this.end, placeholder: 'CSV导出结束日期（可空）' }).onChange((value: string) => { this.end = value; })
      Button('选择位置并导出').enabled(!this.busy && this.state.status === 'ready').onClick(() => this.output())
      Button('选择文件并预览').enabled(!this.busy && !this.state.saving && this.state.status === 'ready').onClick(() => this.input())
      if (this.preview !== null) {
        Text(`新增 ${this.preview.added} 项；重复跳过 ${this.preview.duplicates} 项（含关联实体）`)
        Button('确认合并导入').enabled(!this.busy && !this.state.saving).onClick(() => this.apply())
        Button('取消预览').onClick(() => { this.preview = null; this.message = '已取消，账本未修改'; })
      }
      if (this.message) { Text(this.message).fontColor(FinanceTheme.muted) }
      Button('返回').onClick(() => this.onBack())
    }.width('100%')
  }
}
