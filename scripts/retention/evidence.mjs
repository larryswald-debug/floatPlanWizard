// Offline evidence helpers. No network, database, or application mutations.
export function id(value) {
  const s = String(value ?? '').trim();
  return /^[1-9][0-9]*$/.test(s) && Number.isSafeInteger(Number(s)) ? s : null;
}

// SQL DATETIME strings are accepted ONLY when the caller has established UTC
// provenance. Legacy *_raw fields must never be passed as authoritative clocks.
export function utc(value) {
  if (typeof value !== 'string') return null;
  const m = /^(\d{4}-\d\d-\d\d)[T ](\d\d:\d\d:\d\d)(?:\.(\d{1,6}))?Z?$/.exec(value);
  if (!m) return null;
  const seconds = `${m[1]}T${m[2]}`;
  const date = new Date(`${seconds}Z`);
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 19) !== seconds) return null;
  return `${seconds}.${(m[3] || '').padEnd(6, '0')}Z`;
}

export function windowStart(T) {
  const t = utc(T);
  if (!t) throw new Error('Invalid database UTC report time');
  const d = new Date(Date.parse(t) - 30 * 86400000);
  return `${d.toISOString().slice(0, 19)}.${t.slice(20, 26)}Z`;
}

export function within(at, W, T) { return !!at && at >= W && at < T; }
export function flag(v) { return v === true || v === 1 || v === '1'; }
export function upper(v) { return String(v ?? '').trim().toUpperCase(); }
export function unique(items) { return [...new Set(items)]; }
export function sortIds(a, b) { return Number(a) - Number(b); }
export function rowMap(rows, key = 'id') {
  const map = new Map();
  for (const row of rows) {
    const k = id(row[key]);
    if (!k) throw new Error(`Invalid ${key} in snapshot`);
    if (map.has(k) && JSON.stringify(map.get(k)) !== JSON.stringify(row)) {
      throw new Error(`Conflicting duplicate ${key}=${k} in snapshot`);
    }
    map.set(k, row);
  }
  return map;
}

export function ratio(numerator, denominator, label) {
  return { numerator, denominator, percent: denominator ? numerator / denominator * 100 : null, label };
}

export const LIMITATIONS = [
  'Historical observation coverage is incomplete; absent evidence is UNKNOWN, never inferred inactivity.',
  'Recovery coverage markers do not certify complete Day 40 observation coverage.',
  'Historical route-update events may be rename-only and do not prove substantive activity.',
  'Legacy local/server timestamps are retained as raw evidence and receive no offset correction.',
  'Deleted route/trip objects and best-effort historical event writers can hide legitimate uses.',
  'Earliest evidenced use is not necessarily the member\'s true lifetime first use.',
  'Successful sharing describes accepted application sending evidence, not inbox delivery.',
  'Known-positive repeat ratios are observed evidence rates; the primary ratio is not a mathematical lower bound when both counts have incomplete history.'
];
