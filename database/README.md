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

## Verification

Verification files must identify the selected database, expected tables, columns, indexes, foreign keys, and CHECK constraints. Application validation must use disposable local records and remove them afterward.

## Rollback limitations

MySQL and MariaDB DDL perform implicit commits. A rollback script cannot provide transactional rollback for table creation or removal. Every down migration must therefore be guarded and deterministic.

A rollback must refuse to drop a populated application table unless that specific destructive operation and its data handling have been explicitly authorized. Disposable validation records must be removed before the guarded rollback is run.
