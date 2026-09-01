USE `FPW`;

-- Required in the same session before rollback:
-- SET @fpw_confirm_rollback_vessel_fuel_capacities = 'ROLLBACK_VESSEL_FUEL_CAPACITIES';

SET @fpw_down_20260831_002_error = NULL;
SET @fpw_down_20260831_002_table_count = 0;
SET @fpw_down_20260831_002_named_column_count = 0;
SET @fpw_down_20260831_002_source_column_count = 0;
SET @fpw_down_20260831_002_primary_source_nonnull = 0;
SET @fpw_down_20260831_002_aux_source_nonnull = 0;
SET @fpw_down_20260831_002_primary_source_total = 0;
SET @fpw_down_20260831_002_aux_source_total = 0;

SELECT COUNT(*)
INTO @fpw_down_20260831_002_table_count
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'vessels'
  AND TABLE_TYPE = 'BASE TABLE'
  AND ENGINE = 'InnoDB';

SELECT COUNT(*)
INTO @fpw_down_20260831_002_named_column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'vessels'
  AND COLUMN_NAME IN ('primaryFuelCapacity', 'auxFuelCapacity');

SELECT COUNT(*)
INTO @fpw_down_20260831_002_source_column_count
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

SET @fpw_down_20260831_002_data_sql = IF(
  @fpw_down_20260831_002_table_count = 1
  AND @fpw_down_20260831_002_named_column_count = 2
  AND @fpw_down_20260831_002_source_column_count = 2,
  'SELECT
     COALESCE(SUM(`primaryFuelCapacity` IS NOT NULL), 0),
     COALESCE(SUM(`auxFuelCapacity` IS NOT NULL), 0),
     COALESCE(SUM(`primaryFuelCapacity`), 0),
     COALESCE(SUM(`auxFuelCapacity`), 0)
   INTO
     @fpw_down_20260831_002_primary_source_nonnull,
     @fpw_down_20260831_002_aux_source_nonnull,
     @fpw_down_20260831_002_primary_source_total,
     @fpw_down_20260831_002_aux_source_total
   FROM `vessels`',
  'DO 0'
);
PREPARE fpw_down_20260831_002_data FROM @fpw_down_20260831_002_data_sql;
EXECUTE fpw_down_20260831_002_data;
DEALLOCATE PREPARE fpw_down_20260831_002_data;

SET @fpw_down_20260831_002_error = CASE
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    'Refusing rollback: selected database is not FPW.'
  WHEN @fpw_down_20260831_002_table_count <> 1 THEN
    'Refusing rollback: FPW.vessels must exist as an InnoDB base table.'
  WHEN @fpw_down_20260831_002_named_column_count <> 2 THEN
    'Refusing rollback: both vessel fuel-capacity columns must exist.'
  WHEN @fpw_down_20260831_002_source_column_count <> 2 THEN
    'Refusing rollback: both fuel-capacity columns must have the exact nullable DECIMAL(10,2) migration definition.'
  WHEN CAST(COALESCE(@fpw_confirm_rollback_vessel_fuel_capacities, '') AS BINARY)
       <> CAST('ROLLBACK_VESSEL_FUEL_CAPACITIES' AS BINARY) THEN
    'Refusing rollback: set @fpw_confirm_rollback_vessel_fuel_capacities to ROLLBACK_VESSEL_FUEL_CAPACITIES in this session.'
  ELSE NULL
END;

SELECT @fpw_down_20260831_002_error AS rollback_refusal
WHERE @fpw_down_20260831_002_error IS NOT NULL;

SET @fpw_down_20260831_002_guard_sql = IF(
  @fpw_down_20260831_002_error IS NULL,
  'DO 0',
  'SELECT `_fpw_rollback_refused_20260831_002` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_down_20260831_002_guard FROM @fpw_down_20260831_002_guard_sql;
EXECUTE fpw_down_20260831_002_guard;
DEALLOCATE PREPARE fpw_down_20260831_002_guard;

ALTER TABLE `vessels`
  MODIFY COLUMN `primaryFuelCapacity` VARCHAR(45)
    CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NULL DEFAULT NULL,
  MODIFY COLUMN `auxFuelCapacity` VARCHAR(45)
    CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NULL DEFAULT NULL;

SELECT COUNT(*)
INTO @fpw_down_20260831_002_target_column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'vessels'
  AND COLUMN_NAME IN ('primaryFuelCapacity', 'auxFuelCapacity')
  AND DATA_TYPE = 'varchar'
  AND CHARACTER_MAXIMUM_LENGTH = 45
  AND CHARACTER_SET_NAME = 'utf8mb3'
  AND COLLATION_NAME = 'utf8mb3_general_ci'
  AND IS_NULLABLE = 'YES'
  AND COLUMN_DEFAULT IS NULL
  AND EXTRA = '';

SELECT
  COALESCE(SUM(`primaryFuelCapacity` IS NOT NULL AND TRIM(`primaryFuelCapacity`) <> ''), 0),
  COALESCE(SUM(`auxFuelCapacity` IS NOT NULL AND TRIM(`auxFuelCapacity`) <> ''), 0),
  COALESCE(SUM(CASE WHEN `primaryFuelCapacity` IS NOT NULL AND TRIM(`primaryFuelCapacity`) <> '' THEN CAST(TRIM(`primaryFuelCapacity`) AS DECIMAL(10,2)) ELSE 0 END), 0),
  COALESCE(SUM(CASE WHEN `auxFuelCapacity` IS NOT NULL AND TRIM(`auxFuelCapacity`) <> '' THEN CAST(TRIM(`auxFuelCapacity`) AS DECIMAL(10,2)) ELSE 0 END), 0),
  COALESCE(SUM(CASE WHEN `primaryFuelCapacity` IS NOT NULL AND TRIM(`primaryFuelCapacity`) = '' THEN 1 ELSE 0 END), 0) + COALESCE(SUM(CASE WHEN `auxFuelCapacity` IS NOT NULL AND TRIM(`auxFuelCapacity`) = '' THEN 1 ELSE 0 END), 0)
INTO
  @fpw_down_20260831_002_primary_target_nonblank,
  @fpw_down_20260831_002_aux_target_nonblank,
  @fpw_down_20260831_002_primary_target_total,
  @fpw_down_20260831_002_aux_target_total,
  @fpw_down_20260831_002_target_blank_count
FROM `vessels`;

SET @fpw_down_20260831_002_post_error = CASE
  WHEN @fpw_down_20260831_002_target_column_count <> 2 THEN
    'Rollback failed verification: the original nullable VARCHAR(45) definitions were not restored.'
  WHEN @fpw_down_20260831_002_primary_target_nonblank <> @fpw_down_20260831_002_primary_source_nonnull
    OR @fpw_down_20260831_002_aux_target_nonblank <> @fpw_down_20260831_002_aux_source_nonnull THEN
    'Rollback failed verification: populated fuel-capacity counts changed.'
  WHEN NOT (@fpw_down_20260831_002_primary_target_total <=> @fpw_down_20260831_002_primary_source_total)
    OR NOT (@fpw_down_20260831_002_aux_target_total <=> @fpw_down_20260831_002_aux_source_total) THEN
    'Rollback failed verification: fuel-capacity totals changed.'
  WHEN @fpw_down_20260831_002_target_blank_count > 0 THEN
    'Rollback failed verification: unexpected blank strings were created.'
  ELSE NULL
END;

SELECT
  IF(@fpw_down_20260831_002_post_error IS NULL, 'PASS', 'FAIL') AS rollback_status,
  @fpw_down_20260831_002_primary_target_nonblank AS primary_values_preserved,
  @fpw_down_20260831_002_aux_target_nonblank AS auxiliary_values_preserved,
  @fpw_down_20260831_002_post_error AS rollback_error;

SET @fpw_down_20260831_002_post_guard_sql = IF(
  @fpw_down_20260831_002_post_error IS NULL,
  'DO 0',
  'SELECT `_fpw_rollback_verification_failed_20260831_002` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_down_20260831_002_post_guard FROM @fpw_down_20260831_002_post_guard_sql;
EXECUTE fpw_down_20260831_002_post_guard;
DEALLOCATE PREPARE fpw_down_20260831_002_post_guard;

SET @fpw_confirm_rollback_vessel_fuel_capacities = NULL;
SET @fpw_down_20260831_002_error = NULL;
SET @fpw_down_20260831_002_table_count = NULL;
SET @fpw_down_20260831_002_named_column_count = NULL;
SET @fpw_down_20260831_002_source_column_count = NULL;
SET @fpw_down_20260831_002_primary_source_nonnull = NULL;
SET @fpw_down_20260831_002_aux_source_nonnull = NULL;
SET @fpw_down_20260831_002_primary_source_total = NULL;
SET @fpw_down_20260831_002_aux_source_total = NULL;
SET @fpw_down_20260831_002_target_column_count = NULL;
SET @fpw_down_20260831_002_primary_target_nonblank = NULL;
SET @fpw_down_20260831_002_aux_target_nonblank = NULL;
SET @fpw_down_20260831_002_primary_target_total = NULL;
SET @fpw_down_20260831_002_aux_target_total = NULL;
SET @fpw_down_20260831_002_target_blank_count = NULL;
SET @fpw_down_20260831_002_post_error = NULL;
SET @fpw_down_20260831_002_data_sql = NULL;
SET @fpw_down_20260831_002_guard_sql = NULL;
SET @fpw_down_20260831_002_post_guard_sql = NULL;
