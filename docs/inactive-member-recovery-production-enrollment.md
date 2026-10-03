# Day 39: production recovery enrollment

> Recovery Center update (2026-10-03): historical behavior and validation results below predate the numbered-contact transition. The current model has exactly three automated contacts, independently recalculated A/B/C/D destinations, and configurable First Delay / Contact Interval / Attribution Window defaults of 24 / 24 / 24 hours. Stage-keyed delivery rules and fixed 168-hour rollout instructions below are superseded. See [Recovery Center implementation](recovery-center.md) and [current email copy](recovery-center-email-copy.md). Historical test results are retained as historical evidence.

Implementation and local verification: 2026-09-24.

**Production-capable enrollment callers are implemented and locally verified. They have not been deployed or exercised against production.** No production member was enrolled, no recovery email was sent, and no live-send configuration or recurring schedule was changed.

## New-member path and timing

The authoritative account-creation path is `api/v1/join.cfc::handle()`. It validates the request and rejects duplicate accounts before its required signup transaction. That transaction persists the user, applicable address and credit records, and canonical signup/coverage evidence.

Immediately after the transaction commits, at `join.cfc:327`, it calls the new private `enrollNewMemberForRecovery(newUserId)`, before initializing the authenticated session and continuing the existing signup response and welcome flow. Only the newly inserted, server-side user ID reaches `InactiveMemberRecoveryEnrollmentService.ensureEnrolled()`. No browser-supplied dates, coverage assertions, or metadata are accepted.

The helper at `join.cfc:412` contains service construction, execution, malformed responses, and logging failures. A noncritical enrollment failure cannot turn committed account creation into failed signup. There is no automatic retry loop. Its stable result is recorded by `writeRecoveryEnrollmentAudit()` at line 439 in the application's `logs/fpw_recovery_enrollment.log` file: user ID plus an allowlisted outcome code, without email addresses or raw exceptions. An enrollment failure therefore needs later investigation or an explicitly reviewed cohort attempt.

Anonymous visits, rejected registrations, and duplicate-account attempts never reach this hook. The existing service rejects missing users and applies its existing enrollment assessment.

## Existing-member administrative path

New page: `admin/recovery-enrollment.cfm`, available from the existing admin navigation as **Recovery Enrollment**.

New service: `api/v1/AdminRecoveryEnrollmentService.cfc`. It reuses the existing `AdminAuthorizationService`, `AdminAuditService`, and enrollment/coverage services. Existing `Application.cfc` admin authorization and POST CSRF checks remain in place; the service additionally checks current authorization, request method, and CSRF.

1. Enter an explicit list of **1–100 distinct positive user IDs**, separated by commas or whitespace, then select **Preview selected members**. Invalid formats, duplicate IDs, and out-of-range IDs reject the batch without enrollment writes. Missing valid IDs receive `MEMBER_NOT_FOUND` rows.
2. `preview()` / `buildPreview()` calls the existing enrollment assessment for each ID and separately reads coverage. The database is read-only during preview. The result shows each ID, outcome, reason, original enrollment UTC where present, and coverage **at review**.
3. The server retains the reviewed rows and eligible subset in the admin session, bound to that admin, a random review token, and a 15-minute expiration.
4. The admin explicitly confirms the displayed eligible selection and submits **Enroll reviewed eligible members**. POST accepts the review token and confirmation, not replacement IDs. Unsupported posted fields are rejected.
5. `enroll()` consumes the token under an exclusive session lock. `executeReviewed()` calls existing `ensureEnrolled()` only for the IDs marked `ENROLLABLE` in that server-side review. Current eligibility is rechecked by that service under its existing member-row lock. A newly opted-out or otherwise disqualified member is skipped; a member enrolled in the meantime retains the original timestamp.
6. IDs skipped at preview are never promoted into the enrollment operation without a new preview. Replayed, expired, forged, or cross-actor review tokens cannot repeat the command.

The page reports scanned, eligible/reviewed eligible, already enrolled, newly enrolled, skipped, failures, and reason counts plus per-member outcomes. Enrollment eligibility is distinct from current eligibility to receive a message.

The service writes `recovery_enrollment_reviewed` and per-member `recovery_enrollment_result` records through `AdminAuditService.record()` to `fpw_admin_audit_log`, with a shared operation ID and user IDs/outcome/reason codes. If the initial required audit fails, no enrollment starts. If a later result audit fails, already committed enrollments remain reported, remaining writes stop, and the report flags incomplete auditing. A fresh preview is required before retrying.

There is no database-wide selection, scheduled enrollment, automatic legacy backfill, or sender invocation.

## Existing contracts preserved

- **Idempotency:** unchanged `InactiveMemberRecoveryEnrollmentService.ensureEnrolled()` uses a read-committed transaction, `users ... FOR UPDATE`, assessment, event insertion, and verified readback. The authoritative event is `product_events.event_name = inactive_member_recovery_enrolled`, source `recovery_enrollment`, entity `user`, empty metadata, with key `inactive_member_recovery_enrolled:<userId>`. Existing unique index `uq_product_events_idempotency` protects `idempotency_key`; the index was confirmed in the local database. Existing valid enrollment returns `ALREADY_ENROLLED` with its original UTC timestamp.
- **UTC timing:** the callers supply no timestamp. The existing event writer supplies current database UTC for new evidence. Old members are not backdated.
- **168 hours:** unchanged `InactiveMemberRecoveryPolicy.evaluate()` uses the latest verified enrollment, current-stage entry, qualifying activity, and applicable previous-send clock, plus 604800 seconds. Tests prove defer at 167h59m59s and eligibility at 168h when all other gates pass.
- **Coverage:** the existing signup transaction still records its independent canonical coverage evidence. Enrollment does not create or attest coverage. Cohort enrollment only reads it. Missing historical coverage continues to hold sending after enrollment and after the interval.
- **Account state:** missing/deleted users are rejected by the existing service. No new disabled-account feature was introduced; inspection of the current local `users` columns found no authoritative enabled/disabled flag.
- **Sending:** stage classification, suppression, delivery ledger, duplicate-send prevention, recovery templates, CTA destinations, and scheduler execution are unchanged by this enrollment task.

## Files changed for this task

Earlier CTA changes already present in this checkout are separate and were preserved.

Production code:

| File | Change |
|---|---|
| `api/v1/join.cfc` | Post-commit enrollment hook and contained, sanitized audit helper |
| `api/v1/AdminRecoveryEnrollmentService.cfc` | New authorized preview and reviewed cohort execution |
| `admin/recovery-enrollment.cfm` | New bounded preview, explicit confirmation, and results page |
| `admin/includes/admin_reports_nav.cfm` | Add Recovery Enrollment link |
| `includes/InactiveMemberRecoveryEnrollmentService.cfc` | Comment update only; executable text unchanged |
| `includes/InactiveMemberRecoveryCoverageService.cfc` | Comment update only; executable text unchanged |

Documentation:

- `docs/inactive-member-recovery-production-enrollment.md` — this report.
- `docs/inactive-member-recovery-enrollment.md` — mark the earlier checkpoint historical and link this production-caller update.

New tests and supporting files:

- `tests/specs/InactiveMemberRecoverySignupSpec.cfc`
- `tests/support/RecoverySignupEnrollmentStub.cfc`
- `tests/inactive-member-recovery-signup-runner.cfm`
- `tests/specs/InactiveMemberRecoveryEnrollmentIntegrationSpec.cfc`
- `tests/support/RecoveryEnrollmentIntegrationFixture.cfc`
- `tests/support/RecoveryEnrollmentAuditStub.cfc`
- `tests/inactive-member-recovery-enrollment-integration-runner.cfm`
- `tests/inactive-member-recovery-enrollment-integration-fixture.cfm`
- `tests/inactive-member-recovery-enrollment-integration.playwright.js`
- `tests/inactive-member-recovery-readiness-dry.playwright.js`

Updated test files:

- `tests/inactive-member-recovery-enrollment.playwright.js` — expect enrollment after actual signup; preserve clock and concurrency assertions.
- `tests/inactive-member-recovery-readiness.playwright.js` — expect automatic signup enrollment and later `ALREADY_ENROLLED`.
- `tests/inactive-member-recovery-readiness-command.cfm` — derive the test clock from the existing classifier's reported `POLICY_DECISION.anchor_utc`, because saved stage activity can follow automatic enrollment. This changes only the local test fixture; no production clock or policy changed.

MCPCF snapshots cover edits to existing files under `.codex-snapshots/fpw-patches/`. New-file absence was checked before creation. Additional checkout/scope evidence is under `.codex-snapshots/20260924-recovery-production-enrollment/`.

## Local verification results

All runtime and browser checks used local disposable fixtures. MCPCF ran the ColdFusion suites; MCP Playwright executed the browser scripts. Local Node and Git validation used the user's previously authorized fallback.

### ColdFusion recovery suites

The matching runners are `tests/inactive-member-recovery-<name>-runner.cfm`.

| Name / spec component under tests/specs | Passed / total |
|---|---:|
| policy / InactiveMemberRecoveryPolicySpec | 29 / 29 |
| classifier / InactiveMemberRecoveryClassifierSpec | 32 / 32 |
| enrollment / InactiveMemberRecoveryEnrollmentSpec | 15 / 15 |
| ledger / InactiveMemberRecoveryLedgerSpec | 4 / 4 |
| sender / InactiveMemberRecoverySenderSpec | 16 / 16 |
| readiness / InactiveMemberRecoveryReadinessSpec | 30 / 30 |
| email-template / InactiveMemberRecoveryEmailTemplateSpec | 13 / 13 |
| destination / InactiveMemberRecoveryDestinationSpec | 15 / 15 |
| action-path / InactiveMemberRecoveryActionPathSpec | 12 / 12 |
| signup / InactiveMemberRecoverySignupSpec | 7 / 7 |
| enrollment-integration / InactiveMemberRecoveryEnrollmentIntegrationSpec | 8 / 8 |
| **Recovery subtotal** | **181 / 181** |

The new signup tests cover ID-only invocation, stable outcomes, exceptions, malformed responses, logging failure containment, single enrollment/current clock, and no ledger/transport activity. The cohort specs cover preview without writes, strict bounds, reviewed-only execution, repeated/concurrent state changes, opt-outs, independent coverage holds, 168-hour timing, initial/result audit failures, and enrollment persistence rollback.

### Related regressions and local checks

| Check | Result |
|---|---|
| `tests/onboarding-runner.cfm` | 10 / 10 specs passed |
| `tests/member-activity-evidence-runner.cfm` | 2 / 2 default compilation/input checks passed; full fixture-driven activity integration was not run |
| `tests/non-essential-email-compliance-runner.cfm` | 7 / 8 specs passed; one pre-existing stale checksum failure below |
| `tests/recovery-component-path-runner.cfm` | 7 / 7 checks passed in the local subdirectory mount |
| Six Node recovery suites | 37 / 37 tests passed |
| Git whitespace/scope checks | Passed after removing patch-tool-introduced EOF artifacts |

Total executed ColdFusion specs: **200 passed, 1 failed, 0 errors**. Component-path checks are separate.

Node command:

```sh
node --test tests/inactive-member-recovery-policy.test.mjs tests/inactive-member-recovery-classifier.test.mjs tests/inactive-member-recovery-enrollment.test.mjs tests/inactive-member-recovery-ledger.test.mjs tests/inactive-member-recovery-sender.test.mjs tests/inactive-member-recovery-email-template.test.mjs
```

The compliance failure is at `tests/specs/NonEssentialEmailComplianceSpec.cfc:232`, in “preserves the operational builders and keeps diagnostics token-free.” Its fixture `tests/fixtures/operational-email-function-sha256.json:10` expects an obsolete checksum for `api/v1/email.cfc::buildSafeArrivalCaptainEmail()`. Commit `1c5f86b82f7b18e22b3c6b183948665191a5253d` (2026-09-23) added the fallback URL at current `email.cfc:849` without updating that fixture. Read-only Git/Node comparison found the expected hash in that commit's parent, and the actual hash in that commit, current HEAD, and this checkout. All eight operational email functions are unchanged from HEAD. The unrelated email code and checksum fixture were left untouched.

### Browser assertions

| Executed script | Passed |
|---|---:|
| `tests/inactive-member-recovery-enrollment-integration.playwright.js` | 36 |
| `tests/inactive-member-recovery-enrollment.playwright.js` | 22 |
| `tests/inactive-member-recovery-readiness-dry.playwright.js` | 39 |
| **Total** | **97** |

Coverage includes actual successful/rejected/duplicate signup, real admin-page preview and commit, anonymous/non-admin denial, CSRF, forged/replayed/expired tokens, explicit confirmation, replacement-ID rejection, selection bounds, first-enrollment concurrency, opt-out between preview and commit, and canonical signup/vessel/route/draft stages with exact interval boundaries.

All scripts returned success with no error. Exact fixture cleanup reported zero remaining accounts/events/ledger evidence as applicable, and seven exact-recipient MailHog checks returned zero messages. No recovery transport was invoked as part of enrollment. The full readiness browser `dueSend` workflow was **not run**, because it would exercise real email transport; the dry-only script covers timing without delivery.

Fourteen protected files, including policy, classifier, ledger, sender, email, CTA services, dashboard/auth assets, and scheduled runner, matched their start-of-task hashes. Enrollment and coverage service executable text matched HEAD; only their outdated comments changed. No staging, commit, push, deployment, production configuration, production data, or scheduler mutation was performed.

## Before production dry-run verification

1. Review and deploy the enrollment production files above through the normal deployment process. Preserve the already required recovery dependencies and earlier validated CTA work. No new schema migration is introduced.
2. Confirm production can resolve the deployed components and existing `users`, `product_events` (including its unique idempotency index), admin entitlement, and `fpw_admin_audit_log` objects. Local subdirectory checks do not prove the production mount/runtime.
3. Have an authorized administrator open Recovery Enrollment and preview an explicitly selected list of production IDs. Verify the reported enrollment states, skip reasons, original timestamps, and independent coverage. Stop at preview for this verification.

Actual existing-member enrollment requires a separately reviewed, explicit action. Live recovery sending and recurring schedule activation remain outside this task.

## Enrollment diagnostics update — 2026-09-25

This update follows a production preview displaying `ENROLLMENT_FAILED` with a blank reason despite independently verified coverage. The confirmed diagnostic defect was that `assessEnrollment()` discarded its exception and `AdminRecoveryEnrollmentService.outcomeRow()` discarded failed-result details. The underlying production exception remains unconfirmed; these changes make the next occurrence diagnosable.

Production files for this update:

- `includes/InactiveMemberRecoveryEnrollmentService.cfc`: both assessment and enrollment-write catches return safe diagnostic reasons and an `ERROR_REFERENCE`. Assessment failures retain their original reference through writer rollback. The private diagnostic helper tolerates ColdFusion exception objects, malformed fields, and unavailable logging.
- `api/v1/AdminRecoveryEnrollmentService.cfc`: failed outcomes preserve only allowlisted reasons and strictly validated diagnostic UUIDs; invalid or absent diagnostics receive a nonblank generic reason. Successful outcomes carry no failure reference.
- `admin/recovery-enrollment.cfm`: the admin table shows an HTML-encoded diagnostic reference and instructions for locating it in the application's `/logs/fpw_recovery_enrollment.log` file.

The application log is `logs/fpw_recovery_enrollment.log`, resolved from the deployed application root, with marker `RECOVERY_ENROLLMENT_FAILURE`. It is written by a timestamped UTF-8 append; access to ColdFusion's server log directory is not required. Look up the reference shown in the admin row. Each record contains the member ID, operation, failing step, reason, exception type, available SQLState/native error code, a recognized missing table/column identifier where available, and at most five source filenames/line numbers. Filename and identifier lengths are bounded. Raw messages/details, SQL statements and values, request bodies, credentials, email addresses, absolute paths, and full stack traces are not logged or sent to the browser.

Possible failure reasons:

| Reason | Meaning |
|---|---|
| `ENROLLMENT_EVIDENCE_INVALID` | Existing enrollment evidence failed the existing strict validation |
| `ENROLLMENT_DATABASE_ERROR` | A database exception was caught; consult its error codes and source location |
| `ENROLLMENT_COMPONENT_ERROR` | Classifier construction failed |
| `ENROLLMENT_ASSESSMENT_ERROR` | Another assessment exception was caught |
| `ENROLLMENT_WRITE_ERROR` | Enrollment execution or event confirmation failed |

These are diagnostic categories, not new lifecycle or eligibility rules. All existing enrollment decisions, SQL, locks, rollback, unique-event semantics, timing, coverage, and sending behavior are preserved. A failed log write cannot fail signup or replace the original safe enrollment failure.

Limits: this change diagnoses exceptions caught by the enrollment service. It does not recover exceptions already discarded inside `ProductEventService.recordEvent()`, and it does not add a new diagnostic mechanism for unrelated coverage or audit failures. References are generated even if logging is unavailable; production log availability still needs verification.

Updated regression files are `tests/specs/InactiveMemberRecoveryEnrollmentSpec.cfc`, `tests/specs/InactiveMemberRecoveryEnrollmentIntegrationSpec.cfc`, `tests/inactive-member-recovery-enrollment-integration-fixture.cfm`, and `tests/inactive-member-recovery-enrollment-integration.playwright.js`. They cover diagnostic redaction and bounds, real ColdFusion exception objects, logging failure containment, reference preservation through rollback, failed preview with verified coverage and no writes, and the rendered admin failure row. The fixture corruption is restricted to an exact disposable account in the local test environment and removed during cleanup.

Local validation for the original diagnostic handling update, before the application log destination change below: **191/191 ColdFusion recovery specs**, **37/37 Node tests**, and **43 MCP Playwright browser assertions** passed. The ColdFusion totals include 21 enrollment and 12 cohort integration specs. The browser cleanup reported zero remaining fixture users/events/ledger/attempted/submitted counts and zero matching MailHog messages. Git whitespace and protected-file checks passed. The separate pre-existing compliance checksum failure documented in the September 24 report was not changed or rerun for this diagnostics-only update. No production files, data, configuration, enrollment, schedules, or mail were changed during this update. For the original diagnostic handling update, the deployment list consisted of the three production files above. The application log destination update below also changes `api/v1/join.cfc`. After deploying the complete current change, repeat the authorized **preview** to obtain the production diagnostic reason/reference. That preview does not enroll the member.

## Application log destination update — 2026-09-25

Recovery diagnostics and signup enrollment outcome records now append to the deployed application's `logs/fpw_recovery_enrollment.log` file. The destination is relative to the application root in both root-mounted production and the local `/fpw` application. The admin failure guidance displays `/logs/fpw_recovery_enrollment.log`; this names the application file, not a public download link. Each UTF-8 record has a timestamp. Diagnostic redaction, bounded fields, and nonfatal logging failure containment are preserved.

Production files for this destination change are `includes/InactiveMemberRecoveryEnrollmentService.cfc` (`writeEnrollmentDiagnostic()`), `api/v1/join.cfc` (`writeRecoveryEnrollmentAudit()`), and `admin/recovery-enrollment.cfm` (log-location guidance). `AdminRecoveryEnrollmentService.cfc` retains the prior diagnostic-reference behavior without a further change. No enrollment, eligibility, policy, coverage, scheduling, or sending behavior changes.

The deployed application process must have permission to create or append to this file in its `logs` directory. Logging remains nonfatal if that access fails, so a displayed reference alone does not prove a record was written. Production path and write access still require deployment verification.

Destination-specific local validation: **42/42 ColdFusion specs** passed (enrollment 22, signup 8, cohort integration 12), plus **8/8 Node enrollment checks** and Git whitespace checks. The new tests invoked both real file writers and read back their timestamped records from the application log, verifying that prior contents were retained. The local file was confirmed readable and writable. Existing tests also confirmed that unavailable logging does not replace the original enrollment failure or fail committed signup. No production deployment or production writes were performed.
