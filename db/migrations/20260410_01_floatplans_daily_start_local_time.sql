-- Adds a canonical per-float-plan local daily start time override for overnight resume logic.

SET @schema_name := DATABASE();

SET @sql_add_col_daily_start_local_time := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND column_name = 'dailyStartLocalTime') = 0,
  'ALTER TABLE floatplans ADD COLUMN dailyStartLocalTime TIME NULL AFTER departureTZ',
  'SELECT 1'
);
PREPARE stmt_add_col_daily_start_local_time FROM @sql_add_col_daily_start_local_time;
EXECUTE stmt_add_col_daily_start_local_time;
DEALLOCATE PREPARE stmt_add_col_daily_start_local_time;
