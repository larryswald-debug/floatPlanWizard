-- FPW Promo-2: promo-code foundation and Founder lifetime entitlement support.
-- Additive schema only. Do not seed production promo codes in this migration.

CREATE TABLE IF NOT EXISTS fpw_promo_codes (
  promo_code_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code_hash CHAR(64) NOT NULL,
  promo_type VARCHAR(40) NOT NULL,
  status VARCHAR(40) NOT NULL DEFAULT 'active',
  starts_at_utc DATETIME NOT NULL,
  expires_at_utc DATETIME NULL,
  max_redemptions INT UNSIGNED NULL,
  redemptions_count INT UNSIGNED NOT NULL DEFAULT 0,
  one_per_user TINYINT(1) NOT NULL DEFAULT 1,
  duration_months INT UNSIGNED NULL,
  stripe_promotion_code_id VARCHAR(255) NULL,
  entitlement_type VARCHAR(40) NOT NULL DEFAULT 'premium',
  entitlement_source VARCHAR(40) NULL,
  created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (promo_code_id),
  UNIQUE KEY uq_fpw_promo_codes_code_hash (code_hash),
  KEY idx_fpw_promo_codes_status_window (status, starts_at_utc, expires_at_utc),
  KEY idx_fpw_promo_codes_type_status (promo_type, status),
  KEY idx_fpw_promo_codes_stripe_promotion (stripe_promotion_code_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fpw_promo_redemptions (
  redemption_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  promo_code_id BIGINT UNSIGNED NULL,
  user_id INT NOT NULL,
  attempt_code_hash CHAR(64) NULL,
  result VARCHAR(40) NOT NULL,
  error_code VARCHAR(80) NULL,
  entitlement_id BIGINT UNSIGNED NULL,
  stripe_checkout_session_id VARCHAR(255) NULL,
  stripe_customer_id VARCHAR(255) NULL,
  stripe_subscription_id VARCHAR(255) NULL,
  attempted_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  redeemed_at_utc DATETIME NULL,
  created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (redemption_id),
  KEY idx_fpw_promo_redemptions_promo_user_result (promo_code_id, user_id, result),
  KEY idx_fpw_promo_redemptions_user_result_created (user_id, result, created_at_utc),
  KEY idx_fpw_promo_redemptions_promo_result (promo_code_id, result),
  KEY idx_fpw_promo_redemptions_entitlement (entitlement_id),
  KEY idx_fpw_promo_redemptions_checkout (stripe_checkout_session_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
