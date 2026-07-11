-- FPW admin promo-code and member-entitlement management foundation.
-- Additive and idempotent for MySQL 8.0. Existing promo, redemption,
-- entitlement, and Stripe data is preserved.

SET @schema_name := DATABASE();

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND column_name = 'code_normalized') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN code_normalized VARCHAR(120) NULL AFTER code_hash',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND column_name = 'internal_name') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN internal_name VARCHAR(160) NULL AFTER code_normalized',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND column_name = 'public_description') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN public_description VARCHAR(500) NULL AFTER internal_name',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND column_name = 'admin_grant_kind') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN admin_grant_kind VARCHAR(40) NULL AFTER entitlement_source',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND column_name = 'admin_grant_duration_days') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN admin_grant_duration_days INT UNSIGNED NULL AFTER admin_grant_kind',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND column_name = 'admin_grant_expires_at_utc') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN admin_grant_expires_at_utc DATETIME NULL AFTER admin_grant_duration_days',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND column_name = 'stripe_coupon_id') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN stripe_coupon_id VARCHAR(255) NULL AFTER stripe_promotion_code_id',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND column_name = 'admin_notes') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN admin_notes TEXT NULL AFTER admin_grant_expires_at_utc',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND column_name = 'created_by_user_id') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN created_by_user_id INT NULL AFTER admin_notes',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND column_name = 'updated_by_user_id') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN updated_by_user_id INT NULL AFTER created_by_user_id',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND column_name = 'archived_at_utc') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN archived_at_utc DATETIME NULL AFTER updated_by_user_id',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND column_name = 'archived_by_user_id') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN archived_by_user_id INT NULL AFTER archived_at_utc',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND index_name = 'uq_fpw_promo_codes_code_normalized') = 0,
  'ALTER TABLE fpw_promo_codes ADD UNIQUE INDEX uq_fpw_promo_codes_code_normalized (code_normalized)',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND index_name = 'idx_fpw_promo_codes_admin_grant') = 0,
  'ALTER TABLE fpw_promo_codes ADD INDEX idx_fpw_promo_codes_admin_grant (admin_grant_kind, status)',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = @schema_name AND table_name = 'fpw_promo_codes' AND index_name = 'idx_fpw_promo_codes_stripe_coupon') = 0,
  'ALTER TABLE fpw_promo_codes ADD INDEX idx_fpw_promo_codes_stripe_coupon (stripe_coupon_id)',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'member_entitlements' AND column_name = 'promo_code_id') = 0,
  'ALTER TABLE member_entitlements ADD COLUMN promo_code_id BIGINT UNSIGNED NULL AFTER source',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'member_entitlements' AND column_name = 'grant_kind') = 0,
  'ALTER TABLE member_entitlements ADD COLUMN grant_kind VARCHAR(40) NULL AFTER promo_code_id',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'member_entitlements' AND column_name = 'admin_notes') = 0,
  'ALTER TABLE member_entitlements ADD COLUMN admin_notes TEXT NULL AFTER stripe_subscription_status',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'member_entitlements' AND column_name = 'created_by_user_id') = 0,
  'ALTER TABLE member_entitlements ADD COLUMN created_by_user_id INT NULL AFTER admin_notes',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'member_entitlements' AND column_name = 'updated_by_user_id') = 0,
  'ALTER TABLE member_entitlements ADD COLUMN updated_by_user_id INT NULL AFTER created_by_user_id',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'member_entitlements' AND column_name = 'revoked_at_utc') = 0,
  'ALTER TABLE member_entitlements ADD COLUMN revoked_at_utc DATETIME NULL AFTER updated_by_user_id',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'member_entitlements' AND column_name = 'revoked_by_user_id') = 0,
  'ALTER TABLE member_entitlements ADD COLUMN revoked_by_user_id INT NULL AFTER revoked_at_utc',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'member_entitlements' AND column_name = 'revocation_reason') = 0,
  'ALTER TABLE member_entitlements ADD COLUMN revocation_reason VARCHAR(500) NULL AFTER revoked_by_user_id',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = @schema_name AND table_name = 'member_entitlements' AND index_name = 'idx_member_entitlements_promo') = 0,
  'ALTER TABLE member_entitlements ADD INDEX idx_member_entitlements_promo (promo_code_id)',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = @schema_name AND table_name = 'member_entitlements' AND index_name = 'idx_member_entitlements_grant_status') = 0,
  'ALTER TABLE member_entitlements ADD INDEX idx_member_entitlements_grant_status (grant_kind, status)',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS fpw_admin_audit_log (
  audit_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  admin_user_id INT NOT NULL,
  admin_email VARCHAR(255) NULL,
  action VARCHAR(80) NOT NULL,
  entity_type VARCHAR(80) NOT NULL,
  entity_id VARCHAR(80) NOT NULL,
  previous_values_json JSON NULL,
  new_values_json JSON NULL,
  reason VARCHAR(500) NULL,
  created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (audit_id),
  KEY idx_fpw_admin_audit_entity (entity_type, entity_id, created_at_utc),
  KEY idx_fpw_admin_audit_admin (admin_user_id, created_at_utc),
  KEY idx_fpw_admin_audit_action (action, created_at_utc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
