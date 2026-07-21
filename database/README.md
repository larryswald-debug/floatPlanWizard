# FPW database migrations

This directory contains reviewed, manually executed FPW schema migrations. It is intentionally not a general-purpose migration framework.

## File naming and execution order

Migration files use `YYYYMMDD_NNN_description.direction.sql` names. Apply `.up.sql` files in ascending filename order. Run the matching `.verify.sql` immediately after each forward migration. A `.down.sql` file is an explicit, guarded rollback for only the objects created by its matching forward migration.

The Phase 1 introductory-trip files are:

1. `migrations/20260721_001_introductory_trip_foundation.up.sql`
2. `migrations/20260721_001_introductory_trip_foundation.verify.sql`
3. `migrations/20260721_001_introductory_trip_foundation.down.sql` only when an approved rollback is required

Inspect each SQL file before execution. These scripts select the `FPW` schema explicitly and must not be run against staging or production as part of local validation.

## Local Docker/MySQL procedure

First prove that the application datasource and the Docker schema are the same local database. The `fpw` ColdFusion datasource should report `FPW`, MySQL 8.0, and the same container hostname reported by the Docker query.

The container commands below intentionally read the root password from the container environment; they do not put a password literal in shell history.

```sh
docker exec cfdev-mysql sh -lc 'exec mysql --protocol=socket -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "SELECT DATABASE(), VERSION(), @@hostname, @@port;" FPW'
docker exec -i cfdev-mysql sh -lc 'exec mysql --protocol=socket -uroot -p"$MYSQL_ROOT_PASSWORD" FPW' < database/migrations/20260721_001_introductory_trip_foundation.up.sql
docker exec -i cfdev-mysql sh -lc 'exec mysql --protocol=socket -uroot -p"$MYSQL_ROOT_PASSWORD" FPW' < database/migrations/20260721_001_introductory_trip_foundation.verify.sql
```

The expected target is the local `FPW` schema in the `cfdev-mysql` container. Stop if the schema, server hostname, or MySQL version does not match the local application datasource. Never substitute staging or production connection details.

## Verification

The verification script reports the selected schema, MySQL version, table engines, column definitions, indexes, foreign keys, CHECK constraints, row counts, and a final `PASS` or `FAIL` result. A forward migration is not complete until the final result is `PASS` and the application service validation also succeeds.

## Guarded rollback

MySQL implicitly commits DDL statements. A rollback script therefore cannot provide all-or-nothing transactional rollback of multiple `DROP TABLE` statements. The Phase 1 rollback first inspects both new tables and raises an error before any drop when either table contains data. Only after both counts are zero does it drop the outbox table and then the entitlement table.

```sh
docker exec -i cfdev-mysql sh -lc 'exec mysql --protocol=socket -uroot -p"$MYSQL_ROOT_PASSWORD" FPW' < database/migrations/20260721_001_introductory_trip_foundation.down.sql
```

Rollback scripts must refuse to drop populated application tables unless a separately reviewed and explicitly authorized rollback identifies how that data will be handled. Disposable local validation records must be clearly identified and deleted before running this rollback; the rollback script has no data-loss bypass.
