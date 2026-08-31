# FPW database migrations

FPW uses inspected SQL migration files instead of a general-purpose migration framework.

## Naming

Use `YYYYMMDD_NNN_description.up.sql`, `YYYYMMDD_NNN_description.down.sql`, and `YYYYMMDD_NNN_description.verify.sql`. A production-specific, read-only prerequisite gate may use the matching `YYYYMMDD_NNN_description.preflight.sql` name. A preflight is an adjunct to the migration trilogy and must not duplicate or replace its schema definitions.

## Execution order

1. Verify the target connection is the local `FPW` database.
2. Inspect the forward migration.
3. Apply the `.up.sql` file.
4. Run the matching `.verify.sql` file.
5. For rollback validation, inspect and run the guarded `.down.sql` file.
6. Confirm removal, then reapply and reverify the forward migration.

Example from the local MySQL container:

```sh
docker exec -i cfdev-mysql sh -lc 'mysql --protocol=socket -uroot -p"$MYSQL_ROOT_PASSWORD" FPW' < database/migrations/<migration>.up.sql
```

Use the matching `.verify.sql` or guarded `.down.sql` path for verification or rollback. The explicit `cfdev-mysql` container and `FPW` database arguments are required local-target safeguards.

Never execute the local Docker command against staging or production.

## Production execution

Production requires a separately approved deployment plan and an operator-supplied production database connection. Do not record production credentials in this repository or in shell history.

For `20260721_001_membership_premium_send_credits`, use this database-file order:

1. Select the production `FPW` database without using the SQL client's `--force` option.
2. Run `20260721_001_membership_premium_send_credits.preflight.sql`.
3. Stop if the preflight does not report `PASS`.
4. Run `20260721_001_membership_premium_send_credits.up.sql`.
5. Run `20260721_001_membership_premium_send_credits.verify.sql`.
6. Stop if verification does not report `PASS`.

The preflight does not create or modify application tables or application data. It validates the selected database, supported database engine and version, MariaDB CHECK-constraint enforcement, table absence, prerequisite tables, foreign-key column compatibility, and InnoDB parent tables. This migration supports MySQL 8.0.16 or newer and MariaDB 10.5.26 or newer within the 10.5 release series. The forward and verification files remain the only schema authority.

The complete production sequencing, configuration, application reload, Stripe webhook, smoke-test, and rollback notes are in `docs/premium-send-credit-cutover.md`.

For `20260724_001_stripe_subscription_entitlement_uniqueness`, run the `.up.sql`
and `.verify.sql` files after `20260721_001_membership_premium_send_credits` has
been applied. The forward migration refuses to add the unique Stripe
subscription binding when duplicate non-null `stripe_subscription_id` values
exist. Resolve and audit any duplicates before retrying; the migration never
deletes or merges entitlement records. The guarded rollback removes only the
exact named unique index and never changes entitlement data.

For `20260724_002_add_welcome_onboarding_seen_at`, run the `.preflight.sql`,
`.up.sql`, and `.verify.sql` files in that order without the SQL client's
`--force` option. The preflight is read-only and refuses to continue unless the
selected database is exactly `FPW`, `users.userId` has the expected definition,
and `users.welcomeOnboardingSeenAt` is absent. The forward migration captures
the current maximum `userId` and existing-user count before adding
`welcomeOnboardingSeenAt DATETIME(6) NULL DEFAULT NULL`. It backfills only users
at or below that captured cutoff, leaving later accounts `NULL` and eligible
for the welcome onboarding flow. Record the cutoff, count, and UTC timestamp
reported by the forward migration.

Rollback deletes all persisted welcome-acknowledgment timestamps. The down
migration therefore refuses to run unless the operator sets this exact
same-session confirmation immediately before sourcing the file:

```sql
SET @fpw_confirm_drop_welcome_onboarding_seen_at =
  'DROP_WELCOME_ONBOARDING_SEEN_AT';
SOURCE database/migrations/20260724_002_add_welcome_onboarding_seen_at.down.sql;
```

Prefer disabling the onboarding feature while leaving the compatible nullable
column in place when schema rollback is not explicitly required.

For `20260724_003_add_getting_started_hidden`, run the `.preflight.sql`,
`.up.sql`, and `.verify.sql` files in that order before the application
rollout, without the SQL client's `--force` option. The read-only preflight
requires the exact `20260724_002` column definition and refuses to continue
when `users.gettingStartedHidden` already exists. The forward migration adds
`gettingStartedHidden TINYINT(1) NULL DEFAULT NULL` without a data backfill:
`NULL` retains automatic visibility, `0` records an explicit Show choice, and
`1` records an explicit Hide choice.

Rollback deletes every persisted Getting Started visibility choice. The down
migration therefore requires this exact same-session confirmation:

```sql
SET @fpw_confirm_drop_getting_started_hidden =
  'DROP_GETTING_STARTED_HIDDEN';
SOURCE database/migrations/20260724_003_add_getting_started_hidden.down.sql;
```

## Single-trip access lifecycle Phase 1

For `20260801_001_single_trip_access_lifecycle`, deploy the database migration
before application code that reads or writes the new lifecycle fields. Use this
order without the SQL client's `--force` option:

1. Select the production `FPW` database.
2. Take and verify a recoverable database backup or snapshot.
3. Quiesce Premium Save & Send and float-plan lifecycle writes until verification
   completes; the DDL is not transactional and the backfill must use one stable
   deployment snapshot.
4. Run `20260801_001_single_trip_access_lifecycle.preflight.sql` and stop unless
   it reports `PASS`.
5. Run `20260801_001_single_trip_access_lifecycle.up.sql` once.
6. Run `20260801_001_single_trip_access_lifecycle.verify.sql` and stop unless it
   reports `PASS`.
7. Deploy and reload the matching application release, then restore writes.

The forward migration repeats the exact source-column and CHECK-enforcement
guards in its own database session. Its cross-table DDL still uses implicit
commits. If any forward DDL statement fails, stop with writes quiesced: do not
rerun the up migration and do not run the guarded down migration against a
partial object set. Inspect the exact objects left in `information_schema` and
restore the verified database snapshot or prepare an explicitly reviewed manual
repair before continuing.

The preflight reports safe internal IDs and refuses unsafe credit, receipt,
member, float-plan, or active-authorization bindings. It reports historical
general-Premium interval values as unproven rather than fabricating Monthly or
Annual history. Canonical active Basic plans are excluded only when their latest
monitoring record proves `monitoring_mode = 'basic'`.

The forward migration extends `premium_send_receipts` with the separate access
window, membership snapshot, and access-ending fields; adds `floatplans.expiredAt`
and `floatplans.end_reason`; and adds the supporting indexes, CHECK constraints,
and exact `(member_entitlement_id, user_id)` foreign-key binding. It does not
change the existing `original_response_json` storage type. One database
`UTC_TIMESTAMP(6)` value supplies the complete rollout grace period for every
existing active credit-origin plan: start at deployment UTC and expire exactly
21 days later. Ended credit-origin plans receive historical metadata and are not
reactivated. General-Premium receipts receive no single-trip expiry, and their
historical interval snapshot remains `NULL`.

After the matching application release is live, configure a production
ColdFusion scheduled task to request this token-protected endpoint every 15
minutes:

```text
/app/scheduled/run-single-trip-expiration.cfm?token=<production monitor token>
```

The endpoint uses the existing application monitor token, defaults to a bounded
batch of 100, and accepts an optional `limit` from 1 through 500. Keep the token
out of the repository, deployment logs, and validation output. Repository code
does not create the ColdFusion scheduled task; production scheduling is a
separate operator action. Request-time authorization still enforces the exact
database UTC expiration boundary between scheduled runs.

## Day 36 departure reminders

After migration `20260831_001_departure_reminder_deliveries` and the matching
application release are deployed, configure a production ColdFusion scheduled
task to request this token-protected endpoint every 15 minutes:

```text
/app/scheduled/run-departure-reminders.cfm?token=<production monitor token>
```

The endpoint uses the existing application monitor token, defaults to a bounded
batch of 100, and accepts an optional `limit` from 1 through 500. Each reminder
has a 30-minute due window: the pre-departure occurrence opens two hours before
the persisted UTC departure, and the not-started occurrence opens 30 minutes
after it. The delivery ledger and its unique occurrence key prevent repeated or
concurrent scheduler runs from sending the same reminder for the same scheduled
departure. A materially changed `departureTimeUTC` creates a new occurrence.
Known failed sends may be reclaimed only while the occurrence window remains
open and only up to three total attempts. A `CLAIMED` delivery is never
automatically reclaimed, because SMTP may have accepted the message before an
interrupted worker recorded `SENT`.

Keep the token out of the repository, deployment logs, and validation output.
Repository code does not create the ColdFusion scheduled task; production
scheduling remains a separate operator action. Do not enable this task until the
ledger migration and matching application release are both live.

Rollback is destructive to the new lifecycle metadata. First place Premium
Save & Send and all trip-lifecycle request paths in maintenance, drain in-flight
requests, and stop the expiration task. While that traffic remains quiesced,
deploy and reload application code that does not require these columns, run the
guarded down migration, verify the expected schema removal, and only then
restore traffic. This avoids both old-code/new-schema receipt failures and
in-flight Phase 1 requests reaching a schema whose lifecycle columns have been
dropped. The down migration deliberately leaves every `EXPIRED` status
unchanged and never restores, refunds, or deletes credits or receipts. It
requires this exact same-session confirmation:

```sql
SET @fpw_confirm_drop_single_trip_access_lifecycle =
  'DROP_SINGLE_TRIP_ACCESS_LIFECYCLE';
SOURCE database/migrations/20260801_001_single_trip_access_lifecycle.down.sql;
```

Because each down-migration DDL statement commits independently, a partial down
failure is not automatically rerunnable. Keep traffic quiesced, stop, and use
the verified backup or an explicitly reviewed manual repair before continuing.

Once any plan has become `EXPIRED`, this destructive schema rollback is not a
reapplicable rollback path: it preserves the `EXPIRED` status while removing the
timestamps and reason needed by the forward preflight and CHECK constraint.
Reapplying then requires an explicitly reviewed forward repair using the
verified pre-rollback backup; the migration intentionally will not guess or
reconstruct those lifecycle timestamps.

## Verification

Verification files must identify the selected database, expected tables, columns, indexes, foreign keys, and CHECK constraints. Application validation must use disposable local records and remove them afterward.

## Rollback limitations

MySQL and MariaDB DDL perform implicit commits. A rollback script cannot provide transactional rollback for table creation or removal. Every down migration must therefore be guarded and deterministic.

A rollback must refuse to drop a populated application table unless that specific destructive operation and its data handling have been explicitly authorized. Disposable validation records must be removed before the guarded rollback is run.
