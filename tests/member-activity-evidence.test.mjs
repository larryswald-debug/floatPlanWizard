import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const eventService = read('includes/ProductEventService.cfc');
const route = read('api/v1/routeBuilder.cfc');
const plan = read('api/v1/floatplan.cfc');
const tagFunction = (source, name) => {
  const start = source.indexOf('<cffunction name="' + name + '"');
  assert.notEqual(start, -1, name);
  return source.slice(start, source.indexOf('</cffunction>', start));
};
const names = ['vessel_created','vessel_updated','shore_contact_created','shore_contact_updated',
  'operator_created','operator_updated','passenger_created','passenger_updated',
  'waypoint_created','waypoint_updated','user_route_created','user_route_updated',
  'route_created','route_updated','route_segment_updated','float_plan_created','float_plan_updated'];

test('required evidence has the exact 17-name contract and a non-remote server-only interface', () => {
  const types = eventService.slice(eventService.indexOf('private struct function memberActivityTypes()'), eventService.indexOf('public struct function recordEvent('));
  assert.deepEqual([...types.slice(types.indexOf('return {')).matchAll(/([a-z_]+)\s*=\s*"[a-z_]+"/g)].map(m => m[1]).sort(), [...names].sort());
  const required = eventService.slice(eventService.indexOf('public void function recordRequiredMemberActivity('), eventService.indexOf('private struct function memberActivityTypes()'));
  assert.match(required, /eventSource = "member_api"/);
  assert.match(required, /eventMetadata = \{\}/);
  assert.match(required, /creation_source = "member"/);
  assert.match(required, /createUUID\(\)/);
  assert.match(required, /!result\.SUCCESS[\s\S]*!result\.RECORDED/);
  assert.match(required, /FPW\.MemberActivity\.PersistenceFailed/);
  assert.doesNotMatch(required, /required.*(?:metadata|eventSource|timestamp)/i);
  assert.match(eventService, /UTC_TIMESTAMP\(\)/);
});

test('all five CRUD saves lock owned rows and require evidence within their transactions', () => {
  for (const family of ['vessel','contact','operator','passenger','waypoint']) {
    const source = read('api/v1/' + family + '.cfc');
    const start = source.indexOf('<cftransaction>');
    const end = source.indexOf('</cftransaction>', start);
    const block = source.slice(start, end);
    assert.match(block, /activityOwner[\s\S]*FOR UPDATE/);
    assert.match(block, /activityBefore[\s\S]*AND userId[\s\S]*FOR UPDATE/);
    assert.match(block, /activityAfter\.recordCount NEQ 1/);
    assert.match(block, /compare\(local\.activityBefore\.projection\[1\], local\.activityAfter\.projection\[1\]\)/);
    assert.match(block, /recordRequiredMemberActivity\(/);
    assert.doesNotMatch(block, /SELECT\s+\*/i);
  }
});

test('images use an internal opt-in, identical-byte detection and no mutation fallback retry', () => {
  const image = read('api/v1/VesselImageService.cfc');
  for (const name of ['saveUploadedVesselImage','removeVesselImage']) {
    const fn = tagFunction(image, name);
    assert.match(fn, /name="memberCommand"[^>]*default="false"/);
    assert.match(fn, /transaction[\s\S]*lockOwnedVessel[\s\S]*recordRequiredMemberActivity/);
  }
  assert.match(image, /hash\(fileReadBinary\(previousPath\), "SHA-256"\)/);
  const upload = read('api/v1/vesselImageUpload.cfm');
  assert.equal((upload.match(/saveUploadedVesselImage\(/g) || []).length, 1);
  assert.match(upload, /memberCommand = true/);
});

test('geometry target verification happens again after owned locks; nested saves default off', () => {
  for (const name of ['saveRouteLegOverrideGeometry','clearRouteLegOverrideGeometry','routegenSaveLegOverride','routegenClearLegOverride']) {
    const fn = tagFunction(route, name);
    const locked = fn.slice(fn.indexOf('transaction {'));
    assert.match(locked, /memberRouteActivityProjection[\s\S]*legRow = routegenRead[\s\S]*!structCount\(legRow\)/);
  }
  assert.match(tagFunction(route,'routegenSaveLegOverride'), /name="memberCommand"[^>]*default="false"/);
  assert.doesNotMatch(tagFunction(route,'routegenPersistDraftLegOverrides'), /recordRequiredMemberActivity/);
});

test('Draft projections distinguish logical selections and the current Draft status under lock', () => {
  const projection = tagFunction(plan,'readDraftActivityProjection');
  assert.match(projection, /WHERE floatplanId=:pid AND userId=:uid FOR UPDATE/);
  assert.match(projection, /SELECT DISTINCT contactId[\s\S]*ORDER BY contactId/);
  assert.match(projection, /ORDER BY recId/);
  for (const name of ['saveFloatPlan','saveBasicFloatPlan']) {
    const fn = tagFunction(plan, name);
    assert.match(fn, /transaction[\s\S]*activityBefore = readDraftActivityProjection/);
    assert.match(fn, /activityBefore\.draft AND activityAfter\.draft[\s\S]*recordRequiredMemberActivity/);
  }
  const build = tagFunction(route,'buildFloatPlansFromRoute');
  assert.ok(build.indexOf('REUSED_EXISTING = true') < build.indexOf('recordRequiredMemberActivity'));
  assert.match(build, /SELECT vesselID FROM vessels WHERE vesselID=:vid AND userId=:uid FOR UPDATE/);
});

test('activity emission is confined to member save boundaries, not auth or lifecycle services', () => {
  for (const path of ['api/v1/auth.cfc','includes/InactiveMemberRecoveryPolicy.cfc',
    'api/v1/DepartureReminderService.cfc','api/v1/SafeArrivalNotificationService.cfc']) {
    assert.doesNotMatch(read(path), /recordRequiredMemberActivity/);
  }
  const allowed = new Set(['saveFloatPlan','saveBasicFloatPlan']);
  for (const match of plan.matchAll(/<cffunction name="([^"]+)"[\s\S]*?<\/cffunction>/g)) {
    if (match[0].includes('.recordRequiredMemberActivity(')) assert.ok(allowed.has(match[1]), match[1]);
  }
});

test('runtime failure injection is limited to isolated fresh local fixture harnesses', () => {
  const harness = read('tests/member-activity-command.cfm');
  assert.match(harness, /cgi\.request_method NEQ "POST"/);
  assert.match(harness, /RUN_MEMBER_ACTIVITY_EVIDENCE_TESTS/);
  assert.match(harness, /structKeyExists\(session,"user"\)/);
  assert.match(harness, /codex-activity-%@example\.test/);
  assert.match(harness, /INTERVAL 4 HOUR/);
  assert.match(harness, /event_name='sign_up'/);
});
