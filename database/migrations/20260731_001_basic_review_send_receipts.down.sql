USE `FPW`;

SET @fpw_down_20260731_001_error = NULL;
SET @fpw_down_20260731_001_table_count = 0;
SET @fpw_down_20260731_001_row_count = 0;

SELECT COUNT(*)
INTO @fpw_down_20260731_001_table_count
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'basic_review_send_receipts';

SET @fpw_down_20260731_001_count_sql = IF(
  @fpw_down_20260731_001_table_count = 1,
  'SELECT COUNT(*) INTO @fpw_down_20260731_001_row_count FROM `basic_review_send_receipts`',
  'SET @fpw_down_20260731_001_row_count = 0'
);
PREPARE fpw_down_20260731_001_count FROM @fpw_down_20260731_001_count_sql;
EXECUTE fpw_down_20260731_001_count;
DEALLOCATE PREPARE fpw_down_20260731_001_count;

SET @fpw_down_20260731_001_error = CASE
  WHEN DATABASE() <> 'FPW' THEN
    'Refusing rollback: selected database is not FPW.'
  WHEN @fpw_down_20260731_001_table_count <> 1 THEN
    'Refusing rollback: basic_review_send_receipts does not exist.'
  WHEN @fpw_down_20260731_001_row_count > 0 THEN
    'Refusing rollback: basic_review_send_receipts contains application data.'
  ELSE NULL
END;

SET @fpw_down_20260731_001_guard_sql = IF(
  @fpw_down_20260731_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_rollback_refused_20260731_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_down_20260731_001_guard FROM @fpw_down_20260731_001_guard_sql;
EXECUTE fpw_down_20260731_001_guard;
DEALLOCATE PREPARE fpw_down_20260731_001_guard;

DROP TABLE `basic_review_send_receipts`;

SET @fpw_down_20260731_001_error = NULL;
SET @fpw_down_20260731_001_table_count = NULL;
SET @fpw_down_20260731_001_row_count = NULL;
SET @fpw_down_20260731_001_count_sql = NULL;
SET @fpw_down_20260731_001_guard_sql = NULL;
