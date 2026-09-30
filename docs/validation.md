# Day 40 fresh-capture validation

**Day 40 status: Complete with Known Historical Gaps.**

This report was generated from a fresh current-production SELECT after approval of the implementation decision gate. It is not a replay presented as a new capture. The original 2026-09-29T155156Z baseline remains unchanged.

- Database UTC T: 2026-09-29T17:23:22.527189Z
- Window start W: 2026-08-30T17:23:22.527189Z
- Window: W <= action_at_utc < T. Repeat horizon: lifetime through T.
- Native MySQL Workbench connection was verified immediately before capture: imac@%, schema fpw, MariaDB 10.6.24; verification database UTC 2026-09-29 17:22:26.226645.
- The approved SELECT-only SQL returned 14 source packets. Every packet has identical T/W and captured_at_utc=T.
- Source SHA-256: dca7f402e04078eab38d0ab6a84400f904bb4f7abb8a0e5618a60bfb7a14c3ba
- Reporter code SHA-256: 882be6830b2fa6392e69872e22a9fa1d1ac878e9b0bcb8da315e0b2118c09354
- The complete exported file is 317,079 bytes. All JSON arrays match declared row counts; no source was missing or truncated.
- Native UI observation timed out after the Save action. The newly written file was verified by its fresh database T, complete packet counts, and full parsing. No additional post-save database query is claimed.

## Approved changes

Only these three existing repository files changed during this approved follow-up:
- /Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/scripts/retention/cli.mjs — memberCsv adds report_T, report_W, definition_version and report_context on every member row.
- /Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/retention-baseline.test.mjs — standalone CSV context regression including included/excluded members, counts, denominators, limitations and preserved identities.
- /Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/day40-retention-baseline.md — output metadata and fresh-capture/replay instructions; corrected literal newline markers in prose.

Backups were captured and verified before edits. No metric, exclusion, route-normalization or SQL-query logic changed. No production data, schema, recovery enrollment/schedule, email behavior, telemetry, trip/route logic, billing or funnel behavior changed. No commit, push or deployment was performed.

## Population and results

- Examined 26 current users. Excluded active admins 1 and 41 using the application entitlement rule at T; excluded owner-reviewed tests 31–39; other verified-invalid exclusions 0. N=15.
- Included IDs: 5,14,17,18,25,30,40,42,43,44,45,46,47,48,49. No new or removed accounts were found, all previously reviewed member rows match, and no manual population review remains pending.
- The new population-review.json binds the previously authorized explicit IDs to this capture T and records the prior review reference. No future account is implicitly reviewed.
- Activity: ACTIVE 2, INACTIVE 0, UNKNOWN 13. Evidenced minimum active rate 2/15 = 13.33%.
- Legitimate route/trip use: 2 members; no proven use for 13. Earliest evidenced beginnings are not promoted to true historical first-use dates.
- Repeat: 0 verified / 15 unknown. Primary observed ratio 0/2 = 0%; secondary 0/15 = 0%. All 15 have some unresolved route-history uncertainty.
- Sharing: lifetime 0 verified / 15 unknown; trailing 30 days 0 verified / 15 unknown.
- Completion: lifetime 1 verified / 14 unknown; trailing 30 days 0 verified / 15 unknown.
- Return after completion: lifetime and trailing 30 days each 0 verified / 15 unknown.

Zero verified positives is not a known negative or proof that no one performed an action. Missing observation coverage prevents known-inactive classifications.

## Manual evidence review

| Case | Fresh retained-source evidence | Interpretation |
|---|---|---|
| Active 48 | product_events:489 (vessel 21, September 13 UTC), :508 and :510 (saved routes 27/28, September 15 UTC) | Verified owned member_api actions in the window; one member across three positives. |
| Active 49 | product_events:500 (vessel 22, September 15 UTC) | Verified owned creation inside W/T. |
| Unknown 14 and 47 | No qualifying retained activity proof | Unknown, never inferred inactive. |
| Legitimate single evidenced use 18 | user_routes:3 has one leg; :4 has zero | One substantive use; raw creation/update clocks do not establish a UTC beginning or repeat. |
| Empty routes and edits 48 | user_routes:27/:28 have zero legs; product_events:509 is a field-ambiguous update | Creates may prove activity, zero legs never prove legitimate use; update is rename-ambiguous. |
| Completed trips 5 | Owned CLOSED route-less floatplans:5/:6 with closed timestamps and substantive required Basic details | One completed member; raw clocks leave 30-day completion, repeat ordering and post-completion return unknown. |
| Cohort sharing | No successful Basic/Premium receipts or completed-share evidence for the approved 15 IDs | Zero verified sharing; all 15 unknown. Legacy initial_sent_at_raw hints for member 5 do not establish the audited successful-send contract. |
| Basic Review receipt controls | Receipts 1–3: test owner 38, plan 32; receipt 4: test owner 31, plan 38; all SENT, corresponding completed-share events absent | Receipt evidence is recognized independently, deduplicated, and excluded from population totals through the reviewed fixture list. |
| Admins | member_entitlements:17 for user 1 and :27 for user 41, active with valid starts and no expiry/revocation | Existing application rule excludes both at fresh T. |

Independent source-only reconciliation agreed with every total. Every source row array also matched the earlier production capture; only capture boundaries changed. No positive inactive, repeat or return example exists in the approved cohort. Those paths were verified with focused local fixtures, not represented as production-positive proof.

## Validation performed

- 52/52 focused tests passed using the archived report code; see tests.txt. Coverage includes UTC boundaries, distinct-member/evidence deduplication, source ownership, exclusions, unknowns, receipt recognition/overlap, zero-leg routes, repeated edits, Draft rebuilds/daily plans, source-copy lineage, strictly ordered repeat/return and CSV report-context equivalence.
- Every one of the 26 CSV member rows matched report.json for T/W/version, all seven report_context objects, member name and email. The context includes population/exclusions, raw counts, rates/denominators, unknown counts and limitations.
- Archived-code replay into a separate new directory produced six byte-identical files: source-export.csv, source-snapshot.json, population-review.json, report.json, members.csv and summary.md.
- Existing output-directory overwrite was rejected. The original baseline source, summary, report, CSV and validation checksums remain unchanged.
- Syntax and tracked/untracked whitespace checks passed. Exactly the three approved files differ from the original archived code; metric and query modules are unchanged.
- No reusable application service was modified; application mutation/browser regression runs were not required.

## Source manifest

| Source | Rows |
|---|---:|
| users | 26 |
| member_entitlements | 2 |
| vessels | 15 |
| product_events | 135 |
| user_routes | 24 |
| route_instances | 40 |
| route_instance_leg_progress | 172 |
| floatplans | 41 |
| basic_review_send_receipts | 4 |
| premium_send_receipts | 36 |
| floatplan_events | 220 |
| floatplan_captain_log_entries | 5 |
| voyage_delay_posts | 0 |
| floatplan_companion_events | 0 |

## Retained artifacts

- members.csv: standalone member export with names/emails, report context and per-member evidence.
- summary.md: concise readable baseline, identities, exclusions, rates and limitations.
- report.json: complete structured report.
- source-export.csv / source-snapshot.json: raw and parsed current-production evidence.
- population-review.json: exact capture-bound explicit population review.
- capture.sql: successful executed SELECT.
- report-code/: exact reporter modules, tests and runbook.
- tests.txt / validation.md: validation evidence.

Reproduce with the archived report-code/scripts/retention/cli.mjs using the retained source-export.csv and population-review.json and a new output directory. A fresh database capture always receives a new T; historical replay retains the original T.

## Historical limitations and future instrumentation

Incomplete event coverage, historical raw clocks, deleted objects/lineage and rename-ambiguous updates constrain inference. No blanket timezone correction or conversion of missing history into negative evidence was applied. Successful sharing represents accepted application send evidence, not confirmed inbox delivery.

Future recommendations, requiring separate approval: durable logical-use/rebuild identity, authoritative member-attributed UTC beginnings/completions, changed-field evidence, and explicit observation-coverage boundaries. None was implemented. No Day 41, Day 50 or optimization work was performed.
