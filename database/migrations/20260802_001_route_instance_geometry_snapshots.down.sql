USE `FPW`;

-- Guarded rollback. The table may be dropped only while it is still empty;
-- operational geometry snapshots are immutable application records.
SET @fpw_down_20260802_001_error = NULL;
SET @fpw_down_20260802_001_table_count = 0;
SET @fpw_down_20260802_001_row_count = 0;

SELECT COUNT(*)
INTO @fpw_down_20260802_001_table_count
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'route_instance_geometry_snapshots';

SET @fpw_down_20260802_001_count_sql = IF(
  @fpw_down_20260802_001_table_count = 1,
  'SELECT COUNT(*) INTO @fpw_down_20260802_001_row_count FROM `route_instance_geometry_snapshots`',
  'SET @fpw_down_20260802_001_row_count = 0'
);
PREPARE fpw_down_20260802_001_count FROM @fpw_down_20260802_001_count_sql;
EXECUTE fpw_down_20260802_001_count;
DEALLOCATE PREPARE fpw_down_20260802_001_count;

SET @fpw_down_20260802_001_error = CASE
  WHEN DATABASE() IS NULL THEN
    'Refusing rollback: no database is selected.'
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    CONCAT('Refusing rollback: selected database is ', DATABASE(), ', not FPW.')
  WHEN @fpw_down_20260802_001_table_count <> 1 THEN
    'Refusing rollback: route_instance_geometry_snapshots does not exist.'
  WHEN @fpw_down_20260802_001_row_count > 0 THEN
    'Refusing rollback: route_instance_geometry_snapshots contains application data.'
  ELSE NULL
END;

SELECT
  DATABASE() AS selected_database,
  @fpw_down_20260802_001_table_count AS target_tables_found,
  @fpw_down_20260802_001_row_count AS snapshot_rows_found,
  IF(@fpw_down_20260802_001_error IS NULL, 'PASS', 'FAIL') AS rollback_guard_status,
  @fpw_down_20260802_001_error AS rollback_refusal;

SET @fpw_down_20260802_001_guard_sql = IF(
  @fpw_down_20260802_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_rollback_refused_20260802_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_down_20260802_001_guard FROM @fpw_down_20260802_001_guard_sql;
EXECUTE fpw_down_20260802_001_guard;
DEALLOCATE PREPARE fpw_down_20260802_001_guard;

DROP TABLE `route_instance_geometry_snapshots`;

SET @fpw_down_20260802_001_error = NULL;
SET @fpw_down_20260802_001_table_count = NULL;
SET @fpw_down_20260802_001_row_count = NULL;
SET @fpw_down_20260802_001_count_sql = NULL;
SET @fpw_down_20260802_001_guard_sql = NULL;
