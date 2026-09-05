import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const email = read("api/v1/email.cfc");

function extractFunction(name) {
  const match = email.match(new RegExp(`<cffunction\\s+name="${name}"[\\s\\S]*?<\\/cffunction>`, "i"));
  assert.ok(match, `Missing ${name}`);
  return match[0];
}

test("one public render-only builder uses the existing layout, URL, and compliance contracts", () => {
  const builder = extractFunction("buildInactiveMemberRecoveryEmail");
  assert.match(builder, /access="public"/i);
  assert.match(builder, /getInactiveMemberRecoveryTemplateConfig/);
  assert.match(builder, /resolveAbsolutePublicUrl\("\/app\/dashboard\.cfm"\)/);
  assert.match(builder, /buildNonEssentialEmailComplianceFooter/);
  assert.match(builder, /renderBaseEmailLayout/);
  assert.doesNotMatch(builder, /\b(?:queryExecute|cfquery|cfmail|cfschedule|sendMultipartEmail|InactiveMemberRecoveryClassifier|InactiveMemberRecoveryPolicy|inactive_member_recovery_deliveries)\b/i);
  assert.doesNotMatch(email, /sendInactiveMemberRecoveryEmail/i);
});

test("stage configuration has the exact approved subjects, bodies, and CTA labels", () => {
  const config = extractFunction("getInactiveMemberRecoveryTemplateConfig");
  for (const text of [
    "Add your boat to FloatPlanWizard",
    "Your FloatPlanWizard account is ready. Add your vessel details once and FPW can reuse them when you plan future trips and create Float Plans.",
    "Continue Vessel Setup",
    "Ready to plan your first trip?",
    "Your vessel is saved in FloatPlanWizard. When you're ready, use Trip Planner to map a route, add stops, and estimate your trip.",
    "Start Planning a Trip",
    "Pick up your trip planning",
    "You've started saving trip-planning work in FloatPlanWizard. You can come back anytime to continue the route and turn it into a trip when you're ready.",
    "Continue Trip Planning",
    "Your Float Plan is waiting",
    "You've started a Float Plan in FloatPlanWizard. Come back when you're ready to finish the details and share the trip with someone ashore.",
    "Continue Your Float Plan"
  ]) assert.ok(config.includes(text), `Missing approved copy: ${text}`);
});

test("invalid stages and invalid verified Draft URLs fail without send-ready bodies", () => {
  const builder = extractFunction("buildInactiveMemberRecoveryEmail");
  const draftValidator = extractFunction("validateVerifiedInactiveMemberDraftUrl");
  const failure = extractFunction("buildInactiveMemberRecoveryEmailFailure");
  assert.match(builder, /INVALID_RECOVERY_STAGE/);
  assert.match(builder, /INVALID_VERIFIED_DRAFT_URL/);
  assert.match(builder, /NON_ESSENTIAL_COMPLIANCE_REQUIRED/);
  assert.match(draftValidator, /\/app\/floatplan-wizard\.cfm/);
  assert.match(draftValidator, /publicBaseUrl/);
  assert.match(failure, /subject = ""/);
  assert.match(failure, /htmlBody = ""/);
  assert.match(failure, /textBody = ""/);
});

test("content configuration contains no pressure, sales, referral, or internal stage language", () => {
  const config = extractFunction("getInactiveMemberRecoveryTemplateConfig");
  assert.doesNotMatch(config, /\b(?:upgrade|pricing|subscribe|premium|discount|last chance|urgent|overdue|referral rewards|stage [abcd])\b/i);
});

test("address remains private configuration owned by the existing footer", () => {
  const builder = extractFunction("buildInactiveMemberRecoveryEmail");
  assert.doesNotMatch(builder, /4347 Topsail Trail|New Port Richey/i);
  assert.match(email, /FPW_BUSINESS_MAILING_ADDRESS/);
});

test("local test and preview endpoints require explicit confirmation", () => {
  const runner = read("tests/inactive-member-recovery-email-template-runner.cfm");
  const preview = read("tests/inactive-member-recovery-email-preview.cfm");
  assert.match(runner, /RUN_INACTIVE_MEMBER_RECOVERY_EMAIL_TEMPLATE_TESTS/);
  assert.match(preview, /RUN_INACTIVE_MEMBER_RECOVERY_EMAIL_PREVIEW/);
  for (const source of [runner,preview]) {
    assert.match(source, /serverPort EQ 8500/);
    assert.match(source, /OR NOT isLocal/);
    assert.match(source, /statuscode="404"/);
  }
});

test("contract keeps rendering separate from classification and delivery", () => {
  const doc = read("docs/inactive-member-recovery-email-templates.md");
  assert.match(doc, /template and rendering only/i);
  assert.match(doc, /does not classify, evaluate policy, claim or write the ledger, schedule, or send email/i);
  assert.match(doc, /Shared → D → C → B → A/);
  assert.match(doc, /FPW_BUSINESS_MAILING_ADDRESS/);
});
