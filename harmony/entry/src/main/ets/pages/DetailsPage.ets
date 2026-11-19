import { AppState } from '../state/AppState';
import { categoryImage } from '../components/CategoryIcon';
import { FinanceTheme } from '../theme/FinanceTheme';
import { DetailsPalette } from '../theme/DetailsPalette';
import { Category, DateRange, LedgerFilter, LedgerEntry, LedgerCursor, EntryType } from '../model/LedgerModels';
import { defaultFilter } from '../service/LedgerQueryService';
import { saveEntry, deleteEntry, EntryInput } from '../service/TransactionService';
import { parseAmount } from '../domain/Money';
import { validateFilter } from '../domain/LedgerRules';
import { calendarMonth, calendarWeek } from '../domain/DateRange';
import { DetailsOverview, detailsOverview, detailsMoney, detailsRangeLabel, detailsDayLabel, detailsEntryTime } from '../domain/DetailsOverview';
import { DailyTotal } from '../repository/LedgerRepository';
import { dateKey, money, pad } from '../model/AppData';

@Component
export struct DetailsPage {
  @ObjectLink state: AppState;
  @Prop initialFilter: LedgerFilter = defaultFilter();
  onBudgets: () => void = () => {};
  onOpenEditor: () => void = () => {};
  @Prop @Watch('refreshOverview') refreshVersion: number = 0;
  @State keyword: string = '';
  @State typeIndex: number = 0;
  @State accountId: string = '';
  @State categoryId: string = '';
  @State start: string = '';
  @State end: string = '';
  @State min: string = '';
  @State max: string = '';
  @State rows: LedgerEntry[] = [];
  @State income: number = 0;
  @State expense: number = 0;
  @State count: number = 0;
  @State next: LedgerCursor | null = null;
  @State error: string = '';
  @State selected: string = '';
  @State editAmount: string = '';
  @State editDate: string = '';
  @State editTime: string = '';
  @State editNote: string = '';
  @State editAccount: string = '';
  @State editCategory: string = '';
  @State editIncome: boolean = false;
  @State editError: string = '';
  @State active: LedgerFilter = defaultFilter();
  @State overview: DetailsOverview = { monthLabel: '', incomeCents: 0, expenseCents: 0, balanceCents: 0,
    budgetCents: null, remainingCents: null, budgetPercent: 0 };
  @State days: DailyTotal[] = [];
  @State loading: boolean = false;
  @State showSearch: boolean = false;
  private keywordTimer: number = -1;
  private pageVisible: boolean = false;
  private searchController: TextInputController = new TextInputController();
  private request: number = 0;
  private pageRevision: number = 0;
  aboutToAppear(): void {
    this.pageVisible = true;
    this.keyword = this.initialFilter.keyword;
    this.showSearch = this.keyword.length > 0;
    this.typeIndex = this.initialFilter.type === null ? 0 : this.initialFilter.type === 'expense' ? 1 : 2;
    this.accountId = this.initialFilter.accountIds[0] || ''; this.categoryId = this.initialFilter.categoryIds[0] || '';
    this.start = this.initialFilter.range?.startDate || ''; this.end = this.initialFilter.range?.endDate || '';
    this.min = this.initialFilter.minAmountCents === null ? '' : money(this.initialFilter.minAmountCents);
    this.max = this.initialFilter.maxAmountCents === null ? '' : money(this.initialFilter.maxAmountCents);
    this.overview = detailsOverview(this.state.data, dateKey());
    this.search();
  }
  aboutToDisappear(): void {
    this.pageVisible = false;
    this.request++;
    this.cancelKeywordSearch();
    this.searchController.stopEditing();
  }
  private refreshOverview(): void { this.overview = detailsOverview(this.state.data, dateKey()); }
  private editCategories(): Category[] {
    return this.state.data.categories.filter((row) => row.type === (this.editIncome ? 'income' : 'expense'));
  }
  private editOptions(account: boolean): SelectOption[] {
    const options: SelectOption[] = [];
    if (account) {
      this.state.data.accounts.forEach((row) => options.push({ value: row.name }));
    } else {
      this.editCategories().forEach((row) => options.push({ value: row.name }));
    }
    return options;
  }
  private filter(): LedgerFilter {
    const filter = defaultFilter();
    filter.keyword = this.keyword; filter.type = this.typeIndex === 0 ? null : this.typeIndex === 1 ? 'expense' : 'income';
    filter.accountIds = this.accountId ? [this.accountId] : []; filter.categoryIds = this.categoryId ? [this.categoryId] : [];
    if (this.start || this.end) { filter.range = { startDate: this.start, endDate: this.end }; }
    filter.minAmountCents = this.min ? parseAmount(this.min) : null; filter.maxAmountCents = this.max ? parseAmount(this.max) : null;
    validateFilter(filter);
    return filter;
  }
  private cancelKeywordSearch(): void {
    if (this.keywordTimer !== -1) { clearTimeout(this.keywordTimer); this.keywordTimer = -1; }
  }
  private search(): void {
    this.cancelKeywordSearch();
    try { this.active = this.filter(); this.fetch(false); } catch (error) { this.error = (error as Error).message; }
  }
  private changeKeyword(value: string): void {
    if (value === this.keyword) { return; }
    this.keyword = value;
    this.cancelKeywordSearch();
    this.keywordTimer = setTimeout(() => { this.keywordTimer = -1; this.search(); }, 250);
  }
  private expandSearch(open: boolean): void {
    if (this.showSearch === open || !this.pageVisible) { return; }
    this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseInOut, onFinish: () => {
      if (open && this.showSearch && this.pageVisible) {
        this.getUIContext().getFocusController().requestFocus('details-search-input');
      }
    } }, () => { this.showSearch = open; });
    if (!open) {
      this.searchController.stopEditing();
      this.keyword = '';
      this.search();
    }
  }
  private searchEditingChanged(editing: boolean): void {
    // Both the IME hide key and system back end editing. Keep meaningful queries visible.
    if (!editing && this.keyword.trim().length === 0) { this.expandSearch(false); }
  }
  private reset(): void {
    this.keyword = ''; this.typeIndex = 0; this.accountId = ''; this.categoryId = '';
    this.min = ''; this.max = '';
    const month = calendarMonth(dateKey()); this.start = month.startDate; this.end = month.endDate;
    this.search();
  }
  private period(index: number): void {
    const today = dateKey();
    let range: DateRange | null = null;
    if (index === 0) { range = calendarMonth(today); }
    else if (index === 1) { range = calendarWeek(today); }
    else if (index === 2) { range = { startDate: `${today.slice(0, 4)}-01-01`, endDate: `${today.slice(0, 4)}-12-31` }; }
    this.start = range?.startDate || ''; this.end = range?.endDate || ''; this.search();
  }
  private billType(index: number): void { this.typeIndex = index; this.search(); }
  private async fetch(append: boolean): Promise<void> {
    if (append && this.loading) { return; }
    const ticket = ++this.request; this.loading = true;
    try {
      const filter: LedgerFilter = JSON.parse(JSON.stringify(this.active)) as LedgerFilter;
      filter.cursor = append ? this.next : null;
      const result = await this.state.queryEntries(filter);
      if (ticket !== this.request) { return; }
      if (append && result.revision !== this.pageRevision) { this.fetch(false); return; }
      const page = result.page;
      this.rows = append ? this.rows.concat(page.rows) : page.rows;
      this.days = result.days; this.pageRevision = result.revision;
      this.income = page.incomeCents; this.expense = page.expenseCents; this.count = page.count; this.next = page.next; this.error = '';
      this.overview = detailsOverview(this.state.data, dateKey());
    } catch (error) { if (ticket === this.request) { this.error = (error as Error).message; } }
    finally { if (ticket === this.request) { this.loading = false; } }
  }
  private open(row: LedgerEntry): void {
    this.searchController.stopEditing();
    this.editAmount = money(row.amountCents);
    this.editDate = row.date;
    this.editTime = row.time;
    this.editNote = row.note;
    this.editAccount = row.accountId;
    this.editCategory = row.categoryId;
    this.editIncome = row.type === 'income';
    this.editError = '';
    this.selected = row.id;
    this.onOpenEditor();
  }
  private editType(income: boolean): void {
    if (this.editIncome === income) { return; }
    this.editIncome = income;
    this.editCategory = '';
    this.editError = '';
  }
  private createdAtLabel(): string {
    const stamp = this.state.data.entries.find((row) => row.id === this.selected)?.createdAt;
    if (!stamp) { return '创建时间未记录'; }
    const date = new Date(stamp);
    if (!Number.isFinite(date.getTime())) { return '创建时间未记录'; }
    return `创建于 ${dateKey(date)} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }
  private closeEditor(): void {
    this.getUIContext().getFocusController().clearFocus();
    this.editError = '';
    this.selected = '';
  }
  private returnToList(): void {
    if (this.state.saving) { return; }
    const row = this.state.data.entries.find((item) => item.id === this.selected);
    if (row && money(row.amountCents) === this.editAmount && row.date === this.editDate &&
      row.time === this.editTime && row.note === this.editNote && row.accountId === this.editAccount &&
      row.categoryId === this.editCategory && (row.type === 'income') === this.editIncome) {
      this.closeEditor();
      return;
    }
    this.getUIContext().showAlertDialog({ title: '放弃未保存的修改？', message: '原账单不会变化。',
      primaryButton: { value: '继续编辑', action: () => {} },
      secondaryButton: { value: '放弃修改', action: () => this.closeEditor() } });
  }
  private editFailure(code: string, fallback: string): string {
    if (code === 'INVALID_AMOUNT' || code === 'AMOUNT_OVERFLOW') { return '请输入有效金额，最多两位小数。'; }
    if (code === 'INVALID_DATE') { return '请检查交易日期和时间。'; }
    if (code === 'REFERENCE_NOT_FOUND' || code === 'CATEGORY_TYPE_MISMATCH') { return '请选择有效账户和对应的收支分类。'; }
    if (code === 'NEGATIVE_BALANCE') { return '此操作会使普通账户余额低于零。'; }
    return fallback;
  }
  private async save(): Promise<void> {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    this.editError = '';
    try {
      const type: EntryType = this.editIncome ? 'income' : 'expense';
      const input: EntryInput = { id: this.selected, type: type, amount: this.editAmount, date: this.editDate,
        time: this.editTime, note: this.editNote, accountId: this.editAccount, categoryId: this.editCategory };
      if (await this.state.commit(saveEntry(this.state.data, input, new Date().toISOString()))) {
        this.closeEditor();
        this.fetch(false);
      } else { this.editError = this.editFailure(this.state.message, '保存失败，请重试。'); }
    } catch (error) { this.editError = this.editFailure((error as Error).message, '请检查账单信息后重试。'); }
  }
  private confirmDelete(): void {
    const id = this.selected;
    this.getUIContext().showAlertDialog({ title: '删除这笔账单？', message: '删除后余额与统计会同步更新。若导致普通账户负余额将拒绝。',
      primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: '删除', action: () => { this.erase(id); } } });
  }
  private async erase(id: string): Promise<void> {
    if (this.state.saving || this.state.status !== 'ready') { return; }
    this.editError = '';
    try {
      if (await this.state.commit(deleteEntry(this.state.data, id))) {
        this.closeEditor();
        this.fetch(false);
      } else { this.editError = this.editFailure(this.state.message, '删除失败，请重试。'); }
    } catch (error) { this.editError = this.editFailure((error as Error).message, '删除失败，请重试。'); }
  }
  private dayTotal(date: string): string {
    const day = this.days.find((row: DailyTotal) => row.date === date);
    const income = day?.incomeCents || 0;
    const expense = day?.expenseCents || 0;
    if (income > 0 && expense > 0) { return `收入：${money(income)}  支出：${money(expense)}`; }
    return income > 0 ? `收入：${money(income)}` : `支出：${money(expense)}`;
  }
  private categoryName(row: LedgerEntry): string {
    return this.state.data.categories.find((item) => item.id === row.categoryId)?.name || '未分类';
  }
  private categoryIcon(row: LedgerEntry): Resource {
    const category = this.state.data.categories.find((item) => item.id === row.categoryId);
    return categoryImage(category?.name || '', category?.iconKey || 'category');
  }
  private hasExtraFilters(): boolean {
    return this.active.accountIds.length > 0 || this.active.categoryIds.length > 0 || this.active.keyword.length > 0 ||
      this.active.minAmountCents !== null || this.active.maxAmountCents !== null;
  }
  @Builder
  monthlyCard() {
    Column({ space: 12 }) {
      Text('本月结余').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
      Text(detailsMoney(this.overview.balanceCents)).fontSize(42).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        .maxLines(1).minFontSize(24).maxFontSize(42).textAlign(TextAlign.Center).width('100%')
      Row() {
        Column({ space: 8 }) {
          Text('收入').fontSize(14).fontColor('#D7D7D7')
          Text(detailsMoney(this.overview.incomeCents)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(DetailsPalette.incomeOnDark)
            .maxLines(1).minFontSize(11).maxFontSize(17).id('details-month-income')
        }.layoutWeight(1)
        Column() {}.width(1).height(45).backgroundColor('#626262')
        Column({ space: 8 }) {
          Text('支出').fontSize(14).fontColor('#D7D7D7')
          Text(detailsMoney(this.overview.expenseCents)).fontSize(17).fontWeight(FontWeight.Bold).fontColor(DetailsPalette.expense)
            .maxLines(1).minFontSize(11).maxFontSize(17).id('details-month-expense')
        }.layoutWeight(1)
      }.width('100%').margin({ top: 12 })
    }.width('100%').padding({ left: 22, right: 22, top: 28, bottom: 28 }).borderRadius(22)
      .backgroundColor(DetailsPalette.strongBackground).id('details-month-overview')
  }
  @Builder
  budgetCard() {
    Column({ space: 18 }) {
      Row() {
        Text(`${this.overview.monthLabel}总预算`).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#737373').layoutWeight(1)
        Button(this.overview.budgetCents === null ? '设置' : '编辑', { type: ButtonType.Normal })
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor(DetailsPalette.text).backgroundColor(Color.Transparent)
          .height(28).padding({ left: 8, right: 0 }).id('details-edit-budget')
          .enabled(this.state.status === 'ready' && !this.state.saving).onClick(() => this.onBudgets())
      }.width('100%')
      Row({ space: 8 }) {
        Text(this.overview.remainingCents === null ? '尚未设置本月预算' : `剩余预算：${detailsMoney(this.overview.remainingCents)}`)
          .fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).maxLines(2)
          .fontColor(this.overview.remainingCents === null ? DetailsPalette.muted : this.overview.remainingCents < 0 ? DetailsPalette.expense : DetailsPalette.availableBudget)
          .id('details-budget-remaining')
        Stack() {
          Progress({ value: this.overview.budgetPercent, total: 100, type: ProgressType.Ring })
            .width(42).height(42).style({ strokeWidth: 5 })
            .color(this.overview.remainingCents !== null && this.overview.remainingCents < 0 ? DetailsPalette.expense : DetailsPalette.availableBudget)
            .backgroundColor(DetailsPalette.ringTrack).id('details-budget-progress').accessibilityLevel('no')
          Text(this.overview.budgetCents === null ? '—' : `${this.overview.budgetPercent}%`)
            .fontSize(9).fontWeight(FontWeight.Bold).fontColor(this.overview.remainingCents !== null && this.overview.remainingCents < 0 ? DetailsPalette.expense : DetailsPalette.availableBudget)
            .id('details-budget-percent')
        }.width(42).height(42).accessibilityText(this.overview.budgetCents === null ? '未设置预算' : `预算已用${this.overview.budgetPercent}%`)
      }.width('100%')
      Row({ space: 14 }) {
        Column({ space: 7 }) {
          Text('本月预算').fontSize(13).fontColor(DetailsPalette.secondary)
          Text(this.overview.budgetCents === null ? '未设置' : detailsMoney(this.overview.budgetCents))
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor(DetailsPalette.text).maxLines(1).minFontSize(10).maxFontSize(16)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).padding(12).borderRadius(8).backgroundColor('#F5F5F5')
        Column({ space: 7 }) {
          Text('本月支出').fontSize(13).fontColor(DetailsPalette.secondary)
          Text(detailsMoney(this.overview.expenseCents)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(DetailsPalette.expense)
            .maxLines(1).minFontSize(10).maxFontSize(16)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).padding(12).borderRadius(8).backgroundColor('#F5F5F5')
      }.width('100%')
    }.width('100%').padding(14).borderRadius(12).backgroundColor('#FFFFFF')
      .shadow({ radius: 14, color: '#05000000', offsetY: 5 }).id('details-budget-card')
  }
  @Builder
  filterBar() {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Capsule }) {
        if (this.showSearch) {
          Image($r('app.media.details_bill')).width(20).height(20).supportSvg2(true)
            .id('details-type-icon').accessibilityLevel('no')
        } else {
          Row({ space: 4 }) {
            Text(this.active.type === null ? '全部账单' : this.active.type === 'expense' ? '支出账单' : '收入账单')
              .fontSize(13).fontWeight(FontWeight.Medium).fontColor(DetailsPalette.text).maxLines(1)
            Image($r('app.media.details_chevron')).width(10).height(10).fillColor(DetailsPalette.text).accessibilityLevel('no')
          }.justifyContent(FlexAlign.Center).width('100%')
        }
      }.width(40).layoutWeight(this.showSearch ? 0 : 1).height(40).padding(8).clip(true)
        .backgroundColor('#FFFFFF').id('details-type-filter')
        .accessibilityText(`账单类型筛选，当前${this.active.type === null ? '全部账单' : this.active.type === 'expense' ? '支出账单' : '收入账单'}`)
        .onClick(() => this.searchController.stopEditing()).bindMenu([
          { value: '全部账单', action: () => this.billType(0) },
          { value: '支出账单', action: () => this.billType(1) },
          { value: '收入账单', action: () => this.billType(2) }
        ])
      Button({ type: ButtonType.Capsule }) {
        if (this.showSearch) {
          Image($r('app.media.details_calendar')).width(20).height(20).supportSvg2(true)
            .id('details-period-icon').accessibilityLevel('no')
        } else {
          Row({ space: 4 }) {
            Text(detailsRangeLabel(this.active.range, dateKey())).fontSize(13).fontWeight(FontWeight.Medium)
              .fontColor(DetailsPalette.text).maxLines(1)
            Image($r('app.media.details_chevron')).width(10).height(10).fillColor(DetailsPalette.text).accessibilityLevel('no')
          }.justifyContent(FlexAlign.Center).width('100%')
        }
      }.width(40).layoutWeight(this.showSearch ? 0 : 1).height(40).padding(8).clip(true)
        .backgroundColor('#FFFFFF').id('details-period-filter')
        .accessibilityText(`账单日期范围，当前${detailsRangeLabel(this.active.range, dateKey())}`)
        .onClick(() => this.searchController.stopEditing()).bindMenu([
          { value: '本月', action: () => this.period(0) }, { value: '本周', action: () => this.period(1) },
          { value: '本年', action: () => this.period(2) }, { value: '全部时间', action: () => this.period(3) }
        ])
      Row() {
        if (this.showSearch) {
          Image($r('app.media.details_search')).width(15).height(15).margin({ left: 12 }).accessibilityLevel('no')
          TextInput({ text: this.keyword, placeholder: '搜索分类、备注或账户', controller: this.searchController })
            .layoutWeight(1).height(40).padding({ left: 7, right: 0 }).fontSize(13).fontColor(DetailsPalette.text)
            .placeholderColor(DetailsPalette.muted).backgroundColor(Color.Transparent).enterKeyType(EnterKeyType.Search)
            .id('details-search-input').accessibilityText('搜索分类、备注或账户')
            .onChange((value: string) => this.changeKeyword(value))
            .onEditChange((editing: boolean) => this.searchEditingChanged(editing))
            .onSubmit(() => { this.search(); this.searchController.stopEditing(); })
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.details_close')).width(16).height(16).supportSvg2(true).accessibilityLevel('no')
          }.width(32).height(40).padding(0).backgroundColor(Color.Transparent).id('details-search-close')
            .accessibilityText('关闭搜索并清空关键词').onClick(() => this.expandSearch(false))
        } else {
          Button({ type: ButtonType.Capsule }) {
            Row({ space: 5 }) {
              Image($r('app.media.details_search')).width(14).height(14).accessibilityLevel('no')
              Text('查找交易').fontSize(13).fontWeight(FontWeight.Medium).fontColor(DetailsPalette.text).maxLines(1)
            }.justifyContent(FlexAlign.Center).width('100%')
          }.width('100%').height(40).padding(8).backgroundColor(Color.Transparent)
            .id('details-search-toggle').accessibilityText('查找交易').onClick(() => this.expandSearch(true))
        }
      }.layoutWeight(1).height(40).borderRadius(20).backgroundColor('#FFFFFF').clip(true).id('details-search-capsule')
    }.width('100%').margin({ top: 4 }).id('details-filter-bar')
  }
  @Builder
  ledgerRow(row: LedgerEntry) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Image(this.categoryIcon(row)).width(22).height(22).supportSvg2(true)
          .colorFilter(new ColorFilter([0, 0, 0, 0.6, 0, 0, 0, 0, 0.6, 0, 0, 0, 0, 0.6, 0, 0, 0, 0, 1, 0]))
          .padding(7).width(36).height(36).backgroundColor(DetailsPalette.surfaceMuted).borderRadius(10).accessibilityLevel('no')
        Column({ space: 7 }) {
          Text(this.categoryName(row)).fontSize(16).fontWeight(FontWeight.Medium).fontColor(DetailsPalette.secondary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.state.data.accounts.find((item) => item.id === row.accountId)?.name || '未知账户'} · ${detailsEntryTime(row.date, row.time, dateKey())}`)
            .fontSize(12).fontColor(DetailsPalette.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (row.note) { Text(row.note).fontSize(12).fontColor(DetailsPalette.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }) }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(`${row.type === 'income' ? '+' : '-'}${detailsMoney(row.amountCents)}`).fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(row.type === 'income' ? DetailsPalette.income : DetailsPalette.expense).maxLines(1).minFontSize(11).maxFontSize(16)
          .constraintSize({ maxWidth: '47%' })
      }.padding({ left: 15, right: 15, top: 19, bottom: 19 }).width('100%').constraintSize({ minHeight: 76 })
    }.width('100%').padding(0).borderRadius(12).backgroundColor('#FFFFFF').id(`details-entry-${row.id}`)
      .accessibilityText(`${this.categoryName(row)}，${row.type === 'income' ? '收入' : '支出'}${money(row.amountCents)}元，点击查看或编辑`)
      .onClick(() => this.open(row))
  }
  @Builder
  ledgerList() {
    Column({ space: 10 }) {
      Row() {
        Text('账单流水').fontSize(20).fontWeight(FontWeight.Bold).fontColor(DetailsPalette.text).layoutWeight(1)
        Text(`${this.count} 条`).fontSize(13).fontColor(DetailsPalette.muted).id('details-entry-count')
      }.width('100%').margin({ top: 6, bottom: 8 })
      if (this.hasExtraFilters() || this.active.type !== null || detailsRangeLabel(this.active.range, dateKey()) !== '本月') {
        Row({ space: 8 }) {
          Text(`筛选结果 · 收入 ${detailsMoney(this.income)} / 支出 ${detailsMoney(this.expense)}`)
            .fontSize(11).fontColor(DetailsPalette.muted).layoutWeight(1)
          Button('清除', { type: ButtonType.Normal }).fontSize(12).height(28).padding({ left: 6, right: 6 })
            .fontColor(DetailsPalette.secondary).backgroundColor(Color.Transparent).id('details-clear-filters').onClick(() => this.reset())
        }.width('100%').id('details-filter-summary')
      }
      if (this.loading) { Text('正在加载账单…').fontSize(13).fontColor(DetailsPalette.muted) }
      if (!this.loading && !this.error && this.rows.length === 0) {
        Column({ space: 10 }) {
          Image($r('app.media.record_category')).width(30).height(30).accessibilityLevel('no')
          Text('暂无符合条件的账单').fontSize(14).fontColor(DetailsPalette.muted)
          Text('记下一笔，或试试调整筛选条件').fontSize(12).fontColor(DetailsPalette.faint)
        }.width('100%').padding({ top: 28, bottom: 28 }).borderRadius(12).backgroundColor('#FFFFFF')
      }
      ForEach(this.rows, (row: LedgerEntry, index: number) => {
        if (index === 0 || this.rows[index - 1].date !== row.date) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
            Text(detailsDayLabel(row.date, dateKey())).fontSize(12).fontColor(DetailsPalette.muted)
            Text(this.dayTotal(row.date)).fontSize(12).fontColor(DetailsPalette.muted)
          }.width('100%').margin({ top: index === 0 ? 0 : 10, bottom: 0 })
        }
        this.ledgerRow(row)
      }, (row: LedgerEntry) => `${row.id}:${row.updatedAt}`)
      if (this.next !== null) {
        Button(this.loading ? '加载中…' : '加载更多', { type: ButtonType.Normal }).height(40).width('100%').borderRadius(12)
          .fontSize(13).enabled(!this.loading).fontColor(DetailsPalette.secondary).backgroundColor('#FFFFFF').onClick(() => this.fetch(true))
      }
    }.width('100%').id('details-ledger-list')
  }
  @Builder
  editTypeButton(income: boolean) {
    Button(income ? '收入' : '支出', { type: ButtonType.Normal })
      .layoutWeight(1).height(40).padding(0).borderRadius(9).fontSize(14).fontWeight(FontWeight.Medium)
      .backgroundColor(this.editIncome === income ? DetailsPalette.strongBackground : Color.Transparent)
      .fontColor(this.editIncome === income ? Color.White : DetailsPalette.secondary)
      .accessibilityText(`${income ? '收入' : '支出'}${this.editIncome === income ? '，已选中' : ''}`)
      .enabled(!this.state.saving).id(income ? 'details-edit-income' : 'details-edit-expense')
      .onClick(() => this.editType(income))
  }
  @Builder
  editLabel(label: string) {
    Text(label).fontSize(13).fontWeight(FontWeight.Medium).fontColor(DetailsPalette.secondary)
  }
  @Builder
  editAmountCard() {
    Column({ space: 12 }) {
      Row({ space: 4 }) {
        this.editTypeButton(false)
        this.editTypeButton(true)
      }.width('100%').padding(4).borderRadius(12).backgroundColor(DetailsPalette.surfaceMuted)
      Column({ space: 3 }) {
        this.editLabel('交易金额')
        Row({ space: 8 }) {
          Text('¥').fontSize(20).fontWeight(FontWeight.Medium).fontColor(DetailsPalette.secondary)
          TextInput({ text: this.editAmount, placeholder: '0.00' }).layoutWeight(1).height(48).padding(0)
            .type(InputType.NUMBER_DECIMAL).fontSize(30).fontWeight(FontWeight.Bold).fontColor(DetailsPalette.text)
            .backgroundColor(Color.Transparent).enabled(!this.state.saving)
            .accessibilityText('交易金额').id('details-edit-amount')
            .onChange((value: string) => { this.editAmount = value; })
        }.width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').padding(16).borderRadius(18).backgroundColor(Color.White)
  }
  @Builder
  editFieldsCard() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Column({ space: 6 }) {
          this.editLabel('账户')
          Select(this.editOptions(true))
            .selected(this.state.data.accounts.findIndex((row) => row.id === this.editAccount))
            .value(this.state.data.accounts.find((row) => row.id === this.editAccount)?.name || '选择账户')
            .width('100%').height(44).borderRadius(10).font({ size: 14 }).fontColor(DetailsPalette.text)
            .backgroundColor(DetailsPalette.surfaceMuted).enabled(!this.state.saving)
            .id('details-edit-account')
            .onSelect((index: number) => { this.editAccount = this.state.data.accounts[index]?.id || ''; })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 6 }) {
          this.editLabel('分类')
          Select(this.editOptions(false)).selected(this.editCategories().findIndex((row) => row.id === this.editCategory))
            .value(this.editCategories().find((row) => row.id === this.editCategory)?.name || '选择分类')
            .width('100%').height(44).borderRadius(10).font({ size: 14 }).fontColor(DetailsPalette.text)
            .backgroundColor(DetailsPalette.surfaceMuted).enabled(!this.state.saving && this.editCategories().length > 0)
            .id('details-edit-category')
            .onSelect((index: number) => { this.editCategory = this.editCategories()[index]?.id || ''; })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Row({ space: 12 }) {
        Column({ space: 6 }) {
          this.editLabel('交易日期')
          TextInput({ text: this.editDate, placeholder: 'YYYY-MM-DD' }).width('100%').height(44)
            .padding({ left: 12, right: 8 }).borderRadius(10).fontSize(14).fontColor(DetailsPalette.text)
            .backgroundColor(DetailsPalette.surfaceMuted).maxLength(10).enabled(!this.state.saving)
            .accessibilityText('交易日期').id('details-edit-date')
            .onChange((value: string) => { this.editDate = value; })
        }.layoutWeight(3).alignItems(HorizontalAlign.Start)
        Column({ space: 6 }) {
          this.editLabel('交易时间')
          TextInput({ text: this.editTime, placeholder: 'HH:mm' }).width('100%').height(44)
            .padding({ left: 12, right: 8 }).borderRadius(10).fontSize(14).fontColor(DetailsPalette.text)
            .backgroundColor(DetailsPalette.surfaceMuted).maxLength(5).enabled(!this.state.saving)
            .accessibilityText('交易时间').id('details-edit-time')
            .onChange((value: string) => { this.editTime = value; })
        }.layoutWeight(2).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Column({ space: 6 }) {
        this.editLabel('备注')
        TextArea({ text: this.editNote, placeholder: '添加备注（选填）' }).width('100%').height(60)
          .padding(12).borderRadius(10).fontSize(14).fontColor(DetailsPalette.text)
          .backgroundColor(DetailsPalette.surfaceMuted).maxLength(500).enabled(!this.state.saving)
          .accessibilityText('备注').id('details-edit-note')
          .onChange((value: string) => { this.editNote = value; })
      }.width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').padding(16).borderRadius(18).backgroundColor(Color.White)
  }
  @Builder
  entryEditor() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        Button('‹').width(44).height(44).padding(0).fontSize(30).fontColor(DetailsPalette.text)
          .backgroundColor(Color.White).enabled(!this.state.saving).accessibilityText('返回列表')
          .id('details-edit-back').onClick(() => this.returnToList())
        Text('编辑账单').layoutWeight(1).fontSize(22).fontWeight(FontWeight.Bold).fontColor(DetailsPalette.text)
      }.width('100%')
      this.editAmountCard()
      this.editFieldsCard()
      if (this.editError) {
        Text(this.editError).width('100%').padding(12).borderRadius(10).backgroundColor('#F8EDEA')
          .fontSize(13).fontColor('#A43D34').id('details-edit-error')
      }
      Row({ space: 12 }) {
        Button(this.state.saving ? '保存中…' : '保存修改', { type: ButtonType.Normal })
          .layoutWeight(1).height(48).borderRadius(14).fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor(Color.White).backgroundColor(DetailsPalette.strongBackground)
          .enabled(this.state.status === 'ready' && !this.state.saving).id('details-edit-save').onClick(() => this.save())
        Button('删除账单', { type: ButtonType.Normal }).height(48).padding({ left: 16, right: 16 })
          .borderRadius(14).fontSize(14).fontColor('#A43D34').backgroundColor('#F8EDEA')
          .enabled(this.state.status === 'ready' && !this.state.saving).id('details-edit-delete').onClick(() => this.confirmDelete())
      }.width('100%')
      Text(this.createdAtLabel()).width('100%').padding({ left: 4 }).fontSize(11).fontColor(DetailsPalette.secondary)
    }.width('100%').id('details-entry-editor')
  }
  build() {
    Column({ space: 18 }) {
      if (this.selected) { this.entryEditor() }
      else {
        this.monthlyCard()
        this.budgetCard()
        this.filterBar()
        if (this.overview.remainingCents !== null && this.overview.remainingCents < 0) {
          Row({ space: 10 }) {
            Image($r('app.media.details_warning')).width(18).height(18).fillColor(DetailsPalette.expense).accessibilityLevel('no')
            Text(`今月已超预算 ${detailsMoney(-this.overview.remainingCents)}元`).fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(DetailsPalette.expense).layoutWeight(1)
          }.width('100%').padding({ left: 16, right: 16, top: 13, bottom: 13 }).borderRadius(12)
            .backgroundColor(DetailsPalette.overBudgetBackground).id('details-budget-warning')
        }
        this.ledgerList()
        if (this.error) { Text(this.error).fontColor(FinanceTheme.expense).fontSize(13) }
      }
    }.width('100%').id('finance-page-details')
  }
}
