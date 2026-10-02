-- Select the target fpw database first. Run with a client that stops on the first SQL error; never use --force.
-- No deployment or database execution is implied by this file.
-- Coordinate rollback with application rollback: authentication fails closed without this table.
SET @fpw_20261001_001_down_error = CASE
  WHEN DATABASE() IS NULL THEN 'No database is selected.'
  WHEN CAST(LOWER(DATABASE()) AS BINARY) <> CAST('fpw' AS BINARY) THEN 'Selected database must be fpw (case-insensitive).'
  WHEN COALESCE(@fpw_confirm_auth_rate_rollback,'') <> 'ROLLBACK_AUTH_RATE_COUNTERS'
    THEN 'Set @fpw_confirm_auth_rate_rollback to ROLLBACK_AUTH_RATE_COUNTERS explicitly.'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='auth_rate_counters' AND ENGINE='InnoDB') <> 1
    THEN 'auth_rate_counters is absent or incompatible.'
  ELSE NULL END;
SELECT @fpw_20261001_001_down_error AS migration_error;
SET @fpw_20261001_001_down_guard_sql = IF(@fpw_20261001_001_down_error IS NULL, 'DO 0',
  'SELECT `_fpw_down_20261001_001_refused` FROM (SELECT 1 AS ok) AS _fpw_guard');
PREPARE fpw_20261001_001_down_guard FROM @fpw_20261001_001_down_guard_sql;
EXECUTE fpw_20261001_001_down_guard;
DEALLOCATE PREPARE fpw_20261001_001_down_guard;
DROP TABLE auth_rate_counters;
SET @fpw_confirm_auth_rate_rollback=NULL;
