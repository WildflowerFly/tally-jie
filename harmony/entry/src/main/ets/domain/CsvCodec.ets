export function encodeCsv(rows: string[][]): string {
  return '\uFEFF' + rows.map((row: string[]) => row.map((cell: string) => `"${cell.replace(/"/g, '""')}"`).join(',')).join('\r\n');
}
export function decodeCsv(text: string): string[][] {
  const source = text.replace(/^\uFEFF/, '');
  const rows: string[][] = []; let row: string[] = []; let cell = ''; let quoted = false; let closed = false;
  for (let i = 0; i < source.length; i++) {
    const c = source[i];
    if (quoted) {
      if (c === '"') { if (source[i + 1] === '"') { cell += '"'; i++; } else { quoted = false; closed = true; } }
      else { cell += c; }
    } else if (c === ',' || c === '\n' || c === '\r') {
      row.push(cell); cell = ''; closed = false;
      if (c !== ',') { rows.push(row); row = []; if (c === '\r' && source[i + 1] === '\n') { i++; } }
    } else if (c === '"' && cell.length === 0 && !closed) { quoted = true; }
    else { if (closed || c === '"') { throw new Error('INVALID_CSV_QUOTE'); } cell += c; }
  }
  if (quoted) { throw new Error('INVALID_CSV_QUOTE'); }
  if (cell.length > 0 || row.length > 0 || closed) { row.push(cell); rows.push(row); }
  return rows;
}
