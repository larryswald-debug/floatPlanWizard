import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const classifier = read("includes/InactiveMemberRecoveryClassifierService.cfc");

const activityEvents = [
  "vessel_created", "vessel_updated",
  "shore_contact_created", "shore_contact_updated",
  "operator_created", "operator_updated",
  "passenger_created", "passenger_updated",
  "waypoint_created", "waypoint_updated",
  "user_route_created", "user_route_updated",
  "route_created", "route_updated", "route_segment_updated",
  "float_plan_created", "float_plan_updated"
];

test("classifier is a read-only single-member service", () => {
  assert.match(classifier, /public struct function evaluateMember\s*\(/);
  assert.doesNotMatch(classifier, /\b(?:INSERT\s+INTO|UPDATE\s+[`A-Za-z_]|DELETE\s+FROM|REPLACE\s+INTO)\b/i);
  assert.doesNotMatch(classifier, /\b(?:cfmail|cfschedule|sendMultipartEmail|recordRequiredMemberActivity|claimStage|markSent|markFailed)\s*\(/i);
  assert.doesNotMatch(classifier, /\bremote\s+(?:struct|any|boolean|string|numeric)\s+function/i);
});

test("classifier integrates existing policy, preference, admin, share, ledger, and activity authorities", () => {
  assert.match(classifier, /InactiveMemberRecoveryPolicy/);
  assert.match(classifier, /EmailOptOutService/);
  assert.match(classifier, /AdminAuthorizationService/);
  assert.match(classifier, /\.isOptedOut\(normalizedEmail,\s*"non_essential"\)/);
  assert.match(classifier, /\.authorizeCurrentSession\(\{userId=/);
  assert.match(classifier, /inactive_member_recovery_deliveries/);
  assert.match(classifier, /basic_send_completed/);
  assert.match(classifier, /premium_send_completed/);
  assert.match(classifier, /basic_review_send_receipts/);
  assert.match(classifier, /premium_send_receipts/);
  assert.match(classifier, /initialSentAt/);
  for (const eventName of activityEvents) assert.match(classifier, new RegExp(`'${eventName}'`));
});

test("stable decision codes and privacy-safe result contract are present", () => {
  for (const code of [
    "ELIGIBLE", "SUPPRESSED_ALREADY_SHARED", "SUPPRESSED_OPTED_OUT", "SUPPRESSED_ADMIN",
    "SUPPRESSED_INVALID_EMAIL", "SUPPRESSED_ACTIVE_TRIP", "SUPPRESSED_STAGE_ALREADY_SENT",
    "SUPPRESSED_UNRESOLVED_CLAIM", "SUPPRESSED_RECENT_ACTIVITY",
    "SUPPRESSED_CROSS_STAGE_SPACING", "HOLD_INCOMPLETE_STAGE_CLOCK",
    "HOLD_INCOMPLETE_ACTIVITY_EVIDENCE", "HOLD_CONTRADICTORY_EVIDENCE",
    "HOLD_PREFERENCE_LOOKUP_FAILED", "HOLD_DUPLICATE_EMAIL_IDENTITY", "MEMBER_NOT_FOUND"
  ]) assert.match(classifier, new RegExp(`"${code}"`));

  const baseResult = classifier.slice(classifier.indexOf("private struct function baseResult"));
  assert.doesNotMatch(baseResult, /\b(?:EMAIL|VESSEL_NAME|ROUTE_NAME|CONTACT_NAME|COORDINATES|FOLLOW_TOKEN|TRIP_DETAILS)\s*=/i);
});

test("classifier is wired only through the approved recovery orchestration service", () => {
  const excluded = new Set([".git", ".codex-snapshots", "node_modules", "tests", "docs", "vendor"]);
  const matches = [];
  function scan(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      if (excluded.has(entry.name)) continue;
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) scan(absolute);
      else if (entry.isFile() && /\.(?:cfc|cfm|js|mjs)$/i.test(entry.name)) {
        const relative = path.relative(root, absolute);
        if (relative !== "includes/InactiveMemberRecoveryClassifierService.cfc"
          && /InactiveMemberRecoveryClassifierService/.test(fs.readFileSync(absolute, "utf8"))) matches.push(relative);
      }
    }
  }
  scan(root);
  assert.deepEqual(matches, ["api/v1/InactiveMemberRecoveryService.cfc"]);
});

test("runtime runner is local-only and requires explicit confirmation", () => {
  const runner = read("tests/inactive-member-recovery-classifier-runner.cfm");
  assert.match(runner, /serverPort EQ 8500/);
  assert.match(runner, /OR NOT isLocal/);
  assert.match(runner, /RUN_INACTIVE_MEMBER_RECOVERY_CLASSIFIER_TESTS/);
  assert.match(runner, /statuscode="404"/);
  assert.match(runner, /fpw\.tests\.specs\.InactiveMemberRecoveryClassifierSpec/);
});

test("contract documents conservative evidence and the no-send boundary", () => {
  const doc = read("docs/inactive-member-recovery-classifier.md");
  assert.match(doc, /Shared → D → C → B → A/);
  assert.match(doc, /saved named route with zero legs counts as C/);
  assert.match(doc, /NO_QUALIFYING_ACTIVITY_EVIDENCE/);
  assert.match(doc, /caller-supplied enrollment UTC is an explicit upstream attestation/);
  assert.match(doc, /does not send email, claim recovery, or write the ledger/);
  for (const eventName of activityEvents) assert.match(doc, new RegExp(`\\b${eventName}\\b`));
});
