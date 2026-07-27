USE `FPW`;

SET @fpw_down_20260724_003_error = NULL;
SET @fpw_down_20260724_003_drop_column = 0;

DROP PROCEDURE IF EXISTS `_fpw_down_20260724_003_getting_started_hidden`;
DELIMITER $$
CREATE PROCEDURE `_fpw_down_20260724_003_getting_started_hidden`()
BEGIN
  DECLARE v_users_table_count INT DEFAULT 0;
  DECLARE v_named_column_count INT DEFAULT 0;
  DECLARE v_exact_column_count INT DEFAULT 0;

  IF DATABASE() <> 'FPW' THEN
    SET @fpw_down_20260724_003_error =
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
      AND COLUMN_NAME = 'gettingStartedHidden';

    SELECT COUNT(*) INTO v_exact_column_count
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'FPW'
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'gettingStartedHidden'
      AND DATA_TYPE = 'tinyint'
      AND LOWER(COLUMN_TYPE) = 'tinyint(1)'
      AND IS_NULLABLE = 'YES'
      AND (
        COLUMN_DEFAULT IS NULL
        OR UPPER(CAST(COLUMN_DEFAULT AS CHAR)) = 'NULL'
      )
      AND EXTRA = '';

    IF v_users_table_count <> 1 THEN
      SET @fpw_down_20260724_003_error =
        'Refusing rollback: FPW.users does not exist.';
    ELSEIF CAST(
      COALESCE(@fpw_confirm_drop_getting_started_hidden, '')
      AS BINARY
    ) <> CAST('DROP_GETTING_STARTED_HIDDEN' AS BINARY) THEN
      SET @fpw_down_20260724_003_error =
        'Refusing rollback: set @fpw_confirm_drop_getting_started_hidden to DROP_GETTING_STARTED_HIDDEN in this session.';
    ELSEIF v_named_column_count = 0 THEN
      SET @fpw_down_20260724_003_error =
        'Refusing rollback: users.gettingStartedHidden does not exist.';
    ELSEIF v_exact_column_count <> 1 THEN
      SET @fpw_down_20260724_003_error =
        'Refusing rollback: users.gettingStartedHidden has an incompatible definition.';
    ELSE
      SET @fpw_down_20260724_003_drop_column = 1;
    END IF;
  END IF;
END$$
DELIMITER ;

CALL `_fpw_down_20260724_003_getting_started_hidden`();
DROP PROCEDURE `_fpw_down_20260724_003_getting_started_hidden`;

SELECT @fpw_down_20260724_003_error AS rollback_refusal
WHERE @fpw_down_20260724_003_error IS NOT NULL;

SET @fpw_down_20260724_003_guard_sql = IF(
  @fpw_down_20260724_003_error IS NULL,
  'DO 0',
  'SELECT `_fpw_rollback_refused_20260724_003` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_down_20260724_003_guard
FROM @fpw_down_20260724_003_guard_sql;
EXECUTE fpw_down_20260724_003_guard;
DEALLOCATE PREPARE fpw_down_20260724_003_guard;

SET @fpw_down_20260724_003_column_sql = IF(
  @fpw_down_20260724_003_drop_column = 1,
  'ALTER TABLE `users` DROP COLUMN `gettingStartedHidden`',
  'DO 0'
);
PREPARE fpw_down_20260724_003_column
FROM @fpw_down_20260724_003_column_sql;
EXECUTE fpw_down_20260724_003_column;
DEALLOCATE PREPARE fpw_down_20260724_003_column;

SELECT COUNT(*)
INTO @fpw_down_20260724_003_remaining_column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'gettingStartedHidden';

SET @fpw_down_20260724_003_status = IF(
  @fpw_down_20260724_003_remaining_column_count = 0,
  'PASS',
  'FAIL'
);

SELECT
  @fpw_down_20260724_003_status AS rollback_status,
  @fpw_down_20260724_003_remaining_column_count AS remaining_column_count;

SET @fpw_down_20260724_003_post_guard_sql = IF(
  @fpw_down_20260724_003_status = 'PASS',
  'DO 0',
  'SELECT `_fpw_rollback_verification_failed_20260724_003` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_down_20260724_003_post_guard
FROM @fpw_down_20260724_003_post_guard_sql;
EXECUTE fpw_down_20260724_003_post_guard;
DEALLOCATE PREPARE fpw_down_20260724_003_post_guard;

SET @fpw_confirm_drop_getting_started_hidden = NULL;
SET @fpw_down_20260724_003_error = NULL;
SET @fpw_down_20260724_003_drop_column = NULL;
SET @fpw_down_20260724_003_remaining_column_count = NULL;
SET @fpw_down_20260724_003_status = NULL;
SET @fpw_down_20260724_003_guard_sql = NULL;
SET @fpw_down_20260724_003_column_sql = NULL;
SET @fpw_down_20260724_003_post_guard_sql = NULL;
