-- FPW authoritative product-event foundation - Phase 1.
-- Additive migration only. Do not auto-run in production without review.
-- No historical backfill or existing-member event creation is included.

CREATE TABLE IF NOT EXISTS product_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  event_uuid CHAR(36) NOT NULL,
  user_id INT NOT NULL,
  event_name VARCHAR(64) NOT NULL,
  entity_type VARCHAR(40) NOT NULL,
  entity_id BIGINT UNSIGNED NOT NULL,
  event_source VARCHAR(64) NOT NULL,
  occurred_at_utc DATETIME NOT NULL,
  request_correlation_id VARCHAR(64) NULL,
  metadata_json JSON NULL,
  created_at_utc DATETIME NOT NULL,
  idempotency_key VARCHAR(191) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_product_events_event_uuid (event_uuid),
  UNIQUE KEY uq_product_events_idempotency (idempotency_key),
  KEY idx_product_events_user_time (user_id, occurred_at_utc, id),
  KEY idx_product_events_name_time (event_name, occurred_at_utc, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
