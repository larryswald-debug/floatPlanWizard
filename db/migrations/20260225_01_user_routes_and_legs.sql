-- Add user-owned custom routes and ordered canonical leg mapping.
-- Also align leg override uniqueness to (user_id, route_id, route_leg_id)
-- so a user can override the same leg id across multiple routes safely.

CREATE TABLE IF NOT EXISTS user_routes (
  id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  route_name VARCHAR(255) NOT NULL,
  start_waypoint_id INT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_routes_user_name (user_id, route_name),
  KEY idx_user_routes_start_waypoint (start_waypoint_id),
  KEY idx_user_routes_user_active (user_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_route_legs (
  id INT NOT NULL AUTO_INCREMENT,
  user_route_id INT NOT NULL,
  order_index INT NOT NULL,
  segment_id INT NULL,
  start_waypoint_id INT NULL,
  end_waypoint_id INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_route_legs_route_order (user_route_id, order_index),
  KEY idx_user_route_legs_route (user_route_id),
  KEY idx_user_route_legs_segment (segment_id),
  KEY idx_user_route_legs_start_waypoint (start_waypoint_id),
  KEY idx_user_route_legs_end_waypoint (end_waypoint_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @schema_name := DATABASE();

SET @user_routes_start_wp_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = @schema_name
    AND table_name = 'user_routes'
    AND column_name = 'start_waypoint_id'
);
SET @sql_add_user_routes_start_wp := IF(
  @user_routes_start_wp_col_exists = 0,
  'ALTER TABLE user_routes ADD COLUMN start_waypoint_id INT NULL AFTER route_name',
  'SELECT 1'
);
PREPARE stmt_add_user_routes_start_wp FROM @sql_add_user_routes_start_wp;
EXECUTE stmt_add_user_routes_start_wp;
DEALLOCATE PREPARE stmt_add_user_routes_start_wp;

SET @user_route_legs_start_wp_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = @schema_name
    AND table_name = 'user_route_legs'
    AND column_name = 'start_waypoint_id'
);
SET @sql_add_user_route_legs_start_wp := IF(
  @user_route_legs_start_wp_col_exists = 0,
  'ALTER TABLE user_route_legs ADD COLUMN start_waypoint_id INT NULL AFTER segment_id',
  'SELECT 1'
);
PREPARE stmt_add_user_route_legs_start_wp FROM @sql_add_user_route_legs_start_wp;
EXECUTE stmt_add_user_route_legs_start_wp;
DEALLOCATE PREPARE stmt_add_user_route_legs_start_wp;

SET @user_route_legs_end_wp_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = @schema_name
    AND table_name = 'user_route_legs'
    AND column_name = 'end_waypoint_id'
);
SET @sql_add_user_route_legs_end_wp := IF(
  @user_route_legs_end_wp_col_exists = 0,
  'ALTER TABLE user_route_legs ADD COLUMN end_waypoint_id INT NULL AFTER start_waypoint_id',
  'SELECT 1'
);
PREPARE stmt_add_user_route_legs_end_wp FROM @sql_add_user_route_legs_end_wp;
EXECUTE stmt_add_user_route_legs_end_wp;
DEALLOCATE PREPARE stmt_add_user_route_legs_end_wp;

SET @user_route_legs_segment_nullable := (
  SELECT UPPER(is_nullable)
  FROM information_schema.columns
  WHERE table_schema = @schema_name
    AND table_name = 'user_route_legs'
    AND column_name = 'segment_id'
  LIMIT 1
);
SET @sql_user_route_legs_segment_nullable := IF(
  @user_route_legs_segment_nullable = 'YES',
  'SELECT 1',
  'ALTER TABLE user_route_legs MODIFY COLUMN segment_id INT NULL'
);
PREPARE stmt_user_route_legs_segment_nullable FROM @sql_user_route_legs_segment_nullable;
EXECUTE stmt_user_route_legs_segment_nullable;
DEALLOCATE PREPARE stmt_user_route_legs_segment_nullable;

SET @idx_user_routes_start_waypoint_exists := (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = @schema_name
    AND table_name = 'user_routes'
    AND index_name = 'idx_user_routes_start_waypoint'
);
SET @sql_idx_user_routes_start_waypoint := IF(
  @idx_user_routes_start_waypoint_exists = 0,
  'ALTER TABLE user_routes ADD KEY idx_user_routes_start_waypoint (start_waypoint_id)',
  'SELECT 1'
);
PREPARE stmt_idx_user_routes_start_waypoint FROM @sql_idx_user_routes_start_waypoint;
EXECUTE stmt_idx_user_routes_start_waypoint;
DEALLOCATE PREPARE stmt_idx_user_routes_start_waypoint;

SET @idx_user_route_legs_start_waypoint_exists := (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = @schema_name
    AND table_name = 'user_route_legs'
    AND index_name = 'idx_user_route_legs_start_waypoint'
);
SET @sql_idx_user_route_legs_start_waypoint := IF(
  @idx_user_route_legs_start_waypoint_exists = 0,
  'ALTER TABLE user_route_legs ADD KEY idx_user_route_legs_start_waypoint (start_waypoint_id)',
  'SELECT 1'
);
PREPARE stmt_idx_user_route_legs_start_waypoint FROM @sql_idx_user_route_legs_start_waypoint;
EXECUTE stmt_idx_user_route_legs_start_waypoint;
DEALLOCATE PREPARE stmt_idx_user_route_legs_start_waypoint;

SET @idx_user_route_legs_end_waypoint_exists := (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = @schema_name
    AND table_name = 'user_route_legs'
    AND index_name = 'idx_user_route_legs_end_waypoint'
);
SET @sql_idx_user_route_legs_end_waypoint := IF(
  @idx_user_route_legs_end_waypoint_exists = 0,
  'ALTER TABLE user_route_legs ADD KEY idx_user_route_legs_end_waypoint (end_waypoint_id)',
  'SELECT 1'
);
PREPARE stmt_idx_user_route_legs_end_waypoint FROM @sql_idx_user_route_legs_end_waypoint;
EXECUTE stmt_idx_user_route_legs_end_waypoint;
DEALLOCATE PREPARE stmt_idx_user_route_legs_end_waypoint;

SET @route_leg_user_overrides_exists := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = @schema_name
    AND table_name = 'route_leg_user_overrides'
);

SET @legacy_unique_exists := (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = @schema_name
    AND table_name = 'route_leg_user_overrides'
    AND index_name = 'uq_route_leg_user_override_user_leg'
    AND non_unique = 0
);

SET @sql_drop_legacy_unique := IF(
  @route_leg_user_overrides_exists = 0,
  'SELECT 1',
  IF(
    @legacy_unique_exists > 0,
    'ALTER TABLE route_leg_user_overrides DROP INDEX uq_route_leg_user_override_user_leg',
    'SELECT 1'
  )
);
PREPARE stmt_drop_legacy_unique FROM @sql_drop_legacy_unique;
EXECUTE stmt_drop_legacy_unique;
DEALLOCATE PREPARE stmt_drop_legacy_unique;

SET @new_unique_exists := (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = @schema_name
    AND table_name = 'route_leg_user_overrides'
    AND index_name = 'uq_route_leg_user_override_user_route_leg'
    AND non_unique = 0
);

SET @sql_add_new_unique := IF(
  @route_leg_user_overrides_exists = 0,
  'SELECT 1',
  IF(
    @new_unique_exists = 0,
    'ALTER TABLE route_leg_user_overrides ADD UNIQUE KEY uq_route_leg_user_override_user_route_leg (user_id, route_id, route_leg_id)',
    'SELECT 1'
  )
);
PREPARE stmt_add_new_unique FROM @sql_add_new_unique;
EXECUTE stmt_add_new_unique;
DEALLOCATE PREPARE stmt_add_new_unique;
