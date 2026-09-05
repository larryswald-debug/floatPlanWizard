import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "..");
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), "utf8");

test("Review Basic Send bypasses the legacy modal and saves before confirmation", () => {
  const dashboard = read("app/dashboard.cfm");
  const wizard = read("assets/js/app/floatplanWizard.js");

  assert.match(dashboard, /@click="openBasicReviewSend"/);
  assert.doesNotMatch(
    dashboard.match(/ref="basicReviewOpenButton"[\s\S]*?<\/button>/)?.[0] || "",
    /data-basic-floatplan-open/
  );
  assert.match(wizard, /setStatus\("Saving your latest float-plan changes…"/);
  assert.match(
    wizard,
    /window\.Api\.saveFloatPlan\([\s\S]*?applySaveResponse\(response\)[\s\S]*?getBasicReviewSendConfirmation/
  );
});

test("confirmation supports one canonical recipient, a saved-contact selector, and existing Premium upgrade", () => {
  const dashboard = read("app/dashboard.cfm");
  const wizard = read("assets/js/app/floatplanWizard.js");

  assert.match(dashboard, /v-if="basicReviewContacts\.length === 1"/);
  assert.match(dashboard, /v-model\.number="basicReviewSelectedContactId"/);
  assert.match(dashboard, /Continue with Basic Send/);
  assert.match(dashboard, /Upgrade to Premium Send/);
  assert.match(wizard, /upgradeFromBasicReviewSend[\s\S]*?this\.submitPlanAndSend\(\)/);
});

test("client retains one token across retries and resets it for a reopened confirmation", () => {
  const wizard = read("assets/js/app/floatplanWizard.js");

  assert.match(wizard, /if \(!this\.basicReviewIdempotencyKey\)[\s\S]*?createBasicSendIdempotencyKey\(\)/);
  assert.match(wizard, /sendBasicReviewFloatPlan\([\s\S]*?this\.basicReviewIdempotencyKey/);
  assert.match(wizard, /closeBasicReviewSend[\s\S]*?this\.basicReviewIdempotencyKey = ""/);
});

test("server contract resolves saved contacts and does not call Premium, monitoring, or Trip-Follow paths", () => {
  const controller = read("api/v1/floatplan.cfc");
  const service = read("api/v1/BasicReviewSendService.cfc");
  const dashboard = read("app/dashboard.cfm");

  assert.match(controller, /<cfcase value="sendbasicreview">/);
  assert.match(controller, /<cfcase value="savebasic">/);
  assert.match(controller, /<cfcase value="sendbasic">/);
  assert.match(dashboard, /id="basicFloatPlanModal"/);
  assert.match(service, /FROM floatplan_contacts fpc/);
  assert.match(service, /INNER JOIN contacts c/);
  assert.match(service, /STATUS = "DRAFT"/);
  assert.doesNotMatch(service, /PremiumSendCreditService|consumeLockedCredit|startMonitoring|startScheduledRouteMonitoring|voyage_streams|Trip\/Follow/);
});

test("receipt schema provides durable request-token uniqueness", () => {
  const migration = read("database/migrations/20260731_001_basic_review_send_receipts.up.sql");

  assert.match(migration, /UNIQUE KEY `uq_basic_review_send_receipts_idempotency` \(`idempotency_key`\)/);
  assert.match(migration, /'PROCESSING', 'SENT', 'FAILED'/);
  assert.doesNotMatch(migration, /premium_send_credits|premium_send_receipts/);
});

test("Basic delivery attaches the generated PDF and waits for SMTP acceptance", () => {
  const emailService = read("api/v1/email.cfc");
  const basicMethod = emailService.match(
    /<cffunction name="sendBasicReviewFloatPlanEmail"[\s\S]*?<\/cffunction>/
  )?.[0] || "";

  assert.match(basicMethod, /attachmentPath = attachmentPath/);
  assert.match(basicMethod, /spoolEnable = false/);
  assert.match(basicMethod, /rethrowOnFailure = true/);
  assert.match(emailService, /<cfmailparam type="application\/pdf" file="#arguments\.attachmentPath#">/);
  assert.match(basicMethod, /cleanBasicReviewTextValue\(arguments\.floatPlanName\)/);
});

test("Basic review success requires transactional durable evidence after email acceptance", () => {
  const service = read("api/v1/BasicReviewSendService.cfc");
  const events = read("includes/ProductEventService.cfc");
  const finalize = service.slice(service.indexOf("private void function completeReceipt("), service.indexOf("private void function failReceipt("));
  assert.match(events, /definitions\["basic_send_completed"\][\s\S]*?eventSources = \[ "basic_save_send", "basic_review_send" \]/);
  assert.match(service, /emailAccepted = true;[\s\S]*?completeReceipt\(claim.RECEIPT_ID, response, pdfFileName\)/);
  assert.match(finalize, /transaction \{[\s\S]*?FOR UPDATE[\s\S]*?recordEvent\([\s\S]*?UPDATE basic_review_send_receipts/);
  assert.match(finalize, /userId = val\(qReceipt.user_id\[1\]\)/);
  assert.match(finalize, /entityId = val\(qReceipt.float_plan_id\[1\]\)/);
  assert.match(finalize, /metadata = \{\}/);
  assert.match(finalize, /basic_send_completed:basic_review_receipt:/);
  assert.doesNotMatch(finalize, /contact\.EMAIL|contact\.NAME|share_token|requestCorrelationId =/);
  assert.match(service, /if \(emailAccepted\)[\s\S]*?BASIC_REVIEW_CONFIRMATION_PENDING[\s\S]*?failReceipt/);
});

test("Basic share regression coverage verifies supported deletion, failures, ownership and Premium parity", () => {
  const spec = read("tests/specs/BasicReviewSendContractSpec.cfc");
  assert.match(spec, /deleteRouteForShareTest/);
  assert.match(spec, /loadReceipt\(result.RECEIPT_ID\)\.recordCount\)\.toBe\(0\)/);
  assert.match(spec, /hasShared\(fixture.userId\)\)\.toBeTrue\(\)/);
  assert.match(spec, /hasShared\(other.userId\)\)\.toBeFalse\(\)/);
  assert.match(spec, /verifyEvidenceFailure\("after_insert"\)/);
  assert.match(spec, /premiumReplay.DUPLICATE/);
  assert.doesNotMatch(spec, /900000 \+ val\(qUser.userId/);
});
