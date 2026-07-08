-- Great Loop Ports Library support tables.
-- Phase scope: database support only. No public pages, map UI, waypoint behavior, or API routes are created here.
-- Safe to run when the tables are missing. If a table already exists with a different shape,
-- this migration does not alter or drop it; use the verification queries in db/seeds/ports/validate_ports_support_tables.sql.

CREATE TABLE IF NOT EXISTS port_profiles (
  port_id int NOT NULL,
  slug varchar(220) DEFAULT NULL,
  state_code varchar(10) DEFAULT NULL,
  country varchar(80) DEFAULT NULL,
  waterway varchar(160) DEFAULT NULL,
  loop_segment varchar(160) DEFAULT NULL,
  mile_marker varchar(80) DEFAULT NULL,
  port_type varchar(80) DEFAULT NULL,
  short_description text,
  approach_notes text,
  services_summary text,
  data_quality_status varchar(40) DEFAULT 'needs_review',
  source_notes text,
  source_url varchar(500) DEFAULT NULL,
  last_reviewed_at datetime DEFAULT NULL,
  created_at datetime DEFAULT CURRENT_TIMESTAMP,
  updated_at datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (port_id),
  KEY idx_port_profiles_slug (slug),
  KEY idx_port_profiles_state_code (state_code),
  KEY idx_port_profiles_country (country),
  KEY idx_port_profiles_loop_segment (loop_segment),
  KEY idx_port_profiles_data_quality_status (data_quality_status),
  CONSTRAINT fk_port_profiles_port
    FOREIGN KEY (port_id) REFERENCES ports(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Service booleans are intentionally nullable:
-- NULL = unknown, 0 = verified no, 1 = verified yes.
CREATE TABLE IF NOT EXISTS port_services (
  port_id int NOT NULL,
  fuel_available tinyint(1) DEFAULT NULL,
  diesel_available tinyint(1) DEFAULT NULL,
  gas_available tinyint(1) DEFAULT NULL,
  pumpout_available tinyint(1) DEFAULT NULL,
  transient_dockage_available tinyint(1) DEFAULT NULL,
  anchorage_available tinyint(1) DEFAULT NULL,
  mooring_available tinyint(1) DEFAULT NULL,
  provisioning_available tinyint(1) DEFAULT NULL,
  restaurants_nearby tinyint(1) DEFAULT NULL,
  marine_supply_nearby tinyint(1) DEFAULT NULL,
  laundry_nearby tinyint(1) DEFAULT NULL,
  transportation_nearby tinyint(1) DEFAULT NULL,
  updated_at datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (port_id),
  CONSTRAINT fk_port_services_port
    FOREIGN KEY (port_id) REFERENCES ports(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Flexible tags for filtering, review labels, and later UI badges.
CREATE TABLE IF NOT EXISTS port_tags (
  id int NOT NULL AUTO_INCREMENT,
  port_id int NOT NULL,
  tag varchar(80) NOT NULL,
  created_at datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_port_tag (port_id, tag),
  KEY idx_port_tags_port_id (port_id),
  KEY idx_port_tags_tag (tag),
  CONSTRAINT fk_port_tags_port
    FOREIGN KEY (port_id) REFERENCES ports(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Nearby asset links are intentionally generic. They can later connect ports to locks,
-- bridges, tide stations, weather stations, marinas, anchorages, or other reference assets.
CREATE TABLE IF NOT EXISTS port_nearby_assets (
  id int NOT NULL AUTO_INCREMENT,
  port_id int NOT NULL,
  asset_type varchar(40) NOT NULL,
  asset_id int DEFAULT NULL,
  asset_name varchar(180) DEFAULT NULL,
  distance_nm decimal(8,2) DEFAULT NULL,
  bearing_deg decimal(6,2) DEFAULT NULL,
  source varchar(120) DEFAULT NULL,
  created_at datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_port_nearby_assets_port_id (port_id),
  KEY idx_port_nearby_assets_asset_type (asset_type),
  KEY idx_port_nearby_assets_asset_id (asset_id),
  CONSTRAINT fk_port_nearby_assets_port
    FOREIGN KEY (port_id) REFERENCES ports(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Existing-table limitation:
-- CREATE TABLE IF NOT EXISTS does not retrofit indexes or foreign keys onto pre-existing tables.
-- Run db/seeds/ports/validate_ports_support_tables.sql after migration. If an existing support
-- table predates this migration and is missing an index/key, add it manually after reviewing data.

