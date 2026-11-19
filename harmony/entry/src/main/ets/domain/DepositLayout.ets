// FloatingNavBar is 88vp high with a 16vp bottom margin. Deposits end at
// its top edge rather than retaining the generic pages' 132vp clearance.
export const DEPOSIT_NAV_CLEARANCE: number = 104;
export const DEPOSIT_RECENT_TOP: number = 24;
export const DEPOSIT_LINK_GOLD: string = '#BD9475';

export function depositHeroHeight(pageHeight: number): number {
  // Give the redesigned card/quick-actions a larger, dedicated upper stage.
  return Math.max(0, pageHeight * 0.58);
}
