USE `FPW`;

SET @fpw_up_20260831_002_error = NULL;
SET @fpw_up_20260831_002_table_count = 0;
SET @fpw_up_20260831_002_named_column_count = 0;
SET @fpw_up_20260831_002_source_column_count = 0;
SET @fpw_up_20260831_002_primary_nonblank = 0;
SET @fpw_up_20260831_002_aux_nonblank = 0;
SET @fpw_up_20260831_002_primary_blank = 0;
SET @fpw_up_20260831_002_aux_blank = 0;
SET @fpw_up_20260831_002_negative_count = 0;
SET @fpw_up_20260831_002_invalid_count = 0;
SET @fpw_up_20260831_002_overprecision_count = 0;
SET @fpw_up_20260831_002_out_of_range_count = 0;
SET @fpw_up_20260831_002_primary_source_total = 0;
SET @fpw_up_20260831_002_aux_source_total = 0;

SELECT COUNT(*)
INTO @fpw_up_20260831_002_table_count
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'vessels'
  AND TABLE_TYPE = 'BASE TABLE'
  AND ENGINE = 'InnoDB';

SELECT COUNT(*)
INTO @fpw_up_20260831_002_named_column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'vessels'
  AND COLUMN_NAME IN ('primaryFuelCapacity', 'auxFuelCapacity');

SELECT COUNT(*)
INTO @fpw_up_20260831_002_source_column_count
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

SET @fpw_up_20260831_002_data_sql = IF(
  @fpw_up_20260831_002_table_count = 1
  AND @fpw_up_20260831_002_named_column_count = 2
  AND @fpw_up_20260831_002_source_column_count = 2,
  'SELECT
     COALESCE(SUM(CASE WHEN `primaryFuelCapacity` IS NOT NULL AND TRIM(CAST(`primaryFuelCapacity` AS CHAR)) <> '''' THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN `auxFuelCapacity` IS NOT NULL AND TRIM(CAST(`auxFuelCapacity` AS CHAR)) <> '''' THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN `primaryFuelCapacity` IS NOT NULL AND TRIM(CAST(`primaryFuelCapacity` AS CHAR)) = '''' THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN `auxFuelCapacity` IS NOT NULL AND TRIM(CAST(`auxFuelCapacity` AS CHAR)) = '''' THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN TRIM(CAST(`primaryFuelCapacity` AS CHAR)) REGEXP ''^-[0-9]+([.][0-9]+)?$'' THEN 1 ELSE 0 END), 0) + COALESCE(SUM(CASE WHEN TRIM(CAST(`auxFuelCapacity` AS CHAR)) REGEXP ''^-[0-9]+([.][0-9]+)?$'' THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN `primaryFuelCapacity` IS NOT NULL AND TRIM(CAST(`primaryFuelCapacity` AS CHAR)) <> '''' AND TRIM(CAST(`primaryFuelCapacity` AS CHAR)) NOT REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' AND TRIM(CAST(`primaryFuelCapacity` AS CHAR)) NOT REGEXP ''^-[0-9]+([.][0-9]+)?$'' THEN 1 ELSE 0 END), 0) + COALESCE(SUM(CASE WHEN `auxFuelCapacity` IS NOT NULL AND TRIM(CAST(`auxFuelCapacity` AS CHAR)) <> '''' AND TRIM(CAST(`auxFuelCapacity` AS CHAR)) NOT REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' AND TRIM(CAST(`auxFuelCapacity` AS CHAR)) NOT REGEXP ''^-[0-9]+([.][0-9]+)?$'' THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN TRIM(CAST(`primaryFuelCapacity` AS CHAR)) REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' AND LOCATE(''.'', TRIM(CAST(`primaryFuelCapacity` AS CHAR))) > 0 AND LENGTH(SUBSTRING_INDEX(TRIM(CAST(`primaryFuelCapacity` AS CHAR)), ''.'', -1)) > 2 THEN 1 ELSE 0 END), 0) + COALESCE(SUM(CASE WHEN TRIM(CAST(`auxFuelCapacity` AS CHAR)) REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' AND LOCATE(''.'', TRIM(CAST(`auxFuelCapacity` AS CHAR))) > 0 AND LENGTH(SUBSTRING_INDEX(TRIM(CAST(`auxFuelCapacity` AS CHAR)), ''.'', -1)) > 2 THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN TRIM(CAST(`primaryFuelCapacity` AS CHAR)) REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' AND CAST(TRIM(CAST(`primaryFuelCapacity` AS CHAR)) AS DECIMAL(65,10)) > 99999999.99 THEN 1 ELSE 0 END), 0) + COALESCE(SUM(CASE WHEN TRIM(CAST(`auxFuelCapacity` AS CHAR)) REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' AND CAST(TRIM(CAST(`auxFuelCapacity` AS CHAR)) AS DECIMAL(65,10)) > 99999999.99 THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN `primaryFuelCapacity` IS NOT NULL AND TRIM(CAST(`primaryFuelCapacity` AS CHAR)) <> '''' AND TRIM(CAST(`primaryFuelCapacity` AS CHAR)) REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' THEN CAST(TRIM(CAST(`primaryFuelCapacity` AS CHAR)) AS DECIMAL(65,2)) ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN `auxFuelCapacity` IS NOT NULL AND TRIM(CAST(`auxFuelCapacity` AS CHAR)) <> '''' AND TRIM(CAST(`auxFuelCapacity` AS CHAR)) REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' THEN CAST(TRIM(CAST(`auxFuelCapacity` AS CHAR)) AS DECIMAL(65,2)) ELSE 0 END), 0)
   INTO
     @fpw_up_20260831_002_primary_nonblank,
     @fpw_up_20260831_002_aux_nonblank,
     @fpw_up_20260831_002_primary_blank,
     @fpw_up_20260831_002_aux_blank,
     @fpw_up_20260831_002_negative_count,
     @fpw_up_20260831_002_invalid_count,
     @fpw_up_20260831_002_overprecision_count,
     @fpw_up_20260831_002_out_of_range_count,
     @fpw_up_20260831_002_primary_source_total,
     @fpw_up_20260831_002_aux_source_total
   FROM `vessels`',
  'DO 0'
);
PREPARE fpw_up_20260831_002_data FROM @fpw_up_20260831_002_data_sql;
EXECUTE fpw_up_20260831_002_data;
DEALLOCATE PREPARE fpw_up_20260831_002_data;

SET @fpw_up_20260831_002_error = CASE
  WHEN @fpw_up_20260831_002_table_count <> 1 THEN
    'Refusing migration: FPW.vessels must exist as an InnoDB base table.'
  WHEN @fpw_up_20260831_002_named_column_count <> 2 THEN
    'Refusing migration: both vessel fuel-capacity source columns must exist.'
  WHEN @fpw_up_20260831_002_source_column_count <> 2 THEN
    'Refusing migration: primaryFuelCapacity and auxFuelCapacity must match the snapshotted nullable utf8mb3 VARCHAR(45) definition with NULL defaults.'
  WHEN @fpw_up_20260831_002_negative_count > 0 THEN
    'Refusing migration: negative primary or auxiliary fuel-capacity values require owner review.'
  WHEN @fpw_up_20260831_002_invalid_count > 0 THEN
    'Refusing migration: mixed or nonnumeric primary or auxiliary fuel-capacity values require owner review.'
  WHEN @fpw_up_20260831_002_overprecision_count > 0 THEN
    'Refusing migration: values with more than two decimal places would be rounded by DECIMAL(10,2).'
  WHEN @fpw_up_20260831_002_out_of_range_count > 0 THEN
    'Refusing migration: one or more fuel-capacity values exceed DECIMAL(10,2).'
  ELSE NULL
END;

SELECT @fpw_up_20260831_002_error AS migration_refusal
WHERE @fpw_up_20260831_002_error IS NOT NULL;

SET @fpw_up_20260831_002_guard_sql = IF(
  @fpw_up_20260831_002_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_refused_20260831_002` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260831_002_guard FROM @fpw_up_20260831_002_guard_sql;
EXECUTE fpw_up_20260831_002_guard;
DEALLOCATE PREPARE fpw_up_20260831_002_guard;

UPDATE `vessels`
SET `primaryFuelCapacity` = NULL
WHERE `primaryFuelCapacity` IS NOT NULL
  AND TRIM(CAST(`primaryFuelCapacity` AS CHAR)) = '';
SET @fpw_up_20260831_002_primary_blanks_normalized = ROW_COUNT();

UPDATE `vessels`
SET `auxFuelCapacity` = NULL
WHERE `auxFuelCapacity` IS NOT NULL
  AND TRIM(CAST(`auxFuelCapacity` AS CHAR)) = '';
SET @fpw_up_20260831_002_aux_blanks_normalized = ROW_COUNT();

ALTER TABLE `vessels`
  MODIFY COLUMN `primaryFuelCapacity` DECIMAL(10,2) NULL DEFAULT NULL,
  MODIFY COLUMN `auxFuelCapacity` DECIMAL(10,2) NULL DEFAULT NULL;

SELECT COUNT(*)
INTO @fpw_up_20260831_002_target_column_count
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
  COALESCE(SUM(`primaryFuelCapacity` IS NOT NULL), 0),
  COALESCE(SUM(`auxFuelCapacity` IS NOT NULL), 0),
  COALESCE(SUM(`primaryFuelCapacity`), 0),
  COALESCE(SUM(`auxFuelCapacity`), 0),
  COALESCE(SUM(CASE WHEN `primaryFuelCapacity` < 0 OR `auxFuelCapacity` < 0 THEN 1 ELSE 0 END), 0)
INTO
  @fpw_up_20260831_002_primary_target_nonnull,
  @fpw_up_20260831_002_aux_target_nonnull,
  @fpw_up_20260831_002_primary_target_total,
  @fpw_up_20260831_002_aux_target_total,
  @fpw_up_20260831_002_target_negative_count
FROM `vessels`;

SET @fpw_up_20260831_002_post_error = CASE
  WHEN @fpw_up_20260831_002_target_column_count <> 2 THEN
    'Migration failed verification: the target fuel-capacity column definitions are incompatible.'
  WHEN @fpw_up_20260831_002_primary_blanks_normalized <> @fpw_up_20260831_002_primary_blank
    OR @fpw_up_20260831_002_aux_blanks_normalized <> @fpw_up_20260831_002_aux_blank THEN
    'Migration failed verification: not all blank source values were normalized to NULL.'
  WHEN @fpw_up_20260831_002_primary_target_nonnull <> @fpw_up_20260831_002_primary_nonblank
    OR @fpw_up_20260831_002_aux_target_nonnull <> @fpw_up_20260831_002_aux_nonblank THEN
    'Migration failed verification: populated fuel-capacity counts changed.'
  WHEN NOT (@fpw_up_20260831_002_primary_target_total <=> @fpw_up_20260831_002_primary_source_total)
    OR NOT (@fpw_up_20260831_002_aux_target_total <=> @fpw_up_20260831_002_aux_source_total) THEN
    'Migration failed verification: fuel-capacity totals changed.'
  WHEN @fpw_up_20260831_002_target_negative_count > 0 THEN
    'Migration failed verification: negative target values exist.'
  ELSE NULL
END;

SELECT
  IF(@fpw_up_20260831_002_post_error IS NULL, 'PASS', 'FAIL') AS migration_status,
  @fpw_up_20260831_002_primary_blanks_normalized AS primary_blanks_normalized,
  @fpw_up_20260831_002_aux_blanks_normalized AS auxiliary_blanks_normalized,
  @fpw_up_20260831_002_primary_target_nonnull AS primary_populated_values_preserved,
  @fpw_up_20260831_002_aux_target_nonnull AS auxiliary_populated_values_preserved,
  @fpw_up_20260831_002_post_error AS migration_error;

SET @fpw_up_20260831_002_post_guard_sql = IF(
  @fpw_up_20260831_002_post_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_verification_failed_20260831_002` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260831_002_post_guard FROM @fpw_up_20260831_002_post_guard_sql;
EXECUTE fpw_up_20260831_002_post_guard;
DEALLOCATE PREPARE fpw_up_20260831_002_post_guard;

SET @fpw_up_20260831_002_error = NULL;
SET @fpw_up_20260831_002_table_count = NULL;
SET @fpw_up_20260831_002_named_column_count = NULL;
SET @fpw_up_20260831_002_source_column_count = NULL;
SET @fpw_up_20260831_002_primary_nonblank = NULL;
SET @fpw_up_20260831_002_aux_nonblank = NULL;
SET @fpw_up_20260831_002_primary_blank = NULL;
SET @fpw_up_20260831_002_aux_blank = NULL;
SET @fpw_up_20260831_002_negative_count = NULL;
SET @fpw_up_20260831_002_invalid_count = NULL;
SET @fpw_up_20260831_002_overprecision_count = NULL;
SET @fpw_up_20260831_002_out_of_range_count = NULL;
SET @fpw_up_20260831_002_primary_source_total = NULL;
SET @fpw_up_20260831_002_aux_source_total = NULL;
SET @fpw_up_20260831_002_primary_blanks_normalized = NULL;
SET @fpw_up_20260831_002_aux_blanks_normalized = NULL;
SET @fpw_up_20260831_002_target_column_count = NULL;
SET @fpw_up_20260831_002_primary_target_nonnull = NULL;
SET @fpw_up_20260831_002_aux_target_nonnull = NULL;
SET @fpw_up_20260831_002_primary_target_total = NULL;
SET @fpw_up_20260831_002_aux_target_total = NULL;
SET @fpw_up_20260831_002_target_negative_count = NULL;
SET @fpw_up_20260831_002_post_error = NULL;
SET @fpw_up_20260831_002_data_sql = NULL;
SET @fpw_up_20260831_002_guard_sql = NULL;
SET @fpw_up_20260831_002_post_guard_sql = NULL;
