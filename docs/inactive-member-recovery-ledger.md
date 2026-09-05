# Inactive-member recovery delivery ledger

Implementation and local validation: 2026-09-04.

## Scope and decision

This change adds delivery history only. It does not classify members, calculate eligibility, query batches, render or send email, schedule work, integrate opt-outs, add stage/activity clocks, or change the approved 168-hour policy.

A dedicated `inactive_member_recovery_deliveries` table is required. Existing ledgers cannot be reused safely:

| Existing ledger | Identity / purpose | Why it is not reusable |
| --- | --- | --- |
| `departure_reminder_deliveries` | Float plan + reminder occurrence | Trip/departure-specific; uniqueness is an occurrence hash, not member + recovery stage |
| `floatplan_alert_history` | Float plan + alert type | Trip/contact lifecycle history; deleting the plan cascades or explicitly deletes the history |
| `fpw_email_log` | Float plan + template + milestone | Trip scheduler log; contains recipient-oriented delivery diagnostics |
| Basic/Premium receipts and `product_events` | Sharing/evidence contracts | Not a claim state machine and cannot atomically reserve one recovery attempt per stage |

Both current departure-reminder and safe-arrival systems use `CLAIMED`, `SENT`, and `FAILED`, permit a definite failed attempt to retry up to three total attempts, and leave a claim unresolved after accepted email if final persistence cannot be confirmed. This ledger follows those established semantics.

## Schema contract

Migration family:

- `database/migrations/20260904_001_inactive_member_recovery_deliveries.preflight.sql`
- `database/migrations/20260904_001_inactive_member_recovery_deliveries.up.sql`
- `database/migrations/20260904_001_inactive_member_recovery_deliveries.verify.sql`
- `database/migrations/20260904_001_inactive_member_recovery_deliveries.down.sql`

| Column | Contract |
| --- | --- |
| `id` | Unsigned auto-increment BIGINT primary key |
| `user_id` | Signed non-null INT; FK to `users.userId` |
| `recovery_stage` | Non-null CHAR(1), checked to A/B/C/D |
| `status` | Non-null VARCHAR(16), checked to CLAIMED/SENT/FAILED |
| `claim_token` | Non-null 64-character internal attempt token |
| `claimed_at_utc` | Non-null DATETIME(6) |
| `sent_at_utc` | Nullable DATETIME(6) |
| `failed_at_utc` | Nullable DATETIME(6) |
| `attempt_count` | Non-null INT, checked from 1 through 3 |
| `last_error_summary` | Nullable VARCHAR(64), machine-safe code only |
| `created_at_utc`, `updated_at_utc` | Non-null DATETIME(6) |

Database enforcement:

- `UNIQUE(user_id, recovery_stage)`: one durable logical row per member + stage.
- `FOREIGN KEY (user_id) ... ON DELETE CASCADE`: deletion of the member deletes the delivery history; a user-row lock and the FK prevent a claim for a missing/deleting member.
- Checks permit only A–D, three statuses, attempts 1–3, and consistent terminal timestamps.
- `(user_id, sent_at_utc)` supports the cross-stage latest-success read.
- `(status, updated_at_utc)` supports diagnostics; this task adds no candidate query.

The internal claim token binds terminal updates to the current attempt. It prevents a stale worker from finalizing a later retry. It is returned only to the successful claimant and omitted from diagnostic state.

All writes use database `UTC_TIMESTAMP(6)`. Display/read results use canonical `YYYY-MM-DDTHH:mm:ss.SSSZ` UTC strings. Browser/local timestamps are never accepted.

## Service contract

`includes/InactiveMemberRecoveryLedgerService.cfc` is an internal, non-remote service using the supplied datasource.

### `claimStage(userId, stage)`

Locks and verifies the user, performs `INSERT IGNORE`, inspects `ROW_COUNT()`, and locks the unique stage row in one transaction.

Results include:

- `CLAIMED`: new claim, with ledger ID, attempt token, and attempt 1.
- `ALREADY_SENT`: this stage is permanently suppressed.
- `ALREADY_CLAIMED`: unresolved/potentially sent and non-replayable.
- `FAILED_PREVIOUSLY`: definite failure exists; normal claiming does not retry it.
- `INVALID_STAGE`, `INVALID_MEMBER`, `MEMBER_NOT_FOUND`: rejected without a row.

Lowercase valid stage input is normalized to its stable uppercase persisted value. No arbitrary stage is accepted.

### `retryFailedStage(userId, stage)`

This is the only retry path. A `FAILED` row below the established three-attempt cap becomes a new `CLAIMED` attempt, receives a new token, increments `attempt_count`, clears terminal/error fields, and returns `FAILED_RETRY`.

`RETRY_EXHAUSTED` is permanent absent an explicitly approved future administrative change. There is no scheduler and no automatic retry loop.

### `markSent(userId, stage, claimToken)`

Only the matching current `CLAIMED` attempt can transition to `SENT`. It writes `sent_at_utc`, clears failed/error fields, and never downgrades an existing `SENT` row.

### `markFailed(userId, stage, claimToken, errorCode)`

Only the matching current `CLAIMED` attempt can transition to `FAILED`. The input must be a machine-style `[A-Z][A-Z0-9_]{0,63}` code. Anything else—including text containing an email address—is stored only as `RECOVERY_SEND_FAILED`. No recipient, profile, trip, route, activity, token, message content, or arbitrary exception text is stored.

Call this method only for a definite known-not-sent outcome. If email submission may have succeeded but `markSent` cannot be confirmed, do not call `markFailed`; the row remains `CLAIMED`. Future `claimStage` calls return `ALREADY_CLAIMED`, preventing automatic replay. This does not claim exactly-once inbox delivery.

### Diagnostics and cross-stage spacing

`getStageState(userId, stage)` returns the stage status, attempt count, UTC timestamps, and safe error code. It never returns the claim token.

`getLastSuccessfulRecoveryUtc(userId)` implements only the read contract:

```sql
SELECT MAX(sent_at_utc)
FROM inactive_member_recovery_deliveries
WHERE user_id = :userId
  AND status = 'SENT';
```

It returns `NO_SUCCESSFUL_RECOVERY` or the canonical UTC value. It does not calculate 168 hours or decide eligibility.

A lower-stage row is never updated/deleted on advancement. For example, Stage A remains `SENT` while Stage B can later be independently claimed. Same-stage requalification is impossible because the unique row remains and `SENT` is terminal.

## Validation

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

## Files added

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
