import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { REQUIRED_SOURCES } from '../scripts/retention/export-sql.mjs';
import { fromPackets, buildReport } from '../scripts/retention/baseline.mjs';
import { utc, windowStart } from '../scripts/retention/evidence.mjs';
import { importPackets, memberCsv, parseCsv, summaryMarkdown, run } from '../scripts/retention/cli.mjs';

const T='2026-09-29T18:00:00.123456Z', W=windowStart(T);
const before='2026-09-10T12:00:00.000000Z';
const cfUuid='79db0622-9f3f-548e-960c669875426a6e';
function snapshot() {
  return {T,W,...Object.fromEntries(REQUIRED_SOURCES.map(k=>[k,[]])),
    users:[{user_id:'42',first_name:'Example',last_name:'Member',email:'member@example.test',created_at_raw:'2026-01-01 00:00:00'}]};
}
function event(name='vessel_created', at=before, overrides={}) {
  const entity_type=name.startsWith('vessel')?'vessel':name.startsWith('user_route')?'user_route':name.startsWith('route')?'route_instance':'float_plan';
  return {id:'1',user_id:'42',event_name:name,entity_type,entity_id:'10',event_source:'member_api',
    occurred_at_utc:at,created_at_utc:at,idempotency_key:'member_activity:'+cfUuid,
    metadata_valid:1,metadata_object:1,metadata_empty:name!=='vessel_created'?1:0,metadata_json:{creation_source:'member'},...overrides};
}
function packets(s) {return REQUIRED_SOURCES.map(source=>({format_version:1,source,T:s.T,W:s.W,captured_at_utc:s.T,row_count:s[source].length,rows:s[source]}));}

test('fixed UTC boundaries preserve microseconds and are independent of server timezone',()=>{
  assert.equal(W,'2026-08-30T18:00:00.123456Z');
  assert.equal(utc('2026-02-30 12:00:00'),null);
  for(const [at,active] of [[W,1],[T,0],['2026-08-30T18:00:00.123455Z',0],['2026-09-29T18:00:00.123455Z',1]]) {
    const s=snapshot();s.product_events=[event('vessel_created',at)];assert.equal(buildReport(s).activity.active,active);
  }
});
test('packet importer fails closed on missing, truncated, duplicate or mismatched sources',()=>{
  const p=packets(snapshot());assert.equal(fromPackets(p).T,T);
  assert.throws(()=>fromPackets(p.slice(1)),/Missing/);
  assert.throws(()=>fromPackets([...p,p[0]]),/duplicate/);
  assert.throws(()=>fromPackets(p.map((v,i)=>i? v:{...v,row_count:99})),/truncated/);
  assert.throws(()=>fromPackets(p.map((v,i)=>i? v:{...v,rows:null})),/truncated/);
  assert.throws(()=>fromPackets(p.map((v,i)=>i? {...v,T:before}:v)),/Inconsistent/);
});
test('MariaDB string row counts remain strict and preserve truncation detection',()=>{
  const p=packets(snapshot()).map(v=>({...v,row_count:String(v.row_count)}));
  assert.equal(fromPackets(p).source_manifest[0].row_count,1);
  for(const bad of ['',null,'1.0','-1',' 1','01','9007199254740992',1.5]) {
    assert.throws(()=>fromPackets(p.map((v,i)=>i?v:{...v,row_count:bad})),/truncated/);
  }
  assert.throws(()=>fromPackets(p.map((v,i)=>i?v:{...v,row_count:'2'})),/truncated/);
});
test('no events and recovery markers never imply inactivity',()=>{
  const s=snapshot(); s.product_events=[event('recovery_coverage_started',before,{entity_type:'user',entity_id:'42',event_source:'member_signup'})];
  const r=buildReport(s);assert.deepEqual([r.activity.active,r.activity.inactive,r.activity.unknown],[0,0,1]);
});
test('zero-leg create may prove activity but never legitimate use or repeat',()=>{
  const s=snapshot();s.user_routes=[{id:'10',user_id:'42',leg_count:0}];s.product_events=[event('user_route_created')];
  const r=buildReport(s);assert.equal(r.activity.active,1);assert.equal(r.route_use.at_least_one,0);assert.equal(r.route_use.repeat,0);
});
test('rename-ambiguous route updates do not qualify; repeated updates do not add uses',()=>{
  const s=snapshot();s.user_routes=[{id:'10',user_id:'42',leg_count:2}];
  s.product_events=[event('user_route_updated'),event('user_route_updated',before,{id:'2'})];
  const r=buildReport(s);assert.equal(r.activity.active,0);assert.equal(r.activity.unknown,1);assert.equal(r.route_use.at_least_one,1);assert.equal(r.route_use.repeat,0);
});
test('active counts deduplicate different actions, duplicate evidence and member projections',()=>{
  const s=snapshot();s.product_events=[event(),event(),event('vessel_updated',before,{id:'2'})];
  assert.equal(buildReport(s).activity.active,1);
});
test('source, entity ownership, metadata and clocks must validate',()=>{
  for(const changed of [{event_source:'scheduler'},{entity_type:'user'},{metadata_valid:0},{created_at_utc:T},{idempotency_key:''}]) {
    const s=snapshot();s.product_events=[event('vessel_created',before,changed)];assert.equal(buildReport(s).activity.active,0);
  }
  const s=snapshot();s.vessels=[{id:'10',user_id:'99'}];s.product_events=[event()];
  assert.equal(buildReport(s).activity.active,0);
});
test('CF UUID and retained legacy creation key are accepted without losing older positive evidence',()=>{
  for(const key of ['member_activity:'+cfUuid,'member_activity:12345678-1234-1234-1234-123456789012','vessel_created:vessel:10']) {
    const s=snapshot();s.product_events=[event('vessel_created',before,{idempotency_key:key})];assert.equal(buildReport(s).activity.active,1);
  }
});
test('reviewed real IDs and current admin rule visibly exclude only authorized members',()=>{
  const s=snapshot();s.users.push({user_id:'43'},{user_id:'44'});
  s.member_entitlements=[{id:'1',user_id:'43',entitlement_type:'admin',status:'active',starts_at_utc:W,expires_at_utc:null,revoked_at_utc:null}];
  const r=buildReport(s,{T,real_user_ids:['42','43'],other_current_users_are_test:true,reason:'Owner reviewed all remaining IDs as tests'});
  assert.equal(r.population.final_valid_population,1);assert.equal(r.population.active_admins_excluded,1);assert.equal(r.population.reviewed_test_fixtures_excluded,1);
  assert.deepEqual(r.population.exclusions.map(e=>e.user_id),['43','44']);
  assert.throws(()=>buildReport(s,{T:before,real_user_ids:['42'],other_current_users_are_test:true,reason:'review'}),/snapshot T/);
});
test('expired, revoked and future admin entitlements do not invent an admin exclusion',()=>{
  for(const change of [{expires_at_utc:T},{revoked_at_utc:before},{starts_at_utc:'2026-10-01T00:00:00Z'},{status:'inactive'}]){
    const s=snapshot();s.member_entitlements=[{user_id:'42',entitlement_type:'admin',status:'active',starts_at_utc:W,expires_at_utc:null,revoked_at_utc:null,...change}];
    assert.equal(buildReport(s).population.final_valid_population,1);
  }
});
test('successful Basic Review receipt counts even when DRAFT and event missing; PROCESSING does not',()=>{
  const s=snapshot();s.floatplans=[{floatplan_id:'10',user_id:'42',status:'DRAFT'}];
  s.basic_review_send_receipts=[{id:'1',user_id:'42',float_plan_id:'10',status:'SENT',completed_at_utc:before}];
  let r=buildReport(s);assert.equal(r.sharing.lifetime.yes,1);assert.equal(r.sharing.trailing_30d.yes,1);assert.equal(r.activity.active,1);
  s.basic_review_send_receipts[0].status='PROCESSING';r=buildReport(s);assert.equal(r.sharing.lifetime.yes,0);assert.equal(r.sharing.lifetime.unknown,1);
});
test('receipt/event overlap counts one sharing member; Basic Review key uses receipt ID',()=>{
  const s=snapshot();s.basic_review_send_receipts=[{id:'90',user_id:'42',float_plan_id:'10',status:'SENT',completed_at_utc:before}];
  s.product_events=[event('basic_send_completed',before,{event_source:'basic_review_send',idempotency_key:'basic_send_completed:basic_review_receipt:90'})];
  s.premium_send_receipts=[{id:'2',user_id:'42',float_plan_id:'10',recipient_count:2,committed_at_utc:before}];
  const r=buildReport(s);assert.equal(r.sharing.lifetime.yes,1);assert.equal(r.activity.active,1);
});
test('successful recovery sharing requires matching start plus single terminal with valid CF UUID',()=>{
  const s=snapshot();
  s.product_events=['started','succeeded'].map((state,i)=>event('recovery_share_'+state,before,{id:String(i+1),entity_type:'float_plan',event_source:'basic_save_send',
    metadata_empty:1,request_correlation_id:cfUuid,idempotency_key:'recovery_share:'+cfUuid+':'+state}));
  assert.equal(buildReport(s).sharing.lifetime.yes,1);
  s.product_events.shift();assert.equal(buildReport(s).sharing.lifetime.yes,0);
});
test('completion requires CLOSED and compatible owned route; legacy clock stays unknown for 30d',()=>{
  const s=snapshot();s.floatplans=[{floatplan_id:'10',user_id:'42',status:'CLOSED',closed_at_raw:'2026-09-20 12:00:00'}];
  let r=buildReport(s);assert.equal(r.completion.lifetime.yes,1);assert.equal(r.completion.trailing_30d.unknown,1);
  assert.equal(r.route_use.at_least_one,1);assert.equal(r.activity.active,0);
  s.floatplans[0].status='CANCELLED';assert.equal(buildReport(s).completion.lifetime.yes,0);
  s.floatplans[0].status='CLOSED';s.floatplans[0].route_instance_id='20';
  assert.equal(buildReport(s).completion.lifetime.yes,0);
});
test('canonical actor/source/post type must agree before using DB UTC corroboration',()=>{
  const s=snapshot();s.floatplans=[{floatplan_id:'10',user_id:'42',status:'ACTIVE'}];
  const e={id:'1',user_id:'42',actor_user_id:'42',floatplan_id:'10',event_type:'CHECKIN_RECEIVED',source:'active_cruise_checkin',
    source_post_exists:1,source_post_author_user_id:'42',source_post_owner_user_id:'42',source_post_floatplan_id:'10',
    source_post_created_at_utc:before,source_post_event_type:'checkin'};
  s.floatplan_events=[e];assert.equal(buildReport(s).activity.active,1);
  e.source_post_event_type='floatplan_closed';assert.equal(buildReport(s).activity.active,0);
  e.source='canonical_cutover';assert.equal(buildReport(s).activity.active,0);
});
test('member manual delay is allowed despite system author tag; generic posts cannot qualify',()=>{
  const s=snapshot();s.floatplans=[{floatplan_id:'10',user_id:'42',status:'ACTIVE'}];
  s.voyage_delay_posts=[{id:'1',author_user_id:'42',owner_user_id:'42',floatplan_id:'10',author_type:'system',post_type:'system_event',event_type:'delay_added',created_utc:before}];
  assert.equal(buildReport(s).activity.active,1);
  s.voyage_delay_posts[0].event_type='';assert.equal(buildReport(s).activity.active,0);
});
test('counts, names, emails and numerators/denominators survive CSV and summary output',()=>{
  const s=snapshot();s.product_events=[event()];const r=buildReport(s);
  assert.equal(r.members[0].email,'member@example.test');
  const csv=memberCsv(r), rows=parseCsv(csv);
  assert.equal(rows.length,2);assert.ok(rows[0].includes('email'));assert.equal(rows[1][rows[0].indexOf('first_name')],'Example');
  assert.match(summaryMarkdown(r),/100.00% \(1\/1\)/);
  assert.match(summaryMarkdown(r),/member@example.test/);
});
test('member CSV retains standalone report context on every included and excluded row',()=>{
  const s=snapshot();
  s.users.push(
    {user_id:'43',first_name:'Reviewed',last_name:'Fixture',email:'fixture@example.test'},
    {user_id:'44',first_name:'Unknown',last_name:'Member',email:'unknown@example.test'}
  );
  s.product_events=[event()];
  s.user_routes=[{id:'20',user_id:'42',leg_count:1}];
  s.floatplans=[{floatplan_id:'10',user_id:'42',status:'CLOSED',closed_at_raw:'2026-09-20 12:00:00'}];
  s.basic_review_send_receipts=[{id:'80',user_id:'42',float_plan_id:'10',status:'SENT',completed_at_utc:before}];
  const report=buildReport(s,{
    T,real_user_ids:['42','44'],other_current_users_are_test:true,
    reason:'Owner reviewed the remaining account as a test fixture'
  });
  const [header,...rows]=parseCsv(memberCsv(report));
  const contextKeys=['population','activity','route_use','sharing','completion','return_after_completion','limitations'];
  const expected=Object.fromEntries(contextKeys.map(key=>[key,report[key]]));
  assert.equal(rows.length,3);
  assert.equal(new Set(header).size,header.length);
  for(const key of ['report_T','report_W','definition_version','report_context']) assert.ok(header.includes(key));
  for(const cells of rows) {
    const row=Object.fromEntries(header.map((key,i)=>[key,cells[i]]));
    assert.equal(row.report_T,T);
    assert.equal(row.report_W,W);
    assert.equal(row.definition_version,report.definition_version);
    const context=JSON.parse(row.report_context);
    assert.deepEqual(context,expected);
    assert.deepEqual(Object.keys(context),contextKeys);
    assert.equal(context.population.final_valid_population,2);
    assert.equal(context.population.exclusions[0].user_id,'43');
    assert.deepEqual([context.activity.active,context.activity.inactive,context.activity.unknown],[1,0,1]);
    assert.deepEqual([context.activity.rate.numerator,context.activity.rate.denominator],[1,2]);
    assert.ok(context.limitations.length>0);
    const member=report.members.find(item=>item.user_id===row.user_id);
    assert.equal(row.first_name,member.first_name);
    assert.equal(row.last_name,member.last_name);
    assert.equal(row.email,member.email);
    assert.equal(row.included,String(member.included));
    assert.equal(row.exclusion_reason,member.exclusion_reason??'');
  }
  const markdown=summaryMarkdown(report);
  assert.ok(markdown.includes(T));
  assert.ok(markdown.includes(W));
  assert.ok(markdown.includes(report.definition_version));
  assert.match(markdown,/50.00% \(1\/2\)/);
});
test('offline CLI retains source, review, report and member CSV; replay deterministic and overwrite refused',()=>{
  const dir=mkdtempSync(join(tmpdir(),'fpw-day40-test-'));
  try{
    const s=snapshot();s.product_events=[event()];
    const csv='"payload"\r\n'+packets(s).map(p=>'"'+JSON.stringify(p).replaceAll('"','""')+'"').join('\r\n')+'\r\n';
    assert.equal(importPackets(csv).length,REQUIRED_SOURCES.length);
    writeFileSync(join(dir,'input.csv'),csv);
    for(const name of ['a','b']) run(['report','--input',join(dir,'input.csv'),'--out',join(dir,name)]);
    assert.equal(readFileSync(join(dir,'a','report.json'),'utf8'),readFileSync(join(dir,'b','report.json'),'utf8'));
    assert.throws(()=>run(['report','--input',join(dir,'input.csv'),'--out',join(dir,'a')]),/never overwritten/);
  }finally{rmSync(dir,{recursive:true,force:true});}
});

test('Workbench native JSON cell envelope imports without weakening JSON or source validation',()=>{
  const p=packets(snapshot());
  const native='payload\n'+p.map(v=>'"'+JSON.stringify(v)+'"').join('\n')+'\n';
  const standard='payload\n'+p.map(v=>'"'+JSON.stringify(v).replaceAll('"','""')+'"').join('\n')+'\n';
  assert.deepEqual(fromPackets(importPackets(native)),fromPackets(importPackets(standard)));
  assert.throws(()=>importPackets('payload\n"{broken}"'),SyntaxError);
  assert.throws(()=>fromPackets(importPackets(native.replace('"row_count":1','"row_count":2'))),/truncated/);
});

test('successful owned Basic operational share proves planning without inventing a beginning clock',()=>{
  const s=snapshot();s.floatplans=[{floatplan_id:'10',user_id:'42',route_instance_id:null,status:'ACTIVE',
    basic_details_present:1,basic_required_fields_present:1}];
  s.product_events=[event('basic_send_completed',before,{event_source:'basic_save_send',
    idempotency_key:'basic_send_completed:float_plan:10'})];
  const r=buildReport(s), use=r.members[0].route_use;
  assert.equal(r.activity.active,1);assert.equal(r.sharing.lifetime.yes,1);
  assert.equal(r.route_use.at_least_one,1);assert.equal(use.has_legitimate_use,'YES');
  assert.equal(use.uses.length,1);assert.equal(use.uses[0].key,'basic-trip:10');
  assert.equal(use.uses[0].begin_at_utc,null);assert.equal(use.first_use,null);
  assert.equal(use.repeat,'UNKNOWN');assert.equal(use.returned_after_completion,'UNKNOWN');
});

test('Basic sharing planning proof requires current ownership, required details and canonical Basic source',()=>{
  for(const change of [{basic_details_present:0},{basic_required_fields_present:0},{user_id:'99'}]) {
    const s=snapshot();s.floatplans=[{floatplan_id:'10',user_id:'42',route_instance_id:null,status:'ACTIVE',
      basic_details_present:1,basic_required_fields_present:1,...change}];
    s.product_events=[event('basic_send_completed',before,{event_source:'basic_save_send',
      idempotency_key:'basic_send_completed:float_plan:10'})];
    assert.equal(buildReport(s).route_use.at_least_one,0);
  }
  const s=snapshot();s.floatplans=[{floatplan_id:'10',user_id:'42',route_instance_id:null,status:'DRAFT',
    basic_details_present:1,basic_required_fields_present:1}];
  s.basic_review_send_receipts=[{id:'1',user_id:'42',float_plan_id:'10',status:'SENT',completed_at_utc:before}];
  assert.equal(buildReport(s).route_use.at_least_one,0);
  s.basic_review_send_receipts=[];
  s.product_events=[event('basic_send_completed',T,{event_source:'basic_save_send',
    idempotency_key:'basic_send_completed:float_plan:10'})];
  assert.equal(buildReport(s).route_use.at_least_one,0);
});

test('validated successful Basic share marker can prove one planning use without a completed product event',()=>{
  const s=snapshot();s.floatplans=[{floatplan_id:'10',user_id:'42',route_instance_id:null,status:'ACTIVE',
    basic_details_present:1,basic_required_fields_present:1}];
  s.product_events=['started','succeeded'].map((state,i)=>event('recovery_share_'+state,before,{id:String(i+1),
    entity_type:'float_plan',event_source:'basic_save_send',metadata_empty:1,request_correlation_id:cfUuid,
    idempotency_key:'recovery_share:'+cfUuid+':'+state}));
  const r=buildReport(s);assert.equal(r.route_use.at_least_one,1);
  assert.equal(r.members[0].route_use.uses[0].begin_at_utc,null);
  s.product_events[1].event_name='recovery_share_failed';
  s.product_events[1].idempotency_key='recovery_share:'+cfUuid+':failed';
  assert.equal(buildReport(s).route_use.at_least_one,0);
});
