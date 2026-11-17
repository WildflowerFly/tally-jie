import { LedgerData } from '../model/LedgerModels';
import { ImportPreview, previewJson, exportJson } from './DataExchangeService';
import { validateLedger } from '../domain/LedgerRules';
export interface PortableFile { path: string; base64: string; }
export interface PortableDocument { format: string; version: number; data: LedgerData; files: PortableFile[]; }
export interface PortablePreview { preview: ImportPreview; files: PortableFile[]; }
function check(data: LedgerData, files: PortableFile[]): void {
  validateLedger(data);
  if (!Array.isArray(files) || files.length > 2000) { throw new Error('FILE_COUNT_LIMIT'); }
  const paths: Set<string> = new Set(); let total = 0;
  for (const file of files) {
    if (typeof file.path !== 'string' || !/^(images\/img_[A-Za-z0-9_-]+\.jpg|legacy\/(?:tallyjie|[a-f0-9]{64})\.json)$/.test(file.path) || paths.has(file.path)) { throw new Error('UNSAFE_OR_DUPLICATE_PATH'); }
    if (typeof file.base64 !== 'string' || file.base64.length % 4 !== 0 || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(file.base64)) { throw new Error('INVALID_BASE64'); }
    const bytes = file.base64.length / 4 * 3 - (file.base64.endsWith('==') ? 2 : file.base64.endsWith('=') ? 1 : 0);
    if (bytes > (file.path.startsWith('images/') ? 8 : 16) * 1024 * 1024) { throw new Error('ASSET_TOO_LARGE'); }
    total += bytes; if (total > 40 * 1024 * 1024) { throw new Error('ASSET_TOTAL_LIMIT'); }
    paths.add(file.path);
  }
  for (const asset of data.attachments) { if (!paths.has(asset.relativePath)) { throw new Error('ATTACHMENT_BYTES_REQUIRED'); } }
}
export function encodePortable(data: LedgerData, files: PortableFile[]): string {
  check(data, files);
  const doc: PortableDocument = { format: 'TallyJie-Portable', version: 1, data: data, files: files };
  const text = JSON.stringify(doc); if (text.length > 64 * 1024 * 1024) { throw new Error('IMPORT_TOO_LARGE'); }
  return text;
}
export function previewPortable(current: LedgerData, text: string): PortablePreview {
  if (text.length > 64 * 1024 * 1024) { throw new Error('IMPORT_TOO_LARGE'); }
  const doc = JSON.parse(text) as PortableDocument;
  if (doc.format !== 'TallyJie-Portable' || doc.version !== 1) { throw new Error('UNSUPPORTED_IMPORT'); }
  check(doc.data, doc.files);
  const base: LedgerData = JSON.parse(JSON.stringify(current)) as LedgerData;
  // Files are validated and staged by the platform adapter before any metadata can commit.
  doc.data.attachments.forEach((asset) => {
    if (!base.attachments.some((old) => old.id === asset.id)) { base.attachments.push(asset); }
  });
  const preview = previewJson(base, exportJson(doc.data));
  const newAssets = doc.data.attachments.filter((asset) => !current.attachments.some((old) => old.id === asset.id)).length;
  preview.added += newAssets; preview.duplicates -= newAssets;
  return { preview: preview, files: doc.files };
}
