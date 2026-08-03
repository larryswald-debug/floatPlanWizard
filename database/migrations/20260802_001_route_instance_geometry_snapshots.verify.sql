USE `FPW`;

-- Verify the exact schema and all snapshot rows that exist at verification time.
-- The forward migration itself reports zero rows immediately after table creation;
-- this verifier allows legitimate snapshots written after application deployment.
SET @fpw_verify_20260802_001_database_ok = 0;
SET @fpw_verify_20260802_001_table_shape = 0;
SET @fpw_verify_20260802_001_column_count = 0;
SET @fpw_verify_20260802_001_column_shape = 0;
SET @fpw_verify_20260802_001_index_count = 0;
SET @fpw_verify_20260802_001_primary_index_shape = 0;
SET @fpw_verify_20260802_001_constraint_count = 0;
SET @fpw_verify_20260802_001_named_constraints = 0;
SET @fpw_verify_20260802_001_foreign_key_shape = 0;
SET @fpw_verify_20260802_001_check_semantics = 0;
SET @fpw_verify_20260802_001_snapshot_rows = 0;
SET @fpw_verify_20260802_001_invalid_rows = 0;

SET @fpw_verify_20260802_001_database_ok =
  CAST(DATABASE() AS BINARY) = CAST('FPW' AS BINARY);

SELECT COUNT(*)
INTO @fpw_verify_20260802_001_table_shape
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instance_geometry_snapshots'
  AND TABLE_TYPE = 'BASE TABLE'
  AND ENGINE = 'InnoDB'
  AND TABLE_COLLATION = 'utf8mb4_unicode_ci';

SELECT COUNT(*)
INTO @fpw_verify_20260802_001_column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instance_geometry_snapshots';

SELECT COUNT(*)
INTO @fpw_verify_20260802_001_column_shape
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instance_geometry_snapshots'
  AND (
    (
      ORDINAL_POSITION = 1
      AND COLUMN_NAME = 'route_instance_id'
      AND DATA_TYPE = 'int'
      AND LOWER(COLUMN_TYPE) = 'int'
      AND IS_NULLABLE = 'NO'
      AND COLUMN_KEY = 'PRI'
      AND COLUMN_DEFAULT IS NULL
    )
    OR
    (
      ORDINAL_POSITION = 2
      AND COLUMN_NAME = 'snapshot_version'
      AND DATA_TYPE = 'smallint'
      AND LOWER(COLUMN_TYPE) = 'smallint unsigned'
      AND IS_NULLABLE = 'NO'
      AND CAST(COLUMN_DEFAULT AS CHAR) = '1'
    )
    OR
    (
      ORDINAL_POSITION = 3
      AND COLUMN_NAME = 'snapshot_json'
      AND DATA_TYPE = 'longtext'
      AND IS_NULLABLE = 'NO'
      AND CHARACTER_SET_NAME = 'utf8mb4'
      AND COLLATION_NAME = 'utf8mb4_bin'
      AND COLUMN_DEFAULT IS NULL
    )
    OR
    (
      ORDINAL_POSITION = 4
      AND COLUMN_NAME = 'created_at_utc'
      AND DATA_TYPE = 'datetime'
      AND LOWER(COLUMN_TYPE) = 'datetime(6)'
      AND DATETIME_PRECISION = 6
      AND IS_NULLABLE = 'NO'
      AND COLUMN_DEFAULT IS NULL
    )
  );

SELECT COUNT(*)
INTO @fpw_verify_20260802_001_index_count
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instance_geometry_snapshots';

SELECT COUNT(*)
INTO @fpw_verify_20260802_001_primary_index_shape
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instance_geometry_snapshots'
  AND INDEX_NAME = 'PRIMARY'
  AND NON_UNIQUE = 0
  AND SEQ_IN_INDEX = 1
  AND COLUMN_NAME = 'route_instance_id';

SELECT COUNT(*)
INTO @fpw_verify_20260802_001_constraint_count
FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instance_geometry_snapshots';

SELECT COUNT(*)
INTO @fpw_verify_20260802_001_named_constraints
FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instance_geometry_snapshots'
  AND (
    (CONSTRAINT_NAME = 'PRIMARY' AND CONSTRAINT_TYPE = 'PRIMARY KEY')
    OR
    (
      CONSTRAINT_NAME = 'fk_route_instance_geometry_snapshots_instance'
      AND CONSTRAINT_TYPE = 'FOREIGN KEY'
    )
    OR
    (
      CONSTRAINT_NAME IN (
        'chk_route_instance_geometry_snapshots_version',
        'chk_route_instance_geometry_snapshots_json'
      )
      AND CONSTRAINT_TYPE = 'CHECK'
    )
  );

SELECT COUNT(*)
INTO @fpw_verify_20260802_001_foreign_key_shape
FROM information_schema.KEY_COLUMN_USAGE kcu
JOIN information_schema.REFERENTIAL_CONSTRAINTS rc
  ON rc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA
 AND rc.TABLE_NAME = kcu.TABLE_NAME
 AND rc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
WHERE kcu.CONSTRAINT_SCHEMA = 'FPW'
  AND kcu.TABLE_NAME = 'route_instance_geometry_snapshots'
  AND kcu.CONSTRAINT_NAME = 'fk_route_instance_geometry_snapshots_instance'
  AND kcu.COLUMN_NAME = 'route_instance_id'
  AND kcu.ORDINAL_POSITION = 1
  AND kcu.REFERENCED_TABLE_NAME = 'route_instances'
  AND kcu.REFERENCED_COLUMN_NAME = 'id'
  AND rc.UPDATE_RULE = 'RESTRICT'
  AND rc.DELETE_RULE = 'CASCADE';

SELECT COUNT(*)
INTO @fpw_verify_20260802_001_check_semantics
FROM information_schema.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'FPW'
  AND (
    (
      CONSTRAINT_NAME = 'chk_route_instance_geometry_snapshots_version'
      AND LOWER(CHECK_CLAUSE) LIKE '%snapshot_version%'
      AND REPLACE(LOWER(CHECK_CLAUSE), ' ', '') LIKE '%>=1%'
    )
    OR
    (
      CONSTRAINT_NAME = 'chk_route_instance_geometry_snapshots_json'
      AND LOWER(CHECK_CLAUSE) LIKE '%json_valid%'
      AND LOWER(CHECK_CLAUSE) LIKE '%snapshot_json%'
    )
  );

SELECT COUNT(*)
INTO @fpw_verify_20260802_001_snapshot_rows
FROM route_instance_geometry_snapshots;

SELECT COUNT(*)
INTO @fpw_verify_20260802_001_invalid_rows
FROM route_instance_geometry_snapshots snapshots
LEFT JOIN route_instances instances
  ON instances.id = snapshots.route_instance_id
WHERE snapshots.snapshot_version < 1
   OR JSON_VALID(snapshots.snapshot_json) <> 1
   OR instances.id IS NULL;

SELECT
  DATABASE() AS selected_database,
  VERSION() AS database_version,
  @fpw_verify_20260802_001_table_shape AS exact_table_shape,
  @fpw_verify_20260802_001_column_count AS total_columns,
  @fpw_verify_20260802_001_column_shape AS exact_columns,
  @fpw_verify_20260802_001_index_count AS total_index_parts,
  @fpw_verify_20260802_001_primary_index_shape AS exact_primary_index_parts,
  @fpw_verify_20260802_001_constraint_count AS total_constraints,
  @fpw_verify_20260802_001_named_constraints AS exact_named_constraints,
  @fpw_verify_20260802_001_foreign_key_shape AS exact_foreign_keys,
  @fpw_verify_20260802_001_check_semantics AS exact_check_constraints,
  @fpw_verify_20260802_001_snapshot_rows AS current_snapshot_rows,
  @fpw_verify_20260802_001_invalid_rows AS invalid_snapshot_rows,
  CASE
    WHEN @fpw_verify_20260802_001_database_ok = 1
      AND @fpw_verify_20260802_001_table_shape = 1
      AND @fpw_verify_20260802_001_column_count = 4
      AND @fpw_verify_20260802_001_column_shape = 4
      AND @fpw_verify_20260802_001_index_count = 1
      AND @fpw_verify_20260802_001_primary_index_shape = 1
      AND @fpw_verify_20260802_001_constraint_count = 4
      AND @fpw_verify_20260802_001_named_constraints = 4
      AND @fpw_verify_20260802_001_foreign_key_shape = 1
      AND @fpw_verify_20260802_001_check_semantics = 2
      AND @fpw_verify_20260802_001_invalid_rows = 0
    THEN 'PASS'
    ELSE 'FAIL'
  END AS verification_status;

SET @fpw_verify_20260802_001_database_ok = NULL;
SET @fpw_verify_20260802_001_table_shape = NULL;
SET @fpw_verify_20260802_001_column_count = NULL;
SET @fpw_verify_20260802_001_column_shape = NULL;
SET @fpw_verify_20260802_001_index_count = NULL;
SET @fpw_verify_20260802_001_primary_index_shape = NULL;
SET @fpw_verify_20260802_001_constraint_count = NULL;
SET @fpw_verify_20260802_001_named_constraints = NULL;
SET @fpw_verify_20260802_001_foreign_key_shape = NULL;
SET @fpw_verify_20260802_001_check_semantics = NULL;
SET @fpw_verify_20260802_001_snapshot_rows = NULL;
SET @fpw_verify_20260802_001_invalid_rows = NULL;
