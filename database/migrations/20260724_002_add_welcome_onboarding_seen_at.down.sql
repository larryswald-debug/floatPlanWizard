USE `FPW`;

SET @fpw_down_20260724_002_error = NULL;
SET @fpw_down_20260724_002_drop_column = 0;

DROP PROCEDURE IF EXISTS `_fpw_down_20260724_002_welcome_onboarding`;
DELIMITER $$
CREATE PROCEDURE `_fpw_down_20260724_002_welcome_onboarding`()
BEGIN
  DECLARE v_users_table_count INT DEFAULT 0;
  DECLARE v_named_column_count INT DEFAULT 0;
  DECLARE v_exact_column_count INT DEFAULT 0;

  IF DATABASE() <> 'FPW' THEN
    SET @fpw_down_20260724_002_error =
      'Refusing rollback: selected database is not FPW.';
  ELSE
    SELECT COUNT(*) INTO v_users_table_count
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'users'
      AND TABLE_TYPE = 'BASE TABLE';

    SELECT COUNT(*) INTO v_named_column_count
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'welcomeOnboardingSeenAt';

    SELECT COUNT(*) INTO v_exact_column_count
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'welcomeOnboardingSeenAt'
      AND DATA_TYPE = 'datetime'
      AND LOWER(COLUMN_TYPE) = 'datetime(6)'
      AND DATETIME_PRECISION = 6
      AND IS_NULLABLE = 'YES'
      AND COLUMN_DEFAULT IS NULL
      AND EXTRA = '';

    IF v_users_table_count <> 1 THEN
      SET @fpw_down_20260724_002_error =
        'Refusing rollback: FPW.users does not exist.';
    ELSEIF CAST(
      COALESCE(@fpw_confirm_drop_welcome_onboarding_seen_at, '')
      AS BINARY
    ) <> CAST('DROP_WELCOME_ONBOARDING_SEEN_AT' AS BINARY) THEN
      SET @fpw_down_20260724_002_error =
        'Refusing rollback: set @fpw_confirm_drop_welcome_onboarding_seen_at to DROP_WELCOME_ONBOARDING_SEEN_AT in this session.';
    ELSEIF v_named_column_count = 0 THEN
      SET @fpw_down_20260724_002_error =
        'Refusing rollback: users.welcomeOnboardingSeenAt does not exist.';
    ELSEIF v_exact_column_count <> 1 THEN
      SET @fpw_down_20260724_002_error =
        'Refusing rollback: users.welcomeOnboardingSeenAt has an incompatible definition.';
    ELSE
      SET @fpw_down_20260724_002_drop_column = 1;
    END IF;
  END IF;
END$$
DELIMITER ;

CALL `_fpw_down_20260724_002_welcome_onboarding`();
DROP PROCEDURE `_fpw_down_20260724_002_welcome_onboarding`;

SELECT @fpw_down_20260724_002_error AS rollback_refusal
WHERE @fpw_down_20260724_002_error IS NOT NULL;

SET @fpw_down_20260724_002_guard_sql = IF(
  @fpw_down_20260724_002_error IS NULL,
  'DO 0',
  'SELECT `_fpw_rollback_refused_20260724_002` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_down_20260724_002_guard
FROM @fpw_down_20260724_002_guard_sql;
EXECUTE fpw_down_20260724_002_guard;
DEALLOCATE PREPARE fpw_down_20260724_002_guard;

SET @fpw_down_20260724_002_column_sql = IF(
  @fpw_down_20260724_002_drop_column = 1,
  'ALTER TABLE `users` DROP COLUMN `welcomeOnboardingSeenAt`',
  'DO 0'
);
PREPARE fpw_down_20260724_002_column
FROM @fpw_down_20260724_002_column_sql;
EXECUTE fpw_down_20260724_002_column;
DEALLOCATE PREPARE fpw_down_20260724_002_column;

SELECT COUNT(*)
INTO @fpw_down_20260724_002_remaining_column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'welcomeOnboardingSeenAt';

SET @fpw_down_20260724_002_status = IF(
  @fpw_down_20260724_002_remaining_column_count = 0,
  'PASS',
  'FAIL'
);

SELECT
  @fpw_down_20260724_002_status AS rollback_status,
  @fpw_down_20260724_002_remaining_column_count AS remaining_column_count;

SET @fpw_down_20260724_002_post_guard_sql = IF(
  @fpw_down_20260724_002_status = 'PASS',
  'DO 0',
  'SELECT `_fpw_rollback_verification_failed_20260724_002` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_down_20260724_002_post_guard
FROM @fpw_down_20260724_002_post_guard_sql;
EXECUTE fpw_down_20260724_002_post_guard;
DEALLOCATE PREPARE fpw_down_20260724_002_post_guard;

SET @fpw_confirm_drop_welcome_onboarding_seen_at = NULL;
SET @fpw_down_20260724_002_error = NULL;
SET @fpw_down_20260724_002_drop_column = NULL;
SET @fpw_down_20260724_002_remaining_column_count = NULL;
SET @fpw_down_20260724_002_status = NULL;
SET @fpw_down_20260724_002_guard_sql = NULL;
SET @fpw_down_20260724_002_column_sql = NULL;
SET @fpw_down_20260724_002_post_guard_sql = NULL;
