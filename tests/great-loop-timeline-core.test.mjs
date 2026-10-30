import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const source = fs.readFileSync(new URL('../api/v1/RouteTimelineService.cfc',import.meta.url),'utf8');
function method(name) {
  const start=source.indexOf('<cffunction name="'+name+'"');
  assert.notEqual(start,-1,name);
  return source.slice(start,source.indexOf('</cffunction>',start)+13);
}
test('owned route wrapper retains ownership gates before calling the shared calculation',()=>{
  const wrapper=method('generateCruiseTimeline');
  const call=wrapper.indexOf('return calculateCruiseTimeline(');
  assert.ok(call>0);
  for (const gate of ['if (userIdVal LTE 0)','if (routeIdVal LTE 0)','resolveMyRouteById(userIdVal, routeIdVal)','AND user_id = :uid','if (qInst.recordCount EQ 0)']) {
    assert.ok(wrapper.includes(gate),gate);
    assert.ok(wrapper.indexOf(gate)<call,gate);
  }
  assert.match(wrapper,/legs = qSegments/);
  assert.match(wrapper,/inputs = effectiveInputs/);
  assert.equal(wrapper.includes('while (remainingSegHours'),false);
});
test('one nonremote calculation loop serves both query and public-array inputs without persistence',()=>{
  const core=method('calculateCruiseTimeline');
  assert.match(core,/access="public"/);
  assert.equal(core.includes('access="remote"'),false);
  assert.match(core,/isQuery\(arguments.legs\)/);
  assert.match(core,/routegenNormalizeTimelinePreviewLegs\(arguments.legs\)/);
  assert.equal((source.match(/while \(remainingSegHours GT sliceEpsilon\)/g)||[]).length,1);
  assert.doesNotMatch(core,/queryExecute\(|\b(?:INSERT INTO|UPDATE .* SET|DELETE FROM)\b/);
  assert.match(core,/routegenFinalizeCruiseTimelineDay\(/);
});
test('owned distance override precedence remains exact',()=>{
  const wrapper=method('generateCruiseTimeline');
  assert.ok(wrapper.includes('COALESCE(rluo_leg.computed_nm, uso.computed_nm, rluo_seg.computed_nm, ril.base_dist_nm)'));
  assert.ok(wrapper.includes('COALESCE(rluo_leg.computed_nm, sl.dist_nm, 0)'));
  assert.ok(wrapper.includes('AND rluo_leg.route_id = :routeId'));
  assert.ok(wrapper.includes('AND uso.segment_id = ril.segment_id'));
});
test('public planning defaults delegate to canonical normalizers',()=>{
  const defaults=method('getPlanningDefaults');
  for(const helper of ['routegenNormalizePace','routegenPaceDefaults','routegenNormalizeCruisingSpeed','routegenNormalizeUnderwayHours','routegenNormalizeWeatherFactorPct','routegenNormalizeReservePct','routegenNormalizeReserveMode']) assert.ok(defaults.includes(helper+'('),helper);
  assert.match(defaults,/"fuel_burn_gph"=""/);
  assert.doesNotMatch(defaults,/access="remote"/);
});
test('cruising-hours projection captures existing value before lock allowance without another calculation',()=>{
  const core=method('calculateCruiseTimeline');
  assert.ok(core.indexOf('segCruisingHours = segHours;') < core.indexOf('segHours += (segLockTimeMin / 60)'));
  assert.equal((core.match(/"segment_cruising_hours"=segCruisingHours/g)||[]).length,2);
  assert.equal((core.match(/segCruisingHours = segHours;/g)||[]).length,1);
});
