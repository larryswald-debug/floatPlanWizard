-- FPW Premium Trip entitlement, creation-lease, and Stripe retry foundation.
-- Additive and idempotent for MySQL 8.0. Historical member_entitlements rows,
-- including three_day_pass rows, are intentionally not modified or migrated.

CREATE TABLE IF NOT EXISTS member_premium_trip_entitlements (
  premium_trip_entitlement_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  grant_source VARCHAR(40) NOT NULL,
  grant_reference VARCHAR(255) NULL,
  grant_sequence INT UNSIGNED NOT NULL DEFAULT 1,
  status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
  canonical_trip_id INT NULL,
  granted_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reserved_at_utc DATETIME NULL,
  activated_at_utc DATETIME NULL,
  consumed_at_utc DATETIME NULL,
  revoked_at_utc DATETIME NULL,
  restored_at_utc DATETIME NULL,
  stripe_checkout_session_id VARCHAR(255) NULL,
  stripe_payment_intent_id VARCHAR(255) NULL,
  stripe_charge_id VARCHAR(255) NULL,
  stripe_price_id VARCHAR(255) NULL,
  stripe_event_id VARCHAR(255) NULL,
  promo_code_id BIGINT UNSIGNED NULL,
  admin_grant_id BIGINT UNSIGNED NULL,
  revocation_reason VARCHAR(500) NULL,
  review_required TINYINT(1) NOT NULL DEFAULT 0,
  review_reason VARCHAR(500) NULL,
  created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  introductory_user_id INT GENERATED ALWAYS AS (
    CASE WHEN grant_source = 'introductory' THEN user_id ELSE NULL END
  ) STORED,
  PRIMARY KEY (premium_trip_entitlement_id),
  CONSTRAINT chk_premium_trip_grant_source CHECK (
    grant_source IN ('introductory','stripe_purchase','promo','referral','admin','customer_service')
  ),
  CONSTRAINT chk_premium_trip_status CHECK (
    status IN ('AVAILABLE','RESERVED','ACTIVE','CONSUMED','REVOKED')
  ),
  CONSTRAINT chk_premium_trip_assignment CHECK (
    (status = 'AVAILABLE' AND canonical_trip_id IS NULL)
    OR (status IN ('RESERVED','ACTIVE','CONSUMED') AND canonical_trip_id IS NOT NULL)
    OR status = 'REVOKED'
  ),
  CONSTRAINT chk_premium_trip_timestamps CHECK (
    (status = 'AVAILABLE')
    OR (status = 'RESERVED' AND reserved_at_utc IS NOT NULL)
    OR (status = 'ACTIVE' AND reserved_at_utc IS NOT NULL AND activated_at_utc IS NOT NULL)
    OR (status = 'CONSUMED' AND reserved_at_utc IS NOT NULL AND activated_at_utc IS NOT NULL AND consumed_at_utc IS NOT NULL)
    OR (status = 'REVOKED' AND revoked_at_utc IS NOT NULL)
  ),
  UNIQUE KEY uq_premium_trip_introductory_user (introductory_user_id),
  UNIQUE KEY uq_premium_trip_canonical_trip (canonical_trip_id),
  UNIQUE KEY uq_premium_trip_checkout_session (stripe_checkout_session_id),
  UNIQUE KEY uq_premium_trip_payment_intent (stripe_payment_intent_id),
  UNIQUE KEY uq_premium_trip_stripe_event (stripe_event_id),
  UNIQUE KEY uq_premium_trip_grant_reference (grant_source, grant_reference, grant_sequence),
  KEY idx_premium_trip_user_status (user_id, status),
  KEY idx_premium_trip_grant_source (grant_source, status),
  KEY idx_premium_trip_stripe_charge (stripe_charge_id),
  KEY idx_premium_trip_stripe_price (stripe_price_id),
  KEY idx_premium_trip_promo (promo_code_id, status),
  KEY idx_premium_trip_admin (admin_grant_id, status),
  CONSTRAINT fk_premium_trip_user FOREIGN KEY (user_id) REFERENCES users (userId) ON DELETE RESTRICT,
  CONSTRAINT fk_premium_trip_canonical_trip FOREIGN KEY (canonical_trip_id) REFERENCES floatplans (floatPlanId) ON DELETE RESTRICT,
  CONSTRAINT fk_premium_trip_promo FOREIGN KEY (promo_code_id) REFERENCES fpw_promo_codes (promo_code_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS premium_trip_creation_sessions (
  creation_session_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  premium_trip_entitlement_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  prepared_route_instance_id INT NULL,
  prepared_float_plan_id INT NULL,
  created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_activity_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at_utc DATETIME NOT NULL,
  completed_at_utc DATETIME NULL,
  canceled_at_utc DATETIME NULL,
  expired_at_utc DATETIME NULL,
  cancellation_reason VARCHAR(500) NULL,
  action_claim_hash CHAR(64) NULL,
  action_claim_name VARCHAR(80) NULL,
  action_claimed_at_utc DATETIME NULL,
  action_claim_expires_at_utc DATETIME NULL,
  lock_version INT UNSIGNED NOT NULL DEFAULT 1,
  updated_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  active_entitlement_id BIGINT UNSIGNED GENERATED ALWAYS AS (
    CASE WHEN status = 'ACTIVE' THEN premium_trip_entitlement_id ELSE NULL END
  ) STORED,
  PRIMARY KEY (creation_session_id),
  CONSTRAINT chk_premium_trip_session_status CHECK (
    status IN ('ACTIVE','COMPLETED','CANCELED','EXPIRED')
  ),
  UNIQUE KEY uq_premium_trip_session_token_hash (token_hash),
  UNIQUE KEY uq_premium_trip_session_active_entitlement (active_entitlement_id),
  KEY idx_premium_trip_session_user_status (user_id, status, expires_at_utc),
  KEY idx_premium_trip_session_action_claim (status, action_claim_expires_at_utc),
  KEY idx_premium_trip_session_route (prepared_route_instance_id),
  KEY idx_premium_trip_session_floatplan (prepared_float_plan_id),
  CONSTRAINT fk_premium_trip_session_user FOREIGN KEY (user_id) REFERENCES users (userId) ON DELETE RESTRICT,
  CONSTRAINT fk_premium_trip_session_entitlement FOREIGN KEY (premium_trip_entitlement_id) REFERENCES member_premium_trip_entitlements (premium_trip_entitlement_id) ON DELETE RESTRICT,
  CONSTRAINT fk_premium_trip_session_route FOREIGN KEY (prepared_route_instance_id) REFERENCES route_instances (id) ON DELETE SET NULL,
  CONSTRAINT fk_premium_trip_session_floatplan FOREIGN KEY (prepared_float_plan_id) REFERENCES floatplans (floatPlanId) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS premium_trip_entitlement_events (
  premium_trip_event_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  premium_trip_entitlement_id BIGINT UNSIGNED NULL,
  creation_session_id BIGINT UNSIGNED NULL,
  actor_type VARCHAR(30) NOT NULL,
  actor_user_id INT NULL,
  user_id INT NOT NULL,
  action VARCHAR(80) NOT NULL,
  canonical_trip_id INT NULL,
  previous_status VARCHAR(20) NULL,
  new_status VARCHAR(20) NULL,
  source VARCHAR(40) NULL,
  reason VARCHAR(500) NULL,
  stripe_event_id VARCHAR(255) NULL,
  promo_code_id BIGINT UNSIGNED NULL,
  idempotency_key VARCHAR(255) NULL,
  created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (premium_trip_event_id),
  UNIQUE KEY uq_premium_trip_event_idempotency (idempotency_key),
  KEY idx_premium_trip_event_entitlement (premium_trip_entitlement_id, created_at_utc),
  KEY idx_premium_trip_event_session (creation_session_id, created_at_utc),
  KEY idx_premium_trip_event_user (user_id, created_at_utc),
  KEY idx_premium_trip_event_action (action, created_at_utc),
  KEY idx_premium_trip_event_trip (canonical_trip_id, created_at_utc),
  CONSTRAINT fk_premium_trip_event_entitlement FOREIGN KEY (premium_trip_entitlement_id) REFERENCES member_premium_trip_entitlements (premium_trip_entitlement_id) ON DELETE RESTRICT,
  CONSTRAINT fk_premium_trip_event_session FOREIGN KEY (creation_session_id) REFERENCES premium_trip_creation_sessions (creation_session_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @schema_name := DATABASE();

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='fpw_promo_codes' AND column_name='benefit_type') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN benefit_type VARCHAR(40) NULL AFTER promo_type',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='fpw_promo_codes' AND column_name='benefit_quantity') = 0,
  'ALTER TABLE fpw_promo_codes ADD COLUMN benefit_quantity INT UNSIGNED NULL AFTER benefit_type',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=@schema_name AND table_name='fpw_promo_codes' AND index_name='idx_fpw_promo_codes_benefit') = 0,
  'ALTER TABLE fpw_promo_codes ADD INDEX idx_fpw_promo_codes_benefit (benefit_type, status)',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='fpw_promo_redemptions' AND column_name='premium_trip_grant_count') = 0,
  'ALTER TABLE fpw_promo_redemptions ADD COLUMN premium_trip_grant_count INT UNSIGNED NULL AFTER entitlement_id',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='stripe_webhook_events' AND column_name='attempt_count') = 0,
  'ALTER TABLE stripe_webhook_events ADD COLUMN attempt_count INT UNSIGNED NOT NULL DEFAULT 0 AFTER processing_status',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='stripe_webhook_events' AND column_name='processing_started_at_utc') = 0,
  'ALTER TABLE stripe_webhook_events ADD COLUMN processing_started_at_utc DATETIME NULL AFTER attempt_count',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='stripe_webhook_events' AND column_name='last_attempt_at_utc') = 0,
  'ALTER TABLE stripe_webhook_events ADD COLUMN last_attempt_at_utc DATETIME NULL AFTER processing_started_at_utc',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='stripe_webhook_events' AND column_name='review_required') = 0,
  'ALTER TABLE stripe_webhook_events ADD COLUMN review_required TINYINT(1) NOT NULL DEFAULT 0 AFTER error_message',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='stripe_webhook_events' AND column_name='review_reason') = 0,
  'ALTER TABLE stripe_webhook_events ADD COLUMN review_reason VARCHAR(500) NULL AFTER review_required',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
