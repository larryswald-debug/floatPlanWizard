SELECT
  CASE
    WHEN COUNT(*) = 12
      AND SUM(COLUMN_NAME = 'id' AND DATA_TYPE = 'bigint' AND LOWER(COLUMN_TYPE) LIKE '%unsigned%' AND EXTRA = 'auto_increment') = 1
      AND SUM(COLUMN_NAME = 'user_id' AND DATA_TYPE = 'int' AND IS_NULLABLE = 'NO') = 1
      AND SUM(COLUMN_NAME = 'recovery_stage' AND COLUMN_TYPE = 'char(1)' AND IS_NULLABLE = 'NO') = 1
      AND SUM(COLUMN_NAME = 'status' AND COLUMN_TYPE = 'varchar(16)' AND IS_NULLABLE = 'NO') = 1
      AND SUM(COLUMN_NAME = 'claim_token' AND COLUMN_TYPE = 'char(64)' AND IS_NULLABLE = 'NO') = 1
      AND SUM(COLUMN_NAME IN ('claimed_at_utc','created_at_utc','updated_at_utc') AND COLUMN_TYPE = 'datetime(6)' AND IS_NULLABLE = 'NO') = 3
      AND SUM(COLUMN_NAME IN ('sent_at_utc','failed_at_utc') AND COLUMN_TYPE = 'datetime(6)' AND IS_NULLABLE = 'YES') = 2
      AND SUM(COLUMN_NAME = 'attempt_count' AND DATA_TYPE = 'int' AND IS_NULLABLE = 'NO') = 1
      AND SUM(COLUMN_NAME = 'last_error_summary' AND COLUMN_TYPE = 'varchar(64)' AND IS_NULLABLE = 'YES') = 1
    THEN 'PASS' ELSE 'FAIL'
  END AS column_contract
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'inactive_member_recovery_deliveries';

SELECT
  IF(COUNT(*) = 1, 'PASS', 'FAIL') AS unique_contract
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'inactive_member_recovery_deliveries'
  AND INDEX_NAME = 'uq_inactive_recovery_member_stage'
  AND NON_UNIQUE = 0
  AND SEQ_IN_INDEX = 1
  AND COLUMN_NAME = 'user_id'
  AND EXISTS (
    SELECT 1 FROM information_schema.STATISTICS s2
    WHERE s2.TABLE_SCHEMA = 'FPW'
      AND s2.TABLE_NAME = 'inactive_member_recovery_deliveries'
      AND s2.INDEX_NAME = 'uq_inactive_recovery_member_stage'
      AND s2.NON_UNIQUE = 0
      AND s2.SEQ_IN_INDEX = 2
      AND s2.COLUMN_NAME = 'recovery_stage'
  );

SELECT
  IF(COUNT(*) = 1 AND MAX(DELETE_RULE) = 'CASCADE', 'PASS', 'FAIL') AS account_delete_contract
FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'FPW'
  AND TABLE_NAME = 'inactive_member_recovery_deliveries'
  AND CONSTRAINT_NAME = 'fk_inactive_recovery_user';

SELECT
  IF(COUNT(*) = 4, 'PASS', 'FAIL') AS check_contract
FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'FPW'
  AND TABLE_NAME = 'inactive_member_recovery_deliveries'
  AND CONSTRAINT_TYPE = 'CHECK'
  AND CONSTRAINT_NAME IN (
    'chk_inactive_recovery_stage',
    'chk_inactive_recovery_status',
    'chk_inactive_recovery_attempt_count',
    'chk_inactive_recovery_terminal_time'
  );
