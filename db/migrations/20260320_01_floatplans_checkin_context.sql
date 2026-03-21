-- Adds a canonical latest-check-in context field to floatplans.

SET @schema_name := DATABASE();

SET @sql_add_col_checkin_context := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND column_name = 'checkin_context') = 0,
  'ALTER TABLE floatplans ADD COLUMN checkin_context VARCHAR(24) NULL AFTER checkedInAt',
  'SELECT 1'
);
PREPARE stmt_add_col_checkin_context FROM @sql_add_col_checkin_context;
EXECUTE stmt_add_col_checkin_context;
DEALLOCATE PREPARE stmt_add_col_checkin_context;
