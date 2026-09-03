-- FPW vessel primary/auxiliary fuel-capacity production preflight.
-- Read-only apart from session variables and a temporary prepared statement.
-- Do not use mysql --force: a failed guard must stop the deployment.

SET @fpw_preflight_20260831_002_error = NULL;
SET @fpw_preflight_20260831_002_table_count = 0;
SET @fpw_preflight_20260831_002_named_column_count = 0;
SET @fpw_preflight_20260831_002_source_column_count = 0;
SET @fpw_preflight_20260831_002_primary_nonblank = 0;
SET @fpw_preflight_20260831_002_aux_nonblank = 0;
SET @fpw_preflight_20260831_002_primary_blank = 0;
SET @fpw_preflight_20260831_002_aux_blank = 0;
SET @fpw_preflight_20260831_002_primary_negative = 0;
SET @fpw_preflight_20260831_002_aux_negative = 0;
SET @fpw_preflight_20260831_002_primary_invalid = 0;
SET @fpw_preflight_20260831_002_aux_invalid = 0;
SET @fpw_preflight_20260831_002_primary_overprecision = 0;
SET @fpw_preflight_20260831_002_aux_overprecision = 0;
SET @fpw_preflight_20260831_002_primary_out_of_range = 0;
SET @fpw_preflight_20260831_002_aux_out_of_range = 0;

SELECT COUNT(*)
INTO @fpw_preflight_20260831_002_table_count
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'vessels'
  AND TABLE_TYPE = 'BASE TABLE'
  AND ENGINE = 'InnoDB';

SELECT COUNT(*)
INTO @fpw_preflight_20260831_002_named_column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'vessels'
  AND COLUMN_NAME IN ('primaryFuelCapacity', 'auxFuelCapacity');

SELECT COUNT(*)
INTO @fpw_preflight_20260831_002_source_column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'vessels'
  AND COLUMN_NAME IN ('primaryFuelCapacity', 'auxFuelCapacity')
  AND DATA_TYPE = 'varchar'
  AND CHARACTER_MAXIMUM_LENGTH = 45
  AND (
    (CHARACTER_SET_NAME = 'utf8mb3' AND COLLATION_NAME = 'utf8mb3_general_ci')
    OR (CHARACTER_SET_NAME = 'utf8' AND COLLATION_NAME = 'utf8_general_ci')
  )
  AND IS_NULLABLE = 'YES'
  AND (
    (LOCATE('MariaDB', VERSION()) > 0 AND CAST(COLUMN_DEFAULT AS CHAR) = 'NULL')
    OR (LOCATE('MariaDB', VERSION()) = 0 AND COLUMN_DEFAULT IS NULL)
  )
  AND EXTRA = '';

SET @fpw_preflight_20260831_002_data_sql = IF(
  @fpw_preflight_20260831_002_table_count = 1
  AND @fpw_preflight_20260831_002_named_column_count = 2
  AND @fpw_preflight_20260831_002_source_column_count = 2,
  'SELECT
     COALESCE(SUM(CASE WHEN `primaryFuelCapacity` IS NOT NULL AND TRIM(CAST(`primaryFuelCapacity` AS CHAR)) <> '''' AND UPPER(TRIM(CAST(`primaryFuelCapacity` AS CHAR))) <> ''NULL'' THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN `auxFuelCapacity` IS NOT NULL AND TRIM(CAST(`auxFuelCapacity` AS CHAR)) <> '''' AND UPPER(TRIM(CAST(`auxFuelCapacity` AS CHAR))) <> ''NULL'' THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN `primaryFuelCapacity` IS NOT NULL AND (TRIM(CAST(`primaryFuelCapacity` AS CHAR)) = '''' OR UPPER(TRIM(CAST(`primaryFuelCapacity` AS CHAR))) = ''NULL'') THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN `auxFuelCapacity` IS NOT NULL AND (TRIM(CAST(`auxFuelCapacity` AS CHAR)) = '''' OR UPPER(TRIM(CAST(`auxFuelCapacity` AS CHAR))) = ''NULL'') THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN TRIM(CAST(`primaryFuelCapacity` AS CHAR)) REGEXP ''^-[0-9]+([.][0-9]+)?$'' THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN TRIM(CAST(`auxFuelCapacity` AS CHAR)) REGEXP ''^-[0-9]+([.][0-9]+)?$'' THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN `primaryFuelCapacity` IS NOT NULL AND TRIM(CAST(`primaryFuelCapacity` AS CHAR)) <> '''' AND UPPER(TRIM(CAST(`primaryFuelCapacity` AS CHAR))) <> ''NULL'' AND TRIM(CAST(`primaryFuelCapacity` AS CHAR)) NOT REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' AND TRIM(CAST(`primaryFuelCapacity` AS CHAR)) NOT REGEXP ''^-[0-9]+([.][0-9]+)?$'' THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN `auxFuelCapacity` IS NOT NULL AND TRIM(CAST(`auxFuelCapacity` AS CHAR)) <> '''' AND UPPER(TRIM(CAST(`auxFuelCapacity` AS CHAR))) <> ''NULL'' AND TRIM(CAST(`auxFuelCapacity` AS CHAR)) NOT REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' AND TRIM(CAST(`auxFuelCapacity` AS CHAR)) NOT REGEXP ''^-[0-9]+([.][0-9]+)?$'' THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN TRIM(CAST(`primaryFuelCapacity` AS CHAR)) REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' AND LOCATE(''.'', TRIM(CAST(`primaryFuelCapacity` AS CHAR))) > 0 AND LENGTH(SUBSTRING_INDEX(TRIM(CAST(`primaryFuelCapacity` AS CHAR)), ''.'', -1)) > 2 THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN TRIM(CAST(`auxFuelCapacity` AS CHAR)) REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' AND LOCATE(''.'', TRIM(CAST(`auxFuelCapacity` AS CHAR))) > 0 AND LENGTH(SUBSTRING_INDEX(TRIM(CAST(`auxFuelCapacity` AS CHAR)), ''.'', -1)) > 2 THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN TRIM(CAST(`primaryFuelCapacity` AS CHAR)) REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' AND CAST(TRIM(CAST(`primaryFuelCapacity` AS CHAR)) AS DECIMAL(65,10)) > 99999999.99 THEN 1 ELSE 0 END), 0),
     COALESCE(SUM(CASE WHEN TRIM(CAST(`auxFuelCapacity` AS CHAR)) REGEXP ''^[+]?[0-9]+([.][0-9]+)?$'' AND CAST(TRIM(CAST(`auxFuelCapacity` AS CHAR)) AS DECIMAL(65,10)) > 99999999.99 THEN 1 ELSE 0 END), 0)
   INTO
     @fpw_preflight_20260831_002_primary_nonblank,
     @fpw_preflight_20260831_002_aux_nonblank,
     @fpw_preflight_20260831_002_primary_blank,
     @fpw_preflight_20260831_002_aux_blank,
     @fpw_preflight_20260831_002_primary_negative,
     @fpw_preflight_20260831_002_aux_negative,
     @fpw_preflight_20260831_002_primary_invalid,
     @fpw_preflight_20260831_002_aux_invalid,
     @fpw_preflight_20260831_002_primary_overprecision,
     @fpw_preflight_20260831_002_aux_overprecision,
     @fpw_preflight_20260831_002_primary_out_of_range,
     @fpw_preflight_20260831_002_aux_out_of_range
   FROM `FPW`.`vessels`',
  'DO 0'
);
PREPARE fpw_preflight_20260831_002_data
FROM @fpw_preflight_20260831_002_data_sql;
EXECUTE fpw_preflight_20260831_002_data;
DEALLOCATE PREPARE fpw_preflight_20260831_002_data;

SET @fpw_preflight_20260831_002_error = CASE
  WHEN DATABASE() IS NULL THEN
    'Refusing preflight: no database is selected.'
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    CONCAT('Refusing preflight: selected database is ', DATABASE(), ', not FPW.')
  WHEN @fpw_preflight_20260831_002_table_count <> 1 THEN
    'Refusing preflight: FPW.vessels must exist as an InnoDB base table.'
  WHEN @fpw_preflight_20260831_002_named_column_count <> 2 THEN
    'Refusing preflight: both vessel fuel-capacity source columns must exist.'
  WHEN @fpw_preflight_20260831_002_source_column_count <> 2 THEN
    'Refusing preflight: primaryFuelCapacity and auxFuelCapacity must be nullable three-byte UTF-8 VARCHAR(45) columns with explicit SQL NULL defaults as reported by MySQL or MariaDB.'
  WHEN @fpw_preflight_20260831_002_primary_negative + @fpw_preflight_20260831_002_aux_negative > 0 THEN
    'Refusing preflight: negative primary or auxiliary fuel-capacity values require owner review.'
  WHEN @fpw_preflight_20260831_002_primary_invalid + @fpw_preflight_20260831_002_aux_invalid > 0 THEN
    'Refusing preflight: mixed or nonnumeric primary or auxiliary fuel-capacity values require owner review.'
  WHEN @fpw_preflight_20260831_002_primary_overprecision + @fpw_preflight_20260831_002_aux_overprecision > 0 THEN
    'Refusing preflight: values with more than two decimal places would be rounded by DECIMAL(10,2).'
  WHEN @fpw_preflight_20260831_002_primary_out_of_range + @fpw_preflight_20260831_002_aux_out_of_range > 0 THEN
    'Refusing preflight: one or more fuel-capacity values exceed DECIMAL(10,2).'
  ELSE NULL
END;

SELECT
  DATABASE() AS selected_database,
  VERSION() AS database_version,
  @fpw_preflight_20260831_002_table_count AS compatible_vessels_tables,
  @fpw_preflight_20260831_002_named_column_count AS named_source_columns,
  @fpw_preflight_20260831_002_source_column_count AS compatible_source_columns,
  @fpw_preflight_20260831_002_primary_nonblank AS primary_nonblank_values,
  @fpw_preflight_20260831_002_aux_nonblank AS auxiliary_nonblank_values,
  @fpw_preflight_20260831_002_primary_blank AS primary_empty_or_text_null_values_to_normalize,
  @fpw_preflight_20260831_002_aux_blank AS auxiliary_empty_or_text_null_values_to_normalize,
  @fpw_preflight_20260831_002_primary_negative AS primary_negative_values,
  @fpw_preflight_20260831_002_aux_negative AS auxiliary_negative_values,
  @fpw_preflight_20260831_002_primary_invalid AS primary_mixed_or_invalid_values,
  @fpw_preflight_20260831_002_aux_invalid AS auxiliary_mixed_or_invalid_values,
  @fpw_preflight_20260831_002_primary_overprecision AS primary_overprecision_values,
  @fpw_preflight_20260831_002_aux_overprecision AS auxiliary_overprecision_values,
  @fpw_preflight_20260831_002_primary_out_of_range AS primary_out_of_range_values,
  @fpw_preflight_20260831_002_aux_out_of_range AS auxiliary_out_of_range_values,
  IF(@fpw_preflight_20260831_002_error IS NULL, 'PASS', 'FAIL') AS preflight_status,
  @fpw_preflight_20260831_002_error AS preflight_error;

SET @fpw_preflight_20260831_002_guard_sql = IF(
  @fpw_preflight_20260831_002_error IS NULL,
  'DO 0',
  'SELECT `_fpw_production_preflight_refused_20260831_002` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_preflight_20260831_002_guard
FROM @fpw_preflight_20260831_002_guard_sql;
EXECUTE fpw_preflight_20260831_002_guard;
DEALLOCATE PREPARE fpw_preflight_20260831_002_guard;

SET @fpw_preflight_20260831_002_error = NULL;
SET @fpw_preflight_20260831_002_table_count = NULL;
SET @fpw_preflight_20260831_002_named_column_count = NULL;
SET @fpw_preflight_20260831_002_source_column_count = NULL;
SET @fpw_preflight_20260831_002_primary_nonblank = NULL;
SET @fpw_preflight_20260831_002_aux_nonblank = NULL;
SET @fpw_preflight_20260831_002_primary_blank = NULL;
SET @fpw_preflight_20260831_002_aux_blank = NULL;
SET @fpw_preflight_20260831_002_primary_negative = NULL;
SET @fpw_preflight_20260831_002_aux_negative = NULL;
SET @fpw_preflight_20260831_002_primary_invalid = NULL;
SET @fpw_preflight_20260831_002_aux_invalid = NULL;
SET @fpw_preflight_20260831_002_primary_overprecision = NULL;
SET @fpw_preflight_20260831_002_aux_overprecision = NULL;
SET @fpw_preflight_20260831_002_primary_out_of_range = NULL;
SET @fpw_preflight_20260831_002_aux_out_of_range = NULL;
SET @fpw_preflight_20260831_002_data_sql = NULL;
SET @fpw_preflight_20260831_002_guard_sql = NULL;







