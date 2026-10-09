# Companion Tracking Phase 1 completion and validation

**Status: Complete with Known Gaps.** Backend implementation and all new tracking tests pass. Two scheduler errors reproduce on unchanged HEAD; two existing global-expiration tests were deliberately excluded to avoid mutating unrelated local trip data. This is local backend proof, not mobile or production proof.

Validated on 2026-10-08 against local ColdFusion and Docker `cfdev-mysql`, database `FPW`, MySQL 8.0.43. FPW baseline was clean at `a6b944737fadb82df342151128edc4b5d2df2c3c` on `main`.

## Exact file inventory

All paths below are relative to `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw`.

| File | Change |
| --- | --- |
| `api/v1/CompanionTrackingService.cfc` | New read-only eligibility, transactional lifecycle/ingestion, latest and bounded retention/reconciliation service |
| `api/v1/companionTracking.cfc` | New bearer-only HTTP controller and input/method/body-size guards |
| `api/v1/CompanionAuthService.cfc` | Future-pairing tracking scope; optional read-only bearer resolution; existing caller defaults preserved |
| `api/v1/AdminScheduledTaskService.cfc` | New maintenance catalog alias and existing monitor-token/limit integration |
| `app/scheduled/run-companion-tracking-maintenance.cfm` | New protected maintenance runner; no schedule created |
| `database/migrations/20261008_001_companion_tracking.preflight.sql` | Local/production-operator prerequisite gate |
| `database/migrations/20261008_001_companion_tracking.up.sql` | Additive tracking schema |
| `database/migrations/20261008_001_companion_tracking.verify.sql` | Columns, indexes, keys and constraints verification |
| `database/migrations/20261008_001_companion_tracking.down.sql` | Explicitly confirmed, empty-table-only rollback |
| `privacy_policy.cfm` | Optional automatic location, safety separation, captain-only retrieval and 90-day disclosure |
| `tests/specs/CompanionTrackingSpec.cfc` | 90 focused contract/security/storage/lifecycle/retention/non-interference tests |
| `tests/support/CompanionTrackingFailingStorage.cfc` | Nonremote test subclass proving whole-transaction rollback after a second-insert failure |
| `tests/companion-tracking-runner.cfm` | Explicitly confirmed local/dev-only disposable-fixture runner |
| `tests/specs/AdminScheduledTaskServiceSpec.cfc` | Maintenance catalog/guard regression coverage |
| `docs/companion-tracking-phase1.md` | API, lifecycle, normalization, retention, deployment and Phase 2 contract |
| `docs/companion-tracking-phase1-validation.md` | This completion report |

No Companion repository file changed. No existing current-trip resolver, check-in service, Active Cruise/Follow view, trip lifecycle, monitor, credit/receipt, entitlement/billing or recovery implementation changed. No dependencies changed. No commit, push or deployment was performed for this phase.

## Snapshot and preservation

Pre-edit snapshot directory:
`/Users/lawrencewald/.codex/backups/companion-tracking-phase1-20261008-150759`

Contains HEAD/status snapshots, binary Git patches, file archives and SHA-256 manifests for both repositories. Existing backend files also have MCPCF patch backups. The Companion baseline had 20 modified tracked files and two untracked files at HEAD `fdebda62527fe0809b7631ff147feafd4b2d78e8`. Final SHA-256 comparison of all 22 files and Git status comparison were unchanged.

## Schema and migration results

- `companion_tracking_sessions`: 20 columns including two nullable generated ACTIVE uniqueness keys.
- `companion_location_samples`: 11 columns including immutable payload SHA-256; no altitude.
- Total: 31 columns, 15 indexes, five cascading foreign keys and eight CHECK constraints.
- Parent types verified: signed INT user/Float Plan/route IDs; BIGINT UNSIGNED companion-device ID; all InnoDB.
- UUID identities are unique per device/session and session/sample. Indexed VIRTUAL keys enforce one ACTIVE session per device and Float Plan while allowing DRAINING history.
- UTC DATETIME(3) preserves capture milliseconds.

Preflight passed. Initial STORED generated columns produced MySQL `ERROR 1215`; inspection confirmed no partial tracking tables. The corrected VIRTUAL form passed up and verify, then an unconfirmed rollback was correctly refused. Confirmed empty rollback passed. Second preflight → up → verify passed. Final table/column/index/FK inspection passed. Schema remains installed locally; both tables contain zero rows after tests.

Best Fix and Safest Fix coincide for the approved scope: isolated additive tracking storage and read-only operational evidence. VIRTUAL generated keys are the locally proven form compatible with cascading deletion. MariaDB is migration-gated but was not executed in this validation. Production deployment remains separately approved work.

## Authentication and API

New pairings add `companion:tracking` alongside `companion:current` and `companion:checkin`. Existing token rows retain their scopes. Old credentials receive HTTP 403 `REPAIR_REQUIRED` for tracking; current/check-in compatibility remains intact. Missing, invalid, expired and revoked credentials return 401. No session fallback exists.

Endpoint: `/api/v1/companionTracking.cfc?method=handle&action=<action>&returnFormat=json`.

GET: `eligibility`, `status`, `latest`. POST: `start`, `batch`, `stop`, `finish`. The full request/response examples and rejection contract are in `companion-tracking-phase1.md`. Responses explicitly acknowledge accepted and duplicate IDs; rejected samples have reasons and zero-based indexes. Database failure returns no success ACKs. Strict UTF-8 request limit is 65,536 bytes and batch limit is 100 samples. Latest orders capture time, not receive time, and is restricted to the authenticated member/device.

## Lifecycle and retention

- Start: online authorization, canonical owned active trip, UUID idempotency, atomic ACTIVE uniqueness.
- Active: capture/upload authorization at most seven days, shortened by known credential/access expiration.
- Stop: immutable capture cutoff, ACTIVE → DRAINING; at most 24 hours and never beyond authorization.
- Drain: only qualifying pre-cutoff backlog; identical acknowledged payloads remain duplicates while current authorization is valid.
- Finish: stopped sessions become CLOSED without deleting acknowledged history.
- Expiration, revocation or trip invalidation: immediately reject new storage even for earlier captures; maintenance reconciles stored session state.
- Retention: samples **90 days from capture**; CLOSED metadata **90 days from closure**. Independently named service policies, bounded deletion, no premature cascade of retained samples. Account deletion cascades tracking records.

## Tests actually run

| Coverage | Executed | Passed | Failed / errors |
| --- | ---: | ---: | ---: |
| CompanionTrackingSpec | 90 | 90 | 0 |
| AuthSecurityServiceSpec | 10 | 10 | 0 |
| RouteInstanceClosureContractSpec | 6 | 6 | 0 |
| CompletedTripViewModelServiceSpec | 7 | 7 | 0 |
| TripPreviewServiceSpec / Active Cruise renderer | 16 | 16 | 0 |
| InactiveMemberRecoveryClassifierSpec | 32 | 32 | 0 |
| PremiumTripAccessLifecycleSpec, scoped subset | 12 | 12 | 0 |
| AdminScheduledTaskServiceSpec | 61 | 59 | 2 pre-existing errors |
| Maintenance authorization/limit checks | 9 | 9 | 0 |
| Authenticated maintenance HTTP success | 1 | 1 | 0 |

New tracking tests cover real HTTP authentication, web-session rejection, new/old pairing scope, no/draft/closed/cancelled/ambiguous/foreign/expired trips, ownership, start retries/concurrent starts, competing devices, expiry boundaries, valid/invalid/partial batches, null and scalar samples, oversized input, immutable conflicts, concurrent duplicates, forced second-insert rollback, stop retry/drain/finish/invalidation/revocation, latest/no-data/old backlog, 90-day boundaries and bounded cleanup, account/device cascading deletion, and non-interference. They also exercise legacy Companion current with an older token and no active trip, legacy check-in input rejection, and default auth usage behavior. No dedicated prior full Companion current/check-in integration bundle was found; these are narrow compatibility checks, not a complete historical client end-to-end claim.

Scheduler errors:
1. `preserves unexposed supported attributes and paused status during edit`: undefined `PORT` in CFML structure.
2. `edits numeric schedules without isDaily and preserves returned timing fields`: undefined `PORT` in `ATTRS`.

Both reproduced using pristine HEAD service/spec copies: baseline 59 total, 57 passed, same two errors. Both newly added scheduler tests pass. They were not repaired in this tracking scope.

Two lifecycle cases were skipped because they invoke the global expiration worker or real scheduler endpoint rather than limiting writes to disposable fixtures:
- `continues a scheduled batch after one row fails and reports sanitized counts`
- `keeps the Phase 1 UI minimal and the scheduled worker independently token-protected`

No new tracking test failures remain. Initial implementation/type and null-handling failures were corrected and the final full tracking suite passed. Temporary diagnostic components were removed.

The protected maintenance endpoint also returned HTTP 200/SUCCESS with limit=1 on empty tracking tables, exposing only counts and 90-day policies. Before/after counts across 15 tracking/operational/billing/recovery tables were unchanged. No actual schedule registration was needed. The existing preview bundle passed 16/16, including the real scheduled Active Cruise renderer and owner preview models.

Additional verification: MCP Playwright rendered `/fpw/privacy_policy.cfm` at 1440px and 390px; optional tracking, safety separation and 90-day text were present, with no horizontal overflow. Initial navigation reported zero console errors and one warning. `git diff --check` and whitespace checks of new source/docs/migrations passed.

## Non-interference and disposable data

**Automatic tracking changed no check-in, monitoring, overdue, Float Plan, route, credit, receipt, entitlement/billing or recovery state in the snapshot assertions.** Source inspection also confirms no writes from the tracking service to those tables.

Before/after snapshots covered users, Float Plans, route instances and leg progress, monitoring rows/events, Companion check-in events, Float Plan events/activity segments, send receipts/credits, entitlements, recovery messages and product events. Read-only eligibility additionally included device state. Sentinel fixtures included a MISSED monitor state and an existing NEED_ATTENTION check-in so the proof was not only empty-table comparisons.

Test setup intentionally created disposable users, devices/pairings, routes, ACTIVE plans, consumed-credit receipts, entitlement and recovery/monitor/check-in sentinels. Some tests deliberately changed their own plan status, token revocation/expiration, entitlement expiry or tracking timestamps to exercise rejection/retention. These were fixture operations, not side effects of GPS requests. Successful tracking writes changed only tracking rows and permitted credential usage timestamps. Cleanup removed fixtures; final queries found zero tracking fixture users/devices/routes/recovery rows and zero tracking sessions/samples.

## Production changes

**No.** No production data, migration, schedule or configuration changed. No production proof is claimed. No iOS/Android implementation, mobile environment change, background mode, permission string, native SQLite/uploader, map/Follow/Active Cruise presentation or satellite code was added.

## Phase 2 prerequisites / required approval

The backend contract is ready for iOS implementation subject to the disclosed local regression gaps. Phase 2 requires separate approval and:

- `environment.prod.ts` correction to **`https://floatplanwizard.com`**, with exact-origin HTTPS and no bearer forwarding across redirects.
- Re-pair UX for existing devices and the explicit Start/Stop/authorization-boundary contract.
- Product review of the implemented privacy disclosure and native consent/permission wording.
- Apple signing/provisioning, build tooling and a physical iPhone.
- Native background location plus durable SQLite, newest-first synchronization and explicit per-ID ACK handling.
- Physical-device tests for background/lock, offline/reconnect, permissions, expiration/revocation, stop/drain, duplicate/conflict retries, termination/reboot queue survival and explicit restart. Continuous capture after termination/reboot is not promised.

**STOP after Phase 1. Request approval for Phase 2 — iOS automatic background tracking + physical-device proof.**

## Evidence files

All execution evidence is under the snapshot directory above:
- `migrations/RESULTS.txt` and numbered migration logs.
- `companion-tracking-focused-results.json`.
- `scheduler-results.json` (modified and pristine HEAD comparison).
- `maintenance-guard-results.json`.
- `regression-focused-results.json`.
- `premium-lifecycle-regression-results.json`.
- `maintenance-success-results.json`.
- `active-cruise-preview-regression-results.json`.
