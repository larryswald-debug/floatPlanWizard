-- Rollback for Phase 1 route_instances schema changes.

SET @schema_name := DATABASE();

SET @sql_drop_idx_route_instance := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND index_name = 'idx_floatplans_route_instance_id') > 0,
  'ALTER TABLE floatplans DROP INDEX idx_floatplans_route_instance_id',
  'SELECT 1'
);
PREPARE stmt_drop_idx_route_instance FROM @sql_drop_idx_route_instance;
EXECUTE stmt_drop_idx_route_instance;
DEALLOCATE PREPARE stmt_drop_idx_route_instance;

SET @sql_drop_idx_route_day := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND index_name = 'idx_floatplans_route_day_number') > 0,
  'ALTER TABLE floatplans DROP INDEX idx_floatplans_route_day_number',
  'SELECT 1'
);
PREPARE stmt_drop_idx_route_day FROM @sql_drop_idx_route_day;
EXECUTE stmt_drop_idx_route_day;
DEALLOCATE PREPARE stmt_drop_idx_route_day;

SET @sql_drop_col_route_instance := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND column_name = 'route_instance_id') > 0,
  'ALTER TABLE floatplans DROP COLUMN route_instance_id',
  'SELECT 1'
);
PREPARE stmt_drop_col_route_instance FROM @sql_drop_col_route_instance;
EXECUTE stmt_drop_col_route_instance;
DEALLOCATE PREPARE stmt_drop_col_route_instance;

SET @sql_drop_col_route_day := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND column_name = 'route_day_number') > 0,
  'ALTER TABLE floatplans DROP COLUMN route_day_number',
  'SELECT 1'
);
PREPARE stmt_drop_col_route_day FROM @sql_drop_col_route_day;
EXECUTE stmt_drop_col_route_day;
DEALLOCATE PREPARE stmt_drop_col_route_day;

DROP TABLE IF EXISTS route_instances;
