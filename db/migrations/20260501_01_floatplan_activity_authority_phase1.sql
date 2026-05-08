-- FPW canonical trip activity/progress authority foundation - Phase 1.
-- Additive migration only. Do not auto-run in production without review.
-- No backfill is included or approved in this phase.

CREATE TABLE IF NOT EXISTS floatplan_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  floatplan_id INT NOT NULL,
  user_id INT NOT NULL,
  route_instance_id INT NULL,
  route_leg_order INT NULL,
  event_type VARCHAR(64) NOT NULL,
  event_status VARCHAR(64) NULL,
  occurred_at_utc DATETIME NOT NULL,
  received_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  source VARCHAR(64) NOT NULL,
  actor_user_id INT NULL,
  source_checkin_id BIGINT UNSIGNED NULL,
  source_monitoring_id BIGINT UNSIGNED NULL,
  source_post_id INT NULL,
  idempotency_key VARCHAR(128) NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  payload_json LONGTEXT NULL,
  created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  voided_at_utc DATETIME NULL,
  correction_of_event_id BIGINT UNSIGNED NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_floatplan_events_idempotency (idempotency_key),
  KEY idx_floatplan_events_plan_time (floatplan_id, occurred_at_utc, id),
  KEY idx_floatplan_events_user_plan (user_id, floatplan_id),
  KEY idx_floatplan_events_route_leg (route_instance_id, route_leg_order, occurred_at_utc),
  KEY idx_floatplan_events_type_time (event_type, occurred_at_utc),
  KEY idx_floatplan_events_monitoring (source_monitoring_id),
  KEY idx_floatplan_events_post (source_post_id),
  KEY idx_floatplan_events_correction (correction_of_event_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Materialized activity intervals. These rows are projections from the event
-- ledger, not a separate page-local source of truth.
-- Local boating-day overlap is calculated by the projection helper; segments
-- remain true UTC intervals and are not split by a stored local_date column.
CREATE TABLE IF NOT EXISTS floatplan_activity_segments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  floatplan_id INT NOT NULL,
  user_id INT NOT NULL,
  route_instance_id INT NULL,
  route_leg_order INT NULL,
  local_timezone VARCHAR(64) NOT NULL,
  segment_type VARCHAR(40) NOT NULL,
  started_at_utc DATETIME NOT NULL,
  ended_at_utc DATETIME NULL,
  expected_resume_at_utc DATETIME NULL,
  actual_resume_at_utc DATETIME NULL,
  source_start_event_id BIGINT UNSIGNED NULL,
  source_end_event_id BIGINT UNSIGNED NULL,
  created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_activity_segments_plan_start (floatplan_id, started_at_utc),
  KEY idx_activity_segments_plan_open (floatplan_id, ended_at_utc),
  KEY idx_activity_segments_route_leg (route_instance_id, route_leg_order, started_at_utc),
  KEY idx_activity_segments_type_start (segment_type, started_at_utc),
  KEY idx_activity_segments_start_event (source_start_event_id),
  KEY idx_activity_segments_end_event (source_end_event_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
