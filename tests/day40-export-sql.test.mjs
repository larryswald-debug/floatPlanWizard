import assert from 'node:assert/strict';
import test from 'node:test';
import {
  REQUIRED_SOURCES, buildCombinedExportSQL, buildExportQueries,
  buildMetadataQuery, normalizeReportTime
} from '../scripts/retention/export-sql.mjs';

test('UTC input is explicit, calendar-valid and preserves database microseconds', () => {
  assert.equal(normalizeReportTime('2026-09-29T18:00:00Z'), '2026-09-29T18:00:00.000000Z');
  assert.equal(normalizeReportTime('2026-09-29T18:00:00.123456Z'), '2026-09-29T18:00:00.123456Z');
  assert.equal(normalizeReportTime('2024-02-29T00:00:00.001Z'), '2024-02-29T00:00:00.001000Z');
  for (const bad of [undefined, '2026-02-29T00:00:00Z', '2026-09-29T24:00:00Z',
    '2026-09-29T18:00:00-04:00', "2026-09-29T18:00:00Z'; DROP TABLE users; --"]) {
    assert.throws(() => normalizeReportTime(bad));
  }
});

test('combined export captures one database UTC boundary; split queries require a fixed boundary', () => {
  const live = buildCombinedExportSQL();
  assert.ok(live.startsWith('WITH bounds AS (SELECT UTC_TIMESTAMP(6) AS t)'));
  assert.equal((live.match(/WITH bounds AS/g) || []).length, 1);
  assert.throws(() => buildExportQueries());
  const T = '2026-09-29T18:00:00.123456Z';
  const queries = buildExportQueries(T);
  assert.equal(queries.length, REQUIRED_SOURCES.length);
  assert.equal(new Set(queries.map(query => query.name)).size, queries.length);
  for (const query of queries) {
    assert.ok(query.sql.startsWith("WITH bounds AS (SELECT CAST('2026-09-29 18:00:00.123456' AS DATETIME(6)) AS t)"));
    assert.match(query.sql, /'row_count', \(SELECT COUNT\(\*\)/);
    assert.match(query.sql, /JSON_ARRAYAGG\(/);
    assert.match(query.sql, /JSON_QUERY\(COALESCE\(/);
  }
});

test('queries remain SELECT-only and exclude private payloads beyond authorized identity fields', () => {
  const sql = buildCombinedExportSQL() + '\n' + buildMetadataQuery();
  assert.doesNotMatch(sql, /\b(?:INSERT|UPDATE|DELETE|REPLACE|CREATE|DROP|ALTER|SET|CALL|INTO\s+OUTFILE)\b/i);
  assert.doesNotMatch(sql, /SELECT\s+\*/i);
  assert.doesNotMatch(sql, /(?:recipient_email|password|share_token|note_body|payload_json|original_response_json|device_uuid)/i);
  assert.doesNotMatch(sql, /'captain_email'\s*,|'notification_contact_email'\s*,|'launch_location'\s*,/);
});

test('lineage keeps key-case conflicts and separates raw clocks from UTC evidence', () => {
  const queries = new Map(buildExportQueries('2026-09-29T18:00:00Z').map(query => [query.name, query.sql]));
  const route = queries.get('route_instances');
  assert.match(route, /\$\.SOURCE_ROUTE_INSTANCE_ID/);
  assert.match(route, /\$\.source_route_instance_id/);
  assert.match(route, /'lineage_json_valid'/);
  assert.match(route, /'started_at_raw', DATE_FORMAT\(r.started_at, '%Y-%m-%d %H:%i:%s.%f'\)/);
  assert.doesNotMatch(route, /'started_at_utc'/);
  assert.match(queries.get('floatplan_events'), /'source_post_created_at_utc'/);
  assert.match(queries.get('floatplans'), /'basic_required_fields_present'/);
});

test('only the users source exports the specifically authorized name and email fields', () => {
  const queries = buildExportQueries('2026-09-29T18:00:00Z');
  const users = queries.find(query => query.name === 'users').sql;
  assert.match(users, /'first_name', u\.fName/);
  assert.match(users, /'last_name', u\.lName/);
  assert.match(users, /'email', u\.email/);
  for (const query of queries.filter(query => query.name !== 'users')) {
    assert.doesNotMatch(query.sql, /'first_name'\s*,|'last_name'\s*,|'email'\s*,/);
  }
});


test('every UNION branch returns the same explicit UTF-8 binary collation', () => {
  const T = '2026-09-29T18:00:00.123456Z';
  const sql = buildCombinedExportSQL(T);
  assert.equal((sql.match(/SELECT CONVERT\(JSON_OBJECT\(/g) || []).length, REQUIRED_SOURCES.length);
  assert.equal((sql.match(/\) USING utf8mb4\) COLLATE utf8mb4_bin AS payload/g) || []).length, REQUIRED_SOURCES.length);
  for (const query of buildExportQueries(T)) {
    assert.match(query.sql, /SELECT CONVERT\(JSON_OBJECT\(/);
    assert.match(query.sql, /\) USING utf8mb4\) COLLATE utf8mb4_bin AS payload FROM bounds b;$/);
  }
  assert.doesNotMatch(sql, /\b(?:SET|ALTER)\b/i);
});
