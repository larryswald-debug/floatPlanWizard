-- Rollback for Phase 2 route instance metadata column.

SET @schema_name := DATABASE();

SET @route_instances_exists := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = @schema_name
    AND table_name = 'route_instances'
);

SET @sql_drop_col_routegen_inputs_json := IF(
  @route_instances_exists = 0,
  'SELECT 1',
  IF(
    (SELECT COUNT(*)
     FROM information_schema.columns
     WHERE table_schema = @schema_name
       AND table_name = 'route_instances'
       AND column_name = 'routegen_inputs_json') > 0,
    'ALTER TABLE route_instances DROP COLUMN routegen_inputs_json',
    'SELECT 1'
  )
);

PREPARE stmt_drop_col_routegen_inputs_json FROM @sql_drop_col_routegen_inputs_json;
EXECUTE stmt_drop_col_routegen_inputs_json;
DEALLOCATE PREPARE stmt_drop_col_routegen_inputs_json;
