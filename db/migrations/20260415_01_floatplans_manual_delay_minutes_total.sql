-- Adds a canonical cumulative manual trip delay accumulator for explicit captain delay adjustments.

SET @schema_name := DATABASE();

SET @sql_add_col_manual_delay_minutes_total := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND column_name = 'manual_delay_minutes_total') = 0,
  'ALTER TABLE floatplans ADD COLUMN manual_delay_minutes_total INT NOT NULL DEFAULT 0 AFTER overnight_pause_minutes_total',
  'SELECT 1'
);
PREPARE stmt_add_col_manual_delay_minutes_total FROM @sql_add_col_manual_delay_minutes_total;
EXECUTE stmt_add_col_manual_delay_minutes_total;
DEALLOCATE PREPARE stmt_add_col_manual_delay_minutes_total;
