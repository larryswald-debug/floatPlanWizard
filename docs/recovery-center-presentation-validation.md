# Recovery Center presentation and email validation

Date: 2026-10-03. Local development only; production sending remains outside this implementation.

## Implemented

- `api/v1/email.cfc`: contact #1/#2/#3 independently selects approved copy for the current A/B/C/D destination; shared layout, CTA labels, personalization, and compliance footer remain. Result includes separate contact, destination, and versioned template identity. Optional tracking links must match the canonical local/public mounted endpoints. Personal subject/body are validated, plain-text HTML is escaped, and personal transport uses its own message type. Recovery-only transport logging excludes recipients, subjects, bearer tokens, and transport exception text.
- `admin/recovery-center.cfm`, `assets/js/admin-recovery-center.js`, `assets/css/admin-recovery-center.css`: six views with current-versus-historical contact/destination labels, search/filter/pagination, run detail, member state/actions/evaluations/timeline, real previews in a network-disabled sandbox, personal confirmation flow, cohort performance, timing impact review, reset review, and audit history.
- `admin/includes/admin_reports_nav.cfm`: Recovery Center entry.
- `admin/recovery-enrollment.cfm`: timing displayed from current settings; settings failure is explicit.
- `docs/recovery-center-email-copy.md`: all 12 approved presentations, exact CTA labels, template IDs, personal copy handling, and result semantics.
- Historical validation reports receive a dated supersession notice; their historical test results are not rewritten.

## Completed checks

- MCPCFC TestBox email template runner: **17/17 passed**, including all twelve contact/destination combinations, invalid contact numbers, destination security, signed compliance, tracking URL restrictions, escaping, and personal header-injection rejection.
- Node email-template contract suite: **7/7 passed**.
- JavaScript syntax checks pass.
- NonEssentialEmailCompliance suite: **7/8 passed**. The existing operational-function hash assertion fails for `buildSafeArrivalCaptainEmail`. All eight guarded operational functions are byte-identical to the checksummed pre-edit snapshot. This mismatch therefore predates this feature: snapshot/current SHA-256 `136dd35a82ff22688641581d1f7ed98f6ff9815cc84d0ecb16d0f525a84959ec`; fixture expects `6f3ec635846ee5d161e22f0bb22d3def8328f6a6332ec19afaf99ea8e6a48726`. No golden hashes were changed.
- MCPCFC Playwright runner could not launch because its container process has no Node/npx. Interactive MCP Playwright is used after the parent agent released its browser profile; no shell browser fallback was used.
- Interactive MCP Playwright Recovery Center proof: **73/73 passed**. All six tabs loaded; queue pagination returned distinct members; current/historical previews redacted bearer tokens and blocked navigation/network activity; pause/resume/exclude/remove preserved clock/contact; invalid timing, CSRF, unauthorized access, arbitrary recipients, and header injection were rejected. A stale settings review was rejected after member state changed. Contact and destination labels remained independent.
- The personal follow-up test revalidated isolated local MailHog immediately before submission, accepted exactly one message, and replayed the **same valid consumed review token**: replay was rejected and no second message appeared. The automated contact remained #1. The fixture's one captured MailHog message and disposable database records were removed.
- Desktop screenshots cover all six tabs; mobile member detail has no document-level horizontal overflow. No Recovery Center JavaScript errors were observed. All screenshots were visually inspected.
- Authorized one-time local rollout through the real Settings UI: **11/11 checks passed** after the fresh post-schema database backup. Exact details are below.

## Test/support files

- Updated `tests/specs/InactiveMemberRecoveryEmailTemplateSpec.cfc`.
- Added `tests/recovery-center.playwright.js` and `tests/recovery-center.spec.js`.
- Used the temporary `tests/recovery-center-local-reset.playwright.js` for the approved one-time UI reset/dry-run proof. It is now archived at `.codex-snapshots/20261003T202352Z-recovery-commit-cleanup/files/tests/recovery-center-local-reset.playwright.js`; its observed 11/11 result remains historical evidence.
- Added local-only `tests/recovery-center-diagnostic.cfm` for compilation/read-only diagnostic requests.
- Extended `tests/support/RecoveryEnrollmentIntegrationFixture.cfc` and `tests/inactive-member-recovery-enrollment-integration-fixture.cfm` with an explicit `prepareCenter` disposable account and scoped cleanup of new recovery child records.

## Boundaries

All eight guarded operational-email function blocks remain byte-identical to the pre-edit snapshot. The shared multipart transport gained an optional recovery-only redaction flag that defaults to false for existing callers. No contact is sent by rendering, preview, settings save, reset review, or state controls. The reusable browser suite never commits the global initial reset; the separate authorized one-time rollout script performed that action against the independently verified original cohort. Its personal-mail proof requires a fresh server probe confirming local MailHog before submission and removes only the fixture's captured mail.

## Evidence paths

Pre-edit file snapshot: `.codex-snapshots/20261003T165055Z-recovery-center/files/`.
Browser screenshot/result directory: `.codex-snapshots/20261003T165055Z-recovery-center/ui/`.
- `results.json`: complete 73-assertion result, cleanup status, zero console errors, and one local fixture email removed.
- `dashboard-desktop.png`, `recovery-queue-desktop.png`, `runs-desktop.png`, `members-desktop.png`, `performance-desktop.png`, `settings-desktop.png`, and `members-mobile.png`.
- `settings-reset-complete.png`: actual local reset completion and audit.
- `local-reset-results.json`: sanitized actual-reset/dry-run/database verification record.

## Actual local recovery-start reset

The root agent completed and verified the pre-reset database backup at `/Users/lawrencewald/.codex/backups/fpw/20261003T165055Z-recovery-center/FPW-before-reset.sql` (3,534,998 bytes; SHA-256 `5250c48ff7f805382f13e1fdad153e2c217eacc25730ee513a070443b128b8b8`) before giving the reset go.

MCPCFC independently verified exactly enrollment event **5090 / member 3752** and **6500 / member 4464**, plus zero delivery/message rows before reset. The real admin Settings preview returned exactly two enrollments; its checkbox confirmation was required. The reset committed shared database UTC **2026-10-03T17:36:28Z**, count **2**, operation `1C6305CD-DF84-D343-04A254C21CEC42CE`, and audit row **1320**. First delay/contact interval/attribution stayed **24 / 24 / 24 hours**; revision remained **3**. The earlier disposable same-value settings-save tests account for revisions 2 and 3.

Original enrollment timestamps remain **2026-09-25T00:49:22Z** and **2026-10-02T14:39:09Z**. Both member-state records use the shared effective start, with pause/exclusion false. Repeating reset preview returned `RESET_ALREADY_COMPLETED`; replaying its consumed review token returned `REVIEW_REQUIRED`.

Fixed dry-run execution **30** (`local_rollout_validation`) completed with **2 evaluated**, both **Contact #1 / Destination A**, **2 waiting**, **0 eligible**, and **0 claims, submissions, accepted sends, failures, holds, or observation gaps**. Both immutable evaluations preserve initial `DEFERRED / DEFERRED_WAITING_FOR_INTERVAL` and resulting eligibility **2026-10-04T17:36:28Z**. Final processing decision is `SKIPPED` with the same waiting reason.

Post-run MCPCFC verified ledger **0**, messages **0**, original enrollment rows unchanged, state/reset history retained, and disposable administrator **5792** absent. No production send was enabled or performed.

## Inspected paths for this subsystem

Production source and schema: `api/v1/email.cfc`; `api/v1/AdminRecoveryEnrollmentService.cfc`; `api/v1/AdminRecoveryCenterService.cfc`; `api/v1/AdminAuditService.cfc`; `admin/includes/admin_reports_nav.cfm`; `admin/recovery-enrollment.cfm`; `admin/recovery-center-data.cfm`; `includes/InactiveMemberRecoverySettingsService.cfc`; `includes/InactiveMemberRecoveryObservabilityService.cfc`; `database/migrations/20261003_001_recovery_center.up.sql`.

Test/support source: `tests/specs/InactiveMemberRecoveryEmailTemplateSpec.cfc`; `tests/inactive-member-recovery-email-template-runner.cfm`; `tests/inactive-member-recovery-email-template.test.mjs`; `tests/non-essential-email-compliance-runner.cfm`; `tests/specs/NonEssentialEmailComplianceSpec.cfc`; `tests/fixtures/operational-email-function-sha256.json`; `tests/auth-mail-safety-probe.cfm`; `tests/inactive-member-recovery-enrollment-integration.playwright.js`; `tests/inactive-member-recovery-enrollment-integration-fixture.cfm`; `tests/support/RecoveryEnrollmentIntegrationFixture.cfc`; `tests/support/RecoveryReadinessFixture.cfc`; `tests/support/RecoveryEnrollmentFixture.cfc`; `tests/support/RecoveryOrchestrationFixture.cfc`; `tests/inactive-member-recovery-destination.spec.js`; `tests/admin-email-diagnostic.spec.js`; `tests/recovery-center-local-rollout.cfm`; `tests/support/RecoveryCenterLocalCohort.cfc`.

Existing documentation reviewed and given supersession notices: `docs/inactive-member-recovery-ledger.md`; `docs/inactive-member-recovery-sender.md`; `docs/inactive-member-recovery-readiness.md`; `docs/inactive-member-recovery-enrollment.md`; `docs/inactive-member-recovery-final-validation.md`; `docs/inactive-member-recovery-production-enrollment.md`; `docs/inactive-member-recovery-destinations.md`; `docs/inactive-member-recovery-basic-draft-validation.md`; `docs/member-activity-evidence.md`. The core-engine agent subsequently owns the detailed ledger/sender documentation revisions.

## Final pagination and scheduler verification

A final review found silent 100-row product-history and 200-row evaluation/message limits. The narrow correction adds independent server-side pages for member messages, eligibility history, product/recovery history, run evaluations, and settings audit. Every response preserves the existing arrays and adds explicit total, current page, total pages, and page size. SQL fetches are bounded to at most 100 rows; stable timestamp/ID ordering and bound numeric parameters preserve safe reporting. UI Next/Previous controls display exact totals independently for each collection. Settings audit is now fully pageable instead of silently limited to 30 rows.

The all-time missing-ledger-telemetry label explicitly says it covers all contacts/destinations, independent of selected message filters.

- Focused affected observability/reporting suite: **29/29 passed**. The new regression reaches all **201 messages**, all **201 evaluations**, and all history beyond the former 100-row limit without duplicates, including the third 100-row run-evaluation page. It checks audit rows beyond the old 30-row limit, invalid page selectors, and the 100-row bound.
- Targeted interactive MCP Playwright pagination proof: **33/33 passed**, using 26 prepared (unsent) message and evaluation fixture records. Real authenticated API page boundaries and independent Next/Previous controls were checked for member history/messages/evaluations, run evaluations, and audit. Injection selectors were rejected, no console errors occurred, and reset T0/count were unchanged. No mail or setting change was performed.
- Evidence: `.codex-snapshots/20261003T165055Z-recovery-center/ui/pagination-results.json` and visually inspected `member-history-pagination.png`.
- Native ColdFusion scheduler checked with **cfschedule action=list only** at **2026-10-03T17:50:07Z**: server task **Run Recover User**, status **Paused**. Four server tasks, zero application tasks. Evidence: `ui/native-scheduler-post-validation.json`.
- Post-proof DB: only genuine rollout run **30** and its **2 evaluations** remain; state **2**, ledger **0**, messages **0**, settings audit **1**, reset **2026-10-03T17:36:28Z / count 2 / revision 3**.

Additional changed paths: `api/v1/AdminRecoveryCenterService.cfc`, `admin/recovery-center-data.cfm`, `assets/js/admin-recovery-center.js`, `tests/specs/InactiveMemberRecoveryObservabilitySpec.cfc`, `tests/support/RecoveryEnrollmentIntegrationFixture.cfc`, and `tests/inactive-member-recovery-enrollment-integration-fixture.cfm`. New targeted test: `tests/recovery-center-pagination.playwright.js`.

After read-only scheduler verification, the requested temporary helpers were archived under `.codex-snapshots/20261003T165055Z-recovery-center/removed-helpers/` and deleted from runtime: `tests/recovery-center-compile.cfm`, `tests/recovery-center-maintenance.cfm`, `tests/recovery-center-local-rollout.cfm`, and `tests/support/RecoveryCenterLocalCohort.cfc`. The one-time local-reset JavaScript was subsequently archived during commit cleanup and removed from `tests/`; its deleted-helper dependency made it unsuitable as a recurring test. Historical reset proof remains in the snapshot.
