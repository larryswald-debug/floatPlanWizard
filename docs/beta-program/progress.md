# FPW Founding Beta Program — Progress Register

This is the authoritative project-progress register for the FPW Founding Beta Program. It is separate from the First 90 Days workbook and daily roadmap. Evidence references describe what has actually been established; proposed work is not implementation approval.

## A. Program overview

| Item | Current record |
|---|---|
| Program | FloatPlanWizard Founding Beta Program |
| Current phase | Minimum development implementation completed; production deployment and BETA-04 production verification pending |
| Latest update | November 5, 2026 |
| Target soft launch | March 21, 2027 |
| Target hard launch | May 31, 2027 |
| Current status | BETA-00 through BETA-03 Complete; BETA-04 In Progress; invitations Not Started |
| Readiness | The minimum participation, accepted-share reporting, optional feedback and explicit failure evidence are implemented and locally validated. Production deployment/source verification and owner disclosure/retention review remain before invitations. |
| Production evidence boundary | Current development source/local read-only checks and historical validation were inspected. No fresh production capture, production test or deployment was performed. Four disposable support emails were captured only in local MailHog and removed. |
| Beta outcomes | Not measured. Local test rows and historical non-beta reporting are not beta outcomes. |

The [measurement audit](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/beta-program/measurement-audit.md) contains the event coverage matrix, evidence references E01–E29, scorecard, implementation options and estimates.

The audit classifies the 12 named collection/reporting contracts as 5 fully supported, 6 partially supported and 1 not supported. This is a category count, not an analytics-coverage percentage or production certification.

## B. Milestone register

Dates are recorded only where supported. “Not recorded” does not imply a missed date. Future implementation/QA owners remain unassigned; role names below identify the decision or responsibility, not a resource commitment.

| ID / milestone | Status | Owner | Start / verified completion | Deliverables | Acceptance criteria | Evidence | Dependencies | Next action |
|---|---|---|---|---|---|---|---|---|
| BETA-00 — Define beta journey and success metrics | Complete | Program owner | Start not recorded / framework verified November 5, 2026 | Approved four dimensions, primary KPI, supporting metrics and launch targets | Approved framework supplied; primary activation requires a successful meaningful share, not a click | November 5 Phase 1 brief, sections 2 and 17; audit sections 1 and 3 | None | Resolve implementation-level eligibility, self-share and return-window details in BETA-02 without changing the approved framework |
| BETA-01 — Audit existing analytics and enrollment capabilities | Complete | Codex, under program-owner scope | November 5, 2026 / November 5, 2026 | Measurement audit and this separate register | Trace collection boundaries, assess all requested areas, record evidence/unknowns, propose minimal options, keep changes limited to the two documents | Audit sections 1–18; 59/59 offline tests; source/schema/browser evidence and unchanged-file check | BETA-00 | Stop implementation work pending BETA-02 approval |
| BETA-02 — Approve minimum measurement implementation | Complete | Program owner | November 5, 2026 / November 5, 2026 | Approved minimal design, definitions, privacy treatment and bounded implementation scope | Approve the narrowed participation, accepted-share, feedback and bounded-failure minimum; explicitly defer advanced seven-day reporting | November 5 One-Day Implementation Directive; implementation entry below | BETA-00, BETA-01 | Completed: narrowed minimum scope authorized; future features remain separate |
| BETA-03 — Implement missing collection and feedback capabilities | Complete | Codex under owner directive | November 5, 2026 / November 5, 2026 | Approved P0 cohort, report, feedback and failure capabilities | Approved scope implemented with required tests; preserve entitlements, Day 40 and notification semantics | Implementation runbook; 65 CF + 59 Node + 2 browser tests and 38 support checks | BETA-02 | Review development delivery; production deployment requires separate approval |
| BETA-04 — Validate reporting and admin visibility | In Progress | Codex local QA; production operator unassigned | November 5, 2026 / — | Synthetic/disposable validation, privacy-safe reports, authorized production source checks | Counts reconcile to authoritative outcomes; unknowns visible; admin access/privacy verified; current production evidence compatibility established | Local protected report/export, lifecycle, feedback and evidence tests passed; production verification not performed | BETA-03 | Obtain separate deployment approval and verify production sources/admin access |
| BETA-05 — Invite and enroll first beta cohort | Not Started | Program owner | Not started / — | Restricted invitation register and accepted cohort | Explicit acceptance recorded separately from access; privacy/disclosure and P0 acceptance complete; invitations separately authorized | None yet | BETA-02, BETA-04 | Approve invitation operation after readiness checks |
| BETA-06 — Complete initial tester activation review | Not Started | Program/reporting owner — unassigned | Not started / — | Enrollment-based activation, latency, readiness and coverage report | Verified shares reconciled; eligible denominator and unknowns disclosed; optional feedback does not gate activation | None yet | BETA-05 and sufficient observation | Collect an authorized cohort snapshot and review actual evidence |
| BETA-07 — Resolve priority beta findings | Not Started | Engineering/QA owner — unassigned | Not started / — | Triaged P0/P1 issues with resolution/retest evidence | Agreed blocking issues resolved or explicitly accepted; no status change based solely on a proposed fix | None yet | BETA-06 or independently verified beta findings | Triage actual findings and seek scoped fix approval |
| BETA-08 — Complete monitoring and reliability acceptance | Not Started | QA/operations owner — unassigned | Not started / — | Approved reliability evidence across lifecycle, check-in and notification paths | Separate scheduler execution, application completion, accepted send and unknown outcomes; preserve resolved-incident status | No beta acceptance evidence yet; owner reports prior live test success | BETA-04, approved QA scope; may run alongside BETA-06/07 | Define and execute the separately approved acceptance checks |
| BETA-09 — Conduct soft-launch readiness review | Not Started | Program owner | Not started / — | Go/no-go decision and unresolved-risk register | Activation/retention/reliability/privacy reviewed; blocking findings resolved or explicitly accepted | None yet | BETA-06, BETA-07, BETA-08 and required P1 reporting | Review evidence before March 21 |
| BETA-10 — Complete March 21 soft launch | Not Started | Program/release owner — unassigned | Target March 21, 2027 / — | Approved soft launch and verification record | Authorized release completed and verified; target date alone is not completion | None yet | BETA-09 and explicit release approval | Execute approved launch when ready |
| BETA-11 — Review post-soft-launch activation and retention | Not Started | Program/reporting owner — unassigned | Not started / — | Post-launch activation, mature return and repeat-use report | Cohort/window/version identified; mature denominators and coverage limits preserved | None yet | BETA-10 and mature observation windows | Review verified post-launch outcomes |
| BETA-12 — Conduct Memorial Day hard-launch readiness review | Not Started | Program owner | Not started / — | Hard-launch go/no-go and accepted-risk decision | Post-soft-launch findings and reliability evidence meet approved release criteria | None yet | BETA-11 and resolution of blocking findings | Review evidence before May 31 |
| BETA-13 — Complete May 31 hard launch | Not Started | Program/release owner — unassigned | Target May 31, 2027 / — | Approved hard launch and verification record | Authorized deployment and post-launch checks verified | None yet | BETA-12 and explicit release approval | Execute approved launch when ready |

BETA-00 completion refers to the supplied approved measurement framework, not approval of the new implementation-level definitions proposed by this audit. BETA-02 and BETA-03 were completed under the later One-Day Implementation Directive, as recorded below. No later milestone is complete merely because supporting FPW functionality exists.

## C. Current beta metrics

All real-beta outcomes below remain **Not measured**. The minimum report now functions in development, but this assignment did not invite or enroll real testers. Disposable fixtures were removed. Do not substitute development tests, prior production members or recovery enrollment for beta outcomes.

| Dimension | Measurement | Current value | Required reporting basis |
|---|---|---|---|
| Enrollment | Eligible invitations issued | Not measured | Invitation identity/source and issued timestamp |
| Enrollment | Accepted/enrolled testers | Not measured | Explicit participation acceptance and eligible member linkage |
| Enrollment | Invitation acceptance rate | Not measured | Accepted eligible invitations / eligible issued invitations at cutoff |
| Enrollment | Recruitment source and existing/new member split | Not measured | Explicit invite/source classification, not inferred from signup date |
| Enrollment | Withdrawn participants | Not measured | Withdrawal timestamp and preserved participation intervals |
| Access | Beta promotion activation | Not measured | Linked effective benefit / enrolled members designated to receive it; existing Premium separate |
| Activation — primary | Eligible enrolled testers | Not measured | Approved distinct-member denominator and exclusions |
| Activation — primary | Unique enrolled testers with verified meaningful share | Not measured | Valid accepted-send evidence during eligible participation interval |
| Activation — primary | Activation percentage | Not measured | Unique qualified sharers / eligible enrolled testers, with unknown/coverage counts |
| Activation — primary | Enrollment-to-first-share time | Not measured | Earliest evidenced accepted UTC minus enrollment UTC; missing time stays unknown |
| Activation | Vessel readiness | Not measured | Owned saved vessel at enrollment plus later saved-activity evidence |
| Activation | Waypoint-saving activity | Not measured | Required committed waypoint events; pre-existing assets separate |
| Activation | Route-start activity | Not measured | Approved planning-start definition; no silent substitution of page open or operational departure |
| Activation | Successful route creation | Not measured | Committed owned route; empty named route distinguished from substantive use |
| Activation | Float-plan creation | Not measured | Committed Draft; pre-existing plans separate from beta-period creation |
| Activation | Active Cruise adoption | Not measured | Accepted operational start, not only a browser event or ACTIVE status |
| Retention | Seven-day member return | Not measured | Approved separate beta definition and only mature observation windows |
| Retention | Repeat route/trip use | Not measured | Existing Day 40 normalized distinct-use/ordered-use rules with beta window |
| Retention | Enrolled, not yet verified activated / returning groups | Not measured | Explicit cohort and positive qualified activity; no missing-event inference |
| Reliability | Expected and accepted check-ins | Not measured | Eligible occurrence/action authority and processing outcomes |
| Reliability | Delayed, late, overdue and closed/suppressed monitoring states | Not measured | Monitoring and arrival transitions/revisions; delay is not automatically a technical error |
| Reliability | Scheduled execution and application completion | Not measured | Distinct run-start/completion evidence; latest start alone is insufficient |
| Reliability | Notification attempts and accepted sends | Not measured | Source-specific recipient/attempt receipts; suppressed and unknown outcomes separate |
| Reliability | Inbox delivery or shore-contact access | Not measured | No general verified delivery/access source established; accepted send is not delivery |
| Reliability | Observed technical failures | Not measured | Explicit failure codes/receipts/logs linked safely to operations |
| Reliability | Technical failure rate | Not measured | Complete eligible-attempt denominator; unavailable for the whole journey today |
| Usability | Optional feedback participation | Not measured | Genuine linked feedback records / enrolled testers; optional |
| Usability | Reported usability problems and triage/resolution | Not measured | Issue category/context/status with private descriptions excluded from analytics |
| All dimensions | Reporting cutoff, window and completeness | Not measured | Fixed UTC cutoff, source manifest/counts, definition version, exclusions and unknowns |

The implemented minimum uses existing authoritative accepted application sharing as the primary success boundary under the One-Day Directive. Advanced retention remains deferred. No claim of inbox delivery, human reading, or comprehensive failure-rate coverage is made.

## D. Decisions and approvals

Append future decisions; preserve earlier approvals and their evidence.

| Date | Decision / authority | Scope and consequence | Evidence |
|---|---|---|---|
| November 5, 2026 | Owner supplied approved beta framework | Activation, reliability, retention and usability; primary KPI is unique eligible enrolled testers who meaningfully share at least one float plan with a shore contact | Phase 1 brief, section 2 |
| November 5, 2026 | Owner authorized BETA-01 discovery and exactly two new documentation files | Read-only source/schema/report review; no implementation, data changes, notifications, deployment or new analytics platform | Brief, sections 1, 16 and 17 |
| November 5, 2026 | Owner established separate beta progress register and update policy | Beta milestones remain separate from First 90 Days; update only with new evidence in future explicitly beta-scoped assignments | Brief, section 14 |
| November 5, 2026 | Owner supplied launch targets | March 21, 2027 soft launch and May 31, 2027 hard launch; no change to those dates | Brief header and milestone list |
| November 5, 2026 | Audit recommends reuse; design is not yet approved | Reuse product events, receipts, promotions/admin security, Day 40 and existing feedback form; preserve historical meanings | Audit sections 1–13 |
| November 5, 2026 | Best Fix and Safest Fix presented for later choice | Best: small participation and feedback persistence plus reporting/failure extensions. Safest: restricted manual registers with a narrower report/failure solution. Neither is implemented or approved by discovery authorization | Audit section 12 |
| November 5, 2026 | Implementation-level metric decisions remain pending | Self-test sharing, exact eligibility, withdrawal/re-enrollment, seven-day calendar/maturity and retention/disclosure rules require explicit approval | Audit sections 3, 9, 10 and 17 |

The initial audit made no implementation or milestone-sequencing changes. The subsequent One-Day Directive authorized the narrowed development implementation; launch dates, billing, membership types, existing Day 40 definitions and production settings remain unchanged.

| Date | Subsequent approval | Scope / evidence |
|---|---|---|
| November 5, 2026 | Owner One-Day Implementation Directive | Approved Git preservation, independent explicit participation, existing-evidence activation reporting, durable optional feedback, bounded failure capture and focused testing; no production deployment. Implemented evidence is appended in section G. |

## E. Risks and blockers

| ID | Active issue / owner | Impact | Required next action | Resolution evidence |
|---|---|---|---|---|
| B-05 | Production deployment/source freshness — authorized operations owner | Local tests do not prove deployed code or current production capture | Approve deployment separately, apply additive migrations, verify deployed sources and protected report | Pending; no production change performed |
| B-06 | Disclosure/retention review — program owner | Real-cohort participation and private feedback must match the approved operating policy | Review the displayed participation disclosure, retention and admin access before invitations | Pending; minimum disclosure and existing privacy-policy link implemented |
| B-08 | Minimum scope limitations — program owner | No pre-signup invite delivery, re-enrollment history, advanced return analytics or full failure denominator | Use existing-member invitations and current-cohort report; approve future extensions separately | Documented in implementation runbook; no unsupported claims |

Prior B-01 official participation, B-02 minimum metric decision, B-03 durable feedback and B-07 minimum implementation capacity are resolved for this delivery by the explicit directive and validated implementation. B-04 is resolved for bounded explicit failures; comprehensive failure-rate denominators remain outside scope. The original audit remains the historical record.

The prior scheduler/Cloudflare incident remains resolved per the owner; no regression was observed or reopened. No legacy development accounts were repaired. New tests used disposable fixtures.

Repository note: the two original beta documents were explicitly included in preservation commit `645c258`; the `docs/` ignore rule remains. Explicitly include the new implementation runbook in a future implementation commit.

## F. Next actions

1. Review the functioning development report at `/fpw/admin/beta-program.cfm` and the [implementation/deployment runbook](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/beta-program/implementation.md).
2. Complete the program owner's participation disclosure/retention review, then authorize production deployment separately if ready.
3. Follow the runbook to apply the two additive migrations and verify production sources/admin authorization before enrolling real testers.
4. Invite existing members only after BETA-04 acceptance. New recruits use existing registration before the admin records an invitation.

The one-day minimum is implemented and validated in development. Prior 8–13 day estimates described the broader audit recommendation; they are historical estimates, not remaining work for this narrowed delivery. March 21 and May 31 targets are unchanged. No advanced seven-day reporting, billing change, scheduler analytics or production deployment is authorized by completion of this assignment.

## G. Change history

### November 5, 2026 — Initial BETA-01 audit and register

- Created the two authorized documents, including the 18-section audit, event matrix, 12-metric scorecard, evidence catalog and P0/P1/P2 options.
- Recorded the approved framework as BETA-00 Complete and the completed scoped discovery as BETA-01 Complete. BETA-02 through BETA-13 remain Not Started.
- Inspected current CFML/JavaScript/reporting/tests, local schema/aggregates and the existing feedback form without submitting it.
- Executed 59 existing offline/synthetic tests: 59 passed, 0 failed, 0 skipped. Historical CF/browser/production evidence is labeled historical and was not rerun.
- Recorded HEAD `6c1051ee92e60ac613523264626c24b946e59831` and SHA-256 coverage for all 18 pre-existing pending files before documentation creation; no existing pending work was edited.
- No application/test/configuration/database changes, enrollment, promo redemption, live notification, production capture, deployment or commit was performed.
- Preserved March 21 and May 31 targets, resolved-incident status and all unknown beta outcomes.

**Update policy:** On future assignments explicitly involving the beta program, append dated changes when new milestone evidence is produced. Update status only with a linked deliverable/acceptance result and the relevant approval. Preserve previous decisions and completion evidence; never silently rewrite historical definitions or treat elapsed time as completion. Keep this program separate from First 90 Days.

### November 5, 2026 — One-Day minimum implementation completed

- Owner explicitly approved implementation in priority order: preserve Git, participation, activation reporting, feedback, bounded failures, focused regression and progress update. This supersedes the earlier audit-only stop boundary for this scoped minimum; it does not authorize production deployment.
- Reviewed and committed the 20 legitimate pending files, including both beta documents, as `645c25839b3f3218355d7e241a64200971d99b79`; verified `origin/main` at that exact commit before application edits. The ignore rule was not changed.
- Added independent invitation/explicit self-acceptance/withdrawal with optional owned promotional entitlement reference. Current enrolled members form the minimum reporting cohort; no Premium grant or promo redemption automatically enrolls them. Acceptance time is preserved on replay; withdrawn participation is terminal in this version.
- Added protected batch activation reporting and IDs-only JSON export. Existing Day 40 accepted-send predicates are reused without editing Day 40 files/definitions. Pre-enrollment shares, clicks/links, uncertain sends, duplicate evidence and current ownership conflicts cannot inflate unique activated members. Self-addressed selected-contact sends retain existing product semantics; no inbox/access verification is claimed.
- Added optional durable feedback to the existing form, before mail, with session-derived identity, submission deduplication and audited admin triage. Added only database/required-save-evidence failure events with bounded metadata and log fallback.
- Applied both new migrations only to local MySQL `FPW`. Isolated, network-disabled MariaDB 10.6.24 validation passed both migrations plus wrong-schema, rerun, invalid enrollment and invalid feedback-state rejection. The disposable MariaDB container was removed.
- Final CF runner: **65 specs, 65 passed, 0 failed, 0 errors, 0 skipped**: 13 participation, 25 report, 14 feedback, 13 failure. Disposable fixture users remaining: 0. Tests include actual SQL evidence, receipt ownership, rollback survival, telemetry failure and API component compilation.
- Existing Node regression: **59 passed, 0 failed** (52 Day 40 + 7 member-activity contracts). Day 40 source files remain unchanged.
- Chromium browser suite: **2 passed**, covering admin/member authorization, CSRF, explicit acceptance, repeated acceptance, current-cohort report, mobile withdrawal and unchanged access. MCP browser checks additionally verified feedback admin status update and absence of private feedback in JSON export.
- Existing support regression through MCP: **38 named checks passed**; four intended messages captured in MailHog and deleted. Five genuine enrolled feedback records included the SMTP-refusal case; honeypot submissions did not persist. All related UI fixture accounts/feedback were subsequently removed; beta participation and feedback tables returned to zero rows.
- BETA-02 and BETA-03 marked Complete using the directive and test evidence above. BETA-04 is In Progress because production deployment/source verification remains pending. Real beta outcomes remain Not measured; synthetic fixtures are not beta results.
- Only the prerequisite preservation commit was pushed. The new implementation remains available in the development working tree for review. Exact files, operating instructions, deployment and data-preserving rollback are in the implementation runbook. No production, billing or monitoring behavior was changed.

- Final browser rerun passed 2/2 in 2.3 seconds. Playwright cleaned four pre-existing tracked screenshots in its default output folder; all four were restored byte-for-byte from the preserved commit. The runbook now directs future runs to a dedicated temporary output folder.
