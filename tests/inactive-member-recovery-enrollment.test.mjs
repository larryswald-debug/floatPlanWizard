import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
const root=path.resolve(import.meta.dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const enrollment=read('includes/InactiveMemberRecoveryEnrollmentService.cfc');
const classifier=read('includes/InactiveMemberRecoveryClassifierService.cfc');
const sender=read('api/v1/InactiveMemberRecoveryService.cfc');
const events=read('includes/ProductEventService.cfc');

test('enrollment uses only existing events and no delivery, scheduler, or remote entry point',()=>{
  assert.match(enrollment,/eventName="inactive_member_recovery_enrolled"/);
  assert.match(enrollment,/eventSource="recovery_enrollment",metadata=\{\}/);
  assert.match(enrollment,/entityId=arguments.userId/);
  assert.doesNotMatch(enrollment,/\b(?:remote|cfmail|cfschedule|claimStage|markSent|markFailed|INSERT INTO users|CREATE TABLE)\b/i);
  assert.doesNotMatch(enrollment,/\b(?:fName|lName|lastLogin|vesselName|routeName)\b/);
});
test('transaction locks member and confirms event persistence before committing',()=>{
  assert.match(enrollment,/transaction isolation="read_committed"/);
  assert.match(enrollment,/SELECT userId FROM users WHERE userId=:userId FOR UPDATE/);
  assert.match(enrollment,/idempotencyKey=eventKey\(arguments.userId\)/);
  assert.match(enrollment,/variables.eventName & ":" & fix\(arguments.userId\)/);
  assert.match(enrollment,/transaction action="rollback"/);
  assert.match(enrollment,/ENROLLMENT_NOT_CONFIRMED/);
  assert.match(events,/UTC_TIMESTAMP\(\)/);
});
test('strict enrollment read detects contradictions without modifying records',()=>{
  const reader=enrollment.slice(enrollment.indexOf('public string function getEnrollmentUtc'),enrollment.indexOf('// Explicit internal command'));
  assert.doesNotMatch(reader,/INSERT|UPDATE|DELETE|recordEvent/);
  for(const term of ['row.recordCount EQ 1','row.user_id','row.entity_id','row.event_name','row.event_source','row.idempotency_key','structIsEmpty(metadata)','valid_clock','ENROLLMENT_EVIDENCE_INVALID']) assert.ok(reader.includes(term),term);
});
test('new enrollment definition is not a qualifying member activity event',()=>{
  const activity=events.slice(events.indexOf('private struct function memberActivityTypes'),events.indexOf('public struct function recordEvent'));
  assert.doesNotMatch(activity,/inactive_member_recovery_enrolled/);
  assert.match(events,/definitions\["inactive_member_recovery_enrolled"\]\s*=\s*\{\s*entityType = "user",\s*eventSources = \[ "recovery_enrollment" \],\s*metadata = \{\}/);
});
test('coverage is independently required and strict booleans only',()=>{
  assert.match(classifier,/struct coverageVerification=\{\}/);
  assert.match(classifier,/compare\(serializeJSON\(arguments.coverageVerification\[proof\]\),"true"\) EQ 0/);
  assert.match(classifier,/HOLD_INCOMPLETE_COVERAGE/);
  for(const field of ['stage_history','activity_coverage','sharing_history','recovery_history']) {
    assert.match(classifier,new RegExp(field+'=coverage[.]'+field));
    assert.doesNotMatch(classifier,new RegExp(field+'=true'));
  }
});
test('all sender evaluations re-read separate coverage and enrollment',()=>{
  assert.equal((sender.match(/classifier\.evaluateMember\(/g)||[]).length,3);
  assert.equal((sender.match(/coverageVerification=coverageVerification\(arguments.userId\)/g)||[]).length,3);
  assert.match(sender,/new fpw\.includes\.InactiveMemberRecoveryCoverageService/);
  assert.doesNotMatch(sender,/ensureEnrolled|previewMembers|recordEvent/);
  assert.match(sender,/variables\.liveEnabled=false/);
});
test('enrollment preview is bounded and does not enroll or send',()=>{
  const preview=enrollment.slice(enrollment.indexOf('public struct function previewMembers'),enrollment.indexOf('private boolean function validId'));
  assert.match(preview,/GT 100/);
  assert.doesNotMatch(preview,/ensureEnrolled|recordEvent|processBatch/);
  assert.match(preview,/already_enrolled/);
  assert.match(preview,/enrollable/);
});
test('browser harness is local, authenticated, owner-bound and token protected',()=>{
  const command=read('tests/inactive-member-recovery-enrollment-command.cfm');
  assert.match(command,/cgi\.server_port\) EQ 8500/);
  assert.match(command,/structKeyExists\(session,"user"\)/);
  assert.match(command,/fixture\.userId NEQ uid/);
  assert.match(command,/http_x_fpw_enrollment_test_token/);
  assert.match(command,/dryRun=true/);
  assert.doesNotMatch(command,/dryRun=false|liveEnabled=true|claimStage/);
});
