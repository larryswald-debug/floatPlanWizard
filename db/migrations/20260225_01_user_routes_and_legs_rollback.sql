-- Rollback custom user route tables and restore legacy override unique index.

DROP TABLE IF EXISTS user_route_legs;
DROP TABLE IF EXISTS user_routes;

SET @schema_name := DATABASE();

SET @route_leg_user_overrides_exists := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = @schema_name
    AND table_name = 'route_leg_user_overrides'
);

SET @new_unique_exists := (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = @schema_name
    AND table_name = 'route_leg_user_overrides'
    AND index_name = 'uq_route_leg_user_override_user_route_leg'
    AND non_unique = 0
);

SET @sql_drop_new_unique := IF(
  @route_leg_user_overrides_exists = 0,
  'SELECT 1',
  IF(
    @new_unique_exists > 0,
    'ALTER TABLE route_leg_user_overrides DROP INDEX uq_route_leg_user_override_user_route_leg',
    'SELECT 1'
  )
);
PREPARE stmt_drop_new_unique FROM @sql_drop_new_unique;
EXECUTE stmt_drop_new_unique;
DEALLOCATE PREPARE stmt_drop_new_unique;

SET @legacy_unique_exists := (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = @schema_name
    AND table_name = 'route_leg_user_overrides'
    AND index_name = 'uq_route_leg_user_override_user_leg'
    AND non_unique = 0
);

SET @sql_add_legacy_unique := IF(
  @route_leg_user_overrides_exists = 0,
  'SELECT 1',
  IF(
    @legacy_unique_exists = 0,
    'ALTER TABLE route_leg_user_overrides ADD UNIQUE KEY uq_route_leg_user_override_user_leg (user_id, route_leg_id)',
    'SELECT 1'
  )
);
PREPARE stmt_add_legacy_unique FROM @sql_add_legacy_unique;
EXECUTE stmt_add_legacy_unique;
DEALLOCATE PREPARE stmt_add_legacy_unique;
