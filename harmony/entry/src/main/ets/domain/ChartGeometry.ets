// Ring: clockwise from 12 o'clock; outer .46*size, inner .28*size, exclusive end boundary.
export function ringHit(values: number[], x: number, y: number, size: number): number {
  if (size <= 0) { return -1; }
  const dx = x - size / 2; const dy = y - size / 2; const radius = Math.sqrt(dx * dx + dy * dy);
  if (radius < size * 0.28 || radius > size * 0.46) { return -1; }
  const total = values.reduce((sum: number, value: number) => sum + Math.max(0, value), 0);
  if (total <= 0) { return -1; }
  const fraction = ((Math.atan2(dy, dx) + Math.PI / 2 + 2 * Math.PI) % (2 * Math.PI)) / (2 * Math.PI);
  let end = 0;
  for (let i = 0; i < values.length; i++) { end += Math.max(0, values[i]) / total; if (values[i] > 0 && fraction < end) { return i; } }
  return -1;
}
export function trendY(value: number, max: number, height: number): number {
  return height - 20 - (max > 0 ? value / max : 0) * (height - 40);
}
export function trendHit(values: number[], x: number, y: number, width: number, height: number): number {
  if (!values.length || width <= 40 || height <= 40) { return -1; }
  const max = Math.max(...values); let nearest = -1; let distance = 20 * 20;
  for (let i = 0; i < values.length; i++) {
    const px = values.length === 1 ? width / 2 : 20 + i * (width - 40) / (values.length - 1);
    const py = trendY(values[i], max, height);
    const square = (x - px) * (x - px) + (y - py) * (y - py);
    if (square <= distance) { distance = square; nearest = i; }
  }
  return nearest;
}
