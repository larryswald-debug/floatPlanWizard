-- FPW Companion auth foundation tables.
-- Additive migration only. Do not auto-run in production without review.

CREATE TABLE IF NOT EXISTS companion_devices (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  device_uuid VARCHAR(128) NULL,
  device_name VARCHAR(120) NULL,
  platform VARCHAR(32) NULL,
  app_version VARCHAR(40) NULL,
  token_prefix VARCHAR(24) NOT NULL,
  token_hash CHAR(64) NOT NULL,
  scopes VARCHAR(255) NOT NULL DEFAULT 'companion:current,companion:checkin',
  expires_at_utc DATETIME NOT NULL,
  last_used_at_utc DATETIME NULL,
  revoked_at_utc DATETIME NULL,
  revoked_by_user_id INT NULL,
  revoked_reason VARCHAR(255) NULL,
  created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_companion_devices_token_prefix (token_prefix),
  UNIQUE KEY uq_companion_devices_token_hash (token_hash),
  KEY idx_companion_devices_user_revoked (user_id, revoked_at_utc),
  KEY idx_companion_devices_user_last_used (user_id, last_used_at_utc),
  KEY idx_companion_devices_device_uuid (device_uuid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS companion_pairing_codes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  code_hash CHAR(64) NOT NULL,
  code_hint VARCHAR(16) NULL,
  expires_at_utc DATETIME NOT NULL,
  used_at_utc DATETIME NULL,
  used_by_device_id BIGINT UNSIGNED NULL,
  attempt_count INT NOT NULL DEFAULT 0,
  revoked_at_utc DATETIME NULL,
  created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_companion_pairing_codes_hash (code_hash),
  KEY idx_companion_pairing_codes_user_expires (user_id, expires_at_utc),
  KEY idx_companion_pairing_codes_expires (expires_at_utc),
  KEY idx_companion_pairing_codes_used_device (used_by_device_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
