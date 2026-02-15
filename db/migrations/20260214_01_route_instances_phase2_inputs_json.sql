-- Phase 2 route instance metadata for Route Generator edit persistence.
-- Adds routegen_inputs_json to preserve pace/advanced/start-date selections.

SET @schema_name := DATABASE();

SET @route_instances_exists := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = @schema_name
    AND table_name = 'route_instances'
);

SET @sql_add_col_routegen_inputs_json := IF(
  @route_instances_exists = 0,
  'SELECT 1',
  IF(
    (SELECT COUNT(*)
     FROM information_schema.columns
     WHERE table_schema = @schema_name
       AND table_name = 'route_instances'
       AND column_name = 'routegen_inputs_json') = 0,
    'ALTER TABLE route_instances ADD COLUMN routegen_inputs_json LONGTEXT NULL AFTER end_location',
    'SELECT 1'
  )
);

PREPARE stmt_add_col_routegen_inputs_json FROM @sql_add_col_routegen_inputs_json;
EXECUTE stmt_add_col_routegen_inputs_json;
DEALLOCATE PREPARE stmt_add_col_routegen_inputs_json;
