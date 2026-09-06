# Inactive-member recovery — final local readiness validation

Date: 2026-09-06. Repository: `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw`.

## Verdict

**Local recovery readiness — PASS for the approved implementation and validation scope.** The outstanding share-path validation, two regression exceptions, and accumulated-change review are complete. No additional production-code correction was needed in this closure phase.

**Production sending and scheduling remain disabled.** Local MailHog delivery is not authorization to deploy, enroll a production cohort, or send production recovery emails. Older accounts without independently verified coverage remain on HOLD; no history was backfilled or blanket-approved.

This report supersedes the remaining-work statements in the earlier enrollment, sender, readiness, and Basic-Draft validation checkpoints. Their original evidence remains available as history.

## Implementation reviewed for check-in

The accumulated implementation retains the approved boundaries:

- Canonical signup and required versioned recovery-coverage evidence commit atomically; evidence failure rolls signup back.
- Enrollment is a separate durable timing anchor, never proof of historical coverage.
- Basic operational, Basic Review, and Premium sharing retain account-owned STARTED evidence before submission. Successful, definitively failed, and unresolved outcomes remain distinct.
- Successful sharing permanently suppresses A–D; unresolved attempts HOLD even after trip/receipt deletion. Definitive failures do not permanently suppress recovery.
- Classifier and sender revalidation use the independent coverage authority. The pure 604,800-second policy is unchanged.
- Only independently verified canonical Basic Drafts receive the zero-vessel exception; unexpected zero or missing/foreign nonzero vessel references still HOLD.
- No caller-controlled production fixture, coverage, clock, recipient, stage, or live-enable override was added.

Independent read-only review found no actionable production correctness/security defect. Relevant local tables were verified as InnoDB; `product_events` has no foreign keys that could cascade away retained evidence.

## Actual share-path validation

MCP Playwright ran `tests/recovery-share-paths.playwright.js`: **12 cases, 279 assertions, all passed**. Each case used a fresh canonical signup and real member API saves. Route-backed cases built an owned named route, saved geometry, generated the route instance and Draft, and saved its selected contact. No entitlement or receipt was manually manufactured to make a send succeed.

Actual ColdFusion Administrator SMTP configuration was independently inspected as `host.docker.internal:1025`; the local endpoint also identified itself as MailHog. Merely finding a MailHog listener is not proof of the configured transport destination. No SMTP configuration was changed.

| Path | Case | Captured share mail | Retained result, including after deletion |
| --- | --- | ---: | --- |
| Basic operational | Success | 1 | Successful sharing; suppressed |
| Basic operational | Definitive PDF-preparation failure | 0 | Failed attempt; ordinary D eligibility still possible after 168 hours |
| Basic operational | Exception inside mail tag | 0 | Unresolved; HOLD |
| Basic operational | First recipient accepted, second throws | 1 | Successful sharing; suppressed |
| Basic Review | Success | 1 | Successful sharing; suppressed |
| Basic Review | Real email validation rejects non-PDF attachment | 0 | Failed attempt; ordinary D eligibility still possible after 168 hours |
| Basic Review | Lost application acknowledgement after actual SMTP acceptance | 1 | Unresolved; HOLD |
| Basic Review | Completion-evidence insertion throws after accepted mail | 1 | `BASIC_REVIEW_CONFIRMATION_PENDING`; retained successful sharing suppresses |
| Premium | Success | 1 | Successful sharing; suppressed |
| Premium | Definitive PDF-preparation failure | 0 | Failed attempt; ordinary D eligibility still possible after 168 hours |
| Premium | Exception inside mail tag | 0 | Unresolved; HOLD |
| Premium | First recipient accepted, second throws | 1 | Successful sharing; suppressed |

Premium failure/partial cases verified the plan remained Draft, no completed Premium receipt remained, and no credit remained consumed before fixture teardown. All paths checked actual entity IDs, matching event source, exact event counts, and empty `{}` metadata. Basic/Premium STARTED was observed before PDF/mail work; Basic Review STARTED was observed before its actual synchronous submission in the acknowledgement-loss case.

Definitive failure was tested for normal D eligibility before source deletion. Deleting a previously attained stage can independently cause contradictory-history HOLD; that is not permanent suppression due to a failed share.

### Deliberate proof limits

- Basic/Premium ambiguous cases use a test-only PDF adapter to make the real `cfmail` attachment operation throw. These are not simulated network disconnects or proof of every possible SMTP failure.
- Basic Review's ambiguity proxy calls the real synchronous email service, observes successful submission, then throws before the calling service receives that acknowledgement. This is lost **application acknowledgement**, not lost SMTP socket acknowledgement.
- Partial cases inject one invalid second recipient through a test-only contact-loader substitution. The first actual message is captured in MailHog; the second raises an exception.
- Basic Review uses the supported member parent-route deletion command. Active Basic/Premium history has intentional production deletion protections; those cases use explicit owner-scoped disposable-fixture destruction to test retained evidence. Production deletion guards were not bypassed or changed.
- Accepted/queued submission is not a recipient read receipt or guaranteed real-world inbox delivery.
- The confirmation-failure campaign checks the caller's pending-confirmation response and retained success. It does not independently report the precise Basic receipt row state after that failure; existing CF receipt-atomicity tests cover their own row-level assertions.

## Full regression evidence

| Validation | Result |
| --- | --- |
| Core CF suite matrix through MCPCF | 300 passed, zero failures/errors |
| Authenticated member-activity CF integration | 11 passed, zero failures/errors |
| **Combined CF total** | **311 passed across 24 runner endpoints / 25 bundles** |
| Node recovery/sharing/activity/vessel/UTC checks | **58/58 passed** |
| Real A/B/C/D recovery dry-run/send browser workflow | **75 assertions passed** |
| Full saved-activity browser workflow | **101 assertions passed** |
| Real share-path browser campaign | **12 cases / 279 assertions passed** |
| Git whitespace validation | `git diff --check` passed |

The preliminary two-test standalone activity run is not added to the combined 311 total; it is replaced by the authenticated 11-test result. The Premium runner includes two bundles.

The CF matrix includes recovery policy, enrollment, coverage/readiness, classifier, ledger, sender, templates, compliance, Basic/Premium sharing and access, onboarding, ownership/Draft saves, route planning/continuity/geometry/reserve handling, departure reminders, safe arrival, completion lifecycle, completed views, and Public Follow privacy. The exact runner/count matrix is in the structured evidence below.

A/B/C/D validation used real signup coverage, separate enrollment, the exact 167h 59m 59s / 168h boundary, real default classifier/coverage/ledger/compliance/templates, one local recovery message per stage, durable SENT state, and repeat suppression. Its fixture controls only candidate selection and the internal observation clock; it does not backdate evidence or change the production live flag. HTML/plain-text parts contained the approved address and distinct unsubscribe/preferences destinations.

The activity browser run covered all profile families, photos, routes/legs/geometry, generated and Basic Drafts, selected contacts, ownership, no-op/concurrency cases, atomic evidence-failure rollback, UTC/privacy, and source-deletion retention.

## Regression exceptions resolved

Both failures were reproduced before the following test-only fixes:

1. `tests/specs/PublicFollowPrivacyContractSpec.cfc` referenced nonexistent `PasswordHashService`. Its fixture now uses the existing canonical signup/test SHA-256 hashing convention. Result: **7/7 pass**. No authentication implementation was changed.
2. `tests/vessel-crud-expanded-fields.test.mjs` expected literal adjacent rollback SQL while the existing migration builds charset/collation/default clauses dynamically. Assertions now verify that explicit dynamic SQL contract. Result: **4/4 pass**. No migration file or schema was changed, and no migration was executed.

There are no unresolved test exceptions in the executed matrix.

## Exact closure-phase changes

These are the files changed in this closure phase, distinct from the preceding accumulated implementation included in the reviewed check-in:

- `tests/specs/PublicFollowPrivacyContractSpec.cfc`
- `tests/vessel-crud-expanded-fields.test.mjs`
- `tests/recovery-share-path-command.cfm` (new)
- `tests/recovery-share-paths.playwright.js` (new)
- `tests/support/RecoverySharePathHarness.cfc` (new)
- `tests/support/RecoverySharePdfProbe.cfc` (new)
- `docs/inactive-member-recovery-sender.md`
- `docs/inactive-member-recovery-readiness.md`
- `docs/inactive-member-recovery-basic-draft-validation.md`
- `docs/inactive-member-recovery-final-validation.md` (new)

The new command is local-development-only, authenticated, fresh-fixture-account-scoped and bound to an expiring random run token. It is not a production sender endpoint. Faults exist only in test adapters; no production failure switch was added.

## Safeguards, artifacts, and cleanup

Snapshot root: `.codex-snapshots/20260906-recovery-final/`.

- `manifest-1788715467144.json` records pre-edit Git status, HEAD, original document hashes, and absence of the new test/report files.
- `before/docs/` preserves all three pre-edit documents.
- `share-path-validation.json` records the complete successful 12-case result.
- `validation-results.json` records the actual share, A–D, authenticated activity, cleanup, and disabled-live evidence.
- `.codex-snapshots/20260906-recovery-final-regressions/manifest.json` and `before/` preserve both test files before correction.
- `.codex-snapshots/20260906-recovery-final-regressions/full-matrix-validation.json` records exact CF and Node results.
- Previous enrollment, readiness, and Basic-Draft snapshots remain intact. Snapshot artifacts are private/ignored and are not part of the source check-in.

Harness iterations exposed and corrected only test plumbing: unavailable `URLSearchParams`, inherited PDF template-path resolution, RFC-2047 subject decoding, a fault callback that did not execute, strict status casing in an assertion, and fixture teardown ordering. Assertions prevented these runs from being reported as passing. Every iteration's disposable data/mail was cleaned. The temporary inherited-PDF probe log was preserved under the snapshot root, and its empty temporary directories were removed.

The successful 12-case run removed its 12 disposable accounts, 11 generated PDF/attachment files, and 19 captured messages including signup mail. The A–D run removed its four accounts and four captured recovery messages. The activity run removed its two accounts and files. A final exact-fixture cleanup removed 12 delayed welcome/iteration messages, including the activity signup messages. No unrelated recipient mail was removed.

Final read-only checks found zero disposable fixture users, orphan recovery events, orphan recovery-ledger rows, orphan voyage streams, or remaining share-fixture PDFs. All test browser contexts were closed. The final runtime probe reported `COMPILED=true`, `MAILHOG=true`, `LIVEENABLED=false`.

The reviewed check-in contains the accumulated recovery implementation, its tests/contracts, and these two approved test repairs. No private configuration, generated PDF, snapshot, log, or schema migration is included. The initial dirty worktree was preserved and reviewed rather than reset. Nothing is pushed or deployed by this approval.

## What remains outside local readiness

Production rollout remains a separately approved operation: verify the deployed schema/code/private configuration and mail links, approve a coverage-qualified enrollment cohort, retain the fresh 168-hour enrollment grace, inspect a production dry run, and only then authorize live sending and a production schedule. Signup coverage does not enroll members automatically. Unverified older accounts remain held; this task adds no backfill or legacy repair.
