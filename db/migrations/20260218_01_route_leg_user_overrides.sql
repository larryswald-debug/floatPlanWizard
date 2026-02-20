-- Route Builder user-specific per-leg geometry + NM overrides.

CREATE TABLE IF NOT EXISTS route_leg_user_overrides (
  id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  route_id INT NOT NULL,
  route_leg_id INT NOT NULL,
  route_leg_order INT NOT NULL,
  segment_id INT NULL,
  geometry_json LONGTEXT NOT NULL,
  computed_nm DECIMAL(10,2) NOT NULL,
  override_fields_json LONGTEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_route_leg_user_override_user_leg (user_id, route_leg_id),
  KEY idx_route_leg_user_override_route_user (route_id, user_id),
  KEY idx_route_leg_user_override_route_order (route_id, route_leg_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
