USE `FPW`;

SET @fpw_up_20260721_001_error = NULL;

DROP PROCEDURE IF EXISTS `_fpw_up_20260721_001_membership_premium_send_credits`;
DELIMITER $$
CREATE PROCEDURE `_fpw_up_20260721_001_membership_premium_send_credits`()
BEGIN
  DECLARE v_existing_table_count INT DEFAULT 0;

  IF DATABASE() <> 'FPW' THEN
    SET @fpw_up_20260721_001_error =
      'Refusing migration: selected database is not FPW.';
  ELSE
    SELECT COUNT(*) INTO v_existing_table_count
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts');

    IF v_existing_table_count > 0 THEN
      SET @fpw_up_20260721_001_error =
        'Refusing migration: a Phase 2 Premium Send table already exists.';
    END IF;
  END IF;
END$$
DELIMITER ;

CALL `_fpw_up_20260721_001_membership_premium_send_credits`();
DROP PROCEDURE `_fpw_up_20260721_001_membership_premium_send_credits`;

SELECT @fpw_up_20260721_001_error AS migration_refusal
WHERE @fpw_up_20260721_001_error IS NOT NULL;

SET @fpw_up_20260721_001_guard_sql = IF(
  @fpw_up_20260721_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_refused_20260721_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260721_001_guard FROM @fpw_up_20260721_001_guard_sql;
EXECUTE fpw_up_20260721_001_guard;
DEALLOCATE PREPARE fpw_up_20260721_001_guard;

SET @fpw_up_20260721_001_error = NULL;
SET @fpw_up_20260721_001_guard_sql = NULL;

CREATE TABLE `premium_send_credits` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` INT NOT NULL,
  `source` VARCHAR(32) NOT NULL,
  `status` VARCHAR(16) NOT NULL,
  `consumed_float_plan_id` INT NULL,
  `idempotency_key` VARCHAR(191) NOT NULL,
  `stripe_checkout_session_id` VARCHAR(255) NULL,
  `stripe_payment_intent_id` VARCHAR(255) NULL,
  `granted_at_utc` DATETIME(6) NOT NULL,
  `consumed_at_utc` DATETIME(6) NULL,
  `created_at_utc` DATETIME(6) NOT NULL,
  `updated_at_utc` DATETIME(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_premium_send_credits_idempotency` (`idempotency_key`),
  UNIQUE KEY `uq_premium_send_credits_float_plan` (`consumed_float_plan_id`),
  UNIQUE KEY `uq_premium_send_credits_checkout` (`stripe_checkout_session_id`),
  UNIQUE KEY `uq_premium_send_credits_payment_intent` (`stripe_payment_intent_id`),
  UNIQUE KEY `uq_premium_send_credits_receipt_binding` (`id`, `user_id`, `consumed_float_plan_id`),
  KEY `ix_premium_send_credits_available` (`user_id`, `status`, `granted_at_utc`, `id`),
  CONSTRAINT `fk_premium_send_credits_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`userId`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_premium_send_credits_float_plan`
    FOREIGN KEY (`consumed_float_plan_id`) REFERENCES `floatplans` (`floatPlanId`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `chk_premium_send_credits_source`
    CHECK (`source` IN ('complimentary_signup', 'stripe_one_trip', 'promotion', 'admin_grant')),
  CONSTRAINT `chk_premium_send_credits_status`
    CHECK (`status` IN ('AVAILABLE', 'CONSUMED')),
  CONSTRAINT `chk_premium_send_credits_state`
    CHECK (
      (
        `status` = 'AVAILABLE'
        AND `consumed_float_plan_id` IS NULL
        AND `consumed_at_utc` IS NULL
      )
      OR
      (
        `status` = 'CONSUMED'
        AND `consumed_float_plan_id` IS NOT NULL
        AND `consumed_at_utc` IS NOT NULL
      )
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `premium_send_receipts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` INT NOT NULL,
  `float_plan_id` INT NOT NULL,
  `credit_id` BIGINT UNSIGNED NULL,
  `access_source` VARCHAR(32) NOT NULL,
  `recipient_count` INT UNSIGNED NOT NULL,
  `original_response_json` JSON NOT NULL,
  `committed_at_utc` DATETIME(6) NOT NULL,
  `created_at_utc` DATETIME(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_premium_send_receipts_float_plan` (`float_plan_id`),
  KEY `ix_premium_send_receipts_user` (`user_id`, `committed_at_utc`, `id`),
  KEY `ix_premium_send_receipts_credit_binding` (`credit_id`, `user_id`, `float_plan_id`),
  CONSTRAINT `fk_premium_send_receipts_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`userId`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_premium_send_receipts_float_plan`
    FOREIGN KEY (`float_plan_id`) REFERENCES `floatplans` (`floatPlanId`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `fk_premium_send_receipts_credit_binding`
    FOREIGN KEY (`credit_id`, `user_id`, `float_plan_id`)
    REFERENCES `premium_send_credits` (`id`, `user_id`, `consumed_float_plan_id`)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT `chk_premium_send_receipts_access_source`
    CHECK (`access_source` IN ('general_premium', 'premium_send_credit')),
  CONSTRAINT `chk_premium_send_receipts_credit_source`
    CHECK (
      (`access_source` = 'general_premium' AND `credit_id` IS NULL)
      OR
      (`access_source` = 'premium_send_credit' AND `credit_id` IS NOT NULL)
    ),
  CONSTRAINT `chk_premium_send_receipts_recipient_count`
    CHECK (`recipient_count` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
