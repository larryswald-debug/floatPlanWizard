# Unified authentication and progressive profile implementation

Status: the approved authentication implementation and local validation are complete. The navigation correction below restores the original public header and records two pre-existing Resources test expectation failures. The user authorized repository cleanup, commit and push on 2026-10-02. Production deployment remains subject to the environment checks below.

## Backup and approved schema execution

The user approved the local Docker/MySQL and Node/Playwright fallbacks on 2026-10-01. MCPCF remained the primary repository/runtime tool. Its Playwright runner lacked Node/npx; the Playwright MCP browser profile was locked. Local testing used the installed Node 25.6.1 and Playwright 1.57.0 without adding dependencies.

Before either migration, the complete local FPW database was backed up outside the web root:

`/Users/lawrencewald/Docker/cf-mysql-dev/backups/unified-auth/20261001-164938/FPW-before-unified-auth.sql`

- Size: 3,506,990 bytes.
- SHA-256: `b2c4cdd2c0d40489e5455ec3da710b2138720143201bbaaca5534ebd98e5cef2`.
- The compressed copy was decompressed and checked against the same hash.
- A temporary isolated MySQL container successfully restored the dump. All 122 original table checksums and stored-object counts matched. The verification container and its anonymous volume were removed.
- Backup directory permissions: 0700; dumps and manifest: 0600.

Only the two approved migrations were applied to local database `FPW`, MySQL 8.0.43:

| Migration | Result |
| --- | --- |
| 20261001_001_auth_rate_counters | Preflight PASS, up exit 0, schema verifier PASS |
| 20261001_002_users_email_uniqueness | Preflight PASS, up exit 0, unique-index verifier PASS |

Both preflights passed before either up script. Execution occurred at 2026-10-01 20:51:27–28 UTC. No collision/whitespace repairs, data backfills, or other migrations were performed. Up scripts were not rerun.

Final SELECT-only verification also passed: InnoDB counter table, eight required non-null columns, binary subject hash, microsecond timestamps, unsigned counters, composite primary key and expiry index; full unique email index under the existing `utf8mb3_general_ci` collation; zero whitespace violations or email collisions. The scope column is named `subject_scope`.

Evidence: `migration-results.json` and script logs in the backup directory; `../final-schema-verification.json`.

## Implementation and execution paths

| Area | Files and principal blocks | Behavior |
| --- | --- | --- |
| Passwords | api/v1/PasswordHashService.cfc: hashPassword, verifyPassword, verifyAndUpgrade; auth.authenticateMember; join.createAccount; profile password action; password_reset confirm | PBKDF2 new writes, bounded parser, successful legacy upgrades with binary compare-and-swap/reverification, unchanged passwordCreated on transparent rehash, atomic reset consumption. |
| Request security | api/v1/AuthRequestGuardService.cfc; api/v1/AuthRateLimitService.cfc; auth/join/profile/password_reset handlers; assets/js/app/api.js and dedicated form callers | POST, session CSRF, supplied-origin validation, no-store responses, database admission/reservation limits, fixed expiry, bounded cleanup and fail-closed behavior. IP extraction uses REMOTE_ADDR. |
| Signup integrity | api/v1/join.cfc: handle/createAccount/getConsentDisclosure; api/v1/auth.cfc; api/v1/adminUsers.cfc; includes/ProductEventService.cfc | Shared nonremote signup operation, optional names, normalized unique email, verified competing-account branch, preserved credit/events/enrollment/welcome, session rotation, authoritative versioned consent metadata. |
| Continuation | includes/AuthContinuationService.cfc; includes/require_auth.cfm; assets/js/app/auth.js; dedicated login/join/forgot/reset pages and scripts | Typed per-token session goals, eight-entry/four-hour bounds, existing Day 39 validation and current ownership resolution, member binding, acknowledgement/dismissal, same-session reset handoff. Only navigation/editing resumes. |
| Modal/navigation | partials/fpw-auth-modal.cfm; assets/js/app/auth-modal.js; assets/css/fpw-auth-modal.css; includes/top_nav.cfm/footer.cfm/footer_scripts.cfm | Native two-field dialog, exact disclosure, inline errors, duplicate-submit and late-response handling, focus/scroll restoration, dedicated fallbacks, masked private name/email identity. |
| Getting Started | app/dashboard.cfm; assets/js/app/dashboard.js; assets/js/app/dashboard/onboarding.js | New-account overview, one-use creation notice, unchanged four essentials, persistent goal outside the checklist, explicit Continue after readiness. Overview acknowledgement and reload cannot auto-open a new account's planner. |
| Names/Float Plans | api/v1/profile.cfc: readMemberName/update-name; app/floatplan-wizard.cfm; assets/js/app/floatplanWizard.js; Dashboard Basic fields and basic-floatplan.js; floatplan.cfc; BasicReviewSendService.cfc; email.cfc; voyage.cfc | Inline first/last-name capture, name-only update preserving phone, guarded meaningful saves/new sends, completed-send replay, separate sender attribution, public unnamed-owner Captain fallback. |
| Guide/analytics | great-loop/trip-planning/index.cfm; partials/fpw-action-cta.cfm; assets/js/fpw-action-cta.js; join.js; ProductEventService.cfc | Typed planner CTAs and corrected guide instructions; allowlisted attribution/events; continuation success only after actual arrival/tool opening and server acknowledgement. |

Existing-file edits have MCPCF backups under `.codex-snapshots/fpw-patches/`. The refreshed `.codex-snapshots/unified-authentication-20261001-manifest.json` lists all changed paths, available pre-edit backups, Git HEAD and current checksums, including uncommitted work. New files were confirmed absent before creation. This code manifest is separate from the database backup.

## Authenticated integration results

Thirteen final live cases passed across the following suites. These use real local endpoints, fresh disposable accounts and records. Mail configuration and the Administrator SMTP server were checked as `host.docker.internal:1025`; its banner identifies MailHog. No real recipients were involved.

| Suite | Passed | Evidence |
| --- | ---: | --- |
| tests/unified-auth-live.spec.js | 1/1 | Modal signup without names; actual cookie rotation; full overview; vessel/contact/operator/two-waypoint gate; explicit final continuation and reload; eligible existing-member bypass; incorrect/correct modal login; independent tab goals; foreign-session rejection; mobile Account; PII-free analytics. |
| tests/unified-auth-dedicated-live.spec.js | 2/2 | Dedicated login/logout, wrong/current credentials, password change, captured reset delivery, same-session planner handoff, different-browser reset with old intent ignored, consumed-token replay rejection, named navigation. |
| tests/member-profile-name-live.spec.js | 1/1 | Regular/standalone/Basic editors, first-only/last-only names, blank/overlength rejection, phone preservation, direct Review, meaningful save/send guards, all three real email deliveries, completed-send replay, generated PDF identities. |
| tests/auth-endpoint-security-live.spec.js | 6/6 | Method/CSRF/origin rejection, forwarded-header spoofing, SHA/literal short-password upgrade, password change, session rotation, shared failure limits/Retry-After, member-switch continuation fallback. |
| tests/auth-signup-integrity-live.spec.js | 3/3 | Stale disclosure, simultaneous case-equivalent signup, exactly-once account/events/enrollment/credit/welcome, both credit branches without a trial/entitlement, dedicated Join retaining its planner token and overview. |

The retained Basic saved-draft action was exercised through its existing workspace renderer in a test container while the global credit flag stayed unchanged. The separate alternate-signup test temporarily changed that flag and restored its original true value in finally; restoration was independently checked.

The main fresh-account browser scenario passed as one uninterrupted run. Separate resumed runs used existing disposable accounts during harness debugging; they are not counted again.

## Final targeted regression results

These suites were rerun after authenticated integration and the final fixes.

| Suite | Passed |
| --- | ---: |
| AuthSecurityServiceSpec | 10/10 |
| AuthPasswordIntegrationSpec | 4/4 |
| AuthRateLimitIntegrationSpec | 9/9 |
| AuthContinuationSpec + existing InactiveMemberRecoveryActionPathSpec | 19/19 |
| Existing InactiveMemberRecoveryDestinationSpec | 15/15 |
| BasicReviewSendContractSpec | 13/13 |
| WelcomeOnboardingContractSpec | 10/10 |
| Float Plan PDF itinerary/timezone contracts | 3/3 |
| Chromium modal/continuation/attribution/profile UI suites | 38/38 |
| WebKit native-modal suite | 5/5 |
| Node Basic Review contracts | 8/8 |

Totals: **83 CFML + 38 Chromium UI + 5 WebKit + 8 Node = 134 regression checks passed**. Together with **13 authenticated integration cases**, this is **147 passing test executions**. The five WebKit checks intentionally repeat modal cases on another engine. Earlier failed/debug runs are excluded from these passing totals.

ColdFusion metadata compilation passed for the affected authentication/profile/delivery components. All 22 changed/new JavaScript files passed Node syntax checks. Final Git whitespace validation passes.

Rate tests cover separate service instances, concurrent reservations, stale-generation completion, fixed expiry, zero-failure success release, unavailable-datasource fail-closed behavior, preserved reset budgets and bounded cleanup. Password tests cover concurrent upgrade winners and an obsolete reset credential. Native dialog checks cover keyboard containment, Escape, focus restoration, mobile drawer closure, preserved background scrolling and accessible alert/busy markup; no physical-device or assistive-technology session is claimed.

Two additional live persistence probes passed: an actual restart of cfdev-mysql, followed by applicationStop() and verified application reinitialization. Three synthetic limiter rows retained identical window generations, admission/failure/in-flight counts and 429 enforcement across both restarts. Initial database reconnection produced ten transient JDBC probe failures; connectivity recovered by approximately 95 seconds without driver or configuration changes. This local recovery delay is recorded as a runtime deviation, not hidden by the passing persistence result. Synthetic rows and the temporary fixture were removed; anonymous auth bootstrap returned 200 afterward.

## Defects found and corrected

| Finding | Correction / proof |
| --- | --- |
| Remote profile GET rejected action=name with HTTP 500 | Added the optional handle action argument; real profile/name flows and compilation pass. |
| MySQL unsigned subtraction underflow prevented successful limiter finalization | Guarded decrements with CASE before subtraction. Zero-failure reservation regression failed before correction and passes now. |
| CF chr(0) collapsed the intended limiter tuple separators | Added version-2 length-prefixed field framing. A concrete valid IPv6/account collision failed before correction and passes now. This was pre-release local data; no deployed counter migration occurred. |
| Standalone Forgot/Reset scripts called an unloaded Api object | Added api.js to both dedicated pages; real reset/change/replay flows pass. |
| Modal backdrop scrolling displaced the originating guide | Lock and restore the existing root overflow/scroll state; desktop/mobile tests pass in Chromium and WebKit. |
| Dedicated Join discarded a newly member-bound goal | Resolve the existing token with response.USERID; dedicated Join planner regression passes. |
| A member change could invalidate the pre-auth token after credentials succeeded | Re-read the intent for the authenticated member and safely fall back to Dashboard; HTTP regression passes. |

Earlier implementation checks also corrected a missing reset CSRF header, lost dedicated recovery handoffs, malformed Account markup, premature new-account planner dispatch after overview acknowledgement, and Basic draft-load error handling. The final suites exercise those paths.

Harness corrections were kept separate from product defects: immediate-navigation response capture, asynchronous MailHog polling (5 to 45 seconds), seeded-member Welcome acknowledgement, smooth-scroll setup timing, WebKit's native dialog focus target, and PDF AcroForm rather than text-only inspection.

## Cleanup and data preservation

- All disposable users and their owned vessels, contacts, operators, waypoints, routes, plans, events, credits and receipts were removed by exact fixture identity.
- All task-recipient MailHog messages and generated application PDF files were removed. Evidence PDFs/screenshots remain outside the web root.
- Known version-1/version-2 limiter keys were snapshotted and removed. Ten remaining unidentified rows were already expired; they were snapshotted and removed only after expiry was verified. No unknown unexpired row was deleted.
- Final reads: **3 users** (the original baseline), **0 auth_rate_counters**.
- All **122 original table data checksums match the pre-migration backup**; this verifies original application data was preserved. Auto-increment sequences were not reset.
- Temporary backup-restore containers/volumes and temporary cleanup endpoints were removed. Prior tracked test-results artifacts were restored byte-for-byte; new runner output was moved outside the web root.
- Earlier worker reports describe their point-in-time remaining counter hashes. The final cleanup above supersedes those temporary exceptions.

## Evidence locations

All execution evidence is under `/Users/lawrencewald/Docker/cf-mysql-dev/backups/unified-auth/`:

- `20261001-164938/`: verified database backup, restore checks, migration outputs, full-flow ledgers, post-validation data checksums.
- `auth-security-validation-summary.json`, `auth-security-final-report.json`, `rate-endpoint-final-report.json`, `dedicated-intent-report.json`.
- `dedicated-validation-report.json`, `member-profile-validation-report.json`.
- `root-fixture-cleanup.json`, `root-mail-cleanup.json`, counter cleanup snapshots/reports.
- `final-schema-verification.json`, `final-js-syntax-results.json`, `final-cf-regression-results.json`, final regression/browser output directories.
- `restart-persistence-proof.json`: database/application restart probes, transient JDBC recovery and cleanup.

Private fixture credentials/session files are disposable test evidence outside the web root, not deployable assets.

## Final Git state

Branch: `main`; HEAD: `5fe47182ec7cb82f56384d4d785c7677de0e3a31`.

**40 modified tracked files, 36 new untracked files, 0 staged files.** The new files comprise the six supporting runtime files, eight migration artifacts, this record and focused tests/fixtures. No commit, push or deployment occurred. No tracked test-results changes remain.

## Release assessment, preserved behavior and rollback

The approved Best Fix is implemented and the local authentication, onboarding, continuation, name and delivery checks pass. Production release readiness is not established by local tests alone. Before production execution, retain separate approval and verify:

1. Production email uniqueness/whitespace against that environment's actual schema/collation, and a restorable production backup.
2. Trusted client-IP restoration behind Cloudflare before relying on production IP budgets; WAF/rate-rule configuration remains unverified. Merely receiving CF-Connecting-IP is not trusted.
3. Production runtime/browser, actual secure-cookie behavior and mail delivery. Local runtime reports sessionType=j2ee but issues rotating CFID/CFTOKEN cookies with HttpOnly, SameSite=Lax and Secure=false on HTTP. No CF/session configuration was changed to hide this discrepancy.
4. Production analytics delivery; local GA delivery is disabled. Local event payloads/masking were checked without claiming production delivery.

**Safest Fix alternative:** a coordinated security-only rollout with dedicated authentication screens can precede modal/profile presentation. It still requires the same validated password readers, request callers/handlers and schema. That staged rollout has not been performed; the user approved the complete Best Fix.

Planning still requires vessel, complete shore contact, operator and two waypoints. Member names do not gate planning or Getting Started. Captain/operator storage and PDF templates/generation code remain unchanged; rendered/generated PDFs retained operator values and omitted the member sender. Fixed-width clipping of deliberately long fixture emails and existing template footer overlays were observed; this is content/identity regression proof, not cosmetic PDF certification.

No trial activation, entitlement redesign, historical account repair, consent backfill, cleanup scheduler, archive model, screenshot substitutions, production changes or Cloudflare configuration changes were introduced.

Rollback must coordinate callers and handlers. Do not drop auth_rate_counters while handlers use it. **Once PBKDF2 credentials are written, every deployed reader must keep supporting PBKDF2; a SHA-only rollback is unsafe.** Preserve created accounts, saved names, consent events, credits and receipts. Prepared down migrations have not been executed.

Legacy SHA/literal compatibility, existing request-derived reset-link origin/global-session-revocation behavior, and same-session-only recovery continuation remain acknowledged limitations.

## Navigation correction — 2026-10-01

The user superseded the anonymous Account-label design with the original public navigation. The Best Fix and Safest Fix are the same narrow correction: restore the original anonymous controls, retaining the approved authentication integration and name/email label.

Source of truth: Git HEAD `5fe47182ec7cb82f56384d4d785c7677de0e3a31`, compared with the complete pre-correction working tree saved in `.codex-snapshots/navigation-correction-20261001/`. That snapshot contains all 76 already changed paths, hashes, the original header and the existing full diff. MCPCF also backed up each patch.

Inspected navigation sources: `includes/top_nav.cfm`, `includes/footer_scripts.cfm`, `assets/css/top-nav.css`, `assets/css/fpw-auth-modal.css`, `assets/js/app/auth-modal.js`, `assets/js/app/auth.js`, `assets/js/app/api.js` and the existing public/mobile navigation tests. The root cause was the anonymous action block removing Start Free and relabeling Login as Account; the existing navigation stylesheet, menu markup and mobile/dropdown JavaScript had not been redesigned.

**Files changed in this correction:** `includes/top_nav.cfm` (anonymous actions, lines 583–593) and this implementation record. The production correction is four restored Start Free markup lines and one visible-label replacement.

- Restored the original prominent Start Free anchor, classes, arrow, position and direct `/fpw/app/join.cfm` destination.
- Restored the person-icon Login label and original `/fpw/app/login.cfm` fallback. Its already-approved modal interception remains intact.
- Retained the existing authenticated dropdown and My Account destination, displaying the existing combined name or email fallback. Existing minimal ellipsis styling and Clarity masking remain.
- Branding, promo, menu order, icons, link destinations, dropdown behavior, 1050px breakpoint and mobile drawer code match the original header. All existing CSS is unchanged by this correction.
- Password/backend security, schema, limiter, modal, continuation, Getting Started, Float Plan behavior, captain/operator identity, PDFs, pricing and public content were not changed by this correction.

Validation after the correction:

| Check | Result |
| --- | --- |
| AuthSecurityServiceSpec | 10/10 passed |
| AuthContinuationSpec + existing Day 39 path specs | 19/19 passed |
| Existing native authentication modal browser suite | 5/5 passed |
| Existing public Resources navigation browser suite | 4/6 passed; two pre-existing test expectation failures below |
| Focused real-account navigation scenario | All 16 checkpoints passed: anonymous homepage/Join link, original menu order, modal login, email fallback, immediate/saved name display, original My Account destination, desktop and mobile logout, and mobile widths 360/390/760/1024 |
| Visual inspection | Anonymous desktop/mobile, named desktop and long-email mobile screenshots reviewed; full identity remains the accessible button name |
| Git whitespace and related JavaScript syntax | Passed |

The two existing Resources test failures are unrelated to this correction. At `tests/public-resources-nav.spec.js:103`, `innerText` returns BOATING SAFETY because the original `top-nav.css:764` applies uppercase, while the test expects title case. At line 212, the test expects Common Boating Emergencies on the third Tab, whereas the unchanged markup puts Shore Contact Guide there and Emergencies eighth. Independent browser observation and byte comparisons with HEAD confirmed both; application and test files were left unchanged.

The focused harness initially expected logout to reach the login form. Source inspection confirmed the existing `AppAuth.redirectToLogin` actually returns to `/index.cfm`; only the temporary harness assertion was corrected. Two preliminary runs are excluded from the final passing result. No application fix was needed.

Disposable users and their product events from all three focused runs were removed by the existing exact-ID fixture cleanup. SELECT verification found zero remaining fixture users/events and the original three local users. The limiter had three rows before and after this correction; existing unrelated account rows were preserved and the shared IP counter advanced normally. No migration or database restore was run.

Evidence: `/Users/lawrencewald/Docker/cf-mysql-dev/backups/unified-auth/navigation-correction-evidence/` (`validation.json`, screenshots, final scope/diff evidence); pre-existing test failure output under `navigation-correction-results/`. The temporary browser harness is under the ignored correction snapshot, with no new runtime file or dependency.

Final Git scope remains **40 modified tracked files, 36 untracked files and 0 staged files**. Relative to the pre-correction snapshot, only `includes/top_nav.cfm` and this record changed. No commit, push or deployment.

## Top-nav Login destination — 2026-10-02

The user requested Dashboard after top-nav login. The anonymous Login anchor in `includes/top_nav.cfm:588` was still declaring `data-fpw-auth-intent="account"`; the existing continuation resolver correctly sent it to Account. The narrow Best/Safest Fix changes that attribute to `dashboard`. No redirect logic, layout, backend, schema or authenticated My Account link was changed.

Snapshot `.codex-snapshots/top-nav-dashboard-20261002/` covers all 76 pre-existing changed paths and the current diff. MCPCF also backed up each patch. Existing top-nav selectors/expectations were updated in `tests/unified-auth-modal.spec.js` and `tests/unified-auth-live.spec.js`; explicit Account continuation coverage remains unchanged.

Validation: the five existing modal tests passed. Fresh real-account login through the homepage top nav reached Dashboard at desktop 1440px and mobile 390px, acknowledged its continuation, and did not open the planner. The signed-in My Account dropdown still reached Account on both widths. Both focused checks passed with no browser JavaScript exceptions. Disposable fixture cleanup succeeded. The broader signup/planning live suite was updated but was not rerun for this single-attribute change.

The first temporary browser harness run hit a Playwright response-body retrieval race during navigation. The harness was adjusted to assert the successful HTTP response and actual authenticated destination; no application change was needed. That preliminary run is excluded from passing results and its fixtures were cleaned up.

Evidence: `/Users/lawrencewald/Docker/cf-mysql-dev/backups/unified-auth/top-nav-dashboard-20261002/`. No commit, push or deployment.

## Repository cleanup and commit readiness — 2026-10-02

The user authorized committing and pushing the complete 76-file implementation on `main`. A fresh fetch confirmed local HEAD matched `origin/main` before packaging. Snapshot `.codex-snapshots/pre-commit-unified-auth-20261002/` preserves all current files, hashes and the pre-cleanup diff.

The staged whitespace check found extra terminal blank lines in 22 new files; only those blank lines were removed. The pre-commit artifact review found no captured credentials, session files or real secrets among the 36 new files. Existing backups and browser execution artifacts remain outside the commit.

One test-harness omission was corrected: `tests/member-profile-name-live.spec.js` now requires `FPW_AUTH_LIVE=1`, matching the other live suites. A normal run with that variable unset reported exactly one skipped test and performed no fixture work. This guard does not change application behavior or the explicitly enabled live test.

All 22 changed/new JavaScript files passed syntax validation. The previously recorded integration results and the two pre-existing Resources expectation failures remain the validation record; they are not represented as a newly rerun full suite. Source commit/push does not execute production migrations or deploy the application.
