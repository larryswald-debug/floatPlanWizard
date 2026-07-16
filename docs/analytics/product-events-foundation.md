# Product Events Foundation

## Scope

Phase 1 provides a first-party internal event ledger and authoritative backend instrumentation for:

- `sign_up`
- `login`
- `vessel_created`
- `shore_contact_created`

It does not implement GA4 transport, browser analytics, historical backfill, or any Phase 2 event. The controlling firing-point analysis remains `docs/analytics/authoritative-event-firing-points.md`.

## Table Schema

Migration: `db/migrations/20260716_01_product_events_phase1.sql`

Table: `product_events`

| Column | Purpose |
|---|---|
| `id` | Internal auto-increment primary key |
| `event_uuid` | Unique internal UUID for the event row |
| `user_id` | Internal member identity |
| `event_name` | Allow-listed product event name |
| `entity_type` | Allow-listed event entity category |
| `entity_id` | Internal authoritative entity identity |
| `event_source` | Allow-listed backend source |
| `occurred_at_utc` | Server-authoritative UTC event time |
| `request_correlation_id` | Optional internal request UUID |
| `metadata_json` | Small allow-listed JSON object |
| `created_at_utc` | Server-authoritative UTC row creation time |
| `idempotency_key` | Internal unique event/deduplication key |

Constraints and indexes:

- Unique `event_uuid`.
- Unique `idempotency_key`; this is also the idempotency lookup index.
- `(user_id, occurred_at_utc, id)` for ordered member history.
- `(event_name, occurred_at_utc, id)` for event/date aggregation.
- InnoDB, `utf8mb4`, `utf8mb4_unicode_ci`.
- No foreign keys and no historical backfill. Existing users, vessels, and contacts do not create rows during migration.

All internal identities remain in this first-party table. They are not returned by the history API and are not transported to analytics.

## ProductEventService API

Component: `includes/ProductEventService.cfc`

### Initialization

```cfml
service = new fpw.includes.ProductEventService().init("fpw");
```

### Record

```cfml
result = service.recordEvent(
  userId = internalUserId,
  eventName = "login",
  entityType = "user",
  entityId = internalUserId,
  eventSource = "password_auth",
  metadata = { auth_method = "password" },
  idempotencyKey = internalKey,
  requestCorrelationId = request.fpwRequestId
);
```

`recordEvent()` returns `SUCCESS`, `RECORDED`, and `DUPLICATE`. It does not return the event UUID, database primary key, entity ID, user ID, idempotency key, or request correlation ID.

Validation failures return `SUCCESS=false` with a stable error code. Database failures are logged to `fpw_product_events` using only the event name, event source, and error code; the method returns a failure result instead of throwing to the calling workflow.

### Member history

```cfml
history = service.getMemberEventHistory(userId, 200);
```

Events are ordered by UTC occurrence time and internal row order. Returned entries contain only `eventName`, `entityType`, `eventSource`, `occurredAtUtc`, and allow-listed `metadata`.

### Aggregates

```cfml
counts = service.getAggregateCounts(
  startUtc = startDate,
  endUtc = endDate,
  eventName = "login"
);
```

The optional event filter must itself be allow-listed. Results are grouped by event name and UTC calendar date.

## Phase 1 Event Dictionary

| Event | Entity | Source | Metadata | Idempotency |
|---|---|---|---|---|
| `sign_up` | `user` | `member_signup` | `signup_method=password`, `account_tier=basic` | `sign_up:user:<internal user id>` |
| `login` | `user` | `password_auth` | `auth_method=password` | `login:request:<internal request UUID>` |
| `vessel_created` | `vessel` | `member_api` | `creation_source=member`; service also permits `is_first=true|false` | `vessel_created:vessel:<internal vessel id>` |
| `shore_contact_created` | `shore_contact` | `member_api` | `creation_source=member`; service also permits `is_first=true|false` | `shore_contact_created:contact:<internal contact id>` |

The key formats are internal database values. They must not be included in GA4 or any other external payload.

## Exact Firing Points

### `sign_up`

`api/v1/join.cfc:242-260` records after the `users` insert succeeds and `LAST_INSERT_ID()` yields a positive user ID. It runs before optional address processing and before the non-fatal welcome-email hook. Validation failures, duplicate-email rejection, and failed inserts do not reach this block.

### `login`

`api/v1/auth.cfc:141-158` records after password verification, successful `lastLogin` update, `sessionRotate()`, and authenticated `session.user` creation. Unknown users, wrong passwords, existing-session requests, and session restoration do not reach this block.

### `vessel_created`

`api/v1/vessel.cfc:216-233` records only inside the member insert branch after `generatedKey` produces a positive vessel identity. Update, default change, list, delete, validation failure, failed insert, and `adminVessels.cfc` paths are excluded.

### `shore_contact_created`

`api/v1/contact.cfc:130-147` records only inside the member insert branch after `generatedKey` produces a positive contact identity. Update, list, delete, float-plan association, validation failure, and failed insert paths are excluded.

## Idempotency Rules

- `sign_up`, `vessel_created`, and `shore_contact_created` use deterministic entity milestone keys.
- Repeating the service call with the same key returns `SUCCESS=true`, `RECORDED=false`, and `DUPLICATE=true`.
- `login` uses the server-created `request.fpwRequestId`, so duplicate service calls within one explicit endpoint execution deduplicate.
- A separate successful HTTP login request has a new request UUID and is intentionally another successful explicit authentication event.
- The database unique key is the final race-safe guard; service-side pre-checks are not used.
- Email, name, phone, and other PII are never idempotency inputs.

## Metadata Allow-List

The service rejects unknown event names, mismatched entity types, mismatched sources, unknown metadata keys, structured metadata values, and values outside these enumerations:

- `sign_up`: `signup_method=password`, `account_tier=basic`
- `login`: `auth_method=password`
- `vessel_created`: `creation_source=member`, optional `is_first=true|false`
- `shore_contact_created`: `creation_source=member`, optional `is_first=true|false`

Metadata is serialized only after validation and is limited to 1,000 serialized characters.

## Privacy Exclusions

Never store or transport in product-event metadata:

- Names, email addresses, phone numbers, or postal addresses.
- Vessel names, registrations, dimensions, equipment, or other vessel details.
- Shore-contact or passenger information.
- Coordinates, route/itinerary information, dates that expose travel, or free text.
- Passwords, authentication material, cookies, session identifiers, or request bodies.
- Stripe identifiers or payment information.
- Generated URLs, reset/share/verification tokens, or CSRF values.
- Application objects such as request, session, user, vessel, contact, or payload structs.

The service uses an allow-list rather than attempting to redact arbitrary input.

## Failure Isolation

Each authoritative endpoint invokes the service after its business write succeeds and encloses component invocation in a local `cftry/cfcatch`. The service also catches persistence failures internally. Either layer logs a non-sensitive error and preserves the existing successful response.

Instrumentation failure therefore does not roll back signup, authentication, vessel creation, or contact creation and is not returned to the customer as a business-operation failure. The service never silently swallows persistence failures.

## Query Examples

Ordered internal history:

```sql
SELECT event_name, entity_type, event_source, occurred_at_utc, metadata_json
FROM product_events
WHERE user_id = ?
ORDER BY occurred_at_utc, id;
```

Daily aggregate:

```sql
SELECT event_name, DATE(occurred_at_utc) AS event_date, COUNT(*) AS event_count
FROM product_events
WHERE occurred_at_utc >= ?
  AND occurred_at_utc <= ?
GROUP BY event_name, DATE(occurred_at_utc)
ORDER BY event_date, event_name;
```

Duplicate audit:

```sql
SELECT idempotency_key, COUNT(*) AS row_count
FROM product_events
GROUP BY idempotency_key
HAVING COUNT(*) > 1;
```

These are first-party administrative/database examples. Do not expose their internal columns through public endpoints or external analytics.

## Test Procedure

The integration specs create the additive table locally if absent and clean only their own test rows. They do not run a production migration.

Service suite:

```text
/fpw/tests/runner.cfm?reporter=text&bundles=fpw.tests.integration.ProductEventServiceSpec
```

Endpoint suite:

```text
/fpw/tests/runner.cfm?reporter=text&bundles=fpw.tests.integration.ProductEventEndpointContractSpec
```

Regression suites:

```text
/fpw/tests/runner.cfm?reporter=text&bundles=fpw.tests.integration.PublicSignupContractSpec
/fpw/tests/runner.cfm?reporter=text&bundles=fpw.tests.integration.AuthLoginContractSpec
/fpw/tests/runner.cfm?reporter=text&bundles=fpw.tests.integration.VesselOperatorCrudContractSpec
/fpw/tests/runner.cfm?reporter=text&bundles=fpw.tests.integration.ContactPassengerWaypointCrudContractSpec
```

Validate TestBox response headers for zero failures/errors, then run `git diff --check` and scan changed migration, service, endpoint, test, and documentation content for disallowed PII/secret patterns and any `gtag`, `dataLayer`, GA4, or browser analytics call.

## Migration and Rollback

Apply only after selecting the intended environment and taking the normal database backup:

```sh
mysql < db/migrations/20260716_01_product_events_phase1.sql
```

The migration is additive and idempotent at the table-creation level. It creates no rows and performs no backfill.

Rollback:

```sh
mysql < db/migrations/20260716_01_product_events_phase1_rollback.sql
```

Rollback permanently deletes the table and any recorded events. Review event retention/export needs before running it. Neither migration was run against production as part of Phase 1.

## Known Limitations

- There is no GA4 or other external transport.
- There is no historical backfill.
- Delivery is synchronous, failure-isolated database persistence; there is no outbox or retry worker.
- A product event can be lost when the event store is unavailable, though the failure is logged and the customer action remains successful.
- Login idempotency is request-scoped. A new successful HTTP authentication request is a new login by the approved definition.
- The service allows `is_first` for vessel/contact, but Phase 1 firing calls omit it rather than adding extra concurrency-sensitive counting queries.
- The table has no foreign keys so customer deletion/retention behavior must be explicitly designed before production lifecycle automation.
- Member history and aggregate methods are internal service methods only; no public/admin HTTP endpoint was added.
- Signup’s existing application-level duplicate-email behavior is unchanged.

## Phase 2 Recommendations

Before adding another event:

1. Approve its authoritative lifecycle definition from the controlling report.
2. Add it to the service allow-list with an explicit entity/source/metadata contract.
3. Choose a deterministic idempotency boundary.
4. Add positive, negative, retry, failure-isolation, UTC, and privacy tests.
5. Decide whether a durable outbox/retry worker is required before GA4 transport.
6. Define retention, deletion, consent, administrative access, and production monitoring for the first-party event store.
7. Add GA4 transport only as a separate consumer; do not make external delivery authoritative for the product event.
