-- FPW Day 36 departure-reminder delivery-ledger production preflight.
-- Read-only apart from session variables and temporary prepared statements.

SET @fpw_preflight_20260831_001_error = NULL;
SET @fpw_preflight_20260831_001_existing_table = 0;
SET @fpw_preflight_20260831_001_parent_table = 0;
SET @fpw_preflight_20260831_001_parent_column = 0;

SELECT COUNT(*)
INTO @fpw_preflight_20260831_001_existing_table
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'departure_reminder_deliveries';

SELECT COUNT(*)
INTO @fpw_preflight_20260831_001_parent_table
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'floatplans'
  AND TABLE_TYPE = 'BASE TABLE'
  AND ENGINE = 'InnoDB';

SELECT COUNT(*)
INTO @fpw_preflight_20260831_001_parent_column
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'floatplans'
  AND COLUMN_NAME = 'floatPlanId'
  AND DATA_TYPE = 'int'
  AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%'
  AND IS_NULLABLE = 'NO';

SET @fpw_preflight_20260831_001_error = CASE
  WHEN DATABASE() IS NULL THEN
    'Refusing preflight: no database is selected.'
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    CONCAT('Refusing preflight: selected database is ', DATABASE(), ', not FPW.')
  WHEN @fpw_preflight_20260831_001_existing_table <> 0 THEN
    'Refusing preflight: departure_reminder_deliveries already exists.'
  WHEN @fpw_preflight_20260831_001_parent_table <> 1 THEN
    'Refusing preflight: floatplans must exist as an InnoDB table.'
  WHEN @fpw_preflight_20260831_001_parent_column <> 1 THEN
    'Refusing preflight: floatplans.floatPlanId must be a signed NOT NULL INT column.'
  ELSE NULL
END;

SELECT
  DATABASE() AS selected_database,
  VERSION() AS database_version,
  @fpw_preflight_20260831_001_existing_table AS existing_target_tables,
  @fpw_preflight_20260831_001_parent_table AS compatible_parent_tables,
  @fpw_preflight_20260831_001_parent_column AS compatible_parent_columns,
  IF(@fpw_preflight_20260831_001_error IS NULL, 'PASS', 'FAIL') AS preflight_status,
  @fpw_preflight_20260831_001_error AS preflight_error;

SET @fpw_preflight_20260831_001_guard_sql = IF(
  @fpw_preflight_20260831_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_production_preflight_refused_20260831_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_preflight_20260831_001_guard FROM @fpw_preflight_20260831_001_guard_sql;
EXECUTE fpw_preflight_20260831_001_guard;
DEALLOCATE PREPARE fpw_preflight_20260831_001_guard;

SET @fpw_preflight_20260831_001_error = NULL;
SET @fpw_preflight_20260831_001_existing_table = NULL;
SET @fpw_preflight_20260831_001_parent_table = NULL;
SET @fpw_preflight_20260831_001_parent_column = NULL;
SET @fpw_preflight_20260831_001_guard_sql = NULL;
