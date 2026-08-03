-- FPW route-instance geometry snapshot production preflight.
-- Read-only apart from session variables and temporary prepared statements.
-- Do not use the SQL client's --force option: a failed guard must stop deployment.

SET @fpw_preflight_20260802_001_error = NULL;
SET @fpw_preflight_20260802_001_existing_table = 0;
SET @fpw_preflight_20260802_001_parent_table = 0;
SET @fpw_preflight_20260802_001_parent_id_column = 0;
SET @fpw_preflight_20260802_001_parent_primary_key_parts = 0;
SET @fpw_preflight_20260802_001_parent_primary_key_id = 0;

SELECT COUNT(*)
INTO @fpw_preflight_20260802_001_existing_table
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instance_geometry_snapshots';

SELECT COUNT(*)
INTO @fpw_preflight_20260802_001_parent_table
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instances'
  AND TABLE_TYPE = 'BASE TABLE'
  AND ENGINE = 'InnoDB';

SELECT COUNT(*)
INTO @fpw_preflight_20260802_001_parent_id_column
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instances'
  AND COLUMN_NAME = 'id'
  AND DATA_TYPE = 'int'
  AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%'
  AND IS_NULLABLE = 'NO';

SELECT COUNT(*)
INTO @fpw_preflight_20260802_001_parent_primary_key_parts
FROM information_schema.KEY_COLUMN_USAGE
WHERE CONSTRAINT_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instances'
  AND CONSTRAINT_NAME = 'PRIMARY';

SELECT COUNT(*)
INTO @fpw_preflight_20260802_001_parent_primary_key_id
FROM information_schema.KEY_COLUMN_USAGE
WHERE CONSTRAINT_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instances'
  AND CONSTRAINT_NAME = 'PRIMARY'
  AND COLUMN_NAME = 'id'
  AND ORDINAL_POSITION = 1;

SET @fpw_preflight_20260802_001_error = CASE
  WHEN DATABASE() IS NULL THEN
    'Refusing preflight: no database is selected.'
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    CONCAT('Refusing preflight: selected database is ', DATABASE(), ', not FPW.')
  WHEN @fpw_preflight_20260802_001_existing_table <> 0 THEN
    'Refusing preflight: route_instance_geometry_snapshots already exists.'
  WHEN @fpw_preflight_20260802_001_parent_table <> 1 THEN
    'Refusing preflight: route_instances must exist as an InnoDB base table.'
  WHEN @fpw_preflight_20260802_001_parent_id_column <> 1 THEN
    'Refusing preflight: route_instances.id must be a signed NOT NULL INT column.'
  WHEN @fpw_preflight_20260802_001_parent_primary_key_parts <> 1
    OR @fpw_preflight_20260802_001_parent_primary_key_id <> 1 THEN
    'Refusing preflight: route_instances.id must be the sole primary-key column.'
  ELSE NULL
END;

SELECT
  DATABASE() AS selected_database,
  VERSION() AS database_version,
  @fpw_preflight_20260802_001_existing_table AS existing_target_tables,
  @fpw_preflight_20260802_001_parent_table AS compatible_parent_tables,
  @fpw_preflight_20260802_001_parent_id_column AS compatible_parent_id_columns,
  @fpw_preflight_20260802_001_parent_primary_key_parts AS parent_primary_key_parts,
  @fpw_preflight_20260802_001_parent_primary_key_id AS parent_primary_key_id_parts,
  IF(@fpw_preflight_20260802_001_error IS NULL, 'PASS', 'FAIL') AS preflight_status,
  @fpw_preflight_20260802_001_error AS preflight_error;

SET @fpw_preflight_20260802_001_guard_sql = IF(
  @fpw_preflight_20260802_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_production_preflight_refused_20260802_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_preflight_20260802_001_guard
FROM @fpw_preflight_20260802_001_guard_sql;
EXECUTE fpw_preflight_20260802_001_guard;
DEALLOCATE PREPARE fpw_preflight_20260802_001_guard;

SET @fpw_preflight_20260802_001_error = NULL;
SET @fpw_preflight_20260802_001_existing_table = NULL;
SET @fpw_preflight_20260802_001_parent_table = NULL;
SET @fpw_preflight_20260802_001_parent_id_column = NULL;
SET @fpw_preflight_20260802_001_parent_primary_key_parts = NULL;
SET @fpw_preflight_20260802_001_parent_primary_key_id = NULL;
SET @fpw_preflight_20260802_001_guard_sql = NULL;
