USE `FPW`;

-- Apply only after the matching preflight reports PASS. This migration creates
-- the immutable snapshot store only; it deliberately performs no legacy backfill.
SET @fpw_up_20260802_001_error = NULL;
SET @fpw_up_20260802_001_existing_table = 0;
SET @fpw_up_20260802_001_parent_table = 0;
SET @fpw_up_20260802_001_parent_id_column = 0;
SET @fpw_up_20260802_001_parent_primary_key_parts = 0;
SET @fpw_up_20260802_001_parent_primary_key_id = 0;
SET @fpw_up_20260802_001_initial_rows = NULL;

SELECT COUNT(*)
INTO @fpw_up_20260802_001_existing_table
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instance_geometry_snapshots';

SELECT COUNT(*)
INTO @fpw_up_20260802_001_parent_table
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instances'
  AND TABLE_TYPE = 'BASE TABLE'
  AND ENGINE = 'InnoDB';

SELECT COUNT(*)
INTO @fpw_up_20260802_001_parent_id_column
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instances'
  AND COLUMN_NAME = 'id'
  AND DATA_TYPE = 'int'
  AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%'
  AND IS_NULLABLE = 'NO';

SELECT COUNT(*)
INTO @fpw_up_20260802_001_parent_primary_key_parts
FROM information_schema.KEY_COLUMN_USAGE
WHERE CONSTRAINT_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instances'
  AND CONSTRAINT_NAME = 'PRIMARY';

SELECT COUNT(*)
INTO @fpw_up_20260802_001_parent_primary_key_id
FROM information_schema.KEY_COLUMN_USAGE
WHERE CONSTRAINT_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instances'
  AND CONSTRAINT_NAME = 'PRIMARY'
  AND COLUMN_NAME = 'id'
  AND ORDINAL_POSITION = 1;

SET @fpw_up_20260802_001_error = CASE
  WHEN DATABASE() IS NULL THEN
    'Refusing migration: no database is selected.'
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    CONCAT('Refusing migration: selected database is ', DATABASE(), ', not FPW.')
  WHEN @fpw_up_20260802_001_existing_table <> 0 THEN
    'Refusing migration: route_instance_geometry_snapshots already exists.'
  WHEN @fpw_up_20260802_001_parent_table <> 1 THEN
    'Refusing migration: route_instances must exist as an InnoDB base table.'
  WHEN @fpw_up_20260802_001_parent_id_column <> 1 THEN
    'Refusing migration: route_instances.id must be a signed NOT NULL INT column.'
  WHEN @fpw_up_20260802_001_parent_primary_key_parts <> 1
    OR @fpw_up_20260802_001_parent_primary_key_id <> 1 THEN
    'Refusing migration: route_instances.id must be the sole primary-key column.'
  ELSE NULL
END;

SELECT
  DATABASE() AS selected_database,
  @fpw_up_20260802_001_existing_table AS existing_target_tables,
  @fpw_up_20260802_001_parent_table AS compatible_parent_tables,
  @fpw_up_20260802_001_parent_id_column AS compatible_parent_id_columns,
  @fpw_up_20260802_001_parent_primary_key_parts AS parent_primary_key_parts,
  @fpw_up_20260802_001_parent_primary_key_id AS parent_primary_key_id_parts,
  IF(@fpw_up_20260802_001_error IS NULL, 'PASS', 'FAIL') AS forward_guard_status,
  @fpw_up_20260802_001_error AS forward_guard_error;

SET @fpw_up_20260802_001_guard_sql = IF(
  @fpw_up_20260802_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_refused_20260802_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260802_001_guard FROM @fpw_up_20260802_001_guard_sql;
EXECUTE fpw_up_20260802_001_guard;
DEALLOCATE PREPARE fpw_up_20260802_001_guard;

CREATE TABLE `route_instance_geometry_snapshots` (
  `route_instance_id` INT NOT NULL,
  `snapshot_version` SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  `snapshot_json` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `created_at_utc` DATETIME(6) NOT NULL,
  PRIMARY KEY (`route_instance_id`),
  CONSTRAINT `fk_route_instance_geometry_snapshots_instance`
    FOREIGN KEY (`route_instance_id`) REFERENCES `route_instances` (`id`)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  CONSTRAINT `chk_route_instance_geometry_snapshots_version`
    CHECK (`snapshot_version` >= 1),
  CONSTRAINT `chk_route_instance_geometry_snapshots_json`
    CHECK (JSON_VALID(`snapshot_json`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- This is the migration-time proof that no legacy route instance was backfilled.
-- Later verification must allow legitimate application-created snapshot rows.
SELECT COUNT(*)
INTO @fpw_up_20260802_001_initial_rows
FROM route_instance_geometry_snapshots;

SELECT
  @fpw_up_20260802_001_initial_rows AS snapshot_rows_immediately_after_create,
  IF(@fpw_up_20260802_001_initial_rows = 0, 'PASS', 'FAIL') AS no_legacy_backfill_status;

SET @fpw_up_20260802_001_error = NULL;
SET @fpw_up_20260802_001_existing_table = NULL;
SET @fpw_up_20260802_001_parent_table = NULL;
SET @fpw_up_20260802_001_parent_id_column = NULL;
SET @fpw_up_20260802_001_parent_primary_key_parts = NULL;
SET @fpw_up_20260802_001_parent_primary_key_id = NULL;
SET @fpw_up_20260802_001_initial_rows = NULL;
SET @fpw_up_20260802_001_guard_sql = NULL;
