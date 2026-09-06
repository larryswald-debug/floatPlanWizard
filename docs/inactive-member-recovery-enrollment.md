# Trustworthy recovery enrollment evidence

Implementation date: 2026-09-06. Local FPW only. **Enrollment is not historical coverage verification. Live sending remains disabled.**

## Discovery and selected contract

The existing `product_events` store provides authoritative `UTC_TIMESTAMP()` persistence, a unique idempotency-key index, and account/time indexes. Both it and `users` use InnoDB locally. No suitable separate enrollment/coverage table or user field was found. Entitlement, signup, login, stage, activity, delivery, and deployment timestamps are not enrollment authority. No schema change is required.

The approved Best Fix adds durable enrollment and separates the classifier's previous date-plus-coverage attestation. The safest storage-only alternative was not selected. Neither path authorizes guessing historical coverage.

| Contract | Value |
| --- | --- |
| Event | `inactive_member_recovery_enrolled` |
| Source | `recovery_enrollment` |
| Entity | `user`; both `user_id` and `entity_id` equal the actual current member ID |
| Idempotency key | `inactive_member_recovery_enrolled:<userId>` |
| Timestamp | Database `UTC_TIMESTAMP()` via existing `ProductEventService.recordEvent()` |
| Metadata | Exactly `{}`; no stage, names, emails, product IDs, or eligibility date |
| Canonical representation | Whole-second UTC `YYYY-MM-DDTHH:mm:ssZ` |
| Meaning | This account entered recovery evaluation at this instant; **nothing about prior history** |

The event is not one of the 17 qualifying saved-activity events. It does not advance a stage, imply sharing, or create a recovery delivery record. It has no product-row dependency, so supported vessel/route/Draft deletion does not remove its clock.

## Explicit service/manual rollout model

`includes/InactiveMemberRecoveryEnrollmentService.cfc` is non-remote. It provides:

- `getEnrollmentUtc(userId)`: read only; returns the canonical UTC or an empty string when absent. Invalid/contradictory evidence throws the safe `ENROLLMENT_EVIDENCE_INVALID` error. Empty is not verified inactivity.
- `assessEnrollment(userId)`: read-only enrollment assessment, not send eligibility.
- `ensureEnrolled(userId)`: explicit internal enrollment command; returns `ENROLLED`, `ALREADY_ENROLLED`, `NOT_ELIGIBLE_FOR_ENROLLMENT`, `MEMBER_NOT_FOUND`, or safe `ENROLLMENT_FAILED`.
- `previewMembers(userIds)`: read-only, maximum 100 distinct valid IDs. Returns aggregate already-enrolled, enrollable, held, shared, and not-eligible counts with stable reasons and no identities. The caller owns cohort selection and authorization.

**Existing and new members both use an explicit enrollment pass.** Signup, login, startup, sender scans, dry runs, and scheduler invocations do not enroll anyone. No additional production runner or `mode=enroll` was needed; production enrollment remains a separately approved internal/manual operation. There is no production bulk-enrollment or coverage-approval endpoint.

For a new enrollment, `ensureEnrolled` locks the actual `users` row inside a read-committed transaction, rechecks absence/account gates, writes the event, rereads and validates it, then commits. Event failure (including after insertion) rolls back. Concurrent calls serialize on that user lock; the existing unique key is additional duplicate protection. Repeated calls return the same stored timestamp, including after later sharing or stage/activity changes.

Readback requires one record, matching account/entity, exact event/source/key, empty object metadata, matching event/creation times, and a valid nonfuture database clock. Duplicate, malformed, wrong-owner, or conflicting-key evidence is held, not repaired or replaced. Deleted/nonexistent accounts cannot enroll; retained orphan evidence is not returned for a nonexistent member.

## Account gates without a second classifier

Assessment reuses `InactiveMemberRecoveryClassifierService.evaluateMember()` without coverage proof. Only the specific **post-account-gate** outcomes `ENROLLMENT_EVIDENCE_REQUIRED` and `HOLD_INCOMPLETE_STAGE_CLOCK` allow an initial enrollment. Thus a missing stage clock can coexist with enrollment, but remains a sending HOLD.

Shared, admin, invalid/duplicate recipient, opt-out, active trip/monitoring, ownership/lifecycle conflicts, future stage/activity clocks, lookup failures, historical regression, and other unresolved results do not create initial enrollment. This conservatively excludes some temporarily held states; arbitrary HOLD is never interpreted as enrollment permission. Already-enrolled accounts retain their original event when subsequently suppressed. The sender always rechecks current suppression; enrollment readback itself is not permission to send.

## Independent coverage and sender integration

The classifier's optional `coverageVerification={}` now requires four separate actual booleans: `stage_history`, `activity_coverage`, `sharing_history`, `recovery_history`. A date no longer sets these to true. Missing/partial/false/string proofs produce `HOLD_INCOMPLETE_COVERAGE`, after applicable existing suppression/clock checks. No production provider currently establishes these proofs, and this task creates no coverage ledger, coverage event, historical backfill, or blanket approval flag.

The sender defaults to the durable enrollment service's **read-only** lookup. An independently reviewed internal context provider may later supply `getCoverageVerification(userId)`; absence returns `{}`. Every initial, retry, and pre-send revalidation rereads both inputs. The HTTP runner exposes neither proof nor timestamp overrides. Tests explicitly attest only their controlled disposable fixture histories; those proofs are not available to production requests.

The pure `InactiveMemberRecoveryPolicy.cfc` is unchanged. With all independent gates satisfied, the latest enrollment/stage/activity/prior-send anchor still wins and adds exactly 604,800 seconds. An existing account enrolled now cannot receive an immediate age-based backlog. Coverage missing after seven days still means HOLD, not elapsed-time eligibility.

## Validation and cleanup

See the final verification record in `.codex-snapshots/20260906-recovery-enrollment/verification.json` for executed counts and limits. Tests never backdate enrollment. Synthetic old-account and later stage/activity scenarios use disposable test evidence and an internal evaluation clock; actual enrollment always uses current database UTC.

Executed results: **138 passing ColdFusion specs**, **52 passing Node contract checks**, **22 passing MCP Playwright assertions**, and clean `git diff --check`.

| ColdFusion suite | Passed | Deliberately not executed |
| --- | ---: | --- |
| New enrollment | 15 | None |
| Existing policy | 29 | None |
| Existing classifier | 28 | 4 specs that create delivery-state fixtures |
| Non-essential compliance | 8 | None |
| Recovery templates | 11 | None |
| Basic durable sharing | 11 | None |
| Premium sharing/access | 36 | None |

The sender/ledger **execution** suites were not run because they create recovery claims; their Node contract checks passed. No full operational lifecycle/browser regression rerun is claimed. Operational, signup, saved-activity, policy, email, ledger, and scheduled-runner production source files outside the stated changes remain unchanged.

An initial browser fixture omitted required vessel type/length/color and correctly received validation failure. Only the test payload was corrected; subsequent complete 22-assertion runs passed. Each run cleaned its own accounts. No unrelated product failure was repaired.

The focused ColdFusion suite covers UTC/privacy, one-event idempotency, coverage separation, exact 167h59m59s/168h grace, later activity and advancement, missing stage clocks, durable Basic/Premium suppression, admin/invalid/duplicate/opted-out/nonexistent accounts, future/conflicting history, tampered enrollment, event rollback before/after insertion, preview bounds, and sender dry runs without claims or sends.

The MCP Playwright test uses new canonical signup accounts, authenticated owner-bound temporary test tokens, and a two-worker barrier before real concurrent HTTP enrollment calls. It checks one event/same UTC, unchanged signup/preview behavior, cross-member/token rejection, real vessel stage advancement, and default sender HOLD behavior. Its disposable accounts, dependent records, events, temporary fixture state, browser contexts, and any exact-recipient captured test mail are cleaned up. No real recovery email is sent.

## Exact file scope and snapshots

Repository: `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw`.

Existing files modified (all snapshotted first):

1. `includes/ProductEventService.cfc` — one additional enrollment definition only.
2. `includes/InactiveMemberRecoveryClassifierService.cfc` — separate coverage proof, read-only durable clock lookup, invalid-evidence HOLD; reject known future clocks before considering initial enrollment.
3. `api/v1/InactiveMemberRecoveryService.cfc` — default enrollment reader and independent proof at each evaluation.
4. `tests/specs/InactiveMemberRecoveryClassifierSpec.cfc` — explicit reviewed synthetic-fixture coverage.
5. `tests/support/RecoveryOrchestrationFixture.cfc` — separate fixture-only coverage proof.
6. `tests/support/RecoveryOrchestrationRaceClassifier.cfc` — forward the new internal proof argument.
7. `tests/inactive-member-recovery-classifier.test.mjs` — approved enrollment integration and separate-coverage assertions.
8. `docs/inactive-member-recovery-classifier.md` — updated contract.
9. `docs/inactive-member-recovery-sender.md` — updated current enrollment/coverage boundary; original verification history retained.

New files:

- `includes/InactiveMemberRecoveryEnrollmentService.cfc`
- `tests/specs/InactiveMemberRecoveryEnrollmentSpec.cfc`
- `tests/support/RecoveryEnrollmentFixture.cfc`
- `tests/support/RecoveryEnrollmentEventFailure.cfc`
- `tests/support/RecoveryEnrollmentCandidateSource.cfc`
- `tests/inactive-member-recovery-enrollment-runner.cfm`
- `tests/inactive-member-recovery-enrollment-regressions.cfm`
- `tests/inactive-member-recovery-enrollment-command.cfm`
- `tests/inactive-member-recovery-enrollment.playwright.js`
- `tests/inactive-member-recovery-enrollment.test.mjs`
- `docs/inactive-member-recovery-enrollment.md`

Snapshot root: `.codex-snapshots/20260906-recovery-enrollment/`. Copies retain the original relative paths; `initial-state.json` records SHA-256 and the clean initial worktree at commit `5620db87a8459da606035fae3b7a69ac0bc5ef7e`. Older snapshots and generated artifacts remain untouched. New files have no pre-edit version.

## Historical limits and remaining production steps

No existing account was enrolled as a rollout operation. Only disposable fixtures were enrolled. Historical coverage is not inferred from signup, last login, current objects, deployment time, first scan, or absence of events. Missing historical edits/shares are not reconstructed. Stage/activity evidence and the 168-hour policy remain unchanged.

Still separately required: approve a trustworthy independent coverage authority and cohort; synchronize approved production code/config/schema prerequisites; authorize an explicit production enrollment pass; allow the full grace period; review a post-grace authenticated dry run; obtain final send approval; then separately authorize daily scheduling. No migration, production enrollment, live flag, schedule, email template, compliance, ledger semantics, CRM, pricing, referral, or operational lifecycle change is part of this task. Nothing is staged, committed, pushed, or deployed.

## Final report checklist

| # | Requested item | Result |
| --- | --- | --- |
| 1 | Enrollment-capable infrastructure | Existing InnoDB `product_events`, UTC persistence, unique idempotency key and user/time index |
| 2 | Mechanism selected | Approved Best Fix: explicit durable enrollment separate from historical coverage |
| 3 | Event/table | `product_events`; no new table |
| 4 | Event name | `inactive_member_recovery_enrolled` |
| 5 | Service | New `InactiveMemberRecoveryEnrollmentService` |
| 6 | Idempotency | One deterministic per-member key, owned account lock, confirmed readback; timestamp retained |
| 7 | Existing members | Explicit enrollment at current DB UTC, never account age or reconstructed history |
| 8 | New members | Same explicit pass; signup unchanged |
| 9 | Gates | Classifier-backed account/suppression gates; only the two documented missing-clock/enrollment outcomes admit initial enrollment |
| 10 | UTC authority | Existing database `UTC_TIMESTAMP()`; canonical whole-second Z representation |
| 11 | Privacy | Account identity only; `{}` metadata; aggregate preview contains no identities |
| 12 | Classifier | Read-only enrollment consumption; independent strict coverage booleans; missing proof stays HOLD |
| 13 | Sender | Default durable reader; separate coverage lookup on all three evaluations; no hidden enrollment |
| 14 | Dry run | Authenticated previews and sender dry runs passed; absent enrollment and missing coverage correctly held |
| 15 | Existing-account grace | Deferred at 167h59m59s; potentially eligible at exactly 168h with independently reviewed fixture evidence |
| 16 | Later activity | T0+5 days activity becomes the later anchor and requires another 168h |
| 17 | Stage advancement | Later C entry becomes the anchor; actual canonical vessel save advances to B without resetting enrollment |
| 18 | Shared | Basic/Premium evidence suppresses initial enrollment after product deletion; later sharing retains the clock and suppresses sending |
| 19 | Admin/deleted | No initial admin/nonexistent enrollment; deleted account cannot recreate or read enrollment |
| 20 | Concurrency | Two overlapping authenticated HTTP calls; one ENROLLED, one ALREADY_ENROLLED, one event, identical UTC |
| 21 | Files | 9 existing modified and 11 new, enumerated above; all 9 originals snapshotted with SHA-256 |
| 22 | Schema | None; no migration execution |
| 23 | Tests | 138 CF, 52 Node, 22 browser checks passed; intentional execution limits documented above |
| 24 | Cleanup | Disposable accounts/dependencies/events and browser fixture state/contexts removed; zero enrollment events, fixture users, or recovery delivery rows remain; no captured test mail found in exact-recipient checks |
| 25 | Production steps | Independent coverage authority/cohort, synchronization, explicit enrollment, grace, post-grace dry run, send approval, scheduler approval remain |
| 26 | Recovery email | None sent; no transport invocation or recovery claim in this task |
| 27 | Production mode | Live flag verified false; no private configuration changes, production enrollment, schedule, commit, push, or deployment |

**Inactive-Member Recovery Enrollment Evidence — PASS:** the enrollment implementation passes locally. This is not approval or readiness for production sending; independent historical coverage remains unverified by default.
