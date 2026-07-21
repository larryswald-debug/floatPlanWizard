USE `FPW`;

SELECT DATABASE() AS selected_database, VERSION() AS mysql_version;

SELECT
  TABLE_NAME,
  ENGINE,
  TABLE_COLLATION
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts')
ORDER BY TABLE_NAME;

SELECT
  TABLE_NAME,
  ORDINAL_POSITION,
  COLUMN_NAME,
  COLUMN_TYPE,
  IS_NULLABLE,
  COLUMN_KEY,
  EXTRA
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT
  TABLE_NAME,
  INDEX_NAME,
  NON_UNIQUE,
  SEQ_IN_INDEX,
  COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts')
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

SELECT
  tc.TABLE_NAME,
  tc.CONSTRAINT_NAME,
  tc.CONSTRAINT_TYPE,
  kcu.COLUMN_NAME,
  kcu.REFERENCED_TABLE_NAME,
  kcu.REFERENCED_COLUMN_NAME,
  rc.UPDATE_RULE,
  rc.DELETE_RULE
FROM information_schema.TABLE_CONSTRAINTS tc
LEFT JOIN information_schema.KEY_COLUMN_USAGE kcu
  ON kcu.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
 AND kcu.TABLE_NAME = tc.TABLE_NAME
 AND kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
LEFT JOIN information_schema.REFERENTIAL_CONSTRAINTS rc
  ON rc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
 AND rc.TABLE_NAME = tc.TABLE_NAME
 AND rc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
WHERE tc.CONSTRAINT_SCHEMA = 'FPW'
  AND tc.TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts')
ORDER BY tc.TABLE_NAME, tc.CONSTRAINT_TYPE, tc.CONSTRAINT_NAME, kcu.ORDINAL_POSITION;

SELECT
  tc.TABLE_NAME,
  tc.CONSTRAINT_NAME,
  tc.ENFORCED,
  cc.CHECK_CLAUSE
FROM information_schema.TABLE_CONSTRAINTS tc
INNER JOIN information_schema.CHECK_CONSTRAINTS cc
  ON cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
 AND cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
WHERE tc.CONSTRAINT_SCHEMA = 'FPW'
  AND tc.TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts')
  AND tc.CONSTRAINT_TYPE = 'CHECK'
ORDER BY tc.TABLE_NAME, tc.CONSTRAINT_NAME;

SET @fpw_phase2_expected_metadata = JSON_ARRAY(
  'DATABASE|FPW',
  'TABLE|premium_send_credits|BASE TABLE|InnoDB|utf8mb4_unicode_ci',
  'TABLE|premium_send_receipts|BASE TABLE|InnoDB|utf8mb4_unicode_ci',

  'COLUMN|premium_send_credits|1|id|bigint unsigned|NO|<NULL>|auto_increment|<NULL>|<NULL>',
  'COLUMN|premium_send_credits|2|user_id|int|NO|<NULL>|<NONE>|<NULL>|<NULL>',
  'COLUMN|premium_send_credits|3|source|varchar(32)|NO|<NULL>|<NONE>|utf8mb4|utf8mb4_unicode_ci',
  'COLUMN|premium_send_credits|4|status|varchar(16)|NO|<NULL>|<NONE>|utf8mb4|utf8mb4_unicode_ci',
  'COLUMN|premium_send_credits|5|consumed_float_plan_id|int|YES|<NULL>|<NONE>|<NULL>|<NULL>',
  'COLUMN|premium_send_credits|6|idempotency_key|varchar(191)|NO|<NULL>|<NONE>|utf8mb4|utf8mb4_unicode_ci',
  'COLUMN|premium_send_credits|7|stripe_checkout_session_id|varchar(255)|YES|<NULL>|<NONE>|utf8mb4|utf8mb4_unicode_ci',
  'COLUMN|premium_send_credits|8|stripe_payment_intent_id|varchar(255)|YES|<NULL>|<NONE>|utf8mb4|utf8mb4_unicode_ci',
  'COLUMN|premium_send_credits|9|granted_at_utc|datetime(6)|NO|<NULL>|<NONE>|<NULL>|<NULL>',
  'COLUMN|premium_send_credits|10|consumed_at_utc|datetime(6)|YES|<NULL>|<NONE>|<NULL>|<NULL>',
  'COLUMN|premium_send_credits|11|created_at_utc|datetime(6)|NO|<NULL>|<NONE>|<NULL>|<NULL>',
  'COLUMN|premium_send_credits|12|updated_at_utc|datetime(6)|NO|<NULL>|<NONE>|<NULL>|<NULL>',
  'COLUMN|premium_send_receipts|1|id|bigint unsigned|NO|<NULL>|auto_increment|<NULL>|<NULL>',
  'COLUMN|premium_send_receipts|2|user_id|int|NO|<NULL>|<NONE>|<NULL>|<NULL>',
  'COLUMN|premium_send_receipts|3|float_plan_id|int|NO|<NULL>|<NONE>|<NULL>|<NULL>',
  'COLUMN|premium_send_receipts|4|credit_id|bigint unsigned|YES|<NULL>|<NONE>|<NULL>|<NULL>',
  'COLUMN|premium_send_receipts|5|access_source|varchar(32)|NO|<NULL>|<NONE>|utf8mb4|utf8mb4_unicode_ci',
  'COLUMN|premium_send_receipts|6|recipient_count|int unsigned|NO|<NULL>|<NONE>|<NULL>|<NULL>',
  'COLUMN|premium_send_receipts|7|original_response_json|json|NO|<NULL>|<NONE>|<NULL>|<NULL>',
  'COLUMN|premium_send_receipts|8|committed_at_utc|datetime(6)|NO|<NULL>|<NONE>|<NULL>|<NULL>',
  'COLUMN|premium_send_receipts|9|created_at_utc|datetime(6)|NO|<NULL>|<NONE>|<NULL>|<NULL>',

  'INDEX|premium_send_credits|ix_premium_send_credits_available|1|1|user_id',
  'INDEX|premium_send_credits|ix_premium_send_credits_available|1|2|status',
  'INDEX|premium_send_credits|ix_premium_send_credits_available|1|3|granted_at_utc',
  'INDEX|premium_send_credits|ix_premium_send_credits_available|1|4|id',
  'INDEX|premium_send_credits|PRIMARY|0|1|id',
  'INDEX|premium_send_credits|uq_premium_send_credits_checkout|0|1|stripe_checkout_session_id',
  'INDEX|premium_send_credits|uq_premium_send_credits_float_plan|0|1|consumed_float_plan_id',
  'INDEX|premium_send_credits|uq_premium_send_credits_idempotency|0|1|idempotency_key',
  'INDEX|premium_send_credits|uq_premium_send_credits_payment_intent|0|1|stripe_payment_intent_id',
  'INDEX|premium_send_credits|uq_premium_send_credits_receipt_binding|0|1|id',
  'INDEX|premium_send_credits|uq_premium_send_credits_receipt_binding|0|2|user_id',
  'INDEX|premium_send_credits|uq_premium_send_credits_receipt_binding|0|3|consumed_float_plan_id',
  'INDEX|premium_send_receipts|ix_premium_send_receipts_credit_binding|1|1|credit_id',
  'INDEX|premium_send_receipts|ix_premium_send_receipts_credit_binding|1|2|user_id',
  'INDEX|premium_send_receipts|ix_premium_send_receipts_credit_binding|1|3|float_plan_id',
  'INDEX|premium_send_receipts|ix_premium_send_receipts_user|1|1|user_id',
  'INDEX|premium_send_receipts|ix_premium_send_receipts_user|1|2|committed_at_utc',
  'INDEX|premium_send_receipts|ix_premium_send_receipts_user|1|3|id',
  'INDEX|premium_send_receipts|PRIMARY|0|1|id',
  'INDEX|premium_send_receipts|uq_premium_send_receipts_float_plan|0|1|float_plan_id',

  'FK|premium_send_credits|fk_premium_send_credits_float_plan|1|consumed_float_plan_id|floatplans|floatPlanId|RESTRICT|RESTRICT',
  'FK|premium_send_credits|fk_premium_send_credits_user|1|user_id|users|userId|RESTRICT|RESTRICT',
  'FK|premium_send_receipts|fk_premium_send_receipts_credit_binding|1|credit_id|premium_send_credits|id|RESTRICT|RESTRICT',
  'FK|premium_send_receipts|fk_premium_send_receipts_credit_binding|2|user_id|premium_send_credits|user_id|RESTRICT|RESTRICT',
  'FK|premium_send_receipts|fk_premium_send_receipts_credit_binding|3|float_plan_id|premium_send_credits|consumed_float_plan_id|RESTRICT|RESTRICT',
  'FK|premium_send_receipts|fk_premium_send_receipts_float_plan|1|float_plan_id|floatplans|floatPlanId|RESTRICT|RESTRICT',
  'FK|premium_send_receipts|fk_premium_send_receipts_user|1|user_id|users|userId|RESTRICT|RESTRICT',

  'CHECK|premium_send_credits|chk_premium_send_credits_source|YES|(sourcein(''complimentary_signup'',''stripe_one_trip'',''promotion'',''admin_grant''))',
  'CHECK|premium_send_credits|chk_premium_send_credits_state|YES|(((status=''available'')and(consumed_float_plan_idisnull)and(consumed_at_utcisnull))or((status=''consumed'')and(consumed_float_plan_idisnotnull)and(consumed_at_utcisnotnull)))',
  'CHECK|premium_send_credits|chk_premium_send_credits_status|YES|(statusin(''available'',''consumed''))',
  'CHECK|premium_send_receipts|chk_premium_send_receipts_access_source|YES|(access_sourcein(''general_premium'',''premium_send_credit''))',
  'CHECK|premium_send_receipts|chk_premium_send_receipts_credit_source|YES|(((access_source=''general_premium'')and(credit_idisnull))or((access_source=''premium_send_credit'')and(credit_idisnotnull)))',
  'CHECK|premium_send_receipts|chk_premium_send_receipts_recipient_count|YES|(recipient_count>0)'
);

DROP TEMPORARY TABLE IF EXISTS `_fpw_phase2_verify_mismatches`;
CREATE TEMPORARY TABLE `_fpw_phase2_verify_mismatches` AS
SELECT
  MIN(verification_tuple) AS mismatch_tuple,
  SUM(tuple_origin = 'expected') AS expected_count,
  SUM(tuple_origin = 'actual') AS actual_count
FROM (
  SELECT expected_rows.verification_tuple, 'expected' AS tuple_origin
  FROM JSON_TABLE(
    @fpw_phase2_expected_metadata,
    '$[*]' COLUMNS (verification_tuple VARCHAR(2048) PATH '$')
  ) AS expected_rows

  UNION ALL

  SELECT actual_rows.verification_tuple, 'actual' AS tuple_origin
  FROM (
    SELECT CONCAT_WS('|', 'DATABASE', DATABASE()) AS verification_tuple

    UNION ALL

    SELECT CONCAT_WS('|', 'TABLE', TABLE_NAME, TABLE_TYPE, COALESCE(ENGINE, '<NULL>'), COALESCE(TABLE_COLLATION, '<NULL>'))
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts')

    UNION ALL

    SELECT CONCAT_WS(
      '|', 'COLUMN', TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE,
      COALESCE(CAST(COLUMN_DEFAULT AS CHAR), '<NULL>'),
      COALESCE(NULLIF(EXTRA, ''), '<NONE>'),
      COALESCE(CHARACTER_SET_NAME, '<NULL>'),
      COALESCE(COLLATION_NAME, '<NULL>')
    )
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts')

    UNION ALL

    SELECT CONCAT_WS('|', 'INDEX', TABLE_NAME, INDEX_NAME, NON_UNIQUE, SEQ_IN_INDEX, COLUMN_NAME)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts')

    UNION ALL

    SELECT CONCAT_WS(
      '|', 'FK', kcu.TABLE_NAME, kcu.CONSTRAINT_NAME, kcu.ORDINAL_POSITION,
      kcu.COLUMN_NAME, kcu.REFERENCED_TABLE_NAME, kcu.REFERENCED_COLUMN_NAME,
      rc.UPDATE_RULE, rc.DELETE_RULE
    )
    FROM information_schema.KEY_COLUMN_USAGE kcu
    INNER JOIN information_schema.REFERENTIAL_CONSTRAINTS rc
      ON rc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA
     AND rc.TABLE_NAME = kcu.TABLE_NAME
     AND rc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    WHERE kcu.CONSTRAINT_SCHEMA = 'FPW'
      AND kcu.TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts')
      AND kcu.REFERENCED_TABLE_NAME IS NOT NULL

    UNION ALL

    SELECT CONCAT_WS(
      '|', 'CHECK', tc.TABLE_NAME, tc.CONSTRAINT_NAME, tc.ENFORCED,
      REGEXP_REPLACE(
        REPLACE(
          REPLACE(
            REPLACE(
              REPLACE(
                REPLACE(LOWER(cc.CHECK_CLAUSE), '_latin1', ''),
                '_utf8mb4', ''
              ),
              '_utf8mb3', ''
            ),
            CHAR(96), ''
          ),
          CHAR(92), ''
        ),
        '[[:space:]]+',
        ''
      )
    )
    FROM information_schema.TABLE_CONSTRAINTS tc
    INNER JOIN information_schema.CHECK_CONSTRAINTS cc
      ON cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
     AND cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
    WHERE tc.CONSTRAINT_SCHEMA = 'FPW'
      AND tc.TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts')
      AND tc.CONSTRAINT_TYPE = 'CHECK'
  ) AS actual_rows
) AS combined_rows
GROUP BY HEX(verification_tuple)
HAVING SUM(tuple_origin = 'expected') <> 1
    OR SUM(tuple_origin = 'actual') <> 1;

SELECT mismatch_tuple, expected_count, actual_count
FROM `_fpw_phase2_verify_mismatches`
ORDER BY HEX(mismatch_tuple);

SET @fpw_phase2_verify_error = IF(
  (SELECT COUNT(*) FROM `_fpw_phase2_verify_mismatches`) = 0,
  NULL,
  'Phase 2 Premium Send schema verification failed. See mismatch tuples above.'
);

DROP TEMPORARY TABLE `_fpw_phase2_verify_mismatches`;
SET @fpw_phase2_expected_metadata = NULL;

SELECT
  IF(@fpw_phase2_verify_error IS NULL, 'PASS', 'FAIL') AS verification_status,
  @fpw_phase2_verify_error AS verification_error;

SET @fpw_phase2_verify_guard_sql = IF(
  @fpw_phase2_verify_error IS NULL,
  'DO 0',
  'SELECT `_fpw_phase2_schema_verification_failed`'
);
PREPARE fpw_phase2_verify_guard FROM @fpw_phase2_verify_guard_sql;
EXECUTE fpw_phase2_verify_guard;
DEALLOCATE PREPARE fpw_phase2_verify_guard;

SET @fpw_phase2_verify_guard_sql = NULL;
SET @fpw_phase2_verify_error = NULL;

SELECT
  (SELECT COUNT(*) FROM `premium_send_credits`) AS credit_rows,
  (SELECT COUNT(*) FROM `premium_send_receipts`) AS receipt_rows;
