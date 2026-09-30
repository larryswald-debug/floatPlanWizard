# Day 40 retention baseline

This is an isolated read-only SQL exporter and offline Node report. It does not load
FPW application code, call application endpoints, connect to a database itself, send
email, or mutate application data. No dependencies or database objects are added.

The owner approved names and email addresses in the local report. Retain exports
outside the web root and repository. The approved first-baseline location is
`/Users/lawrencewald/Documents/FPW Reports/Day40/`.

## Run

From the FPW checkout, using Node:

```sh
node scripts/retention/cli.mjs sql --out '/absolute/private/path/capture.sql'
```

Open that generated SQL file in the existing authorized read-only MySQL Workbench
connection. Execute the single SELECT statement. It contains one fixed database
UTC boundary and independent source subqueries combined into one export grid.
It does not change server/session settings. Export the entire one-column result
as CSV, with its `payload` header. Both standard CSV and Workbench's native
JSON-cell envelope are accepted. Do not copy truncated result-grid cell previews.

Prepare the owner-reviewed population file for this exact snapshot:

```json
{
  "T": "the exact database T from the source export",
  "real_user_ids": ["owner-reviewed IDs"],
  "other_current_users_are_test": true,
  "reason": "Owner explicitly reviewed these real IDs and all other current IDs as tests."
}
```

This complement-based review is bound to the exact snapshot T. It must not silently
exclude new accounts in later reports. Alternatively, `exclusions` can list
`{user_id, category, reason}` entries; allowed categories are `TEST_FIXTURE` and
`VERIFIED_INVALID`. Without a reviewed list, all non-admin users stay included and
the report labels fixture review as pending. Active admins always use the existing
application entitlement rule.

```sh
node scripts/retention/cli.mjs report \
  --input '/absolute/private/path/source-export.csv' \
  --review '/absolute/private/path/population-review.json' \
  --out '/absolute/private/path/new-dated-baseline-directory'
```

The output directory must not already exist. Each baseline retains the source CSV,
parsed source snapshot, reviewed population, report JSON, member CSV, and Markdown
summary. Existing dated baselines are preserved.

Every row in `members.csv` includes `report_T`, `report_W`, `definition_version`,
and `report_context`, so a member row keeps its report context when separated from
the other output files. The JSON `report_context` contains the report's population
and exclusions, activity counts and rate, route-use counts and both repeat rates,
sharing/completion/return counts for both horizons, unknown counts, and limitations.
Raw numerators and denominators are retained within the rate objects. The existing
member identity, classification, evidence, exclusion and unknown-reason fields are
preserved, including the owner-approved names and email addresses. The Markdown
summary records the same boundaries, definition, population, exclusions, counts,
rates and limitations in readable form.

For an approved fresh production baseline, execute the default single live SELECT
again so the database supplies a new fixed T, retain that new source export, and
bind the reviewed population file to that exact snapshot T. Review any new account
IDs before applying a complement-based fixture exclusion. Generate the report in
a new dated directory; do not overwrite the first retained baseline.

To reproduce an old result, rerun its retained inputs into a new directory and
label it as a replay of the original capture T, not a fresh production capture.
Fixed-T SQL is only a coordination mechanism for a current capture; it cannot
reconstruct users, entitlements or object state from an earlier date. An earlier T
against current tables is not a supported historical population report.

The report validates all required sources, expected row counts, and identical T/W
before classification. Null/truncated JSON arrays, missing sources, inconsistent
boundaries and conflicting duplicate identities fail the report rather than
silently becoming empty data. MariaDB numeric/string row-count representations
are checked as strict nonnegative safe integers. UNION payloads explicitly use
utf8mb4_bin to tolerate differing source collations without changing the database.
MariaDB JSON aggregation limits are not changed.

## Fixed definitions

- `T` is database UTC at capture; `W = T - 30 days`.
- Activity uses `W <= action_at_utc < T`; lifetime evidence must precede T.
- A zero-leg saved-route creation may prove member activity but never legitimate use.
- Route-update events without changed-field evidence remain rename-ambiguous.
- Login, page views, recovery enrollment, tracking cutover, automated events and
  generic text/photo posts do not establish meaningful activity.
- No absent event is interpreted as inactivity. Current sources do not certify
  complete Day 40 observation coverage, so zero known-inactive classifications
  means none can be proven, not that all users are active.
- Repeat requires distinct normalized legitimate uses with strictly ordered,
  evidenced beginnings. Primary rate is repeat / evidenced planning members;
  secondary is repeat / valid population. Preserve raw counts.
- A saved route, its generated instance, reopened/rebuilt Drafts and daily plans
  are normalized; edits and copy creation alone do not establish another use.
- A different use must begin strictly after verified completion to prove return.
  Later actions on an already-begun use do not satisfy that condition.
- Sharing, completion and return are reported for lifetime and 30-day horizons,
  always with positive/unknown counts. Missing history is never a negative.

## Evidence and time handling

`export-sql.mjs` selects IDs, authorized member names/emails, ownership, status,
source-specific timestamps, safe metadata and leg counts. It does not select
passwords, reset/share tokens, emails sent, recipient addresses, note text,
location content or billing credentials.

`baseline.mjs` reconciles validated member events, committed Premium receipts,
successful Basic Review receipts, paired recovery-share outcomes, canonical
member events, captain logs, member-requested manual delays, Companion receipts
and the existing completed-trip state contract. Member totals are sets, not sums
of action/receipt rows. A shared Basic Review plan can remain DRAFT.

Product-event UTC clocks must agree with their creation clock. Source/entity,
ownership and idempotency evidence are checked. A retained event may survive
deletion of its entity; a conflicting surviving owner invalidates the evidence.

Historical canonical occurrence clocks had binding/provenance concerns.
Operation-specific owned timeline posts can corroborate database UTC; otherwise
the historical action is preserved without claiming a trustworthy window time.
Legacy `*_raw` route/plan/account clocks are never offset-corrected or treated as
authoritative UTC. Processed Companion receipts, captain logs and manual-delay
posts use their audited database UTC write clocks.

`route-uses.mjs` preserves uppercase/lowercase lineage, rejects conflicting or
missing ancestry for independent-repeat proof, collapses copies without subsequent
use proof, and preserves archived saved routes with legs. The initial named-route
creation occurs before its legs exist: that clock is retained separately and does
not date a substantive use retroactively. Route-less verified trips can establish
lifetime use even when a legacy completion clock cannot establish its UTC date.
An owned route-less Basic plan with complete required details and validated
`basic_save_send` success also proves lifetime planning. The share clock does not
become its beginning clock; beginning, repeat and return stay unknown without
separate proof. Basic Review itself requires a route-backed plan.

An earliest dated use is the earliest *evidenced* use. Historical completeness is
not certified. The primary observed repeat ratio is not mathematically a lower
bound when both its numerator and denominator have incomplete history.

## Validation

```sh
node --test tests/retention-baseline.test.mjs \
  tests/retention-route-uses.test.mjs tests/day40-export-sql.test.mjs
git diff --check
```

Manually reconcile a representative sample against the retained sources and
read-only database evidence. Record source IDs, applicable timestamps, exclusions
and the reason for each result in a validation note beside the dated baseline.
If a category has no proven production example, state that explicitly; exercise
its logic with focused local fixtures instead of creating production activity.

No reusable FPW application services are changed, so application mutation/browser
tests are not part of this exporter validation.

## Future instrumentation — not part of Day 40

Complete future lifetime/window measurement would benefit from durable logical-use
identity and creation/reuse/rebuild provenance, reliable member-attributed trip
start/completion evidence, changed-field evidence for substantive route updates,
and an explicit observation-coverage boundary. None is implemented here, and none
can reconstruct unavailable historical facts.
