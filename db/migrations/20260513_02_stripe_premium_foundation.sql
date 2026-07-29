-- FPW Stripe-1 backend Premium subscription foundation.
-- Additive migration only. Do not store raw Stripe payload JSON or payment details.

CREATE TABLE IF NOT EXISTS stripe_webhook_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  stripe_event_id VARCHAR(255) NOT NULL,
  event_type VARCHAR(120) NOT NULL,
  processing_status VARCHAR(40) NOT NULL DEFAULT 'processing',
  user_id INT NULL,
  stripe_customer_id VARCHAR(255) NULL,
  stripe_subscription_id VARCHAR(255) NULL,
  stripe_checkout_session_id VARCHAR(255) NULL,
  stripe_invoice_id VARCHAR(255) NULL,
  stripe_payment_intent_id VARCHAR(255) NULL,
  stripe_price_id VARCHAR(255) NULL,
  processed_at_utc DATETIME NULL,
  error_message VARCHAR(500) NULL,
  created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_stripe_webhook_events_event_id (stripe_event_id),
  KEY idx_stripe_webhook_events_status_created (processing_status, created_at_utc),
  KEY idx_stripe_webhook_events_user_created (user_id, created_at_utc),
  KEY idx_stripe_webhook_events_subscription (stripe_subscription_id),
  KEY idx_stripe_webhook_events_customer (stripe_customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @schema_name := DATABASE();

SET @sql_add_stripe_price_id := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'member_entitlements'
     AND column_name = 'stripe_price_id') = 0,
  'ALTER TABLE member_entitlements ADD COLUMN stripe_price_id VARCHAR(255) NULL AFTER stripe_payment_intent_id',
  'SELECT 1'
);
PREPARE stmt_add_stripe_price_id FROM @sql_add_stripe_price_id;
EXECUTE stmt_add_stripe_price_id;
DEALLOCATE PREPARE stmt_add_stripe_price_id;

SET @sql_add_stripe_subscription_status := IF(
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = @schema_name
     AND table_name = 'member_entitlements'
     AND column_name = 'stripe_subscription_status') = 0,
  'ALTER TABLE member_entitlements ADD COLUMN stripe_subscription_status VARCHAR(40) NULL AFTER stripe_price_id',
  'SELECT 1'
);
PREPARE stmt_add_stripe_subscription_status FROM @sql_add_stripe_subscription_status;
EXECUTE stmt_add_stripe_subscription_status;
DEALLOCATE PREPARE stmt_add_stripe_subscription_status;

SET @sql_add_price_idx := IF(
  (SELECT COUNT(*)
   FROM information_schema.statistics
   WHERE table_schema = @schema_name
     AND table_name = 'member_entitlements'
     AND index_name = 'idx_member_entitlements_stripe_price') = 0,
  'ALTER TABLE member_entitlements ADD INDEX idx_member_entitlements_stripe_price (stripe_price_id)',
  'SELECT 1'
);
PREPARE stmt_add_price_idx FROM @sql_add_price_idx;
EXECUTE stmt_add_price_idx;
DEALLOCATE PREPARE stmt_add_price_idx;
