-- Companion tracking Phase 1: forward migration, repeating prerequisite guards in this connection.
-- Select the intended FPW database explicitly. Never use the SQL client's --force option.
-- No production migration is authorized by this file. DDL requires a verified backup.
-- Supported: MySQL 8.0.16+; MariaDB 10.5.26+ within the 10.5 series, or exactly 10.6.24.
SET @fpw_tracking_mariadb = LOWER(VERSION()) LIKE '%mariadb%';
SET @fpw_tracking_version = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @fpw_tracking_major = CAST(SUBSTRING_INDEX(@fpw_tracking_version, '.', 1) AS UNSIGNED);
SET @fpw_tracking_minor = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@fpw_tracking_version, '.', 2), '.', -1) AS UNSIGNED);
SET @fpw_tracking_patch = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@fpw_tracking_version, '.', 3), '.', -1) AS UNSIGNED);
SET @fpw_tracking_check_enforcement = 1;
SET @fpw_tracking_check_sql = IF(@fpw_tracking_mariadb,
  'SELECT @@SESSION.check_constraint_checks INTO @fpw_tracking_check_enforcement',
  'SET @fpw_tracking_check_enforcement = 1');
PREPARE fpw_tracking_check FROM @fpw_tracking_check_sql;
EXECUTE fpw_tracking_check;
DEALLOCATE PREPARE fpw_tracking_check;

SET @fpw_tracking_error = CASE
  WHEN DATABASE() IS NULL THEN 'No database is selected.'
  WHEN CAST(LOWER(DATABASE()) AS BINARY) <> CAST('fpw' AS BINARY)
    THEN 'Selected database must be FPW (case-insensitive).'
  WHEN @fpw_tracking_mariadb = 1 AND NOT (
    @fpw_tracking_major = 10 AND (
      (@fpw_tracking_minor = 5 AND @fpw_tracking_patch >= 26) OR
      (@fpw_tracking_minor = 6 AND @fpw_tracking_patch = 24)
    ))
    THEN 'Supported MariaDB versions are 10.5.26 or newer within the 10.5 series, or exactly 10.6.24.'
  WHEN @fpw_tracking_mariadb = 0 AND (@fpw_tracking_major < 8 OR (@fpw_tracking_major = 8 AND @fpw_tracking_minor = 0 AND @fpw_tracking_patch < 16))
    THEN 'MySQL 8.0.16 or newer is required.'
  WHEN @fpw_tracking_check_enforcement <> 1 THEN 'CHECK constraint enforcement must be enabled.'
  WHEN @@SESSION.foreign_key_checks <> 1 THEN 'Foreign key enforcement must be enabled.'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE()
        AND TABLE_NAME IN ('companion_tracking_sessions','companion_location_samples')) <> 0
    THEN 'A tracking table already exists; do not rerun or repair a partial migration automatically.'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE()
        AND TABLE_NAME IN ('users','companion_devices','floatplans','route_instances')
        AND TABLE_TYPE='BASE TABLE' AND ENGINE='InnoDB') <> 4
    THEN 'All four parent tables must exist and use InnoDB.'
  WHEN (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE()
        AND IS_NULLABLE='NO' AND COLUMN_KEY='PRI' AND (
          (TABLE_NAME='users' AND COLUMN_NAME='userId' AND DATA_TYPE='int' AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%') OR
          (TABLE_NAME='floatplans' AND COLUMN_NAME='floatPlanId' AND DATA_TYPE='int' AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%') OR
          (TABLE_NAME='route_instances' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%') OR
          (TABLE_NAME='companion_devices' AND COLUMN_NAME='id' AND DATA_TYPE='bigint' AND LOWER(COLUMN_TYPE) LIKE '%unsigned%')
        )) <> 4
    THEN 'Parent primary keys have incompatible types, signedness, or nullability.'
  WHEN (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE()
        AND INDEX_NAME='PRIMARY' AND TABLE_NAME IN ('users','companion_devices','floatplans','route_instances')) <> 4
    THEN 'Each referenced parent must have a single-column primary key.'
  ELSE NULL END;
SELECT DATABASE() AS selected_database, VERSION() AS database_version,
  IF(@fpw_tracking_error IS NULL, 'PASS', 'FAIL') AS preflight_status;
SELECT @fpw_tracking_error AS migration_error;
SET @fpw_tracking_guard_sql = IF(@fpw_tracking_error IS NULL, 'DO 0',
  'SELECT `_fpw_tracking_preflight_refused` FROM (SELECT 1 AS ok) AS _fpw_guard');
PREPARE fpw_tracking_guard FROM @fpw_tracking_guard_sql;
EXECUTE fpw_tracking_guard;
DEALLOCATE PREPARE fpw_tracking_guard;

-- UTC millisecond timestamps are supplied by the application/UTC_TIMESTAMP(3), not session-local NOW().
-- NULL generated keys make ACTIVE uniqueness atomic while allowing history and DRAINING backlog.
CREATE TABLE companion_tracking_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  client_session_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id INT NOT NULL,
  companion_device_id BIGINT UNSIGNED NOT NULL,
  floatplan_id INT NOT NULL,
  route_instance_id INT NOT NULL,
  status ENUM('ACTIVE','DRAINING','CLOSED') NOT NULL,
  started_at_utc DATETIME(3) NOT NULL,
  capture_stopped_at_utc DATETIME(3) NULL,
  closed_at_utc DATETIME(3) NULL,
  stop_reason VARCHAR(64) NULL,
  authorization_valid_until_utc DATETIME(3) NOT NULL,
  drain_until_utc DATETIME(3) NULL,
  last_sample_captured_at_utc DATETIME(3) NULL,
  last_received_at_utc DATETIME(3) NULL,
  consent_version VARCHAR(64) NOT NULL,
  created_utc DATETIME(3) NOT NULL,
  updated_utc DATETIME(3) NOT NULL,
  active_device_id BIGINT UNSIGNED GENERATED ALWAYS AS (IF(status='ACTIVE', companion_device_id, NULL)) VIRTUAL,
  active_floatplan_id INT GENERATED ALWAYS AS (IF(status='ACTIVE', floatplan_id, NULL)) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_cts_device_client (companion_device_id, client_session_id),
  UNIQUE KEY uq_cts_active_device (active_device_id),
  UNIQUE KEY uq_cts_active_trip (active_floatplan_id),
  KEY ix_cts_user_trip (user_id, floatplan_id, started_at_utc, id),
  KEY ix_cts_floatplan (floatplan_id),
  KEY ix_cts_route (route_instance_id),
  KEY ix_cts_expiration (status, authorization_valid_until_utc, id),
  KEY ix_cts_drain (status, drain_until_utc, id),
  KEY ix_cts_retention (status, closed_at_utc, id),
  KEY ix_cts_reconcile (status, updated_utc, id),
  CONSTRAINT fk_cts_user FOREIGN KEY (user_id) REFERENCES users(userId) ON DELETE CASCADE,
  CONSTRAINT fk_cts_device FOREIGN KEY (companion_device_id) REFERENCES companion_devices(id) ON DELETE CASCADE,
  CONSTRAINT fk_cts_floatplan FOREIGN KEY (floatplan_id) REFERENCES floatplans(floatPlanId) ON DELETE CASCADE,
  CONSTRAINT fk_cts_route FOREIGN KEY (route_instance_id) REFERENCES route_instances(id) ON DELETE CASCADE,
  CONSTRAINT chk_cts_status CHECK (status IN ('ACTIVE','DRAINING','CLOSED')),
  CONSTRAINT chk_cts_authorization CHECK (authorization_valid_until_utc > started_at_utc),
  CONSTRAINT chk_cts_lifecycle CHECK (
    (status='ACTIVE' AND capture_stopped_at_utc IS NULL AND closed_at_utc IS NULL AND drain_until_utc IS NULL) OR
    (status='DRAINING' AND capture_stopped_at_utc IS NOT NULL AND closed_at_utc IS NULL AND drain_until_utc IS NOT NULL) OR
    (status='CLOSED' AND closed_at_utc IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE companion_location_samples (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tracking_session_id BIGINT UNSIGNED NOT NULL,
  client_sample_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  latitude DECIMAL(10,7) NOT NULL,
  longitude DECIMAL(10,7) NOT NULL,
  accuracy_meters DECIMAL(8,3) NOT NULL,
  speed_knots DECIMAL(8,3) NULL,
  course_degrees DECIMAL(7,3) NULL,
  captured_at_utc DATETIME(3) NOT NULL,
  received_at_utc DATETIME(3) NOT NULL,
  payload_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_cls_session_sample (tracking_session_id, client_sample_id),
  KEY ix_cls_latest (tracking_session_id, captured_at_utc, id),
  KEY ix_cls_retention (captured_at_utc, id),
  CONSTRAINT fk_cls_session FOREIGN KEY (tracking_session_id) REFERENCES companion_tracking_sessions(id) ON DELETE CASCADE,
  CONSTRAINT chk_cls_latitude CHECK (latitude BETWEEN -90 AND 90),
  CONSTRAINT chk_cls_longitude CHECK (longitude BETWEEN -180 AND 180),
  CONSTRAINT chk_cls_accuracy CHECK (accuracy_meters > 0 AND accuracy_meters <= 500),
  CONSTRAINT chk_cls_speed CHECK (speed_knots IS NULL OR (speed_knots >= 0 AND speed_knots <= 200)),
  CONSTRAINT chk_cls_course CHECK (course_degrees IS NULL OR (course_degrees >= 0 AND course_degrees < 360))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SELECT 'PASS' AS forward_status;
