import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const context = vm.createContext({window:{FPW:{}}});
for (const file of ['fuel-math.js','cruise-timeline-view.js']) {
  vm.runInContext(fs.readFileSync(new URL('../assets/js/app/shared/'+file,import.meta.url),'utf8'),context);
}
const view = context.window.FPW.CruiseTimelineView;
const plain = value => JSON.parse(JSON.stringify(value));
const leg={order_index:1,segment_id:101,start_name:'A <inlet>',end_name:'B',dist_nm:120,lock_count:3};
const raw={
  route_summary:{total_days:2,total_nm:140,total_required_fuel:90},
  timeline_meta:{hours_source:'weather_adjusted_speed',effective_speed_kn:10,fuel_burn_gph:5,weather_adjusted_fuel_burn_gph:5,effective_weather_pct_max:0},
  days:[1,2].map((day)=>({leg_index:day,date:'2026-10-'+(28+day),start_name:'A <inlet>',end_name:day===1?'B':'C',total_dist_nm:70,est_hours:7,lock_count:day===1?2:1,required_fuel_gallons:45,reserve_gallons:15,risk_color:day===1?'YELLOW':'RED',segment_ids:day===1?[101]:[101,102],segment_slices:[{source_id:101,segment_id:101,order_index:1,start_name:'A <inlet>',end_name:'B',slice_dist_nm:60,slice_hours:6,segment_dist_nm:120,segment_hours:12,lock_count:day===1?2:1,is_split:true}]}))
};
const payload=view.normalizePayload(raw);

test('shared normalization retains canonical grouped days, slices and risk',()=>{
  assert.equal(payload.days.length,2);
  assert.deepEqual(plain(payload.days.map(day=>[day.riskColor,day.badgeClass])),[['YELLOW','bg-warning text-dark'],['RED','bg-danger']]);
  assert.equal(view.getEntriesForLeg(payload,leg,1).length,2);
  assert.deepEqual(plain(view.getLegMetrics(payload,leg,1)),{startName:'A <inlet>',endName:'B',distNm:120,estHours:12,lockCount:3});
});

test('selected-leg details reuse canonical segment and day totals without recomputing',()=>{
  const html=view.renderDayDetails({payload,leg,order:1});
  assert.match(html,/Leg hours: <strong>12\.0 hrs/);
  assert.match(html,/Grouped day hours: <strong>7\.0 hrs/);
  assert.match(html,/Grouped legs: <strong>2/);
  assert.match(html,/A &lt;inlet&gt;/);
  assert.match(html,/bg-warning text-dark/);
  assert.match(html,/bg-danger/);
  assert.match(html,/This leg spans <strong>2/);
});

test('calculation summary delegates the existing shared fuel model',()=>{
  const ui={maxHoursPerDay:7,reserveMode:'thirds',reservePct:33};
  assert.deepEqual(plain(view.buildSummaryModel(payload,ui)),plain(context.window.FPW.SharedFuelMath.buildCruiseTimelineSummaryModel(payload,{...ui,timelineCruiseOnly:true})));
});

test('missing public fuel is unavailable without mutating canonical results',()=>{
  const before=JSON.stringify(payload);
  const summary=view.buildSummaryModel(payload,{maxHoursPerDay:7,fuelAvailable:false});
  assert.match(summary.calcLine,/Fuel n\/a/);
  assert.equal(summary.totalRequiredFuel,null);
  assert.equal(summary.totalReserveFuel,null);
  const html=view.renderDayDetails({payload,leg,order:1,fuelAvailable:false});
  assert.match(html,/required-fuel">Unavailable/);
  assert.match(html,/Reserve: <strong>Unavailable/);
  assert.equal(JSON.stringify(payload),before);
});

test('missing lock mappings preserve known counts and never claim zero',()=>{
  const html=view.renderLockDetails({mappingAvailable:false,expectedLockCount:3,details:{locks:[],totals:{}},timelineHtml:'<p>timeline</p>'});
  assert.match(html,/<span>Locks<\/span><strong>3/);
  assert.match(html,/Canonical lock mapping unavailable/);
  assert.match(html,/does not mean there are no locks/);
  assert.match(html,/<span>Best<\/span><strong>Unavailable/);
  assert.match(html,/<p>timeline<\/p>/);
});

test('incomplete delay models keep names but mask totals and per-lock delay',()=>{
  const details={lock_count:1,totals:{best_wait_min:1,typical_wait_min:2,worst_wait_min:3},locks:[{seq:1,name:'Lock <A>',best_wait_min:1,typical_wait_min:2,worst_wait_min:3}]};
  const publicHtml=view.renderLockDetails({details,delayAvailable:false});
  assert.match(publicHtml,/Lock &lt;A&gt;/);
  assert.match(publicHtml,/Best\/Typical\/Worst: Unavailable/);
  const generatorHtml=view.renderLockDetails({details});
  assert.match(generatorHtml,/<span>Typical<\/span><strong>2 min/);
  assert.match(generatorHtml,/data-leg-action="collapse-locks"/);
});

test('public rows are keyboard-accessible and read-only; generator retains edit hooks',()=>{
  const publicHtml=view.renderLegRows([leg],{readOnlyGeometry:true,selectedOrder:1,expandedOrder:1,getGeometryLabel:()=> 'Template'});
  assert.match(publicHtml,/role="button" tabindex="0" aria-expanded="true"/);
  assert.match(publicHtml,/Template/);
  assert.doesNotMatch(publicHtml,/data-leg-action="open-map"/);
  const generatorHtml=view.renderLegRows([leg],{});
  assert.match(generatorHtml,/data-leg-action="open-map"/);
  assert.doesNotMatch(generatorHtml,/role="button"/);
});

// The canonical engine exposes cruising-only segment hours separately from lock-inclusive slices.
test('canonical cruising hours drive selected-leg headline while day rollups retain locks',()=>{
  const enriched=plain(raw);
  enriched.days.forEach(day=>day.segment_slices.forEach(slice=>{slice.segment_cruising_hours=10;}));
  const normalized=view.normalizePayload(enriched);
  assert.equal(normalized.days[0].segmentSlices[0].segmentCruisingHours,10);
  assert.equal(view.getLegMetrics(normalized,leg,1).estHours,10);
  const html=view.renderDayDetails({payload:normalized,leg,order:1});
  assert.match(html,/Leg hours: <strong>10\.0 hrs/);
  assert.match(html,/Grouped day hours: <strong>7\.0 hrs/);
  assert.equal(Object.hasOwn(payload.days[0].segmentSlices[0],'segmentCruisingHours'),false);
});
