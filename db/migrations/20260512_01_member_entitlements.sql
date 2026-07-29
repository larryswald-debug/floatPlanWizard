-- FPW membership entitlement foundation - Phase 1.
-- Additive migration only. Do not auto-run in production without review.
-- No route, float-plan, monitoring, Stripe, or UI gating is included in this phase.

CREATE TABLE IF NOT EXISTS member_entitlements (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  entitlement_type VARCHAR(40) NOT NULL DEFAULT 'premium',
  source VARCHAR(40) NOT NULL,
  status VARCHAR(40) NOT NULL DEFAULT 'active',
  starts_at_utc DATETIME NOT NULL,
  expires_at_utc DATETIME NULL,
  stripe_customer_id VARCHAR(255) NULL,
  stripe_subscription_id VARCHAR(255) NULL,
  stripe_checkout_session_id VARCHAR(255) NULL,
  stripe_payment_intent_id VARCHAR(255) NULL,
  created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_member_entitlements_user_access (user_id, entitlement_type, status, starts_at_utc, expires_at_utc),
  KEY idx_member_entitlements_pass_expiry (source, status, expires_at_utc),
  KEY idx_member_entitlements_stripe_customer (stripe_customer_id),
  KEY idx_member_entitlements_stripe_subscription (stripe_subscription_id),
  KEY idx_member_entitlements_stripe_checkout (stripe_checkout_session_id),
  KEY idx_member_entitlements_stripe_payment (stripe_payment_intent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
