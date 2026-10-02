-- Select the target fpw database first. Run with a client that stops on the first SQL error; never use --force.
-- No deployment or database execution is implied by this file.
-- Read-only except connection-local variables/prepared refusal statement. Returns no account identities.
SET @fpw_20261001_001_error = CASE
  WHEN DATABASE() IS NULL THEN 'No database is selected.'
  WHEN CAST(LOWER(DATABASE()) AS BINARY) <> CAST('fpw' AS BINARY) THEN 'Selected database must be fpw (case-insensitive).'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='auth_rate_counters') <> 0
    THEN 'auth_rate_counters already exists; do not rerun this migration.'
  ELSE NULL END;
SELECT DATABASE() AS selected_database, VERSION() AS database_version, IF(@fpw_20261001_001_error IS NULL,'PASS','FAIL') AS preflight_status;
SELECT @fpw_20261001_001_error AS migration_error;
SET @fpw_20261001_001_guard_sql = IF(@fpw_20261001_001_error IS NULL, 'DO 0',
  'SELECT `_fpw_preflight_20261001_001_refused` FROM (SELECT 1 AS ok) AS _fpw_guard');
PREPARE fpw_20261001_001_guard FROM @fpw_20261001_001_guard_sql;
EXECUTE fpw_20261001_001_guard;
DEALLOCATE PREPARE fpw_20261001_001_guard;
