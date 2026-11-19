export interface CardLayer { index: number; depth: number; angle: number; shiftX: number; shiftY: number; }
// Slots alternate below/above the horizontal face: next, previous, next + 1,
// previous - 1. Render each real account once, with at most two cards per side.
function fanDistance(depth: number): number { return depth > 0 ? Math.ceil(depth / 2) : 0; }
function fanSide(depth: number): number { return depth > 0 ? (depth % 2 === 1 ? 1 : -1) : 0; }
export function cardLayers(count: number, selected: number): CardLayer[] {
  if (count <= 0) { return []; }
  const active = Math.max(0, Math.min(count - 1, selected));
  const result: CardLayer[] = [];
  const seen: number[] = [active];
  for (let depth = 1; depth <= Math.min(4, count - 1); depth++) {
    const distance = fanDistance(depth);
    const side = fanSide(depth);
    const index = nextCard(count, active, side * distance);
    if (seen.indexOf(index) >= 0) { continue; }
    seen.push(index);
    result.unshift({ index: index, depth: depth, angle: -side * distance * 14,
      shiftX: distance * 42, shiftY: 0 });
  }
  result.push({ index: active, depth: 0, angle: 0, shiftX: 0, shiftY: 0 });
  return result;
}
export function nextCard(count: number, selected: number, direction: number): number {
  return count > 0 ? ((selected + direction) % count + count) % count : 0;
}
// One account per completed vertical swipe. Short drags are taps, not switches.
export function swipedCard(count: number, selected: number, offsetY: number): number {
  return nextCard(count, selected, Math.abs(offsetY) < 30 ? 0 : offsetY < 0 ? 1 : -1);
}
export interface CardDimensions {
  stackHeight: number; width: number; height: number; x: number; y: number; angle: number;
}
// The hinge is toward the offscreen right edge: positive/negative rotations
// open distinct upper/lower wings, rather than piling both rear cards on top.
export const CARD_FAN_PIVOT_X: string = '60%';
export const CARD_FAN_PIVOT_Y: string = '50%';
export interface CardRotation {
  x: number; y: number; z: number; angle: number; centerX: string; centerY: string;
}
export function cardRotation(angle: number): CardRotation {
  // A rotation in the screen plane only: no X/Y tilt, perspective or skew.
  return { x: 0, y: 0, z: 1, angle: angle, centerX: CARD_FAN_PIVOT_X, centerY: CARD_FAN_PIVOT_Y };
}
export function cardDimensions(width: number, depth: number, dark: boolean, homeHeight: number = 300): CardDimensions {
  const height = dark ? Math.min(272, width * 0.75) :
    Math.max(148, Math.min(224, width * 0.76, homeHeight * 0.66));
  const distance = fanDistance(depth);
  const side = fanSide(depth);
  // Reserve the full rotated outline before the viewport clips its right edge.
  // Vertical staggering reveals a card body, not just a triangular lower sliver.
  const stagger = dark ? height * 0.14 : 0;
  const outerAngle = 28 * Math.PI / 180;
  const halfFan = width * 0.6 * Math.sin(outerAngle) + height / 2 * Math.cos(outerAngle) + stagger * 2;
  return {
    stackHeight: dark ? Math.max(360, Math.ceil((halfFan + 8) * 2)) : homeHeight,
    width: width, height: height,
    x: (dark ? 28 : 40) + distance * (dark ? 42 : 18),
    y: dark ? side * distance * stagger : Math.min(34, Math.max(0, (homeHeight - height) / 2 - 10)),
    angle: distance > 0 ? -side * distance * (dark ? 14 : 10) : 0
  };
}

export function cardFanScale(width: number, availableHeight: number): number {
  // Fit the entire rigid fan into the single-page detail without squeezing a
  // card's width/height independently. The offscreen right hinge stays fixed.
  return Math.min(1, Math.max(1, availableHeight) / cardDimensions(width, 0, true).stackHeight);
}

// Stable account IDs are rendered throughout a turn, including the outgoing face
// and the new rear cards. Depth -1 means that account is outside the visible fan.
export function cardDepth(count: number, selected: number, index: number): number {
  if (count <= 0 || index < 0 || index >= count) { return -1; }
  const active = Math.max(0, Math.min(count - 1, selected));
  if (index === active) { return 0; }
  for (let depth = 1; depth <= Math.min(4, count - 1); depth++) {
    if (index === nextCard(count, active, fanSide(depth) * fanDistance(depth))) { return depth; }
  }
  return -1;
}
export function turningCards(count: number, selected: number, target: number): number[] {
  const indices = cardLayers(count, selected).map((layer: CardLayer) => layer.index);
  if (target >= 0) {
    cardLayers(count, target).forEach((layer: CardLayer) => {
      if (indices.indexOf(layer.index) < 0) { indices.push(layer.index); }
    });
  }
  return indices;
}
export interface CardPose {
  width: number; height: number; x: number; y: number; angle: number;
  opacity: number; tone: number; zIndex: number;
}
function lerp(from: number, to: number, progress: number): number {
  return progress === 0 ? from : progress === 1 ? to : from + (to - from) * progress;
}
export function cardPose(width: number, dark: boolean, homeHeight: number, fromDepth: number,
  toDepth: number, progress: number, direction: number): CardPose {
  const t = Math.max(0, Math.min(1, progress));
  const from = cardDimensions(width, fromDepth, dark, homeHeight);
  const to = cardDimensions(width, toDepth, dark, homeHeight);
  // Dark rear cards are opaque grey surfaces, not translucent copies whose
  // text bleeds through each other. Only an outer wrapping card fades out.
  const fromOpacity = fromDepth < 0 ? 0 : fromDepth === 0 || dark ? 1 : 0.22;
  const toOpacity = toDepth < 0 ? 0 : toDepth === 0 || dark ? 1 : 0.22;
  const pose: CardPose = {
    // The outline, corner radius and content size never morph between layers.
    width: from.width, height: from.height,
    x: lerp(from.x, to.x, t), y: lerp(from.y, to.y, t), angle: lerp(from.angle, to.angle, t),
    opacity: lerp(fromOpacity, toOpacity, t), tone: lerp(fanDistance(fromDepth), fanDistance(toDepth), t),
    zIndex: 10 - (t < 0.5 ? (fromDepth < 0 ? 5 : fromDepth) : (toDepth < 0 ? 5 : toDepth))
  };
  if (fromDepth === toDepth) { return pose; }
  // Swipe direction chooses the neighbour in the caller. Both directions
  // reveal from the same offscreen side, never from above/below the viewport.
  // Adjacent accounts move directly into/out of the face, including the
  // two-account case where previous and next refer to the same real account.
  const adjacent = (fromDepth > 0 && fromDepth <= 2 && toDepth === 0) ||
    (fromDepth === 0 && toDepth > 0 && toDepth <= 2);
  const sameSide = fromDepth > 0 && toDepth > 0 && fanSide(fromDepth) === fanSide(toDepth);
  if (adjacent || sameSide) {
    // Small cross-fade while rotating in place; no vertical arc or drop.
    const fade = t === 0 || t === 1 ? 0 : Math.sin(Math.PI * t) * 0.12;
    pose.opacity *= 1 - fade;
    return pose;
  }
  // An outer card disappears behind the right side, then softly reappears in
  // its new slot. Relocate vertically only while fully transparent.
  const travel = Math.min(40, width * 0.1);
  if (t < 0.5) {
    const leg = t * 2;
    pose.x = from.x + travel * leg;
    pose.y = from.y;
    pose.angle = from.angle;
    pose.opacity = fromOpacity * (1 - leg);
  } else {
    const leg = t * 2 - 1;
    pose.x = to.x + travel * (1 - leg);
    pose.y = to.y;
    pose.angle = to.angle;
    pose.opacity = toOpacity * leg;
  }
  return pose;
}
export function cardToneColor(tone: number, bottom: boolean): string {
  const t = Math.max(0, Math.min(2, tone));
  const low = bottom ? (t < 1 ? 9 : 80) : (t < 1 ? 51 : 116);
  const high = bottom ? (t < 1 ? 80 : 150) : (t < 1 ? 116 : 181);
  const channel = Math.round(lerp(low, high, t < 1 ? t : t - 1));
  return `rgb(${channel}, ${channel}, ${channel})`;
}
