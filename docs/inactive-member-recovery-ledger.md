# Inactive-member recovery contact ledger

Current contract: 2026-10-03. The existing delivery ledger now identifies each logical automated contact by **original enrollment event + contact number**. A/B/C/D is stored separately as destination evidence. See [Recovery Center](recovery-center.md); the original historical validation below is retained without treating its stage-based semantics as current.

## Schema and migration

`inactive_member_recovery_deliveries` retains its ID, member, status, claim token, UTC timestamps, attempt count, and sanitized error fields. The 20261003 Recovery Center migration replaces `recovery_stage` with `destination_stage`, adds `recovery_enrollment_event_id` and `contact_number`, and uses `UNIQUE(recovery_enrollment_event_id,contact_number)`. Contact numbers are 1–3; destination values remain A–D.

The original enrollment event is the sole cycle identity. An effective-start reset does not create a new sequence. The ledger migration requires stopped processing, a verified backup, and an empty ledger; any existing delivery rows stop it without inferred contact numbers or deleted history.

Member FK cleanup remains cascading; enrollment FK is restrictive. Fixture cleanup must remove dependent message/evaluation/delivery/state records before enrollment events. Status constraints retain CLAIMED/SENT/FAILED, consistent terminal timestamps, and **three transport attempts per contact**. This retry cap is independent of the three-contact sequence.

All mutation timestamps come from database `UTC_TIMESTAMP(6)`. Diagnostic clocks are canonical whole-second UTC text for policy compatibility. Message snapshots preserve each transport attempt's rendered destination, including a retry that legitimately uses a different destination.

## Operations and concurrency

Internal, nonremote signatures:

- `claimContact(userId,enrollmentEventId,contactNumber,destinationStage)`
- `retryFailedContact(userId,enrollmentEventId,contactNumber,destinationStage)`
- `markSent(userId,enrollmentEventId,contactNumber,claimToken)`
- `markFailed(userId,enrollmentEventId,contactNumber,claimToken,errorCode)`
- `getContactState(userId,enrollmentEventId,contactNumber)`
- `getSequenceState(userId,ownedClaimToken="")`
- `getLastSuccessfulRecoveryUtc(userId)`

Each mutation locks the member row, validates the immutable canonical enrollment belongs to that member, checks the contiguous accepted prefix, and enforces claim-token ownership. The unique key prevents duplicate logical contacts. A pending or failed contact prevents skipping to the next one; a CLAIMED contact is never automatically expired or replayed.

Definite failures retry the same contact with a new token and refreshed destination. `RETRY_EXHAUSTED` stops at three total transport attempts. Successful acceptance records SENT; uncertain transport or acceptance confirmation leaves a nonreplayable claim. SENT cannot be downgraded. There is no claim of exactly-once inbox delivery.

`getSequenceState` returns enrollment ID, next contact (zero when complete), total 3, completion, last accepted contact/time, current contact state, unresolved-claim flag, and whether an internally supplied token owns that claim. It verifies contiguous contact history and nondecreasing accepted clocks no earlier than enrollment and no later than database UTC, including before returning a completed sequence. Diagnostics never expose claim tokens; only a successful claim does.

At completion, changes to destination, elapsed time, pause/resume, or the start overlay cannot restart contact #1. The ledger does not calculate eligibility intervals or send email.

## Current validation

The current TestBox ledger suite checks schema/identity separation, canonical enrollment ownership, skipped/duplicate/wrong-token claims, all three contacts at A, no restart/#4, explicit failed retries with refreshed destination, transport cap, future accepted timestamps (including contact #3), and simultaneous claim workers with one winner. Sender tests separately verify timing, policy, current destination selection, final revalidation, and non-delivering transport.

## Original 2026-09-04 validation — historical

The exact migration DDL was extracted from the up migration and applied to the local approved `fpw` development datasource after a clean preflight. The resulting table has 12 expected columns, the exact unique key, cascading user FK, four checks, InnoDB storage, and required indexes. The production migration was not executed. The guarded rollback was source-validated and not run because the new local development table is retained for the implemented service.

MCP Playwright created a fresh canonical account through the real signup UI and sent two actual HTTP claim requests concurrently:

- Exactly one returned `CLAIMED`; the other returned `ALREADY_CLAIMED`.
- Exactly one Stage A ledger row existed.
- Stage A transitioned to `SENT`; future Stage A claims returned `ALREADY_SENT`; failure could not downgrade it.
- Stage B was independently claimed while A remained `SENT`.
- A definite failure required `retryFailedStage`; attempts advanced to 2 and 3, then `RETRY_EXHAUSTED`.
- A Stage C definite failure was explicitly retried and became `SENT`.
- A Stage D unresolved claim remained `CLAIMED` and non-replayable.
- Latest success returned the maximum of Stage A/C `sent_at_utc`.
- A private error string became `RECOVERY_SEND_FAILED`; diagnostic state exposed no token or PII.
- Deleting the fixture member cascaded all four ledger rows; a later claim returned `MEMBER_NOT_FOUND`.

Focused results:

- MCP Playwright ledger flow: 22 assertions passed.
- ColdFusion ledger/schema suite: 4 passed, 0 failed/errors.
- Node ledger contract suite: 7 passed, 0 failed.
- Existing relevant CF regressions: policy 29, Basic durable sharing 11, departure reminders 11, safe arrival 11, activity compilation/validation 2; all passed.
- The preceding unchanged activity-evidence implementation remains covered by its 101 browser/API assertions, 11 CF integration specs, and 7 static tests.
- `git diff --check` passes.

Cleanup removed only the ledger test account, all dependent rows, all ledger rows, its captured welcome messages, and disposable browser contexts. The local empty ledger table remains as the intended development migration state. Pre-existing dirty and untracked work is checksum-preserved.

## Original files added — historical

- The four migration files listed above.
- `includes/InactiveMemberRecoveryLedgerService.cfc`
- `tests/specs/InactiveMemberRecoveryLedgerSpec.cfc`
- `tests/inactive-member-recovery-ledger-runner.cfm`
- `tests/inactive-member-recovery-ledger-command.cfm`
- `tests/inactive-member-recovery-ledger.playwright.js`
- `tests/inactive-member-recovery-ledger.test.mjs`
- `docs/inactive-member-recovery-ledger.md`
- `.codex-snapshots/20260904-inactive-member-recovery-ledger/initial-state.json`
- `.codex-snapshots/20260904-inactive-member-recovery-ledger/validation-results.json`

No pre-existing production, policy, email, scheduled, classifier, CRM, analytics, Basic/Premium evidence, activity evidence, or lifecycle source file was edited by this task.
