import { nextCard, swipedCard, cardDimensions, cardDepth, turningCards, cardPose,
  CardPose, cardRotation, cardFanScale } from '../domain/CardLayout';
import { money } from '../model/AppData';
import { AccountCardFace, AccountCardModel } from './AccountCardFace';

@Component
export struct AccountCardStack {
  @Prop @Watch('accountsChanged') cards: AccountCardModel[] = [];
  @Prop @Watch('selectionChanged') activeIndex: number = 0;
  @Prop dark: boolean = false;
  @Prop fillHeight: boolean = false;
  @State availableWidth: number = 300;
  @State availableHeight: number = 300;
  @State motionTarget: number = -1;
  @State motionProgress: number = 0;
  @State motionDirection: number = 1;
  onSelect: (index: number) => void = () => {};
  onOpen: () => void = () => {};
  private motionTimer: number = -1;
  private animating: boolean = false;
  private dragging: boolean = false;
  private accountIds: string = '';

  aboutToAppear(): void { this.accountIds = this.cards.map((card: AccountCardModel) => card.id).join('|'); }
  aboutToDisappear(): void { this.resetMotion(); }
  private accountsChanged(): void {
    const ids = this.cards.map((card: AccountCardModel) => card.id).join('|');
    if (ids !== this.accountIds) { this.accountIds = ids; this.resetMotion(); }
  }
  private selectionChanged(): void { this.resetMotion(); }
  private resetMotion(): void {
    if (this.motionTimer !== -1) { clearInterval(this.motionTimer); this.motionTimer = -1; }
    this.animating = false; this.dragging = false; this.motionTarget = -1; this.motionProgress = 0;
  }
  private card(id: string): AccountCardModel {
    return this.cards.find((card: AccountCardModel) => card.id === id) ||
      { id: id, name: '', englishName: '', iconKey: '', balanceCents: 0 };
  }
  private visibleIds(): string[] {
    return turningCards(this.cards.length, this.activeIndex, this.motionTarget)
      .map((index: number) => this.cards[index].id);
  }
  private isFront(id: string): boolean { return this.cards[this.activeIndex]?.id === id; }
  private depth(id: string): number {
    return cardDepth(this.cards.length, this.activeIndex, this.cards.findIndex((card: AccountCardModel) => card.id === id));
  }
  private slotId(id: string, content: string): string {
    const depth = this.depth(id);
    const slot = depth === 0 ? 'active' : depth === 1 ? 'next' : depth === 2 ? 'previous' :
      depth === 3 ? 'outer-next' : depth === 4 ? 'outer-previous' : `offstage-${id}`;
    return `deposit-${slot}-${content}`;
  }
  private pose(id: string): CardPose {
    const index = this.cards.findIndex((card: AccountCardModel) => card.id === id);
    const from = this.depth(id);
    const to = this.motionTarget < 0 ? from : cardDepth(this.cards.length, this.motionTarget, index);
    return cardPose(this.availableWidth, this.dark, this.availableHeight, from, to, this.motionProgress, this.motionDirection);
  }
  private settle(commit: boolean): void {
    if (this.motionTarget < 0) { this.resetMotion(); return; }
    this.dragging = false; this.animating = true;
    const target = this.motionTarget;
    const from = this.motionProgress;
    const to = commit ? 1 : 0;
    const duration = Math.max(160, 500 * Math.abs(to - from));
    const startedAt = Date.now();
    // Keep the same rigid card nodes alive through the vertical carousel.
    // Only translation, rotation, tint and opacity change, never size or radius.
    this.motionTimer = setInterval(() => {
      const t = Math.min(1, (Date.now() - startedAt) / duration);
      this.motionProgress = from + (to - from) * t * t * (3 - 2 * t);
      if (t === 1) {
        this.resetMotion();
        if (commit) { this.onSelect(target); }
      }
    }, 16);
  }
  private drag(offsetY: number): void {
    if (!this.dragging || this.animating || this.cards.length < 2) { return; }
    this.motionDirection = offsetY < 0 ? 1 : -1;
    this.motionTarget = nextCard(this.cards.length, this.activeIndex, this.motionDirection);
    const travel = this.availableHeight;
    this.motionProgress = Math.min(0.44, Math.abs(offsetY) / Math.max(160, travel));
  }
  private fanScale(): number {
    return this.dark && this.fillHeight ? cardFanScale(this.availableWidth, this.availableHeight) : 1;
  }
  @Builder
  fan() {
    Stack({ alignContent: Alignment.Center }) {
      ForEach(this.visibleIds(), (id: string) => {
        // Lay out and clip one complete rectangular surface FIRST. Rotate the
        // wrapper, not individual content or an already viewport-clipped strip.
        Stack() {
          AccountCardFace({ card: this.card(id), dark: this.dark, tone: this.pose(id).tone,
            nameId: this.slotId(id, 'name') })
        }.width(this.pose(id).width).height(this.pose(id).height)
          .id(this.slotId(id, 'card')).renderGroup(true)
          .opacity(this.pose(id).opacity).zIndex(this.pose(id).zIndex)
          .shadow({ radius: this.isFront(id) ? 14 : 0, color: '#18000000', offsetY: 8 })
          .rotate(cardRotation(this.pose(id).angle))
          .translate({ x: this.pose(id).x, y: this.pose(id).y })
          .accessibilityLevel(this.isFront(id) ? 'yes' : 'no-hide-descendants')
          .accessibilityText(`${this.card(id).name}，余额${money(this.card(id).balanceCents)}元，${this.dark ? '点击编辑账户，上下滑动切换账户' : '点击查看账户详情，上下滑动切换账户'}`)
          .onClick(() => { if (this.isFront(id) && !this.animating && !this.dragging) { this.onOpen(); } })
      }, (id: string) => id)
    }.width('100%').height(this.dark ? cardDimensions(this.availableWidth, 0, true).stackHeight : '100%')
      .scale({ x: this.fanScale(), y: this.fanScale(), centerX: '100%', centerY: '50%' })
  }
  build() {
    Stack({ alignContent: Alignment.Center }) { this.fan() }
      .width('100%').height(this.fillHeight ? '100%' : cardDimensions(this.availableWidth, 0, this.dark).stackHeight).clip(true)
      .onAreaChange((_old: Area, area: Area) => {
        const width = Number(area.width); const height = Number(area.height);
        if (width > 0 && width !== this.availableWidth) { this.availableWidth = width; }
        if (height > 0 && height !== this.availableHeight) { this.availableHeight = height; }
      })
      .id(this.dark ? 'deposit-detail-stack' : 'deposit-home-stack')
      // Capture only the card gesture; the detail itself has no vertical Scroll.
      .priorityGesture(PanGesture({ direction: PanDirection.Vertical, distance: 1 })
        .onActionStart(() => { if (!this.animating && this.cards.length > 1) { this.dragging = true; } })
        .onActionUpdate((event: GestureEvent) => { this.drag(event.offsetY); })
        .onActionEnd((event: GestureEvent) => {
          if (!this.dragging || this.animating) { return; }
          this.drag(event.offsetY);
          this.settle(swipedCard(this.cards.length, this.activeIndex, event.offsetY) !== this.activeIndex);
        })
        .onActionCancel(() => { if (this.dragging && !this.animating) { this.settle(false); } }))
  }
}
