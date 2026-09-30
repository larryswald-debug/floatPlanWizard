import { id, utc, windowStart, within, flag, upper, unique, sortIds, rowMap, ratio, LIMITATIONS } from './evidence.mjs';
import { REQUIRED_SOURCES } from './export-sql.mjs';
import { normalizeRouteUses } from './route-uses.mjs';

export const DEFINITION_VERSION = 'Day40RetentionBaseline-v1';
const activityTypes = {
  vessel_created: 'vessel', vessel_updated: 'vessel',
  user_route_created: 'user_route', user_route_updated: 'user_route',
  route_created: 'route_instance', route_updated: 'route_instance',
  float_plan_created: 'float_plan', float_plan_updated: 'float_plan'
};
const shareSources = ['basic_save_send', 'basic_review_send', 'premium_save_send'];
const uuid = v => /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-(?:[a-f0-9]{16}|[a-f0-9]{4}-[a-f0-9]{12})$/i.test(String(v || ''));
const getMeta = e => typeof e.metadata_json === 'string' ? JSON.parse(e.metadata_json) : (e.metadata_json || {});

export function fromPackets(packets) {
  if (!Array.isArray(packets) || !packets.length) throw new Error('No evidence packets');
  const T = utc(packets[0].T), W = utc(packets[0].W);
  if (!T || W !== windowStart(T)) throw new Error('Invalid fixed T/W');
  const snapshot = { T, W, source_manifest: [] };
  for (const p of packets) {
    if (p.format_version !== 1 || utc(p.T) !== T || utc(p.W) !== W) throw new Error('Inconsistent packet format or T/W');
    if (!REQUIRED_SOURCES.includes(p.source) || snapshot[p.source]) throw new Error(`Unexpected/duplicate source: ${p.source}`);
    const count = typeof p.row_count === 'number' ? p.row_count :
      (typeof p.row_count === 'string' && /^(0|[1-9]\d*)$/.test(p.row_count) ? Number(p.row_count) : NaN);
    if (!Array.isArray(p.rows) || !Number.isSafeInteger(count) || count < 0 || p.rows.length !== count) {
      throw new Error(`Incomplete/truncated source: ${p.source}`);
    }
    snapshot[p.source] = p.rows;
    snapshot.source_manifest.push({ source: p.source, row_count: count, captured_at_utc: p.captured_at_utc });
  }
  for (const name of REQUIRED_SOURCES) if (!snapshot[name]) throw new Error(`Missing source: ${name}`);
  return snapshot;
}

export function buildReport(s, review = {}) {
  const T = utc(s.T), W = utc(s.W);
  if (!T || W !== windowStart(T)) throw new Error('Invalid report T/W');
  for (const source of REQUIRED_SOURCES) if (!Array.isArray(s[source])) throw new Error(`Missing source: ${source}`);
  const users = rowMap(s.users, 'user_id');
  const plans = rowMap(s.floatplans, 'floatplan_id');
  const routes = rowMap(s.route_instances);
  const entities = { vessel: rowMap(s.vessels), user_route: rowMap(s.user_routes), route_instance: routes, float_plan: plans };
  const results = new Map([...users.keys()].sort(sortIds).map(user_id => [user_id, {
    user_id, first_name: users.get(user_id).first_name || '', last_name: users.get(user_id).last_name || '',
    email: users.get(user_id).email || '', included: true, exclusion_category: '', exclusion_reason: '',
    fixture_review: review.other_current_users_are_test ? 'REVIEWED' : 'REQUIRES_REVIEW',
    account_created_utc: null, observation_start_utc: W,
    activity: { status: 'UNKNOWN', reason: 'INSUFFICIENT_EVIDENCE', evidence: [] },
    sharing_evidence: [], completion_evidence: [], reasons: []
  }]));
  if (review.other_current_users_are_test && (utc(review.T) !== T || !Array.isArray(review.real_user_ids) || !review.reason)) {
    throw new Error('Reviewed population must specify this snapshot T, real_user_ids and reason');
  }
  const realIds = new Set((review.real_user_ids || []).map(v => { const k = id(v); if (!k) throw new Error('Invalid reviewed user ID'); return k; }));
  const explicit = new Map();
  for (const e of review.exclusions || []) {
    if (!id(e.user_id) || !['TEST_FIXTURE', 'VERIFIED_INVALID'].includes(e.category) || !e.reason || explicit.has(id(e.user_id))) {
      throw new Error('Invalid or duplicate reviewed exclusion');
    }
    explicit.set(id(e.user_id), e);
  }
  for (const r of results.values()) {
    const admin = s.member_entitlements.some(m => id(m.user_id) === r.user_id && upper(m.entitlement_type) === 'ADMIN' &&
      upper(m.status) === 'ACTIVE' && utc(m.starts_at_utc) && utc(m.starts_at_utc) <= T &&
      (m.expires_at_utc == null || (utc(m.expires_at_utc) && utc(m.expires_at_utc) > T)) && m.revoked_at_utc == null);
    const e = explicit.get(r.user_id);
    if (admin) Object.assign(r, { included: false, exclusion_category: 'ACTIVE_ADMIN', exclusion_reason: 'Existing active admin-entitlement rule at T' });
    else if (e) Object.assign(r, { included: false, exclusion_category: e.category, exclusion_reason: e.reason });
    else if (review.other_current_users_are_test && !realIds.has(r.user_id)) Object.assign(r, {
      included: false, exclusion_category: 'TEST_FIXTURE', exclusion_reason: review.reason
    });
  }

  const diagnostics = [], validatedEvents = [], canonicalEvents = [], tripBeginnings = [], tripCompletions = [], planningBeginnings = [];
  const note = (uid, reason) => { if (results.has(uid)) results.get(uid).reasons.push(reason); };
  const owns = (uid, type, entity, requireCurrent = false) => {
    const row = entities[type]?.get(id(entity));
    return id(entity) && (row ? id(row.user_id) === uid : !requireCurrent);
  };
  const planOwner = (uid, pid, requireCurrent = false) => owns(uid, 'float_plan', pid, requireCurrent);
  const addActivity = (uid, source_ref, at_utc, reason, extra = {}) => {
    const member = results.get(uid);
    if (!member || (at_utc && at_utc >= T)) return;
    member.activity.evidence.push({ source_ref, at_utc, reason, ...extra });
  };
  const addShare = (uid, pid, ref, at, source = '') => {
    if (!results.has(uid) || !at || at >= T || !planOwner(uid, pid)) return;
    results.get(uid).sharing_evidence.push({ floatplan_id: id(pid), source_ref: ref, at_utc: at });
    addActivity(uid, ref, at, 'SUCCESSFUL_SHARE');
    const plan = plans.get(id(pid));
    if (source === 'basic_save_send' && plan && planOwner(uid, pid, true) &&
        !id(plan.route_instance_id) && flag(plan.basic_details_present) && flag(plan.basic_required_fields_present)) {
      // A successful Basic operational send proves substantive planning. Its
      // share clock does not establish when this distinct use first began.
      planningBeginnings.push({ user_id: uid, floatplan_id: id(pid), route_instance_id: null,
        at_utc: null, source_ref: ref });
    }
  };
  const eventMap = rowMap(s.product_events);
  const recovery = new Map();
  for (const e of eventMap.values()) {
    const uid = id(e.user_id), eid = id(e.entity_id), at = utc(e.occurred_at_utc);
    if (!results.has(uid)) { diagnostics.push({ source_ref: `product_events:${e.id}`, reason: 'OWNER_NOT_IN_CURRENT_USERS' }); continue; }
    if (!at || at >= T || at <= '1970-01-01T00:00:00.000000Z' || at !== utc(e.created_at_utc) || !flag(e.metadata_valid) || !flag(e.metadata_object)) {
      note(uid, `UNVERIFIED_PRODUCT_EVENT:${e.id}`); continue;
    }
    const ref = `product_events:${e.id}`;
    if (e.event_name === 'sign_up' && e.event_source === 'member_signup' && e.entity_type === 'user' && eid === uid) {
      const r = results.get(uid);
      if (r.account_created_utc && r.account_created_utc !== at) { r.account_created_utc = null; r.creation_conflict = true; }
      else if (!r.creation_conflict) r.account_created_utc = at;
    }
    if (activityTypes[e.event_name]) {
      if (e.event_source !== 'member_api' || e.entity_type !== activityTypes[e.event_name] || !owns(uid, e.entity_type, eid)) {
        note(uid, `ACTIVITY_SOURCE_OR_OWNER_MISMATCH:${e.id}`); continue;
      }
      const key = String(e.idempotency_key || '');
      const validKey = (key.startsWith('member_activity:') && uuid(key.slice(16))) || (key.startsWith(e.event_name + ':') && /^[A-Za-z0-9:_-]{1,191}$/.test(key));
      if (!validKey) { note(uid, `ACTIVITY_IDEMPOTENCY_UNVERIFIED:${e.id}`); continue; }
      validatedEvents.push({ ...e, user_id: uid, entity_id: eid, occurred_at_utc: at });
      if (['user_route_updated', 'route_updated'].includes(e.event_name)) {
        note(uid, `ROUTE_UPDATE_MAY_BE_RENAME_ONLY:${e.id}`); continue;
      }
      addActivity(uid, ref, at, e.event_name.toUpperCase());
    }
    const completed = (e.event_name === 'premium_send_completed' && e.event_source === 'premium_save_send') ||
      (e.event_name === 'basic_send_completed' && ['basic_save_send', 'basic_review_send'].includes(e.event_source));
    let completedKeyValid = e.idempotency_key === `${e.event_name}:float_plan:${eid}`;
    if (e.event_source === 'basic_review_send') {
      const receiptId = /^basic_send_completed:basic_review_receipt:([1-9][0-9]*)$/.exec(String(e.idempotency_key || ''))?.[1];
      const receipt = s.basic_review_send_receipts.find(r => id(r.id) === receiptId);
      completedKeyValid = !!receiptId && (!receipt || (id(receipt.user_id) === uid && id(receipt.float_plan_id) === eid));
    }
    if (completed && completedKeyValid && e.entity_type === 'float_plan' && eid && planOwner(uid, eid)) {
      // Existing writers validate actor/entity/source. Receipts and this retained
      // product evidence are independent positives, not extra members or trips.
      addShare(uid, eid, ref, at, e.event_source);
    }
    if (e.event_name.startsWith('recovery_share_')) {
      const state = e.event_name.slice('recovery_share_'.length), token = String(e.request_correlation_id || '');
      if (!['started', 'succeeded', 'failed'].includes(state) || !uuid(token) || e.entity_type !== 'float_plan' ||
          !eid || !shareSources.includes(e.event_source) || !flag(e.metadata_empty) ||
          e.idempotency_key !== `recovery_share:${token.toLowerCase()}:${state}` || !planOwner(uid, eid)) {
        note(uid, `INVALID_RECOVERY_SHARE_EVIDENCE:${e.id}`); continue;
      }
      const key = `${uid}:${token}`;
      if (!recovery.has(key)) recovery.set(key, []);
      recovery.get(key).push({ ...e, at, state });
    }
  }
  for (const events of recovery.values()) {
    const start = events.filter(e => e.state === 'started'), end = events.filter(e => e.state !== 'started');
    const uid = id(events[0].user_id);
    if (start.length !== 1 || end.length !== 1 || start[0].entity_id !== end[0].entity_id ||
        start[0].event_source !== end[0].event_source || Number(start[0].id) >= Number(end[0].id) || start[0].at > end[0].at) {
      note(uid, 'UNRESOLVED_OR_INVALID_SHARE_ATTEMPT'); continue;
    }
    if (end[0].state === 'succeeded') addShare(uid, end[0].entity_id, `product_events:${end[0].id}`, end[0].at, end[0].event_source);
  }
  for (const r of rowMap(s.basic_review_send_receipts).values()) {
    if (upper(r.status) === 'SENT') addShare(id(r.user_id), r.float_plan_id, `basic_review_send_receipts:${r.id}`, utc(r.completed_at_utc));
  }
  for (const r of rowMap(s.premium_send_receipts).values()) {
    if (Number(r.recipient_count) > 0) addShare(id(r.user_id), r.float_plan_id, `premium_send_receipts:${r.id}`, utc(r.committed_at_utc));
  }

  for (const e of rowMap(s.floatplan_events).values()) {
    const uid = id(e.user_id), pid = id(e.floatplan_id), rid = id(e.route_instance_id);
    if (!results.has(uid) || e.voided_at_utc != null || id(e.actor_user_id) !== uid || !planOwner(uid, pid) ||
      (rid && !owns(uid, 'route_instance', rid))) continue;
    const accepted = (e.source === 'active_cruise_checkin' && e.event_type === 'CHECKIN_RECEIVED') ||
      (e.source === 'active_cruise_route_action' && ['ROUTE_LEG_STARTED', 'ROUTE_LEG_COMPLETED', 'FLOATPLAN_CLOSED'].includes(e.event_type));
    if (!accepted) continue;
    // Old canonical occurrence clocks had CF/JDBC binding issues. Corroborate
    // with the same owned operation's DB-UTC timeline post; never shift clocks.
    const postMatches = flag(e.source_post_exists) && id(e.source_post_author_user_id) === uid &&
      id(e.source_post_owner_user_id) === uid && id(e.source_post_floatplan_id) === pid &&
      e.source_post_event_type === ({ CHECKIN_RECEIVED: 'checkin', ROUTE_LEG_STARTED: 'route_leg_started',
        ROUTE_LEG_COMPLETED: 'route_leg_completed', FLOATPLAN_CLOSED: 'floatplan_closed' })[e.event_type];
    const at = postMatches ? utc(e.source_post_created_at_utc) : null;
    if (at && at >= T) continue;
    const fact = { user_id: uid, floatplan_id: pid, route_instance_id: rid, at_utc: at, source_ref: `floatplan_events:${e.id}` };
    canonicalEvents.push({ ...e, ...fact });
    addActivity(uid, fact.source_ref, at, e.event_type, { timestamp_provenance: at ? 'OWNED_OPERATION_POST_DB_UTC' : 'UNVERIFIED_HISTORICAL_CANONICAL_CLOCK' });
    if (!at) note(uid, `CANONICAL_ACTION_UTC_UNVERIFIED:${e.id}`);
    const route = routes.get(rid);
    if (at && ((e.event_type === 'ROUTE_LEG_STARTED' && Number(e.route_leg_order) === 1) ||
        (e.event_type === 'CHECKIN_RECEIVED' && upper(e.event_status) === 'ON_TRACK' && route && utc(route.started_at_raw) === at))) {
      tripBeginnings.push(fact);
    }
  }
  for (const c of rowMap(s.floatplan_captain_log_entries).values()) {
    const uid = id(c.user_id), at = utc(c.created_utc);
    if (at && planOwner(uid, c.floatplan_id, true)) addActivity(uid, `floatplan_captain_log_entries:${c.id}`, at, 'CAPTAIN_LOG');
  }
  for (const p of rowMap(s.voyage_delay_posts).values()) {
    const uid = id(p.author_user_id), at = utc(p.created_utc);
    if (p.author_type === 'system' && p.post_type === 'system_event' && p.event_type === 'delay_added' &&
        uid === id(p.owner_user_id) && planOwner(uid, p.floatplan_id, true) && at) {
      addActivity(uid, `voyage_posts:${p.id}`, at, 'MEMBER_MANUAL_DELAY');
    }
  }
  for (const c of rowMap(s.floatplan_companion_events).values()) {
    const uid = id(c.user_id), pid = id(c.floatplan_id), at = utc(c.processed_at_utc);
    if (upper(c.process_status) !== 'PROCESSED' || c.event_type !== 'CHECKIN' || !at || !planOwner(uid, pid)) continue;
    // No stable cross-table operation token is exported. Preserve supporting
    // references; all metrics count distinct members rather than raw events.
    addActivity(uid, `floatplan_companion_events:${c.id}`, at, 'PROCESSED_COMPANION_CHECKIN');
  }
  for (const p of plans.values()) {
    const uid = id(p.user_id), pid = id(p.floatplan_id), rid = id(p.route_instance_id), route = routes.get(rid);
    if (!results.has(uid) || upper(p.status) !== 'CLOSED' || !p.closed_at_raw) continue;
    if (rid && (!route || id(route.user_id) !== uid || upper(route.status) !== 'COMPLETED' || !route.completed_at_raw)) {
      note(uid, `COMPLETION_ROUTE_CONTRACT_UNVERIFIED:${pid}`); continue;
    }
    const closures = canonicalEvents.filter(e => e.floatplan_id === pid && e.event_type === 'FLOATPLAN_CLOSED' && e.at_utc);
    const at = closures.length ? closures.map(e => e.at_utc).sort()[0] : null;
    const fact = { user_id: uid, floatplan_id: pid, route_instance_id: rid, at_utc: at,
      source_ref: `floatplans:${pid}`, raw_closed_at: p.closed_at_raw,
      timestamp_provenance: at ? 'CORROBORATED_OPERATION_DB_UTC' : 'LEGACY_CLOCK_UNVERIFIED' };
    results.get(uid).completion_evidence.push(fact);
    tripCompletions.push(fact);
    addActivity(uid, fact.source_ref, at, 'VERIFIED_COMPLETED_TRIP');
    if (!at) note(uid, `COMPLETION_UTC_UNVERIFIED:${pid}`);
  }

  const normalized = normalizeRouteUses({ ...s, as_of_utc: T, members: s.users, product_events: validatedEvents,
    trip_beginnings: tripBeginnings, trip_completions: tripCompletions, planning_beginnings: planningBeginnings });
  const useMembers = new Map(normalized.per_member.map(r => [id(r.user_id), r]));
  const horizon = (facts, window) => ({
    status: facts.some(f => window ? within(f.at_utc, W, T) : (!f.at_utc || f.at_utc < T)) ? 'YES' : 'UNKNOWN',
    reason: facts.some(f => window ? within(f.at_utc, W, T) : (!f.at_utc || f.at_utc < T)) ? 'VERIFIED_POSITIVE_EVIDENCE' : 'INSUFFICIENT_EVIDENCE'
  });
  for (const r of results.values()) {
    if (r.account_created_utc && r.account_created_utc > W) r.observation_start_utc = r.account_created_utc;
    const evidence = new Map(r.activity.evidence.map(e => [e.source_ref, e]));
    r.activity.evidence = [...evidence.values()].sort((a, b) => String(a.at_utc).localeCompare(String(b.at_utc)) || a.source_ref.localeCompare(b.source_ref));
    if (r.activity.evidence.some(e => within(e.at_utc, r.observation_start_utc, T))) {
      r.activity.status = 'ACTIVE'; r.activity.reason = 'VERIFIED_MEANINGFUL_ACTION_IN_WINDOW';
    } else r.reasons.push('NO_COMPLETE_RETENTION_OBSERVATION_COVERAGE');
    r.route_use = useMembers.get(r.user_id) || { uses: [], has_legitimate_use: 'unknown', repeat: 'unknown', reasons: ['INSUFFICIENT_ROUTE_USE_EVIDENCE'] };
    r.sharing_lifetime = horizon(r.sharing_evidence, false); r.sharing_30d = horizon(r.sharing_evidence, true);
    r.completion_lifetime = horizon(r.completion_evidence, false); r.completion_30d = horizon(r.completion_evidence, true);
    r.reasons = unique([...r.reasons, ...(r.route_use.reasons || [])]);
  }
  const members = [...results.values()], included = members.filter(m => m.included), N = included.length;
  const count = fn => included.filter(fn).length;
  const countHorizon = key => ({ yes: count(m => m[key]?.status === 'YES'), no: 0, unknown: count(m => m[key]?.status !== 'YES') });
  const P = count(m => String(m.route_use.has_legitimate_use).toUpperCase() === 'YES');
  const R = count(m => String(m.route_use.repeat).toUpperCase() === 'YES');
  const A = count(m => m.activity.status === 'ACTIVE');
  return {
    definition_version: DEFINITION_VERSION, T, W, population_review: review,
    source_manifest: s.source_manifest || [], limitations: LIMITATIONS,
    population: { examined: members.length, active_admins_excluded: members.filter(m => m.exclusion_category === 'ACTIVE_ADMIN').length,
      reviewed_test_fixtures_excluded: members.filter(m => m.exclusion_category === 'TEST_FIXTURE').length,
      verified_invalid_excluded: members.filter(m => m.exclusion_category === 'VERIFIED_INVALID').length,
      final_valid_population: N, fixture_review_pending: count(m => m.fixture_review === 'REQUIRES_REVIEW'),
      reviewed_real_ids_absent: [...realIds].filter(k => !users.has(k)),
      exclusions: members.filter(m => !m.included).map(m => ({ user_id: m.user_id, category: m.exclusion_category, reason: m.exclusion_reason })) },
    activity: { active: A, inactive: 0, unknown: N - A, rate: ratio(A, N, 'Evidenced minimum; incomplete observation coverage') },
    route_use: { at_least_one: P, repeat: R, no_proven_use: N - P,
      unknown_or_ambiguous: count(m => String(m.route_use.repeat).toUpperCase() !== 'YES' || m.route_use.reasons.length > 0),
      primary_rate: ratio(R, P, 'Observed repeat evidence / evidenced planning members; incomplete lifetime history'),
      secondary_rate: ratio(R, N, 'Observed repeat evidence / valid members') },
    sharing: { lifetime: countHorizon('sharing_lifetime'), trailing_30d: countHorizon('sharing_30d') },
    completion: { lifetime: countHorizon('completion_lifetime'), trailing_30d: countHorizon('completion_30d') },
    return_after_completion: {
      lifetime: { yes: count(m => String(m.route_use.returned_after_completion).toUpperCase() === 'YES'), no: 0,
        unknown: count(m => String(m.route_use.returned_after_completion).toUpperCase() !== 'YES') },
      trailing_30d: { yes: count(m => (m.route_use.return_evidence || []).some(e => within(e.subsequent_begin_at_utc, W, T))), no: 0,
        unknown: count(m => !(m.route_use.return_evidence || []).some(e => within(e.subsequent_begin_at_utc, W, T))) }
    }, members, diagnostics
  };
}
