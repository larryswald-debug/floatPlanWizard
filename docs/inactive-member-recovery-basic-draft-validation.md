# Recovery readiness: canonical Basic-Draft classifier validation

Date: 2026-09-06. Repository: `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw`.

Historical checkpoint: the later [final validation report](inactive-member-recovery-final-validation.md) supersedes this report's remaining-test, regression-exception, and uncommitted-status statements. Both regression exceptions were subsequently corrected with test-only changes, and the share-path campaign passed. The evidence below is preserved as the original Basic-Draft checkpoint.

## Verdict and scope

**Approved narrow Basic-Draft fix: PASS.** Fresh canonical Basic Drafts now classify as D, including real local MailHog recovery delivery. Unexpected zero references and missing/foreign nonzero vessel references still HOLD.

The requested regression run was completed, but is **not entirely green**: one unrelated existing CF suite cannot initialize, and one unrelated existing Node assertion fails. Both are recorded below and were left untouched. This is not a blanket production-readiness or deployment approval.

Production recovery sending remains disabled. No scheduler, schema, recovery-policy, enrollment, backfill, email-template, lifecycle, billing, or private-configuration changes were made in this follow-up. Earlier uncommitted recovery-readiness work remains present and was preserved.

## Root cause and exact change

`api/v1/floatplan.cfc:saveBasicFloatPlan` intentionally persists a route-less Basic Draft with `vesselId=0`. Its existing `markBasicOperationalFloatPlanScope` sets the Basic origin and scope flags, and its save transaction persists the plan's own `floatplan_basic_details` row. The prior classifier required every non-null vessel reference to resolve to an owned vessel, so it rejected this canonical sentinel.

The only production file changed in this follow-up is `includes/InactiveMemberRecoveryClassifierService.cfc`, in `loadLiveEvidence` (lines 401–445). The zero-vessel exception requires every condition below:

- The parent Draft belongs to the evaluated user; existing clean-Draft lifecycle gates still apply.
- `route_instance_id` and `route_day_number` are null.
- `route_origin='basic_float_plan'`.
- `is_reusable=0` and `is_visible_in_route_library=0`.
- `operatorId` is null.
- A `floatplan_basic_details` row references that exact plan ID.

The details table has no independent owner column; its identity is checked through the exact owned parent. Another plan's details cannot qualify it. A Basic origin label or zero vessel value alone is insufficient. Nonzero vessel IDs continue to require a matching owned vessel, and normal operator ownership checks remain unchanged. The existing behavior for null vessel references is unchanged.

This implements the approved Best Fix without changing canonical Basic saves or manufacturing vessel records. No broader alternative was applied.

## Files changed in this follow-up

Paths are relative to the repository above, not a list of all pre-existing dirty files.

| File | Change |
| --- | --- |
| `includes/InactiveMemberRecoveryClassifierService.cfc` | Narrow Basic sentinel predicate and explanatory comment |
| `tests/specs/InactiveMemberRecoveryReadinessSpec.cfc` | Thirteen additional canonical/sentinel/ownership cases; 30 tests total |
| `tests/support/RecoveryReadinessFixture.cfc` | Basic Draft fixture and exact dependent-details cleanup |
| `tests/specs/InactiveMemberRecoverySenderSpec.cfc` | Supply the existing fixture's explicit coverage verification to its synthetic classifier call |
| `docs/inactive-member-recovery-classifier.md` | Document the exception and current independent coverage/retained-share authorities |
| `docs/inactive-member-recovery-sender.md` | Correct stale coverage-provider documentation and link current validation |
| `docs/inactive-member-recovery-readiness.md` | Mark the earlier Stage D blocker/report as historical and link this result |
| `docs/inactive-member-recovery-basic-draft-validation.md` | This report |

The sender fixture previously provided enrollment but omitted the independent coverage proof now required by the approved contract. Its correction changes only a test argument; production coverage enforcement remains intact.

## Focused and end-to-end evidence

MCPCF executed the ColdFusion suites; MCP Playwright executed the browser workflows.

The 30-test readiness suite passes. Added checks include canonical zero acceptance, exact 168-hour eligibility, missing or wrong-plan details, incorrect origin/scope flags, unexpected route/day/operator references, missing and foreign positive vessel IDs, and normal owned positive vessel references. The database rejects null scope flags; that rejection is explicitly tested without altering the schema.

`tests/inactive-member-recovery-readiness.playwright.js`: **75 assertions passed** using fresh canonical signups and member save commands for A, B, C, and D. C used a saved named route without legs; D used the real route-less Basic Draft save with `vesselId=0`.

For each stage, verification covered separate enrollment, birth-coverage proof, ineligibility at 167h 59m 59s, eligibility at exactly 168h, dry-run without sending/claiming, one real local SMTP recovery send, durable SENT state, and suppression of a repeated send. The fixture supplies a controlled evaluation clock; it does not backdate enrollment or coverage records. The real default coverage verifier, classifier, ledger, compliance renderer, templates, and SMTP path were used.

Exactly one recovery message per stage was captured in local MailHog. Subjects were `Add your boat to FloatPlanWizard`, `Ready to plan your first trip?`, `Pick up your trip planning`, and `Your Float Plan is waiting`. Each message had HTML/plain-text parts, the approved mailing address, and distinct unsubscribe/preferences links. Signed-token behavior is covered by the compliance suite; this follow-up did not click each captured message's unsubscribe link.

`tests/member-activity-evidence.playwright.js`: **101 scenarios passed**, plus **11 authenticated CF integration tests**. Coverage includes profile CRUD, vessel photos, persisted route geometry, generated routes/Drafts, selected-contact saves, no-ops, ownership denial, concurrent identical saves, forced evidence-failure rollback, UTC/privacy, and source-row deletion retention.

Local SMTP configuration was observed as `host.docker.internal:1025`; the local probe confirmed MailHog. The final probe returned `COMPILED=true`, `MAILHOG=true`, and `LIVEENABLED=false`. No production mail was sent and no mail configuration was changed.

## Regression results

**304 ColdFusion tests passed across 24 runnable bundles / 23 passing runner endpoints.** The Premium runner contains two bundles. The authenticated 11-test activity result is counted once; its preliminary standalone run is not added again.

| Runner (`tests/<name>.cfm`) | Passed |
| --- | ---: |
| `inactive-member-recovery-readiness-runner` | 30 |
| `inactive-member-recovery-enrollment-runner` | 15 |
| `inactive-member-recovery-classifier-runner` | 32 |
| `inactive-member-recovery-policy-runner` | 29 |
| `inactive-member-recovery-ledger-runner` | 4 |
| `inactive-member-recovery-sender-runner` | 16 |
| `inactive-member-recovery-email-template-runner` | 11 |
| `non-essential-email-compliance-runner` | 8 |
| `basic-review-send-runner` | 11 |
| `runner` (Premium send/access) | 36 |
| `onboarding-runner` | 10 |
| `member-activity-evidence-runner` (authenticated) | 11 |
| `route-continuity-runner` | 4 |
| `scheduled-actual-departure-route-draft-runner` | 3 |
| `floatplan-ownership-authorization-runner` | 5 |
| `departure-reminder-runner` | 11 |
| `safe-arrival-notification-runner` | 11 |
| `route-instance-closure-runner` | 6 |
| `completed-trip-view-model-runner` | 7 |
| `completed-contact-access-runner` | 17 |
| `scheduled-actual-departure-runner` | 10 |
| `operational-route-geometry-snapshot-runner` | 8 |
| `route-reserve-mode-runner` | 9 |

Node: **57 of 58 checks passed** using:

```sh
node --test --test-reporter=spec tests/inactive-member-recovery-*.test.mjs tests/basic-review-send.test.mjs tests/member-activity-evidence.test.mjs tests/vessel-crud-expanded-fields.test.mjs tests/monitoring-utc-contract.test.mjs
```

Pre-existing exceptions, neither changed by this task:

1. `tests/specs/PublicFollowPrivacyContractSpec.cfc:13` cannot initialize because it references missing `fpw.api.v1.PasswordHashService`. Its runner returned HTTP 500 before any specs executed. This is not a passing privacy-suite result.
2. `tests/vessel-crud-expanded-fields.test.mjs:263` expects a short literal `VARCHAR(45) ... NULL DEFAULT NULL` sequence in the existing vessel-capacity down migration. The migration constructs intervening charset/collation SQL dynamically, so the regex fails. The test and migration are unchanged; no migration was run.

`git diff --check` passes. Basic/Premium sharing and retained-attempt behavior were checked through the existing contract/integration suites. This follow-up did not run a new real-SMTP fault-injection campaign across every trip-sharing path; do not interpret the A–D recovery delivery result as that separate proof.

## Snapshots, cleanup, and Git safeguards

Snapshot root: `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/.codex-snapshots/20260906-basic-draft-classifier/`.

- `manifest-1788709987063.json`: initial Git status, HEAD, and six pre-edit file hashes.
- `manifest-1788710226523.json`: sender-spec pre-edit hash.
- `manifest-1788710826395.json`: this report recorded as absent before creation.
- `before/<repository-relative-file>`: seven pre-edit copies, including previously untracked work; all SHA-256 checksums verified against their manifests.
- `validation-results.json`: structured observed test, mail, cleanup, and guardrail results.

Only this run's disposable account/dependent records and exact-recipient captured messages were cleaned. The four A–D accounts and two activity accounts were removed. Four recovery emails and two activity-signup welcome emails were deleted from local MailHog; matching messages remaining: zero. Test browser contexts were closed. Final read-only checks found zero disposable fixture users, orphan readiness evidence, orphan recovery-ledger records, or orphan Basic test details for the checked fixture scopes.

The initial dirty worktree and existing snapshots/artifacts were preserved. Initial Git status had 12 modified and 21 untracked files; final status has 13 modified and 22 untracked files, including the preceding readiness work. All changes remain unstaged on `main`; the index is empty and HEAD remains `5620db87a8459da606035fae3b7a69ac0bc5ef7e`. Nothing was committed, pushed, deployed, or migrated. No legacy data was repaired or backfilled, and production recovery sending/scheduling was not enabled.
