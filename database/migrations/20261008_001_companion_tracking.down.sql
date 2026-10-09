-- Guarded rollback: quiesce tracking requests/maintenance and restore compatible code first.
-- MySQL/MariaDB DDL is not transactional. Stop on any error; never use --force.
-- This rollback only supports EMPTY tables after disposable validation cleanup.
-- Populated rollback needs a separately reviewed data-handling plan; this file never authorizes it.
-- SET @fpw_confirm_drop_companion_tracking = 'DROP_EMPTY_COMPANION_TRACKING';
SET @fpw_tracking_down_error = CASE
  WHEN DATABASE() IS NULL OR CAST(LOWER(DATABASE()) AS BINARY) <> CAST('fpw' AS BINARY)
    THEN 'Selected database must be FPW (case-insensitive).'
  WHEN CAST(COALESCE(@fpw_confirm_drop_companion_tracking,'') AS BINARY) <> CAST('DROP_EMPTY_COMPANION_TRACKING' AS BINARY)
    THEN 'Set @fpw_confirm_drop_companion_tracking to DROP_EMPTY_COMPANION_TRACKING in this session.'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE()
        AND TABLE_NAME IN ('companion_tracking_sessions','companion_location_samples') AND ENGINE='InnoDB' AND TABLE_TYPE='BASE TABLE') <> 2
    THEN 'Both tracking tables must exist; do not use this rollback on a partial migration.'
  WHEN EXISTS (SELECT 1 FROM information_schema.KEY_COLUMN_USAGE WHERE REFERENCED_TABLE_SCHEMA=DATABASE()
        AND REFERENCED_TABLE_NAME IN ('companion_tracking_sessions','companion_location_samples')
        AND NOT (TABLE_SCHEMA=DATABASE() AND TABLE_NAME='companion_location_samples' AND CONSTRAINT_NAME='fk_cls_session'))
    THEN 'An unexpected external foreign key depends on the tracking tables.'
  ELSE NULL END;
SELECT @fpw_tracking_down_error AS migration_error;
SET @fpw_tracking_guard_sql = IF(@fpw_tracking_down_error IS NULL, 'DO 0',
  'SELECT `_fpw_tracking_down_refused` FROM (SELECT 1 AS ok) AS _fpw_guard');
PREPARE fpw_tracking_guard FROM @fpw_tracking_guard_sql;
EXECUTE fpw_tracking_guard;
DEALLOCATE PREPARE fpw_tracking_guard;

SET @fpw_tracking_down_error = CASE
  WHEN EXISTS (SELECT 1 FROM companion_location_samples LIMIT 1) THEN 'Location samples remain; rollback refuses to delete their data.'
  WHEN EXISTS (SELECT 1 FROM companion_tracking_sessions LIMIT 1) THEN 'Tracking sessions remain; rollback refuses to delete their data.'
  ELSE NULL END;
SELECT @fpw_tracking_down_error AS migration_error;
SET @fpw_tracking_guard_sql = IF(@fpw_tracking_down_error IS NULL, 'DO 0',
  'SELECT `_fpw_tracking_down_data_refused` FROM (SELECT 1 AS ok) AS _fpw_guard');
PREPARE fpw_tracking_guard FROM @fpw_tracking_guard_sql;
EXECUTE fpw_tracking_guard;
DEALLOCATE PREPARE fpw_tracking_guard;

DROP TABLE companion_location_samples;
DROP TABLE companion_tracking_sessions;
SET @fpw_confirm_drop_companion_tracking = NULL;
SELECT IF(COUNT(*)=0, 'PASS', 'FAIL') AS rollback_status FROM information_schema.TABLES
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ('companion_tracking_sessions','companion_location_samples');
