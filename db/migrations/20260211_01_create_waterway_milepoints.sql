CREATE TABLE IF NOT EXISTS waterway_milepoints (
  id BIGINT NOT NULL AUTO_INCREMENT,
  waterway_code VARCHAR(64) NOT NULL,
  location_name VARCHAR(255) NOT NULL,
  alias_name VARCHAR(255) NULL,
  rm_value DECIMAL(10,2) NOT NULL,
  source VARCHAR(128) NOT NULL DEFAULT 'USACE',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_wmp_waterway_location (waterway_code, location_name),
  INDEX idx_wmp_waterway_alias (waterway_code, alias_name),
  INDEX idx_wmp_waterway_active (waterway_code, is_active)
);
