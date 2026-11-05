# FPW Founding Beta Program — Progress Register

This is the authoritative project-progress register for the FPW Founding Beta Program. It is separate from the First 90 Days workbook and daily roadmap. Evidence references describe what has actually been established; proposed work is not implementation approval.

## A. Program overview

| Item | Current record |
|---|---|
| Program | FloatPlanWizard Founding Beta Program |
| Current phase | Phase 1 discovery completed; awaiting BETA-02 design/implementation approval |
| Latest update | November 5, 2026 |
| Target soft launch | March 21, 2027 |
| Target hard launch | May 31, 2027 |
| Current status | BETA-01 Complete; implementation and invitations Not Started in this register |
| Readiness | Existing transactional activity, sharing receipts, entitlements, monitoring ledgers and Day 40 reporting provide a strong base. Official beta enrollment, enrollment-relative reporting, structured feedback and focused failure visibility need an approved solution before invitations. |
| Production evidence boundary | Current development source/local read-only checks and historical validation were inspected. No fresh production capture, production test, deployment or live notification was performed. |
| Beta outcomes | Not measured. Local test rows and historical non-beta reporting are not beta outcomes. |

The [measurement audit](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/beta-program/measurement-audit.md) contains the event coverage matrix, evidence references E01–E29, scorecard, implementation options and estimates.

The audit classifies the 12 named collection/reporting contracts as 5 fully supported, 6 partially supported and 1 not supported. This is a category count, not an analytics-coverage percentage or production certification.

## B. Milestone register

Dates are recorded only where supported. “Not recorded” does not imply a missed date. Future implementation/QA owners remain unassigned; role names below identify the decision or responsibility, not a resource commitment.

| ID / milestone | Status | Owner | Start / verified completion | Deliverables | Acceptance criteria | Evidence | Dependencies | Next action |
|---|---|---|---|---|---|---|---|---|
| BETA-00 — Define beta journey and success metrics | Complete | Program owner | Start not recorded / framework verified November 5, 2026 | Approved four dimensions, primary KPI, supporting metrics and launch targets | Approved framework supplied; primary activation requires a successful meaningful share, not a click | November 5 Phase 1 brief, sections 2 and 17; audit sections 1 and 3 | None | Resolve implementation-level eligibility, self-share and return-window details in BETA-02 without changing the approved framework |
| BETA-01 — Audit existing analytics and enrollment capabilities | Complete | Codex, under program-owner scope | November 5, 2026 / November 5, 2026 | Measurement audit and this separate register | Trace collection boundaries, assess all requested areas, record evidence/unknowns, propose minimal options, keep changes limited to the two documents | Audit sections 1–18; 59/59 offline tests; source/schema/browser evidence and unchanged-file check | BETA-00 | Stop implementation work pending BETA-02 approval |
| BETA-02 — Approve minimum measurement implementation | Not Started | Program owner | Not started / — | Approved minimal design, definitions, privacy treatment and bounded implementation scope | Select Best Fix or Safest Fix; approve participation, qualifying share, cohort/withdrawal, seven-day return and acceptance criteria | Pending; proposals in audit sections 3, 10 and 12 | BETA-00, BETA-01 | Review options and explicitly authorize the selected next phase |
| BETA-03 — Implement missing collection and feedback capabilities | Not Started | Implementation owner — unassigned | Not started / — | Approved P0 cohort, report, feedback and failure capabilities | Approved scope implemented with required tests; preserve entitlements, Day 40 and notification semantics | None yet | BETA-02 | Begin only after explicit implementation approval |
| BETA-04 — Validate reporting and admin visibility | Not Started | QA/reporting owner — unassigned | Not started / — | Synthetic/disposable validation, privacy-safe reports, authorized production source checks | Counts reconcile to authoritative outcomes; unknowns visible; admin access/privacy verified; current production evidence compatibility established | None yet; proposed strategy in audit section 14 | BETA-03 | Validate selected implementation and deployment/capture evidence |
| BETA-05 — Invite and enroll first beta cohort | Not Started | Program owner | Not started / — | Restricted invitation register and accepted cohort | Explicit acceptance recorded separately from access; privacy/disclosure and P0 acceptance complete; invitations separately authorized | None yet | BETA-02, BETA-04 | Approve invitation operation after readiness checks |
| BETA-06 — Complete initial tester activation review | Not Started | Program/reporting owner — unassigned | Not started / — | Enrollment-based activation, latency, readiness and coverage report | Verified shares reconciled; eligible denominator and unknowns disclosed; optional feedback does not gate activation | None yet | BETA-05 and sufficient observation | Collect an authorized cohort snapshot and review actual evidence |
| BETA-07 — Resolve priority beta findings | Not Started | Engineering/QA owner — unassigned | Not started / — | Triaged P0/P1 issues with resolution/retest evidence | Agreed blocking issues resolved or explicitly accepted; no status change based solely on a proposed fix | None yet | BETA-06 or independently verified beta findings | Triage actual findings and seek scoped fix approval |
| BETA-08 — Complete monitoring and reliability acceptance | Not Started | QA/operations owner — unassigned | Not started / — | Approved reliability evidence across lifecycle, check-in and notification paths | Separate scheduler execution, application completion, accepted send and unknown outcomes; preserve resolved-incident status | No beta acceptance evidence yet; owner reports prior live test success | BETA-04, approved QA scope; may run alongside BETA-06/07 | Define and execute the separately approved acceptance checks |
| BETA-09 — Conduct soft-launch readiness review | Not Started | Program owner | Not started / — | Go/no-go decision and unresolved-risk register | Activation/retention/reliability/privacy reviewed; blocking findings resolved or explicitly accepted | None yet | BETA-06, BETA-07, BETA-08 and required P1 reporting | Review evidence before March 21 |
| BETA-10 — Complete March 21 soft launch | Not Started | Program/release owner — unassigned | Target March 21, 2027 / — | Approved soft launch and verification record | Authorized release completed and verified; target date alone is not completion | None yet | BETA-09 and explicit release approval | Execute approved launch when ready |
| BETA-11 — Review post-soft-launch activation and retention | Not Started | Program/reporting owner — unassigned | Not started / — | Post-launch activation, mature return and repeat-use report | Cohort/window/version identified; mature denominators and coverage limits preserved | None yet | BETA-10 and mature observation windows | Review verified post-launch outcomes |
| BETA-12 — Conduct Memorial Day hard-launch readiness review | Not Started | Program owner | Not started / — | Hard-launch go/no-go and accepted-risk decision | Post-soft-launch findings and reliability evidence meet approved release criteria | None yet | BETA-11 and resolution of blocking findings | Review evidence before May 31 |
| BETA-13 — Complete May 31 hard launch | Not Started | Program/release owner — unassigned | Target May 31, 2027 / — | Approved hard launch and verification record | Authorized deployment and post-launch checks verified | None yet | BETA-12 and explicit release approval | Execute approved launch when ready |

BETA-00 completion refers to the supplied approved measurement framework, not approval of the new implementation-level definitions proposed by this audit. BETA-02 remains unstarted. No later milestone is complete merely because supporting FPW functionality already exists.

## C. Current beta metrics

All outcomes below are **Not measured**. The application has useful evidence sources, but no verified official beta cohort/report exists in this audit. Do not substitute development fixtures, prior production members or recovery enrollment.

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

The audit proposes accepted application sharing as the primary success boundary, with explicit qualification details still awaiting BETA-02. No claim of inbox delivery, human reading, or comprehensive failure-rate coverage is made.

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

No change to milestone sequencing, launch dates, billing, membership types, existing Day 40 definitions or production settings was authorized or performed.

## E. Risks and blockers

| ID | Active issue / owner | Impact | Required next action | Resolution evidence |
|---|---|---|---|---|
| B-01 | Official cohort/acceptance missing — program owner and future implementation owner | No defensible eligible-beta denominator or withdrawal history | Approve and establish independent participation register, manual or persisted | Pending; acceptance/withdrawal independent of entitlement demonstrated |
| B-02 | Metric details pending — program owner | Comparisons can change with self-share, eligibility or return-window assumptions | Approve explicit KPI/return/withdrawal definitions in BETA-02 | Pending; dated approved contract |
| B-03 | Feedback is email-only — future implementation/operations owner | No reproducible optional-feedback/triage report | Approve existing-form persistence or audited manual register | Pending; linked genuine feedback and status history verified |
| B-04 | Incomplete attempt/failure coverage — engineering/reporting owner | Full technical/reliability rates cannot be asserted | Add only approved bounded failure evidence first; show unknowns; defer full denominators to P1 | Pending; scope-specific coverage and reconciliation tests |
| B-05 | Production evidence not refreshed — authorized operations owner | Development tests cannot certify current production capture/parity | Obtain approved SELECT-only capture and coverage/deployment verification before first report | Pending; fresh safe source manifest and reconciliation |
| B-06 | Privacy/disclosure/retention choices pending — program owner | Participation and feedback linkage could exceed the approved data purpose | Review minimal fields, report access, retention, withdrawal and existing analytics masking/disclosures | Pending; owner-approved policy and access/privacy checks |
| B-07 | Implementation capacity not assigned — program owner | Estimates cannot establish a delivery commitment | Select option, assign capacity and schedule validation | Pending; designated owner and approved plan |

The previously reported scheduler/Cloudflare issue is **not** an active blocker in this register: the brief reports it resolved and recent live email sending successful. No new regression was observed or investigated. Historical missing evidence is a reporting limitation, not a demand to repair old development accounts or infer failed usage.

Repository housekeeping note: the existing `.gitignore` rule ignores `docs/`, including these two newly created files. The rule was not changed and these files were not staged or committed. An authorized future documentation commit must explicitly include them; this does not change their current on-disk contents.

## F. Next actions

1. **BETA-02:** Review the [audit](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/beta-program/measurement-audit.md), select Best Fix or Safest Fix, and approve the exact minimal implementation scope.
2. Approve the participation, accepted-share, self-test, withdrawal, seven-day return, privacy and retention contracts; designate implementation/operations owners.
3. After explicit approval, implement and validate only the selected P0 gaps using disposable development fixtures and existing services.
4. Verify authorized production evidence compatibility and admin/privacy controls before inviting the first cohort.
5. Keep P1 seven-day/repeat-use and stronger reliability evidence on the pre-soft-launch plan; defer P2 convenience dashboards, screenshots and advanced analytics.

Planning estimates: Best Fix P0 **8–13 working days**, or Safest Fix **3–5 engineering days** plus recurring manual administration. P1 approximately **5–8 additional working days**. March 21 is feasible for the discovered engineering scope if approval, capacity and verification follow; this is not launch certification.

**Current stop boundary:** Audit and documentation only. No next-phase implementation or invitations may be inferred from this register.

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
