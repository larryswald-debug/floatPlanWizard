# Companion tracking: Phase 1 backend contract

Phase 1 supplies server authorization, storage, retrieval and maintenance. **It does not implement background GPS on iOS or Android.** No map, trail, Active Cruise, Follow, follower or public location API is included.

**Phase 2 / release prerequisite:** Companion `src/environments/environment.prod.ts` must target **`https://floatplanwizard.com`**. The obsolete Media3 hostname is not a release destination. Phase 1 does not edit Companion files.

## Endpoint and authorization

Use `/api/v1/companionTracking.cfc?method=handle&action=<action>&returnFormat=json` on the configured FPW API origin (local development has the `/fpw` mount prefix). Send `Authorization: Bearer <paired-device-token>`. No web-session, cookie, submitted user/device ID, query token or alternate origin establishes tracking authority.

New pairings receive `companion:current,companion:checkin,companion:tracking`. Existing persisted credentials are unchanged. An otherwise valid older credential returns HTTP 403, `ERROR: REPAIR_REQUIRED`, and `rePairRequired: true`; explicitly re-pair before tracking. Missing, malformed, revoked, expired or inactive credentials return 401. Initial Start requires connectivity.

The dedicated endpoint uses read-only bearer resolution. Eligibility, status and latest do not update credential usage or tracking rows. Successful writes can update normal Companion credential usage timestamps. Every write locks/rechecks current device, trip and operational access; revocation waits for an already authorized transaction or precedes/rejects the next one.

| Action | Method | Input | Successful result |
| --- | --- | --- | --- |
| `eligibility` | GET | None | `eligible`, canonical `floatPlanId`, `routeInstanceId`, authorization boundary |
| `start` | POST | `clientSessionId`, `floatPlanId`, `routeInstanceId`, `consentVersion` | Canonical session identity, state and persisted boundary |
| `batch` | POST | `trackingSessionId`, `batchId`, `samples` | Explicit per-sample accepted, duplicate and rejected arrays |
| `status` | GET | `trackingSessionId` query parameter | Stored/effective state and current authorization reason |
| `stop` | POST | `trackingSessionId`, `captureStoppedAtUtc` | Immutable capture cutoff and bounded drain deadline |
| `finish` | POST | `trackingSessionId` | CLOSED after stopping; history remains stored |
| `latest` | GET | `trackingSessionId` query parameter | `hasLocation`, nullable `location`, session context |

Responses use uppercase `SUCCESS`, `AUTH`, `ERROR`, `MESSAGE` and quoted camelCase contract fields. Internal service `HTTP_STATUS` is removed from wire responses. IDs are positive decimal strings within signed 64-bit range; session/sample client identifiers are standard hyphenated UUIDs, normalized lowercase. Times use strict UTC `YYYY-MM-DDTHH:mm:ss.SSSZ`. Wrong methods return 405; malformed input 400; missing/foreign sessions 404; trip/session conflicts 409; oversized body/count 413; transient storage failure 503. No application rate limiter is added in this phase.

### Start

```json
{
  "clientSessionId": "690aef63-b5c0-4e46-b95a-a3e7cc1425a1",
  "floatPlanId": "123",
  "routeInstanceId": "456",
  "consentVersion": "tracking-v1"
}
```

IDs must match the bearer's one current eligible ACTIVE route-backed Float Plan. Both Float Plan and route ownership are checked in database evidence. `PremiumTripAccessService.getTripOperationalAccess(userId, floatPlanId, false)` supplies read-only operational access; the mutating current-trip resolver and operational gate are never called.

A device/client-session UUID binds immutable trip and consent context. Repeating it returns that session rather than creating/reopening one. Different context is a conflict. Nullable generated unique keys atomically enforce one ACTIVE session per device and one per Float Plan. DRAINING history can coexist with a new ACTIVE session.

The persisted authorization deadline is no later than seven days from server start, bearer expiration, known inactivity boundary and the known operational-access expiry. For membership-backed access the earliest current non-null Premium entitlement expiry is a conservative bound; it can require an earlier restart even if another entitlement would continue access. A start retry never extends the original boundary.

### Batch and acknowledgments

```json
{
  "trackingSessionId": "42",
  "batchId": "12998d34-87de-4a18-9940-4dd612a7a110",
  "samples": [{
    "clientSampleId": "46950823-d589-453c-988e-7c0c4c78b112",
    "latitude": 27.9506,
    "longitude": -82.4572,
    "accuracyMeters": 18,
    "speedKnots": 6.2,
    "courseDegrees": 182,
    "capturedAtUtc": "2026-10-08T15:30:00.000Z"
  }]
}
```

```json
{
  "SUCCESS": true,
  "AUTH": true,
  "trackingSessionId": "42",
  "batchId": "12998d34-87de-4a18-9940-4dd612a7a110",
  "sessionStatus": "ACTIVE",
  "acceptedSampleIds": ["46950823-d589-453c-988e-7c0c4c78b112"],
  "duplicateSampleIds": [],
  "rejectedSamples": [],
  "serverTimeUtc": "2026-10-08T15:30:01.000Z"
}
```

Responses also contain session context and lifecycle timestamps. HTTP 200 alone acknowledges nothing: remove local rows only for explicit accepted/duplicate IDs. Keep unacknowledged IDs unchanged for retry. `batchId` is correlation only. Rejections contain zero-based `index`, a stable `reason`, and a valid normalized `clientSampleId` when available.

- At most 100 samples and 65,536 UTF-8 body bytes; at least one sample.
- JSON numbers only: finite latitude −90..90, longitude −180..180, accuracy >0..500 metres; optional speed 0..200 knots and course >=0..<360 degrees. Numeric strings and booleans are rejected. Altitude is not stored.
- Coordinates normalize to seven decimal places; accuracy/speed/course to three, HALF_UP. Values rounding to an invalid accuracy/course boundary are rejected.
- Captures must be at/after session start, before its authorization deadline, no more than two minutes ahead of server UTC and no more than seven days old. DRAINING additionally requires capture at/before its cutoff.
- SHA-256 covers the normalized coordinate/accuracy/optional-value/capture-time tuple. After current authorization is established, a stored session/sample UUID with the same normalized payload is a duplicate even if its capture admission window subsequently changed; changed payload returns permanent `SAMPLE_ID_CONFLICT`, never an overwrite.
- Valid points in a structurally valid authorized batch can commit alongside per-index rejections. Any database exception rolls back the whole transaction and returns no successful ACK arrays. Concurrent duplicate requests serialize and then see persisted duplicate identities.

## Lifecycle and safety separation

`ACTIVE → DRAINING → CLOSED`. Start persists authorization; stop persists the captain's cutoff. Stop accepts a valid session cutoff no more than two minutes ahead of server time, consistent with capture clock tolerance. Drain ends at the earliest of cutoff +24 hours, server stop acceptance +24 hours, or session authorization expiry. Repeating Stop never changes its cutoff/deadline. Finish requires a stopped session and is idempotent; it does not delete samples.

All writes recheck live trip/device/access validity. Losing ownership, ending/cancelling/expiring the Float Plan, losing operational access, revoking/expiring the credential, or reaching the session/drain deadline blocks even previously captured backlog. Immediate authorization does not depend on maintenance. Status reports effective CLOSED with the invalidation reason when storage has not yet been reconciled; `storedSessionStatus` exposes the persisted state. Revoked credentials receive 401 and cannot use status to retrieve session data.

Latest is restricted to the same authenticated member **and device** and requires the current eligible trip/session authorization. It orders by capture time then internal sample row ID, with cutoff/authorization/retention filters; late-arriving old backlog cannot move latest backward. A CLOSED finished session can be read while its trip/session authorization remains valid. No foreign-device or follower fallback is provided.

Automatic samples never create captain check-ins, acknowledge monitoring, reset overdue state, start/end trips, change Float Plan/route state, mark a captain safe, consume credits, alter receipts, change entitlements/billing or affect recovery. Phone-reported location is not cryptographically verified physical truth: a compromised phone can fabricate GPS. GPS, offline capture and delivery remain best effort.

## Schema and retention

`companion_tracking_sessions` has the approved identities, lifecycle timestamps, state, deadlines, consent version and latest receive/capture summaries, plus nullable generated ACTIVE keys. `companion_location_samples` stores immutable normalized samples and payload hashes; no altitude. All tracking timestamps are DATETIME(3) UTC. Five cascading foreign keys remove tracking on user/device/Float Plan/route deletion; deleting a session removes its samples. Existing companion tables and account deletion flow are not refactored.

The approved best and safest implementation is this isolated additive schema/API with read-only access evidence. Indexed **VIRTUAL** generated keys preserve CASCADE foreign keys and ACTIVE uniqueness on the tested MySQL engine; STORED keys failed the database FK restriction and are not used. There are 31 columns, 15 indexes, five foreign keys and eight CHECK constraints across the two tables. Unique constraints enforce device/session UUID and session/sample UUID identities.

Retention is **90 days from capture for samples** and **90 days from closure for CLOSED session metadata**. Maintenance deletes only rows strictly older than the respective boundary. It does not delete a session still holding retained samples. Account deletion can remove data earlier. The service keeps independently named sampleRetentionDays and closedSessionRetentionDays policy values, both 90; no general retention-management feature is introduced.

`app/scheduled/run-companion-tracking-maintenance.cfm` uses the existing exact monitor-token guard and accepts integer `limit` 1..500 (default100). Each run examines at most that many nonclosed sessions, deletes at most that many old samples, and deletes at most that many old closed empty sessions. Ordering by last reconciliation/update prevents untouched valid sessions from permanently starving later sessions. Recommend approximately every five minutes, adjusted for volume/backlog. Failed runs must be retried; bounded cleanup may need multiple runs. No schedule was created or enabled.

## Migration and deployment

Files: `database/migrations/20261008_001_companion_tracking.{preflight,up,verify,down}.sql`. Follow `database/README.md` and use the explicit local Docker target:

```sh
docker exec -i cfdev-mysql sh -lc 'mysql --protocol=socket -uroot -p"$MYSQL_ROOT_PASSWORD" FPW' < database/migrations/20261008_001_companion_tracking.preflight.sql
```

Then run `up.sql` and `verify.sql` the same way, stopping on any error (never use `--force`). Preflight and up refuse existing/partial tracking tables. DDL implicitly commits: inspect partial outcomes and restore an approved snapshot rather than blindly rerunning. Guarded rollback requires both tables empty and this exact same-connection declaration before sourcing down:

```sql
SET @fpw_confirm_drop_companion_tracking = 'DROP_EMPTY_COMPANION_TRACKING';
SOURCE database/migrations/20261008_001_companion_tracking.down.sql;
```

For a separately approved deployment: verify backup/parent types/engine, run preflight → up → verify, deploy matching backend files, refresh the CF component/template cache, run authorized smoke tests, then separately configure maintenance. MariaDB compatibility is guarded by migration checks but **not runtime-tested in this local MySQL validation**. Production migration, schedule, configuration and data changes are not authorized by Phase 1 and were not performed.

## Phase 2 prerequisites and mandatory stop

Separate approval is required for **iOS automatic background tracking + physical-device proof**. Phase 1 leaves the existing Companion working tree untouched.

1. Correct `environment.prod.ts` to `https://floatplanwizard.com`; native transport must use the exact HTTPS API origin and must not forward bearer credentials through redirects or to other origins.
2. Implement native GPS → durable native SQLite queue → newest-position-first upload, using unchanged sample UUID/payloads until explicit ACK. Prove queue survival and ambiguous-response retry.
3. Add explicit start consent, location permissions/background disclosures, stop/re-pair/error UI, and locally enforced server authorization deadlines. Existing devices must re-pair.
4. Confirm approved privacy text and consent version, Apple signing/provisioning, Xcode/toolchain and physical iPhone availability before builds.
5. Test foreground/background/locked screen, airplane mode/reconnect, denied/reduced permissions, clock skew, duplicate/conflicting batches, stop/drain, server invalidation, revocation and expiration on a real iPhone.
6. Test process termination/reboot: queued points survive, but uninterrupted capture is **not promised**. Require explicit restart when the collector did not continue; reconcile the old server session. No boot-time or hidden automatic restart.

Android follows iOS proof under separate approval. Presentation and satellite transport remain later workstreams. Validation results are recorded in `companion-tracking-phase1-validation.md`.
