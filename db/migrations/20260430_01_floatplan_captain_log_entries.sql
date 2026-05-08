-- FPW private captain log entries
-- Additive migration only. Do not auto-run in production without review.

CREATE TABLE IF NOT EXISTS floatplan_captain_log_entries (
  id INT NOT NULL AUTO_INCREMENT,
  floatplan_id INT NOT NULL,
  user_id INT NOT NULL,
  route_instance_id INT NULL,
  route_leg_order INT NULL,
  note_body TEXT NOT NULL,
  note_tag VARCHAR(64) NULL,
  posted_to_stream TINYINT(1) NOT NULL DEFAULT 0,
  voyage_post_id INT NULL,
  created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_utc DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_captain_log_floatplan_created (floatplan_id, created_utc),
  KEY idx_captain_log_user_created (user_id, created_utc),
  KEY idx_captain_log_route_instance (route_instance_id),
  KEY idx_captain_log_voyage_post (voyage_post_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
