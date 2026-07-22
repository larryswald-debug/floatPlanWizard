# FPW database migrations

FPW uses inspected SQL migration files instead of a general-purpose migration framework.

## Naming

Use `YYYYMMDD_NNN_description.up.sql`, `YYYYMMDD_NNN_description.down.sql`, and `YYYYMMDD_NNN_description.verify.sql`.

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

Never execute these commands against staging or production without a separately approved deployment plan.

## Verification

Verification files must identify the selected database, expected tables, columns, indexes, foreign keys, and CHECK constraints. Application validation must use disposable local records and remove them afterward.

## Rollback limitations

MySQL DDL performs implicit commits. A rollback script cannot provide transactional rollback for table creation or removal. Every down migration must therefore be guarded and deterministic.

A rollback must refuse to drop a populated application table unless that specific destructive operation and its data handling have been explicitly authorized. Disposable validation records must be removed before the guarded rollback is run.
