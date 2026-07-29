# FPW production schema synchronization — 2026-07-13

Target: the FPW production schema represented by
`prod_structureOnly_Dump20260713.sql`, running MariaDB 10.5.

This package reuses the existing dated migrations as the canonical authority.
It does not copy local backup tables, rollback tables, import staging tables,
or the one-off anchorage import table into production.

## Required safety gate

1. Create and verify a current production database backup.
2. Select the FPW production database.
3. Run `00_preflight.sql`.
4. Stop unless every automated check returns `PASS`.
5. Manually confirm that the returned `userId=1` identity is the intended
   initial ADMIN account.
6. Review the estimated row counts and schedule the ALTER statements for an
   acceptable maintenance window. MariaDB DDL can commit independently.

The preflight is read-only.

## Execution order

Run these files against the same selected FPW database, in this exact order:

1. `db/migrations/prod/20260713_schema_sync/00_preflight.sql`
2. `db/migrations/20260528_01_upgrade_email_optout.sql`
3. `db/migrations/20260710_01_admin_promotions_entitlements.sql`
4. `db/migrations/20260711_01_vessel_images.sql`
5. `db/migrations/20260711_02_admin_authorization.sql`
6. `db/migrations/20260713_01_lock_delay_model.sql`
7. `db/migrations/prod/20260713_schema_sync/99_postflight.sql`

The migrations are additive and idempotent. The lock-delay migration also
upserts the canonical 68-row model so rerunning it restores the approved
timing values without deleting unexpected rows.

## Expected postflight

Every check in `99_postflight.sql` must return `PASS`. In particular:

- all 30 required additive columns and 11 additive indexes exist;
- `fpw_admin_audit_log`, `vessel_images`, and `lock_delay_model` exist;
- the three new tables use `utf8mb4_unicode_ci`;
- the vessel-image and lock-model foreign keys use the approved rules;
- all 68 lock models exist with the approved timing distributions;
- existing `email_optout` rows have normalized hashes;
- userId 1 has an active, non-revoked ADMIN entitlement and audit record.

If any migration or postflight check fails, stop application deployment and
restore the verified database backup. Do not attempt ad hoc repair in
production because the package includes DDL, data backfills, and an explicit
ADMIN entitlement grant.
