# Reliable member-activity evidence

Implementation and local validation: 2026-09-04. Repository: `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw`.

## Scope and decision

The selected **Best Fix** records required activity in the same database transaction as the member's saved change. A validation, authorization, or evidence-persistence failure prevents the transaction from committing. The **Safest narrow alternative** was to retain best-effort logging and existing save-failure behavior; it was not selected because it cannot guarantee evidence coverage.

The existing 168-hour policy evaluator is unchanged. This is collection only, not proof that any account is eligible for recovery. No schema, migration, sending, scheduler, stage ledger, classifier, enrollment, CRM, pricing, referral, or unrelated lifecycle change was made.

## Discovery and canonical mutation paths

All paths below are relative to the repository above. These are server-side member commands, not browser analytics.

| Activity family | Canonical mutation path | Existing timestamp | Existing durable event | Member-initiated distinguishable? | Gap addressed |
| --- | --- | --- | --- | --- | --- |
| Vessel profile | Dashboard vessel form → `api/v1/vessel.cfc:handle(save)` → `vessels` | No profile activity timestamp | Best-effort `vessel_created` | Authenticated member endpoint; admin separate | Transaction, owner verification before default flags, typed no-op comparison, required creation/update |
| Vessel photo | `api/v1/vesselImageUpload.cfm`; vessel `removeImage` → `VesselImageService.cfc` → `vessel_images` and files | Image row timestamps | None | Internal `memberCommand=true`, default false | Atomic metadata/event, byte-identical suppression, rollback/new-file cleanup |
| Shore contact | Dashboard form → `api/v1/contact.cfc:handle(save)` → `contacts` | None | Best-effort `shore_contact_created` | Authenticated member endpoint | Owned transaction, creation/update evidence, no-op comparison |
| Operator | Dashboard form → `api/v1/operator.cfc:handle(save)` → `operators` | None | None | Member endpoint; admin separate | Owned transaction, creation/update evidence, no-op comparison |
| Passenger | Dashboard form → `api/v1/passenger.cfc:handle(save)` → `passengers` | None | None | Member endpoint; admin separate | Owned transaction, creation/update evidence, no-op comparison |
| Saved waypoint | Dashboard / Ports Library → `api/v1/waypoint.cfc:handle(save)` → `waypoints` | None | None | Persistent save only; temporary map state separate | Owned transaction, creation/update evidence, no-op comparison |
| Named route | My Routes → `routeBuilder.cfc:createUserRoute`, `setUserRouteStartWaypoint` → `user_routes` | DB creation/update timestamps, including unconditional writes | None qualifying | Private commands called by authenticated handler | Empty named routes count; active reuse does not; restoration is update |
| Generated route | Trip Planner → `routeBuilder.cfc:routegenGenerate/routegenUpdate` → `route_instances` and derived rows | DB creation/update timestamps | None qualifying | Authenticated save commands | One outer event, real route-instance ID, logical rather than generated-row comparison |
| Route leg / geometry | Route Builder add/remove/reorder, save/clear leg override, standalone segment override → `user_route_legs`, `route_leg_user_overrides`, `user_segment_overrides` | Leg/override timestamps; parent not consistently updated | None | Outer member command; nested override context defaults off | Parent-route activity or actual standalone override identity; no-op/order/geometry checks |
| Draft Float Plan | `floatplan.cfc:saveFloatPlan/saveBasicFloatPlan`; `routeBuilder.cfc:buildFloatPlansFromRoute` → `floatplans` and associations | Mixed DB/UTC detail timestamps | No qualifying server event | Member saves/builds, separate from lifecycle | Draft status under lock; one event for changed save; real generated insertion only |
| Draft selected contacts | Normal Draft save → `floatplan_contacts`; Basic notification details → `floatplan_basic_details` | No reliable association activity clock | None | Within authenticated Draft save | Logical selection comparison, not association IDs/order; one Draft event |

Before this change, five profile endpoints could return successful saves without proving a target owned row changed. Vessel defaults were modified before target verification. Generated-Draft creation lacked the explicit-vessel ownership check. Existing route/Draft transactions did not require activity evidence. All original validation/access rules remain, with these approved fail-closed ownership checks added. Cloning remains disabled.

## Exact event and identity contract

`includes/ProductEventService.cfc:recordRequiredMemberActivity(userId, eventName, entityId)` is public for internal CFC use, **not remote**. It accepts no source, metadata, timestamp, or client identity override. The authenticated mutation boundary supplies the verified owner and real persisted entity ID.

All qualifying rows have `event_source = 'member_api'`.

| Event names | Entity type | Entity ID |
| --- | --- | --- |
| `vessel_created`, `vessel_updated` | `vessel` | `vessels.vesselID` |
| `shore_contact_created`, `shore_contact_updated` | `shore_contact` | `contacts.contactId` |
| `operator_created`, `operator_updated` | `operator` | `operators.opId` |
| `passenger_created`, `passenger_updated` | `passenger` | `passengers.passId` |
| `waypoint_created`, `waypoint_updated` | `waypoint` | `waypoints.wpId` |
| `user_route_created`, `user_route_updated` | `user_route` | `user_routes.id` |
| `route_created`, `route_updated` | `route_instance` | `route_instances.id`, not generated loop-route ID |
| `route_segment_updated` | `user_segment_override` | Stored override row ID; removal uses the just-removed owned row ID |
| `float_plan_created`, `float_plan_updated` | `float_plan` | `floatplans.floatplanId` |

Seventeen names total. The existing vessel/contact creation events are reused, replacing their best-effort member calls rather than adding a duplicate. Fifteen names are new.

Metadata is `{}`, except the two reused creation names retain only `{"creation_source":"member"}`. Names, emails, field values, filenames, geometry, hashes, snapshots, and private content are not stored in activity metadata or new diagnostic logs.

The wrapper generates a private operation UUID, uses existing `recordEvent`, and requires both `SUCCESS` and `RECORDED`. Its safe exception escapes the surrounding transaction on failure. Existing best-effort event callers and Basic/Premium sharing contracts are unchanged.

## Transactions, no-ops, and source classification

| Family | Meaningful-change detection | Ownership / source / atomicity |
| --- | --- | --- |
| Five profile CRUD families | SQL `JSON_ARRAY` projections of explicit editable persisted columns before/after; storage precision/null behavior retained; noneditable fields excluded | Authenticated user, locked user and owned target, domain writes + required event in one datasource/transaction |
| Vessel photos | Uploaded/stored bytes hashed in memory; identical bytes ignore filename change; absent removal is no-op | Internal member context only, locked owned vessel/image; files prepared first; metadata + event commit together; superseded files removed after commit; failure removes only prepared files |
| Named routes | Actual insertion, inactive→active restoration, editable start waypoint and logical legs/overrides | Locked owned route/user; reopening unchanged active named route emits nothing |
| My Routes legs | Ordered leg identities, actual add/remove, normalized persisted geometry/override fields | One retained parent-route update; geometry target is re-read after route/leg locks |
| Generated routes/legs | Persisted member choices, logical ordered legs and overrides; generated IDs, timestamps, description and derived-only recalculation ignored | Locked owned canonical route instance; direct leg command emits once; nested override preparation defaults off |
| Standalone segment geometry | Canonical geometry + override fields; unchanged upsert/absent clear ignored | Owned override row lock + actual ID; valid segment verified for insert; one segment event |
| Drafts and contacts | Editable plan columns + logical contacts/passenger attributes/ordered itinerary; contact ordering and regenerated IDs ignored | Owned plan under lock; both before/after must be Draft; selected resources retain ownership checks; one event per save |
| Generated Drafts | Actual inserted Draft after successful preparation; `REUSED_EXISTING` emits nothing | Existing build transaction and locks; supplied vessel must be owned; no nested route-preparation event |

Separate profile/photo requests may produce two events. Whole-object deletion and archival do not qualify; explicit removal of a leg or geometry on a retained planning object does. Route completion, activation, automatic normalization/snapshot preparation, scheduler maintenance, login, page views and admin CRUD do not call required member activity. Browser flags cannot turn on internal member context.

Filesystem and DB commits are not a distributed transaction. The approved prepare/commit/cleanup sequence preserves the prior image on handled save failures; a process crash or post-commit filesystem deletion failure may leave an unreferenced file, not false activity or a partially committed metadata/event pair. No crash-recovery subsystem was added.

## Latest qualifying activity query

Use the exact allowlist and fixed source, not the latest generic product event:

```sql
SELECT MAX(occurred_at_utc) AS latest_activity_utc
FROM product_events
WHERE user_id = :userId
  AND event_source = 'member_api'
  AND event_name IN (
    'vessel_created', 'vessel_updated',
    'shore_contact_created', 'shore_contact_updated',
    'operator_created', 'operator_updated',
    'passenger_created', 'passenger_updated',
    'waypoint_created', 'waypoint_updated',
    'user_route_created', 'user_route_updated',
    'route_created', 'route_updated', 'route_segment_updated',
    'float_plan_created', 'float_plan_updated'
  );
```

`product_events.occurred_at_utc` is written by database `UTC_TIMESTAMP()`. For the existing policy's UTC-string input, format this UTC-valued SQL result as `YYYY-MM-DDTHH:mm:ssZ`, for example SQL `DATE_FORMAT(MAX(occurred_at_utc), '%Y-%m-%dT%H:%i:%sZ')`. Do not apply a browser/member timezone or treat a server-local date string as UTC.

A null result means **no qualifying evidence found**, not verified inactivity. First verified creation may establish a stage-entry clock; subsequent creation/edit events can reset activity. This collector does not select stages or reconstruct stage history.

Historical best-effort creation rows are positive evidence when present. Missing edits cannot be reconstructed from source rows, last login, current timestamps, or file dates. No backfill, historical enrollment, or coverage inference was performed.

## Validation and reproduction

Local runtime: ColdFusion 2025 with the existing `fpw` datasource. MCPCF source/database/endpoint tools and MCP Playwright were used; no alternate runtime/browser fallback.

- MCP Playwright: execute `tests/member-activity-evidence.playwright.js` through `browser_run_code_unsafe`. It creates two canonical accounts through the real signup UI, calls real authenticated save endpoints, invokes focused CF tests, and cleans its fixtures in `finally`.
- Latest completed run: **101 browser/API assertions passed**, **11 CF specs passed**, no failure/error. Both accounts and dependent records were removed.
- New static contract tests: `node --test tests/member-activity-evidence.test.mjs`: **7 passed**.
- A direct call to `tests/member-activity-evidence-runner.cfm?confirm=RUN_MEMBER_ACTIVITY_EVIDENCE_TESTS` without a seeded fixture runs only the two compile/validation specs. It is **not** full integration proof. The Playwright script provides its fresh fixture email for all 11 specs.
- Failure injection uses isolated per-component MockBox factories, not application flags or production mutation endpoints. The test command requires localhost:8500, POST, confirmation, an authenticated run-specific account, recent creation and durable signup evidence.

Positive coverage includes all nine required families, operator/passenger, photos, route start/legs/reorder/removal, generated routes, standalone overrides, route-less Basic Drafts, selected-contact-only edits, and named routes with no legs.

Negative coverage includes invalid input, cross-member profiles/photo/contact/explicit generated-Draft vessel, unchanged saves and geometry, identical photos, absent removals, existing-Draft reuse, contact reorder, login, views/browser-only state, and default-off system image writes. Nested generated geometry emits only the outer route event. Concurrent identical profile updates emit exactly one update after the first committed change.

Forced failure both before and after required event insertion was tested through actual mutation paths for all five profile families, generated/named routes, normal/Basic Drafts, segment geometry, and image persistence. Domain state and event rows roll back; image tests verify prior metadata/files survive and newly prepared files are removed.

UTC was bounded by database UTC observations. The latest-activity query selected the qualifying event despite a newer nonqualifying login event in a rolled-back test transaction. Ownership/entity types and minimal metadata were asserted. Actual supported waypoint deletion retained its durable creation evidence and emitted no deletion activity.

### Existing regressions

All 16 ColdFusion runners passed: **181 specs, 0 failures, 0 errors**.

| Suite | Pass |
| --- | ---: |
| Inactive-member recovery policy | 29 |
| Basic durable review sharing | 11 |
| Onboarding | 10 |
| Route continuity | 4 |
| Route reserve/planning | 9 |
| Float-plan ownership | 5 |
| Generated Draft route preparation | 3 |
| Departure reminders | 11 |
| Safe arrival | 11 |
| Route-instance completion lifecycle | 6 |
| Captain completed-trip view | 7 |
| Completed shore-contact access | 17 |
| Operational geometry snapshots | 8 |
| Scheduled/actual departure | 10 |
| Route archive | 4 |
| Premium sharing/access/credits | 36 |

Route continuity, generated-Draft preparation, departure reminders and route closure were rerun after the final locking review/cleanup adjustment; all passed. The member-api event count/maximum ID was unchanged before/after these cleaned regression runs.

Selected existing Node suites (policy, Basic durable share, expanded vessel CRUD): **15 pass, 1 pre-existing failure**. The unchanged vessel migration rollback test at `tests/vessel-crud-expanded-fields.test.mjs:260` expects a literal `MODIFY COLUMN ... VARCHAR(45) ... NULL DEFAULT NULL`; the unchanged migration uses constructed SQL. No migration or that test was changed to hide the failure. This is separate from the passing activity tests.

### Cleanup and safeguards

Pre-edit byte-exact copies and SHA-256 checksums are in `.codex-snapshots/20260904-member-activity-evidence/`:

- `manifest.json`: initial HEAD, dirty/untracked state, ten production snapshots and pre-existing file checksums.
- `regression-cleanup-snapshots.json`: four existing regression spec/runner snapshots.
- `validation-results.json`: final test/cleanup/status evidence.

Only this run's disposable accounts, owned dependent records, activity events, prepared image files, temporary test artifacts and browser tabs were cleaned. Fifteen captured welcome messages addressed to the exact run accounts were removed; six unrelated messages were retained.

Two old regression cleanup routines did not yet know about required activity. Their first run left five new orphan fixture events; those exact five were removed after matching their fixture owner/event/entity IDs. Four test-only cleanup blocks now delete their own product events before deleting their own fixture users. Reruns left no such events. No pre-existing legacy records were repaired or deleted.

No production data migration, staging, commit, push or deployment occurred. Existing dirty/untracked policy, Basic-share work, snapshots and the pre-existing PDF are preserved. See the validation artifact for final hashes/status and any limitations.

## Exact implementation files

Production (10):

- `includes/ProductEventService.cfc`
- `api/v1/vessel.cfc`
- `api/v1/contact.cfc`
- `api/v1/operator.cfc`
- `api/v1/passenger.cfc`
- `api/v1/waypoint.cfc`
- `api/v1/vesselImageUpload.cfm`
- `api/v1/VesselImageService.cfc`
- `api/v1/routeBuilder.cfc`
- `api/v1/floatplan.cfc`

New focused tests/documentation (8):

- `tests/member-activity-evidence-runner.cfm`
- `tests/member-activity-command.cfm`
- `tests/member-activity-evidence.playwright.js`
- `tests/member-activity-evidence.test.mjs`
- `tests/specs/MemberActivityEvidenceSpec.cfc`
- `tests/support/MemberActivityFailureStub.cfc`
- `tests/support/MemberActivityHarness.cfc`
- `docs/member-activity-evidence.md`

Existing regression cleanup only (4):

- `tests/specs/RouteContinuitySpec.cfc`
- `tests/specs/ScheduledActualDepartureRouteDraftSpec.cfc`
- `tests/route-continuity-runner.cfm`
- `tests/scheduled-actual-departure-route-draft-runner.cfm`

No schema changes. No activity-collection blocker remains after the recorded passing checks. Historical coverage is still incomplete by design; this work does not authorize recovery sending.
