-- FPW single-trip access lifecycle production preflight.
-- Read-only apart from session variables and temporary prepared statements.
-- Do not use the SQL client's --force option: a failed guard must stop deployment.

SET @fpw_preflight_20260801_001_error = NULL;
SET @fpw_preflight_20260801_001_prerequisite_tables = 0;
SET @fpw_preflight_20260801_001_prerequisite_columns = 0;
SET @fpw_preflight_20260801_001_new_columns = 0;
SET @fpw_preflight_20260801_001_new_indexes = 0;
SET @fpw_preflight_20260801_001_new_constraints = 0;
SET @fpw_preflight_20260801_001_invalid_credit_states = 0;
SET @fpw_preflight_20260801_001_consumed_missing_timestamp = 0;
SET @fpw_preflight_20260801_001_invalid_receipt_bindings = 0;
SET @fpw_preflight_20260801_001_consumed_without_receipt = 0;
SET @fpw_preflight_20260801_001_active_valid_credit_receipts = 0;
SET @fpw_preflight_20260801_001_active_credit_without_receipt = 0;
SET @fpw_preflight_20260801_001_active_multiple_candidate_credits = 0;
SET @fpw_preflight_20260801_001_active_unclassified = 0;
SET @fpw_preflight_20260801_001_active_conflicts = 0;
SET @fpw_preflight_20260801_001_receipt_plan_status_conflicts = 0;
SET @fpw_preflight_20260801_001_ended_timestamp_conflicts = 0;
SET @fpw_preflight_20260801_001_ended_chronology_conflicts = 0;
SET @fpw_preflight_20260801_001_unexpected_plan_statuses = 0;
SET @fpw_preflight_20260801_001_invalid_receipt_json = 0;
SET @fpw_preflight_20260801_001_general_interval_unproven = 0;
SET @fpw_preflight_20260801_001_check_enforcement = 1;
SET @fpw_preflight_20260801_001_target_error = CASE
  WHEN DATABASE() IS NULL THEN
    'Refusing preflight: no database is selected.'
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    CONCAT('Refusing preflight: selected database is ', DATABASE(), ', not FPW.')
  ELSE NULL
END;
SET @fpw_preflight_20260801_001_target_guard_sql = IF(
  @fpw_preflight_20260801_001_target_error IS NULL,
  'DO 0',
  'SELECT `_fpw_preflight_wrong_database_20260801_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_preflight_20260801_001_target_guard
FROM @fpw_preflight_20260801_001_target_guard_sql;
EXECUTE fpw_preflight_20260801_001_target_guard;
DEALLOCATE PREPARE fpw_preflight_20260801_001_target_guard;

SET @fpw_preflight_20260801_001_is_mariadb =
  LOWER(VERSION()) LIKE '%mariadb%';
SET @fpw_preflight_20260801_001_version_core =
  SUBSTRING_INDEX(VERSION(), '-', 1);
SET @fpw_preflight_20260801_001_version_major =
  CAST(SUBSTRING_INDEX(@fpw_preflight_20260801_001_version_core, '.', 1) AS UNSIGNED);
SET @fpw_preflight_20260801_001_version_minor =
  CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@fpw_preflight_20260801_001_version_core, '.', 2), '.', -1) AS UNSIGNED);
SET @fpw_preflight_20260801_001_version_patch =
  CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@fpw_preflight_20260801_001_version_core, '.', 3), '.', -1) AS UNSIGNED);

SET @fpw_preflight_20260801_001_check_sql = IF(
  @fpw_preflight_20260801_001_is_mariadb = 1,
  'SELECT @@SESSION.check_constraint_checks INTO @fpw_preflight_20260801_001_check_enforcement',
  'SET @fpw_preflight_20260801_001_check_enforcement = 1'
);
PREPARE fpw_preflight_20260801_001_check
FROM @fpw_preflight_20260801_001_check_sql;
EXECUTE fpw_preflight_20260801_001_check;
DEALLOCATE PREPARE fpw_preflight_20260801_001_check;

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_prerequisite_tables
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_TYPE = 'BASE TABLE'
  AND ENGINE = 'InnoDB'
  AND TABLE_NAME IN (
    'floatplans',
    'floatplan_monitoring',
    'member_entitlements',
    'premium_send_credits',
    'premium_send_receipts'
  );

-- This accepts native JSON and the repository's LONGTEXT + JSON_VALID form.
-- The Phase 1 migration must not normalize the unrelated response column.
SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_prerequisite_columns
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND (
    (TABLE_NAME = 'floatplans' AND COLUMN_NAME = 'floatPlanId' AND DATA_TYPE = 'int' AND IS_NULLABLE = 'NO')
    OR (TABLE_NAME = 'floatplans' AND COLUMN_NAME = 'userId' AND DATA_TYPE = 'varchar' AND IS_NULLABLE = 'NO')
    OR (TABLE_NAME = 'floatplans' AND COLUMN_NAME = 'status' AND DATA_TYPE = 'varchar' AND IS_NULLABLE = 'NO')
    OR (TABLE_NAME = 'floatplans' AND COLUMN_NAME = 'closedAt' AND DATA_TYPE = 'datetime')
    OR (TABLE_NAME = 'floatplan_monitoring' AND COLUMN_NAME = 'id')
    OR (TABLE_NAME = 'floatplan_monitoring' AND COLUMN_NAME = 'float_plan_id')
    OR (TABLE_NAME = 'floatplan_monitoring' AND COLUMN_NAME = 'monitoring_mode')
    OR (
      TABLE_NAME = 'member_entitlements'
      AND COLUMN_NAME = 'id'
      AND DATA_TYPE = 'bigint'
      AND LOWER(COLUMN_TYPE) LIKE '%unsigned%'
      AND IS_NULLABLE = 'NO'
    )
    OR (
      TABLE_NAME = 'member_entitlements'
      AND COLUMN_NAME = 'user_id'
      AND DATA_TYPE = 'int'
      AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%'
      AND IS_NULLABLE = 'NO'
    )
    OR (TABLE_NAME = 'member_entitlements' AND COLUMN_NAME = 'entitlement_type')
    OR (TABLE_NAME = 'member_entitlements' AND COLUMN_NAME = 'source')
    OR (TABLE_NAME = 'member_entitlements' AND COLUMN_NAME = 'status')
    OR (TABLE_NAME = 'member_entitlements' AND COLUMN_NAME = 'starts_at_utc' AND DATA_TYPE = 'datetime')
    OR (TABLE_NAME = 'member_entitlements' AND COLUMN_NAME = 'expires_at_utc' AND DATA_TYPE = 'datetime')
    OR (TABLE_NAME = 'member_entitlements' AND COLUMN_NAME = 'stripe_price_id')
    OR (TABLE_NAME = 'member_entitlements' AND COLUMN_NAME = 'created_utc' AND DATA_TYPE = 'datetime')
    OR (TABLE_NAME = 'member_entitlements' AND COLUMN_NAME = 'revoked_at_utc' AND DATA_TYPE = 'datetime')
    OR (TABLE_NAME = 'premium_send_credits' AND COLUMN_NAME = 'id' AND DATA_TYPE = 'bigint' AND IS_NULLABLE = 'NO')
    OR (TABLE_NAME = 'premium_send_credits' AND COLUMN_NAME = 'user_id' AND DATA_TYPE = 'int' AND IS_NULLABLE = 'NO')
    OR (TABLE_NAME = 'premium_send_credits' AND COLUMN_NAME = 'source')
    OR (TABLE_NAME = 'premium_send_credits' AND COLUMN_NAME = 'status')
    OR (TABLE_NAME = 'premium_send_credits' AND COLUMN_NAME = 'consumed_float_plan_id' AND DATA_TYPE = 'int')
    OR (TABLE_NAME = 'premium_send_credits' AND COLUMN_NAME = 'consumed_at_utc' AND DATA_TYPE = 'datetime' AND DATETIME_PRECISION = 6)
    OR (TABLE_NAME = 'premium_send_receipts' AND COLUMN_NAME = 'id' AND DATA_TYPE = 'bigint' AND IS_NULLABLE = 'NO')
    OR (
      TABLE_NAME = 'premium_send_receipts'
      AND COLUMN_NAME = 'user_id'
      AND DATA_TYPE = 'int'
      AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%'
      AND IS_NULLABLE = 'NO'
    )
    OR (TABLE_NAME = 'premium_send_receipts' AND COLUMN_NAME = 'float_plan_id' AND DATA_TYPE = 'int' AND IS_NULLABLE = 'NO')
    OR (TABLE_NAME = 'premium_send_receipts' AND COLUMN_NAME = 'credit_id' AND DATA_TYPE = 'bigint')
    OR (TABLE_NAME = 'premium_send_receipts' AND COLUMN_NAME = 'access_source')
    OR (
      TABLE_NAME = 'premium_send_receipts'
      AND COLUMN_NAME = 'original_response_json'
      AND DATA_TYPE IN ('json', 'longtext')
      AND IS_NULLABLE = 'NO'
    )
    OR (
      TABLE_NAME = 'premium_send_receipts'
      AND COLUMN_NAME = 'committed_at_utc'
      AND DATA_TYPE = 'datetime'
      AND DATETIME_PRECISION = 6
      AND IS_NULLABLE = 'NO'
    )
  );

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_new_columns
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
    (
      TABLE_NAME = 'floatplans'
      AND COLUMN_NAME IN ('expiredAt', 'end_reason')
    )
  );

SELECT COUNT(DISTINCT CONCAT(TABLE_NAME, '|', INDEX_NAME))
INTO @fpw_preflight_20260801_001_new_indexes
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
INTO @fpw_preflight_20260801_001_new_constraints
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
    (
      TABLE_NAME = 'floatplans'
      AND CONSTRAINT_NAME = 'chk_floatplans_expired_lifecycle'
    )
  );

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_invalid_credit_states
FROM premium_send_credits c
WHERE c.source NOT IN ('complimentary_signup', 'stripe_one_trip', 'promotion', 'admin_grant')
   OR c.status NOT IN ('AVAILABLE', 'CONSUMED')
   OR (
     c.status = 'AVAILABLE'
     AND (c.consumed_float_plan_id IS NOT NULL OR c.consumed_at_utc IS NOT NULL)
   )
   OR (
     c.status = 'CONSUMED'
     AND (c.consumed_float_plan_id IS NULL OR c.consumed_at_utc IS NULL)
   );

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_invalid_receipt_bindings
FROM premium_send_receipts r
LEFT JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
LEFT JOIN premium_send_credits c
  ON c.id = r.credit_id
 AND c.user_id = r.user_id
 AND c.consumed_float_plan_id = r.float_plan_id
WHERE fp.floatPlanId IS NULL
   OR TRIM(fp.userId) <> CAST(r.user_id AS CHAR)
   OR r.access_source NOT IN ('general_premium', 'premium_send_credit')
   OR (r.access_source = 'general_premium' AND r.credit_id IS NOT NULL)
   OR (
     r.access_source = 'premium_send_credit'
     AND (
       r.credit_id IS NULL
       OR c.id IS NULL
       OR c.status <> 'CONSUMED'
       OR c.consumed_at_utc IS NULL
     )
   );

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_consumed_missing_timestamp
FROM premium_send_credits c
WHERE c.status = 'CONSUMED'
  AND c.consumed_at_utc IS NULL;

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_consumed_without_receipt
FROM premium_send_credits c
LEFT JOIN premium_send_receipts r
  ON r.credit_id = c.id
 AND r.user_id = c.user_id
 AND r.float_plan_id = c.consumed_float_plan_id
WHERE c.status = 'CONSUMED'
  AND r.id IS NULL;

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_active_valid_credit_receipts
FROM premium_send_receipts r
INNER JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
 AND TRIM(fp.userId) = CAST(r.user_id AS CHAR)
INNER JOIN premium_send_credits c
  ON c.id = r.credit_id
 AND c.user_id = r.user_id
 AND c.consumed_float_plan_id = r.float_plan_id
WHERE r.access_source = 'premium_send_credit'
  AND c.status = 'CONSUMED'
  AND c.consumed_at_utc IS NOT NULL
  AND UPPER(TRIM(fp.status)) = 'ACTIVE';

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_active_credit_without_receipt
FROM floatplans fp
WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
  AND EXISTS (
    SELECT 1
    FROM premium_send_credits c
    WHERE c.consumed_float_plan_id = fp.floatPlanId
      AND c.status = 'CONSUMED'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM premium_send_receipts r
    WHERE r.float_plan_id = fp.floatPlanId
  );

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_active_multiple_candidate_credits
FROM (
  SELECT fp.floatPlanId
  FROM floatplans fp
  INNER JOIN premium_send_credits c
    ON c.consumed_float_plan_id = fp.floatPlanId
   AND c.status = 'CONSUMED'
  WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
  GROUP BY fp.floatPlanId
  HAVING COUNT(*) > 1
) AS active_multiple_candidate_credits;

-- Canonical Basic sends always create a latest monitoring row with mode=basic.
-- Excluding that proof keeps this Premium migration from reclassifying Basic data.
SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_active_unclassified
FROM floatplans fp
WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
  AND NOT EXISTS (
    SELECT 1
    FROM premium_send_receipts r
    WHERE r.float_plan_id = fp.floatPlanId
  )
  AND NOT EXISTS (
    SELECT 1
    FROM premium_send_credits c
    WHERE c.consumed_float_plan_id = fp.floatPlanId
      AND c.status = 'CONSUMED'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM floatplan_monitoring fm
    WHERE fm.float_plan_id = fp.floatPlanId
      AND fm.id = (
        SELECT MAX(fm_latest.id)
        FROM floatplan_monitoring fm_latest
        WHERE fm_latest.float_plan_id = fp.floatPlanId
      )
      AND fm.monitoring_mode = 'basic'
  );

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_active_conflicts
FROM floatplans fp
WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
  AND (
    (SELECT COUNT(*) FROM premium_send_receipts r WHERE r.float_plan_id = fp.floatPlanId) > 1
    OR
    (
      (SELECT COUNT(*) FROM premium_send_credits c WHERE c.consumed_float_plan_id = fp.floatPlanId AND c.status = 'CONSUMED') > 1
    )
    OR
    (
      (
        EXISTS (SELECT 1 FROM premium_send_receipts r WHERE r.float_plan_id = fp.floatPlanId)
        OR EXISTS (
          SELECT 1
          FROM premium_send_credits c
          WHERE c.consumed_float_plan_id = fp.floatPlanId
            AND c.status = 'CONSUMED'
        )
      )
      AND EXISTS (
        SELECT 1
        FROM floatplan_monitoring fm
        WHERE fm.float_plan_id = fp.floatPlanId
          AND fm.id = (
            SELECT MAX(fm_latest.id)
            FROM floatplan_monitoring fm_latest
            WHERE fm_latest.float_plan_id = fp.floatPlanId
          )
          AND fm.monitoring_mode = 'basic'
      )
    )
    OR
    (
      EXISTS (
        SELECT 1
        FROM premium_send_receipts r
        WHERE r.float_plan_id = fp.floatPlanId
          AND r.access_source = 'general_premium'
      )
      AND EXISTS (
        SELECT 1
        FROM premium_send_credits c
        WHERE c.consumed_float_plan_id = fp.floatPlanId
          AND c.status = 'CONSUMED'
      )
    )
  );

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_receipt_plan_status_conflicts
FROM premium_send_receipts r
INNER JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
WHERE UPPER(TRIM(fp.status)) NOT IN ('ACTIVE', 'CLOSED', 'CANCELLED', 'CANCELED');

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_ended_timestamp_conflicts
FROM premium_send_receipts r
INNER JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
WHERE UPPER(TRIM(fp.status)) IN ('CLOSED', 'CANCELLED', 'CANCELED')
  AND fp.closedAt IS NULL;

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_ended_chronology_conflicts
FROM premium_send_receipts r
INNER JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
LEFT JOIN premium_send_credits c
  ON c.id = r.credit_id
 AND c.user_id = r.user_id
 AND c.consumed_float_plan_id = r.float_plan_id
WHERE UPPER(TRIM(fp.status)) IN ('CLOSED', 'CANCELLED', 'CANCELED')
  AND (
    fp.closedAt < r.committed_at_utc
    OR
    (r.access_source = 'premium_send_credit' AND fp.closedAt < c.consumed_at_utc)
  );

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_unexpected_plan_statuses
FROM floatplans fp
WHERE UPPER(TRIM(fp.status)) NOT IN ('DRAFT', 'ACTIVE', 'CLOSED', 'CANCELLED', 'CANCELED');

SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_invalid_receipt_json
FROM premium_send_receipts r
WHERE JSON_VALID(r.original_response_json) <> 1;

-- Historical interval values are intentionally reported as unproven. The
-- monthly/annual mapping lives in application configuration and is not durable
-- database history, so the migration leaves these snapshots NULL.
SELECT COUNT(*)
INTO @fpw_preflight_20260801_001_general_interval_unproven
FROM premium_send_receipts r
WHERE r.access_source = 'general_premium';

SET @fpw_preflight_20260801_001_error = CASE
  WHEN DATABASE() IS NULL THEN
    'Refusing preflight: no database is selected.'
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    CONCAT('Refusing preflight: selected database is ', DATABASE(), ', not FPW.')
  WHEN
    @fpw_preflight_20260801_001_is_mariadb = 1
    AND (
      @fpw_preflight_20260801_001_version_major <> 10
      OR @fpw_preflight_20260801_001_version_minor <> 5
      OR @fpw_preflight_20260801_001_version_patch < 26
    )
  THEN
    CONCAT('Refusing preflight: unsupported MariaDB version ', VERSION(), '.')
  WHEN
    @fpw_preflight_20260801_001_is_mariadb = 0
    AND (
      @fpw_preflight_20260801_001_version_major < 8
      OR (
        @fpw_preflight_20260801_001_version_major = 8
        AND @fpw_preflight_20260801_001_version_minor = 0
        AND @fpw_preflight_20260801_001_version_patch < 16
      )
    )
  THEN
    CONCAT('Refusing preflight: MySQL 8.0.16 or newer is required; found ', VERSION(), '.')
  WHEN @fpw_preflight_20260801_001_check_enforcement <> 1 THEN
    'Refusing preflight: CHECK constraint enforcement is disabled.'
  WHEN @fpw_preflight_20260801_001_prerequisite_tables <> 5 THEN
    'Refusing preflight: one or more required InnoDB tables are missing.'
  WHEN @fpw_preflight_20260801_001_prerequisite_columns <> 30 THEN
    'Refusing preflight: one or more required source columns have an incompatible definition.'
  WHEN @fpw_preflight_20260801_001_new_columns <> 0 THEN
    'Refusing preflight: one or more Phase 1 lifecycle columns already exist.'
  WHEN @fpw_preflight_20260801_001_new_indexes <> 0 THEN
    'Refusing preflight: one or more Phase 1 lifecycle indexes already exist.'
  WHEN @fpw_preflight_20260801_001_new_constraints <> 0 THEN
    'Refusing preflight: one or more Phase 1 lifecycle constraints already exist.'
  WHEN @fpw_preflight_20260801_001_invalid_credit_states <> 0 THEN
    'Refusing preflight: invalid Premium Send Credit state was found.'
  WHEN @fpw_preflight_20260801_001_invalid_receipt_bindings <> 0 THEN
    'Refusing preflight: an invalid Premium Send receipt binding was found.'
  WHEN @fpw_preflight_20260801_001_consumed_without_receipt <> 0 THEN
    'Refusing preflight: a consumed Premium Send Credit has no receipt.'
  WHEN @fpw_preflight_20260801_001_active_credit_without_receipt <> 0 THEN
    'Refusing preflight: an active credit-origin plan has no receipt.'
  WHEN @fpw_preflight_20260801_001_active_unclassified <> 0 THEN
    'Refusing preflight: an active non-Basic plan has no provable authorization source.'
  WHEN @fpw_preflight_20260801_001_active_conflicts <> 0 THEN
    'Refusing preflight: an active plan has conflicting authorization evidence.'
  WHEN @fpw_preflight_20260801_001_receipt_plan_status_conflicts <> 0 THEN
    'Refusing preflight: a Premium Send receipt is bound to an unsupported plan status.'
  WHEN @fpw_preflight_20260801_001_ended_timestamp_conflicts <> 0 THEN
    'Refusing preflight: an ended Premium plan has no confirmed closedAt timestamp.'
  WHEN @fpw_preflight_20260801_001_ended_chronology_conflicts <> 0 THEN
    'Refusing preflight: an ended Premium plan timestamp predates its send or credit consumption.'
  WHEN @fpw_preflight_20260801_001_unexpected_plan_statuses <> 0 THEN
    'Refusing preflight: an unexpected float-plan status exists.'
  WHEN @fpw_preflight_20260801_001_invalid_receipt_json <> 0 THEN
    'Refusing preflight: a Premium Send receipt contains invalid response JSON.'
  ELSE NULL
END;

SELECT
  DATABASE() AS selected_database,
  VERSION() AS database_version,
  UTC_TIMESTAMP(6) AS checked_at_utc,
  @fpw_preflight_20260801_001_check_enforcement AS check_constraint_enforcement,
  @fpw_preflight_20260801_001_prerequisite_tables AS prerequisite_tables_found,
  @fpw_preflight_20260801_001_prerequisite_columns AS compatible_source_columns,
  @fpw_preflight_20260801_001_new_columns AS existing_phase1_columns,
  @fpw_preflight_20260801_001_new_indexes AS existing_phase1_indexes,
  @fpw_preflight_20260801_001_new_constraints AS existing_phase1_constraints,
  @fpw_preflight_20260801_001_invalid_credit_states AS invalid_credit_states,
  @fpw_preflight_20260801_001_consumed_missing_timestamp AS consumed_credits_missing_consumed_at_utc,
  @fpw_preflight_20260801_001_invalid_receipt_bindings AS invalid_receipt_bindings,
  @fpw_preflight_20260801_001_consumed_without_receipt AS consumed_credits_without_receipts,
  @fpw_preflight_20260801_001_active_valid_credit_receipts AS active_credit_receipts_with_valid_bindings,
  @fpw_preflight_20260801_001_active_credit_without_receipt AS active_credit_plans_without_receipts,
  @fpw_preflight_20260801_001_active_multiple_candidate_credits AS active_plans_with_multiple_candidate_credits,
  @fpw_preflight_20260801_001_active_unclassified AS active_unclassified_non_basic_plans,
  @fpw_preflight_20260801_001_active_conflicts AS active_authorization_conflicts,
  @fpw_preflight_20260801_001_receipt_plan_status_conflicts AS receipt_plan_status_conflicts,
  @fpw_preflight_20260801_001_ended_timestamp_conflicts AS ended_timestamp_conflicts,
  @fpw_preflight_20260801_001_ended_chronology_conflicts AS ended_chronology_conflicts,
  @fpw_preflight_20260801_001_unexpected_plan_statuses AS unexpected_plan_statuses,
  @fpw_preflight_20260801_001_invalid_receipt_json AS invalid_receipt_json,
  @fpw_preflight_20260801_001_general_interval_unproven AS general_premium_intervals_left_unproven,
  IF(@fpw_preflight_20260801_001_error IS NULL, 'PASS', 'FAIL') AS preflight_status,
  @fpw_preflight_20260801_001_error AS preflight_error;

-- Safe identifiers only; no member PII is returned.
SELECT
  issue_code,
  float_plan_id,
  receipt_id,
  credit_id
FROM (
  SELECT
    'ACTIVE_CREDIT_RECEIPT_MISSING' AS issue_code,
    fp.floatPlanId AS float_plan_id,
    NULL AS receipt_id,
    c.id AS credit_id
  FROM floatplans fp
  INNER JOIN premium_send_credits c
    ON c.consumed_float_plan_id = fp.floatPlanId
   AND c.status = 'CONSUMED'
  LEFT JOIN premium_send_receipts r
    ON r.float_plan_id = fp.floatPlanId
  WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
    AND r.id IS NULL

  UNION ALL

  SELECT
    'ACTIVE_AUTHORIZATION_CONFLICT',
    fp.floatPlanId,
    (SELECT MIN(r.id) FROM premium_send_receipts r WHERE r.float_plan_id = fp.floatPlanId),
    (
      SELECT MIN(c.id)
      FROM premium_send_credits c
      WHERE c.consumed_float_plan_id = fp.floatPlanId
        AND c.status = 'CONSUMED'
    )
  FROM floatplans fp
  WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
    AND (
      (SELECT COUNT(*) FROM premium_send_receipts r WHERE r.float_plan_id = fp.floatPlanId) > 1
      OR
      (SELECT COUNT(*) FROM premium_send_credits c WHERE c.consumed_float_plan_id = fp.floatPlanId AND c.status = 'CONSUMED') > 1
      OR
      (
        (
          EXISTS (SELECT 1 FROM premium_send_receipts r WHERE r.float_plan_id = fp.floatPlanId)
          OR EXISTS (
            SELECT 1
            FROM premium_send_credits c
            WHERE c.consumed_float_plan_id = fp.floatPlanId
              AND c.status = 'CONSUMED'
          )
        )
        AND EXISTS (
          SELECT 1
          FROM floatplan_monitoring fm
          WHERE fm.float_plan_id = fp.floatPlanId
            AND fm.id = (
              SELECT MAX(fm_latest.id)
              FROM floatplan_monitoring fm_latest
              WHERE fm_latest.float_plan_id = fp.floatPlanId
            )
            AND fm.monitoring_mode = 'basic'
        )
      )
      OR
      (
        EXISTS (
          SELECT 1
          FROM premium_send_receipts r
          WHERE r.float_plan_id = fp.floatPlanId
            AND r.access_source = 'general_premium'
        )
        AND EXISTS (
          SELECT 1
          FROM premium_send_credits c
          WHERE c.consumed_float_plan_id = fp.floatPlanId
            AND c.status = 'CONSUMED'
        )
      )
    )

  UNION ALL

  SELECT
    'ACTIVE_AUTHORIZATION_UNCLASSIFIED',
    fp.floatPlanId,
    NULL,
    NULL
  FROM floatplans fp
  WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
    AND NOT EXISTS (SELECT 1 FROM premium_send_receipts r WHERE r.float_plan_id = fp.floatPlanId)
    AND NOT EXISTS (
      SELECT 1
      FROM premium_send_credits c
      WHERE c.consumed_float_plan_id = fp.floatPlanId
        AND c.status = 'CONSUMED'
    )
    AND NOT EXISTS (
      SELECT 1
      FROM floatplan_monitoring fm
      WHERE fm.float_plan_id = fp.floatPlanId
        AND fm.id = (
          SELECT MAX(fm_latest.id)
          FROM floatplan_monitoring fm_latest
          WHERE fm_latest.float_plan_id = fp.floatPlanId
        )
        AND fm.monitoring_mode = 'basic'
    )

  UNION ALL

  SELECT
    'CONSUMED_CREDIT_TIMESTAMP_MISSING',
    c.consumed_float_plan_id,
    NULL,
    c.id
  FROM premium_send_credits c
  WHERE c.status = 'CONSUMED'
    AND c.consumed_at_utc IS NULL

  UNION ALL

  SELECT
    'RECEIPT_PLAN_STATUS_UNSUPPORTED',
    fp.floatPlanId,
    r.id,
    r.credit_id
  FROM premium_send_receipts r
  INNER JOIN floatplans fp
    ON fp.floatPlanId = r.float_plan_id
  WHERE UPPER(TRIM(fp.status)) NOT IN ('ACTIVE', 'CLOSED', 'CANCELLED', 'CANCELED')

  UNION ALL

  SELECT
    'ENDED_TIMESTAMP_MISSING',
    fp.floatPlanId,
    r.id,
    r.credit_id
  FROM premium_send_receipts r
  INNER JOIN floatplans fp
    ON fp.floatPlanId = r.float_plan_id
  WHERE UPPER(TRIM(fp.status)) IN ('CLOSED', 'CANCELLED', 'CANCELED')
    AND fp.closedAt IS NULL

  UNION ALL

  SELECT
    'CONSUMED_CREDIT_RECEIPT_MISSING',
    c.consumed_float_plan_id,
    NULL,
    c.id
  FROM premium_send_credits c
  LEFT JOIN premium_send_receipts r
    ON r.credit_id = c.id
   AND r.user_id = c.user_id
   AND r.float_plan_id = c.consumed_float_plan_id
  WHERE c.status = 'CONSUMED'
    AND r.id IS NULL

  UNION ALL

  SELECT
    'PLAN_STATUS_UNEXPECTED',
    fp.floatPlanId,
    NULL,
    NULL
  FROM floatplans fp
  WHERE UPPER(TRIM(fp.status)) NOT IN ('DRAFT', 'ACTIVE', 'CLOSED', 'CANCELLED', 'CANCELED')
) AS preflight_issues
ORDER BY issue_code, float_plan_id, receipt_id, credit_id;

SELECT
  access_source,
  UPPER(TRIM(fp.status)) AS plan_status,
  COUNT(*) AS receipt_count
FROM premium_send_receipts r
INNER JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
GROUP BY access_source, UPPER(TRIM(fp.status))
ORDER BY access_source, plan_status;

-- Historical entitlement IDs are backfilled only when exactly one candidate is
-- provable. Historical Monthly/Annual interval values remain NULL because the
-- price-to-interval mapping is application configuration, not database history.
SELECT
  candidate_count,
  COUNT(*) AS general_premium_receipt_count
FROM (
  SELECT
    r.id,
    COUNT(me.id) AS candidate_count
  FROM premium_send_receipts r
  LEFT JOIN member_entitlements me
    ON me.user_id = r.user_id
   AND me.entitlement_type = 'premium'
   AND me.created_utc <= r.committed_at_utc
   AND me.starts_at_utc <= r.committed_at_utc
   AND (me.expires_at_utc IS NULL OR me.expires_at_utc >= r.committed_at_utc)
   AND (me.revoked_at_utc IS NULL OR me.revoked_at_utc >= r.committed_at_utc)
  WHERE r.access_source = 'general_premium'
  GROUP BY r.id
) AS historical_entitlement_candidates
GROUP BY candidate_count
ORDER BY candidate_count;

SET @fpw_preflight_20260801_001_guard_sql = IF(
  @fpw_preflight_20260801_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_production_preflight_refused_20260801_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_preflight_20260801_001_guard
FROM @fpw_preflight_20260801_001_guard_sql;
EXECUTE fpw_preflight_20260801_001_guard;
DEALLOCATE PREPARE fpw_preflight_20260801_001_guard;

SET @fpw_preflight_20260801_001_error = NULL;
SET @fpw_preflight_20260801_001_prerequisite_tables = NULL;
SET @fpw_preflight_20260801_001_prerequisite_columns = NULL;
SET @fpw_preflight_20260801_001_new_columns = NULL;
SET @fpw_preflight_20260801_001_new_indexes = NULL;
SET @fpw_preflight_20260801_001_new_constraints = NULL;
SET @fpw_preflight_20260801_001_invalid_credit_states = NULL;
SET @fpw_preflight_20260801_001_consumed_missing_timestamp = NULL;
SET @fpw_preflight_20260801_001_invalid_receipt_bindings = NULL;
SET @fpw_preflight_20260801_001_consumed_without_receipt = NULL;
SET @fpw_preflight_20260801_001_active_valid_credit_receipts = NULL;
SET @fpw_preflight_20260801_001_active_credit_without_receipt = NULL;
SET @fpw_preflight_20260801_001_active_multiple_candidate_credits = NULL;
SET @fpw_preflight_20260801_001_active_unclassified = NULL;
SET @fpw_preflight_20260801_001_active_conflicts = NULL;
SET @fpw_preflight_20260801_001_receipt_plan_status_conflicts = NULL;
SET @fpw_preflight_20260801_001_ended_timestamp_conflicts = NULL;
SET @fpw_preflight_20260801_001_ended_chronology_conflicts = NULL;
SET @fpw_preflight_20260801_001_unexpected_plan_statuses = NULL;
SET @fpw_preflight_20260801_001_invalid_receipt_json = NULL;
SET @fpw_preflight_20260801_001_general_interval_unproven = NULL;
SET @fpw_preflight_20260801_001_check_enforcement = NULL;
SET @fpw_preflight_20260801_001_target_error = NULL;
SET @fpw_preflight_20260801_001_target_guard_sql = NULL;
SET @fpw_preflight_20260801_001_is_mariadb = NULL;
SET @fpw_preflight_20260801_001_version_core = NULL;
SET @fpw_preflight_20260801_001_version_major = NULL;
SET @fpw_preflight_20260801_001_version_minor = NULL;
SET @fpw_preflight_20260801_001_version_patch = NULL;
SET @fpw_preflight_20260801_001_check_sql = NULL;
SET @fpw_preflight_20260801_001_guard_sql = NULL;
