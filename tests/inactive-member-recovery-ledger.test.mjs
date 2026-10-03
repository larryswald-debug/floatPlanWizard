import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const service=read('includes/InactiveMemberRecoveryLedgerService.cfc');
const up=read('database/migrations/20260904_001_inactive_member_recovery_deliveries.up.sql');
const transition=read('database/migrations/20261003_001_recovery_center.up.sql');
const preflight=read('database/migrations/20260904_001_inactive_member_recovery_deliveries.preflight.sql');
const down=read('database/migrations/20260904_001_inactive_member_recovery_deliveries.down.sql');
const verify=read('database/migrations/20260904_001_inactive_member_recovery_deliveries.verify.sql');

test('schema transitions to enrollment contact identity and preserves the three-state model',()=>{
  assert.match(transition,/ADD UNIQUE KEY uq_recovery_enrollment_contact \(recovery_enrollment_event_id,contact_number\)/);
  assert.match(transition,/CHANGE COLUMN recovery_stage destination_stage/);
  assert.match(transition,/CHECK\(contact_number BETWEEN 1 AND 3\)/);
  assert.match(up,/CHECK \(`recovery_stage` IN \('A', 'B', 'C', 'D'\)\)/);
  assert.match(up,/CHECK \(`status` IN \('CLAIMED', 'SENT', 'FAILED'\)\)/);
  assert.match(up,/CHECK \(`attempt_count` BETWEEN 1 AND 3\)/);
  assert.match(up,/ON UPDATE RESTRICT ON DELETE CASCADE/);
  assert.match(up,/ENGINE=InnoDB/);
});

test('timestamps use database UTC and terminal-state consistency checks',()=>{
  assert.ok((up.match(/UTC_TIMESTAMP/g)||[]).length===0,'DDL must not fabricate row timestamps');
  assert.match(up,/`status` = 'CLAIMED'[\s\S]*`status` = 'SENT'[\s\S]*`status` = 'FAILED'/);
  assert.match(service,/claimed_at_utc=UTC_TIMESTAMP\(6\)/);
  assert.match(service,/sent_at_utc=UTC_TIMESTAMP\(6\),failed_at_utc=NULL/);
  assert.match(service,/sent_at_utc=NULL,failed_at_utc=UTC_TIMESTAMP\(6\)/);
  assert.match(service,/updated_at_utc=UTC_TIMESTAMP\(6\)/);
  assert.doesNotMatch(service,/\bnow\(\)|dateConvert|browser|timezone/i);
});

test('claim relies on database uniqueness and row locks',()=>{
  assert.match(service,/INSERT INTO inactive_member_recovery_deliveries/);
  assert.match(service,/SELECT ROW_COUNT\(\) AS changed_count/);
  assert.match(service,/FROM users WHERE userId=:userId FOR UPDATE/);
  assert.match(service,/getSequenceState\(arguments.userId\)/);
  assert.match(service,/CONTACT_SEQUENCE_CONFLICT/);
  assert.match(service,/ALREADY_SENT/);
  assert.match(service,/ALREADY_CLAIMED/);
  assert.match(service,/FAILED_PREVIOUSLY/);
});

test('definite retries are explicit, token-bound, and capped at three',()=>{
  assert.match(service,/public struct function retryFailedContact/);
  assert.match(service,/attempt_count=attempt_count\+1/);
  assert.match(service,/attempt_count < :maxAttempts/);
  assert.match(service,/variables\.maxAttempts\s*=\s*3/);
  assert.match(service,/claim_token=:token/);
  assert.match(service,/RETRY_EXHAUSTED/);
  assert.doesNotMatch(service,/stale|timeout|expire.*claim/i);
});

test('diagnostics omit the private claim token and error content is code-only',()=>{
  const state=service.slice(service.indexOf('private struct function rowState'),service.indexOf('private struct function claimedResult'));
  assert.doesNotMatch(state,/CLAIM_TOKEN|claim_token/);
  assert.match(service,/\^\[A-Z\]\[A-Z0-9_\]\{0,63\}\$/);
  assert.match(service,/"RECOVERY_SEND_FAILED"/);
  assert.doesNotMatch(up,/email|recipient|float.?plan|trip|route|message_body/i);
});

test('migration lifecycle follows guarded four-file convention',()=>{
  assert.match(preflight,/selected_database[\s\S]*preflight_status[\s\S]*preflight_error/);
  assert.match(preflight,/_fpw_production_preflight_refused_20260904_001/);
  assert.match(down,/ROLLBACK_INACTIVE_MEMBER_RECOVERY_DELIVERIES/);
  assert.match(down,/_fpw_rollback_refused_20260904_001/);
  assert.match(verify,/column_contract[\s\S]*unique_contract[\s\S]*account_delete_contract[\s\S]*check_contract/);
});

test('ledger remains unwired from policy, email, scheduled, and classifier paths',()=>{
  for(const path of ['includes/InactiveMemberRecoveryPolicy.cfc','api/v1/email.cfc',
    'app/scheduled/run-departure-reminders.cfm','api/v1/DepartureReminderService.cfc']){
    assert.doesNotMatch(read(path),/InactiveMemberRecoveryLedgerService|inactive_member_recovery_deliveries/);
  }
  assert.doesNotMatch(service,/sendMail|sendEmail|classifier|eligib|168|604800|product_events/i);
});
