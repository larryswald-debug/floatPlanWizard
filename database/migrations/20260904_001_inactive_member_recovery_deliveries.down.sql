USE `FPW`;

SET @fpw_down_20260904_001_error = CASE
  WHEN COALESCE(@fpw_confirm_rollback_inactive_recovery, '') <> 'ROLLBACK_INACTIVE_MEMBER_RECOVERY_DELIVERIES' THEN
    'Refusing rollback: set @fpw_confirm_rollback_inactive_recovery to the required confirmation token.'
  WHEN (
    SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'inactive_member_recovery_deliveries'
      AND TABLE_TYPE = 'BASE TABLE'
  ) <> 1 THEN
    'Refusing rollback: inactive_member_recovery_deliveries does not exist.'
  ELSE NULL
END;

SET @fpw_down_20260904_001_guard_sql = IF(
  @fpw_down_20260904_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_rollback_refused_20260904_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_down_20260904_001_guard FROM @fpw_down_20260904_001_guard_sql;
EXECUTE fpw_down_20260904_001_guard;
DEALLOCATE PREPARE fpw_down_20260904_001_guard;

DROP TABLE `inactive_member_recovery_deliveries`;

SET @fpw_confirm_rollback_inactive_recovery = NULL;
SET @fpw_down_20260904_001_error = NULL;
SET @fpw_down_20260904_001_guard_sql = NULL;
