USE `FPW`;

-- Apply only after the matching preflight reports PASS. DDL below performs
-- implicit commits; do not use the SQL client's --force option.
SET @fpw_up_20260801_001_error = NULL;
SET @fpw_up_20260801_001_prerequisite_tables = 0;
SET @fpw_up_20260801_001_prerequisite_columns = 0;
SET @fpw_up_20260801_001_existing_objects = 0;
SET @fpw_up_20260801_001_unsafe_rows = 0;
SET @fpw_up_20260801_001_check_enforcement = 1;
SET @fpw_up_20260801_001_is_mariadb =
  LOWER(VERSION()) LIKE '%mariadb%';
SET @fpw_up_20260801_001_deployment_utc = NULL;
SET @fpw_up_20260801_001_active_credit_rows = 0;
SET @fpw_up_20260801_001_ended_credit_rows = 0;
SET @fpw_up_20260801_001_general_premium_rows = 0;
SET @fpw_up_20260801_001_general_snapshot_rows = 0;

SET @fpw_up_20260801_001_check_sql = IF(
  @fpw_up_20260801_001_is_mariadb = 1,
  'SELECT @@SESSION.check_constraint_checks INTO @fpw_up_20260801_001_check_enforcement',
  'SET @fpw_up_20260801_001_check_enforcement = 1'
);
PREPARE fpw_up_20260801_001_check
FROM @fpw_up_20260801_001_check_sql;
EXECUTE fpw_up_20260801_001_check;
DEALLOCATE PREPARE fpw_up_20260801_001_check;

SELECT COUNT(*)
INTO @fpw_up_20260801_001_prerequisite_tables
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

-- Repeat the exact source-column compatibility check in this connection. The
-- production preflight and forward migration may be run in separate sessions.
SELECT COUNT(*)
INTO @fpw_up_20260801_001_prerequisite_columns
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

SELECT
  (
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
  )
  +
  (
    SELECT COUNT(DISTINCT CONCAT(TABLE_NAME, '|', INDEX_NAME))
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
      )
  )
  +
  (
    SELECT COUNT(*)
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
      )
  )
INTO @fpw_up_20260801_001_existing_objects;

-- Repeat the destructive-data safety gate so the forward migration still
-- fails closed if an operator skips or races the preflight.
SELECT
  (
    SELECT COUNT(*)
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
       )
  )
  +
  (
    SELECT COUNT(*)
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
       )
  )
  +
  (
    SELECT COUNT(*)
    FROM premium_send_credits c
    LEFT JOIN premium_send_receipts r
      ON r.credit_id = c.id
     AND r.user_id = c.user_id
     AND r.float_plan_id = c.consumed_float_plan_id
    WHERE c.status = 'CONSUMED'
      AND r.id IS NULL
  )
  +
  (
    SELECT COUNT(*)
    FROM floatplans fp
    WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
      AND NOT EXISTS (
        SELECT 1 FROM premium_send_receipts r WHERE r.float_plan_id = fp.floatPlanId
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
      )
  )
  +
  (
    SELECT COUNT(*)
    FROM floatplans fp
    WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
      AND (
        (SELECT COUNT(*) FROM premium_send_receipts r WHERE r.float_plan_id = fp.floatPlanId) > 1
        OR
        (
          SELECT COUNT(*)
          FROM premium_send_credits c
          WHERE c.consumed_float_plan_id = fp.floatPlanId
            AND c.status = 'CONSUMED'
        ) > 1
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
  )
  +
  (
    SELECT COUNT(*)
    FROM premium_send_receipts r
    INNER JOIN floatplans fp
      ON fp.floatPlanId = r.float_plan_id
    LEFT JOIN premium_send_credits c
      ON c.id = r.credit_id
     AND c.user_id = r.user_id
     AND c.consumed_float_plan_id = r.float_plan_id
    WHERE UPPER(TRIM(fp.status)) NOT IN ('ACTIVE', 'CLOSED', 'CANCELLED', 'CANCELED')
       OR (
         UPPER(TRIM(fp.status)) IN ('CLOSED', 'CANCELLED', 'CANCELED')
         AND (
           fp.closedAt IS NULL
           OR fp.closedAt < r.committed_at_utc
           OR (r.access_source = 'premium_send_credit' AND fp.closedAt < c.consumed_at_utc)
         )
       )
  )
  +
  (
    SELECT COUNT(*)
    FROM floatplans fp
    WHERE UPPER(TRIM(fp.status)) NOT IN ('DRAFT', 'ACTIVE', 'CLOSED', 'CANCELLED', 'CANCELED')
  )
  +
  (
    SELECT COUNT(*)
    FROM premium_send_receipts r
    WHERE JSON_VALID(r.original_response_json) <> 1
  )
INTO @fpw_up_20260801_001_unsafe_rows;

SET @fpw_up_20260801_001_error = CASE
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    'Refusing migration: selected database is not FPW.'
  WHEN @fpw_up_20260801_001_prerequisite_tables <> 5 THEN
    'Refusing migration: one or more required InnoDB tables are missing.'
  WHEN @fpw_up_20260801_001_prerequisite_columns <> 30 THEN
    'Refusing migration: one or more required source columns have an incompatible definition.'
  WHEN @fpw_up_20260801_001_check_enforcement <> 1 THEN
    'Refusing migration: CHECK constraint enforcement is disabled in this session.'
  WHEN @fpw_up_20260801_001_existing_objects <> 0 THEN
    'Refusing migration: one or more Phase 1 lifecycle objects already exist.'
  WHEN @fpw_up_20260801_001_unsafe_rows <> 0 THEN
    'Refusing migration: source data no longer satisfies the Phase 1 safety gate.'
  ELSE NULL
END;

SELECT
  @fpw_up_20260801_001_prerequisite_tables AS prerequisite_tables_found,
  @fpw_up_20260801_001_prerequisite_columns AS compatible_source_columns,
  @fpw_up_20260801_001_check_enforcement AS check_constraint_enforcement,
  @fpw_up_20260801_001_existing_objects AS existing_phase1_objects,
  @fpw_up_20260801_001_unsafe_rows AS unsafe_source_rows,
  IF(@fpw_up_20260801_001_error IS NULL, 'PASS', 'FAIL') AS forward_guard_status,
  @fpw_up_20260801_001_error AS migration_refusal;

SET @fpw_up_20260801_001_guard_sql = IF(
  @fpw_up_20260801_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_refused_20260801_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260801_001_guard FROM @fpw_up_20260801_001_guard_sql;
EXECUTE fpw_up_20260801_001_guard;
DEALLOCATE PREPARE fpw_up_20260801_001_guard;

-- One authoritative database UTC value supplies the complete active-trip grace
-- backfill. It is intentionally unrelated to purchase, departure, or route time.
SET @fpw_up_20260801_001_deployment_utc = UTC_TIMESTAMP(6);

SELECT COUNT(*)
INTO @fpw_up_20260801_001_active_credit_rows
FROM premium_send_receipts r
INNER JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
INNER JOIN premium_send_credits c
  ON c.id = r.credit_id
 AND c.user_id = r.user_id
 AND c.consumed_float_plan_id = r.float_plan_id
WHERE r.access_source = 'premium_send_credit'
  AND UPPER(TRIM(fp.status)) = 'ACTIVE';

SELECT COUNT(*)
INTO @fpw_up_20260801_001_ended_credit_rows
FROM premium_send_receipts r
INNER JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
INNER JOIN premium_send_credits c
  ON c.id = r.credit_id
 AND c.user_id = r.user_id
 AND c.consumed_float_plan_id = r.float_plan_id
WHERE r.access_source = 'premium_send_credit'
  AND UPPER(TRIM(fp.status)) IN ('CLOSED', 'CANCELLED', 'CANCELED');

SELECT COUNT(*)
INTO @fpw_up_20260801_001_general_premium_rows
FROM premium_send_receipts r
WHERE r.access_source = 'general_premium';

ALTER TABLE `member_entitlements`
  ADD UNIQUE KEY `uq_member_entitlements_receipt_binding` (`id`, `user_id`);

ALTER TABLE `premium_send_receipts`
  ADD COLUMN `member_entitlement_id` BIGINT UNSIGNED NULL AFTER `credit_id`,
  ADD COLUMN `membership_interval_snapshot` VARCHAR(16) NULL AFTER `access_source`,
  ADD COLUMN `access_started_at_utc` DATETIME(6) NULL AFTER `membership_interval_snapshot`,
  ADD COLUMN `access_expires_at_utc` DATETIME(6) NULL AFTER `access_started_at_utc`,
  ADD COLUMN `access_ended_at_utc` DATETIME(6) NULL AFTER `access_expires_at_utc`,
  ADD COLUMN `access_end_reason` VARCHAR(64) NULL AFTER `access_ended_at_utc`;

ALTER TABLE `floatplans`
  ADD COLUMN `expiredAt` DATETIME(6) NULL AFTER `closedAt`,
  ADD COLUMN `end_reason` VARCHAR(64) NULL AFTER `expiredAt`;

-- Existing ACTIVE credit-origin plans receive the one-time deployment grace.
UPDATE premium_send_receipts r
INNER JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
INNER JOIN premium_send_credits c
  ON c.id = r.credit_id
 AND c.user_id = r.user_id
 AND c.consumed_float_plan_id = r.float_plan_id
SET r.member_entitlement_id = NULL,
    r.membership_interval_snapshot = NULL,
    r.access_started_at_utc = @fpw_up_20260801_001_deployment_utc,
    r.access_expires_at_utc = DATE_ADD(@fpw_up_20260801_001_deployment_utc, INTERVAL 21 DAY),
    r.access_ended_at_utc = NULL,
    r.access_end_reason = NULL
WHERE r.access_source = 'premium_send_credit'
  AND UPPER(TRIM(fp.status)) = 'ACTIVE';

-- Ended credit-origin history uses only immutable consumption and confirmed
-- float-plan ending timestamps. Nothing is reactivated or granted future access.
UPDATE premium_send_receipts r
INNER JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
INNER JOIN premium_send_credits c
  ON c.id = r.credit_id
 AND c.user_id = r.user_id
 AND c.consumed_float_plan_id = r.float_plan_id
SET r.member_entitlement_id = NULL,
    r.membership_interval_snapshot = NULL,
    r.access_started_at_utc = c.consumed_at_utc,
    r.access_expires_at_utc = DATE_ADD(c.consumed_at_utc, INTERVAL 21 DAY),
    r.access_ended_at_utc = fp.closedAt,
    r.access_end_reason = UPPER(TRIM(fp.status))
WHERE r.access_source = 'premium_send_credit'
  AND UPPER(TRIM(fp.status)) IN ('CLOSED', 'CANCELLED', 'CANCELED');

-- General-Premium history retains no single-trip expiry. committed_at_utc is
-- copied into the new, separate audit field as the only durable send timestamp;
-- it is not reused as mutable lifecycle state after this backfill.
UPDATE premium_send_receipts r
INNER JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
SET r.member_entitlement_id = (
      SELECT MIN(me.id)
      FROM member_entitlements me
      WHERE me.user_id = r.user_id
        AND me.entitlement_type = 'premium'
        AND me.created_utc <= r.committed_at_utc
        AND me.starts_at_utc <= r.committed_at_utc
        AND (me.expires_at_utc IS NULL OR me.expires_at_utc >= r.committed_at_utc)
        AND (me.revoked_at_utc IS NULL OR me.revoked_at_utc >= r.committed_at_utc)
      HAVING COUNT(*) = 1
    ),
    r.membership_interval_snapshot = NULL,
    r.access_started_at_utc = r.committed_at_utc,
    r.access_expires_at_utc = NULL,
    r.access_ended_at_utc = CASE
      WHEN UPPER(TRIM(fp.status)) IN ('CLOSED', 'CANCELLED', 'CANCELED') THEN fp.closedAt
      ELSE NULL
    END,
    r.access_end_reason = CASE
      WHEN UPPER(TRIM(fp.status)) IN ('CLOSED', 'CANCELLED', 'CANCELED') THEN UPPER(TRIM(fp.status))
      ELSE NULL
    END
WHERE r.access_source = 'general_premium';

SELECT COUNT(*)
INTO @fpw_up_20260801_001_general_snapshot_rows
FROM premium_send_receipts r
WHERE r.access_source = 'general_premium'
  AND r.member_entitlement_id IS NOT NULL;

ALTER TABLE `premium_send_receipts`
  ADD KEY `ix_premium_send_receipts_due_access`
    (`access_source`, `access_ended_at_utc`, `access_expires_at_utc`, `id`),
  ADD KEY `ix_premium_send_receipts_entitlement_binding`
    (`member_entitlement_id`, `user_id`),
  ADD CONSTRAINT `fk_premium_send_receipts_entitlement_binding`
    FOREIGN KEY (`member_entitlement_id`, `user_id`)
    REFERENCES `member_entitlements` (`id`, `user_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  ADD CONSTRAINT `chk_premium_send_receipts_access_window`
    CHECK (
      (
        `access_source` = 'premium_send_credit'
        AND `access_started_at_utc` IS NOT NULL
        AND `access_expires_at_utc` IS NOT NULL
        AND `access_expires_at_utc` = DATE_ADD(`access_started_at_utc`, INTERVAL 21 DAY)
      )
      OR
      (
        `access_source` = 'general_premium'
        AND `access_started_at_utc` IS NOT NULL
        AND `access_expires_at_utc` IS NULL
      )
    ),
  ADD CONSTRAINT `chk_premium_send_receipts_membership_snapshot`
    CHECK (
      (
        `access_source` = 'premium_send_credit'
        AND `member_entitlement_id` IS NULL
        AND `membership_interval_snapshot` IS NULL
      )
      OR
      (
        `access_source` = 'general_premium'
        AND (
          `membership_interval_snapshot` IS NULL
          OR
          (
            `member_entitlement_id` IS NOT NULL
            AND `membership_interval_snapshot` IN ('monthly', 'annual')
          )
        )
      )
    ),
  ADD CONSTRAINT `chk_premium_send_receipts_access_end`
    CHECK (
      (
        `access_ended_at_utc` IS NULL
        AND `access_end_reason` IS NULL
      )
      OR
      (
        `access_ended_at_utc` IS NOT NULL
        AND `access_ended_at_utc` >= `access_started_at_utc`
        AND `access_end_reason` IS NOT NULL
        AND CHAR_LENGTH(TRIM(`access_end_reason`)) > 0
      )
    );

ALTER TABLE `floatplans`
  ADD CONSTRAINT `chk_floatplans_expired_lifecycle`
    CHECK (
      (
        UPPER(TRIM(`status`)) = 'EXPIRED'
        AND `expiredAt` IS NOT NULL
        AND `end_reason` IS NOT NULL
        AND `end_reason` = 'SINGLE_TRIP_LIMIT'
      )
      OR
      (
        UPPER(TRIM(`status`)) <> 'EXPIRED'
        AND `expiredAt` IS NULL
        AND `end_reason` IS NULL
      )
    );

SELECT
  @fpw_up_20260801_001_deployment_utc AS deployment_utc,
  DATE_ADD(@fpw_up_20260801_001_deployment_utc, INTERVAL 21 DAY) AS active_credit_grace_expires_at_utc,
  @fpw_up_20260801_001_active_credit_rows AS active_credit_rows_backfilled,
  @fpw_up_20260801_001_ended_credit_rows AS ended_credit_rows_backfilled,
  @fpw_up_20260801_001_general_premium_rows AS general_premium_rows_backfilled,
  @fpw_up_20260801_001_general_snapshot_rows AS general_entitlement_ids_snapshotted,
  CASE
    WHEN (
      SELECT COUNT(*)
      FROM premium_send_receipts r
      WHERE r.access_started_at_utc IS NULL
         OR (
           r.access_source = 'premium_send_credit'
           AND (
             r.access_expires_at_utc IS NULL
             OR r.access_expires_at_utc <> DATE_ADD(r.access_started_at_utc, INTERVAL 21 DAY)
           )
         )
         OR (r.access_source = 'general_premium' AND r.access_expires_at_utc IS NOT NULL)
         OR ((r.access_ended_at_utc IS NULL) <> (r.access_end_reason IS NULL))
    ) = 0
    THEN 'PASS'
    ELSE 'FAIL'
  END AS forward_backfill_status;

SET @fpw_up_20260801_001_error = NULL;
SET @fpw_up_20260801_001_prerequisite_tables = NULL;
SET @fpw_up_20260801_001_prerequisite_columns = NULL;
SET @fpw_up_20260801_001_existing_objects = NULL;
SET @fpw_up_20260801_001_unsafe_rows = NULL;
SET @fpw_up_20260801_001_check_enforcement = NULL;
SET @fpw_up_20260801_001_is_mariadb = NULL;
SET @fpw_up_20260801_001_check_sql = NULL;
SET @fpw_up_20260801_001_deployment_utc = NULL;
SET @fpw_up_20260801_001_active_credit_rows = NULL;
SET @fpw_up_20260801_001_ended_credit_rows = NULL;
SET @fpw_up_20260801_001_general_premium_rows = NULL;
SET @fpw_up_20260801_001_general_snapshot_rows = NULL;
SET @fpw_up_20260801_001_guard_sql = NULL;
