-- FPW Phase 2B: distinguish Basic operational-only float plans from reusable route-backed plans.
-- Additive migration only. No route_instance or loop_routes schema changes.

SET @schema_name := DATABASE();

SET @sql_add_route_origin := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND column_name = 'route_origin') = 0,
  'ALTER TABLE floatplans ADD COLUMN route_origin VARCHAR(40) NOT NULL DEFAULT ''premium_saved_route'' AFTER route_day_number',
  'SELECT 1'
);
PREPARE stmt_add_route_origin FROM @sql_add_route_origin;
EXECUTE stmt_add_route_origin;
DEALLOCATE PREPARE stmt_add_route_origin;

SET @sql_add_is_reusable := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND column_name = 'is_reusable') = 0,
  'ALTER TABLE floatplans ADD COLUMN is_reusable TINYINT(1) NOT NULL DEFAULT 1 AFTER route_origin',
  'SELECT 1'
);
PREPARE stmt_add_is_reusable FROM @sql_add_is_reusable;
EXECUTE stmt_add_is_reusable;
DEALLOCATE PREPARE stmt_add_is_reusable;

SET @sql_add_is_visible := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND column_name = 'is_visible_in_route_library') = 0,
  'ALTER TABLE floatplans ADD COLUMN is_visible_in_route_library TINYINT(1) NOT NULL DEFAULT 1 AFTER is_reusable',
  'SELECT 1'
);
PREPARE stmt_add_is_visible FROM @sql_add_is_visible;
EXECUTE stmt_add_is_visible;
DEALLOCATE PREPARE stmt_add_is_visible;

SET @sql_add_scope_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND index_name = 'idx_floatplans_route_scope') = 0,
  'ALTER TABLE floatplans ADD INDEX idx_floatplans_route_scope (userId, route_origin, is_reusable, is_visible_in_route_library)',
  'SELECT 1'
);
PREPARE stmt_add_scope_idx FROM @sql_add_scope_idx;
EXECUTE stmt_add_scope_idx;
DEALLOCATE PREPARE stmt_add_scope_idx;
