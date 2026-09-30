# FloatPlanWizard Day 40 baseline

**Historical evidence is incomplete. See the accompanying validation.md for verification status.**

- Report UTC T: 2026-09-29T17:23:22.527189Z
- Window start W: 2026-08-30T17:23:22.527189Z
- Window: W <= action timestamp < T; lifetime measures end at T.
- Definition: Day40RetentionBaseline-v1
- Report code SHA-256: 882be6830b2fa6392e69872e22a9fa1d1ac878e9b0bcb8da315e0b2118c09354
- Source export SHA-256: dca7f402e04078eab38d0ab6a84400f904bb4f7abb8a0e5618a60bfb7a14c3ba

## Population

Examined 26; active admins excluded 2; reviewed test accounts excluded 9; other verified invalid accounts excluded 0.
Final population N = **15**. Fixture review pending: 0.

## Metrics

| Metric | Known positive | Known negative | Unknown |
|---|---:|---:|---:|
| 30-day activity | 2 | 0 | 13 |
| At least one legitimate use | 2 | 0 | 13 |
| Lifetime repeat use | 0 | 0 | 15 |
| Lifetime sharing | 0 | 0 | 15 |
| 30-day sharing | 0 | 0 | 15 |
| Lifetime completion | 1 | 0 | 14 |
| 30-day completion | 0 | 0 | 15 |
| Lifetime return after completion | 0 | 0 | 15 |
| 30-day return after completion | 0 | 0 | 15 |

- Active rate: **13.33% (2/15)**, evidenced minimum.
- Primary repeat rate: **0.00% (0/2)** — observed repeat / evidenced planning members.
- Secondary repeat rate: **0.00% (0/15)** — observed repeat / all valid members.
- Route-use uncertainty: 15 members have an unresolved classification or incomplete history.

Zero known positives is not evidence that the true total is zero. Unknowns stay in the population.

## Included members

| ID | Name | Email | Activity | Legitimate use | Repeat |
|---|---|---|---|---|---|
| 5 | Chris Wall | cwall@mita.org | UNKNOWN | YES | UNKNOWN |
| 14 | Scott Goren | scott@sbdirectinc.com | UNKNOWN | UNKNOWN | UNKNOWN |
| 17 | Rhett Dawson | rhett1999@mac.com | UNKNOWN | UNKNOWN | UNKNOWN |
| 18 | Marcus Norman | marcus1225@gmail.com | UNKNOWN | YES | UNKNOWN |
| 25 | Talia Duany | tcduany@yahoo.com | UNKNOWN | UNKNOWN | UNKNOWN |
| 30 | Ralph Frisina | ralph@ralphfrisina.com | UNKNOWN | UNKNOWN | UNKNOWN |
| 40 | Brett Hobson | brett.hobson@acgenius.com | UNKNOWN | UNKNOWN | UNKNOWN |
| 42 | coco bell | bell@email.com | UNKNOWN | UNKNOWN | UNKNOWN |
| 43 | Ann Brown | ann.rose.brown@gmail.com | UNKNOWN | UNKNOWN | UNKNOWN |
| 44 | Bambi Reigel | breigel86@gmail.com | UNKNOWN | UNKNOWN | UNKNOWN |
| 45 | Christina Hassett | christina@mita.org | UNKNOWN | UNKNOWN | UNKNOWN |
| 46 | Jonathan Walsh | jonathanwalsh393@gmail.com | UNKNOWN | UNKNOWN | UNKNOWN |
| 47 | Tesla cars | cars@email.com | UNKNOWN | UNKNOWN | UNKNOWN |
| 48 | Ted Henke | loopers2b@gmail.com | ACTIVE | UNKNOWN | UNKNOWN |
| 49 | carla page | sandy22@bellsouth.net | ACTIVE | UNKNOWN | UNKNOWN |

## Exclusions

| ID | Name | Email | Category | Reason |
|---|---|---|---|---|
| 1 | Lawrence Wald | lswald@yahoo.com | ACTIVE_ADMIN | Existing active admin-entitlement rule at T |
| 31 | Jim Lovell | lwald@floatplanwizard.com | TEST_FIXTURE | Owner explicitly reviewed these 15 real member IDs and IDs 31–39 as testing. Fresh-capture users exactly match the earlier reviewed users; no newly encountered accounts. Admins are evaluated separately at this T. |
| 32 | Lars Wald | larry@floatplanwizard.com | TEST_FIXTURE | Owner explicitly reviewed these 15 real member IDs and IDs 31–39 as testing. Fresh-capture users exactly match the earlier reviewed users; no newly encountered accounts. Admins are evaluated separately at this T. |
| 33 | Jerry Jones | lar34@floatplanwizard.com | TEST_FIXTURE | Owner explicitly reviewed these 15 real member IDs and IDs 31–39 as testing. Fresh-capture users exactly match the earlier reviewed users; no newly encountered accounts. Admins are evaluated separately at this T. |
| 34 | Jackson Jack | support@floatplanwizard.com | TEST_FIXTURE | Owner explicitly reviewed these 15 real member IDs and IDs 31–39 as testing. Fresh-capture users exactly match the earlier reviewed users; no newly encountered accounts. Admins are evaluated separately at this T. |
| 35 | LILsa May | info@floatplanwizard.com | TEST_FIXTURE | Owner explicitly reviewed these 15 real member IDs and IDs 31–39 as testing. Fresh-capture users exactly match the earlier reviewed users; no newly encountered accounts. Admins are evaluated separately at this T. |
| 36 | jimmy hack | noreply@floatplanwizard.com | TEST_FIXTURE | Owner explicitly reviewed these 15 real member IDs and IDs 31–39 as testing. Fresh-capture users exactly match the earlier reviewed users; no newly encountered accounts. Admins are evaluated separately at this T. |
| 37 | Lawrence Bmail | larryswald@gmail.com | TEST_FIXTURE | Owner explicitly reviewed these 15 real member IDs and IDs 31–39 as testing. Fresh-capture users exactly match the earlier reviewed users; no newly encountered accounts. Admins are evaluated separately at this T. |
| 38 | jacki gleason | mailadmin@floatplanwizard.com | TEST_FIXTURE | Owner explicitly reviewed these 15 real member IDs and IDs 31–39 as testing. Fresh-capture users exactly match the earlier reviewed users; no newly encountered accounts. Admins are evaluated separately at this T. |
| 39 | Callie Wald | callie@floatplanwizard.com | TEST_FIXTURE | Owner explicitly reviewed these 15 real member IDs and IDs 31–39 as testing. Fresh-capture users exactly match the earlier reviewed users; no newly encountered accounts. Admins are evaluated separately at this T. |
| 41 | jack jone | jack@email.com | ACTIVE_ADMIN | Existing active admin-entitlement rule at T |

## Definitions and limitations

- Activity requires verified substantive member action. Route rename-only/ambiguous updates, generic posts, views, logins and automatic events do not qualify.
- Zero-leg saved routes can prove activity but never establish a legitimate route/trip use.
- Repeat use requires distinct normalized uses with an evidenced strictly later beginning. Draft rebuilds, repeated edits and copy creation alone do not qualify.
- Return requires a different legitimate use beginning strictly after a verified completion.
- No member is declared inactive without sufficient observation coverage; current evidence cannot certify that coverage.
- Historical observation coverage is incomplete; absent evidence is UNKNOWN, never inferred inactivity.
- Recovery coverage markers do not certify complete Day 40 observation coverage.
- Historical route-update events may be rename-only and do not prove substantive activity.
- Legacy local/server timestamps are retained as raw evidence and receive no offset correction.
- Deleted route/trip objects and best-effort historical event writers can hide legitimate uses.
- Earliest evidenced use is not necessarily the member's true lifetime first use.
- Successful sharing describes accepted application sending evidence, not inbox delivery.
- Known-positive repeat ratios are observed evidence rates; the primary ratio is not a mathematical lower bound when both counts have incomplete history.

## Reproduction

The retained source-export.csv and population-review.json are the inputs. source-snapshot.json preserves parsed evidence. members.csv and report.json contain member-level evidence and uncertainty reasons.
Use the documented local Node CLI with these retained inputs. A fresh database capture is a new report, not a historical replay.
