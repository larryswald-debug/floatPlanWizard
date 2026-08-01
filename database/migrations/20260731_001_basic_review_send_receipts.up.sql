USE `FPW`;

SET @fpw_up_20260731_001_error = NULL;

SELECT IF(COUNT(*) = 0, NULL, 'Refusing migration: basic_review_send_receipts already exists.')
INTO @fpw_up_20260731_001_error
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'basic_review_send_receipts';

SET @fpw_up_20260731_001_guard_sql = IF(
  @fpw_up_20260731_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_refused_20260731_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260731_001_guard FROM @fpw_up_20260731_001_guard_sql;
EXECUTE fpw_up_20260731_001_guard;
DEALLOCATE PREPARE fpw_up_20260731_001_guard;

CREATE TABLE `basic_review_send_receipts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` INT NOT NULL,
  `float_plan_id` INT NOT NULL,
  `contact_id` INT NOT NULL,
  `idempotency_key` VARCHAR(191) NOT NULL,
  `status` VARCHAR(16) NOT NULL,
  `recipient_email` VARCHAR(255) NOT NULL,
  `pdf_file_name` VARCHAR(255) NULL,
  `error_code` VARCHAR(64) NULL,
  `response_json` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL,
  `request_correlation_id` VARCHAR(64) NULL,
  `created_at_utc` DATETIME(6) NOT NULL,
  `updated_at_utc` DATETIME(6) NOT NULL,
  `completed_at_utc` DATETIME(6) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_basic_review_send_receipts_idempotency` (`idempotency_key`),
  KEY `ix_basic_review_send_receipts_plan` (`user_id`, `float_plan_id`, `created_at_utc`, `id`),
  KEY `ix_basic_review_send_receipts_contact` (`contact_id`, `created_at_utc`, `id`),
  CONSTRAINT `fk_basic_review_send_receipts_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`userId`)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  CONSTRAINT `fk_basic_review_send_receipts_float_plan`
    FOREIGN KEY (`float_plan_id`) REFERENCES `floatplans` (`floatPlanId`)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  CONSTRAINT `chk_basic_review_send_receipts_status`
    CHECK (`status` IN ('PROCESSING', 'SENT', 'FAILED')),
  CONSTRAINT `chk_basic_review_send_receipts_email`
    CHECK (CHAR_LENGTH(TRIM(`recipient_email`)) > 3),
  CONSTRAINT `chk_basic_review_send_receipts_response_json`
    CHECK (`response_json` IS NULL OR JSON_VALID(`response_json`)),
  CONSTRAINT `chk_basic_review_send_receipts_completion`
    CHECK (
      (`status` = 'PROCESSING' AND `completed_at_utc` IS NULL)
      OR
      (`status` IN ('SENT', 'FAILED') AND `completed_at_utc` IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @fpw_up_20260731_001_error = NULL;
SET @fpw_up_20260731_001_guard_sql = NULL;
