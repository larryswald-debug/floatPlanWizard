USE `FPW`;

SET @fpw_up_20260904_001_error = NULL;

SELECT IF(COUNT(*) = 0, NULL, 'Refusing migration: inactive_member_recovery_deliveries already exists.')
INTO @fpw_up_20260904_001_error
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'inactive_member_recovery_deliveries';

SET @fpw_up_20260904_001_guard_sql = IF(
  @fpw_up_20260904_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_refused_20260904_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260904_001_guard FROM @fpw_up_20260904_001_guard_sql;
EXECUTE fpw_up_20260904_001_guard;
DEALLOCATE PREPARE fpw_up_20260904_001_guard;

CREATE TABLE `inactive_member_recovery_deliveries` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` INT NOT NULL,
  `recovery_stage` CHAR(1) NOT NULL,
  `status` VARCHAR(16) NOT NULL,
  `claim_token` CHAR(64) NOT NULL,
  `claimed_at_utc` DATETIME(6) NOT NULL,
  `sent_at_utc` DATETIME(6) NULL,
  `failed_at_utc` DATETIME(6) NULL,
  `attempt_count` INT NOT NULL DEFAULT 1,
  `last_error_summary` VARCHAR(64) NULL,
  `created_at_utc` DATETIME(6) NOT NULL,
  `updated_at_utc` DATETIME(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_inactive_recovery_member_stage` (`user_id`, `recovery_stage`),
  KEY `ix_inactive_recovery_member_sent` (`user_id`, `sent_at_utc`),
  KEY `ix_inactive_recovery_status` (`status`, `updated_at_utc`),
  CONSTRAINT `fk_inactive_recovery_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`userId`)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  CONSTRAINT `chk_inactive_recovery_stage`
    CHECK (`recovery_stage` IN ('A', 'B', 'C', 'D')),
  CONSTRAINT `chk_inactive_recovery_status`
    CHECK (`status` IN ('CLAIMED', 'SENT', 'FAILED')),
  CONSTRAINT `chk_inactive_recovery_attempt_count`
    CHECK (`attempt_count` BETWEEN 1 AND 3),
  CONSTRAINT `chk_inactive_recovery_terminal_time`
    CHECK (
      (`status` = 'CLAIMED' AND `sent_at_utc` IS NULL AND `failed_at_utc` IS NULL)
      OR
      (`status` = 'SENT' AND `sent_at_utc` IS NOT NULL AND `failed_at_utc` IS NULL)
      OR
      (`status` = 'FAILED' AND `sent_at_utc` IS NULL AND `failed_at_utc` IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @fpw_up_20260904_001_error = NULL;
SET @fpw_up_20260904_001_guard_sql = NULL;
