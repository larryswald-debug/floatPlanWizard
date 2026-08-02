USE `FPW`;

-- DESTRUCTIVE ROLLBACK.
--
-- This removes all stored Phase 1 access windows, membership snapshots, access
-- ending records, and float-plan expiration metadata. It deliberately does not
-- rewrite any EXPIRED plan to ACTIVE, CLOSED, or another status.
--
-- The operator must set the exact same-session confirmation before sourcing:
--   SET @fpw_confirm_drop_single_trip_access_lifecycle =
--     'DROP_SINGLE_TRIP_ACCESS_LIFECYCLE';

SET @fpw_down_20260801_001_error = NULL;
SET @fpw_down_20260801_001_columns = 0;
SET @fpw_down_20260801_001_indexes = 0;
SET @fpw_down_20260801_001_constraints = 0;
SET @fpw_down_20260801_001_expired_plan_count = 0;
SET @fpw_down_20260801_001_ended_access_count = 0;
SET @fpw_down_20260801_001_is_mariadb =
  LOWER(VERSION()) LIKE '%mariadb%';

SELECT COUNT(*)
INTO @fpw_down_20260801_001_columns
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND (
    (
      TABLE_NAME = 'premium_send_receipts'
      AND COLUMN_NAME IN (
        'member_entitlement_id',
        'membership_interval_snapshot',
        'access_started_at_utc',
        'access_expires_at_utc',
        'access_ended_at_utc',
        'access_end_reason'
      )
    )
    OR
    (TABLE_NAME = 'floatplans' AND COLUMN_NAME IN ('expiredAt', 'end_reason'))
  );

SELECT COUNT(DISTINCT CONCAT(TABLE_NAME, '|', INDEX_NAME))
INTO @fpw_down_20260801_001_indexes
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'FPW'
  AND (
    (TABLE_NAME = 'member_entitlements' AND INDEX_NAME = 'uq_member_entitlements_receipt_binding')
    OR
    (
      TABLE_NAME = 'premium_send_receipts'
      AND INDEX_NAME IN (
        'ix_premium_send_receipts_due_access',
        'ix_premium_send_receipts_entitlement_binding'
      )
    )
  );

SELECT COUNT(*)
INTO @fpw_down_20260801_001_constraints
FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'FPW'
  AND (
    (
      TABLE_NAME = 'premium_send_receipts'
      AND CONSTRAINT_NAME IN (
        'fk_premium_send_receipts_entitlement_binding',
        'chk_premium_send_receipts_access_window',
        'chk_premium_send_receipts_membership_snapshot',
        'chk_premium_send_receipts_access_end'
      )
    )
    OR
    (TABLE_NAME = 'floatplans' AND CONSTRAINT_NAME = 'chk_floatplans_expired_lifecycle')
  );

SELECT COUNT(*)
INTO @fpw_down_20260801_001_expired_plan_count
FROM floatplans fp
WHERE UPPER(TRIM(fp.status)) = 'EXPIRED';

-- Do not reference a lifecycle column until its presence has been proven. This
-- keeps an accidental pre-migration rollback attempt inside the explicit guard.
SET @fpw_down_20260801_001_count_ended_sql = IF(
  @fpw_down_20260801_001_columns = 8,
  'SELECT COUNT(*) INTO @fpw_down_20260801_001_ended_access_count FROM `premium_send_receipts` WHERE `access_ended_at_utc` IS NOT NULL',
  'SET @fpw_down_20260801_001_ended_access_count = 0'
);
PREPARE fpw_down_20260801_001_count_ended
FROM @fpw_down_20260801_001_count_ended_sql;
EXECUTE fpw_down_20260801_001_count_ended;
DEALLOCATE PREPARE fpw_down_20260801_001_count_ended;

SET @fpw_down_20260801_001_error = CASE
  WHEN DATABASE() IS NULL THEN
    'Refusing rollback: no database is selected.'
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    CONCAT('Refusing rollback: selected database is ', DATABASE(), ', not FPW.')
  WHEN COALESCE(@fpw_confirm_drop_single_trip_access_lifecycle, '') <>
       'DROP_SINGLE_TRIP_ACCESS_LIFECYCLE' THEN
    'Refusing rollback: exact same-session destructive confirmation is required.'
  WHEN @fpw_down_20260801_001_columns <> 8 THEN
    'Refusing rollback: the exact eight Phase 1 columns are not present.'
  WHEN @fpw_down_20260801_001_indexes <> 3 THEN
    'Refusing rollback: the exact three Phase 1 indexes are not present.'
  WHEN @fpw_down_20260801_001_constraints <> 5 THEN
    'Refusing rollback: the exact five Phase 1 constraints are not present.'
  ELSE NULL
END;

SELECT
  DATABASE() AS selected_database,
  @fpw_down_20260801_001_columns AS phase1_columns_found,
  @fpw_down_20260801_001_indexes AS phase1_indexes_found,
  @fpw_down_20260801_001_constraints AS phase1_constraints_found,
  @fpw_down_20260801_001_expired_plan_count AS expired_plans_that_will_remain_expired,
  @fpw_down_20260801_001_ended_access_count AS ended_access_records_that_will_lose_metadata,
  IF(@fpw_down_20260801_001_error IS NULL, 'PASS', 'FAIL') AS rollback_guard_status,
  @fpw_down_20260801_001_error AS rollback_refusal;

SET @fpw_down_20260801_001_guard_sql = IF(
  @fpw_down_20260801_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_rollback_refused_20260801_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_down_20260801_001_guard FROM @fpw_down_20260801_001_guard_sql;
EXECUTE fpw_down_20260801_001_guard;
DEALLOCATE PREPARE fpw_down_20260801_001_guard;

ALTER TABLE `premium_send_receipts`
  DROP FOREIGN KEY `fk_premium_send_receipts_entitlement_binding`;

-- MySQL and MariaDB use different preferred CHECK-removal syntax.
SET @fpw_down_20260801_001_drop_receipt_checks_sql = IF(
  @fpw_down_20260801_001_is_mariadb = 1,
  'ALTER TABLE `premium_send_receipts` DROP CONSTRAINT `chk_premium_send_receipts_access_window`, DROP CONSTRAINT `chk_premium_send_receipts_membership_snapshot`, DROP CONSTRAINT `chk_premium_send_receipts_access_end`',
  'ALTER TABLE `premium_send_receipts` DROP CHECK `chk_premium_send_receipts_access_window`, DROP CHECK `chk_premium_send_receipts_membership_snapshot`, DROP CHECK `chk_premium_send_receipts_access_end`'
);
PREPARE fpw_down_20260801_001_drop_receipt_checks
FROM @fpw_down_20260801_001_drop_receipt_checks_sql;
EXECUTE fpw_down_20260801_001_drop_receipt_checks;
DEALLOCATE PREPARE fpw_down_20260801_001_drop_receipt_checks;

SET @fpw_down_20260801_001_drop_plan_check_sql = IF(
  @fpw_down_20260801_001_is_mariadb = 1,
  'ALTER TABLE `floatplans` DROP CONSTRAINT `chk_floatplans_expired_lifecycle`',
  'ALTER TABLE `floatplans` DROP CHECK `chk_floatplans_expired_lifecycle`'
);
PREPARE fpw_down_20260801_001_drop_plan_check
FROM @fpw_down_20260801_001_drop_plan_check_sql;
EXECUTE fpw_down_20260801_001_drop_plan_check;
DEALLOCATE PREPARE fpw_down_20260801_001_drop_plan_check;

ALTER TABLE `premium_send_receipts`
  DROP INDEX `ix_premium_send_receipts_due_access`,
  DROP INDEX `ix_premium_send_receipts_entitlement_binding`,
  DROP COLUMN `access_end_reason`,
  DROP COLUMN `access_ended_at_utc`,
  DROP COLUMN `access_expires_at_utc`,
  DROP COLUMN `access_started_at_utc`,
  DROP COLUMN `membership_interval_snapshot`,
  DROP COLUMN `member_entitlement_id`;

ALTER TABLE `floatplans`
  DROP COLUMN `end_reason`,
  DROP COLUMN `expiredAt`;

ALTER TABLE `member_entitlements`
  DROP INDEX `uq_member_entitlements_receipt_binding`;

SELECT
  @fpw_down_20260801_001_expired_plan_count AS expired_plans_left_with_status_unchanged,
  CASE
    WHEN (
      SELECT COUNT(*)
      FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = 'FPW'
        AND (
          (
            TABLE_NAME = 'premium_send_receipts'
            AND COLUMN_NAME IN (
              'member_entitlement_id',
              'membership_interval_snapshot',
              'access_started_at_utc',
              'access_expires_at_utc',
              'access_ended_at_utc',
              'access_end_reason'
            )
          )
          OR
          (TABLE_NAME = 'floatplans' AND COLUMN_NAME IN ('expiredAt', 'end_reason'))
        )
    ) = 0
    THEN 'PASS'
    ELSE 'FAIL'
  END AS rollback_schema_status;

SET @fpw_confirm_drop_single_trip_access_lifecycle = NULL;
SET @fpw_down_20260801_001_error = NULL;
SET @fpw_down_20260801_001_columns = NULL;
SET @fpw_down_20260801_001_indexes = NULL;
SET @fpw_down_20260801_001_constraints = NULL;
SET @fpw_down_20260801_001_expired_plan_count = NULL;
SET @fpw_down_20260801_001_ended_access_count = NULL;
SET @fpw_down_20260801_001_is_mariadb = NULL;
SET @fpw_down_20260801_001_guard_sql = NULL;
SET @fpw_down_20260801_001_drop_receipt_checks_sql = NULL;
SET @fpw_down_20260801_001_drop_plan_check_sql = NULL;
SET @fpw_down_20260801_001_count_ended_sql = NULL;
