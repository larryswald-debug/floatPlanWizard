USE `FPW`;

SELECT DATABASE() AS selected_database, VERSION() AS database_version;

SELECT
  COLUMN_NAME,
  COLUMN_TYPE,
  DATA_TYPE,
  IS_NULLABLE,
  COLUMN_DEFAULT,
  NUMERIC_PRECISION,
  NUMERIC_SCALE,
  EXTRA
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'vessels'
  AND COLUMN_NAME IN ('fuel_capacity', 'primaryFuelCapacity', 'auxFuelCapacity')
ORDER BY ORDINAL_POSITION;

SET @fpw_verify_20260831_002_database_ok = CAST(DATABASE() AS BINARY) = CAST('FPW' AS BINARY);

SELECT COUNT(*)
INTO @fpw_verify_20260831_002_target_column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'vessels'
  AND COLUMN_NAME IN ('primaryFuelCapacity', 'auxFuelCapacity')
  AND DATA_TYPE = 'decimal'
  AND NUMERIC_PRECISION = 10
  AND NUMERIC_SCALE = 2
  AND IS_NULLABLE = 'YES'
  AND COLUMN_DEFAULT IS NULL
  AND EXTRA = '';

SELECT
  COUNT(*) AS total_vessels,
  SUM(`primaryFuelCapacity` IS NULL) AS primary_unknown_values,
  SUM(`primaryFuelCapacity` IS NOT NULL) AS primary_populated_values,
  SUM(`auxFuelCapacity` IS NULL) AS auxiliary_unknown_values,
  SUM(`auxFuelCapacity` IS NOT NULL) AS auxiliary_populated_values,
  SUM(CASE WHEN `primaryFuelCapacity` < 0 OR `auxFuelCapacity` < 0 THEN 1 ELSE 0 END) AS negative_values
FROM `vessels`;

SELECT COUNT(*)
INTO @fpw_verify_20260831_002_negative_count
FROM `vessels`
WHERE `primaryFuelCapacity` < 0
   OR `auxFuelCapacity` < 0;

SET @fpw_verify_20260831_002_status = IF(
  @fpw_verify_20260831_002_database_ok = 1
  AND @fpw_verify_20260831_002_target_column_count = 2
  AND @fpw_verify_20260831_002_negative_count = 0,
  'PASS',
  'FAIL'
);

SELECT
  @fpw_verify_20260831_002_status AS verification_status,
  @fpw_verify_20260831_002_database_ok AS database_ok,
  @fpw_verify_20260831_002_target_column_count AS compatible_target_columns,
  @fpw_verify_20260831_002_negative_count AS negative_values;

SET @fpw_verify_20260831_002_guard_sql = IF(
  @fpw_verify_20260831_002_status = 'PASS',
  'DO 0',
  'SELECT `_fpw_verification_failed_20260831_002` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_verify_20260831_002_guard
FROM @fpw_verify_20260831_002_guard_sql;
EXECUTE fpw_verify_20260831_002_guard;
DEALLOCATE PREPARE fpw_verify_20260831_002_guard;

SET @fpw_verify_20260831_002_database_ok = NULL;
SET @fpw_verify_20260831_002_target_column_count = NULL;
SET @fpw_verify_20260831_002_negative_count = NULL;
SET @fpw_verify_20260831_002_status = NULL;
SET @fpw_verify_20260831_002_guard_sql = NULL;
