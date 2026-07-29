-- Create Great Loop locks reference table for the admin XLSX import tool.

CREATE TABLE IF NOT EXISTS great_loop_locks (
  id BIGINT NOT NULL AUTO_INCREMENT,
  lock_name VARCHAR(255) NOT NULL,
  latitude DECIMAL(10,6) NOT NULL,
  longitude DECIMAL(10,6) NOT NULL,
  note TEXT NULL,
  city VARCHAR(128) NULL,
  state VARCHAR(16) NULL,
  zip VARCHAR(32) NULL,
  phone VARCHAR(64) NULL,
  vhf VARCHAR(64) NULL,
  source_filename VARCHAR(255) NOT NULL,
  source_sheet VARCHAR(128) NOT NULL DEFAULT 'Locks',
  import_batch_id CHAR(36) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_gll_lock_name_coords (lock_name, latitude, longitude),
  KEY idx_gll_state_city (state, city),
  KEY idx_gll_lat_lng (latitude, longitude),
  KEY idx_gll_import_batch (import_batch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
