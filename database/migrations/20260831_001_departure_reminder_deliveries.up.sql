USE `FPW`;

SET @fpw_up_20260831_001_error = NULL;

SELECT IF(COUNT(*) = 0, NULL, 'Refusing migration: departure_reminder_deliveries already exists.')
INTO @fpw_up_20260831_001_error
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'departure_reminder_deliveries';

SET @fpw_up_20260831_001_guard_sql = IF(
  @fpw_up_20260831_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_refused_20260831_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260831_001_guard FROM @fpw_up_20260831_001_guard_sql;
EXECUTE fpw_up_20260831_001_guard;
DEALLOCATE PREPARE fpw_up_20260831_001_guard;

CREATE TABLE `departure_reminder_deliveries` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `float_plan_id` INT NOT NULL,
  `reminder_type` VARCHAR(32) NOT NULL,
  `scheduled_departure_at_utc` DATETIME(6) NOT NULL,
  `occurrence_key` VARCHAR(64) NOT NULL,
  `status` VARCHAR(16) NOT NULL,
  `claimed_at_utc` DATETIME(6) NOT NULL,
  `sent_at_utc` DATETIME(6) NULL,
  `failed_at_utc` DATETIME(6) NULL,
  `attempt_count` INT NOT NULL DEFAULT 1,
  `last_error_summary` VARCHAR(255) NULL,
  `created_at_utc` DATETIME(6) NOT NULL,
  `updated_at_utc` DATETIME(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_departure_reminder_deliveries_occurrence` (`occurrence_key`),
  KEY `ix_departure_reminder_deliveries_plan_departure` (`float_plan_id`, `scheduled_departure_at_utc`, `reminder_type`),
  KEY `ix_departure_reminder_deliveries_status` (`status`, `updated_at_utc`),
  CONSTRAINT `fk_departure_reminder_deliveries_float_plan`
    FOREIGN KEY (`float_plan_id`) REFERENCES `floatplans` (`floatPlanId`)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  CONSTRAINT `chk_departure_reminder_deliveries_type`
    CHECK (`reminder_type` IN ('PRE_DEPARTURE', 'NOT_STARTED')),
  CONSTRAINT `chk_departure_reminder_deliveries_status`
    CHECK (`status` IN ('CLAIMED', 'SENT', 'FAILED')),
  CONSTRAINT `chk_departure_reminder_deliveries_attempt_count`
    CHECK (`attempt_count` BETWEEN 1 AND 3),
  CONSTRAINT `chk_departure_reminder_deliveries_terminal_time`
    CHECK (
      (`status` = 'CLAIMED' AND `sent_at_utc` IS NULL AND `failed_at_utc` IS NULL)
      OR
      (`status` = 'SENT' AND `sent_at_utc` IS NOT NULL AND `failed_at_utc` IS NULL)
      OR
      (`status` = 'FAILED' AND `sent_at_utc` IS NULL AND `failed_at_utc` IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @fpw_up_20260831_001_error = NULL;
SET @fpw_up_20260831_001_guard_sql = NULL;
