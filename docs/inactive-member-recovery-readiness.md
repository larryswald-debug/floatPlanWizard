# Inactive-member recovery readiness — implementation history

Update, 2026-09-06: independent coverage authority and the separately approved
narrow Basic-Draft classifier fix are implemented. All four A/B/C/D local MailHog
dry-run/send paths passed at the [Basic-Draft checkpoint](inactive-member-recovery-basic-draft-validation.md).
The [final validation report](inactive-member-recovery-final-validation.md) is the
current authority for the complete share-path campaign, regression results,
review status, cleanup, and remaining limitations. This implementation-history
document does not claim that an unfinished validation campaign passed.
Production live sending remains disabled; no scheduler was enabled.

The sections below preserve the preceding implementation run's findings. Its Stage D
blocker and pending-regression statements are historical, superseded by the reports
above. Historical counts, failures, cleanup, and Git state below describe that run
only, not the current worktree or release verdict.

## Implemented contract

- `join.cfc` writes the existing `sign_up` event and new `recovery_coverage_started`
  event inside the user/address/complimentary-credit signup transaction, before
  session authentication. Required-evidence failure rolls back signup. Existing
  signup metadata is retained; welcome and credit behavior are otherwise unchanged.
- Coverage event: user entity, actual user ID, source `member_signup`, metadata
  `{"contract_version":"v1"}`, key `recovery_coverage_v1:user:<actual ID>`.
  A server-generated correlation UUID binds the two required signup records.
- `InactiveMemberRecoveryCoverageService` verifies exact event identity, binding,
  version, UTC clocks, ordering, and absence of pre-birth event history. Missing,
  unknown-version, or contradictory evidence returns false coverage. Its signup
  writer is internal and signup-only, never an older-account approval/backfill tool.
- Coverage describes collection from canonical signup forward, not an inference
  from current rows or a declaration that there has been no activity. Enrollment
  stays an independent explicit event and timing anchor; signup does not enroll.
- New account-level retained share events: `recovery_share_started`,
  `recovery_share_succeeded`, `recovery_share_failed`. Entity `float_plan`, actual
  owned plan ID, source `basic_save_send`, `basic_review_send`, or
  `premium_save_send`; empty metadata. Internal per-operation UUID correlation and
  deterministic outcome keys. No schema or cascade dependency on trip/receipt rows.
- The Basic/Premium save-send wrappers persist STARTED outside the existing send
  transaction, track entry into mail submission and accepted calls, then finalize
  outside the transaction. Basic Review persists STARTED before calling its mail
  boundary and finalizes after its receipt transaction. An absent terminal record
  means unresolved, including unknown SMTP or outcome-persistence failure.
- Successful means accepted by the existing application's mail-submission boundary,
  not proven inbox delivery/read receipt. Existing spool settings are unchanged.
  A proven pre-submission failure can record FAILED; generic mail exceptions cannot.
  Any accepted recipient is positive sharing evidence, including partial submission.
- The classifier retains successful-sharing suppression and independently HOLDs
  unresolved/invalid attempts even after source deletion. The default sender now
  uses the coverage service for independent coverage/enrollment reads at its existing
  initial/retry/pre-send evaluations. The pure 168-hour policy is unchanged.
- None of the new evidence names qualify as saved member activity. The existing
  17-name activity allowlist remains unchanged. No history was backfilled.

## Verified during the original implementation run — historical

- MCPCFC runtime compilation: coverage service, signup, Float Plan, Basic Review.
- ColdFusion Administrator, inspected read-only with MCP Playwright: configured
  SMTP host `host.docker.internal`, port `1025`. A read-only runtime connection
  confirmed a MailHog banner. Recovery configuration reported `liveEnabled=false`.
- New CF integration suite: **17 passed**, zero failures/errors. Includes signup
  rollback before/after coverage insertion, legacy enrollment-only HOLD, malformed
  coverage, all three retained share sources, deletion persistence, ownership,
  failed-outcome rollback, and sender revalidation cancellation.
- Existing enrollment CF suite: **15 passed**.
- Existing updated enrollment MCP Playwright test: **22 assertions passed**,
  including actual signup, separate enrollment, concurrency, and vessel advancement.
- Node recovery/Basic sharing/activity source-contract suites: **52 passed**.
- A/B/C actual signup and canonical stage saves, explicit enrollment, real default
  coverage/classifier, real ledger/compliance/templates/multipart transport passed
  the exact 168-hour dry-run/send checks using local MailHog. Each produced exactly
  one captured recovery message, durable SENT, and no repeat delivery. Captured
  subjects: A `Add your boat to FloatPlanWizard`; B `Ready to plan your first trip?`;
  C `Pick up your trip planning`. HTML/text parts contained the approved mailing
  address and distinct unsubscribe/preferences destinations.
- The browser harness supplies only one disposable candidate and a future internal
  observation clock. It does not backdate enrollment or coverage, inject coverage
  approvals, change production configuration, or expose clock overrides in the
  production scheduled runner.
- `git diff --check` passed before this report.

Two test-harness errors were corrected before the A/B/C result: unavailable
`Buffer` in the browser execution context, and an incorrect duplicate URL action
parameter for the vessel controller. All affected run fixtures/mail were cleaned.

## Original Basic-Draft blocker — subsequently resolved

Canonical route-less Basic Drafts deliberately set `vesselId=0` in
`api/v1/floatplan.cfc:saveBasicFloatPlan` (local declaration near line 4853 and insert
near line 5113). At that checkpoint, the pre-existing `loadLiveEvidence` SQL in
`includes/InactiveMemberRecoveryClassifierService.cfc` treated any non-null vessel
ID without a matching vessel as contradictory. It therefore treated this valid
Basic sentinel as a broken vessel reference.

A fresh real signup + real `savebasic` reproduced:

```text
coverage: all four proofs true
stage: D
decision: HOLD_CONTRADICTORY_EVIDENCE
enrollment: NOT_ELIGIBLE_FOR_ENROLLMENT
recovery ledger rows: 0
mail sent for that D account: 0
```

This was not legacy data, an enrollment failure, or missing coverage. No change
was made to that existing lifecycle/ownership predicate during the original run.
The later approved narrow fix and its negative ownership/sentinel checks are
documented in the Basic-Draft validation report linked above.

**Original Best Fix recommendation, subsequently approved and implemented:** recognize the zero-vessel sentinel narrowly for the canonical
route-less Basic Draft model, with its required Basic-details/scope evidence;
retain positive vessel-ID ownership checks and fail closed for noncanonical or
contradictory records. Add focused negatives and rerun full D/send validation.

**Original Safest Fix alternative, not selected:** retain the HOLD and keep readiness incomplete. Do not alter data,
invent a vessel, or silently substitute a synthetic Draft to claim D passed.

Remaining at the original checkpoint: D E2E, final all-path share submission/failure validation,
broader requested regressions, complete review, final documentation, and final PASS
decision. That checkpoint made no full validation claim for those checks; use the
final validation report for their current status.

## Original implementation snapshot and exact edit inventory — historical

Snapshots preserve the initial dirty worktree (9 modified + 11 untracked files).
Root: `.codex-snapshots/20260906-recovery-readiness/`; byte copies under `before/`.
SHA-256/status/HEAD manifests: `manifest-1788707468591.json` and
`manifest-1788708169791.json`. Existing HEAD: `5620db87a8459da606035fae3b7a69ac0bc5ef7e`.

Existing files edited during this readiness implementation (including pre-existing
untracked files, whose original bytes were snapshotted):

- `api/v1/BasicReviewSendService.cfc`
- `api/v1/InactiveMemberRecoveryService.cfc`
- `api/v1/floatplan.cfc`
- `api/v1/join.cfc`
- `includes/InactiveMemberRecoveryClassifierService.cfc`
- `includes/ProductEventService.cfc`
- `tests/inactive-member-recovery-enrollment.playwright.js`
- `tests/inactive-member-recovery-enrollment.test.mjs`

New files in this readiness implementation:

- `includes/InactiveMemberRecoveryCoverageService.cfc`
- `tests/inactive-member-recovery-readiness-runner.cfm`
- `tests/inactive-member-recovery-readiness-command.cfm`
- `tests/inactive-member-recovery-readiness.playwright.js`
- `tests/specs/InactiveMemberRecoveryReadinessSpec.cfc`
- `tests/support/RecoveryCoverageEventFailure.cfc`
- `tests/support/RecoveryCoverageRaceClassifier.cfc`
- `tests/support/RecoveryReadinessE2EContext.cfc`
- `tests/support/RecoveryReadinessFixture.cfc`
- This document.

Other initial modifications and untracked enrollment work were preserved. No staging,
commit, push, deployment, migration, historical repair, CRM, analytics, recovery-policy,
pricing, referral, or lifecycle behavior changes were performed.

## Original implementation cleanup — historical

Each run cleaned only its disposable accounts/dependents, product events, recovery
ledger rows, and exact-recipient MailHog messages. Five actual recovery messages were
captured across the attempted readiness runs (A twice during harness iteration,
then A/B/C); all five were deleted from local MailHog. No D recovery was submitted.
All created browser contexts were closed; the original tab was returned to blank.

Final read-only database checks: readiness fixture users 0; service fixture users 0;
orphan new coverage/share evidence 0; orphan recovery ledger rows 0. Each browser
cleanup returned remaining users 0 and remaining fixture mail 0. All code remains
unstaged on `main`; the repository is intentionally dirty with preserved prior work
plus the unfinished implementation above.

## Production boundary — not executed

- Obtain separate production rollout authorization and verify the approved code,
  schema, private configuration, unsubscribe/preferences contract, and mail
  transport in the production environment.
- Coverage is collection evidence, not enrollment or approval of older history.
  Explicitly enroll only an approved eligible cohort, retain the full 168-hour
  enrollment grace, and review a post-grace production dry run before live sending.
- Keep older accounts with unverified history on HOLD. No speculative backfill,
  blanket historical coverage approval, or legacy-data repair is authorized.
- Production live sending and scheduler creation require separate explicit
  approval. Local MailHog delivery does not enable either one.
