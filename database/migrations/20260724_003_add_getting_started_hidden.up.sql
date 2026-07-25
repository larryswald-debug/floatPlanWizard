USE `FPW`;

SET @fpw_up_20260724_003_error = NULL;
SET @fpw_up_20260724_003_existing_user_count = 0;

DROP PROCEDURE IF EXISTS `_fpw_up_20260724_003_getting_started_hidden`;
DELIMITER $$
CREATE PROCEDURE `_fpw_up_20260724_003_getting_started_hidden`()
BEGIN
  DECLARE v_users_table_count INT DEFAULT 0;
  DECLARE v_user_id_column_count INT DEFAULT 0;
  DECLARE v_prerequisite_column_count INT DEFAULT 0;
  DECLARE v_target_column_count INT DEFAULT 0;

  IF DATABASE() <> 'FPW' THEN
    SET @fpw_up_20260724_003_error =
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
      AND LOWER(COLUMN_TYPE) = 'int'
      AND IS_NULLABLE = 'NO'
      AND COLUMN_KEY = 'PRI'
      AND LOWER(EXTRA) = 'auto_increment';

    SELECT COUNT(*) INTO v_prerequisite_column_count
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

    SELECT COUNT(*) INTO v_target_column_count
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'gettingStartedHidden';

    IF v_users_table_count <> 1 THEN
      SET @fpw_up_20260724_003_error =
        'Refusing migration: FPW.users is missing, is not a base table, or is not InnoDB.';
    ELSEIF v_user_id_column_count <> 1 THEN
      SET @fpw_up_20260724_003_error =
        'Refusing migration: users.userId is not the required signed INT NOT NULL AUTO_INCREMENT primary key.';
    ELSEIF v_prerequisite_column_count <> 1 THEN
      SET @fpw_up_20260724_003_error =
        'Refusing migration: migration 20260724_002 is not applied with the expected users.welcomeOnboardingSeenAt definition.';
    ELSEIF v_target_column_count <> 0 THEN
      SET @fpw_up_20260724_003_error =
        'Refusing migration: users.gettingStartedHidden already exists.';
    ELSE
      SELECT COUNT(*)
      INTO @fpw_up_20260724_003_existing_user_count
      FROM users;
    END IF;
  END IF;
END$$
DELIMITER ;

CALL `_fpw_up_20260724_003_getting_started_hidden`();
DROP PROCEDURE `_fpw_up_20260724_003_getting_started_hidden`;

SELECT @fpw_up_20260724_003_error AS migration_refusal
WHERE @fpw_up_20260724_003_error IS NOT NULL;

SET @fpw_up_20260724_003_guard_sql = IF(
  @fpw_up_20260724_003_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_refused_20260724_003` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260724_003_guard FROM @fpw_up_20260724_003_guard_sql;
EXECUTE fpw_up_20260724_003_guard;
DEALLOCATE PREPARE fpw_up_20260724_003_guard;

ALTER TABLE `users`
  ADD COLUMN `gettingStartedHidden` TINYINT(1) NULL DEFAULT NULL
  AFTER `welcomeOnboardingSeenAt`;

SELECT COUNT(*)
INTO @fpw_up_20260724_003_column_definition_ok
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'gettingStartedHidden'
  AND DATA_TYPE = 'tinyint'
  AND LOWER(COLUMN_TYPE) = 'tinyint(1)'
  AND IS_NULLABLE = 'YES'
  AND COLUMN_DEFAULT IS NULL
  AND EXTRA = '';

SELECT COUNT(*)
INTO @fpw_up_20260724_003_non_null_preference_count
FROM users
WHERE gettingStartedHidden IS NOT NULL;

SET @fpw_up_20260724_003_post_error = CASE
  WHEN @fpw_up_20260724_003_column_definition_ok <> 1 THEN
    'Migration failed verification: users.gettingStartedHidden has an incompatible definition.'
  WHEN @fpw_up_20260724_003_non_null_preference_count <> 0 THEN
    'Migration failed verification: one or more users received a non-NULL visibility preference.'
  ELSE NULL
END;

SELECT
  IF(@fpw_up_20260724_003_post_error IS NULL, 'PASS', 'FAIL')
    AS migration_status,
  @fpw_up_20260724_003_existing_user_count AS existing_user_count,
  @fpw_up_20260724_003_non_null_preference_count
    AS non_null_preference_count,
  @fpw_up_20260724_003_post_error AS migration_error;

SET @fpw_up_20260724_003_post_guard_sql = IF(
  @fpw_up_20260724_003_post_error IS NULL,
  'DO 0',
  'SELECT `_fpw_migration_verification_failed_20260724_003` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_up_20260724_003_post_guard
FROM @fpw_up_20260724_003_post_guard_sql;
EXECUTE fpw_up_20260724_003_post_guard;
DEALLOCATE PREPARE fpw_up_20260724_003_post_guard;

SET @fpw_up_20260724_003_error = NULL;
SET @fpw_up_20260724_003_existing_user_count = NULL;
SET @fpw_up_20260724_003_column_definition_ok = NULL;
SET @fpw_up_20260724_003_non_null_preference_count = NULL;
SET @fpw_up_20260724_003_post_error = NULL;
SET @fpw_up_20260724_003_guard_sql = NULL;
SET @fpw_up_20260724_003_post_guard_sql = NULL;
