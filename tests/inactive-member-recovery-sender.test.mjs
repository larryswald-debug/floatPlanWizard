import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

const root = path.resolve(import.meta.dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const service = read('api/v1/InactiveMemberRecoveryService.cfc');
const runner = read('app/scheduled/run-inactive-member-recovery.cfm');
const email = read('api/v1/email.cfc');

test('service delegates decisions, claims, rendering and delivery without duplicating authorities', () => {
  for (const name of ['InactiveMemberRecoveryClassifierService', 'InactiveMemberRecoveryLedgerService',
    'evaluateMember', 'claimStage', 'retryFailedStage', 'checkNonEssentialEmailEligibility',
    'buildInactiveMemberRecoveryEmail', 'submitInactiveMemberRecoveryEmail', 'markSent', 'markFailed']) {
    assert.ok(service.includes(name), name);
  }
  assert.doesNotMatch(service, /\b(?:INSERT|UPDATE|DELETE)\s+(?:INTO|FROM|inactive_member_recovery_deliveries)\b/i);
  assert.doesNotMatch(service, /\b(?:cfmail|cfschedule|604800|168)\b/i);
  assert.doesNotMatch(service, /\bremote\s+\w+\s+function/i);
});

test('fresh authorization and compliance occur inside rollback-capable preparation before transport', () => {
  const tx = service.indexOf('transaction isolation="read_committed"');
  const fresh = service.indexOf('var fresh=');
  const compliance = service.indexOf('compliance=variables.emailService');
  const render = service.indexOf('prepared=variables.emailService');
  const rollback = service.indexOf('transaction action="rollback"');
  const submit = service.indexOf('submission=variables.transport');
  assert.ok(tx > 0 && fresh > tx && compliance > fresh && render > compliance
    && rollback > render && submit > rollback);
  assert.match(service, /ownedClaimToken=claim\.CLAIM_TOKEN/);
  assert.match(service, /fresh\.CURRENT_STAGE NEQ stage OR !fresh\.ELIGIBLE/);
  assert.match(service, /if \(arguments\.dryRun\) return result/);
  assert.ok(service.indexOf('if (arguments.dryRun) return result') < tx);
});

test('runner exposes only bounded authorized aggregate processing and live mode defaults off', () => {
  assert.match(runner, /token,batchSize,dryRun/);
  assert.match(runner, /val\(batchValue\) GT 100/);
  assert.match(runner, /httpStatus=403/);
  assert.match(runner, /no-store, no-cache/);
  assert.match(runner, /LIVE_MODE_DISABLED/);
  assert.match(service, /batchSize=25, boolean dryRun=true/);
  assert.match(service, /FPW_INACTIVE_RECOVERY_RUNNER_TOKEN/);
  assert.match(service, /FPW_INACTIVE_RECOVERY_LIVE_ENABLED/);
  assert.doesNotMatch(runner, /\b(?:userId|recipient|draftUrl|stageOverride)\s*=/i);
  assert.doesNotMatch(runner, /runnerError\.(?:message|detail|stacktrace)/i);
});

test('the nonremote transport boundary reuses multipart delivery with conservative failure semantics', () => {
  const extract = src => new Map([...src.matchAll(/<cffunction\b[^>]*\bname="([^"]+)"[^>]*>[\s\S]*?<\/cffunction>/gi)]
    .map(match => [match[1], match[0]]));
  const after = extract(email);
  assert.ok(after.size > 25, 'must actually extract the existing functions');
  const boundary = after.get('submitInactiveMemberRecoveryEmail');
  assert.match(boundary, /access="public"/);
  assert.match(boundary, /sendMultipartEmail\(/);
  assert.match(boundary, /spoolEnable=false/);
  assert.match(boundary, /rethrowOnFailure=true/);
  assert.match(boundary, /OUTCOME="AMBIGUOUS"/);
});

test('no enrollment is guessed and concurrency fixtures are local disposable non-delivery commands', () => {
  assert.match(service, /getEnrollmentUtc\(arguments\.userId\) : ""/);
  const command = read('tests/inactive-member-recovery-sender-command.cfm');
  assert.match(command, /val\(cgi\.server_port\) EQ 8500/);
  assert.match(command, /RUN_RECOVERY_SENDER_COMMAND/);
  assert.match(command, /FPW_INACTIVE_RECOVERY_LIVE_ENABLED=false/);
  assert.match(command, /fileWrite\(configPath,original\)/);
  const browser = read('tests/inactive-member-recovery-sender.playwright.js');
  assert.match(browser, /Promise\.all/);
  assert.match(browser, /prepareRetry/);
  assert.match(browser, /finally/);
});
