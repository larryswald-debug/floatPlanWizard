import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve, dirname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { buildCombinedExportSQL } from './export-sql.mjs';
import { fromPackets, buildReport } from './baseline.mjs';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '../..');
const sha256 = value => createHash('sha256').update(value).digest('hex');
export function parseCsv(text) {
  const rows = []; let row = [], cell = '', quoted = false;
  text = text.replace(/^\uFEFF/, '');
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { cell += '"'; i++; }
      else if (ch === '"') quoted = false;
      else cell += ch;
    } else if (ch === '"' && !cell.length) quoted = true;
    else if (ch === ',') { row.push(cell); cell = ''; }
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(cell); if (row.some(c => c.length)) rows.push(row); row = []; cell = '';
    } else cell += ch;
  }
  if (quoted) throw new Error('Unclosed CSV quote');
  if (cell.length || row.length) { row.push(cell); rows.push(row); }
  return rows;
}
export function importPackets(text) {
  const trimmed = text.trim().replace(/^\uFEFF/, '');
  if (trimmed.startsWith('[')) return JSON.parse(trimmed);
  // Workbench's native result-grid CSV can wrap a JSON cell without doubling its internal quotes.
  // Accept only that exact one-payload-per-line envelope; JSON.parse still validates every value.
  const nativeLines = trimmed.split(/\r?\n/);
  if (nativeLines[0] === 'payload') nativeLines.shift();
  if (nativeLines.length && nativeLines.every(line => line.startsWith('"{') && !line.startsWith('"{""') && line.endsWith('}"'))) {
    return nativeLines.map(line => JSON.parse(line.slice(1, -1)));
  }
  const rows = parseCsv(trimmed);
  if (rows[0]?.[0] === 'payload') rows.shift();
  if (!rows.length || rows.some(r => r.length !== 1)) throw new Error('Expected one payload column from the SQL export');
  return rows.map(r => JSON.parse(r[0]));
}
function safeCsvCell(value) {
  let text = value == null ? '' : typeof value === 'object' ? JSON.stringify(value) : String(value);
  if (/^[\s]*[=+@-]/.test(text)) text = "'" + text;
  return '"' + text.replaceAll('"', '""') + '"';
}
export function memberCsv(report) {
  const reportContext = {
    population: report.population, activity: report.activity, route_use: report.route_use,
    sharing: report.sharing, completion: report.completion,
    return_after_completion: report.return_after_completion, limitations: report.limitations
  };
  const cols = ['report_T','report_W','definition_version','report_context','user_id','first_name','last_name','email','included','exclusion_category','exclusion_reason',
    'activity_classification','activity_reason','activity_evidence','observation_start_utc',
    'has_legitimate_use','repeat_route','first_evidenced_use','second_evidenced_use','normalized_uses',
    'sharing_lifetime','sharing_30d','share_evidence','completion_lifetime','completion_30d',
    'completion_evidence','return_after_completion_lifetime','return_after_completion_30d','return_evidence','unknown_reasons'];
  const rows = report.members.map(m => ({
    report_T: report.T, report_W: report.W, definition_version: report.definition_version, report_context: reportContext,
    ...m, activity_classification:m.activity.status, activity_reason:m.activity.reason, activity_evidence:m.activity.evidence,
    has_legitimate_use:m.route_use.has_legitimate_use, repeat_route:m.route_use.repeat,
    first_evidenced_use:m.route_use.first_use, second_evidenced_use:m.route_use.second_use, normalized_uses:m.route_use.uses,
    sharing_lifetime:m.sharing_lifetime.status, sharing_30d:m.sharing_30d.status, share_evidence:m.sharing_evidence,
    completion_lifetime:m.completion_lifetime.status, completion_30d:m.completion_30d.status,
    completion_evidence:m.completion_evidence, return_after_completion_lifetime:m.route_use.returned_after_completion,
    return_after_completion_30d:(m.route_use.return_evidence || []).some(e => e.subsequent_begin_at_utc >= report.W && e.subsequent_begin_at_utc < report.T) ? 'YES' : 'UNKNOWN',
    return_evidence:m.route_use.return_evidence, unknown_reasons:m.reasons
  }));
  return cols.map(safeCsvCell).join(',') + '\r\n' + rows.map(r => cols.map(k => safeCsvCell(r[k])).join(',')).join('\r\n') + '\r\n';
}
const md = value => String(value ?? '').replaceAll('|', '\\|').replace(/[\r\n]/g, ' ');
const rateText = r => r.percent == null ? `Unknown (denominator zero; ${r.numerator}/${r.denominator})` : `${r.percent.toFixed(2)}% (${r.numerator}/${r.denominator})`;
export function summaryMarkdown(r) {
  const p = r.population;
  const lines = [
    '# FloatPlanWizard Day 40 baseline', '',
    '**Historical evidence is incomplete. See the accompanying validation.md for verification status.**', '',
    `- Report UTC T: ${r.T}`, `- Window start W: ${r.W}`,
    '- Window: W <= action timestamp < T; lifetime measures end at T.',
    `- Definition: ${r.definition_version}`, `- Report code SHA-256: ${r.report_code_sha256 || 'not supplied'}`,
    `- Source export SHA-256: ${r.source_export_sha256 || 'not supplied'}`, '',
    '## Population', '',
    `Examined ${p.examined}; active admins excluded ${p.active_admins_excluded}; reviewed test accounts excluded ${p.reviewed_test_fixtures_excluded}; other verified invalid accounts excluded ${p.verified_invalid_excluded}.`,
    `Final population N = **${p.final_valid_population}**. Fixture review pending: ${p.fixture_review_pending}.`, '',
    '## Metrics', '',
    '| Metric | Known positive | Known negative | Unknown |', '|---|---:|---:|---:|',
    `| 30-day activity | ${r.activity.active} | ${r.activity.inactive} | ${r.activity.unknown} |`,
    `| At least one legitimate use | ${r.route_use.at_least_one} | 0 | ${r.route_use.no_proven_use} |`,
    `| Lifetime repeat use | ${r.route_use.repeat} | 0 | ${p.final_valid_population-r.route_use.repeat} |`
  ];
  for (const [label, field] of [['Sharing','sharing'],['Completion','completion'],['Return after completion','return_after_completion']]) {
    for (const [horizon, key] of [['Lifetime','lifetime'],['30-day','trailing_30d']]) {
      const v = r[field][key]; lines.push(`| ${horizon} ${label.toLowerCase()} | ${v.yes} | ${v.no} | ${v.unknown} |`);
    }
  }
  lines.push('', `- Active rate: **${rateText(r.activity.rate)}**, evidenced minimum.`,
    `- Primary repeat rate: **${rateText(r.route_use.primary_rate)}** — observed repeat / evidenced planning members.`,
    `- Secondary repeat rate: **${rateText(r.route_use.secondary_rate)}** — observed repeat / all valid members.`,
    `- Route-use uncertainty: ${r.route_use.unknown_or_ambiguous} members have an unresolved classification or incomplete history.`,
    '', 'Zero known positives is not evidence that the true total is zero. Unknowns stay in the population.',
    '', '## Included members', '',
    '| ID | Name | Email | Activity | Legitimate use | Repeat |', '|---|---|---|---|---|---|');
  for (const m of r.members.filter(m=>m.included)) lines.push(`| ${m.user_id} | ${md([m.first_name,m.last_name].filter(Boolean).join(' '))} | ${md(m.email)} | ${m.activity.status} | ${m.route_use.has_legitimate_use} | ${m.route_use.repeat} |`);
  lines.push('', '## Exclusions', '', '| ID | Name | Email | Category | Reason |', '|---|---|---|---|---|');
  for (const m of r.members.filter(m=>!m.included)) lines.push(`| ${m.user_id} | ${md([m.first_name,m.last_name].filter(Boolean).join(' '))} | ${md(m.email)} | ${m.exclusion_category} | ${md(m.exclusion_reason)} |`);
  lines.push('', '## Definitions and limitations', '',
    '- Activity requires verified substantive member action. Route rename-only/ambiguous updates, generic posts, views, logins and automatic events do not qualify.',
    '- Zero-leg saved routes can prove activity but never establish a legitimate route/trip use.',
    '- Repeat use requires distinct normalized uses with an evidenced strictly later beginning. Draft rebuilds, repeated edits and copy creation alone do not qualify.',
    '- Return requires a different legitimate use beginning strictly after a verified completion.',
    '- No member is declared inactive without sufficient observation coverage; current evidence cannot certify that coverage.',
    ...r.limitations.map(l => '- ' + l), '',
    '## Reproduction', '',
    'The retained source-export.csv and population-review.json are the inputs. source-snapshot.json preserves parsed evidence. members.csv and report.json contain member-level evidence and uncertainty reasons.',
    'Use the documented local Node CLI with these retained inputs. A fresh database capture is a new report, not a historical replay.', '');
  return lines.join('\n');
}
function outsideRepo(path) {
  const p = resolve(path);
  if (p === repoRoot || p.startsWith(repoRoot + sep)) throw new Error('Retain member data outside the application/web root');
  return p;
}
export function run(args) {
  const command = args.shift(), opts = {};
  while (args.length) {
    const key = args.shift();
    if (!key.startsWith('--') || !args.length) throw new Error('Use --option value');
    opts[key.slice(2)] = args.shift();
  }
  if (command === 'sql') {
    if (!opts.out) throw new Error('sql requires --out');
    const output = outsideRepo(opts.out); mkdirSync(dirname(output), {recursive:true});
    writeFileSync(output, buildCombinedExportSQL(opts.T) + '\n', {flag:'wx',mode:0o600});
    return { sql:output };
  }
  if (command !== 'report' || !opts.input || !opts.out) throw new Error('Usage: cli.mjs sql --out file.sql | report --input source-export.csv --out new-directory [--review population-review.json]');
  const output = outsideRepo(opts.out);
  if (existsSync(output)) throw new Error('Output directory already exists; retained baselines are never overwritten');
  const raw = readFileSync(opts.input,'utf8');
  const snapshot = fromPackets(importPackets(raw));
  const review = opts.review ? JSON.parse(readFileSync(opts.review,'utf8')) : {};
  const report = buildReport(snapshot, review);
  report.source_export_sha256 = sha256(raw);
  report.report_code_sha256 = sha256(['evidence.mjs','export-sql.mjs','route-uses.mjs','baseline.mjs','cli.mjs'].map(name=>name+'\n'+readFileSync(resolve(scriptDir,name),'utf8')).join('\n'));
  mkdirSync(dirname(output), {recursive:true}); mkdirSync(output,{mode:0o700});
  for (const [name, contents] of Object.entries({
    'source-export.csv':raw, 'source-snapshot.json':JSON.stringify(snapshot,null,2)+'\n',
    'population-review.json':JSON.stringify(review,null,2)+'\n', 'report.json':JSON.stringify(report,null,2)+'\n',
    'members.csv':memberCsv(report), 'summary.md':summaryMarkdown(report)
  })) writeFileSync(resolve(output,name),contents,{flag:'wx',mode:0o600});
  return { output, T:report.T, W:report.W, population:report.population, activity:report.activity };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { console.log(JSON.stringify(run(process.argv.slice(2)),null,2)); }
  catch (err) { console.error(err.message); process.exitCode=1; }
}
