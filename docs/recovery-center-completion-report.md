# Recovery Center implementation completion report

Local implementation date: 2026-10-03. Repository: `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw`.

## Result and rollout state

Implemented the approved three-contact Recovery Center by adapting FPW's existing recovery engine and ledger. Numbered contacts, A/B/C/D destinations, transport attempts, and engagement are separate concepts throughout processing, storage, messages, reporting, and the admin interface.

The approved **Best Fix** is implemented. The approved **Safest Fix rollout** was used: files and database were backed up, recovery scheduling was paused, the independently verified empty ledger was migrated, the schema was verified, and canonical local/non-delivering validation preceded the one-time reset. Production deployment and operational sending were not performed.

The actual reset covered **2 existing enrollments**, with one database UTC effective start, **2026-10-03T17:36:28Z**. Original enrollment events are unchanged. Settings remain **24 / 24 / 24 hours**, revision **3**. The revision increased only because browser tests saved the same values twice.

Retained dry run **30**, source `local_rollout_validation`, completed with two evaluated members: both **Contact #1 of 3**, current **Destination A — Add Vessel**, waiting until **2026-10-04T17:36:28Z**. It made **zero claims, submissions, accepted sends, failures, or holds**. Its two persisted evaluations retain initial eligibility and final skipped/waiting outcomes.

## Discovery, source of truth, and change

The old delivery identity was member plus destination A/B/C/D. The old policy/classifier also used destination ordering and prior-stage sends to suppress or order sends. That could not represent a timed sequence which legitimately sends Contacts #1–#3 to the same destination.

The existing validated enrollment event, classifier and product evidence remain authoritative. The change returns the original immutable enrollment event ID, replaces the ledger identity with `(recovery_enrollment_event_id, contact_number)`, and uses contiguous confirmed accepted-contact history to select a number. Destination classification remains based on actual current product evidence. No second automated sender, parallel recovery ledger, recurring cycle, or restart mechanism was introduced.

The execution path remains:

1. Scheduled runner → existing `InactiveMemberRecoveryService.processBatch`.
2. Validated enrollment, settings/state, classifier and policy resolve current eligibility.
3. Existing member-row lock and ledger derive and claim the next contact or permitted same-contact retry.
4. Fresh classifier/destination resolution → existing email renderer with separate contact number and destination stage.
5. Independent final state, settings, recipient/preference, eligibility and ownership/destination checks cancel stale preparation.
6. Existing multipart mail transport runs outside the transaction.
7. Claim-token-protected ledger confirmation controls contact progression; optional observability records evaluation and attempt outcomes.

Confirmed Contact #3 completes automation only. It never marks Returned or Engaged. Destination changes, pause/resume, activity, and elapsed time preserve contact position and cycle identity. Known failures retry that contact within the independent three-transport-attempt limit; uncertain transport or ledger confirmation holds it.

## Timing, settings, and reset

First Recovery Delay applies to Contact #1; Recovery Stage Interval spaces Contacts #2 and #3; Recovery Attribution Window controls attribution only. Each is independently stored and validated as a whole number from 1 through 720 hours, default 24. Current values are read without an indefinite cache.

Eligibility retains the approved later-activity/stage-entry postponement behavior using canonical anchors. Later activity can defer a contact without resetting its number. The accepted message freezes its own attribution hours and deadline.

Settings Preview Impact is read-only for durable data and reports affected, earlier/later, newly immediate, and earliest resulting eligibility. Actor-bound, expiring, single-use review; POST; CSRF; current authorization; fresh impact re-evaluation; and one atomic old/new audit accompany a save. A save never sends mail.

The reset captures an unchanged reviewed enrolled cohort and one whole-second database UTC timestamp. It writes effective-start overlays and reset history while retaining original enrollment IDs, timestamps, metadata, product progress, and coverage. Later signups use their real enrollment times. Nonempty-ledger, stale-cohort, already-reset, replay, and audit-failure cases are guarded.

Actual retained reset evidence:

| Member | Original enrollment event | Original enrollment UTC | Effective recovery start UTC |
| --- | --- | --- | --- |
| 3752 | 5090 | 2026-09-25T00:49:22Z | 2026-10-03T17:36:28Z |
| 4464 | 6500 | 2026-10-02T14:39:09Z | 2026-10-03T17:36:28Z |

Reset operation: `1C6305CD-DF84-D343-04A254C21CEC42CE`; cohort audit row: **1320**. Pause/exclusion remain false for both. Repeated reset preview returned `RESET_ALREADY_COMPLETED`; the consumed review token returned `REVIEW_REQUIRED`.

## Backups and migration

Pre-edit Git state: clean `main...origin/main`, HEAD `b5308208b696e68b577edb88ec5f32beef747448`.

Pre-edit file snapshot:

`/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/.codex-snapshots/20261003T165055Z-recovery-center`

Its manifest covers **1,476 tracked files**, original Git state, and per-file SHA-256 values; private Stripe configuration was excluded. The complete snapshot was independently rehashed with **zero mismatches**. Manifest SHA-256:

`5d57a23342e74503447e4fe76b97d1054e207cc1baf650b8d546cfb83fda828c`

Database backups are outside the web root, directory mode 700 and file mode 600:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `/Users/lawrencewald/.codex/backups/fpw/20261003T165055Z-recovery-center/FPW-before.sql` | 3,515,842 | `9fd45e5a250de197b0c883a9cd915588a5c5ec32e45c4153a6e692683ee620d9` |
| `/Users/lawrencewald/.codex/backups/fpw/20261003T165055Z-recovery-center/FPW-before-reset.sql` | 3,534,998 | `5250c48ff7f805382f13e1fdad153e2c217eacc25730ee513a070443b128b8b8` |

Verified local database: **FPW**, datasource `fpw`, **MySQL 8.0.43**, Docker `cfdev-mysql`. Native recovery task **Run Recover User** was paused before migration. The processor also checks `.codex-snapshots/recovery-center-migration.lock` before writes; the transition sentinel was removed only after the schema and contact-aware code were ready for local validation.

Four migration files: `database/migrations/20261003_001_recovery_center.{preflight,up,verify,down}.sql`. The migration independently requires an empty old ledger and refuses inferred conversion of historical deliveries. Initial population was two valid enrollments and zero deliveries.

The first ALTER attempt stopped because the old destination CHECK referenced the column being renamed. No ledger conversion occurred. The migration was corrected to drop that CHECK in the same ALTER and add the new destination CHECK; empty-ledger guards were rechecked before applying it successfully. This is recorded as a local implementation correction, not hidden as a successful first execution.

The existing ledger now has `recovery_enrollment_event_id`, `contact_number` constrained 1–3, and separate `destination_stage` constrained A–D. It retains status, claim token, transport-attempt count and timestamps. New unique/index authority includes `uq_recovery_enrollment_contact`, `ix_recovery_member_contact`, and an enrollment-event foreign key.

Five supporting tables were added:

- `inactive_member_recovery_settings`
- `inactive_member_recovery_member_state`
- `inactive_member_recovery_runs`
- `inactive_member_recovery_evaluations`
- `inactive_member_recovery_messages`

Message uniqueness covers `(delivery_id, transport_attempt_number)`, durable personal `submission_identity`, and opaque `public_id`. Run UUIDs are unique. Member/time, run/evaluation, performance, and reconciliation indexes were verified from `information_schema`. Existing `product_events` and `fpw_admin_audit_log` are reused.

The guarded down migration was not executed; it refuses to discard delivery/message/evaluation/run/state/reset or changed-settings evidence. Production database dialect and deployment remain unverified; do not treat this local MySQL result as production migration proof.

## Observability, tracking, attribution, and security

Every actually evaluated member gets a stable initial evaluation when storage is available, with final cancellation/send outcome separate. Typed columns carry enrollment/cycle, contact/total, destination/type/object, template/version, transport attempt, decision, reason and timestamps. Immutable message attempts retain their actual recipient/content/destination; a retry at a newly legitimate destination does not rewrite earlier attempts.

Dry runs are observable without enrollment, claims, or sends. Incomplete runs, uncertain outcomes, and optional telemetry gaps remain explicit. SMTP acceptance is never presented as delivered or bounced. Optional reporting failures cannot authorize retry or break committed member actions; required eligibility/settings/state/preferences checks remain fail-closed.

Open/click tokens use random opaque references and purpose-bound signatures, contain no public member ID/email/raw destination, and expire 90 days after acceptance. Invalid/expired opens return the normal transparent image without recording; clicks use the fixed safe FPW entry point. Valid clicks revalidate owned destinations and use existing authentication continuation. Tokens never authenticate members. A guarded update also catches expiry between validation and recording.

Opens and clicks have independent/repeat/late counters. Late signals remain visible without reopening attribution. Attribution selects the latest accepted automated contact for that member whose frozen interval contains the original source timestamp, with source-event deduplication. Authenticated returns and meaningful durable actions/shares are distinct. Login, views, unchanged saves, opens and clicks do not establish engagement.

Existing canonical activity sources feed a nonfatal post-request observation hook and bounded reconciliation. Historical previews use stored rendering; new previews use the real renderer. Raw and encoded bearer values are redacted, links/resources disabled, and browser previews sandboxed with network access disabled.

Recovery-only mail logs contain status without recipient, subject, content, token or raw exception. Direct log inspection found:
`2026-10-03 17:26:31 recoveryMail status=SEND_ACCEPTED`
and
`2026-10-03 17:33:16 recoveryMail status=SEND_ACCEPTED`.

## Recovery Center interface and controls

`/admin/recovery-center.cfm` uses the existing admin authorization/layout/navigation, CSRF conventions and vanilla JavaScript. Six views are implemented: Dashboard, Recovery Queue, Runs, Members, Performance, Settings.

The UI distinguishes current next contact, actual destination, last accepted contact/destination, transport attempt, automated sequence completion, Returned and Engaged. Performance groups/filters contact, destination, template and combinations, states explicit accepted-message denominators, and separates independent signals and late/missing tracking evidence. Missing ledger-only telemetry is an all-time completeness measure.

Pause, Resume, Exclude, Remove Exclusion, eligibility refresh, and real/historical previews preserve clocks/history/contact position. No Force Send, Skip Contact, Restart Cycle, or Manual Recovered action was added. Failures appear immediately in Needs Attention; accepted retry and latest accepted-message attribution-deadline rules are separate from engagement.

Personal follow-up resolves the recipient from the database, honors pause/exclusion/non-essential preferences, requires authorized POST/CSRF and reviewed confirmation, validates and escapes plain text, and records durable replay protection, immutable content, administrator, outcome and audit independently. It can be used while automation is waiting, sent or complete when otherwise permitted; it does not consume a contact, change timing, or override compliance.

## Validation evidence

Detailed subsystem reports:

- [Core engine and exact suite evidence](recovery-center-core-validation.md)
- [Settings, observability, tracking and attribution](recovery-center-observability-validation.md)
- [Email, browser, security and actual reset](recovery-center-presentation-validation.md)

| Validation | Result |
| --- | --- |
| Core CFML/TestBox: policy, ledger, classifier, sender, enrollment, integration, readiness, signup | 163/163 passed |
| Enrollment/readiness fixture rerun after removing test-only telemetry leakage | 52/52 passed |
| Final sender reporting-gap regression rerun | 23/23 passed |
| Existing authentication continuation/action paths | 19/19 passed |
| Existing destination regression | 15/15 passed |
| Full activity suite with fresh canonical account/vessel/waypoints | 11/11 passed |
| Settings/state/reset runtime | 15/15 passed |
| Observability/tracking/attribution/reporting runtime, including complete pagination | 29/29 passed |
| All automated/personal email rendering runtime | 17/17 passed |
| Final root Node core + email + existing admin diagnostic contracts | 39/39 passed |
| MCP Playwright six-view UI/security proof | 73/73 passed, zero console errors |
| Targeted MCP Playwright complete-history pagination follow-up | 33/33 passed, zero console errors |
| Actual one-time reset UI proof | 11/11 passed |
| Existing non-essential email compliance | 7/8 passed; one pre-existing golden-hash mismatch |

The final sender follow-up corrected missing reporting-gap propagation for malformed transport outcomes and a dry run with no observer. Its 23/23 rerun includes nonreplayable claims and explicit telemetry gaps; this is separate from the earlier complete 163-test execution. Pagination coverage walks 201 evaluation/message rows and history beyond the former 100-row limit, with bounded pages and no repeats.

Core scenarios include all three contacts at A and all three at C; first contact at each A/B/C/D; failed Contact #2 at A retrying at genuinely progressed B; no fourth contact or restart; predecessor requirements and gaps; enrollment substitution; future/corrupt clock rejection; independent retries; two concurrent workers with one accepted claim/send; uncertain acceptance holds; and final post-render activity/destination/preferences/state cancellation.

Timing/reset cases include exact boundaries, independent current settings, impact preview and stale review, atomic audit rollback, one T0, original evidence retention, later signups, empty-ledger requirement and replay. Security proof includes authorization, POST/CSRF, recipient manipulation, injection, personal blocks/replay, tampering/purpose/expiry/late signals, ownership/continuation, immutable snapshots and encoded bearer redaction.

Mail proof used injected non-delivering core transports and exactly scoped local MailHog messages. Before personal submission, the runtime probe verified `SAFE_LOCAL_MAIL=true`, `host.docker.internal:1025`, the MailHog banner and server configuration. Each browser proof's single captured fixture message was removed, without clearing unrelated mail.

Screenshots and sanitized JSON results are under:
`.codex-snapshots/20261003T165055Z-recovery-center/ui/`
including all six desktop views, `members-mobile.png`, `settings-reset-complete.png`, `results.json` and `local-reset-results.json`. Desktop/mobile screenshots were visually inspected; member mobile has no page-level horizontal overflow.

The one compliance failure is **pre-existing**: `buildSafeArrivalCaptainEmail` has snapshot/current SHA-256 `136dd35a82ff22688641581d1f7ed98f6ff9815cc84d0ecb16d0f525a84959ec`, while its existing fixture expects `6f3ec635846ee5d161e22f0bb22d3def8328f6a6332ec19afaf99ea8e6a48726`. All eight guarded operational email functions are byte-identical to the pre-edit snapshot. No unrelated renderer or golden fixture was altered.

## Cleanup, preserved scope, and limits

Disposable task accounts, vessel/route/draft/activity fixtures, fixture messages, claims and evaluations were cleaned up. Exact empty test-run IDs `4,5,6,7,8,9,13,14,15,20,21,22,31,32,33` were removed only after proving this task created them and checking source/status/zero child rows. Fixture observers were stubbed so the affected test constructors no longer leave these runs.

The real reset records and run30/two evaluations are retained. The unrelated older Safe Arrival development account was not repurposed or repaired. Private Stripe configuration, unrelated seven-day settings, production configuration and operational-email copy were not changed.

This proof is local. It does not establish production scheduling/deployment, real inbox delivery, provider bounce/webhook results, or complete tracking when optional telemetry fails. The legacy `runnerChecks` operation was excluded because it modifies private configuration. The older ledger Playwright script was updated but not rerun; its contact/concurrency behavior was exercised directly in CFML. MCPCFC's container browser launcher lacked Node/npx; browser proof used the MCP Playwright toolset directly, with no shell browser fallback.

## Exact implemented email copy


Current renderer: `api/v1/email.cfc` → `buildInactiveMemberRecoveryEmail`.

Exactly three automated contacts are independent of destination stages A–D. A contact selects the message copy; the freshly verified destination selects its CTA and destination-specific wording. The same destination can receive all three contacts. Time and contact acceptance never establish product progress.

Each message uses the existing shared greeting, layout, sign-off, and non-essential email compliance footer. CTA labels are shared across contact numbers:

| Destination | CTA label |
|---|---|
| A — Add Vessel | Continue Vessel Setup |
| B — Trip Planner | Start Planning a Trip |
| C — Saved/Planned Route | Continue Trip Planning |
| D — Draft Editor | Continue Your Float Plan |

## Contact #1

| Destination | Template ID | Subject | Body |
|---|---|---|---|
| A | `recovery.contact_1.destination_A.v1` | Add your boat to FloatPlanWizard | Your FloatPlanWizard account is ready. Add your vessel details once and FPW can reuse them when you plan future trips and create Float Plans. |
| B | `recovery.contact_1.destination_B.v1` | Ready to plan your first trip? | Your vessel is saved in FloatPlanWizard. When you're ready, use Trip Planner to map a route, add stops, and estimate your trip. |
| C | `recovery.contact_1.destination_C.v1` | Pick up your trip planning | You've started saving trip-planning work in FloatPlanWizard. You can come back anytime to continue the route and turn it into a trip when you're ready. |
| D | `recovery.contact_1.destination_D.v1` | Your Float Plan is waiting | You've started a Float Plan in FloatPlanWizard. Come back when you're ready to finish the details and share the trip with someone ashore. |

## Contact #2

| Destination | Template ID | Subject | Body |
|---|---|---|---|
| A | `recovery.contact_2.destination_A.v1` | Pick up your vessel setup | If adding your boat is still on your list, you can continue whenever you're ready. Save its details once so you can reuse them when planning trips and creating Float Plans. |
| B | `recovery.contact_2.destination_B.v1` | Still planning your next trip? | Your vessel details are already saved. When you're ready to take the next step, Trip Planner can help you map a route, add stops, and estimate the trip. |
| C | `recovery.contact_2.destination_C.v1` | Continue the route you started | Still working on your trip? Return to your saved planning work, review the route, and continue toward a Float Plan when you're ready. |
| D | `recovery.contact_2.destination_D.v1` | Ready to finish your Float Plan? | If your Float Plan still needs a few details, you can pick it up whenever you're ready. Review the trip and share it with someone ashore when it's complete. |

## Contact #3

| Destination | Template ID | Subject | Body |
|---|---|---|---|
| A | `recovery.contact_3.destination_A.v1` | One last reminder to add your boat | One last automated reminder from FloatPlanWizard: add your boat whenever you're ready, and reuse its details for future trips and Float Plans. |
| B | `recovery.contact_3.destination_B.v1` | One last reminder to plan your trip | One last automated reminder from FloatPlanWizard: your vessel details are saved, and Trip Planner is available whenever you're ready to map your next trip. |
| C | `recovery.contact_3.destination_C.v1` | One last trip-planning reminder | One last automated reminder from FloatPlanWizard: return to your saved planning work whenever you're ready to continue your route. |
| D | `recovery.contact_3.destination_D.v1` | One last Float Plan reminder | One last automated reminder from FloatPlanWizard: return to your Float Plan whenever you're ready to finish the details and share it with someone ashore. |

## Personal follow-up

Personal messages use `recovery.personal.v1` and message type `RECOVERY_PERSONAL`. The administrator supplies a plain-text subject (1–160 characters) and body (1–10,000 characters); HTML is escaped. Header control characters and NUL body characters are rejected. The shared sign-off and non-essential-email compliance footer are added by the real renderer. Personal messages never consume a numbered contact.

The server rechecks member state, pause/exclusion, and email preferences, resolves the recipient itself, and consumes a reviewed single-use submission identity before transport. The admin preview displays the rendered message with signed tokens redacted, navigation disabled, and image/network requests blocked.

## Interpretation

`SEND_ACCEPTED` describes transport acceptance, not provider delivery. Opens and clicks are signals that can be generated by mail clients or scanners. Returned and Engaged are independent durable observations; engagement after a recovery contact does not establish causation. Contact #3 completes the automated sequence without marking the member engaged.


## Final verification and exact file inventory

Final independent database check at **2026-10-03T17:53:27Z**: **2 original enrollment events, 2 member-state overlays, 1 retained run, 2 evaluations, 0 deliveries, 0 messages**. Later integrity checks found **0 duplicate contacts, 0 duplicate attempts, 0 invalid state/enrollment owners, and 0 orphan evaluations**. Message-link integrity was also zero. The original enrollment IDs/timestamps and reset T0/count/settings were rechecked after all tests.

Native scheduler evidence at **2026-10-03T17:50:07Z** confirms **Run Recover User — Paused**, using `cfschedule action=list` only. Four server tasks and zero application tasks were listed. The recovery task remains paused; production sending was not enabled.

Complete-history pagination now exposes every persisted member evaluation, message and activity row, every run evaluation, and settings audit through independently bounded pages. Browser proof **33/33** covers actual Next/Previous controls, explicit totals, distinct pages, invalid selector rejection, the global missing-telemetry label, and unchanged reset state. Its evidence is `ui/pagination-results.json`, `ui/member-history-pagination.png`, and `ui/native-scheduler-post-validation.json` inside the snapshot.

Temporary compile/maintenance/rollout helpers were archived under snapshot `removed-helpers/` and removed from runtime:

- `tests/recovery-center-compile.cfm`
- `tests/recovery-center-maintenance.cfm`
- `tests/recovery-center-local-rollout.cfm`
- `tests/support/RecoveryCenterLocalCohort.cfc`

The one-time reset Playwright script was archived during commit cleanup at `.codex-snapshots/20261003T202352Z-recovery-commit-cleanup/files/tests/recovery-center-local-reset.playwright.js` and removed from `tests/`, because its rollout helpers were intentionally removed after the completed reset. The ordinary Recovery Center browser test remains reusable.

Pre-commit Git scope after cleanup: **main...origin/main**, HEAD `b5308208b696e68b577edb88ec5f32beef747448`; **46 modified tracked files and 33 new files**. This inventory is prepared for the user-authorized commit; its resulting commit ID and clean working-tree verification are supplied in the completion message. No push was requested. `git diff --check` and `git diff --cached --check` passed. New files were additionally checked with `git diff --no-index --check /dev/null <path>` so untracked files were not omitted; normal difference exit status is distinct from whitespace errors. Only trailing blank-line normalization followed executable testing.

### Changed existing files (46)

- [Application.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/Application.cfc)
- [admin/includes/admin_reports_nav.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/admin/includes/admin_reports_nav.cfm)
- [admin/recovery-enrollment.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/admin/recovery-enrollment.cfm)
- [api/v1/InactiveMemberRecoveryService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/InactiveMemberRecoveryService.cfc)
- [api/v1/email.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/email.cfc)
- [app/scheduled/run-inactive-member-recovery.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/scheduled/run-inactive-member-recovery.cfm)
- [docs/inactive-member-recovery-basic-draft-validation.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-basic-draft-validation.md)
- [docs/inactive-member-recovery-classifier.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-classifier.md)
- [docs/inactive-member-recovery-destinations.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-destinations.md)
- [docs/inactive-member-recovery-enrollment.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-enrollment.md)
- [docs/inactive-member-recovery-final-validation.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-final-validation.md)
- [docs/inactive-member-recovery-ledger.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-ledger.md)
- [docs/inactive-member-recovery-production-enrollment.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-production-enrollment.md)
- [docs/inactive-member-recovery-readiness.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-readiness.md)
- [docs/inactive-member-recovery-sender.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-sender.md)
- [docs/inactive-member-recovery-threshold.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/inactive-member-recovery-threshold.md)
- [docs/member-activity-evidence.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/member-activity-evidence.md)
- [includes/InactiveMemberRecoveryClassifierService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryClassifierService.cfc)
- [includes/InactiveMemberRecoveryEnrollmentService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryEnrollmentService.cfc)
- [includes/InactiveMemberRecoveryLedgerService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryLedgerService.cfc)
- [includes/InactiveMemberRecoveryPolicy.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryPolicy.cfc)
- [includes/ProductEventService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/ProductEventService.cfc)
- [includes/require_auth.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/require_auth.cfm)
- [tests/inactive-member-recovery-classifier.test.mjs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-classifier.test.mjs)
- [tests/inactive-member-recovery-enrollment-integration-fixture.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-enrollment-integration-fixture.cfm)
- [tests/inactive-member-recovery-ledger-command.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-ledger-command.cfm)
- [tests/inactive-member-recovery-ledger.playwright.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-ledger.playwright.js)
- [tests/inactive-member-recovery-ledger.test.mjs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-ledger.test.mjs)
- [tests/inactive-member-recovery-policy.test.mjs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-policy.test.mjs)
- [tests/inactive-member-recovery-sender-command.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-sender-command.cfm)
- [tests/inactive-member-recovery-sender.test.mjs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-sender.test.mjs)
- [tests/specs/InactiveMemberRecoveryClassifierSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryClassifierSpec.cfc)
- [tests/specs/InactiveMemberRecoveryEmailTemplateSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryEmailTemplateSpec.cfc)
- [tests/specs/InactiveMemberRecoveryEnrollmentIntegrationSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryEnrollmentIntegrationSpec.cfc)
- [tests/specs/InactiveMemberRecoveryEnrollmentSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryEnrollmentSpec.cfc)
- [tests/specs/InactiveMemberRecoveryLedgerSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryLedgerSpec.cfc)
- [tests/specs/InactiveMemberRecoveryPolicySpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryPolicySpec.cfc)
- [tests/specs/InactiveMemberRecoveryReadinessSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryReadinessSpec.cfc)
- [tests/specs/InactiveMemberRecoverySenderSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoverySenderSpec.cfc)
- [tests/support/RecoveryEnrollmentFixture.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/support/RecoveryEnrollmentFixture.cfc)
- [tests/support/RecoveryEnrollmentIntegrationFixture.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/support/RecoveryEnrollmentIntegrationFixture.cfc)
- [tests/support/RecoveryOrchestrationEmailStub.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/support/RecoveryOrchestrationEmailStub.cfc)
- [tests/support/RecoveryOrchestrationFixture.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/support/RecoveryOrchestrationFixture.cfc)
- [tests/support/RecoveryOrchestrationLedgerStub.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/support/RecoveryOrchestrationLedgerStub.cfc)
- [tests/support/RecoveryOrchestrationRaceClassifier.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/support/RecoveryOrchestrationRaceClassifier.cfc)
- [tests/support/RecoveryReadinessFixture.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/support/RecoveryReadinessFixture.cfc)

### New files (33)

- [admin/recovery-center-data.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/admin/recovery-center-data.cfm)
- [admin/recovery-center.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/admin/recovery-center.cfm)
- [api/v1/AdminRecoveryCenterService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/AdminRecoveryCenterService.cfc)
- [app/recovery-click.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/recovery-click.cfm)
- [app/recovery-open.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/recovery-open.cfm)
- [assets/css/admin-recovery-center.css](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/css/admin-recovery-center.css)
- [assets/js/admin-recovery-center.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/admin-recovery-center.js)
- [database/migrations/20261003_001_recovery_center.down.sql](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/database/migrations/20261003_001_recovery_center.down.sql)
- [database/migrations/20261003_001_recovery_center.preflight.sql](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/database/migrations/20261003_001_recovery_center.preflight.sql)
- [database/migrations/20261003_001_recovery_center.up.sql](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/database/migrations/20261003_001_recovery_center.up.sql)
- [database/migrations/20261003_001_recovery_center.verify.sql](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/database/migrations/20261003_001_recovery_center.verify.sql)
- [docs/recovery-center-completion-report.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/recovery-center-completion-report.md)
- [docs/recovery-center-core-validation.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/recovery-center-core-validation.md)
- [docs/recovery-center-email-copy.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/recovery-center-email-copy.md)
- [docs/recovery-center-observability-validation.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/recovery-center-observability-validation.md)
- [docs/recovery-center-presentation-validation.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/recovery-center-presentation-validation.md)
- [docs/recovery-center.md](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/recovery-center.md)
- [includes/InactiveMemberRecoveryAttributionService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryAttributionService.cfc)
- [includes/InactiveMemberRecoveryObservabilityService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryObservabilityService.cfc)
- [includes/InactiveMemberRecoverySettingsService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoverySettingsService.cfc)
- [includes/InactiveMemberRecoveryStateService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryStateService.cfc)
- [includes/InactiveMemberRecoveryTrackingService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryTrackingService.cfc)
- [tests/inactive-member-recovery-core-runner.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-core-runner.cfm)
- [tests/inactive-member-recovery-observability-runner.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-observability-runner.cfm)
- [tests/inactive-member-recovery-settings-runner.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-settings-runner.cfm)
- [tests/recovery-center-activity-runner.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/recovery-center-activity-runner.cfm)
- [tests/recovery-center-diagnostic.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/recovery-center-diagnostic.cfm)
- [tests/recovery-center-pagination.playwright.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/recovery-center-pagination.playwright.js)
- [tests/recovery-center.playwright.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/recovery-center.playwright.js)
- [tests/recovery-center.spec.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/recovery-center.spec.js)
- [tests/specs/InactiveMemberRecoveryObservabilitySpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryObservabilitySpec.cfc)
- [tests/specs/InactiveMemberRecoverySettingsSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoverySettingsSpec.cfc)
- [tests/support/RecoveryCoreObservationStub.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/support/RecoveryCoreObservationStub.cfc)

### Additional inspected sources left unchanged

The changed implementation/test/documentation files above were inspected within their owning subsystem. Additional explicitly identified unchanged source and test paths follow; this list does not imply that unchanged runtime behavior was exhaustively retested.

- [api/v1/AdminAuditService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/AdminAuditService.cfc)
- [api/v1/AdminAuthorizationService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/AdminAuthorizationService.cfc)
- [api/v1/AdminRecoveryEnrollmentService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/AdminRecoveryEnrollmentService.cfc)
- [includes/AuthContinuationService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/AuthContinuationService.cfc)
- [includes/InactiveMemberRecoveryActionPathService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryActionPathService.cfc)
- [includes/InactiveMemberRecoveryCoverageService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryCoverageService.cfc)
- [includes/InactiveMemberRecoveryDestinationService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryDestinationService.cfc)
- [testbox/system/Expectation.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/testbox/system/Expectation.cfc)
- [tests/admin-email-diagnostic.spec.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/admin-email-diagnostic.spec.js)
- [tests/admin-email-diagnostic.test.mjs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/admin-email-diagnostic.test.mjs)
- [tests/admin-scheduled-tasks-runner.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/admin-scheduled-tasks-runner.cfm)
- [tests/auth-continuation-runner.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/auth-continuation-runner.cfm)
- [tests/auth-mail-safety-probe.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/auth-mail-safety-probe.cfm)
- [tests/fixtures/operational-email-function-sha256.json](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/fixtures/operational-email-function-sha256.json)
- [tests/inactive-member-recovery-destination-runner.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-destination-runner.cfm)
- [tests/inactive-member-recovery-destination.spec.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-destination.spec.js)
- [tests/inactive-member-recovery-email-template-runner.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-email-template-runner.cfm)
- [tests/inactive-member-recovery-email-template.test.mjs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-email-template.test.mjs)
- [tests/inactive-member-recovery-enrollment-integration.playwright.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/inactive-member-recovery-enrollment-integration.playwright.js)
- [tests/member-activity-runner.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/member-activity-runner.cfm)
- [tests/non-essential-email-compliance-runner.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/non-essential-email-compliance-runner.cfm)
- [tests/specs/AuthContinuationSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/AuthContinuationSpec.cfc)
- [tests/specs/InactiveMemberRecoveryActionPathSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryActionPathSpec.cfc)
- [tests/specs/InactiveMemberRecoveryDestinationSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoveryDestinationSpec.cfc)
- [tests/specs/InactiveMemberRecoverySignupSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/InactiveMemberRecoverySignupSpec.cfc)
- [tests/specs/MemberActivityEvidenceSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/MemberActivityEvidenceSpec.cfc)
- [tests/specs/NonEssentialEmailComplianceSpec.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/NonEssentialEmailComplianceSpec.cfc)
- [tests/support/MemberActivityHarness.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/support/MemberActivityHarness.cfc)

The user-supplied task attachment and pre-edit snapshot/manifest were also read. Temporary helpers and their archives are identified above. Detailed function-level evidence and test invocations appear in the three linked subsystem reports.

### Verified recovery indexes

| Table | Index | Columns | Unique |
| --- | --- | --- | --- |
| `inactive_member_recovery_deliveries` | `ix_inactive_recovery_member_sent` | `user_id,sent_at_utc` | No |
| `inactive_member_recovery_deliveries` | `ix_inactive_recovery_status` | `status,updated_at_utc` | No |
| `inactive_member_recovery_deliveries` | `ix_recovery_member_contact` | `user_id,recovery_enrollment_event_id,contact_number` | No |
| `inactive_member_recovery_deliveries` | `PRIMARY` | `id` | Yes |
| `inactive_member_recovery_deliveries` | `uq_recovery_enrollment_contact` | `recovery_enrollment_event_id,contact_number` | Yes |
| `inactive_member_recovery_evaluations` | `ix_recovery_evaluation_decision` | `initial_decision,evaluated_at_utc` | No |
| `inactive_member_recovery_evaluations` | `ix_recovery_evaluation_member` | `user_id,evaluated_at_utc,id` | No |
| `inactive_member_recovery_evaluations` | `ix_recovery_evaluation_run` | `run_id,id` | No |
| `inactive_member_recovery_evaluations` | `PRIMARY` | `id` | Yes |
| `inactive_member_recovery_member_state` | `fk_recovery_state_enrollment` | `recovery_enrollment_event_id` | No |
| `inactive_member_recovery_member_state` | `PRIMARY` | `user_id` | Yes |
| `inactive_member_recovery_messages` | `fk_recovery_message_evaluation` | `evaluation_id` | No |
| `inactive_member_recovery_messages` | `fk_recovery_message_run` | `run_id` | No |
| `inactive_member_recovery_messages` | `ix_recovery_message_member` | `user_id,accepted_at_utc,id` | No |
| `inactive_member_recovery_messages` | `ix_recovery_message_performance` | `message_kind,contact_number,destination_stage,accepted_at_utc` | No |
| `inactive_member_recovery_messages` | `ix_recovery_message_reconciliation` | `status,attribution_deadline_utc,id` | No |
| `inactive_member_recovery_messages` | `PRIMARY` | `id` | Yes |
| `inactive_member_recovery_messages` | `uq_recovery_message_attempt` | `delivery_id,transport_attempt_number` | Yes |
| `inactive_member_recovery_messages` | `uq_recovery_message_public` | `public_id` | Yes |
| `inactive_member_recovery_messages` | `uq_recovery_message_submission` | `submission_identity` | Yes |
| `inactive_member_recovery_runs` | `ix_recovery_runs_time` | `started_at_utc,id` | No |
| `inactive_member_recovery_runs` | `PRIMARY` | `id` | Yes |
| `inactive_member_recovery_runs` | `uq_recovery_run_uuid` | `run_uuid` | Yes |
| `inactive_member_recovery_settings` | `PRIMARY` | `id` | Yes |

## MariaDB migration correction — 2026-10-03

The user reported production MariaDB error 1064 at `DROP CHECK chk_inactive_recovery_stage` and confirmed MySQL Workbench stopped on that error. The supplied migration used MySQL-specific CHECK removal syntax. That failed ALTER did not execute; subsequent statements should not have executed given the reported stop-on-error behavior. The target schema/version has not been independently inspected.

**Best Fix:** use `DROP CONSTRAINT` for the old CHECK in the upgrade and both new CHECKs in the rollback. The same syntax is documented for MariaDB and MySQL 8.0.19+. Sources: [MariaDB ALTER TABLE](https://mariadb.com/docs/server/reference/sql-statements/data-definition/alter/alter-table), [MySQL ALTER TABLE](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html).

**Safest Fix rollout:** keep processing stopped, retain the pre-migration production backup, run the updated read-only preflight on the selected production database, and review its results before a full retry with the corrected script in a stop-on-error client. The expected retry state is zero deliveries; the original recovery_stage column, stage CHECK and unique index present; new contact/enrollment columns absent; all five supporting tables absent; and no leftover migration guard routine. If any differs, stop and inspect the partial state. Do not delete history or bypass the mismatch with IF NOT EXISTS. A statement-level syntax failure does not by itself prove what other statements a client executed.

The executable upgrade guard now refuses pre-existing supporting tables before changing the ledger. Preflight reports server version, supporting tables, guard routines and ledger constraint names. Verification includes the actual CHECK definitions. The migration remains dependent on stopping at the first SQL error; continuing after a failed guard is unsupported.

Exact follow-up files changed:
- `database/migrations/20261003_001_recovery_center.up.sql`
- `database/migrations/20261003_001_recovery_center.down.sql`
- `database/migrations/20261003_001_recovery_center.preflight.sql`
- `database/migrations/20261003_001_recovery_center.verify.sql`
- `docs/recovery-center.md`
- `docs/recovery-center-completion-report.md`

Pre-edit snapshot: `.codex-snapshots/20261003T185157Z-recovery-mariadb-fix/`; seven files were copied and checksum-verified (including the unchanged ledger test). Manifest SHA-256: `44babc7e13641ddc940b32a004a2a3d733024758c81d406e00e390ff7132c11b`.

Validation: existing ledger Node suite **7/7 passed**. A guarded disposable schema in local `cfdev-mysql`, MySQL **8.0.43**, passed **9/9 checks** at **2026-10-03T18:56:15Z**: runtime identity, preflight execution, complete corrected upgrade, complete verify script, all five supporting tables, ledger columns/constraints, complete empty-history rollback, restored old stage CHECK/index, and refusal of partial supporting tables before ALTER. The scratch database was removed. The first local test caught an editing-induced delimiter typo, which was corrected before the final nine-check pass. Evidence and executable scratch harness: `runtime-results.json` and `runtime-test.cjs` inside this snapshot. This is MySQL runtime proof plus MariaDB documentation verification, not a MariaDB runtime or production execution claim.

No application engine, email copy, recovery history, reset or live sending was changed by this follow-up. The local FPW database still had zero deliveries/messages and reset count2 before testing; the test operated solely in its new disposable schema. Production was not accessed or mutated by the assistant.


## Commit cleanup — 2026-10-03

The obsolete one-time reset script was archived at `.codex-snapshots/20261003T202352Z-recovery-commit-cleanup/files/tests/recovery-center-local-reset.playwright.js` and removed from the working source tree. It depended on previously removed rollout helpers and was not a repeatable test. Historical reset **11/11** evidence is retained. Reusable test runners, diagnostics, browser tests, migration fixes and all Recovery Center implementation changes remain in scope.

The two updated reports and archived script have verified pre-edit copies in `.codex-snapshots/20261003T202352Z-recovery-commit-cleanup/`. Manifest SHA-256: `83aad0ba532119ac5c7cd33d37a1beabe71cc514915c29527b43546b5aaa7e15`. Existing snapshots, database backups, logs and browser artifacts remain outside the commit under existing ignore rules; no private configuration was read or staged.
