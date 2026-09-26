# Day 39 Step 1 — recovery CTA destinations

Review date: 2026-09-24. Repository: `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw`.

**Status: Step 1 complete and locally validated. Production rollout and live sending remain outside scope.**

## Final behavior

The existing product workflows live in Dashboard modals. The links now carry an action that opens the appropriate workflow; they no longer stop at the generic Dashboard.

| Stage | URL after the configured public base | Behavior |
| --- | --- | --- |
| A | `/app/dashboard.cfm?recoveryAction=vessel` | Open existing Add Vessel workflow. |
| B | `/app/dashboard.cfm?recoveryAction=planner` | Enter existing new-route readiness/Trip Planner flow. A vessel-only member still receives the existing Getting Started gate; a ready member opens Trip Planner. |
| C | `/app/dashboard.cfm?recoveryAction=route&routeId=<id>` | Open newest active owned saved route, ordered by `updated_at DESC,id DESC`, matching `listMyRoutes`. Zero-leg saved work is supported. If no saved route exists, use `routeInstanceId=<id>` for the newest eligible owned generated route and its latest instance. |
| D | `/app/dashboard.cfm?recoveryAction=draft&floatPlanId=<id>` | Open the unique eligible owned Draft in its existing Basic editor or ordinary/route-backed wizard. Multiple eligible Drafts use the list fallback rather than an arbitrary choice. |

Stage B's existing readiness gate requires a vessel, contact, operator, and two waypoints. This change does not bypass that gate.

## Ownership, continuation, and fallback

`InactiveMemberRecoveryDestinationService.resolveStage()` uses parameterized queries constrained by the server's user ID before creating a specific object URL. Saved routes require `user_routes.user_id` ownership and `is_active=1`. Generated routes require a matching owned latest `route_instances` row, active `loop_routes` identity, clean PLANNED state, and no unfinished started leg.

Draft selection requires `floatplans.userId` ownership, current DRAFT state, no lifecycle activation/closure/share timestamps, and owned linked route/vessel/operator evidence where present. Canonical Basic Drafts are recognized through their existing markers and `floatplan_basic_details`. Successful share events or receipts, active target monitoring, and unfinished started legs prevent recovery reopening. This also handles successful Basic Review sharing that leaves status DRAFT and `initialSentAt` empty.

On every authenticated click, `resolveRequest()` repeats ownership/current-state checks using the authenticated session member. URL IDs are selectors, never authorization. Existing data-loading APIs retain their own ownership checks. Missing, deleted, foreign, inactive, advanced, shared, unreadable, or otherwise ineligible targets fall back to `recoveryAction=routes` or `recoveryAction=plans`, with guidance and focus on the existing Routes/Float Plans workspace.

Anonymous links use the existing login page and login API. The server reconstructs only fixed recovery actions and canonical IDs; login renders that safe destination. Client validation also requires the expected same-origin local path before redirecting. External URLs, protocol-relative URLs, arbitrary return fields, extra object IDs, and malformed IDs are rejected. Expired-session handling retains the same validated context. Ordinary login behavior is unchanged.

## Tracking and scope

Existing recovery subjects, bodies, CTA labels, message types, stage accounting, multipart layout, and compliance links remain. No campaign parameters or click-tracking hooks existed in the prior recovery builder/sender.

Snapshot comparison found exactly two changed existing email functions: `buildInactiveMemberRecoveryEmail` and `validateVerifiedInactiveMemberDraftUrl`; the new `validateVerifiedInactiveMemberRecoveryUrl` helper was added. The other **38 existing email function bodies are byte-for-byte unchanged**. Sender snapshot comparison confines its change to destination resolution and builder arguments after the existing pre-send checks.

No changes were made to the 168-hour policy, classifier, enrollment, ledger, duplicate-send prevention, disabled-account handling, recovery transport, or production schedules/configuration. No real recovery email was sent. This task performs no production enrollment or live sending.

## Files changed

### Application

| File | Change | Purpose |
| --- | --- | --- |
| [includes/InactiveMemberRecoveryDestinationService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryDestinationService.cfc) | Added | Resolve current owned route/Draft at send time and again on authenticated click; safe list fallbacks. |
| [includes/InactiveMemberRecoveryActionPathService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryActionPathService.cfc) | Added | Strict canonical recovery action/path allowlist; rejects arbitrary return URLs and extra fields. |
| [api/v1/email.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/email.cfc) | Modified | Stage-specific default CTA actions and validated internal route/Draft URL inputs. |
| [api/v1/InactiveMemberRecoveryService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/InactiveMemberRecoveryService.cfc) | Modified | Resolve destination after existing fresh eligibility/compliance checks; pass verified URLs to builder. |
| [includes/require_auth.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/require_auth.cfm) | Modified | Preserve valid recovery action through the existing login page. |
| [app/login.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/login.cfm) | Modified | Render validated continuation and update core.js cache key. |
| [assets/js/app/core.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/core.js) | Modified | Validate the local recovery destination before successful-login redirect. |
| [assets/js/app/auth.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/auth.js) | Modified | Preserve safe recovery context after expired-session API failures. |
| [includes/footer_scripts.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/footer_scripts.cfm) | Modified | Update auth.js cache key. |
| [app/dashboard.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/dashboard.cfm) | Modified | Recheck ownership/current target and render encoded action intent; update script cache keys. |
| [assets/js/app/dashboard.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard.js) | Modified | Dispatch the verified intent into existing vessel/planning/Draft workflows and useful fallbacks. |
| [assets/js/app/dashboard/routebuilder.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/routebuilder.js) | Modified | Open an owned saved route, including zero-leg work; safely handle stale generated-route recovery. |

### Tests

| File | Change | Purpose |
| --- | --- | --- |
| [tests/specs/InactiveMemberRecoveryActionPathSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryActionPathSpec.cfc) | Added | 12 path/allowlist cases, including root/subdirectory paths and unsafe inputs. |
| [tests/inactive-member-recovery-action-path-runner.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-action-path-runner.cfm) | Added | Local-only TestBox entry point. |
| [tests/specs/InactiveMemberRecoveryDestinationSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryDestinationSpec.cfc) | Added | 15 DB cases for A-D, deterministic choice, ownership, stale/foreign targets, multiple Drafts, shared Drafts, and active state. |
| [tests/inactive-member-recovery-destination-runner.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-destination-runner.cfm) | Added | Local-only TestBox entry point. |
| [tests/specs/InactiveMemberRecoveryEmailTemplateSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryEmailTemplateSpec.cfc) | Modified | 13 cases, including stage-specific URLs, unsafe URLs, unchanged copy/metadata and compliance. |
| [tests/specs/InactiveMemberRecoverySenderSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoverySenderSpec.cfc) | Modified | 16 orchestration cases now assert verified destinations while retaining revalidation/suppression checks. |
| [tests/support/RecoveryOrchestrationEmailStub.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/support/RecoveryOrchestrationEmailStub.cfc) | Modified | Pass the new internal route URL through the existing capture stub. |
| [tests/inactive-member-recovery-email-template.test.mjs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-email-template.test.mjs) | Modified | Update static CTA contract; all seven template Node checks pass. |
| [tests/inactive-member-recovery-destination-browser-fixture.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-destination-browser-fixture.cfm) | Added | Local-only, expiring keyed disposable SQL fixture; prepare/inspect/cleanup; no email transport. |
| [tests/inactive-member-recovery-destination.playwright.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-destination.playwright.js) | Added | 14 integrated browser scenarios; all pass through authorized local Playwright. |
| [tests/inactive-member-recovery-destination.spec.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-destination.spec.js) | Added | Standalone Playwright wrapper for the same scenarios; local run passed. |

### Documentation

| File | Change | Purpose |
| --- | --- | --- |
| [docs/inactive-member-recovery-email-templates.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-email-templates.md) | Modified | Current URL, selection, authentication, fallback, and tracking contract. |
| [docs/inactive-member-recovery-sender.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-sender.md) | Modified | Update only current destination integration contract; preserve historical results as historical. |
| [docs/inactive-member-recovery-destinations.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-destinations.md) | Added | This implementation and validation report. |

Existing files were backed up before edits by MCPCF under `.codex-snapshots/fpw-patches/20260924-*/`. The MJS test has an exact backup at `.codex-snapshots/20260924-recovery-destinations/inactive-member-recovery-email-template.test.mjs.txt`. New-file absence was checked before creation.

## Validation completed in this task

All tests below ran through MCPCF against the local ColdFusion development runtime:

| Runner | Passed | Failed/errors |
| --- | ---: | ---: |
| `inactive-member-recovery-policy-runner.cfm` | 29 | 0 |
| `inactive-member-recovery-classifier-runner.cfm` | 32 | 0 |
| `inactive-member-recovery-enrollment-runner.cfm` | 15 | 0 |
| `inactive-member-recovery-ledger-runner.cfm` | 4 | 0 |
| `inactive-member-recovery-sender-runner.cfm` | 16 | 0 |
| `inactive-member-recovery-readiness-runner.cfm` | 30 | 0 |
| `inactive-member-recovery-email-template-runner.cfm` | 13 | 0 |
| `inactive-member-recovery-destination-runner.cfm` | 15 | 0 |
| `inactive-member-recovery-action-path-runner.cfm` | 12 | 0 |
| **TestBox total** | **166** | **0** |

The existing `recovery-component-path-runner.cfm` additionally passed **7 checks** in local dev-subdirectory mode. This is not production/root-host browser verification.

Dashboard and route-builder JavaScript syntax parsing passed via MCP Playwright before its later profile lock. The final browser fixture's prepare/cleanup smoke test passed via MCPCF: eight disposable accounts and associated tracked objects were removed, all remaining counts were zero, and recovery submissions/ledger counts remained zero.

The saved browser test passed all 14 scenarios, with no page errors: actual anonymous login continuation; A; both Stage B readiness outcomes; C with zero/one leg; Basic/ordinary D; foreign route/Draft; deleted route/Draft; external return rejection; ordinary login; and expired-session continuation.

## Authorized local validation — completed

After the user explicitly authorized local Node/Playwright and Git fallback, the saved destination spec ran in an isolated Chromium browser: **14/14 scenarios passed**, with no page errors. The actual login form/API preserved every valid destination; foreign and deleted IDs resolved to useful fallbacks. Ordinary login and stale-session recovery continuation passed. All disposable fixture counts were zero after cleanup, with no recovery ledger entries or submissions.

Command:

```sh
node node_modules/@playwright/test/cli.js test tests/inactive-member-recovery-destination.spec.js --workers=1 --reporter=line --output=test-results/recovery-destinations
```

The existing `tests/inactive-member-recovery-sender.playwright.js` also passed both browser concurrency scenarios through the local Playwright runtime. First-claim and explicit FAILED-retry races each produced exactly one captured submission, one SENT row, and one competing skip. Attempt counts were one and two respectively. These fixtures use the existing capture transport; no SMTP or real recovery email was involved. Cleanup verified zero remaining users, events, and ledger rows. Detailed output is preserved in `.codex-snapshots/20260924-recovery-validation-evidence/sender-concurrency-results.json`.

All six existing Node suites passed:

| Node suite | Passed | Failed |
| --- | ---: | ---: |
| `inactive-member-recovery-policy.test.mjs` | 4 | 0 |
| `inactive-member-recovery-classifier.test.mjs` | 6 | 0 |
| `inactive-member-recovery-enrollment.test.mjs` | 8 | 0 |
| `inactive-member-recovery-ledger.test.mjs` | 7 | 0 |
| `inactive-member-recovery-sender.test.mjs` | 5 | 0 |
| `inactive-member-recovery-email-template.test.mjs` | 7 | 0 |
| **Total** | **37** | **0** |

The initial Node run had one documentation assertion failure because the updated contract omitted the tested phrase `template and rendering only`. The contract now explicitly restores that authority boundary, and the six suites pass unchanged. Git's initial whitespace checks found redundant EOF blank lines introduced during MCPCF writes; those were removed with exact pre-write backups. No behavioral code fix was needed. Existing modified files passed `git diff --check`; new files were checked separately with `git diff --no-index --check`, since the ordinary command does not include untracked files.

The earlier MCP profile lock and MCPCF missing-Node errors prevented those tools from launching a browser. The authorized local browser run resolves that validation gap without changing either tool configuration.

The SMTP/readiness browser workflow was intentionally not run because this task forbids real recovery email. Local tests do not claim production deployment or inbox delivery.

## Remaining work for Step 1 completion

None. The requested implementation, existing ColdFusion regression suites, destination browser scenarios, no-mail sender concurrency scenarios, Node contracts, and Git checks are complete.

Production enrollment, schedule activation, disabled-account work, and live recovery sending remain outside Step 1.
