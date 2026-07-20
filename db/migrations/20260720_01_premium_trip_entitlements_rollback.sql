-- Roll back only the additive Premium Trip Phase 2 objects.
-- Historical member_entitlements rows are never modified.

SET @schema_name := DATABASE();

DROP TABLE IF EXISTS premium_trip_entitlement_events;
DROP TABLE IF EXISTS premium_trip_creation_sessions;
DROP TABLE IF EXISTS member_premium_trip_entitlements;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=@schema_name AND table_name='fpw_promo_codes' AND index_name='idx_fpw_promo_codes_benefit') > 0,
  'ALTER TABLE fpw_promo_codes DROP INDEX idx_fpw_promo_codes_benefit',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='fpw_promo_redemptions' AND column_name='premium_trip_grant_count') > 0,
  'ALTER TABLE fpw_promo_redemptions DROP COLUMN premium_trip_grant_count',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='fpw_promo_codes' AND column_name='benefit_quantity') > 0,
  'ALTER TABLE fpw_promo_codes DROP COLUMN benefit_quantity',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='fpw_promo_codes' AND column_name='benefit_type') > 0,
  'ALTER TABLE fpw_promo_codes DROP COLUMN benefit_type',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='stripe_webhook_events' AND column_name='review_reason') > 0,
  'ALTER TABLE stripe_webhook_events DROP COLUMN review_reason',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='stripe_webhook_events' AND column_name='review_required') > 0,
  'ALTER TABLE stripe_webhook_events DROP COLUMN review_required',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='stripe_webhook_events' AND column_name='last_attempt_at_utc') > 0,
  'ALTER TABLE stripe_webhook_events DROP COLUMN last_attempt_at_utc',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='stripe_webhook_events' AND column_name='processing_started_at_utc') > 0,
  'ALTER TABLE stripe_webhook_events DROP COLUMN processing_started_at_utc',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=@schema_name AND table_name='stripe_webhook_events' AND column_name='attempt_count') > 0,
  'ALTER TABLE stripe_webhook_events DROP COLUMN attempt_count',
  'SELECT 1'
); PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
