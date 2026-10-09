-- Companion tracking Phase 1: read-only prerequisite checks (session variables only).
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
