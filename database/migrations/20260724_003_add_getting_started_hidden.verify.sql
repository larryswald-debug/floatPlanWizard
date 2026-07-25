USE `FPW`;

SELECT DATABASE() AS selected_database, VERSION() AS database_version;

SELECT
  COLUMN_NAME,
  COLUMN_TYPE,
  IS_NULLABLE,
  COLUMN_DEFAULT,
  EXTRA
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'gettingStartedHidden';

SET @fpw_verify_20260724_003_database_ok = DATABASE() = 'FPW';

SELECT COUNT(*)
INTO @fpw_verify_20260724_003_column_definition_ok
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'gettingStartedHidden'
  AND DATA_TYPE = 'tinyint'
  AND LOWER(COLUMN_TYPE) = 'tinyint(1)'
  AND IS_NULLABLE = 'YES'
  AND COLUMN_DEFAULT IS NULL
  AND EXTRA = '';

SELECT
  COUNT(*) AS total_users,
  COALESCE(SUM(gettingStartedHidden IS NULL), 0) AS automatic_users,
  COALESCE(SUM(gettingStartedHidden = 0), 0) AS explicitly_shown_users,
  COALESCE(SUM(gettingStartedHidden = 1), 0) AS explicitly_hidden_users,
  COALESCE(
    SUM(
      gettingStartedHidden IS NOT NULL
      AND gettingStartedHidden NOT IN (0, 1)
    ),
    0
  ) AS invalid_preference_users
FROM users;

SELECT COUNT(*)
INTO @fpw_verify_20260724_003_invalid_preference_count
FROM users
WHERE gettingStartedHidden IS NOT NULL
  AND gettingStartedHidden NOT IN (0, 1);

SET @fpw_verify_20260724_003_status = IF(
  @fpw_verify_20260724_003_database_ok = 1
  AND @fpw_verify_20260724_003_column_definition_ok = 1
  AND @fpw_verify_20260724_003_invalid_preference_count = 0,
  'PASS',
  'FAIL'
);

SELECT
  @fpw_verify_20260724_003_status AS verification_status,
  @fpw_verify_20260724_003_database_ok AS database_ok,
  @fpw_verify_20260724_003_column_definition_ok AS column_definition_ok,
  @fpw_verify_20260724_003_invalid_preference_count
    AS invalid_preference_count;

SET @fpw_verify_20260724_003_guard_sql = IF(
  @fpw_verify_20260724_003_status = 'PASS',
  'DO 0',
  'SELECT `_fpw_verification_failed_20260724_003` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_verify_20260724_003_guard
FROM @fpw_verify_20260724_003_guard_sql;
EXECUTE fpw_verify_20260724_003_guard;
DEALLOCATE PREPARE fpw_verify_20260724_003_guard;

SET @fpw_verify_20260724_003_database_ok = NULL;
SET @fpw_verify_20260724_003_column_definition_ok = NULL;
SET @fpw_verify_20260724_003_invalid_preference_count = NULL;
SET @fpw_verify_20260724_003_status = NULL;
SET @fpw_verify_20260724_003_guard_sql = NULL;
