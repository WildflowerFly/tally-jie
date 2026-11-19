export interface NavShoulder {
  reach: number;
  cornerRadius: number;
}

export interface NavGeometry {
  width: number;
  center: number;
  top: number;
  bottom: number;
  cornerRadius: number;
  depth: number;
  bowlHalf: number;
  bowlHeight: number;
  bottomHandle: number;
  left: NavShoulder;
  right: NavShoulder;
}

// Keep the existing spacing. The fixed capsule clips the notch at the
// ends instead of squeezing its outer cap or moving the buttons inward.
// The row and travelling button share this inset so their centres align.
export function navContentInset(width: number, count: number): number {
  if (width <= 0 || count <= 1) { return 0; }
  const edge = 60 * Math.min(1, width / 240);
  return Math.max(0, (count * edge - width / 2) / (count - 1));
}

export function navTabCenter(width: number, index: number, count: number): number {
  if (count <= 1) { return width / 2; }
  const inset = navContentInset(width, count);
  return inset + (width - 2 * inset) * (index + 0.5) / count;
}

// All geometry is in vp. Only path serialization converts to physical pixels.
export function navGeometry(center: number, width: number, progress: number, expandedHeight: number = 360): NavGeometry {
  const p = Math.max(0, Math.min(1, progress));
  const scale = 1 - p;
  const horizontalScale = Math.min(1, Math.max(0, width) / 240);
  const corner = (32 - 8 * p) * horizontalScale;
  const half = 44 * scale * horizontalScale;
  const minimumEdge = half + (16 + 8 * p) * horizontalScale;
  const safeCenter = Math.max(minimumEdge, Math.min(width - minimumEdge, center));
  // Selection cannot change the outer capsule. Where the notch overlaps
  // the end cap, the renderer intersects it with the fixed capsule below.
  const left: NavShoulder = { reach: half, cornerRadius: corner };
  const right: NavShoulder = { reach: half, cornerRadius: corner };
  const bowlHalf = 27 * scale * horizontalScale;
  return {
    width: width, center: safeCenter,
    top: 24 * scale, bottom: 88 + (Math.max(88, expandedHeight) - 88) * p,
    cornerRadius: corner, depth: 42 * scale,
    bowlHalf: bowlHalf, bowlHeight: 20 * scale,
    bottomHandle: bowlHalf * 0.55228475,
    left: left, right: right
  };
}

// Clip in physical pixels, just like makeNavOutline. This prevents the
// notch's top rail from filling outside the original circular end cap.
export function makeNavCapsule(width: number, density: number, progress: number, expandedHeight: number = 360): string {
  if (width <= 0 || density <= 0) { return ''; }
  const g = navGeometry(width / 2, width, progress, expandedHeight);
  const w = width * density;
  const t = g.top * density;
  const b = g.bottom * density;
  const r = g.cornerRadius * density;
  return `M ${r} ${t} L ${w - r} ${t} A ${r} ${r} 0 0 1 ${w} ${t + r} ` +
    `L ${w} ${b - r} A ${r} ${r} 0 0 1 ${w - r} ${b} ` +
    `L ${r} ${b} A ${r} ${r} 0 0 1 0 ${b - r} ` +
    `L 0 ${t + r} A ${r} ${r} 0 0 1 ${r} ${t} Z`;
}

export function makeNavOutline(center: number, width: number, density: number, progress: number, expandedHeight: number = 360): string {
  if (width <= 0 || density <= 0) { return ''; }
  const g = navGeometry(center, width, progress, expandedHeight);
  const w = g.width * density;
  const c = g.center * density;
  const t = g.top * density;
  const b = g.bottom * density;
  const l = c - g.left.reach * density;
  const h = c + g.right.reach * density;
  const y = t + g.depth * density;
  const handle = g.bottomHandle * density;
  const q = g.bowlHalf * density;
  const joinY = y - g.bowlHeight * density;
  const verticalHandle = g.bowlHeight * density * 0.55228475;
  const slopeHandle = Math.min(q * 0.15,
    (Math.min(g.left.reach, g.right.reach) * density - q) * 0.7);
  // The joins lean gently inward rather than forming vertical cup walls.
  // Shared diagonal handles keep the shoulders tangent to the round bowl.
  // The lower two cubics are exact mirrors, even at the first/last tab.
  // A single non-retracing contour supplies the notch. The independent
  // capsule clip supplies ALL four outer arcs, avoiding overlapping rails
  // when a shoulder extends beyond the straight part of the capsule.
  return `M 0 ${t} L ${l} ${t} ` +
    `C ${l + (g.left.reach * density - q) * 0.6} ${t} ${c - q - slopeHandle} ${joinY - verticalHandle} ${c - q} ${joinY} ` +
    `C ${c - q + slopeHandle} ${joinY + verticalHandle} ${c - handle} ${y} ${c} ${y} ` +
    `C ${c + handle} ${y} ${c + q - slopeHandle} ${joinY + verticalHandle} ${c + q} ${joinY} ` +
    `C ${c + q + slopeHandle} ${joinY - verticalHandle} ${h - (g.right.reach * density - q) * 0.6} ${t} ${h} ${t} ` +
    `L ${w} ${t} L ${w} ${b} L 0 ${b} Z`;
}
