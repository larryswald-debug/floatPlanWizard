USE `FPW`;

SET @fpw_up_20260724_002_error = NULL;
SET @fpw_up_20260724_002_existing_user_max_id = 0;
SET @fpw_up_20260724_002_existing_user_count = 0;
SET @fpw_up_20260724_002_backfill_at = UTC_TIMESTAMP(6);
SET @fpw_up_20260724_002_backfilled_count = 0;

DROP PROCEDURE IF EXISTS `_fpw_up_20260724_002_welcome_onboarding`;
DELIMITER $$
CREATE PROCEDURE `_fpw_up_20260724_002_welcome_onboarding`()
BEGIN
  DECLARE v_users_table_count INT DEFAULT 0;
  DECLARE v_user_id_column_count INT DEFAULT 0;
  DECLARE v_target_column_count INT DEFAULT 0;

  IF DATABASE() <> 'FPW' THEN
    SET @fpw_up_20260724_002_error =
      'Refusing migration: selected database is not FPW.';
  ELSE
    SELECT COUNT(*) INTO v_users_table_count
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'users'
      AND TABLE_TYPE = 'BASE TABLE'
      AND ENGINE = 'InnoDB';

    SELECT COUNT(*) INTO v_user_id_column_count
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'userId'
      AND DATA_TYPE = 'int'
      AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%'
      AND IS_NULLABLE = 'NO'
      AND COLUMN_KEY = 'PRI'
      AND LOWER(EXTRA) = 'auto_increment';

    SELECT COUNT(*) INTO v_target_column_count
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'welcomeOnboardingSeenAt';

    IF v_users_table_count <> 1 THEN
      SET @fpw_up_20260724_002_error =
        'Refusing migration: FPW.users is missing, is not a base table, or is not InnoDB.';
    ELSEIF v_user_id_column_count <> 1 THEN
      SET @fpw_up_20260724_002_error =
        'Refusing migration: users.userId is not the required signed INT NOT NULL AUTO_INCREMENT primary key.';
    ELSEIF v_target_column_count <> 0 THEN
      SET @fpw_up_20260724_002_error =
        'Refusing migration: users.welcomeOnboardingSeenAt already exists.';
    ELSE
      SELECT
        COALESCE(MAX(userId), 0),
        COUNT(*)
      INTO
        @fpw_up_20260724_002_existing_user_max_id,
        @fpw_up_20260724_002_existing_user_count
      FROM users;
    END IF;
  END IF;
END$$
DELIMITER ;

CALL `_fpw_up_20260724_002_welcome_onboarding`();
DROP PROCEDURE `_fpw_up_20260724_002_welcome_onboarding`;

SELECT @fpw_up_20260724_002_error AS migration_refusal
WHERE @fpw_up_20260724_002_error IS NOT NULL;

SET @fpw_up_20260724_002_guard_sql = IF(
  @fpw_up_20260724_002_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_refused_20260724_002` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260724_002_guard FROM @fpw_up_20260724_002_guard_sql;
EXECUTE fpw_up_20260724_002_guard;
DEALLOCATE PREPARE fpw_up_20260724_002_guard;

ALTER TABLE `users`
  ADD COLUMN `welcomeOnboardingSeenAt` DATETIME(6) NULL DEFAULT NULL;

UPDATE `users`
SET `welcomeOnboardingSeenAt` = @fpw_up_20260724_002_backfill_at
WHERE `userId` <= @fpw_up_20260724_002_existing_user_max_id
  AND `welcomeOnboardingSeenAt` IS NULL;

SET @fpw_up_20260724_002_backfilled_count = ROW_COUNT();

SELECT COUNT(*)
INTO @fpw_up_20260724_002_remaining_existing_null_count
FROM users
WHERE userId <= @fpw_up_20260724_002_existing_user_max_id
  AND welcomeOnboardingSeenAt IS NULL;

SELECT COUNT(*)
INTO @fpw_up_20260724_002_column_definition_ok
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'welcomeOnboardingSeenAt'
  AND DATA_TYPE = 'datetime'
  AND LOWER(COLUMN_TYPE) = 'datetime(6)'
  AND DATETIME_PRECISION = 6
  AND IS_NULLABLE = 'YES'
  AND (
    COLUMN_DEFAULT IS NULL
    OR UPPER(CAST(COLUMN_DEFAULT AS CHAR)) = 'NULL'
  )
  AND EXTRA = '';

SET @fpw_up_20260724_002_post_error = CASE
  WHEN @fpw_up_20260724_002_column_definition_ok <> 1 THEN
    'Migration failed verification: users.welcomeOnboardingSeenAt has an incompatible definition.'
  WHEN @fpw_up_20260724_002_backfilled_count
       <> @fpw_up_20260724_002_existing_user_count THEN
    CONCAT(
      'Migration failed verification: expected to backfill ',
      @fpw_up_20260724_002_existing_user_count,
      ' existing users but changed ',
      @fpw_up_20260724_002_backfilled_count,
      '.'
    )
  WHEN @fpw_up_20260724_002_remaining_existing_null_count <> 0 THEN
    'Migration failed verification: one or more users at or below the captured cutoff remain unacknowledged.'
  ELSE NULL
END;

SELECT
  IF(@fpw_up_20260724_002_post_error IS NULL, 'PASS', 'FAIL')
    AS migration_status,
  @fpw_up_20260724_002_existing_user_max_id AS existing_user_cutoff,
  @fpw_up_20260724_002_existing_user_count AS existing_user_count,
  @fpw_up_20260724_002_backfilled_count AS backfilled_user_count,
  @fpw_up_20260724_002_remaining_existing_null_count
    AS remaining_existing_null_count,
  @fpw_up_20260724_002_backfill_at AS backfill_timestamp_utc,
  @fpw_up_20260724_002_post_error AS migration_error;

SET @fpw_up_20260724_002_post_guard_sql = IF(
  @fpw_up_20260724_002_post_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_verification_failed_20260724_002` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260724_002_post_guard
FROM @fpw_up_20260724_002_post_guard_sql;
EXECUTE fpw_up_20260724_002_post_guard;
DEALLOCATE PREPARE fpw_up_20260724_002_post_guard;

SET @fpw_up_20260724_002_error = NULL;
SET @fpw_up_20260724_002_existing_user_max_id = NULL;
SET @fpw_up_20260724_002_existing_user_count = NULL;
SET @fpw_up_20260724_002_backfill_at = NULL;
SET @fpw_up_20260724_002_backfilled_count = NULL;
SET @fpw_up_20260724_002_remaining_existing_null_count = NULL;
SET @fpw_up_20260724_002_column_definition_ok = NULL;
SET @fpw_up_20260724_002_post_error = NULL;
SET @fpw_up_20260724_002_guard_sql = NULL;
SET @fpw_up_20260724_002_post_guard_sql = NULL;
