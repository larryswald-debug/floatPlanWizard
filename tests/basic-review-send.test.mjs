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
