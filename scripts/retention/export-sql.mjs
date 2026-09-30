// Read-only MariaDB export for the offline Day 40 baseline.
// Member names and email addresses are included by explicit user authorization.
// Each source has one row_count plus a JSON array. The importer must verify both;
// JSON_ARRAYAGG is bounded by MariaDB group_concat_max_len and may truncate.
// Never SET that limit, write data, or infer historical UTC from the session offset.

const utc = column => `DATE_FORMAT(${column}, '%Y-%m-%dT%H:%i:%s.%fZ')`;
const raw = column => `DATE_FORMAT(${column}, '%Y-%m-%d %H:%i:%s.%f')`;
const id = column => `CAST(${column} AS CHAR)`;
const quote = value => "'" + value.replaceAll("'", "''") + "'";
const object = fields => "JSON_OBJECT(\n      " + Object.entries(fields)
  .map(([name, expression]) => `${quote(name)}, ${expression}`).join(",\n      ") + "\n    )";

export function normalizeReportTime(value) {
  const match = typeof value === 'string'
    ? value.match(/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{3}|\d{6}))?Z$/)
    : null;
  if (!match) {
    throw new Error('Report time must be an explicit UTC ISO timestamp, with optional milliseconds or microseconds.');
  }
  const fraction = (match[2] || '').padEnd(6, '0');
  const millisecondValue = `${match[1]}.${fraction.slice(0, 3)}Z`;
  const parsed = new Date(millisecondValue);
  if (!Number.isFinite(parsed.getTime()) || parsed.toISOString() !== millisecondValue) {
    throw new Error('Invalid report UTC timestamp.');
  }
  return `${match[1]}.${fraction}Z`;
}

const eventNames = [
  'sign_up', 'recovery_coverage_started',
  'vessel_created', 'vessel_updated', 'user_route_created', 'user_route_updated',
  'route_created', 'route_updated', 'float_plan_created', 'float_plan_updated',
  'premium_send_completed', 'basic_send_completed',
  'recovery_share_started', 'recovery_share_succeeded', 'recovery_share_failed'
];
const safeEventJson = "CASE WHEN JSON_VALID(e.metadata_json) THEN e.metadata_json ELSE '{}' END";
const safeRouteJson = "CASE WHEN JSON_VALID(r.routegen_inputs_json) THEN r.routegen_inputs_json ELSE '{}' END";
const routeKeys = [
  'route_type', 'route_id', 'source_route_instance_id',
  'source_generated_route_id', 'source_user_route_id'
];
const routeFields = Object.fromEntries(routeKeys.flatMap(key => [key, key.toUpperCase()]
  .map(variant => [variant, `JSON_EXTRACT(${safeRouteJson}, '$.${variant}')`])));

const sources = [
  {
    name: 'users', from: 'users u', order: 'u.userId',
    fields: { user_id: id('u.userId'), first_name: 'u.fName', last_name: 'u.lName',
      email: 'u.email', created_at_raw: raw('u.created') }
  },
  {
    name: 'member_entitlements', from: "member_entitlements m", order: 'm.id',
    where: "LOWER(m.entitlement_type) = 'admin'",
    fields: { id: id('m.id'), user_id: id('m.user_id'), entitlement_type: 'm.entitlement_type',
      status: 'm.status', starts_at_utc: utc('m.starts_at_utc'),
      expires_at_utc: utc('m.expires_at_utc'), revoked_at_utc: utc('m.revoked_at_utc') }
  },
  {
    name: 'vessels', from: 'vessels v', order: 'v.vesselID',
    fields: { id: id('v.vesselID'), user_id: id('v.userId') }
  },
  {
    name: 'product_events', from: 'product_events e', order: 'e.id',
    where: `e.event_name IN (${eventNames.map(quote).join(', ')})`,
    fields: { id: id('e.id'), user_id: id('e.user_id'), event_name: 'e.event_name',
      entity_type: 'e.entity_type', entity_id: id('e.entity_id'), event_source: 'e.event_source',
      occurred_at_utc: utc('e.occurred_at_utc'), created_at_utc: utc('e.created_at_utc'),
      idempotency_key: 'e.idempotency_key', request_correlation_id: 'e.request_correlation_id',
      metadata_valid: 'COALESCE(JSON_VALID(e.metadata_json), 0)',
      metadata_object: `JSON_TYPE(${safeEventJson}) = 'OBJECT'`,
      metadata_empty: `JSON_TYPE(${safeEventJson}) = 'OBJECT' AND JSON_LENGTH(${safeEventJson}) = 0`,
      metadata_key_count: `JSON_LENGTH(${safeEventJson})`,
      metadata_json: `JSON_OBJECT('contract_version', JSON_EXTRACT(${safeEventJson}, '$.contract_version'),
        'creation_source', JSON_EXTRACT(${safeEventJson}, '$.creation_source'))` }
  },
  {
    name: 'user_routes', from: 'user_routes r', order: 'r.id',
    fields: { id: id('r.id'), user_id: id('r.user_id'), is_active: 'r.is_active',
      created_at_raw: raw('r.created_at'), updated_at_raw: raw('r.updated_at'),
      leg_count: '(SELECT COUNT(*) FROM user_route_legs l WHERE l.user_route_id = r.id)' }
  },
  {
    name: 'route_instances', from: 'route_instances r', order: 'r.id',
    fields: { id: id('r.id'), user_id: id('r.user_id'), status: 'r.status',
      generated_route_id: id('r.generated_route_id'), template_route_code: 'r.template_route_code',
      created_at_raw: raw('r.created_at'), updated_at_raw: raw('r.updated_at'),
      started_at_raw: raw('r.started_at'), completed_at_raw: raw('r.completed_at'),
      leg_count: '(SELECT COUNT(*) FROM route_instance_legs l WHERE l.route_instance_id = r.id)',
      lineage_json_valid: "COALESCE(JSON_VALID(r.routegen_inputs_json), 0)",
      lineage_json_present: "r.routegen_inputs_json IS NOT NULL AND TRIM(r.routegen_inputs_json) <> ''",
      routegen_inputs_json: object(routeFields) }
  },
  {
    name: 'route_instance_leg_progress', from: 'route_instance_leg_progress p',
    order: 'p.user_id, p.route_instance_id, p.leg_order',
    fields: { user_id: id('p.user_id'), route_instance_id: id('p.route_instance_id'),
      leg_order: 'p.leg_order', status: 'p.status',
      leg_started_at_raw: raw('p.leg_started_at'), completed_at_raw: raw('p.completed_at') }
  },
  {
    name: 'floatplans', from: 'floatplans f', order: 'f.floatPlanId',
    fields: { floatplan_id: id('f.floatPlanId'), user_id: id('f.userId'), status: 'f.status',
      route_instance_id: id('f.route_instance_id'), route_day_number: 'f.route_day_number',
      date_created_raw: raw('f.dateCreated'), last_update_raw: raw('f.lastUpdate'),
      closed_at_raw: raw('f.closedAt'), checked_in_at_raw: raw('f.checkedInAt'),
      activated_at_raw: raw('f.activatedAt'), initial_sent_at_raw: raw('f.initialSentAt'),
      basic_details_present: '(SELECT COUNT(*) > 0 FROM floatplan_basic_details d WHERE d.floatplan_id = f.floatPlanId)',
      basic_required_fields_present: `(SELECT COUNT(*) > 0 FROM floatplan_basic_details d
        WHERE d.floatplan_id = f.floatPlanId
          AND CHAR_LENGTH(TRIM(COALESCE(d.vessel_name, ''))) > 0
          AND CHAR_LENGTH(TRIM(COALESCE(d.operator_name, ''))) > 0
          AND CHAR_LENGTH(TRIM(COALESCE(d.captain_name, ''))) > 0
          AND CHAR_LENGTH(TRIM(COALESCE(d.captain_email, ''))) > 0
          AND CHAR_LENGTH(TRIM(COALESCE(d.notification_contact_name, ''))) > 0
          AND CHAR_LENGTH(TRIM(COALESCE(d.notification_contact_email, ''))) > 0
          AND CHAR_LENGTH(TRIM(COALESCE(d.launch_location, ''))) > 0
          AND CHAR_LENGTH(TRIM(COALESCE(d.destination_location, ''))) > 0
          AND (d.authority_id > 0 OR d.authority_id = -1))` }
  },
  {
    name: 'basic_review_send_receipts', from: 'basic_review_send_receipts r', order: 'r.id',
    fields: { id: id('r.id'), user_id: id('r.user_id'), float_plan_id: id('r.float_plan_id'),
      status: 'r.status', created_at_utc: utc('r.created_at_utc'),
      completed_at_utc: utc('r.completed_at_utc') }
  },
  {
    name: 'premium_send_receipts', from: 'premium_send_receipts r', order: 'r.id',
    fields: { id: id('r.id'), user_id: id('r.user_id'), float_plan_id: id('r.float_plan_id'),
      recipient_count: 'r.recipient_count', created_at_utc: utc('r.created_at_utc'),
      committed_at_utc: utc('r.committed_at_utc') }
  },
  {
    name: 'floatplan_events',
    from: `floatplan_events e
      LEFT JOIN voyage_posts p ON p.id = e.source_post_id
      LEFT JOIN voyage_streams s ON s.id = p.stream_id`,
    order: 'e.id',
    fields: { id: id('e.id'), user_id: id('e.user_id'), floatplan_id: id('e.floatplan_id'),
      route_instance_id: id('e.route_instance_id'), route_leg_order: 'e.route_leg_order',
      event_type: 'e.event_type', event_status: 'e.event_status', source: 'e.source',
      actor_user_id: id('e.actor_user_id'), occurred_at_utc: utc('e.occurred_at_utc'),
      voided_at_utc: utc('e.voided_at_utc'), source_post_id: id('e.source_post_id'),
      source_monitoring_id: id('e.source_monitoring_id'), idempotency_key: 'e.idempotency_key',
      source_post_exists: 'p.id IS NOT NULL', source_post_created_at_utc: utc('p.created_utc'),
      source_post_author_user_id: id('p.author_user_id'), source_post_author_type: 'p.author_type',
      source_post_type: 'p.post_type', source_post_event_type: 'p.event_type',
      source_post_floatplan_id: id('s.floatplan_id'), source_post_owner_user_id: id('s.owner_user_id') }
  },
  {
    name: 'floatplan_captain_log_entries', from: 'floatplan_captain_log_entries c', order: 'c.id',
    fields: { id: id('c.id'), user_id: id('c.user_id'), floatplan_id: id('c.floatplan_id'),
      route_instance_id: id('c.route_instance_id'), voyage_post_id: id('c.voyage_post_id'),
      created_utc: utc('c.created_utc') }
  },
  {
    name: 'voyage_delay_posts',
    from: 'voyage_posts p LEFT JOIN voyage_streams s ON s.id = p.stream_id', order: 'p.id',
    where: "p.event_type = 'delay_added'",
    fields: { id: id('p.id'), stream_id: id('p.stream_id'), author_user_id: id('p.author_user_id'),
      author_type: 'p.author_type', post_type: 'p.post_type', event_type: 'p.event_type',
      owner_user_id: id('s.owner_user_id'), floatplan_id: id('s.floatplan_id'),
      created_utc: utc('p.created_utc') }
  },
  {
    name: 'floatplan_companion_events', from: 'floatplan_companion_events c', order: 'c.id',
    fields: { id: id('c.id'), user_id: id('c.user_id'), floatplan_id: id('c.floatplan_id'),
      route_instance_id: id('c.route_instance_id'), event_type: 'c.event_type',
      canonical_status: 'c.canonical_status', process_status: 'c.process_status',
      received_at_utc: utc('c.received_at_utc'), processed_at_utc: utc('c.processed_at_utc') }
  }
];

export const REQUIRED_SOURCES = Object.freeze(sources.map(source => source.name));

function boundsSql(T, allowLive = false) {
  if (T === undefined && allowLive) return 'WITH bounds AS (SELECT UTC_TIMESTAMP(6) AS t)';
  return `WITH bounds AS (SELECT CAST(${quote(normalizeReportTime(T).replace('T', ' ').replace('Z', ''))} AS DATETIME(6)) AS t)`;
}

function sourceSelect(source) {
  const where = source.where ? ` WHERE ${source.where}` : '';
  const count = `(SELECT COUNT(*) FROM ${source.from}${where})`;
  const rows = `(SELECT JSON_ARRAYAGG(${object(source.fields)} ORDER BY ${source.order})
      FROM ${source.from}${where})`;
  // Source columns use different legacy collations; normalize only the result expression.
  return `SELECT CONVERT(JSON_OBJECT(
    'format_version', 1,
    'source', ${quote(source.name)},
    'T', ${utc('b.t')},
    'W', ${utc('b.t - INTERVAL 30 DAY')},
    'captured_at_utc', ${utc('UTC_TIMESTAMP(6)')},
    'row_count', ${count},
    'rows', JSON_QUERY(COALESCE(${rows}, '[]'), '$')
  ) USING utf8mb4) COLLATE utf8mb4_bin AS payload FROM bounds b`;
}

export function buildExportQueries(T) {
  const bounds = boundsSql(T);
  return sources.map(source => ({ name: source.name, sql: bounds + '\n' + sourceSelect(source) + ';' }));
}

export function buildCombinedExportQuery(T) {
  return boundsSql(T, true) + '\n' + sources.map(sourceSelect).join('\nUNION ALL\n') + ';';
}

export const buildCombinedExportSQL = buildCombinedExportQuery;

// Apart from the authorized member name/email fields, no personal content is selected.
// Passwords, notes, locations, mail bodies, response JSON, device identifiers,
// and authorization/share tokens remain excluded.
export function buildMetadataQuery() {
  return `SELECT JSON_OBJECT(
    'database', DATABASE(),
    'server_version', VERSION(),
    'database_user', CURRENT_USER(),
    'captured_at_utc', ${utc('UTC_TIMESTAMP(6)')},
    'session_time_zone', @@session.time_zone,
    'global_time_zone', @@global.time_zone,
    'current_server_utc_offset_minutes', TIMESTAMPDIFF(MINUTE, UTC_TIMESTAMP(), NOW()),
    'json_arrayagg_limit_bytes', @@session.group_concat_max_len
  ) AS metadata;`;
}
