import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const policy = read("includes/InactiveMemberRecoveryPolicy.cfc");

test("policy has no I/O, runtime clock, shared state, or remote entry point", () => {
  assert.doesNotMatch(policy, /\b(remote|queryExecute|cfquery|cfmail|cfschedule|cfhttp|fileWrite|fileRead|writeLog|now|dateDiff|dateAdd)\s*[({]|\b(remote)\s+(?:struct|any|boolean)\s+function|\b(application|session|request|server|variables)\./i);
  const dependencies = [...policy.matchAll(/createObject\("([^"]+)",\s*"([^"]+)"\)/g)];
  assert.equal(dependencies.length, 2);
  assert.ok(dependencies.every((match) => match[1] === "java" && match[2] === "java.time.Instant"));
  assert.match(policy, /var eligibleAt = anchor \+ 604800;/);
  assert.match(policy, /nowClock\.seconds >= eligibleAt/);
});

test("policy is wired only into the approved read-only classifier", () => {
  const excluded = new Set([".git", ".codex-snapshots", "node_modules", "tests", "docs", "vendor"]);
  const matches = [];
  function scan(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      if (excluded.has(entry.name)) continue;
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) scan(absolute);
      else if (entry.isFile() && /\.(?:cfc|cfm|js|mjs)$/i.test(entry.name)) {
        const relative = path.relative(root, absolute);
        if (relative !== "includes/InactiveMemberRecoveryPolicy.cfc" && /InactiveMemberRecoveryPolicy/.test(fs.readFileSync(absolute, "utf8"))) matches.push(relative);
      }
    }
  }
  scan(root);
  assert.deepEqual(matches, ["includes/InactiveMemberRecoveryClassifierService.cfc"]);
  const classifier = read(matches[0]);
  assert.match(classifier, /public struct function evaluateMember\s*\(/);
  assert.doesNotMatch(classifier, /\b(?:cfmail|cfschedule|sendMultipartEmail|claimStage|markSent|markFailed)\s*\(/i);
});

test("runtime tests are in-memory and the runner requires local confirmation", () => {
  const spec = read("tests/specs/InactiveMemberRecoveryPolicySpec.cfc");
  const runner = read("tests/inactive-member-recovery-policy-runner.cfm");
  assert.doesNotMatch(spec, /queryExecute|cfquery|cfmail|fileWrite|transaction\s*\{|datasource\s*=/i);
  assert.match(runner, /serverPort EQ 8500/);
  assert.match(runner, /OR NOT isLocal/);
  assert.match(runner, /RUN_INACTIVE_MEMBER_RECOVERY_POLICY_TESTS/);
  assert.match(runner, /statuscode="404"/);
  assert.match(runner, /fpw\.tests\.specs\.InactiveMemberRecoveryPolicySpec/);
});

test("contract documents the approval boundary and prerequisites", () => {
  const doc = read("docs/inactive-member-recovery-threshold.md");
  assert.match(doc, /APPROVED — 7 DAYS; policy-only implementation/);
  assert.match(doc, /Sending is not enabled or authorized/);
  assert.match(doc, /saved named route counts as C without legs/);
  assert.match(doc, /both at claim time and immediately before sending/);
  assert.match(doc, /absent instrumentation is not inactivity/);
  assert.match(doc, /This task does not add those records/);
});
