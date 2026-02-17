-- FPW Segment Geometry storage (idempotent)
-- Safe to run multiple times.

SET @db_name := DATABASE();

CREATE TABLE IF NOT EXISTS segment_geometries (
  id INT NOT NULL AUTO_INCREMENT,
  segment_id INT NOT NULL,
  version INT NOT NULL,
  polyline_json LONGTEXT NOT NULL,
  polyline_enc TEXT NULL,
  dist_nm_calc DECIMAL(8,2) NOT NULL,
  point_count INT NOT NULL,
  simplify_tolerance_m DECIMAL(8,2) NULL,
  source VARCHAR(40) NOT NULL DEFAULT 'manual_draw',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by INT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_segment_version (segment_id, version),
  KEY idx_segment_id (segment_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @sql := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE loop_segments ADD COLUMN active_geom_version INT NULL',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'loop_segments'
    AND COLUMN_NAME = 'active_geom_version'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE loop_segments ADD COLUMN dist_nm_calc DECIMAL(8,2) NULL',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'loop_segments'
    AND COLUMN_NAME = 'dist_nm_calc'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE loop_segments ADD COLUMN geom_updated_at DATETIME NULL',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'loop_segments'
    AND COLUMN_NAME = 'geom_updated_at'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE loop_segments ADD COLUMN geom_source VARCHAR(40) NULL',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'loop_segments'
    AND COLUMN_NAME = 'geom_source'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE loop_segments
SET dist_nm_calc = dist_nm
WHERE dist_nm_calc IS NULL
  AND dist_nm IS NOT NULL;
