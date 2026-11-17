export interface CardLayer { index: number; depth: number; angle: number; shiftX: number; shiftY: number; }
export function cardLayers(count: number, selected: number): CardLayer[] {
  if (count <= 0) { return []; }
  const active = Math.max(0, Math.min(count - 1, selected));
  const result: CardLayer[] = [];
  for (let depth = Math.min(2, count - 1); depth >= 0; depth--) {
    result.push({ index: (active + depth) % count, depth: depth, angle: depth === 0 ? 0 : -depth * 12, shiftX: depth * 10, shiftY: depth === 0 ? 0 : -depth * 21 });
  }
  return result;
}
export function nextCard(count: number, selected: number, direction: number): number {
  return count > 0 ? ((selected + direction) % count + count) % count : 0;
}
