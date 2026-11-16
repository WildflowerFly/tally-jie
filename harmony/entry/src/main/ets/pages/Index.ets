import { common } from '@kit.AbilityKit';
import { DataStore } from '../service/DataStore';
import { ACCOUNTS, AppData, Budget, CategoryTotal, Diary, EXPENSE_CATEGORIES, INCOME_CATEGORIES, MOODS,
  PALETTES, Palette, Transaction, WEATHERS, categoryTotals, dateKey, emptyData, money, monthlyTotal, newId, pad,
  toCents, validDate } from '../model/AppData';

@Entry
@Component
struct Index {
  @State private data: AppData = emptyData();
  @State private tab: number = 0;
  @State private month: string = dateKey().slice(0, 7);
  @State private selectedDate: string = dateKey();
  @State private search: string = '';
  @State private filterType: string = 'all';
  @State private filterAccount: string = '全部账户';
  @State private filterCategory: string = '全部分类';
  @State private statsType: string = 'expense';
  @State private editor: string = '';
  @State private editingId: string = '';
  @State private entryType: string = 'expense';
  @State private amount: string = '';
  @State private category: string = '餐饮';
  @State private account: string = '微信';
  @State private note: string = '';
  @State private formDate: string = dateKey();
  @State private formTime: string = '12:00';
  @State private mood: string = MOODS[0];
  @State private weather: string = WEATHERS[0];
  @State private location: string = '';
  @State private images: string[] = [];
  @State private preview: string = '';
  @State private busy: boolean = false;
  @State private ready: boolean = false;
  @State private loadError: string = '';
  private store?: DataStore;

  aboutToAppear(): void {
    try {
      this.getUIContext().getFont().registerFont({ familyName: 'MaShanZheng', familySrc: $rawfile('MaShanZheng-Regular.ttf') });
      this.getUIContext().getFont().registerFont({ familyName: 'ZCOOLXiaoWei', familySrc: $rawfile('ZCOOLXiaoWei-Regular.ttf') });
      this.getUIContext().getFont().registerFont({ familyName: 'NotoSansSC', familySrc: $rawfile('NotoSansSC-wght.ttf') });
      this.store = new DataStore(this.getUIContext().getHostContext() as common.UIAbilityContext);
      this.data = this.store.load();
      this.ready = true;
    } catch (error) {
      this.loadError = `本地数据读取失败，已停止写入以保护原数据：${(error as Error).message}`;
    }
  }

  private color(): string { return PALETTES[this.data.settings.theme].accent; }
  private ink(): string { return PALETTES[this.data.settings.theme].text; }
  private muted(): string { return PALETTES[this.data.settings.theme].secondary; }
  private bg(): string { return PALETTES[this.data.settings.theme].background; }
  private scaledSize(base: number): number { return base * [0.9, 1, 1.12, 1.25][this.data.settings.fontSize]; }
  private family(): string { return ['sans-serif', 'MaShanZheng', 'ZCOOLXiaoWei', 'NotoSansSC'][this.data.settings.font]; }
  private toast(message: string): void { this.getUIContext().getPromptAction().showToast({ message: message }); }
  private copy(): AppData { return JSON.parse(JSON.stringify(this.data)) as AppData; }
  private commit(next: AppData): boolean {
    if (!this.ready || !this.store) return false;
    try {
      this.store.save(next);
      this.data = next;
      return true;
    } catch (error) {
      this.toast(`保存失败：${(error as Error).message}`);
      return false;
    }
  }

  private moveMonth(delta: number): void {
    const date = new Date(`${this.month}-01T12:00:00`);
    date.setMonth(date.getMonth() + delta);
    this.month = dateKey(date).slice(0, 7);
    this.selectedDate = `${this.month}-01`;
  }

  private expense(): number { return monthlyTotal(this.data, this.month, 'expense'); }
  private income(): number { return monthlyTotal(this.data, this.month, 'income'); }
  private budget(): number { return this.data.budgets.find((b: Budget) => b.month === this.month)?.amount ?? 0; }
  private rows(): Transaction[] {
    const query = this.search.trim().toLowerCase();
    return this.data.transactions.filter((t: Transaction) => t.date.startsWith(this.month) &&
      (this.filterType === 'all' || t.type === this.filterType) &&
      (this.filterAccount === '全部账户' || t.account === this.filterAccount) &&
      (this.filterCategory === '全部分类' || t.category === this.filterCategory) &&
      (!query || `${t.note} ${t.category} ${t.account} ${money(t.amount)}`.toLowerCase().includes(query)))
      .sort((a: Transaction, b: Transaction) => `${b.date} ${b.time}`.localeCompare(`${a.date} ${a.time}`));
  }
  private diaries(): Diary[] {
    return this.data.diaries.filter((d: Diary) => d.date === this.selectedDate).slice().reverse();
  }
  private categories(): CategoryTotal[] {
    return categoryTotals(this.data.transactions.filter((t: Transaction) => t.date.startsWith(this.month) && t.type === this.statsType));
  }
  private trendMonths(): string[] {
    const result: string[] = [];
    for (let offset = -5; offset <= 0; offset++) {
      const date = new Date(`${this.month}-01T12:00:00`);
      date.setMonth(date.getMonth() + offset);
      result.push(dateKey(date).slice(0, 7));
    }
    return result;
  }
  private trendMax(): number {
    return Math.max(1, ...this.trendMonths().map(m => Math.max(monthlyTotal(this.data, m, 'expense'), monthlyTotal(this.data, m, 'income'))));
  }
  private days(): string[] {
    const first = new Date(`${this.month}-01T12:00:00`);
    const count = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
    const result: string[] = [];
    for (let i = 0; i < first.getDay(); i++) result.push('');
    for (let i = 1; i <= count; i++) result.push(`${this.month}-${pad(i)}`);
    return result;
  }
  private hasDiary(date: string): boolean { return this.data.diaries.some((d: Diary) => d.date === date); }

  private openTransaction(t?: Transaction): void {
    this.editingId = t?.id ?? '';
    this.entryType = t?.type ?? 'expense';
    this.amount = t ? money(t.amount) : '';
    this.category = t?.category ?? '餐饮';
    this.account = t?.account ?? '微信';
    this.note = t?.note ?? '';
    this.formDate = t?.date ?? (this.month === dateKey().slice(0, 7) ? dateKey() : `${this.month}-01`);
    const now = new Date();
    this.formTime = t?.time ?? `${pad(now.getHours())}:${pad(now.getMinutes())}`;
    this.images = t ? t.images.slice() : [];
    this.editor = 'transaction';
  }
  private openDiary(d?: Diary): void {
    this.editingId = d?.id ?? '';
    this.note = d?.content ?? '';
    this.formDate = d?.date ?? this.selectedDate;
    this.mood = d?.mood ?? MOODS[0];
    this.weather = d?.weather ?? WEATHERS[0];
    this.location = d?.location ?? '';
    this.images = d ? d.images.slice() : [];
    this.editor = 'diary';
  }
  private openBudget(): void {
    this.amount = this.budget() ? money(this.budget()) : '';
    this.editor = 'budget';
  }
  private saveEditor(): void {
    try {
      const next = this.copy();
      if (this.editor === 'budget') {
        next.budgets = next.budgets.filter((b: Budget) => b.month !== this.month);
        if (this.amount.trim()) next.budgets.push({ month: this.month, amount: toCents(this.amount.trim()) });
      } else {
        if (!validDate(this.formDate)) throw new Error('请输入有效日期，例如 2026-11-16');
        if (this.editor === 'transaction') {
          if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(this.formTime)) throw new Error('请输入有效时间，例如 09:30');
          const t: Transaction = { id: this.editingId || newId(), type: this.entryType, amount: toCents(this.amount.trim()),
            category: this.category, account: this.account, note: this.note.trim(), date: this.formDate, time: this.formTime, images: this.images.slice() };
          const index = next.transactions.findIndex((item: Transaction) => item.id === t.id);
          if (index < 0) next.transactions.push(t); else next.transactions[index] = t;
        } else {
          if (!this.note.trim()) throw new Error('写点什么再保存吧');
          const d: Diary = { id: this.editingId || newId(), date: this.formDate, content: this.note.trim(),
            mood: this.mood, weather: this.weather, location: this.location.trim(), images: this.images.slice() };
          const index = next.diaries.findIndex((item: Diary) => item.id === d.id);
          if (index < 0) next.diaries.push(d); else next.diaries[index] = d;
        }
      }
      if (this.commit(next)) {
        const savedType = this.editor;
        this.editor = '';
        if (savedType !== 'budget') {
          this.month = this.formDate.slice(0, 7);
          this.selectedDate = this.formDate;
        }
        this.toast(this.budget() && this.expense() > this.budget() ? `已保存，本月已超预算 ¥${money(this.expense() - this.budget())}` : '已保存');
      }
    } catch (error) { this.toast((error as Error).message); }
  }
  private deleteEntry(): void {
    this.getUIContext().showAlertDialog({ title: '确认删除？', message: '删除后无法撤销。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '删除', fontColor: '#D27165', action: () => {
        const next = this.copy();
        if (this.editor === 'transaction') next.transactions = next.transactions.filter(t => t.id !== this.editingId);
        else next.diaries = next.diaries.filter(d => d.id !== this.editingId);
        if (this.commit(next)) { this.editor = ''; this.toast('已删除'); }
      } } });
  }
  private closeEditor(): void {
    this.getUIContext().showAlertDialog({ title: '放弃本次编辑？', message: '尚未保存的修改将丢失。',
      primaryButton: { value: '继续编辑', action: () => {} },
      secondaryButton: { value: '放弃', action: () => { this.editor = ''; } } });
  }
  private async addImages(): Promise<void> {
    this.busy = true;
    try { this.images = this.images.concat(await this.store!.pickImages(9 - this.images.length)); }
    catch (error) { this.toast(`图片选择失败：${(error as Error).message}`); }
    finally { this.busy = false; }
  }
  private async exportData(): Promise<void> {
    this.busy = true;
    try { if (await this.store!.exportBackup(this.data)) this.toast('备份已导出，包含全部数据和图片'); }
    catch (error) { this.toast(`导出失败：${(error as Error).message}`); }
    finally { this.busy = false; }
  }
  private confirmImport(): void {
    this.getUIContext().showAlertDialog({ title: '恢复备份会替换全部本地数据', message: '请先导出当前数据。仅支持鸿蒙版 JSON 备份，包含图片。确定继续？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '选择备份', action: () => { this.importData(); } } });
  }
  private async importData(): Promise<void> {
    this.busy = true;
    try {
      const next = await this.store!.importBackup();
      if (next) { this.data = next; this.toast('恢复成功'); }
    } catch (error) { this.toast(`恢复失败，原数据未替换：${(error as Error).message}`); }
    finally { this.busy = false; }
  }
  private setTheme(index: number): void { const next = this.copy(); next.settings.theme = index; this.commit(next); }
  private setFontSize(index: number): void { const next = this.copy(); next.settings.fontSize = index; this.commit(next); }
  private setFont(index: number): void { const next = this.copy(); next.settings.font = index; this.commit(next); }

  onBackPress(): boolean {
    if (this.busy) return true;
    if (this.preview) { this.preview = ''; return true; }
    if (this.editor) { this.closeEditor(); return true; }
    return false;
  }

  @Builder
  private heading(title: string, subtitle: string) {
    Column({ space: 6 }) {
      Text(title).fontSize(this.scaledSize(30)).fontWeight(FontWeight.Bold).fontColor(this.ink()).fontFamily(this.family())
      Text(subtitle).fontSize(this.scaledSize(12)).fontColor(this.muted())
    }.alignItems(HorizontalAlign.Start).width('100%').padding({ top: 12, bottom: 20 })
  }

  @Builder
  private monthPicker() {
    Row() {
      Button('‹').onClick(() => this.moveMonth(-1)).backgroundColor(Color.Transparent).fontColor(this.ink()).fontSize(26)
      Text(`${this.month.slice(0, 4)} 年 ${Number(this.month.slice(5))} 月`).fontSize(this.scaledSize(18)).fontColor(this.ink()).layoutWeight(1).textAlign(TextAlign.Center)
      Button('›').onClick(() => this.moveMonth(1)).backgroundColor(Color.Transparent).fontColor(this.ink()).fontSize(26)
    }.width('100%').padding(4).backgroundColor('#FFFFFF').borderRadius(18).margin({ bottom: 16 })
  }

  @Builder
  private empty(title: string, subtitle: string) {
    Column({ space: 12 }) {
      Text('✧').fontSize(40).fontColor(this.color())
      Text(title).fontSize(this.scaledSize(17)).fontColor(this.ink())
      Text(subtitle).fontSize(this.scaledSize(13)).fontColor(this.muted()).textAlign(TextAlign.Center)
    }.width('100%').padding(32).backgroundColor('#FFFFFF').borderRadius(20)
  }

  @Builder
  private summary() {
    Column({ space: 18 }) {
      Text('把日子过成喜欢的样子').fontSize(this.scaledSize(13)).fontColor(this.muted())
      Text(`¥ ${money(this.income() - this.expense())}`).fontSize(this.scaledSize(32)).fontWeight(FontWeight.Medium).fontColor(this.ink())
      Text('本月结余').fontSize(this.scaledSize(12)).fontColor(this.muted())
      Row() {
        Column({ space: 6 }) {
          Text('收入').fontColor(this.muted()).fontSize(this.scaledSize(12))
          Text(`+ ${money(this.income())}`).fontColor('#5D7A6B').fontSize(this.scaledSize(18))
        }.layoutWeight(1)
        Column({ space: 6 }) {
          Text('支出').fontColor(this.muted()).fontSize(this.scaledSize(12))
          Text(`− ${money(this.expense())}`).fontColor('#D27165').fontSize(this.scaledSize(18))
        }.layoutWeight(1)
      }.width('100%')
    }.width('100%').padding(24).backgroundColor('#FFFFFF').borderRadius(24).margin({ bottom: 16 })
  }

  @Builder
  private budgetCard() {
    Column({ space: 10 }) {
      Row() {
        Text('月度预算').fontColor(this.ink()).fontSize(this.scaledSize(15)).layoutWeight(1)
        Text(this.budget() ? `¥ ${money(this.budget())}  ›` : '设置预算  ›').fontColor(this.color()).fontSize(this.scaledSize(13))
      }
      if (this.budget()) {
        Progress({ value: Math.min(100, this.expense() / this.budget() * 100), total: 100, type: ProgressType.Linear }).color(this.expense() > this.budget() ? '#D27165' : this.color())
        Text(this.expense() > this.budget() ? `已超支 ¥ ${money(this.expense() - this.budget())}` : `还可支出 ¥ ${money(this.budget() - this.expense())}`)
          .fontColor(this.expense() > this.budget() ? '#D27165' : this.muted()).fontSize(this.scaledSize(12))
      } else {
        Text('给每一份花销，一点温柔的计划').fontSize(this.scaledSize(12)).fontColor(this.muted())
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(18).backgroundColor('#FFFFFF').borderRadius(20)
      .margin({ bottom: 16 }).onClick(() => this.openBudget())
  }

  @Builder
  private transactionRow(t: Transaction) {
    Row({ space: 12 }) {
      Text(t.category.slice(0, 1)).fontSize(this.scaledSize(18)).fontColor(this.color()).width(44).height(44)
        .textAlign(TextAlign.Center).backgroundColor(this.bg()).borderRadius(14)
      Column({ space: 5 }) {
        Text(t.note || t.category).fontSize(this.scaledSize(15)).fontColor(this.ink()).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${t.category} · ${t.account}${t.images.length ? ` · ${t.images.length} 张凭证` : ''}`).fontSize(this.scaledSize(11)).fontColor(this.muted())
        Text(`${t.date} ${t.time}`).fontSize(this.scaledSize(11)).fontColor(this.muted())
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(`${t.type === 'income' ? '+' : '−'}${money(t.amount)}`).fontSize(this.scaledSize(17))
        .fontColor(t.type === 'income' ? '#5D7A6B' : '#D27165')
    }.width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(18).margin({ bottom: 8 }).onClick(() => this.openTransaction(t))
  }

  @Builder
  private ledgerPage() {
    this.heading('一笔一记', '认真生活，也好好照顾自己的钱包')
    this.monthPicker()
    this.summary()
    this.budgetCard()
    Button('＋ 记一笔').width('100%').height(48).backgroundColor(this.color()).fontColor('#FFFFFF').margin({ bottom: 20 }).onClick(() => this.openTransaction())
    this.filters()
    Text(`账单明细 · ${this.rows().length} 笔`).fontSize(this.scaledSize(16)).fontColor(this.ink()).width('100%').margin({ top: 14, bottom: 12 })
    if (!this.rows().length) {
      this.empty('这里还没有账单', '记下第一笔收支，或者调整筛选条件')
    } else {
      ForEach(this.rows(), (t: Transaction) => { this.transactionRow(t) }, (t: Transaction) => t.id)
    }
  }

  @Builder
  private filters() {
    Search({ value: this.search, placeholder: '搜索备注、分类、账户或金额' }).backgroundColor('#FFFFFF').onChange(value => { this.search = value; })
    Row({ space: 8 }) {
      Select([{ value: '全部收支' }, { value: '支出' }, { value: '收入' }]).value(this.filterType === 'all' ? '全部收支' : this.filterType === 'expense' ? '支出' : '收入')
        .font({ size: this.scaledSize(12) }).layoutWeight(1).onSelect(index => { this.filterType = ['all', 'expense', 'income'][index]; })
      Select(['全部账户'].concat(ACCOUNTS).map((v: string): SelectOption => { return { value: v }; })).value(this.filterAccount)
        .font({ size: this.scaledSize(12) }).layoutWeight(1).onSelect((index, value) => { this.filterAccount = value; })
    }.width('100%').margin({ top: 8 })
    Select(['全部分类'].concat(EXPENSE_CATEGORIES, INCOME_CATEGORIES.filter(v => v !== '其他')).map((v: string): SelectOption => { return { value: v }; }))
      .value(this.filterCategory).font({ size: this.scaledSize(12) }).onSelect((index, value) => { this.filterCategory = value; }).margin({ top: 6 })
  }

  @Builder
  private diaryPage() {
    this.heading('生活手记', '记录生活，而不是记录数字。')
    this.monthPicker()
    Column({ space: 8 }) {
      Row() {
        ForEach(['日', '一', '二', '三', '四', '五', '六'], (day: string) => {
          Text(day).fontSize(this.scaledSize(12)).fontColor(this.muted()).layoutWeight(1).textAlign(TextAlign.Center)
        })
      }.width('100%')
      Grid() {
        ForEach(this.days(), (day: string, index: number) => {
          GridItem() {
            Column({ space: 2 }) {
              Text(day ? `${Number(day.slice(8))}` : '').fontSize(this.scaledSize(14))
                .fontColor(day === this.selectedDate ? '#FFFFFF' : this.ink())
              Text(day && this.hasDiary(day) ? '•' : ' ').fontSize(10).fontColor(day === this.selectedDate ? '#FFFFFF' : this.color())
            }.justifyContent(FlexAlign.Center).width('100%').height(43)
              .backgroundColor(day && day === this.selectedDate ? this.color() : Color.Transparent).borderRadius(13)
              .onClick(() => { if (day) this.selectedDate = day; })
          }
        }, (day: string, index: number) => `${index}_${day}`)
      }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').rowsGap(4).height(Math.ceil(this.days().length / 7) * 47)
    }.padding(16).backgroundColor('#FFFFFF').borderRadius(22).margin({ bottom: 20 })
    Row() {
      Text(this.selectedDate === dateKey() ? '今天的故事' : this.selectedDate).fontSize(this.scaledSize(18)).fontColor(this.ink()).layoutWeight(1)
      Button('＋ 写日记').backgroundColor(this.color()).fontSize(this.scaledSize(13)).onClick(() => this.openDiary())
    }.width('100%').margin({ bottom: 16 })
    if (!this.diaries().length) { this.empty('留一点时间给自己', '今天有什么值得记住的小事？') }
    ForEach(this.diaries(), (d: Diary) => {
      Column({ space: 14 }) {
        Row() {
          Text(`${d.mood}  ${d.weather}`).fontSize(this.scaledSize(13)).fontColor(this.muted()).layoutWeight(1)
          Text('编辑 ›').fontSize(this.scaledSize(12)).fontColor(this.color())
        }.width('100%')
        Text(d.content).fontSize(this.scaledSize(16)).lineHeight(this.scaledSize(26)).fontColor(this.ink()).fontFamily(this.family()).width('100%')
        if (d.location) { Text(`⌖ ${d.location}`).fontSize(this.scaledSize(12)).fontColor(this.muted()).width('100%') }
        this.imageStrip(d.images, false)
      }.padding(20).width('100%').backgroundColor('#FFFFFF').borderRadius(22).margin({ bottom: 12 }).onClick(() => this.openDiary(d))
    }, (d: Diary) => d.id)
  }

  @Builder
  private statisticsPage() {
    this.heading('收支之间', '让每一笔记录，都有迹可循')
    this.monthPicker()
    this.summary()
    Column({ space: 18 }) {
      Text('近六个月 · 收支趋势').fontSize(this.scaledSize(16)).fontColor(this.ink()).width('100%')
      Text('绿色收入 / 豆沙色支出').fontSize(this.scaledSize(11)).fontColor(this.muted()).width('100%')
      Row({ space: 8 }) {
        ForEach(this.trendMonths(), (m: string) => {
          Column({ space: 8 }) {
            Row({ space: 4 }) {
              Column().width(9).height(Math.max(2, monthlyTotal(this.data, m, 'income') / this.trendMax() * 100)).backgroundColor('#5D7A6B').borderRadius(4)
              Column().width(9).height(Math.max(2, monthlyTotal(this.data, m, 'expense') / this.trendMax() * 100)).backgroundColor('#D27165').borderRadius(4)
            }.height(100).alignItems(VerticalAlign.Bottom)
            Text(`${Number(m.slice(5))}月`).fontSize(11).fontColor(this.muted())
          }.layoutWeight(1).onClick(() => { this.month = m; this.selectedDate = `${m}-01`; })
        }, (m: string) => m)
      }.width('100%')
    }.padding(20).backgroundColor('#FFFFFF').borderRadius(22).margin({ bottom: 20 })
    Row({ space: 12 }) {
      Button('支出分类').backgroundColor(this.statsType === 'expense' ? this.color() : '#FFFFFF').fontColor(this.statsType === 'expense' ? '#FFFFFF' : this.muted()).onClick(() => { this.statsType = 'expense'; })
      Button('收入分类').backgroundColor(this.statsType === 'income' ? this.color() : '#FFFFFF').fontColor(this.statsType === 'income' ? '#FFFFFF' : this.muted()).onClick(() => { this.statsType = 'income'; })
    }.width('100%').margin({ bottom: 16 })
    if (!this.categories().length) { this.empty('还没有统计数据', '记下收支后，在这里看看生活的轨迹') }
    ForEach(this.categories(), (c: CategoryTotal) => {
      Column({ space: 10 }) {
        Row() {
          Text(`${c.name} · ${c.count} 笔`).fontSize(this.scaledSize(15)).fontColor(this.ink()).layoutWeight(1)
          Text(`¥ ${money(c.amount)}`).fontColor(this.ink()).fontSize(this.scaledSize(15))
        }.width('100%')
        Progress({ value: c.amount / Math.max(1, this.statsType === 'expense' ? this.expense() : this.income()) * 100, total: 100, type: ProgressType.Linear }).color(this.color())
        Text(`${(c.amount / Math.max(1, this.statsType === 'expense' ? this.expense() : this.income()) * 100).toFixed(1)}% · 点击查看明细`).fontSize(this.scaledSize(11)).fontColor(this.muted())
      }.width('100%').padding(18).backgroundColor('#FFFFFF').borderRadius(18).margin({ bottom: 10 }).onClick(() => {
        this.filterCategory = c.name; this.filterType = this.statsType; this.filterAccount = '全部账户'; this.search = ''; this.tab = 1;
      })
    }, (c: CategoryTotal) => c.name)
  }

  @Builder
  private settingsPage() {
    this.heading('我的小天地', '按自己的节奏，记录自己的生活')
    Column({ space: 12 }) {
      Text('TallyJie · 鸿蒙原生版').fontFamily(this.family()).fontSize(this.scaledSize(24)).fontColor(this.ink())
      Text('记录生活，而不是记录数字。').fontSize(this.scaledSize(13)).fontColor(this.muted())
      Text(`${this.data.diaries.length} 篇日记  ·  ${this.data.transactions.length} 笔账单`).fontSize(this.scaledSize(13)).fontColor(this.color())
    }.width('100%').padding(28).backgroundColor('#FFFFFF').borderRadius(24).margin({ bottom: 20 })
    Column({ space: 16 }) {
      Text('主题配色').fontColor(this.ink()).fontSize(this.scaledSize(17)).width('100%')
      ForEach(PALETTES, (palette: Palette, index: number) => {
        Row({ space: 12 }) {
          Column().width(24).height(24).backgroundColor(palette.accent).borderRadius(12)
          Text(palette.name).fontSize(this.scaledSize(15)).fontColor(this.ink()).layoutWeight(1)
          Text(this.data.settings.theme === index ? '✓' : '').fontColor(this.color())
        }.width('100%').padding(10).onClick(() => this.setTheme(index))
      })
      Text('阅读字号').fontColor(this.ink()).fontSize(this.scaledSize(17)).width('100%')
      Select(['小', '标准', '大', '特大'].map((v: string): SelectOption => { return { value: v }; }))
        .value(['小', '标准', '大', '特大'][this.data.settings.fontSize]).onSelect(index => this.setFontSize(index)).width('100%')
      Text('书写字体').fontColor(this.ink()).fontSize(this.scaledSize(17)).width('100%')
      Select(['系统字体', '马善政楷书', '站酷小薇', '思源黑体'].map((v: string): SelectOption => { return { value: v }; }))
        .value(['系统字体', '马善政楷书', '站酷小薇', '思源黑体'][this.data.settings.font]).onSelect(index => this.setFont(index)).width('100%')
    }.padding(20).backgroundColor('#FFFFFF').borderRadius(22).margin({ bottom: 20 })
    Column({ space: 14 }) {
      Text('数据与备份').fontColor(this.ink()).fontSize(this.scaledSize(17)).width('100%')
      Text('数据仅保存在本机，请定期备份。导出的 JSON 包含日记、账单、预算、设置和图片，请妥善保管。').fontSize(this.scaledSize(12)).fontColor(this.muted()).lineHeight(20)
      Button('导出完整备份').width('100%').backgroundColor(this.color()).onClick(() => { this.exportData(); })
      Button('从备份恢复').width('100%').backgroundColor(this.bg()).fontColor(this.ink()).onClick(() => this.confirmImport())
      Text('恢复会替换现有数据。当前仅支持鸿蒙版备份，不兼容 Flutter ZIP/JSON。').fontSize(this.scaledSize(11)).fontColor('#D27165')
    }.padding(20).backgroundColor('#FFFFFF').borderRadius(22)
  }

  @Builder
  private imageStrip(names: string[], editable: boolean) {
    if (names.length) {
      Scroll() {
        Row({ space: 10 }) {
          ForEach(names, (name: string) => {
            Column({ space: 4 }) {
              Image(this.store?.imagePath(name) ?? '').width(88).height(88).objectFit(ImageFit.Cover).borderRadius(12).onClick(() => { this.preview = name; })
              if (editable) {
                Text('移除').fontSize(12).fontColor('#D27165').onClick(() => { this.images = this.images.filter(n => n !== name); })
              }
            }
          }, (name: string) => name)
        }
      }.scrollable(ScrollDirection.Horizontal).width('100%')
    }
  }

  @Builder
  private label(value: string) {
    Text(value).fontSize(this.scaledSize(13)).fontColor(this.muted()).width('100%').margin({ top: 8 })
  }

  @Builder
  private editorPage() {
    Column() {
      Row() {
        Button('取消').backgroundColor(Color.Transparent).fontColor(this.muted()).onClick(() => this.closeEditor())
        Text(this.editor === 'budget' ? '月度预算' : this.editor === 'diary' ? '生活手记' : '记一笔').fontSize(this.scaledSize(20)).fontColor(this.ink()).layoutWeight(1).textAlign(TextAlign.Center)
        Button('保存').backgroundColor(this.color()).onClick(() => this.saveEditor())
      }.width('100%').padding({ top: 12, bottom: 12 })
      Scroll() {
        Column({ space: 14 }) {
          if (this.editor === 'budget') {
            this.label(`${this.month} 预算（元），留空则取消预算`)
            TextInput({ text: this.amount, placeholder: '例如 3000.00' }).type(InputType.NUMBER_DECIMAL).maxLength(12).onChange(value => { this.amount = value; })
          } else {
            if (this.editor === 'transaction') {
              Row({ space: 12 }) {
                Button('支出').backgroundColor(this.entryType === 'expense' ? this.color() : '#FFFFFF').fontColor(this.entryType === 'expense' ? '#FFFFFF' : this.ink()).onClick(() => { this.entryType = 'expense'; this.category = '餐饮'; })
                Button('收入').backgroundColor(this.entryType === 'income' ? this.color() : '#FFFFFF').fontColor(this.entryType === 'income' ? '#FFFFFF' : this.ink()).onClick(() => { this.entryType = 'income'; this.category = '工资'; })
              }.width('100%')
              this.label('金额 · 元')
              TextInput({ text: this.amount, placeholder: '0.00' }).fontSize(32).type(InputType.NUMBER_DECIMAL).maxLength(12).onChange(value => { this.amount = value; })
              this.label('分类')
              Select((this.entryType === 'expense' ? EXPENSE_CATEGORIES : INCOME_CATEGORIES).map((v: string): SelectOption => { return { value: v }; }))
                .value(this.category).width('100%').onSelect((index, value) => { this.category = value; })
              this.label('账户')
              Select(ACCOUNTS.map((v: string): SelectOption => { return { value: v }; })).value(this.account).width('100%').onSelect((index, value) => { this.account = value; })
            }
            this.label('日期 · YYYY-MM-DD')
            TextInput({ text: this.formDate, placeholder: '2026-11-16' }).maxLength(10).onChange(value => { this.formDate = value; })
            if (this.editor === 'transaction') {
              this.label('时间 · HH:mm')
              TextInput({ text: this.formTime, placeholder: '09:30' }).maxLength(5).onChange(value => { this.formTime = value; })
            } else {
              this.label('此刻的心情与天气')
              Row({ space: 10 }) {
                Select(MOODS.map((v: string): SelectOption => { return { value: v }; })).value(this.mood).layoutWeight(1).onSelect((index, value) => { this.mood = value; })
                Select(WEATHERS.map((v: string): SelectOption => { return { value: v }; })).value(this.weather).layoutWeight(1).onSelect((index, value) => { this.weather = value; })
              }.width('100%')
              this.label('所在地点（手动填写）')
              TextInput({ text: this.location, placeholder: '此刻，你在哪里？' }).maxLength(200).onChange(value => { this.location = value; })
            }
            this.label(this.editor === 'diary' ? '写下今天的故事' : '备注')
            TextArea({ text: this.note, placeholder: this.editor === 'diary' ? '平凡的日子里，也有闪闪发光的小事……' : '这一笔，花在了什么美好上？' })
              .height(this.editor === 'diary' ? 220 : 100).fontSize(this.scaledSize(16)).fontFamily(this.family()).maxLength(20000).onChange(value => { this.note = value; })
            this.label(this.editor === 'diary' ? '生活照片 · 最多 9 张' : '消费凭证 · 最多 9 张')
            this.imageStrip(this.images, true)
            Button(`＋ 添加图片（${this.images.length}/9）`).width('100%').backgroundColor('#FFFFFF').fontColor(this.color()).enabled(this.images.length < 9).onClick(() => { this.addImages(); })
            if (this.editingId) {
              Button('删除这条记录').width('100%').backgroundColor('#FFFFFF').fontColor('#D27165').margin({ top: 24 }).onClick(() => this.deleteEntry())
            }
          }
        }.width('100%').padding({ bottom: 32 })
      }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
    }.padding({ left: 20, right: 20 }).width('100%').height('100%').backgroundColor(this.bg())
  }

  build() {
    Stack() {
      Column() {
        if (this.loadError) {
          this.empty('暂时无法打开数据', this.loadError)
        } else if (this.editor) {
          this.editorPage()
        } else {
          Scroll() {
            Column() {
              if (this.tab === 0) { this.diaryPage() }
              else if (this.tab === 1) { this.ledgerPage() }
              else if (this.tab === 2) { this.statisticsPage() }
              else { this.settingsPage() }
            }.width('100%').constraintSize({ maxWidth: 680 }).padding({ left: 20, right: 20, bottom: 24 })
          }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
          Row() {
            ForEach(['日记', '记账', '统计', '设置'], (title: string, index: number) => {
              Column({ space: 4 }) {
                Text(['✎', '＋', '▥', '⚙'][index]).fontSize(23).fontColor(this.tab === index ? this.color() : this.muted())
                Text(title).fontSize(this.scaledSize(11)).fontColor(this.tab === index ? this.color() : this.muted())
              }.layoutWeight(1).padding({ top: 10, bottom: 10 }).borderRadius(20)
                .backgroundColor(this.tab === index ? '#FFFFFF' : Color.Transparent).onClick(() => { this.tab = index; })
            })
          }.width('100%').padding({ left: 16, right: 16, bottom: 8, top: 6 }).backgroundColor(this.bg())
        }
      }.width('100%').height('100%').backgroundColor(this.bg())
      if (this.preview) {
        Column({ space: 20 }) {
          Button('关闭预览').backgroundColor('#444444').onClick(() => { this.preview = ''; })
          Image(this.store?.imagePath(this.preview) ?? '').width('100%').layoutWeight(1).objectFit(ImageFit.Contain)
        }.width('100%').height('100%').padding(20).backgroundColor('#F0111111')
      }
      if (this.busy) {
        Column({ space: 16 }) {
          LoadingProgress().width(48).height(48).color(this.color())
          Text('处理中，请稍候…').fontColor(this.ink())
        }.width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor('#EFFFFFFF')
      }
    }.width('100%').height('100%')
  }
}
