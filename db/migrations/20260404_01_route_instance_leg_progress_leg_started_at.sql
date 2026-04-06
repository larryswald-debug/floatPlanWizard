-- Adds a canonical per-leg start timestamp to route_instance_leg_progress.

SET @schema_name := DATABASE();

SET @sql_add_col_leg_started_at := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'route_instance_leg_progress'
     AND column_name = 'leg_started_at') = 0,
  'ALTER TABLE route_instance_leg_progress ADD COLUMN leg_started_at DATETIME NULL AFTER status',
  'SELECT 1'
);
PREPARE stmt_add_col_leg_started_at FROM @sql_add_col_leg_started_at;
EXECUTE stmt_add_col_leg_started_at;
DEALLOCATE PREPARE stmt_add_col_leg_started_at;
