# Protected recovery runner and sender orchestration

Current contract: 2026-10-03. Exactly three time-based automated contacts use independently recalculated A/B/C/D product destinations. See [Recovery Center](recovery-center.md), [timing policy](inactive-member-recovery-threshold.md), [contact ledger](inactive-member-recovery-ledger.md), and [email copy](recovery-center-email-copy.md).

## Current execution contract

The existing sources remain authoritative: classifier, pure policy, delivery ledger, durable events/receipts, current non-essential preference checks, destination resolver, authentication continuation, and email renderer/transport.

1. Check the repository `.codex-snapshots/recovery-center-migration.lock` maintenance gate before scanning or writing. Validate integer batch 1–100 (default25) and strict live-mode enablement.
2. Begin a durable run with execution source, dry/live mode, settings snapshot, and run ID. Bounded member-ID traversal preserves existing cheap admin/sharing exclusions. Only actually evaluated members receive evaluation rows.
3. Reevaluate current membership, coverage, ownership, sharing, lifecycle, opt-out, recovery state, UTC clocks, settings, and contact history. First Delay determines contact #1; Contact Interval determines #2/#3 after the latest applicable anchor.
4. In a preparation transaction, claim the current contact (or explicitly retry a definite failure below the transport cap). Identity is original enrollment + contact number; destination is a separate field.
5. Freshly reevaluate with the exact claim token, resolve current owned destination, reread recipient and preferences, and select/render the current contact's template using that destination.
6. Prepare an immutable observation/message snapshot and optional signed tracking. Observation failure falls back to the valid original untracked message and is reported; it cannot grant eligibility.
7. Independently reevaluate after rendering. Require matching enrollment, contact, destination stage, settings revision, member-state revision/effective start, current recipient, preferences, and resolved path. Stale content or changed eligibility cancels preparation. Rollback removes a new claim or restores an exact prior FAILED retry without consuming an attempt.
8. Submit through the existing synchronous multipart boundary **outside** the DB transaction. Record accepted delivery only on confirmed transport acceptance plus ledger confirmation. Known failure retries the same contact; uncertainty remains nonreplayable.
9. Finalize evaluation/message/run observations nonfatally. Bounded activity reconciliation associates committed source evidence with accepted automated messages.

Contact progression does not depend on product-stage progression. All three contacts can point to Add Vessel or the same route. Contact #1 may begin at B/C/D. Contact #2 can point to B following legitimate progress from A. Contact #3 ends the sequence; no #4 or automatic restart exists.

Dry runs persist run/evaluation observations and may reconcile source evidence. They never enroll, claim, render/send mail, or alter delivery history. Optional observational failure never rolls back an accepted send or triggers replay.

## Runner and reporting

The protected GET runner retains only token, batchSize, and dryRun inputs; no member, recipient, contact, destination, clock, or eligibility override is public. Authentication and no-cache behavior are preserved. Native scheduler availability/configuration and production enablement remain distinct operational concerns.

Results contain aggregate scanned/eligible/claimed/submitted/sent/failed/suppressed/held/skipped/canceled/ambiguous counts, **contacts** separately from **destination_stages**, reasons, run_id, and observation_gaps. Recipient identities, claim tokens and exceptions are omitted. Submitted means transport reported acceptance; sent additionally requires ledger confirmation, not inbox delivery.

The classifier's actual fresh failure reason is retained when revalidation becomes ineligible. Cancellation from a changed prepared context remains distinct. Finalized historical evaluations do not change when current settings, product stage, or destination later changes.

## Current test boundaries

Canonical disposable fixtures and injected non-delivering transports cover all first-contact destinations, repeated same-destination contacts, progress before contact #2, retries with fresh destinations, completion, concurrent claims, independent post-render revalidation, preference/ownership/sharing safeguards, and ambiguous transport/confirmation holds. Settings/default timing tests include exact 24-hour boundaries and explicitly configured nondefault intervals.

The historical evidence below describes prior releases, not current test counts or production proof.

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
6. Explicitly approve and enroll only the eligible production cohort, preserve the currently configured First Recovery Delay, then run the authorized post-grace production dry run and review aggregate holds/suppressions and cohort coverage. Signup coverage does not enroll a member; older unverified history remains HOLD. A held account is not evidence of a sending defect.
7. Obtain explicit approval for live sending and scheduler creation. Only then set the strict live flag and register the production task.
8. Recommended cadence: **once daily**, default batch 25, hard max 100. At 25 scanned accounts per daily run, large cohorts take multiple days to traverse; review dry-run volume before choosing an approved bounded batch. This schedule does not change the configured elapsed-hour eligibility policy.
9. Monitor aggregate failures/ambiguities. Never replay ambiguous delivery claims automatically or manually manufacture legacy eligibility.

No production scheduled task was created or enabled. Independent coverage verification is implemented, but deployment/configuration verification, eligible-cohort enrollment, grace-period dry-run review, and explicit live/scheduler authorization remain separate production boundaries. No historical backfill or blanket approval is authorized.
