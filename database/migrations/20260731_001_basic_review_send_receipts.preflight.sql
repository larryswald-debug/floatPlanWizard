-- FPW Basic Review Send receipt production preflight.
-- Read-only apart from session variables and temporary prepared statements.

SET @fpw_preflight_20260731_001_error = NULL;
SET @fpw_preflight_20260731_001_existing_table = 0;
SET @fpw_preflight_20260731_001_parent_tables = 0;
SET @fpw_preflight_20260731_001_parent_columns = 0;

SELECT COUNT(*)
INTO @fpw_preflight_20260731_001_existing_table
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'basic_review_send_receipts';

SELECT COUNT(*)
INTO @fpw_preflight_20260731_001_parent_tables
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_TYPE = 'BASE TABLE'
  AND ENGINE = 'InnoDB'
  AND TABLE_NAME IN ('users', 'floatplans');

SELECT COUNT(*)
INTO @fpw_preflight_20260731_001_parent_columns
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND (
    (
      TABLE_NAME = 'users'
      AND COLUMN_NAME = 'userId'
      AND DATA_TYPE = 'int'
      AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%'
      AND IS_NULLABLE = 'NO'
    )
    OR
    (
      TABLE_NAME = 'floatplans'
      AND COLUMN_NAME = 'floatPlanId'
      AND DATA_TYPE = 'int'
      AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%'
      AND IS_NULLABLE = 'NO'
    )
  );

SET @fpw_preflight_20260731_001_error = CASE
  WHEN DATABASE() IS NULL THEN
    'Refusing preflight: no database is selected.'
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    CONCAT('Refusing preflight: selected database is ', DATABASE(), ', not FPW.')
  WHEN @fpw_preflight_20260731_001_existing_table <> 0 THEN
    'Refusing preflight: basic_review_send_receipts already exists.'
  WHEN @fpw_preflight_20260731_001_parent_tables <> 2 THEN
    'Refusing preflight: users and floatplans must exist as InnoDB tables.'
  WHEN @fpw_preflight_20260731_001_parent_columns <> 2 THEN
    'Refusing preflight: users.userId and floatplans.floatPlanId must be signed NOT NULL INT columns.'
  ELSE NULL
END;

SELECT
  DATABASE() AS selected_database,
  VERSION() AS database_version,
  @fpw_preflight_20260731_001_existing_table AS existing_target_tables,
  @fpw_preflight_20260731_001_parent_tables AS compatible_parent_tables,
  @fpw_preflight_20260731_001_parent_columns AS compatible_parent_columns,
  IF(@fpw_preflight_20260731_001_error IS NULL, 'PASS', 'FAIL') AS preflight_status,
  @fpw_preflight_20260731_001_error AS preflight_error;

SET @fpw_preflight_20260731_001_guard_sql = IF(
  @fpw_preflight_20260731_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_production_preflight_refused_20260731_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_preflight_20260731_001_guard FROM @fpw_preflight_20260731_001_guard_sql;
EXECUTE fpw_preflight_20260731_001_guard;
DEALLOCATE PREPARE fpw_preflight_20260731_001_guard;

SET @fpw_preflight_20260731_001_error = NULL;
SET @fpw_preflight_20260731_001_existing_table = NULL;
SET @fpw_preflight_20260731_001_parent_tables = NULL;
SET @fpw_preflight_20260731_001_parent_columns = NULL;
SET @fpw_preflight_20260731_001_guard_sql = NULL;
