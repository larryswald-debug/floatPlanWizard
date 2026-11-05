# FPW Founding Beta Program — Measurement Audit
## BETA-01 · Phase 1 · November 5, 2026

**Scope:** Read-only discovery of the development checkout and local schema, with only this document and `progress.md` authorized for creation. No implementation, migration, production execution, live notification, enrollment, or deployment is authorized by this audit.

**Source baseline:** `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw`, Git HEAD `6c1051ee92e60ac613523264626c24b946e59831`, plus the pre-existing working-tree changes. The audit includes the current, uncommitted Great Loop waypoint work; it does not imply those changes are deployed. Eighteen pre-existing pending files were hashed before documentation creation. Both documentation targets were absent. No existing file needs replacement or rollback for this documentation-only assignment.

**Targets:** Soft launch March 21, 2027; hard launch May 31, 2027. Progress belongs exclusively in [the Founding Beta register](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/beta-program/progress.md), separate from First 90 Days.

## 1. Executive summary

FPW already has the core collection needed to avoid building another analytics platform:

- Required, transactional `member_api` product events for 17 saved-activity names.
- Durable account-creation evidence, successful sharing receipts, and tracked share attempts/outcomes.
- Existing promotional access administration with redemption, expiration, revocation, overlap checks, and admin audit.
- A conservative, SELECT-only Day 40 exporter and offline reporting engine.
- Monitoring transitions, arrival revisions/notices/recipient attempts, departure reminder receipts, and Companion processing receipts.
- Existing Contact, Support Request, and Suggest a Feature forms.

The principal missing capability is an **official beta participation record**, independent of membership entitlement and recovery enrollment. Existing promotions cannot prove invitation acceptance, consent to beta participation, recruitment source, or withdrawal. Day 40 does not currently calculate enrollment-relative activation or seven-day return. Feedback is emailed rather than stored as an issue with an authenticated tester identity and triage state. Failures are observable in several separate systems, but there is no complete journey-wide attempt denominator or outcome report.

The 12-metric scorecard below has **5 fully supported collection contracts, 6 partially supported metrics, and 1 unsupported metric**. This is a count of the named scorecard categories, not a numerical analytics-coverage percentage and not certification of current production deployment. Beta outcomes remain **Not measured**.

**Best Fix — recommended for the next approval:** Add a small explicit beta participation register; reuse existing promotion services for access; add a separate beta reporting mode around Day 40 evidence rules; extend the existing support form with durable feedback storage/admin triage; record selected explicit technical failures using the existing event service. Do not alter historical Day 40 definitions, billing, or monitoring behavior.

**Safest Fix — meaningfully narrower:** For a small first cohort, use an access-controlled, versioned roster and feedback register outside the repository/web root, recording internal IDs and explicit acceptance/withdrawal evidence, with owner-attested source references. Reuse current promotion screens and existing support email. Build only the beta report adapter and targeted failure visibility. This avoids initial cohort/feedback schema changes but requires reliable manual administration, cannot provide self-service participation history, and is weaker against missed/late entries. It requires an explicit operating-process decision; promo redemption alone is insufficient in either option.

No new third-party analytics service is necessary. No separate beta feedback form is necessary. Existing reports and admin patterns are reusable, but their recovery-specific cohort/denominators must not be relabeled as beta metrics.

## 2. Evidence scope and existing instrumentation inventory

### Evidence levels and validation boundaries

| Evidence | What was inspected or observed | What it does not prove |
|---|---|---|
| Current source | MCPCFC reads/searches of CFML, JavaScript, reporting modules, tests, migrations and documentation, anchored in section 13 | Deployed production files/configuration are identical |
| Current local database | MCPCFC SELECT-only schema/aggregate queries; datasource resolved to database `FPW`, MySQL `8.0.43` | Production MariaDB state or beta-member outcomes |
| Current local event evidence | Aggregate rows for signup, login, required member saves, Premium completion and paired share outcomes; member-save correlation IDs are often absent | Historical coverage completeness or real-member usage; local data includes development/test activity |
| Current local reliability evidence | Four arrival-delivery rows in `SUBMITTED`; four scheduler-last-run identities, latest observed timestamp `2026-11-05 15:01:00` UTC | Inbox delivery, all scheduled runs, or production scheduler status |
| Current automated evidence | 59/59 existing Node checks passed: 52 Day 40 tests and 7 member-activity source-contract tests | A new CF integration, end-to-end sharing, SMTP, or production test |
| Current browser evidence | MCP Playwright opened the existing anonymous local feedback page without submitting it; inspected its POST target/fields; no attachment input | Successful mail delivery, authenticated identity binding, or admin triage |
| Historical documented evidence | Day 40 production capture at `2026-09-29T17:23:22.527189Z`; source completeness/validation documented in `docs/validation.md`; prior member-activity and auth validation documents inspected | A fresh November 5 production capture or rerun of those historical integration suites |
| Owner-reported evidence | Brief reports successful recent live-trip email sending and resolved prior scheduler/Cloudflare incident | A quantitative delivery SLA or fresh independent incident verification |

No real member names, email addresses, trip coordinates, tokens, message bodies, or payment details were exported into these new documents. Existing historical reports containing member data were not copied into beta artifacts. Private Stripe and scheduler configuration contents were not read.

### Collection systems

| System | Source of truth and important fields | Use and limitation |
|---|---|---|
| Durable product events | `product_events`: `user_id,event_name,entity_type,entity_id,event_source,occurred_at_utc,created_at_utc,idempotency_key,request_correlation_id,metadata_json`; E01 | Source/entity/metadata allowlists; DB UTC timestamps; idempotent insertion. Generic `recordEvent` returns failure rather than requiring the business command to fail. The required-activity wrapper makes selected saves fail closed. |
| Account creation | `users.userId` plus required `sign_up` event and bound recovery coverage marker; E02 | Account + required evidence commit together. Account terms/privacy disclosure acceptance is not beta consent. Legacy `users.created` is a raw historical clock in Day 40. |
| Saved planning objects | `vessels,waypoints,user_routes,user_route_legs,route_instances,route_instance_legs,floatplans`; E03–E06 | Owned current state supports readiness; required events date actual new saves. Read-only views, no-op saves, and admin CRUD do not become member activity. |
| Sharing | `basic_review_send_receipts,premium_send_receipts`, completed-share product events and paired `recovery_share_*`; E07–E09 | Positive accepted-send evidence; uncertainty survives rollback. It is not recipient inbox/access proof. |
| Entitlements/promotions | `fpw_promo_codes,fpw_promo_redemptions,member_entitlements,fpw_admin_audit_log`; E10–E12 | Access issuance, redemption, effective access and revocation. No typed beta cohort or participation consent. |
| Operational lifecycle | `floatplans,route_instances,route_instance_leg_progress,floatplan_monitoring,floatplan_monitor_events,floatplan_events,floatplan_companion_events`; E15–E17 | Multiple complementary authorities. Canonical timeline event writes can be best effort; lifecycle state is stronger than browser event names. |
| Notification delivery | `departure_reminder_deliveries,floatplan_alert_history,fpw_arrival_watches,fpw_arrival_revisions,fpw_arrival_events,fpw_arrival_notices,fpw_arrival_deliveries,fpw_arrival_attempts`; E18–E21 | Strong arrival per-recipient/attempt evidence; legacy alert history is less granular. No general inbox-delivered record found. |
| Scheduled execution | `fpw_scheduled_task_last_run` and native scheduler list; E22 | Latest observed start only. Does not retain a run history, finish/result, duration, or job-to-notification run ID. |
| Retention | `scripts/retention/{export-sql,evidence,baseline,route-uses,cli}.mjs`; E13–E14 | 14-source SELECT export, strict completeness checks, fixed UTC window, conservative lineage normalization. No beta enrollment/seven-day mode. |
| Feedback | `app/contact.cfm` → `api/v1/contactUs.cfc.handle`; E23 | Email submission with category/subject/description; no durable feedback table/triage history found. |
| Errors/security | `Application.cfc.onError`, named CF logs, API error responses, `auth_rate_counters`, admin audit; E24–E25 | Useful diagnostics, uneven failure recording and correlation; not a comprehensive failure-rate denominator. |
| Browser analytics | `includes/analytics_ga4.cfm`, `analytics_clarity.cfm`, dashboard/auth JS; E26 | GA4 and Clarity have production-host/path gates. **Plausible is also already present** in the GA include and is injected for non-preview pages without those same gates. Existing browser signals are supplemental, not authoritative member receipts. |

### Existing product-event and browser contracts

| Family | Existing names / payload | Actual firing boundary |
|---|---|---|
| Registration/access starter | `sign_up`; `complimentary_credit_granted` | Signup: required event in account transaction. Complimentary-credit event is best effort after the underlying credit grant; use the credit/entitlement record as authority. Signup metadata allows method/tier/onboarding, constrained CTA attribution, and disclosure revision hashes. |
| Authentication | `login` from `password_auth`, metadata `auth_method=password` | Successful password authentication, best-effort product event. Does not prove meaningful planning or another-day activity when an existing session is reused. |
| Required member saves — all 17 | `vessel_created,vessel_updated,shore_contact_created,shore_contact_updated,operator_created,operator_updated,passenger_created,passenger_updated,waypoint_created,waypoint_updated,user_route_created,user_route_updated,route_created,route_updated,route_segment_updated,float_plan_created,float_plan_updated` | `recordRequiredMemberActivity` inside owned mutation transactions. Real entity ID, source `member_api`, private operation UUID. Metadata is empty except reused vessel/contact creation source. Required event failure rolls back the save; unchanged values do not generate another activity. |
| Share intent/completion | `premium_send_attempted,premium_send_completed,premium_send_denied_no_access,basic_send_completed,same_plan_retry_resolved` | Attempt/denial/replay are not success. Premium completion follows mail calls inside the send transaction; Basic operational completion is best effort. Basic Review receipt and completed event commit together after accepted submission. Premium authority metadata is a fixed allowlist, not billing details. |
| Durable share attempt coverage | `recovery_share_started,recovery_share_succeeded,recovery_share_failed` | Server-generated correlation UUID links start and terminal. Started commits before the send transaction; accepted submission or proved pre-submission failure permits terminal evidence. Uncertain transport remains unresolved. These events are not restricted to recovery-email recipients. |
| Commerce intent and grants | `buy_one_trip_clicked,one_trip_checkout_created,one_trip_credit_granted,monthly_selected,annual_selected` | Billing API choice/checkout and Stripe entitlement write paths. Intent/checkout creation does not prove an entitlement or beta acceptance. No payment data is needed for beta reporting. |
| Recovery-only collection | `recovery_coverage_started,inactive_member_recovery_enrolled,recovery_evaluated,recovery_message_{send_accepted,send_failed,outcome_unknown,canceled},recovery_{opened,clicked,returned,engaged},recovery_authenticated_return,recovery_{paused,resumed,excluded,exclusion_removed,schedule_reset}` | Existing recovery services write typed events and bounded metadata. Recovery enrollment, returned/engaged attribution and opt-out state are not beta enrollment or general seven-day retention. Reuse mechanisms, preserve meanings. |
| Browser journey | `signup_start,sign_up,auth_modal_open,auth_modal_cancelled,auth_continue_submit,auth_account_created,auth_login_success,auth_failure,auth_continuation_success,preview_requested,route_created,float_plan_created,active_cruise_started,follow_page_shared,check_in_submitted`; pricing/checkout and public-CTA events | Browser callbacks at specific screens. Not durable universal coverage: script blocking, navigation, alternate clients and session behavior matter. `follow_page_shared` fires when the share dialog/link is prepared, before copying/sending. `active_cruise_started` in send callbacks does not by itself prove actual departure. |
| Existing public analytics | GA4, Microsoft Clarity, Plausible | Current source confirms integrations, not dashboard ingestion/retention/property settings. Local browser rendered Plausible; GA4/Clarity script hosts were absent as expected from their gates. No additional analytics platform is proposed. |

`ProductEventService.getAggregateCounts` counts **event rows per day**, not unique eligible testers; its end-boundary comparison is inclusive. It cannot be used unmodified as the beta KPI. Day 40 uses half-open `[W,T)` boundaries and member sets.

## 3. Authoritative event coverage matrix

“Fully supported” below means the stated canonical collection contract is implemented and supported by inspected source and available evidence. It does not certify complete historical coverage or current production parity. Cross-client lifecycle histories and ambiguous clocks remain partial.

| Milestone | Existing event/table | Source file / evidence | Success boundary | Coverage | Gap | Required action |
|---|---|---|---|---|---|---|
| Member registered | `users`, `sign_up` | E02: `join.createAccount`, coverage service | User insert + required signup evidence commit | Fully supported | Old raw account clocks; admin-created/legacy users need separate provenance | Reuse canonical signup; existing accounts enroll separately |
| Beta participation accepted | No typed beta record/event found | Targeted source/schema search; section 4 | Explicit authenticated acceptance or audited owner-recorded acceptance | Not supported | No invitation/consent/enrollment/withdrawal contract | P0-1 |
| Beta promotion activated | `fpw_promo_redemptions`, `member_entitlements`, admin audit | E10–E12 | Redeemed/granted entitlement with applicable current access rules | Fully supported for entitlement | Does not establish beta membership; Stripe checkout is not activation | Join to beta register; reuse admin grants |
| Vessel ready | `vessels`, `vessel_created/updated` | E03; required transaction | Successful owned vessel save, or current owned saved vessel at enrollment | Fully supported for saved-vessel definition | No independent navigational-quality certification or separate tester confirmation | Reuse without forcing another save |
| Waypoint saved | `waypoints`, `waypoint_created/updated` | E04; library/leg endpoints call `persistWaypoint` | Owned persisted save + activity commit; duplicate reuse emits no creation | Fully supported | Day 40 exporter does not include waypoint activity; older dates may be missing | Extend beta export only |
| Route started — planning | Browser preview/route callbacks; persisted named/generated routes | E05, E27 | No single durable “planning workflow began” boundary | Partially supported | Empty named route, planner open, preview and trip departure are distinct | Define beta start action; use saved-route proxy only with clear label until P1 |
| Route saved | `user_routes,user_route_legs,route_instances,route_instance_legs`; required create/update | E05 | Committed owned named route or generated instance/legs | Fully supported for persistence | Zero-leg named creation is not substantive route use; updates may be rename-only | Reuse, retain Day 40 substantive-use rules |
| Float plan created | `floatplans`, `float_plan_created` | E06 | New Draft and required event commit; generated Draft reuse emits no create | Fully supported | A saved Draft is not necessarily ready/shared/active | Separate readiness, creation and share |
| Float plan shared | Basic/Premium receipts; completed events; paired share outcomes | E07–E09 | Validated accepted application send to saved selected contact(s) | Partially supported for beta KPI | No enrolled cohort/time anchor; unresolved handoffs; no inbox/access proof; self-test distinction not recorded | P0-1/2; use source-specific success and unknowns |
| Active Cruise started | Monitoring/lifecycle state, route progress, canonical events | E15–E17 | Successful operational start/first-leg transition, not just plan sent/ACTIVE | Partially supported | Browser name conflates send/activation; canonical events can be best effort; historical clock provenance | Reuse state/accepted operation evidence; P1 measurement normalization |
| Check-in completed | `floatplan_monitor_events.CHECKIN_RECEIVED`, plan/timeline state; Companion `PROCESSED` receipt | E15–E17 | Accepted owned check-in and committed monitoring update; Companion must be processed | Partially supported | Rejected attempts before receipt may be absent; canonical supplementary writer can fail; no universal attempts denominator | P0 explicit failure visibility; P1 attempt reconciliation |
| Trip completed | CLOSED plan + compatible completed route contract, canonical close event | E16–E17, Day 40 | Successful close/completion state, not merely intermediate leg completion | Partially supported | Canonical close event after lifecycle transaction can fail; old completion clocks not always usable | Reuse completed-trip contract; retain unknown time and add future coverage proof separately |
| Member returned | Required saved activity, accepted operations; login/recovery return are different | E01, E13–E17 | Qualifying activity on another calendar day | Partially supported | No beta enrollment-relative seven-day calculation; retained session read-only use not a saved event | P1 seven-day model with explicit timezone/maturity |

### Proposed primary KPI contract for BETA-02 approval

Use the existing **accepted application send** definition already used by Day 40, with an explicit beta enrollment/time filter. Do not rename this “delivered.”

1. Denominator: distinct eligible enrolled `user_id` values in the chosen cohort at report cutoff; acceptance must be documented and effective. Invite-only, rejected, test-fixture and withdrawn-as-of-cutoff records are separately reported. Premium access is an entitlement dimension, not an automatic requirement for beta membership: Basic sharing already exists.
2. Numerator: denominator members with at least one qualifying share during an enrolled participation interval and before cutoff. Qualify through an existing supported share path, ownership and product validation; link opening, PDF generation, button clicks, saved contact selection, and sharing-dialog display do not count.
3. Accept positive evidence from a valid `SENT` Basic Review receipt, committed Premium receipt with `recipient_count>0`, source-valid completed event, or validated start + single succeeded share outcome. Deduplicate evidence by member/plan/operation; receipts and events for the same operation are corroboration, not extra testers.
4. `recovery_share_succeeded` can mean **at least one** contact was accepted even if a later contact failed and the larger operation rolled back. This supports an “at least one shore contact” KPI but must remain labeled partial-recipient success in reliability reporting. It does not prove all contacts received the plan.
5. Basic Review can count while the plan remains DRAFT; monitoring is not a prerequisite. Route-less Basic operational sharing has its existing required-details validation. Do not impose a new trip distance, route type, paid tier, or duplicate creation requirement.
6. Pre-enrollment shares establish baseline readiness/history only; they do not become beta-period activation. A legitimate new share of an existing plan can qualify when a fresh accepted-send operation is evidenced. An idempotent replay of a pre-enrollment receipt cannot qualify as a new share.
7. First-share latency is earliest qualifying accepted-send UTC minus enrollment UTC. Missing/ambiguous timestamps produce unknown latency, not zero. Report count with dated evidence alongside the KPI.
8. No accepted evidence means **no verified qualifying share found**, not technical failure or proved inactivity. Show unresolved attempts and known collection gaps next to the observed activation percentage.
9. Proposed denominator policy: show current eligible cohort and an immutable enrollment-cohort view with withdrawals explicitly separated, so withdrawing members cannot silently improve historical results.
10. Owner approval is still needed for self-addressed test shares versus genuine selected shore contacts, exact eligibility/exclusion rules, and the beta seven-day calendar definition. The application does not currently certify a human shore contact read the message.

## 4. Beta enrollment and promotional membership assessment

| Required capability | Existing support | Conclusion |
|---|---|---|
| Identify invited members | No dedicated beta invitation table/status or event found | Not supported as a reliable beta metric |
| Record beta invitation acceptance | Signup terms/privacy consent only | Not supported; account consent and promo redemption are different |
| Distinguish beta testers from ordinary promo members | Unique internal promotion ID/name can distinguish a grant campaign | Partial; misses accepted testers who already have Premium and cannot establish consent |
| Record which promotion issued access | `promo_code_id`, linked redemption/entitlement, creator and audit | Supported |
| Identify redemption time | `attempted_at_utc,redeemed_at_utc,result,error_code` | Supported; `checkout_created` is not redeemed access |
| Identify complimentary Premium expiration | `starts_at_utc,expires_at_utc,status,revoked_at_utc`; existing effective-access service | Supported |
| Track participation status | Entitlement status exists, beta status does not | Not supported for participation |
| Identify withdrawn testers | Access revocation is recorded | Not supported for withdrawal; do not revoke paid access to represent beta withdrawal |
| Preserve billing/entitlement rules | Existing admin grant service, overlap validation and audit | Reuse unchanged |
| Identify already-eligible Premium members | `MemberEntitlementService.getCurrentAccess`; current valid entitlement/source rules | Supported; avoid unnecessary duplicate grants or trial/Stripe flow |

**Smallest reliable official-cohort method:** Keep participation identity independent of benefit identity. Under Best Fix, add one small beta participation table keyed by program/invitation and internal tester identifier, with a nullable member link until signup. Store invitation/acceptance/withdrawal UTC times, recruitment source, versioned acceptance evidence, participation status and an optional promotion/entitlement reference. Reuse existing admin audit for changes. Resolve the precise uniqueness/re-enrollment rules during design; do not silently overwrite a prior withdrawal/acceptance.

Do not put invite email addresses or tokens in analytic events. For existing members, use `user_id`. For pre-signup invitees, use an opaque internal invitation ID; keep any delivery address/token in the existing private invitation operating process or a separately approved delivery mechanism. This audit does not authorize an invitation sender.

Use a dedicated existing `admin_grant` promotion and current fixed-duration/fixed-expiration complimentary Premium tools when access is needed. Do not use the existing `founder_lifetime` type merely because the program is called “Founding Beta”; lifetime access and Stripe trial/billing behavior are separate product decisions.

## 5. Day 40 retention reuse assessment

The established definition is `Day40RetentionBaseline-v1` in `baseline.mjs:5`. Preserve it.

| Requirement | Existing behavior | Reuse decision |
|---|---|---|
| Beta cohort filtering | Snapshot-bound real/test review and admin exclusions, not participation enrollment | Small additive beta adapter; do not misuse the “all other users are tests” flag to mean non-beta |
| Enrollment date | Recovery enrollment has its own meaning; account creation is separate | New beta source required; not reconstructible from promo/account dates |
| First meaningful planning activity | Validated events + conservative route-use normalization; zero-leg route is not legitimate use | Reuse rules; label earliest evidenced activity, not true historical first |
| First successful share | Positive receipt/event reconciliation already implemented | Reuse unchanged evidence predicates, add enrollment interval and first-date calculation |
| Seven-day return | Thirty-day activity and lifetime/post-completion return; no seven-day enrollment model | Add beta-specific calculation/version; preserve existing definitions |
| Repeat route/trip use | Normalizes saved/generated routes, source copies, daily Drafts and ordered separate use | Reuse; keep unresolved lineage/clock history unknown |
| Reporting windows | Fixed database UTC `T`; `W=T-30d`; half-open `[W,T)` | Preserve Day 40; beta report adds its own explicit enrollment/maturity window metadata |
| Completeness | Required 14 packets, row-count and JSON checks, shared boundaries, unknown classifications | Reuse unchanged; extend source manifest without weakening checks |
| Waypoints and promotions | Day 40 event allowlist excludes waypoints; entitlement export selects active-admin evidence, not all Premium/promo records | Extend beta export narrowly; do not change Day 40 denominator or include full billing rows |
| Report privacy | Existing users packet/CSV includes previously authorized names/emails | Beta mode must output internal IDs only; do not use the current identity-bearing export unchanged |

Historical things that cannot be reliably reconstructed include missing pre-instrumentation activity, deleted lineage, actual workflow starts, unseen canceled/abandoned actions, beta acceptance, inbox delivery, and clock provenance from ambiguous legacy timestamps. More SQL cannot recover absent facts.

**Production-capture usability:** The September 29 validation report documents a complete fresh production capture on MariaDB 10.6.24, all 14 source packets and 52 passing tests. The current reporter still passes those 52 tests. Current local schema and event writers remain compatible in the inspected areas. This establishes a reusable workflow, **not a fresh production-compatibility certification**. No November 5 production capture, deployment hash comparison, GA4/Plausible/Clarity dashboard check, or production aggregation was performed. Before the first beta report, obtain a fresh authorized SELECT-only capture, verify source/row completeness and deployment coverage, and keep it outside the repository/web root. Existing outputs must not be overwritten or labeled current.

## 6. Monitoring and notification reliability assessment

The prior incident is not reopened. The owner reports the recent live test succeeded and the scheduling issue was resolved. No task, reminder, deadline, or notification was triggered in this audit.

| Operation | Authoritative evidence | What can be measured | Limits |
|---|---|---|---|
| Scheduled task fires | Native scheduler fire plus observer `ScheduledTaskRunHistory.jobToBeExecuted → recordStart`; `fpw_scheduled_task_last_run.last_run_utc` | Latest observed start by environment/scope/app/group/task | Observer installation depends on runtime; latest-start row is not full run history or successful application execution |
| Monitor endpoint completes | `run-monitor.cfm` returns routine result with nested arrival observation/delivery results | Response counters if retained by caller; named error logs | No common persisted run ID/finish record. Top-level routine success does not certify both arrival sub-results; they must be inspected |
| Departure reminders | `departure_reminder_deliveries`: occurrence, CLAIMED/SENT/FAILED, attempt count, timestamps, last error | Due occurrence, duplicate suppression, known failures/retries | A claim alone is not send success. SMTP acceptance followed by receipt-write failure deliberately leaves CLAIMED/uncertain |
| Operational start | Plan + route progress + monitoring initialized within lifecycle command | Confirmed start versus scheduled/ACTIVE-but-not-departed state | Browser `active_cruise_started` can fire on send; use operational evidence |
| Expected/routine check-in | `floatplan_monitoring.expected_checkin_at,checkpoint_kind,grace_expires_at,next_monitor_eval_at` and monitor events | Current expected checkpoint; late/missed/escalated transitions | Current row changes over cycles; do not calculate all historical scheduled expectations from today's row |
| Accepted and delayed check-in | Monitor `CHECKIN_RECEIVED`/state transitions, owned DB-UTC timeline post, optional canonical event | Positive accepted actions and declared status; Companion processed receipt | DELAYED is a boater-reported operational status, not technical error. Canonical supplementary event can fail while primary operation succeeds |
| Arrival overdue | Watch/revision state + `fpw_arrival_events` and deadline/source/actor/historical flag | Independent overdue observation and authorized revisions/suppression | Historical-only incidents must remain observation-only; do not turn them into missing-email defects |
| Arrival notification queued/claimed | `fpw_arrival_notices` and per-recipient `fpw_arrival_deliveries` | Eligibility, recipient count, pending/claimed/suppressed reasons | Not accepted send; queue state is not delivery proof |
| Arrival transport attempt | `fpw_arrival_attempts`, delivery state/time/reason | SUBMITTED, FAILED_RETRYABLE, FAILED_PERMANENT, UNKNOWN; 5/15/30-minute retry spacing, maximum four attempts | UNKNOWN must not be treated as confirmed failure or retried automatically. Recipient keys are internal keyed identifiers, not reportable addresses |
| Captain closeout reminder | `floatplan_alert_history`, `CAPTAIN_CLOSEOUT` and attempt/status fields | PENDING, SENT, retryable/permanent/unknown status | Separate from shore arrival recipient ledger; aggregate appropriate source separately |
| Arrival deadline change | Revision + notice using reserved change slot; same delivery/attempt services | Old/new revision and accepted recipient attempts | Do not infer a send from the deadline change alone |
| Routine missed/escalated alert | `floatplan_monitor_events` and `floatplan_alert_history` cycle-specific alert types | Captain/contact alert evidence and counters | Older history records aggregate some recipient activity; less detail than arrival per-recipient attempts |
| Trip completion/monitor termination | CLOSED plan, route completion, monitoring close state/events and arrival terminal reason | Successful lifecycle suppression and positive completion evidence | Canonical close timeline writer can be best effort; not all historical clocks are trusted |
| Safe-arrival messages | `SafeArrivalNotificationService`, recipient-scoped `floatplan_alert_history` | Claim/sent/failed evidence and duplicate protection | Separate operation after closure; closure alone is not email acceptance |
| Inbox delivery/access | No general SMTP delivery callback, verified receipt/open/access record for float-plan sharing found | Cannot reliably report delivered/read percentage | Recovery campaign opens/clicks have a different purpose and do not establish shore-contact access |

The arrival mail transport uses synchronous `cfmail spoolenable=false`; SUBMITTED means transport acceptance. Premium direct `cfmail` and other send paths have source-specific spooling behavior. Do not collapse CF queue acceptance, SMTP handoff, final inbox delivery, and human reading into one field called “delivered.”

Correlations already available: member, plan, revision, notice, delivery, attempt, monitoring-cycle and source-event IDs. Missing: a uniform scheduler execution ID carried through evaluation and delivery. **P1** can add minimal run start/finish counters/correlation using the existing recovery-run pattern after design approval; do not change scheduling logic to produce reporting.

## 7. Existing feedback-system assessment

Current path: shared navigation → `app/contact.cfm?mode=contact|support|feedback` → POST `api/v1/contactUs.cfc.handle`.

- Existing fields: first/last name, email, subject, category, description, mode.
- Existing protections: mutation guard, CSRF/origin/method checks, field length/control-character validation, category allowlist, rate admission, honeypot, no-store response.
- Mail goes to the existing support mailbox with a timestamp. A successful honeypot response intentionally sends nothing; a browser success page must not be counted as genuine feedback.
- No database insert, internal member association, issue ID, triage/status history, resolution record, task-ease rating or attachment input was found.
- Browser inspection confirmed the existing form and its fields; it was not submitted.

**No new beta-specific form is needed.** Best Fix extends the current support submission with authenticated tester linkage and a durable issue row, keeping ordinary anonymous contact behavior compatible. Admin issue review is a small new capability; no current feedback triage screen was found. The narrower manual alternative uses the existing support mailbox plus a restricted issue register.

Minimum proposed model:

| Field | Proposed treatment |
|---|---|
| Internal tester/member identifier | Server-resolved authenticated member or explicitly reviewed linkage; never trust a supplied `user_id` |
| Category | Reuse current category allowlist; preserve support/feature mode |
| Page/feature context | Allowlisted feature key and sanitized path, without query tokens/geometry |
| Description | Existing bounded description, access-controlled; omit from aggregate analytics |
| Submission timestamp | Database UTC |
| Optional task-ease rating | Nullable small bounded scale after wording/scale approval |
| Triage status | New / reviewed / investigating / deferred, versioned/audited |
| Resolution status | Unresolved / resolved / unable to reproduce / declined, with a resolution timestamp/reference |

Feedback remains optional and never gates activation or active-tester classification.

**Screenshots:** No current upload support was found. Start with text/context. If later authorized, require an explicit privacy notice and redaction workflow; screenshots can expose names, shore contacts, coordinates, route contents and tokens. Store approved attachments outside the public web root, restrict access, validate file types/size, and define removal timing. Do not promise that automatic masking guarantees privacy. This is P2, not required before invitations.

## 8. Technical failure reporting assessment

| Outcome | Evidence today | Reporting rule |
|---|---|---|
| Successful operation | Required saved-activity transaction, source-valid receipt or accepted lifecycle state | Count according to its authority and deduplication rule |
| Explicit technical failure | `FPW_ERROR` root log; named service logs; persisted arrival/Companion/Basic receipt failures; some API error responses | Count only a known failure boundary/code; preserve operation/source |
| Validation/access rejection | API validation/auth/ownership/entitlement response; auth limiter/admin audit where applicable | Separate from infrastructure or database failure |
| Canceled operation | Some browser auth modal cancel events | Positive client cancellation only; not a durable complete journey history |
| Abandoned/incomplete workflow | Some browser starts/previews, incomplete persisted objects | No universal server start/end evidence; do not label all non-completers abandoned |
| Unknown outcome | Unresolved share start, PROCESSING/CLAIMED/SUBMITTING after uncertain handoff, missing coverage | Report unknown; never convert automatically to failure or retry |

`Application.cfc.onError` writes `logs/fpw-errors.log` and CF `fpw-errors` with request UUID, endpoint/method, user context when available and exception context. Query/referrer redaction is present. Caught API failures can bypass the global handler; some return an error code without a durable failed-operation event. Generic ProductEventService failures log event/source/error but do not always include the original HTTP request ID. Required member-save events currently generate their own UUID and do not forward `request.fpwRequestId`; local aggregate checks corroborated absent request IDs on many saved-activity rows.

The route/float-plan/waypoint save paths prove successful persistence well; they do not provide an exhaustive denominator of attempted saves. Authentication rate counters are bounded operational counters, not a durable beta failure history. No member inactivity, lack of sharing, or lack of a later event is a technical error by itself.

**Minimum P0 recommendation:** Reuse ProductEventService for a narrow allowlisted failure event at important authenticated save/generate/share boundaries, with server-derived member, operation, stable error category, request correlation and database UTC. Record outside a rolled-back business transaction; telemetry failure must not change the existing business response or cause duplicate sending. Never copy exception text, SQL, form values or private payloads into analytics. Do not add a success event duplicating existing authoritative receipts.

P1 can establish attempt IDs and outcome reconciliation where failure-rate denominators or cancellation/abandonment analysis are required. Until then, label reports “observed explicit failures” and “unknown outcomes,” not a comprehensive technical failure rate.

## 9. Privacy and security considerations

1. Reuse `AdminAuthorizationService` and existing admin middleware for all tester-level reports; do not rely on a public page or knowing a report URL. Reuse POST/CSRF and admin audit for participation/triage mutations.
2. Product-event metadata is allowlisted, bounded and normally empty for saved activity. Keep beta metadata similarly small. Member IDs are pseudonymous identifiers, not anonymous data.
3. Do not export route geometry, coordinates, shore-contact details, passwords/tokens, private plan contents, payment identifiers or raw support text to beta measurement outputs.
4. Day 40's current users export and CSV include names/emails under earlier approval. That is not permission to include them in beta reports. Add an IDs-only beta export mode; keep authorized roster/contact delivery material outside Git and the web root.
5. Operational tables and logs can contain sensitive values. For example, Companion records include note/location data, Basic receipts include recipient/response data, and ordinary `email.cfc` logs can include recipient/subject. Project only safe fields; do not copy entire rows/log files into analytics.
6. GA4/Clarity production gating and several `data-clarity-mask` elements were found. Complete private-page masking and the live property settings were not verified. Plausible's non-preview injection is also present locally and does not use the GA4 host gate. Review existing analytics scope/disclosures; do not add another tool or silently change these integrations during this audit.
7. The current public privacy policy discusses technical/usage/analytics information and retention. Before invitations, the owner should review beta-specific participation, optional feedback/screenshots, linkage, withdrawal and report-retention disclosures. Signup's existing terms/privacy hashes do not record acceptance of a separate beta program.
8. Approve a retention schedule for participation evidence, feedback and restricted tester-level exports before collection. Prefer short-lived exports, periodic review after the launch milestones, deletion/pseudonymization when individual linkage is no longer needed, and retained non-identifying aggregates where appropriate. No new numerical retention period or production cleanup setting is imposed here.
9. Withdrawing from beta must not cancel a paid subscription, erase operational safety history, or change required transactional notifications. Honor existing privacy/account-deletion procedures separately.
10. This is an engineering review of current safeguards, not a legal compliance certification.

## 10. Beta cohort reporting model

### Proposed report dimensions and identity

One versioned report with database UTC cutoff `T`, cohort/program ID, approved metric-definition version, source capture timestamp/counts, coverage boundary, exclusions and unknowns. Use internal invitation/tester ID before signup and `user_id` after verified linkage. Keep recruitment classification distinct from membership tier.

| Cohort state | Required evidence |
|---|---|
| Existing member invited | Existing member link + invitation timestamp/source |
| Existing member accepted | Explicit acceptance, accepted/enrolled timestamp and versioned consent/reference |
| New mailing-list recruit | Invitation/source identity joined to subsequent canonical signup; signup date alone cannot prove mailing-list attribution |
| Enrolled, no verified activation | Accepted eligible participation; no qualifying post-enrollment share found, with coverage/unknown disclosure |
| Successfully activated | At least one accepted qualifying post-enrollment share under section 3 |
| Returning tester | Later-calendar-day qualifying activity under the approved beta definition |
| Withdrawn | Explicit withdrawal time/reason category; retain historical inclusion intervals without silently changing old reports |

### Metric calculations proposed for approval

- **Invitation acceptance:** distinct accepted invitations / distinct eligible issued invitations at cutoff. Track attempted invitation delivery separately; invitation delivered cannot be asserted without delivery evidence. Do not reconstruct a mailing-list denominator from current FPW accounts.
- **Promotion activation:** enrolled members requiring a beta benefit with an effective linked grant / enrolled members designated to receive that benefit. Report already-Premium members separately; do not inflate failure counts because they did not redeem.
- **Activation:** unique eligible enrolled testers with qualifying share / eligible enrolled testers. Report observed rate plus enrolled, qualifying, unresolved-share, and incomplete-coverage counts.
- **Readiness:** owned usable saved vessel/waypoints/routes/plans present at enrollment count as pre-existing readiness. Do not force duplication. Report post-enrollment creation/edit events separately.
- **First meaningful planning/first share:** earliest evidenced qualifying post-enrollment time minus enrollment time; missing timing remains unknown.
- **Seven-day return:** proposed `BetaReturn7-v1`: at least one Day-40-qualifying meaningful action on a later UTC calendar date, with `E < action < E+7 days`. Only include enrollments with `T >= E+7 days`; keep early withdrawals/censored windows explicit. UTC preserves existing report conventions. This differs from “exact day 7,” rolling 24-hour sessions, login-only return, and Day 40 return-after-completion; owner must approve the definition before implementation.
- **Repeat use:** retain Day 40 normalized distinct-use and ordered-beginning rules. Reopening/editing a route, copies without independent use proof, and multiple daily plans are not automatically additional trips. Show beta-window and prior-history evidence separately.
- **Reliability:** use relevant eligible operations/occurrences as denominators, not all enrolled members. Separate no opportunity, suppressed/ineligible, attempted, accepted, failed and unknown. Due-history gaps and missing run captures prevent claims of a complete reliability rate.
- **Feedback:** distinct enrolled testers with a genuine persisted feedback record / enrolled testers; optional. Also report category/status counts without sensitive descriptions.

Daily report histories must preserve their original cohort/definition/source cutoff. Re-enrollment, withdrawal treatment, eligibility/test exclusions and self-share treatment are BETA-02 decisions, not implemented defaults.

## 11. Measurement coverage scorecard

Readiness refers to existing application collection evidence, not deployed beta reporting. Effort is an engineering estimate for the missing beta portion, not work performed.

| Core metric | Readiness | Authoritative evidence | Missing capability | Effort / priority |
|---|---|---|---|---|
| Beta enrollment | Not supported | No typed beta register found | Invitations, acceptance, intervals, withdrawal, source attribution | Medium; P0-1 |
| Promotional entitlement activation | Fully supported for access | Redemption + entitlement + admin audit | Beta linkage; existing-Premium classification | Small integration; P0-1/2 |
| Vessel readiness | Fully supported for saved-vessel definition | Owned vessel + required save event | Enrollment snapshot/IDs-only reporting | Small; P0-2 |
| Waypoint saving | Fully supported | Owned waypoint + required save event | Add safe waypoint source to beta export | Small; P0-2 |
| Route creation | Fully supported for persistence | Required saved/generated route event and rows | Beta filtering; keep empty-route/substantive-use separation | Small; P0-2 |
| Float-plan creation | Fully supported | Required Draft event and owned plan | Beta filtering and pre-existing readiness | Small; P0-2 |
| Float-plan sharing | Partially supported | Receipts + source-valid completed/paired events | Cohort/time filter, partial/unknown outcomes, approved qualification | Medium; P0-2 |
| Seven-day return | Partially supported | Qualified UTC activity and Day 40 helpers | Enrollment clock, maturity/calendar definition and report | Medium; P1-1 |
| Repeat use | Partially supported | Day 40 normalized route/trip evidence | Beta window; future missing lineage/start/changed-field evidence | Small report extension; P1-1; stronger collection P1-3 |
| Monitoring reliability | Partially supported | Monitoring/arrival/notification ledgers | Run-level correlation/denominator; delivery remains unverified | Medium; P1-2, pre-invite visibility check P0-5 |
| Technical error reporting | Partially supported | Root/service logs and some failed receipts | Durable selected failures, request correlation, complete attempts denominator | Medium; P0-4 then P1-2 |
| Optional feedback | Partially supported | Existing guarded contact/support form | Durable issue/tester link and triage/resolution | Small–medium; P0-3 |

## 12. P0/P1/P2 implementation recommendations

All entries are proposals requiring a separate approval. File names marked “proposed” do not exist yet and are not created by this audit.

### P0 — required before beta invitations

| ID | Exact proposed change / reuse | Likely files/services and schema impact | Required tests / acceptance criterion | Estimate / risk |
|---|---|---|---|---|
| P0-1 | Official beta participation register, explicit acceptance and withdrawal, separate invitation/source and access eligibility. Reuse admin authorization/audit and existing promo grant/effective-access services. | Proposed `api/v1/BetaEnrollmentService.cfc`, small admin participation view/endpoint and member acceptance action. One proposed `fpw_beta_participation` table; optional linked promotion/entitlement IDs. No membership-type or billing change. | Duplicate invite/accept idempotency, authenticated ownership/CSRF, accepted UTC/version evidence, legacy/new accounts, existing Premium, withdraw/re-enroll, audit rollback. A tester qualifies only through recorded acceptance; access grants alone never enroll. | 2–3 working days. Risks: invitation identity/linkage, accidental access overlap, erased participation history. Resolve schema/status policy before coding. |
| P0-2 | Beta-only IDs-based exporter/report adapter using existing share predicates, cutoff/import checks and Day 40 lineage rules. Report eligible denominator, unique accepted shares, latency, readiness, unknowns and source completeness. | Extend `scripts/retention/export-sql.mjs` and `cli.mjs` through explicit beta mode; proposed `scripts/retention/beta.mjs`; add tests. Read existing tables + P0-1 register; no analytics schema required. | Receipt/event dedup, partial-recipient success, replay of old receipt, pre-enrollment assets/share, withdrawn/test users, missing packets/times, zero denominator, privacy projections. Day 40 v1 output stays unchanged for same inputs. | 1.5–2.5 days. Risks: silently changing Day 40, counting clicks/unknowns as success, leaking legacy identity fields. |
| P0-3 | Persist genuine feedback from existing form; server-derived tester linkage, safe feature context and admin triage/resolution. Retain ordinary contact/support behavior. | `app/contact.cfm`, `api/v1/contactUs.cfc`; proposed feedback service/admin view. One proposed feedback table; reuse admin audit for status history. No new beta form or attachment service. | Anonymous/member ownership, spoofed ID/context, CSRF/rate/honeypot, mail failure versus saved issue, duplicate POST, optional rating, admin-only reading. Genuine issue exists independently of notification email success. | 1–2 days. Risks: identity spoofing, duplicate issues, private description exposure. |
| P0-4 | Record a small allowlist of explicit technical failures for key authenticated route/save/share commands and carry request correlation, without duplicating successes or changing response/send semantics. | `includes/ProductEventService.cfc`; selected existing API failure boundaries in `routeBuilder.cfc,floatplan.cfc,waypoint.cfc`; tests. Reuse `product_events`; no new schema expected. | Validation vs technical vs unknown distinction, rollback survival, event-write failure cannot alter domain outcome, retry/idempotency, metadata rejection. Report known failures; do not claim a complete failure rate until attempt coverage exists. | 1–2 days. Risks: logging inside rolled-back transaction; duplicate event/send; overly broad free-text diagnostics. |
| P0-5 | Approve metric/privacy/retention decisions and verify existing production evidence sources through safe SELECTs and deployment checks. Inspect normal scheduled outcomes; do not reopen resolved incident. | No production code/schema change required for the check. Reuse operational ledgers, public privacy disclosure, current admin screens and existing runbooks. | Verify source tables/UTC coverage and exporter completeness; agreed consent, self-share, eligibility and withdrawal rules; safe report location/admin access. No live notification test without specific authorization. | 0.5–1 day. Risk: production/version drift or unverified provider masking; report unknowns honestly. |
| P0-6 | Integrate/reconcile the minimum report with synthetic cohorts and obtain owner acceptance using privacy-safe output. | Existing tests + proposed beta report/enrollment/feedback tests; approved disposable development data only in implementation phase. | Unique numerator/denominator, accepted share boundary, failure/unknown distinction, unchanged billing/monitoring/Day 40, admin authorization and privacy. | 1–2 days. Risk: functional tests alone do not prove deployed capture. |

**Best Fix P0 estimate:** approximately **8–13 working days** including integration/QA, assuming one experienced developer, existing infrastructure access, prompt decisions and no unexpected production drift. This is a planning range, not a commitment or implementation approval.

**Safest Fix alternative:** an owner-maintained restricted acceptance/withdrawal and feedback register plus beta adapter and limited failure review could reduce initial engineering to approximately **3–5 working days**, with continuing manual reconciliation. It does not deliver the same in-app assurance or automation. No schema migration is strictly necessary for that operating model.

### P1 — before March 21, 2027 soft launch

| ID | Proposed change / likely files | Schema/reuse | Tests and acceptance | Estimate / risks |
|---|---|---|---|---|
| P1-1 | Add `BetaReturn7-v1`, maturity/censoring, repeat route/trip and recruitment comparisons to beta report module | Reuse Day 40 evidence/date/route-use modules; no new table required if enrollment exists | Cross-midnight, exact cutoff, immature/withdrawn enrollment, pre-existing routes, copies and repeated edits; no change to Day 40 v1 | 1–2 days; definition/timezone drift |
| P1-2 | Add minimal job execution correlation and operation outcome denominators where existing ledgers cannot answer reliability questions; expose safe admin reporting | Reuse current scheduler ownership, error logs and recovery-run observability patterns. A small run-record table may be justified after checking approved existing run storage; no general scheduler redesign | Job starts but fails, nested arrival errors despite routine success, no-work run, duplicate attempts, unknown handoff, disabled tasks; captured run status must not claim inbox delivery | 2–3 days; logging must not affect schedule or email semantics |
| P1-3 | Establish future coverage boundaries and durable meaning for planning start/substantive route updates/operational start/completion where necessary | Extend existing event contracts or narrowly add logical-use provenance only after design; reuse current lifecycle transactions. Historical gaps remain unknown | Alternative clients, no-op/edit/copy vs new use, UTC and delete retention, current-session return, lifecycle rollback | 2–3 days; broader lifecycle work requires a fresh scoped approval |

P1 adds roughly **5–8 working days** at current discovery resolution. Current-session read-only page visits should only be collected if the owner wants a separate “visited” metric; they must not silently become meaningful Day 40 activity.

### P2 — useful later

| Enhancement | Scope / reuse | Impact, tests, estimate |
|---|---|---|
| Visual beta dashboard and convenience exports | Reuse beta report data and admin styles, not a new analytics platform | No new collection required; authorization/parity tests; 1–3 days |
| Privacy-controlled screenshots | Optional extension of existing feedback, private storage and explicit redaction/removal workflow | Storage/validation/access testing; 2–4 days; sensitive information risk |
| Stronger delivery/access evidence | First assess existing mail-provider capabilities and current Follow access/privacy design; no provider/platform adoption authorized | Separate proposal and feasibility estimate; automated opens/access do not prove human reading |
| Advanced journey/segmentation | Reuse verified events after stable cohort and definitions | New metrics need explicit denominators/coverage and independent approval; defer estimates until a concrete use case |

## 13. Files, tables and services involved — evidence references

All paths below are in the inspected development checkout. Line anchors refer to the current working copy and may shift after future edits.

| Ref | Exact source / anchor | Evidence established |
|---|---|---|
| E01 | [ProductEventService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/ProductEventService.cfc:36), lines 36–85, 88–205, 261–460, 463–543 | Required 17-name activity contract; UTC/idempotency/metadata; generic event versus required write; aggregate semantics |
| E02 | [join.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/join.cfc:298), lines 298–344; [coverage service](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryCoverageService.cfc:14), lines 14–23; [auth.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/auth.cfc:172) | Required signup/consent event, recovery coverage distinction, login event |
| E03 | [vessel.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/vessel.cfc:414), lines 414–437; [member activity contract](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/member-activity-evidence.md) | Owned changed-save evidence and historical integration record |
| E04 | [waypoint.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/waypoint.cfc:392), lines 392–425; [LibraryWaypointService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/LibraryWaypointService.cfc:1) | Shared persistent save; duplicate behavior; both-leg endpoint transaction |
| E05 | [routeBuilder.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/routeBuilder.cfc:2264), anchors 2191, 2252, 2264–2285, 12337, 12422, 12547, 13082–13112 | Named/generated route and geometry activity boundaries |
| E06 | [floatplan.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/floatplan.cfc:4877), anchors 4877–4883, 5312; [generated Draft creation](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/routeBuilder.cfc:4269) | Required Draft create/update and generated insertion |
| E07 | [BasicReviewSendService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/BasicReviewSendService.cfc:154), lines 154–225 and 482–551; [Basic evidence contract](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/durable-basic-share-evidence.md) | Accepted submission, atomic SENT/event, unresolved completion |
| E08 | [floatplan tracked sharing](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/floatplan.cfc:8529), lines 8529–8570, 9150–9350, 340–354; [PremiumSendCreditService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/PremiumSendCreditService.cfc) | Basic/Premium wrapper, partial accepted count, commit/receipt, best-effort completion event |
| E09 | [share coverage service](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/InactiveMemberRecoveryCoverageService.cfc:72), lines 72–110; [Day 40 share reconciliation](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/scripts/retention/baseline.mjs:127) | Pre-submission durable marker; paired outcomes; deduplication |
| E10 | [AdminPromoCodeService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/AdminPromoCodeService.cfc:13); [admin promo page](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/admin/promo-codes.cfm) | Existing promotion inventory/filtering |
| E11 | [AdminMemberEntitlementService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/AdminMemberEntitlementService.cfc:215), lines 215–358, 363–483; [member access admin](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/admin/member-entitlements.cfm) | Grants/redemptions, overlap, extension/revocation, audit and current member detail |
| E12 | [PromoCodeService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/PromoCodeService.cfc:55), lines 55–174, 706 onward; [MemberEntitlementService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/MemberEntitlementService.cfc:13) | Redemption vs checkout; effective Premium and existing sources |
| E13 | [Day 40 runbook](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/day40-retention-baseline.md); [historical validation](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/validation.md) | Definitions, source capture, known gaps and prior test evidence |
| E14 | [export-sql.mjs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/scripts/retention/export-sql.mjs:30); [baseline.mjs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/scripts/retention/baseline.mjs:5); [evidence.mjs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/scripts/retention/evidence.mjs:48); [route-uses.mjs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/scripts/retention/route-uses.mjs); [cli.mjs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/scripts/retention/cli.mjs:51) | Existing offline algorithms, exclusions, identities, UTC/window and safe export constraints |
| E15 | [monitor.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/monitor.cfc:787), anchors 97, 438, 680–778, 787–870, 895, 1692–1772 | Routine and independent arrival evaluation, transition/event writes, closure |
| E16 | [TripActivityWriterService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/TripActivityWriterService.cfc:11), anchors 11, 205, 537; [check-in writer caller](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/floatplan.cfc:7380), lines 7380–7414; [close](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/floatplan.cfc:6190), lines 6190–6290; [operational start](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/floatplan.cfc:9816) | Lifecycle authority vs best-effort supplementary canonical timeline evidence |
| E17 | [CompanionCheckinService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/CompanionCheckinService.cfc:11), lines 11–123, 491–559 | Received, processed, failed and duplicate submission behavior |
| E18 | [DepartureReminderService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/DepartureReminderService.cfc:19), lines 19–87, 203–221, 382–625 | Occurrence claim, accepted send, failure/uncertainty |
| E19 | [ArrivalOverdueService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/ArrivalOverdueService.cfc:158); [ArrivalOverdueDeliveryService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/ArrivalOverdueDeliveryService.cfc:221), anchors 30–152, 221–419; [ArrivalOverdueMailService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/ArrivalOverdueMailService.cfc:236) | Authoritative deadline revisions, historical suppression, recipient/attempt states, handoff semantics |
| E20 | [OverdueAlertService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/OverdueAlertService.cfc:259), anchors 259, 348, 502–590; [SafeArrivalNotificationService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/SafeArrivalNotificationService.cfc:26) | Routine and completion alert-history evidence |
| E21 | [email.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/email.cfc:1457), lines 1457–1535 | Queue/transport distinction and operational log privacy |
| E22 | [ScheduledTaskRunHistory.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/ScheduledTaskRunHistory.cfc:3), anchors 3–45, 84–148; [run-monitor.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/scheduled/run-monitor.cfm); [run-departure-reminders.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/scheduled/run-departure-reminders.cfm) | Latest start observer and endpoint result/error handling |
| E23 | [contact.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/contact.cfm:1); [contactUs.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/contactUs.cfc:3), lines 3–149 | Existing support/feedback fields, protections, email-only persistence |
| E24 | [Application.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/Application.cfc:241), lines 241–317, request ID anchor 74; [AdminAuthorizationService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/AdminAuthorizationService.cfc:10) | Global diagnostic context and admin authorization/CSRF |
| E25 | [auth implementation/validation](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/unified-authentication-implementation.md); [AuthRequestGuardService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/AuthRequestGuardService.cfc); [AuthRateLimitService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/AuthRateLimitService.cfc) | Prior auth/security validation, existing request protection |
| E26 | [analytics_ga4.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/analytics_ga4.cfm:27); [analytics_clarity.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/analytics_clarity.cfm:17); [public privacy policy](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/privacy_policy.cfm:314), anchors 314–330, 493, 507 | Three existing browser analytics integrations; policy topics; production gating/masking limits |
| E27 | [dashboard.js share callback](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard.js:6184), lines 6184–6202, preview 5319, Draft 5960; [routebuilder.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/routebuilder.js:6040), also 6813; [floatplanWizard.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/floatplanWizard.js:2238); [floatplans.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/floatplans.js:581); [auth-modal.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/auth-modal.js:87) | Browser intent vs actual persisted success |
| E28 | [AdminRecoveryCenterService.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/AdminRecoveryCenterService.cfc:110); [recovery-center-data.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/admin/recovery-center-data.cfm:6); [Recovery Center report](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/recovery-center-completion-report.md) | Reusable admin/history patterns; recovery-specific cohort and metrics |
| E29 | [arrival monitoring migration](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/database/migrations/20261101_001_arrival_overdue_monitoring.up.sql); [arrival delivery migration](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/database/migrations/20261101_002_arrival_overdue_delivery.up.sql); [deadline change migration](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/database/migrations/20261102_001_shore_arrival_time_change.up.sql); [scheduler last-run migration](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/database/migrations/20261103_002_scheduled_task_last_run.up.sql) | Existing engine/schema preflight guards, arrival history/recipient/attempt DDL, deadline-change slot constraint and scheduler composite-key DDL inspected; local schema columns inspected separately. No migration executed. |

## 14. Test strategy and validation performed

### Executed during this audit

```text
node --test tests/retention-baseline.test.mjs tests/retention-route-uses.test.mjs tests/day40-export-sql.test.mjs tests/member-activity-evidence.test.mjs
tests 59; pass 59; fail 0; cancelled 0; skipped 0; todo 0
```

These tests use synthetic in-memory fixtures/source checks and temporary offline files. They do not invoke live notification endpoints or create FPW accounts/plans. The offline CLI test cleans its temporary directory. Source inspected before execution.

- MCPCFC schema and aggregate SELECTs only; no member-level export.
- MCP Playwright local contact/feedback render and DOM inspection only; no form submission or authentication.
- Existing source `git diff --check` passed before and after documentation creation.
- All 18 pre-existing pending files have identical before/after SHA-256 hashes. Both reports have valid local file links and no trailing whitespace. The audit has all 18 requested sections; the progress register has sections A–G and all 14 milestones.
- The two temporary browser artifacts created by this audit were removed; older review artifacts were not touched. Only the two authorized documents remain as additions.
- Existing `.gitignore:23` ignores `docs/`, so these new documents are saved on disk but not staged/tracked. The ignore rule was preserved; an authorized future commit must explicitly include these two files.
- Historical CF/browser validation in E03/E13/E25 is **reported historical evidence**, not newly rerun.
- No CF mutation runner, monitor runner, signup, share, check-in, promo redemption, email, or production report was executed.

### Required for a later implementation phase

Use clean disposable dev fixtures, never recycled accounts or production safety events. Validate ordinary + already-Premium + legacy + new-invite + withdrawn cases; pre-existing readiness; Basic Review/Basic operational/Premium shares; partial/unknown transport; old receipt replay; invalid ownership and CSRF; event failure atomicity; timestamps/DST/calendar maturity; cohort withdrawal/censoring; metadata privacy; feedback failure/honeypot; and unchanged billing/monitoring/Day 40 regression behavior.

Existing integration suites for member activity, durable Basic sharing, authentication, monitoring, arrival delivery and scheduler administration provide useful coverage but can mutate fixtures or send MailHog mail. Run them only under the separately approved implementation/validation scope with explicit safe transport checks. A fresh production SELECT/report reconciliation is a separate deployment-verification step, not replaced by local tests.

## 15. Dependencies and blockers

| Item | Owner / impact | Required next action / resolution evidence |
|---|---|---|
| No official beta participation identity | Program owner + implementation owner to designate; blocks reliable eligible denominator | Approve Best Fix or manual Safest Fix; demonstrate accepted/withdrawn history independent of access |
| KPI policy details | Program owner; affects comparable activation/retention rates | Approve accepted-send boundary, self-share treatment, eligibility/exclusions, withdrawal/re-enrollment and seven-day convention |
| Missing feedback issue persistence | Implementation owner to designate; prevents reproducible optional-feedback/triage report | Approve existing-form extension or audited manual process |
| Incomplete failure/attempt coverage | Engineering owner to designate; prevents comprehensive failure-rate claims | P0 bounded failure evidence; P1 denominators/correlation; retain unknown counts |
| Production evidence freshness | Authorized operator; current code/local proof cannot certify live capture | Fresh safe SELECT capture/deployment coverage and source completeness checks before first cohort report |
| Privacy/retention decisions | Program owner; private data could enter reports/screenshots | Approve IDs-only projection, admin access, beta disclosure and retention operating procedure |
| Historical gaps | No reconstruction fix exists; affects interpretation, not a new defect | Keep known-positive/unknown classifications; do not backfill fabricated events |

The previously resolved scheduler/Cloudflare incident is not an active blocker. There was no new production regression evidence in this audit.

## 16. Implementation estimates and launch feasibility

The Best Fix minimum is approximately 8–13 working days; a manually administered narrow option is approximately 3–5 engineering days plus ongoing owner effort. P1 is approximately 5–8 additional working days. Estimates assume the focused scopes in section 12, not a new analytics platform, new membership product, invitation delivery service, or full scheduler redesign.

From November 5, 2026, the March 21, 2027 soft-launch target is **feasible on the discovered engineering scope**, conditional on owner approval, available implementation capacity, prompt privacy/metric decisions and production verification. This is not a launch-readiness certification or a guarantee about calendar commitments. May 31, 2027 remains the recorded hard-launch target; no dates were changed.

## 17. Remaining unknowns

- Exact current production deployment/configuration parity and a fresh production exporter capture.
- Actual eligible invited/enrolled beta population; all beta outcomes remain Not measured.
- Mailing-list invitation identity/delivery process and acceptance evidence before signup.
- Owner's final self-test/shore-contact qualification and withdrawal/maturity rules.
- Production analytics dashboard ingestion, session recording masks, retention and access settings.
- Existing host/provider inbox-delivery telemetry availability; no such evidence source was found in the app paths inspected.
- Complete historical read-only-session visits, technical attempts, canceled/abandoned flows, missing events and deleted lineage.
- Whether runtime scheduler observation is available on every production instance; local latest-start data alone cannot answer it.

These are explicitly bounded unknowns, not claims that the application is broken. Where evidence exists, report it; where it does not, do not infer inactivity or failure.

## 18. Recommended next assignment

**BETA-02 — Approve the minimum beta measurement design**, choosing Best Fix or Safest Fix and approving the exact participation/activation/return/privacy contracts. Produce a small implementation specification and migration design only for selected gaps. Preserve all existing entitlements, shared product-event meanings, Day 40 v1 and monitoring behavior.

BETA-01 is complete as a scoped discovery/documentation deliverable with the limits above. No P0/P1/P2 functionality has been implemented, no invitations were sent, and no production deployment was performed. Stop here pending explicit next-phase approval.
