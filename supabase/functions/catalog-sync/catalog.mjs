const HEADERS = ['comite', 'nombre_delegacion', 'tipo_delegacion', 'permite_codelegacion'];
const BOOLS = new Map([['si', true], ['sí', true], ['true', true], ['no', false], ['false', false]]);
export class SyncError extends Error {
  constructor(code) { super(code); this.code = code; }
}
export function normalizeRows(values) {
  const headers = values?.[0];
  if (!Array.isArray(headers) || headers.length !== 4 || HEADERS.some((h) => headers.filter((v) => v === h).length !== 1)) throw new SyncError('invalid_headers');
  const indices = HEADERS.map((h) => headers.indexOf(h));
  const rows = [];
  for (let i = 1; i < values.length; i++) {
    const cells = values[i];
    if (!Array.isArray(cells) || cells.length > 4) throw new SyncError('invalid_row');
    const normalized = Array.from({ length: 4 }, (_, j) => {
      const value = cells[j] ?? '';
      if (typeof value !== 'string' && typeof value !== 'boolean') throw new SyncError('invalid_row');
      return typeof value === 'string' ? value.trim().normalize('NFC') : value;
    });
    if (normalized.every((v) => v === '')) continue;
    const [committee, name, kind, raw] = indices.map((j) => normalized[j]);
    if (![committee, name, kind].every((v) => typeof v === 'string' && v.length && !v.includes('\0'))) throw new SyncError('invalid_row');
    const allowed = typeof raw === 'boolean' ? raw : BOOLS.get(raw.toLowerCase());
    if (allowed === undefined) throw new SyncError('invalid_boolean');
    rows.push({ source_line: i + 1, committee, representation_name: name, representation_type: kind, allows_co_delegation: allowed });
  }
  if (!rows.length) throw new SyncError('empty_sheet');
  return rows;
}
export async function readGoogle(url, token, reserve, metrics, options = {}) {
  const fetcher = options.fetcher ?? fetch;
  const wait = options.wait ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
  const deadline = options.deadline ?? Date.now() + 90000;
  for (let attempt = 0; attempt < 3; attempt++) {
    if (Date.now() >= deadline) throw new SyncError('timeout');
    if (!await reserve()) throw new SyncError('quota_budget');
    metrics.attempts++;
    let response;
    try {
      response = await fetcher(url, { headers: { Authorization: 'Bearer ' + token }, signal: AbortSignal.timeout(Math.max(1, Math.min(15000, deadline - Date.now()))) });
    } catch { if (attempt === 2) throw new SyncError('google_unavailable'); }
    if (response?.ok) {
      try { return await response.json(); } catch { throw new SyncError('invalid_google_response'); }
    }
    if (response?.status === 429) metrics.rate_limited++;
    if (response && response.status !== 429 && response.status < 500) throw new SyncError('google_access');
    if (attempt === 2) throw new SyncError('google_unavailable');
    const retryAfter = response?.headers.get('retry-after');
    let delay = (2 ** attempt) * 1000 + Math.floor(Math.random() * 1000);
    if (retryAfter) {
      const seconds = Number(retryAfter);
      const retryMs = Number.isFinite(seconds) ? seconds * 1000 : Date.parse(retryAfter) - Date.now();
      if (Number.isFinite(retryMs)) delay = Math.max(delay, retryMs);
    }
    if (Date.now() + delay >= deadline) throw new SyncError('timeout');
    await wait(delay);
  }
  throw new SyncError('google_unavailable');
}
export async function getSheetRows(spreadsheetId, sheetId, token, reserve, metrics, options = {}) {
  options = { ...options, deadline: options.deadline ?? Date.now() + 90000 };
  const base = 'https://sheets.googleapis.com/v4/spreadsheets/' + encodeURIComponent(spreadsheetId);
  const metadata = await readGoogle(base + '?fields=sheets.properties(sheetId,title)', token, reserve, metrics, options);
  const title = metadata.sheets?.find((sheet) => sheet.properties?.sheetId === sheetId)?.properties?.title;
  if (typeof title !== 'string') throw new SyncError('sheet_missing');
  const range = "'" + title.replaceAll("'", "''") + "'!A:D";
  const data = await readGoogle(base + '/values/' + encodeURIComponent(range) + '?majorDimension=ROWS&valueRenderOption=UNFORMATTED_VALUE', token, reserve, metrics, options);
  return normalizeRows(data.values);
}
