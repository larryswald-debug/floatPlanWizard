-- Route Generator normalization phase 1 (additive schema).
-- Goal: reduce duplicated leg data and support effective-value reads.

SET @schema_name := DATABASE();

-- loop_segments.source_segment_id (transitional link to segment_library.id)
SET @loop_segments_exists := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = @schema_name
    AND table_name = 'loop_segments'
);

SET @sql_add_loop_segments_source_segment := IF(
  @loop_segments_exists = 0,
  'SELECT 1',
  IF(
    (SELECT COUNT(*)
     FROM information_schema.columns
     WHERE table_schema = @schema_name
       AND table_name = 'loop_segments'
       AND column_name = 'source_segment_id') = 0,
    'ALTER TABLE loop_segments ADD COLUMN source_segment_id INT NULL AFTER section_id',
    'SELECT 1'
  )
);
PREPARE stmt_add_loop_segments_source_segment FROM @sql_add_loop_segments_source_segment;
EXECUTE stmt_add_loop_segments_source_segment;
DEALLOCATE PREPARE stmt_add_loop_segments_source_segment;

SET @sql_add_idx_loop_segments_source_segment := IF(
  @loop_segments_exists = 0,
  'SELECT 1',
  IF(
    (SELECT COUNT(*)
     FROM information_schema.statistics
     WHERE table_schema = @schema_name
       AND table_name = 'loop_segments'
       AND index_name = 'idx_rg_norm_loop_segments_source_segment') = 0,
    'ALTER TABLE loop_segments ADD KEY idx_rg_norm_loop_segments_source_segment (source_segment_id)',
    'SELECT 1'
  )
);
PREPARE stmt_add_idx_loop_segments_source_segment FROM @sql_add_idx_loop_segments_source_segment;
EXECUTE stmt_add_idx_loop_segments_source_segment;
DEALLOCATE PREPARE stmt_add_idx_loop_segments_source_segment;

SET @sql_add_idx_loop_sections_route_order := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'loop_sections'
     AND index_name = 'idx_rg_norm_loop_sections_route_order') = 0,
  'ALTER TABLE loop_sections ADD KEY idx_rg_norm_loop_sections_route_order (route_id, order_index)',
  'SELECT 1'
);
PREPARE stmt_add_idx_loop_sections_route_order FROM @sql_add_idx_loop_sections_route_order;
EXECUTE stmt_add_idx_loop_sections_route_order;
DEALLOCATE PREPARE stmt_add_idx_loop_sections_route_order;

SET @sql_add_idx_loop_segments_section_order := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'loop_segments'
     AND index_name = 'idx_rg_norm_loop_segments_section_order') = 0,
  'ALTER TABLE loop_segments ADD KEY idx_rg_norm_loop_segments_section_order (section_id, order_index)',
  'SELECT 1'
);
PREPARE stmt_add_idx_loop_segments_section_order FROM @sql_add_idx_loop_segments_section_order;
EXECUTE stmt_add_idx_loop_segments_section_order;
DEALLOCATE PREPARE stmt_add_idx_loop_segments_section_order;

SET @sql_add_idx_route_instances_user_generated_code := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'route_instances'
     AND index_name = 'idx_rg_norm_route_instances_user_generated_code') = 0,
  'ALTER TABLE route_instances ADD KEY idx_rg_norm_route_instances_user_generated_code (user_id, generated_route_code)',
  'SELECT 1'
);
PREPARE stmt_add_idx_route_instances_user_generated_code FROM @sql_add_idx_route_instances_user_generated_code;
EXECUTE stmt_add_idx_route_instances_user_generated_code;
DEALLOCATE PREPARE stmt_add_idx_route_instances_user_generated_code;

SET @sql_add_idx_user_route_progress_user_segment := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'user_route_progress'
     AND index_name = 'idx_rg_norm_user_route_progress_user_segment') = 0,
  'ALTER TABLE user_route_progress ADD KEY idx_rg_norm_user_route_progress_user_segment (user_id, segment_id)',
  'SELECT 1'
);
PREPARE stmt_add_idx_user_route_progress_user_segment FROM @sql_add_idx_user_route_progress_user_segment;
EXECUTE stmt_add_idx_user_route_progress_user_segment;
DEALLOCATE PREPARE stmt_add_idx_user_route_progress_user_segment;

SET @route_leg_user_overrides_exists := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = @schema_name
    AND table_name = 'route_leg_user_overrides'
);
SET @sql_add_idx_rluo_user_route_leg := IF(
  @route_leg_user_overrides_exists = 0,
  'SELECT 1',
  IF(
    (SELECT COUNT(*)
     FROM information_schema.statistics
     WHERE table_schema = @schema_name
       AND table_name = 'route_leg_user_overrides'
       AND index_name = 'idx_rg_norm_rluo_user_route_leg') = 0,
    'ALTER TABLE route_leg_user_overrides ADD KEY idx_rg_norm_rluo_user_route_leg (user_id, route_id, route_leg_id)',
    'SELECT 1'
  )
);
PREPARE stmt_add_idx_rluo_user_route_leg FROM @sql_add_idx_rluo_user_route_leg;
EXECUTE stmt_add_idx_rluo_user_route_leg;
DEALLOCATE PREPARE stmt_add_idx_rluo_user_route_leg;

CREATE TABLE IF NOT EXISTS route_instance_sections (
  id INT NOT NULL AUTO_INCREMENT,
  route_instance_id INT NOT NULL,
  section_order INT NOT NULL,
  name VARCHAR(120) NOT NULL,
  phase_num INT NULL,
  source_section_id INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_ris_route_section_order (route_instance_id, section_order),
  KEY idx_ris_route_instance (route_instance_id),
  KEY idx_ris_source_section (source_section_id),
  CONSTRAINT fk_ris_route_instance
    FOREIGN KEY (route_instance_id) REFERENCES route_instances(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS route_instance_legs (
  id INT NOT NULL AUTO_INCREMENT,
  route_instance_id INT NOT NULL,
  route_instance_section_id INT NULL,
  leg_order INT NOT NULL,
  segment_id INT NULL,
  source_loop_segment_id INT NULL,
  is_reversed TINYINT(1) NOT NULL DEFAULT 0,
  is_optional TINYINT(1) NOT NULL DEFAULT 0,
  detour_code VARCHAR(64) NULL,
  start_name VARCHAR(255) NULL,
  end_name VARCHAR(255) NULL,
  start_lat DECIMAL(10,7) NULL,
  start_lng DECIMAL(10,7) NULL,
  end_lat DECIMAL(10,7) NULL,
  end_lng DECIMAL(10,7) NULL,
  base_dist_nm DECIMAL(10,2) NULL,
  lock_count INT NULL,
  notes VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_ril_route_leg_order (route_instance_id, leg_order),
  KEY idx_ril_route_instance (route_instance_id),
  KEY idx_ril_segment (segment_id),
  KEY idx_ril_source_loop_segment (source_loop_segment_id),
  CONSTRAINT fk_ril_route_instance
    FOREIGN KEY (route_instance_id) REFERENCES route_instances(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_ril_route_instance_section
    FOREIGN KEY (route_instance_section_id) REFERENCES route_instance_sections(id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_segment_overrides (
  id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  segment_id INT NOT NULL,
  geometry_json LONGTEXT NULL,
  computed_nm DECIMAL(10,2) NULL,
  override_fields_json LONGTEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_uso_user_segment (user_id, segment_id),
  KEY idx_uso_segment (segment_id),
  KEY idx_uso_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS route_instance_leg_progress (
  id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  route_instance_id INT NOT NULL,
  leg_order INT NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'NOT_STARTED',
  completed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_rilp_user_leg (user_id, route_instance_id, leg_order),
  KEY idx_rilp_route_instance (route_instance_id),
  KEY idx_rilp_user_route (user_id, route_instance_id),
  CONSTRAINT fk_rilp_route_instance
    FOREIGN KEY (route_instance_id) REFERENCES route_instances(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
