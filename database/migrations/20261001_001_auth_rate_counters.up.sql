-- Select the target fpw database first. Run with a client that stops on the first SQL error; never use --force.
-- No deployment or database execution is implied by this file.
SET @fpw_20261001_001_error = CASE
  WHEN DATABASE() IS NULL THEN 'No database is selected.'
  WHEN CAST(LOWER(DATABASE()) AS BINARY) <> CAST('fpw' AS BINARY) THEN 'Selected database must be fpw (case-insensitive).'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='auth_rate_counters') <> 0
    THEN 'auth_rate_counters already exists; do not rerun this migration.'
  ELSE NULL END;
SELECT @fpw_20261001_001_error AS migration_error;
SET @fpw_20261001_001_guard_sql = IF(@fpw_20261001_001_error IS NULL, 'DO 0',
  'SELECT `_fpw_up_20261001_001_refused` FROM (SELECT 1 AS ok) AS _fpw_guard');
PREPARE fpw_20261001_001_guard FROM @fpw_20261001_001_guard_sql;
EXECUTE fpw_20261001_001_guard;
DEALLOCATE PREPARE fpw_20261001_001_guard;

CREATE TABLE auth_rate_counters (
  action_group VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  subject_scope VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  subject_hash BINARY(32) NOT NULL,
  window_started_at_utc DATETIME(6) NOT NULL,
  expires_at_utc DATETIME(6) NOT NULL,
  admitted_count INT UNSIGNED NOT NULL DEFAULT 0,
  failure_count INT UNSIGNED NOT NULL DEFAULT 0,
  inflight_count INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (action_group, subject_scope, subject_hash),
  KEY ix_auth_rate_expiry (expires_at_utc),
  CONSTRAINT chk_auth_rate_scope CHECK (subject_scope IN ('ip','account','ip_account')),
  CONSTRAINT chk_auth_rate_window CHECK (expires_at_utc > window_started_at_utc)
) ENGINE=InnoDB DEFAULT CHARSET=ascii COLLATE=ascii_bin;
