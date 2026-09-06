# Protected recovery runner and sender orchestration

Original sender-only verification: 2026-09-05, ColdFusion 2025, datasource `fpw`.

## Current authority and production boundary

Development orchestration and independent coverage verification are implemented. The original sender-only run used disposable canonical data and non-delivering recovery transport; later A/B/C/D validation used local MailHog. The [final validation report](inactive-member-recovery-final-validation.md) is the current authority for the complete regression/share-path results, review status, and remaining limitations. **No production rollout is authorized by these local results.** No production schedule or live-send flag was enabled.

Updated 2026-09-06: the default internal context provider is now `InactiveMemberRecoveryCoverageService`. It independently reads durable enrollment through the existing enrollment service and verifies versioned canonical-signup coverage. Initial/retry/pre-send evaluations re-read both. Scans and sending never enroll members; enrollment proves timing only. New canonical signup coverage is atomic and versioned; older enrolled-but-unverified members remain on `HOLD_INCOMPLETE_COVERAGE`. Retained unresolved share attempts HOLD independently of deleted trip/receipt rows. The HTTP runner still has no fixture, coverage, clock, recipient, stage, or eligibility override. The [Basic-Draft validation report](inactive-member-recovery-basic-draft-validation.md) records the prior A/B/C/D local MailHog proof and the regression exceptions present at that checkpoint; the final report above supersedes those status statements.

**Before any live rollout:** obtain separate production authorization and explicit cohort enrollment; do not substitute signup dates or a blanket launch timestamp. The implemented coverage authority does not approve older history or enable sending.

**Current safety posture:** live mode remains disabled and no schedule was changed. No backfill or automatic enrollment was added. Local MailHog fixture delivery is not production authorization or proof of a deployed scheduler. The verification and snapshot history below describes the original 2026-09-05 sender-only task; subsequent enrollment and readiness handoffs are separate.

## Discovery and exact integration changes

The existing sources of truth remain the classifier, policy evaluator, ledger service, durable product events/receipts, non-essential eligibility/footer helpers, and email builder/transport. Discovery identified two integration defects:

- An ordinary classifier call suppresses any unresolved claim, including the sender's own freshly acquired claim. `evaluateMember` now optionally accepts an internal `ownedClaimToken`; only the exact current member/stage/token match is exempted from that one suppression. A mismatched token holds, and any other unresolved claim still suppresses. Existing callers retain their original behavior.
- Ordinary classification holds `FAILED` rows pending an explicit retry decision. The ledger now exposes computed `CAN_RETRY`; only then does orchestration request fresh policy evaluation using the optional internal `evaluateFailedRetry` flag. Claim/retry writes still occur only through the existing ledger methods and their three-attempt cap.

No cancellation status or schema change was needed. An outer preparation transaction safely rolls back either a newly inserted claim or a retry update if revalidation/compliance/rendering prevents sending. Tests proved restoration of the previous FAILED row, including attempt count and timestamps. SMTP is outside that transaction.

## Execution contract

1. **Candidate selection:** bounded user-ID keyset scan of existing users; cheaply exclude currently active admin entitlements and durable Basic/Premium successful share events. Receipts, ownership, lifecycle, history and all other exclusions remain the classifier's responsibility. An application-memory traversal cursor avoids repeatedly scanning only the first held batch. It is not enrollment or delivery state and can safely reset after restart.
2. **Bounds:** default 25, maximum 100, integer range 1–100. Invalid, duplicate, or oversized injected candidate results fail/skip safely. No unbounded request mode.
3. **Initial evaluation:** current classifier plus unchanged 604,800-second policy. Noneligible accounts are not claimed, rendered, or sent. Reason codes remain authoritative.
4. **Claim:** call canonical `claimStage`, or explicit `retryFailedStage` only for a retryable FAILED row. Require canonical claim success and its private token.
5. **Revalidation:** re-read classifier/policy with fresh UTC/enrollment context and the exact claim token. Stage must still agree and remain eligible.
6. **Compliance:** re-read the current account recipient and require `checkNonEssentialEmailEligibility()` to return `ELIGIBLE`. Opt-out, invalid recipient, lookup/token failure or renderer/address failure prevents submission.
7. **Cancellation:** rollback the preparation transaction on pre-send cancellation/failure. No false permanent first claim, no synthetic FAILED delivery and no consumed retry attempt. A database commit with an uncertain outcome is held and never followed by transport submission in that invocation.
8. **Destinations/templates:** call the unchanged `buildInactiveMemberRecoveryEmail`. A/B/C use the environment-aware Dashboard URL. D also uses the approved Dashboard fallback because classification supplies no ownership-confirmed Draft identity. No arbitrary Draft URL input or new ownership lookup.
9. **Transport:** the new nonremote `email.submitInactiveMemberRecoveryEmail` wrapper calls the existing private `sendMultipartEmail`, with `spoolEnable=false` and `rethrowOnFailure=true`. No new SMTP client, provider, queue or generic fallback copy. Synchronous application submission is not inbox delivery.
10. **SENT:** confirmed submission calls token-bound `markSent`; canonical ledger/database UTC remains authoritative.
11. **FAILED:** only a definitively unsubmitted outcome calls token-bound `markFailed`. A later normal run may explicitly retry, up to three total claimed attempts. Cancellation restores the prior count; successful same-stage sends never repeat.
12. **Ambiguity:** SMTP exceptions alone do not prove nonacceptance. Unknown transport outcomes and uncertain database confirmation remain non-replayable CLAIMED, or already-committed SENT when confirmation was lost. No timeout/reclaim retry was added.
13. **Cross-stage:** a prior A send does not itself exclude B–D. The existing policy still requires fresh stage/activity intervals and at least 168 hours since the last successful recovery. Shared permanently suppresses all stages.

The transaction provides a fresh pre-send check, not an impossible guarantee against an external member change occurring after the last read and after transport begins. There is no automatic replay after an uncertain send.

## Runner, private configuration and response

Endpoint: `/fpw/app/scheduled/run-inactive-member-recovery.cfm` locally; use the deployed application's actual base path in production.

Configuration uses the existing private JSON at `application.stripeConfigPath`, with the existing `/_fpw_private/stripe-config.json` fallback. No second configuration store or hard-coded secret was created.

- `FPW_INACTIVE_RECOVERY_RUNNER_TOKEN`: required private secret.
- `FPW_INACTIVE_RECOVERY_LIVE_ENABLED`: defaults false; only JSON boolean `true` enables the service's live gate. This does not substitute for enrollment or other authorization.
- Prefer `X-FPW-Recovery-Token` header. The existing scheduled-URL token convention is also supported by `token`; if used, keep scheduler configuration and access logs private.
- GET only. Optional `batchSize` and `dryRun`; dry run defaults true. Reject every other query key, including IDs, email, stage, force and eligibility overrides.
- Missing/wrong token: 403. Unsupported method: 405. Invalid options: 400. Live mode disabled: 403. Candidate/service failure: 503. Unexpected runner exception: 500 with a stable code only.
- `Cache-Control: no-store, no-cache, must-revalidate`; `Pragma: no-cache`; JSON only.

Safe results contain `ok`, `mode`, `scanned`, `eligible`, `claimed`, `submitted`, `sent`, `failed`, `suppressed`, `held`, `skipped`, `canceled`, `ambiguous`, stage counts A–D, aggregate reason counts, and a stable error code if applicable. No account identity, recipient, trip/route ID, token or stack trace is serialized. `submitted` means transport reported acceptance; `sent` additionally means the ledger confirmed SENT. `claimed` counts claims retained through preparation, not rolled-back cancellations. Stage counts describe processed classification, not a separate authorization.

Dry run only scans/classifies/evaluates and advances the ephemeral traversal cursor. It does not claim, render email, submit, write product evidence or alter delivery history.

## Original 2026-09-05 verification results — historical

These results, counts, and limitations describe the original sender-only run, not the current release review. MCPCFC ran the ColdFusion suites. MCP Playwright ran actual overlapping HTTP service invocations plus the existing fresh-signup activity regression.

| ColdFusion suite | Passing |
| --- | ---: |
| New sender orchestration | 16 |
| Recovery policy | 29 |
| Recovery classifier | 32 |
| Recovery ledger | 4 |
| Member activity, full disposable-account integration | 11 |
| Durable Basic review sharing | 11 |
| Premium send credits and access lifecycle | 36 |
| Non-essential compliance | 8 |
| Recovery email templates | 11 |
| Onboarding | 10 |
| Safe Arrival | 11 |
| Departure Reminders | 11 |
| Scheduled actual departure | 10 |
| Route-instance closure | 6 |
| Float Plan ownership | 5 |
| Completed-trip view model | 7 |
| Completed shore-contact access | 17 |
| Route continuity | 4 |
| Scheduled actual-departure route Draft | 3 |
| **Original run total across 19 suites** | **242** |

Additional evidence:

- 44 Node static/contract checks passed. The old classifier isolation assertion was updated narrowly to allow exactly the newly approved orchestrator; it still rejects other production callers and still requires the classifier itself to be read-only.
- 12 real HTTP runner checks passed: missing/wrong/correct token; oversized, zero and fractional batch; invalid dry-run value; user/stage/recipient/force overrides; live-disabled protection. Checked no-cache headers and absence of identity fields. The correct-token test used the actual candidate scan in dry-run mode.
- MCP Playwright concurrent first-claim test: both workers initially eligible; one SENT/submission, one ALREADY_CLAIMED skip, one row, attempt count 1.
- Concurrent FAILED retry: one SENT/submission, one skip, one row, attempt count 2 including the earlier controlled failed attempt. A barrier forces overlapping initial evaluations; distinct worker URLs prevent browser GET coalescing.
- A/B/C/D rendered their exact approved subjects, compliant text/HTML content, unsubscribe/preferences links and Dashboard CTAs, and each submitted once to the non-delivery capture transport. Repeated runs submitted nothing.
- At 167h 59m 59s: no claim/send. At 168h: eligible submission. A later qualifying vessel edit deferred until another full 168 hours. No duplicated timing logic in the sender.
- C-to-D advancement, successful sharing, opt-out and active monitoring between initial evaluation and claim revalidation canceled before submission and removed the first claim.
- Durable Basic and Premium share evidence suppressed after disposable planning rows were deleted.
- Preference lookup, unsubscribe creation, missing-address and render failures prevented submission and retained no first claim. A canceled retry restored the exact prior FAILED state.
- Definite failure capped at three attempts. Ambiguous return, thrown transport error and uncertain SENT confirmation before/after persistence never replayed.
- The real wrapper was tested with a mock only at the existing private multipart boundary: correct HTML/text arguments, synchronous settings, confirmed submission, ambiguous exception and invalid-message rejection without calling SMTP.
- All **39 pre-existing email function bodies** were extracted non-vacuously and compared byte-for-byte against the pre-edit snapshot: identical. Only the new submission wrapper was added.
- Existing activity Playwright regression: **101 assertions**, covering fresh canonical signup, all profile families, ownership/no-op/concurrency/failure rollback, photos, named/generated routes, geometry, Draft selected contacts, Basic Drafts, login/view exclusion, UTC/privacy, and retained events after source deletion. Its full 11-spec CF suite passed.
- `git diff --check` passed. No real recovery emails were sent; no inbox-delivery claim is made.

### Original pre-existing regression limitation — historical

An additional Public Follow privacy runner stopped before executing any spec: `tests/specs/PublicFollowPrivacyContractSpec.cfc:13` references missing `fpw.api.v1.PasswordHashService`. That spec and the missing component were not changed by this task; `git diff` for the spec is empty. No unrelated repair was made. Completed-contact and completed-trip suites passed separately; those are not a substitute claim that the blocked Public Follow suite passed.

## Original sender-only files and snapshot coverage — historical

Repository root: `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw`.

Existing files modified in the original sender-only task (all copied before modification):

- `api/v1/email.cfc` — add internal submission wrapper; all existing functions unchanged.
- `includes/InactiveMemberRecoveryClassifierService.cfc` — optional own-claim and explicit-retry read-only evaluation context.
- `includes/InactiveMemberRecoveryLedgerService.cfc` — expose computed `CAN_RETRY` only; existing mutation methods unchanged.
- `tests/inactive-member-recovery-classifier.test.mjs` — permit exactly the approved service integration.

New files:

- `api/v1/InactiveMemberRecoveryService.cfc`
- `app/scheduled/run-inactive-member-recovery.cfm`
- `tests/inactive-member-recovery-sender-runner.cfm`
- `tests/inactive-member-recovery-sender-command.cfm`
- `tests/inactive-member-recovery-sender.playwright.js`
- `tests/inactive-member-recovery-sender.test.mjs`
- `tests/specs/InactiveMemberRecoverySenderSpec.cfc`
- `tests/support/RecoveryOrchestrationFixture.cfc`
- `tests/support/RecoveryOrchestrationRaceClassifier.cfc`
- `tests/support/RecoveryOrchestrationEmailStub.cfc`
- `tests/support/RecoveryOrchestrationLedgerStub.cfc`
- `docs/inactive-member-recovery-sender.md`

Snapshot root: `.codex-snapshots/20260905-recovery-sender/`. Each existing file above is backed up under its same relative path there. `initial-state.json` preserves initial dirty Git state. `verification.json` records hashes and aggregate results; `final-state.json` records final Git status. Pre-existing tracked modifications, untracked policy/ledger/classifier/template work, older snapshots and the pre-existing generated PDF remain in place.

Pre-edit SHA-256:

| File | SHA-256 |
| --- | --- |
| email.cfc | `92112fd6bd20ccaa95ff8a0b620e16f45557dc3bc0d88e5d3ca1d399208968e4` |
| classifier | `3b28d4f9ab9092f487c9a35c0bea31fc3f1756d0a7ffbad2cc16ad92088067e2` |
| ledger | `e0ec77338ce4002669c4ac8f020c34f3e9b527cea70976a25b9ff9351bdeb750` |
| classifier static test | `2de03c93ae8bef7ee7d565031d4906bbb3de5dfad8dbd1bd73dd839d2cea1400` |

## Original sender-only cleanup and unchanged scope — historical

Every new sender fixture tracks its own generated IDs. Cleanup removed only those accounts, dependent planning/monitoring/preference rows, events and delivery rows. Concurrent fixtures reported zero remaining users/events/ledger rows. Database checks found zero `codex-recovery-orch-` users/events. The activity regression removed its two fresh accounts and dependent files/rows; follow-up checks found zero users/events for those exact IDs. Its two captured welcome emails were removed individually from local MailHog and recipient searches returned zero. They were disposable signup mail, not recovery sends. Temporary browser contexts/tabs and this run's two generated browser log/snapshot files were removed; existing browser tabs were preserved.

The runner authorization fixture copied the existing private config before adding a temporary random token and false live flag. Its `finally` restored exact original bytes, verified matching SHA-256 and removed the private backup. No secret was printed or put in public source. There is no persistent private configuration change from this task.

No schema/migration execution, enrollment/backfill, policy timing/stage definition change, product-event change, sharing semantics change, template rewrite, new CRM, analytics/open tracking, queue/provider, pricing/payment/referral change, or unrelated operational lifecycle behavior was added. Nothing was staged, committed, pushed, deployed or scheduled.

## Production enablement checklist — not executed

1. Obtain separate production rollout authorization and verify the approved implementation is deployed. The independent coverage authority is implemented; verify its production behavior rather than approving older history. Do not infer historical inactivity from durable enrollment.
2. Verify the approved recovery-ledger migration and required evidence tables are deployed and valid in production. No migration was run in the original sender-only task.
3. Verify the approved `FPW_BUSINESS_MAILING_ADDRESS` in production's existing private configuration.
4. Configure a dedicated private runner token; retain live flag false for rollout checks.
5. Verify production unsubscribe signatures, distinct preferences URL, clean text/HTML footer, recipient suppression and multipart transport.
6. Explicitly approve and enroll only the eligible production cohort, preserve the full 168-hour enrollment grace, then run the authorized post-grace production dry run and review aggregate holds/suppressions and cohort coverage. Signup coverage does not enroll a member; older unverified history remains HOLD. A held account is not evidence of a sending defect.
7. Obtain explicit approval for live sending and scheduler creation. Only then set the strict live flag and register the production task.
8. Recommended cadence: **once daily**, default batch 25, hard max 100. At 25 scanned accounts per daily run, large cohorts take multiple days to traverse; review dry-run volume before choosing an approved bounded batch. This schedule does not change the 168-hour threshold.
9. Monitor aggregate failures/ambiguities. Never replay ambiguous delivery claims automatically or manually manufacture legacy eligibility.

No production scheduled task was created or enabled. Independent coverage verification is implemented, but deployment/configuration verification, eligible-cohort enrollment, grace-period dry-run review, and explicit live/scheduler authorization remain separate production boundaries. No historical backfill or blanket approval is authorized.
