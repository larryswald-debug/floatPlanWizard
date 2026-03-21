-- Phase 1 data backbone for Route Generator 2.0
-- Adds route_instances and floatplans linkage columns.

CREATE TABLE IF NOT EXISTS route_instances (
  id INT NOT NULL AUTO_INCREMENT,
  user_id VARCHAR(255) NOT NULL,
  template_route_code VARCHAR(40) NOT NULL,
  generated_route_id INT NOT NULL,
  generated_route_code VARCHAR(40) NOT NULL,
  direction ENUM('CW', 'CCW') NOT NULL DEFAULT 'CCW',
  trip_type ENUM('POINT_TO_POINT', 'FULL_LOOP') NOT NULL DEFAULT 'POINT_TO_POINT',
  start_location VARCHAR(160) NOT NULL,
  end_location VARCHAR(160) DEFAULT NULL,
  status VARCHAR(40) NOT NULL DEFAULT 'PLANNED',
  started_at DATETIME DEFAULT NULL,
  completed_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_route_instances_generated_route_id (generated_route_id),
  KEY idx_route_instances_user_status (user_id, status),
  KEY idx_route_instances_template_code (template_route_code),
  KEY idx_route_instances_generated_code (generated_route_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @schema_name := DATABASE();

SET @sql_add_col_route_instance := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND column_name = 'route_instance_id') = 0,
  'ALTER TABLE floatplans ADD COLUMN route_instance_id INT NULL',
  'SELECT 1'
);
PREPARE stmt_add_col_route_instance FROM @sql_add_col_route_instance;
EXECUTE stmt_add_col_route_instance;
DEALLOCATE PREPARE stmt_add_col_route_instance;

SET @sql_add_col_route_day := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND column_name = 'route_day_number') = 0,
  'ALTER TABLE floatplans ADD COLUMN route_day_number INT NULL',
  'SELECT 1'
);
PREPARE stmt_add_col_route_day FROM @sql_add_col_route_day;
EXECUTE stmt_add_col_route_day;
DEALLOCATE PREPARE stmt_add_col_route_day;

SET @sql_add_idx_route_instance := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND index_name = 'idx_floatplans_route_instance_id') = 0,
  'ALTER TABLE floatplans ADD KEY idx_floatplans_route_instance_id (route_instance_id)',
  'SELECT 1'
);
PREPARE stmt_add_idx_route_instance FROM @sql_add_idx_route_instance;
EXECUTE stmt_add_idx_route_instance;
DEALLOCATE PREPARE stmt_add_idx_route_instance;

SET @sql_add_idx_route_day := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'floatplans'
     AND index_name = 'idx_floatplans_route_day_number') = 0,
  'ALTER TABLE floatplans ADD KEY idx_floatplans_route_day_number (route_day_number)',
  'SELECT 1'
);
PREPARE stmt_add_idx_route_day FROM @sql_add_idx_route_day;
EXECUTE stmt_add_idx_route_day;
DEALLOCATE PREPARE stmt_add_idx_route_day;
