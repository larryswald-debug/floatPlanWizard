import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeRouteUses, normalizeUses, normalizeUtc } from '../scripts/retention/route-uses.mjs';

const T = '2026-09-29 14:33:35';
const event = (entity_id, at, entity_type = 'user_route', name = 'user_route_created', extra = {}) => ({
  id: entity_id * 10, user_id: 1, entity_id, entity_type, event_name: name,
  event_source: 'member_api', occurred_at_utc: at, ...extra
});
const saved = (id, extra = {}) => ({ id, user_id: 1, leg_count: 1, is_active: 1, ...extra });
const instance = (id, extra = {}) => ({
  id, user_id: 1, generated_route_id: id + 100, leg_count: 1, routegen_inputs_json: '{}', ...extra
});
const plan = (floatplan_id, route_instance_id = null, extra = {}) => ({
  floatplan_id, user_id: 1, route_instance_id, status: 'DRAFT', ...extra
});
const base = (extra = {}) => ({ as_of_utc: T, members: [{ user_id: 1 }],
  user_routes: [], route_instances: [], floatplans: [], product_events: [], ...extra });
const member = (snapshot) => normalizeRouteUses(snapshot).per_member[0];
const fact = (floatplan_id, route_instance_id, at_utc, extra = {}) => ({
  user_id: 1, floatplan_id, route_instance_id, at_utc, source_ref: 'accepted-test-fact', ...extra
});
const copySnapshot = (extra = {}) => base({
  user_routes: [saved(1)],
  route_instances: [
    instance(10, { routegen_inputs_json: '{"ROUTE_TYPE":"my_route","ROUTE_ID":1}' }),
    instance(20, { routegen_inputs_json: '{"SOURCE_ROUTE_INSTANCE_ID":10,"SOURCE_USER_ROUTE_ID":1}' })
  ],
  floatplans: [plan(100, 10), plan(200, 20)],
  product_events: [event(1, '2026-08-01 12:00:00')],
  ...extra
});

test('strict UTC parser accepts SQL UTC and preserves microsecond order without local parsing', () => {
  assert.equal(normalizeUtc('2024-02-29 23:59:59.123456'), '2024-02-29T23:59:59.123456Z');
  assert.equal(normalizeUtc('2026-09-01T10:00:00Z'), '2026-09-01T10:00:00.000000Z');
  for (const value of ['2026-02-29 01:00:00', '2026-09-01T10:00:00', '2026-09-01T10:00:00-04:00', '2026-09-01 25:00:00', new Date(), null]) {
    assert.equal(normalizeUtc(value), null);
  }
});

test('zero-leg routes never establish a legitimate route use', () => {
  const result = member(base({ user_routes: [saved(1, { leg_count: 0 })],
    route_instances: [instance(10, { leg_count: 0 })],
    product_events: [event(1, '2026-09-01 10:00:00'), event(10, '2026-09-02 10:00:00', 'route_instance', 'route_created')] }));
  assert.equal(result.uses.length, 0);
  assert.equal(result.has_legitimate_use, 'UNKNOWN');
});

test('saved route, generated route and rebuilt or daily Drafts remain one use', () => {
  const result = member(base({ user_routes: [saved(1)], route_instances: [
    instance(10, { template_route_code: 'MY_ROUTE', routegen_inputs_json: '{"ROUTE_ID":1}' })
  ], floatplans: [plan(100, 10, { route_day_number: 1 }), plan(101, 10, { route_day_number: 2 })],
  product_events: [event(1, '2026-09-01 10:00:00'), event(10, '2026-09-02 10:00:00', 'route_instance', 'route_created'),
    event(100, '2026-09-03 10:00:00', 'float_plan', 'float_plan_created'),
    event(101, '2026-09-04 10:00:00', 'float_plan', 'float_plan_created'),
    event(99, '2026-09-02 11:00:00', 'float_plan', 'float_plan_created')] }));
  assert.equal(result.uses.length, 1);
  assert.deepEqual(result.uses[0].plan_ids, [100, 101]);
  assert.equal(result.repeat, 'UNKNOWN');
});

test('multiple instances of the same generated route do not create repeat use', () => {
  const result = member(base({ route_instances: [instance(10), instance(11, { generated_route_id: 110 })],
    product_events: [event(10, '2026-09-01 10:00:00', 'route_instance', 'route_created'),
      event(11, '2026-09-02 10:00:00', 'route_instance', 'route_created')] }));
  assert.equal(result.uses.length, 1);
  assert.deepEqual(result.uses[0].route_instance_ids, [10, 11]);
});

test('repeated edits and legacy raw timestamps establish no UTC beginning or repeat', () => {
  const result = member(base({ user_routes: [saved(1, { created_at_raw: '2026-08-01 10:00:00', updated_at_raw: '2026-09-29 10:00:00' })],
    product_events: [event(1, '2026-09-01 10:00:00', 'user_route', 'user_route_updated'),
      event(1, '2026-09-15 10:00:00', 'user_route', 'user_route_updated')] }));
  assert.equal(result.has_legitimate_use, 'YES');
  assert.equal(result.uses[0].begin_at_utc, null);
  assert.equal(result.first_use, null);
  assert.equal(result.repeat, 'UNKNOWN');
});

test('operational copy alone collapses even when a route-created event or new Draft exists', () => {
  const snapshot = copySnapshot();
  snapshot.product_events.push(event(20, '2026-09-20 10:00:00', 'route_instance', 'route_created'),
    event(200, '2026-09-20 10:00:00', 'float_plan', 'float_plan_created'));
  const result = member(snapshot);
  assert.equal(result.uses.length, 1);
  assert.equal(result.repeat, 'UNKNOWN');
  assert.ok(result.reasons.includes('COPY_WITHOUT_SUBSEQUENT_USE_PROOF_COLLAPSED'));
});

test('verified later trip on a source copy establishes repeat and post-completion return', () => {
  const result = member(copySnapshot({
    trip_beginnings: [fact(100, 10, '2026-08-10 10:00:00'), fact(200, 20, '2026-09-20 10:00:00')],
    trip_completions: [fact(100, 10, '2026-08-12 10:00:00')]
  }));
  assert.equal(result.uses.length, 2);
  assert.equal(result.repeat, 'YES');
  assert.equal(result.returned_after_completion, 'YES');
  assert.equal(result.second_use.key, 'subsequent-trip:20');
  assert.equal(result.second_use.begin_at_utc, '2026-09-20T10:00:00.000000Z');
});

test('legacy completion can prove lifetime route-less use but never invent its UTC beginning', () => {
  const result = member(base({ floatplans: [plan(100)],
    trip_completions: [fact(100, null, null)] }));
  assert.equal(result.has_legitimate_use, 'YES');
  assert.equal(result.uses[0].begin_at_utc, null);
  assert.equal(result.returned_after_completion, 'UNKNOWN');
  assert.ok(result.reasons.includes('COMPLETION_UTC_UNKNOWN'));
});

test('blank route-less Drafts and foreign-owner facts never establish use', () => {
  const result = member(base({ floatplans: [plan(100)],
    trip_beginnings: [fact(100, null, '2026-09-01 10:00:00', { user_id: 2 })] }));
  assert.equal(result.uses.length, 0);
  assert.equal(result.repeat, 'UNKNOWN');
});

test('accepted real route-less trip facts support two distinct ordered uses', () => {
  const result = member(base({ floatplans: [plan(100), plan(200)],
    trip_beginnings: [fact(100, null, '2026-08-01 10:00:00'), fact(200, null, '2026-09-01 10:00:00')],
    trip_completions: [fact(100, null, '2026-08-02 10:00:00')] }));
  assert.equal(result.repeat, 'YES');
  assert.equal(result.returned_after_completion, 'YES');
});

test('uppercase source metadata works; contradictory case variants are held unknown', () => {
  const snapshot = copySnapshot({ trip_beginnings: [fact(200, 20, '2026-09-20 10:00:00')] });
  snapshot.route_instances[1].routegen_inputs_json = '{"SOURCE_ROUTE_INSTANCE_ID":10,"source_route_instance_id":999}';
  const result = member(snapshot);
  assert.equal(result.repeat, 'UNKNOWN');
  assert.ok(result.reasons.includes('INVALID_OR_MISSING_ROUTE_LINEAGE'));
});

test('deleted or foreign source identities do not silently produce independent repeat candidates', () => {
  const result = member(base({ user_routes: [saved(1)], route_instances: [
    instance(20, { routegen_inputs_json: '{"SOURCE_ROUTE_INSTANCE_ID":999}' })
  ], product_events: [event(1, '2026-08-01 10:00:00'), event(20, '2026-09-20 10:00:00', 'route_instance', 'route_created')] }));
  assert.equal(result.has_legitimate_use, 'YES');
  assert.equal(result.repeat, 'UNKNOWN');
  assert.ok(result.reasons.includes('MISSING_OR_FOREIGN_SOURCE_ROUTE'));
});

test('archived saved routes retain lifetime evidence and repeat requires strictly ordered timestamps', () => {
  const snapshot = base({ user_routes: [saved(1, { is_active: 0 }), saved(2)],
    route_instances: [instance(10, { routegen_inputs_json: '{"ROUTE_TYPE":"my_route","ROUTE_ID":1}' }),
      instance(20, { routegen_inputs_json: '{"ROUTE_TYPE":"my_route","ROUTE_ID":2}' })],
    product_events: [event(10, '2026-09-01 10:00:00.000001', 'route_instance', 'route_created'),
      event(20, '2026-09-01 10:00:00.000002', 'route_instance', 'route_created')] });
  assert.equal(member(snapshot).repeat, 'YES');
  snapshot.product_events[1].occurred_at_utc = snapshot.product_events[0].occurred_at_utc;
  assert.equal(member(snapshot).repeat, 'UNKNOWN');
});

test('future creation events and future accepted facts cannot establish temporal use', () => {
  const result = member(base({ user_routes: [saved(1), saved(2)], floatplans: [plan(100)],
    product_events: [event(1, '2026-09-01 10:00:00'), event(2, '2026-10-01 10:00:00')],
    trip_beginnings: [fact(100, null, '2026-10-01 10:00:00')] }));
  assert.equal(result.repeat, 'UNKNOWN');
  assert.equal(result.uses.find(u => u.key === 'saved-route:2').begin_at_utc, null);
  assert.ok(result.reasons.includes('FUTURE_FACT_IGNORED'));
});

test('same-route editing after completion never becomes a return', () => {
  const snapshot = copySnapshot({ trip_beginnings: [fact(100, 10, '2026-08-10 10:00:00')],
    trip_completions: [fact(100, 10, '2026-08-12 10:00:00')] });
  snapshot.product_events.push(event(1, '2026-09-01 10:00:00', 'user_route', 'user_route_updated'));
  assert.equal(member(snapshot).returned_after_completion, 'UNKNOWN');
});

test('single-member adapter accepts validated events and does not mutate snapshots', () => {
  const snapshot = base({ route_instances: [instance(10)] });
  const before = JSON.stringify(snapshot);
  const result = normalizeUses(snapshot, 1, { T, validatedEvents: [event(10, '2026-09-01 10:00:00', 'route_instance', 'route_created')] });
  assert.equal(result.first_use.begin_at_utc, '2026-09-01T10:00:00.000000Z');
  assert.equal(JSON.stringify(snapshot), before);
});

test('a cyclic source graph is held unknown without recursion failure', () => {
  const result = member(base({ route_instances: [
    instance(10, { routegen_inputs_json: '{"SOURCE_ROUTE_INSTANCE_ID":20}' }),
    instance(20, { routegen_inputs_json: '{"SOURCE_ROUTE_INSTANCE_ID":10}' })
  ] }));
  assert.equal(result.repeat, 'UNKNOWN');
  assert.ok(result.reasons.includes('CYCLIC_ROUTE_LINEAGE'));
});

test('initial empty named-route creation is retained separately from a legitimate-use beginning', () => {
  const result = member(base({ user_routes: [saved(1), saved(2)],
    product_events: [event(1, '2026-08-01 10:00:00'), event(2, '2026-09-01 10:00:00')] }));
  assert.equal(result.has_legitimate_use, 'YES');
  assert.equal(result.uses.length, 2);
  assert.equal(result.repeat, 'UNKNOWN');
  assert.equal(result.first_use, null);
  assert.equal(result.uses[0].initial_object_creation.length, 1);
});

test('later operations on another already-begun use cannot qualify as return', () => {
  const result = member(base({ route_instances: [instance(10), instance(20)],
    floatplans: [plan(100, 10), plan(200, 20)],
    product_events: [event(10, '2026-08-01 10:00:00', 'route_instance', 'route_created'),
      event(20, '2026-08-02 10:00:00', 'route_instance', 'route_created')],
    trip_completions: [fact(100, 10, '2026-08-10 10:00:00')],
    trip_beginnings: [fact(200, 20, '2026-09-01 10:00:00')] }));
  assert.equal(result.returned_after_completion, 'UNKNOWN');
  assert.deepEqual(result.return_evidence, []);
});

test('sanitized SQL export null case variants do not conflict with populated uppercase lineage', () => {
  const snapshot = copySnapshot({ trip_beginnings: [fact(100, 10, '2026-08-10 10:00:00'),
    fact(200, 20, '2026-09-20 10:00:00')] });
  snapshot.route_instances[0].routegen_inputs_json = {
    route_type: null, ROUTE_TYPE: 'my_route', route_id: null, ROUTE_ID: 1,
    source_route_instance_id: null, SOURCE_ROUTE_INSTANCE_ID: null
  };
  snapshot.route_instances[1].routegen_inputs_json = {
    source_route_instance_id: null, SOURCE_ROUTE_INSTANCE_ID: 10,
    source_user_route_id: null, SOURCE_USER_ROUTE_ID: 1
  };
  assert.equal(member(snapshot).repeat, 'YES');
});

test('exact report cutoff is excluded from beginnings, product events and completion facts', () => {
  const result = member(base({
    route_instances: [instance(10), instance(20)], floatplans: [plan(100, 10), plan(200, 20), plan(300)],
    product_events: [event(10, '2026-08-01 10:00:00', 'route_instance', 'route_created'),
      event(20, T, 'route_instance', 'route_created')],
    trip_beginnings: [fact(200, 20, T), fact(300, null, T)],
    trip_completions: [fact(100, 10, T)]
  }));
  assert.equal(result.repeat, 'UNKNOWN');
  assert.equal(result.returned_after_completion, 'UNKNOWN');
  assert.equal(result.uses.find(u => u.key === 'generated-route:120').begin_at_utc, null);
  assert.ok(result.uses.every(u => u.completions.length === 0));
  assert.ok(result.uses.every(u => u.key !== 'basic-trip:300'));
});

test('legacy closed Basic plan accepts null-UTC completion and keeps generic Draft unknown', () => {
  const result = member(base({ members: [{ user_id: 42 }],
    floatplans: [plan(900, null, { user_id: 42, status: 'CLOSED', closed_at_raw: '2026-09-01 10:00:00' }),
      plan(901, null, { user_id: 42 })],
    trip_completions: [fact(900, null, null, { user_id: 42 })] }));
  assert.equal(result.user_id, 42);
  assert.equal(result.has_legitimate_use, 'YES');
  assert.deepEqual(result.uses.map(u => u.key), ['basic-trip:900']);
  assert.equal(result.first_use, null);
  assert.equal(result.repeat, 'UNKNOWN');
  assert.equal(result.returned_after_completion, 'UNKNOWN');
});
