USE `FPW`;

-- Verify schema shape and post-migration lifecycle integrity. This file is
-- read-only apart from session variables.
SET @fpw_verify_20260801_001_columns = 0;
SET @fpw_verify_20260801_001_index_rows = 0;
SET @fpw_verify_20260801_001_index_parts = 0;
SET @fpw_verify_20260801_001_constraints = 0;
SET @fpw_verify_20260801_001_check_semantics = 0;
SET @fpw_verify_20260801_001_enforced_checks = 0;
SET @fpw_verify_20260801_001_fk_parts = 0;
SET @fpw_verify_20260801_001_credit_window_violations = 0;
SET @fpw_verify_20260801_001_general_window_violations = 0;
SET @fpw_verify_20260801_001_binding_violations = 0;
SET @fpw_verify_20260801_001_ended_receipt_violations = 0;
SET @fpw_verify_20260801_001_active_receipt_violations = 0;
SET @fpw_verify_20260801_001_expired_lifecycle_violations = 0;
SET @fpw_verify_20260801_001_nonexpired_metadata_violations = 0;
SET @fpw_verify_20260801_001_check_enforcement = 1;
SET @fpw_verify_20260801_001_is_mariadb =
  LOWER(VERSION()) LIKE '%mariadb%';

SET @fpw_verify_20260801_001_check_sql = IF(
  @fpw_verify_20260801_001_is_mariadb = 1,
  'SELECT @@SESSION.check_constraint_checks INTO @fpw_verify_20260801_001_check_enforcement',
  'SET @fpw_verify_20260801_001_check_enforcement = 1'
);
PREPARE fpw_verify_20260801_001_check
FROM @fpw_verify_20260801_001_check_sql;
EXECUTE fpw_verify_20260801_001_check;
DEALLOCATE PREPARE fpw_verify_20260801_001_check;

SELECT COUNT(*)
INTO @fpw_verify_20260801_001_columns
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND (
    (
      TABLE_NAME = 'premium_send_receipts'
      AND COLUMN_NAME = 'member_entitlement_id'
      AND DATA_TYPE = 'bigint'
      AND LOWER(COLUMN_TYPE) LIKE '%unsigned%'
      AND IS_NULLABLE = 'YES'
    )
    OR
    (
      TABLE_NAME = 'premium_send_receipts'
      AND COLUMN_NAME = 'membership_interval_snapshot'
      AND LOWER(COLUMN_TYPE) = 'varchar(16)'
      AND IS_NULLABLE = 'YES'
    )
    OR
    (
      TABLE_NAME = 'premium_send_receipts'
      AND COLUMN_NAME IN (
        'access_started_at_utc',
        'access_expires_at_utc',
        'access_ended_at_utc'
      )
      AND LOWER(COLUMN_TYPE) = 'datetime(6)'
      AND IS_NULLABLE = 'YES'
    )
    OR
    (
      TABLE_NAME = 'premium_send_receipts'
      AND COLUMN_NAME = 'access_end_reason'
      AND LOWER(COLUMN_TYPE) = 'varchar(64)'
      AND IS_NULLABLE = 'YES'
    )
    OR
    (
      TABLE_NAME = 'floatplans'
      AND COLUMN_NAME = 'expiredAt'
      AND LOWER(COLUMN_TYPE) = 'datetime(6)'
      AND IS_NULLABLE = 'YES'
    )
    OR
    (
      TABLE_NAME = 'floatplans'
      AND COLUMN_NAME = 'end_reason'
      AND LOWER(COLUMN_TYPE) = 'varchar(64)'
      AND IS_NULLABLE = 'YES'
    )
  );

SELECT COUNT(*)
INTO @fpw_verify_20260801_001_index_rows
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
INTO @fpw_verify_20260801_001_index_parts
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'FPW'
  AND (
    (
      TABLE_NAME = 'member_entitlements'
      AND INDEX_NAME = 'uq_member_entitlements_receipt_binding'
      AND NON_UNIQUE = 0
      AND (
        (SEQ_IN_INDEX = 1 AND COLUMN_NAME = 'id')
        OR (SEQ_IN_INDEX = 2 AND COLUMN_NAME = 'user_id')
      )
    )
    OR
    (
      TABLE_NAME = 'premium_send_receipts'
      AND INDEX_NAME = 'ix_premium_send_receipts_due_access'
      AND NON_UNIQUE = 1
      AND (
        (SEQ_IN_INDEX = 1 AND COLUMN_NAME = 'access_source')
        OR (SEQ_IN_INDEX = 2 AND COLUMN_NAME = 'access_ended_at_utc')
        OR (SEQ_IN_INDEX = 3 AND COLUMN_NAME = 'access_expires_at_utc')
        OR (SEQ_IN_INDEX = 4 AND COLUMN_NAME = 'id')
      )
    )
    OR
    (
      TABLE_NAME = 'premium_send_receipts'
      AND INDEX_NAME = 'ix_premium_send_receipts_entitlement_binding'
      AND NON_UNIQUE = 1
      AND (
        (SEQ_IN_INDEX = 1 AND COLUMN_NAME = 'member_entitlement_id')
        OR (SEQ_IN_INDEX = 2 AND COLUMN_NAME = 'user_id')
      )
    )
  );

SELECT COUNT(*)
INTO @fpw_verify_20260801_001_constraints
FROM information_schema.TABLE_CONSTRAINTS tc
WHERE tc.CONSTRAINT_SCHEMA = 'FPW'
  AND (
    (
      tc.TABLE_NAME = 'premium_send_receipts'
      AND tc.CONSTRAINT_NAME = 'fk_premium_send_receipts_entitlement_binding'
      AND tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
    )
    OR
    (
      tc.TABLE_NAME = 'premium_send_receipts'
      AND tc.CONSTRAINT_NAME IN (
        'chk_premium_send_receipts_access_window',
        'chk_premium_send_receipts_membership_snapshot',
        'chk_premium_send_receipts_access_end'
      )
      AND tc.CONSTRAINT_TYPE = 'CHECK'
    )
    OR
    (
      tc.TABLE_NAME = 'floatplans'
      AND tc.CONSTRAINT_NAME = 'chk_floatplans_expired_lifecycle'
      AND tc.CONSTRAINT_TYPE = 'CHECK'
    )
  );

-- Verify the named CHECK constraints still express the required lifecycle
-- semantics rather than accepting name-only lookalikes.
SELECT COUNT(*)
INTO @fpw_verify_20260801_001_check_semantics
FROM information_schema.CHECK_CONSTRAINTS cc
WHERE cc.CONSTRAINT_SCHEMA = 'FPW'
  AND (
    (
      cc.CONSTRAINT_NAME = 'chk_premium_send_receipts_access_window'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%premium_send_credit%'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%general_premium%'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%access_started_at_utc%'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%access_expires_at_utc%'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%interval 21 day%'
    )
    OR
    (
      cc.CONSTRAINT_NAME = 'chk_premium_send_receipts_membership_snapshot'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%member_entitlement_id%'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%membership_interval_snapshot%'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%monthly%'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%annual%'
    )
    OR
    (
      cc.CONSTRAINT_NAME = 'chk_premium_send_receipts_access_end'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%access_ended_at_utc%'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%access_end_reason%'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%access_started_at_utc%'
    )
    OR
    (
      cc.CONSTRAINT_NAME = 'chk_floatplans_expired_lifecycle'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%expired%'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%expiredat%'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%end_reason%'
      AND LOWER(cc.CHECK_CLAUSE) LIKE '%single_trip_limit%'
    )
  );

-- MySQL supports per-CHECK NOT ENFORCED state. MariaDB instead uses the
-- session-level check_constraint_checks guard already captured above. Keep the
-- MySQL-only ENFORCED column inside dynamic SQL so this verifier remains
-- parseable on both engines.
SET @fpw_verify_20260801_001_enforced_checks_sql = IF(
  @fpw_verify_20260801_001_is_mariadb = 1,
  'SET @fpw_verify_20260801_001_enforced_checks = IF(@fpw_verify_20260801_001_check_enforcement = 1, 4, 0)',
  'SELECT COUNT(*) INTO @fpw_verify_20260801_001_enforced_checks FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = ''FPW'' AND CONSTRAINT_TYPE = ''CHECK'' AND CONSTRAINT_NAME IN (''chk_premium_send_receipts_access_window'', ''chk_premium_send_receipts_membership_snapshot'', ''chk_premium_send_receipts_access_end'', ''chk_floatplans_expired_lifecycle'') AND ENFORCED = ''YES'''
);
PREPARE fpw_verify_20260801_001_enforced_checks_stmt
FROM @fpw_verify_20260801_001_enforced_checks_sql;
EXECUTE fpw_verify_20260801_001_enforced_checks_stmt;
DEALLOCATE PREPARE fpw_verify_20260801_001_enforced_checks_stmt;

SELECT COUNT(*)
INTO @fpw_verify_20260801_001_fk_parts
FROM information_schema.KEY_COLUMN_USAGE kcu
INNER JOIN information_schema.REFERENTIAL_CONSTRAINTS rc
  ON rc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA
 AND rc.TABLE_NAME = kcu.TABLE_NAME
 AND rc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
WHERE kcu.CONSTRAINT_SCHEMA = 'FPW'
  AND kcu.TABLE_NAME = 'premium_send_receipts'
  AND kcu.CONSTRAINT_NAME = 'fk_premium_send_receipts_entitlement_binding'
  AND kcu.REFERENCED_TABLE_NAME = 'member_entitlements'
  AND rc.UPDATE_RULE = 'RESTRICT'
  AND rc.DELETE_RULE = 'RESTRICT'
  AND (
    (
      kcu.ORDINAL_POSITION = 1
      AND kcu.COLUMN_NAME = 'member_entitlement_id'
      AND kcu.REFERENCED_COLUMN_NAME = 'id'
    )
    OR
    (
      kcu.ORDINAL_POSITION = 2
      AND kcu.COLUMN_NAME = 'user_id'
      AND kcu.REFERENCED_COLUMN_NAME = 'user_id'
    )
  );

SELECT COUNT(*)
INTO @fpw_verify_20260801_001_credit_window_violations
FROM premium_send_receipts r
WHERE r.access_source = 'premium_send_credit'
  AND (
    r.credit_id IS NULL
    OR r.member_entitlement_id IS NOT NULL
    OR r.membership_interval_snapshot IS NOT NULL
    OR r.access_started_at_utc IS NULL
    OR r.access_expires_at_utc IS NULL
    OR r.access_expires_at_utc <> DATE_ADD(r.access_started_at_utc, INTERVAL 21 DAY)
  );

SELECT COUNT(*)
INTO @fpw_verify_20260801_001_general_window_violations
FROM premium_send_receipts r
WHERE r.access_source = 'general_premium'
  AND (
    r.credit_id IS NOT NULL
    OR r.access_started_at_utc IS NULL
    OR r.access_expires_at_utc IS NOT NULL
    OR r.membership_interval_snapshot NOT IN ('monthly', 'annual')
    OR (
      r.membership_interval_snapshot IS NOT NULL
      AND r.member_entitlement_id IS NULL
    )
  );

SELECT COUNT(*)
INTO @fpw_verify_20260801_001_binding_violations
FROM premium_send_receipts r
LEFT JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
LEFT JOIN premium_send_credits c
  ON c.id = r.credit_id
 AND c.user_id = r.user_id
 AND c.consumed_float_plan_id = r.float_plan_id
LEFT JOIN member_entitlements me
  ON me.id = r.member_entitlement_id
 AND me.user_id = r.user_id
WHERE fp.floatPlanId IS NULL
   OR TRIM(fp.userId) <> CAST(r.user_id AS CHAR)
   OR r.access_source NOT IN ('general_premium', 'premium_send_credit')
   OR (
     r.access_source = 'premium_send_credit'
     AND (
       c.id IS NULL
       OR c.status <> 'CONSUMED'
       OR c.consumed_at_utc IS NULL
     )
   )
   OR (
     r.member_entitlement_id IS NOT NULL
     AND (me.id IS NULL OR me.entitlement_type <> 'premium')
   );

SELECT COUNT(*)
INTO @fpw_verify_20260801_001_ended_receipt_violations
FROM premium_send_receipts r
INNER JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
WHERE (
    UPPER(TRIM(fp.status)) IN ('CLOSED', 'CANCELLED', 'CANCELED', 'EXPIRED')
    AND (
      r.access_ended_at_utc IS NULL
      OR r.access_end_reason IS NULL
      OR CHAR_LENGTH(TRIM(r.access_end_reason)) = 0
    )
  )
  OR ((r.access_ended_at_utc IS NULL) <> (r.access_end_reason IS NULL))
  OR (
    r.access_ended_at_utc IS NOT NULL
    AND r.access_ended_at_utc < r.access_started_at_utc
  );

SELECT COUNT(*)
INTO @fpw_verify_20260801_001_active_receipt_violations
FROM premium_send_receipts r
INNER JOIN floatplans fp
  ON fp.floatPlanId = r.float_plan_id
WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
  AND (r.access_ended_at_utc IS NOT NULL OR r.access_end_reason IS NOT NULL);

SELECT COUNT(*)
INTO @fpw_verify_20260801_001_expired_lifecycle_violations
FROM floatplans fp
LEFT JOIN premium_send_receipts r
  ON r.float_plan_id = fp.floatPlanId
WHERE UPPER(TRIM(fp.status)) = 'EXPIRED'
  AND (
    fp.expiredAt IS NULL
    OR fp.end_reason IS NULL
    OR fp.end_reason <> 'SINGLE_TRIP_LIMIT'
    OR r.id IS NULL
    OR r.access_source <> 'premium_send_credit'
    OR r.access_ended_at_utc IS NULL
    OR r.access_ended_at_utc <> fp.expiredAt
    OR r.access_end_reason IS NULL
    OR r.access_end_reason <> 'SINGLE_TRIP_LIMIT'
  );

SELECT COUNT(*)
INTO @fpw_verify_20260801_001_nonexpired_metadata_violations
FROM floatplans fp
WHERE UPPER(TRIM(fp.status)) <> 'EXPIRED'
  AND (fp.expiredAt IS NOT NULL OR fp.end_reason IS NOT NULL);

SELECT
  TABLE_NAME,
  ORDINAL_POSITION,
  COLUMN_NAME,
  COLUMN_TYPE,
  IS_NULLABLE
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
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT
  TABLE_NAME,
  INDEX_NAME,
  NON_UNIQUE,
  SEQ_IN_INDEX,
  COLUMN_NAME
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
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

SELECT
  tc.TABLE_NAME,
  tc.CONSTRAINT_NAME,
  tc.CONSTRAINT_TYPE
FROM information_schema.TABLE_CONSTRAINTS tc
WHERE tc.CONSTRAINT_SCHEMA = 'FPW'
  AND tc.CONSTRAINT_NAME IN (
    'fk_premium_send_receipts_entitlement_binding',
    'chk_premium_send_receipts_access_window',
    'chk_premium_send_receipts_membership_snapshot',
    'chk_premium_send_receipts_access_end',
    'chk_floatplans_expired_lifecycle'
  )
ORDER BY tc.TABLE_NAME, tc.CONSTRAINT_NAME;

SELECT
  UPPER(TRIM(fp.status)) AS plan_status,
  COUNT(*) AS plan_count,
  SUM(CASE WHEN UPPER(TRIM(fp.status)) = 'ACTIVE' THEN 1 ELSE 0 END) AS active_by_canonical_predicate
FROM floatplans fp
WHERE UPPER(TRIM(fp.status)) IN ('ACTIVE', 'EXPIRED')
GROUP BY UPPER(TRIM(fp.status))
ORDER BY plan_status;

SELECT
  @fpw_verify_20260801_001_columns AS compatible_phase1_columns,
  @fpw_verify_20260801_001_index_rows AS named_phase1_index_parts,
  @fpw_verify_20260801_001_index_parts AS compatible_phase1_index_parts,
  @fpw_verify_20260801_001_constraints AS compatible_phase1_constraints,
  @fpw_verify_20260801_001_check_semantics AS compatible_check_semantics,
  @fpw_verify_20260801_001_check_enforcement AS check_constraint_enforcement,
  @fpw_verify_20260801_001_enforced_checks AS enforced_phase1_checks,
  @fpw_verify_20260801_001_fk_parts AS compatible_entitlement_fk_parts,
  @fpw_verify_20260801_001_credit_window_violations AS credit_window_violations,
  @fpw_verify_20260801_001_general_window_violations AS general_premium_window_violations,
  @fpw_verify_20260801_001_binding_violations AS receipt_binding_violations,
  @fpw_verify_20260801_001_ended_receipt_violations AS ended_receipt_violations,
  @fpw_verify_20260801_001_active_receipt_violations AS active_receipt_end_violations,
  @fpw_verify_20260801_001_expired_lifecycle_violations AS expired_lifecycle_violations,
  @fpw_verify_20260801_001_nonexpired_metadata_violations AS nonexpired_lifecycle_metadata_violations,
  CASE
    WHEN CAST(DATABASE() AS BINARY) = CAST('FPW' AS BINARY)
     AND @fpw_verify_20260801_001_columns = 8
     AND @fpw_verify_20260801_001_index_rows = 8
     AND @fpw_verify_20260801_001_index_parts = 8
     AND @fpw_verify_20260801_001_constraints = 5
     AND @fpw_verify_20260801_001_check_semantics = 4
     AND @fpw_verify_20260801_001_check_enforcement = 1
     AND @fpw_verify_20260801_001_enforced_checks = 4
     AND @fpw_verify_20260801_001_fk_parts = 2
     AND @fpw_verify_20260801_001_credit_window_violations = 0
     AND @fpw_verify_20260801_001_general_window_violations = 0
     AND @fpw_verify_20260801_001_binding_violations = 0
     AND @fpw_verify_20260801_001_ended_receipt_violations = 0
     AND @fpw_verify_20260801_001_active_receipt_violations = 0
     AND @fpw_verify_20260801_001_expired_lifecycle_violations = 0
     AND @fpw_verify_20260801_001_nonexpired_metadata_violations = 0
    THEN 'PASS'
    ELSE 'FAIL'
  END AS verification_status;

SET @fpw_verify_20260801_001_columns = NULL;
SET @fpw_verify_20260801_001_index_rows = NULL;
SET @fpw_verify_20260801_001_index_parts = NULL;
SET @fpw_verify_20260801_001_constraints = NULL;
SET @fpw_verify_20260801_001_check_semantics = NULL;
SET @fpw_verify_20260801_001_enforced_checks = NULL;
SET @fpw_verify_20260801_001_enforced_checks_sql = NULL;
SET @fpw_verify_20260801_001_fk_parts = NULL;
SET @fpw_verify_20260801_001_credit_window_violations = NULL;
SET @fpw_verify_20260801_001_general_window_violations = NULL;
SET @fpw_verify_20260801_001_binding_violations = NULL;
SET @fpw_verify_20260801_001_ended_receipt_violations = NULL;
SET @fpw_verify_20260801_001_active_receipt_violations = NULL;
SET @fpw_verify_20260801_001_expired_lifecycle_violations = NULL;
SET @fpw_verify_20260801_001_nonexpired_metadata_violations = NULL;
SET @fpw_verify_20260801_001_check_enforcement = NULL;
SET @fpw_verify_20260801_001_is_mariadb = NULL;
SET @fpw_verify_20260801_001_check_sql = NULL;
