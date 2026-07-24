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

## Verification

Verification files must identify the selected database, expected tables, columns, indexes, foreign keys, and CHECK constraints. Application validation must use disposable local records and remove them afterward.

## Rollback limitations

MySQL and MariaDB DDL perform implicit commits. A rollback script cannot provide transactional rollback for table creation or removal. Every down migration must therefore be guarded and deterministic.

A rollback must refuse to drop a populated application table unless that specific destructive operation and its data handling have been explicitly authorized. Disposable validation records must be removed before the guarded rollback is run.
