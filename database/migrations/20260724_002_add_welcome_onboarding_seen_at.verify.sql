USE `FPW`;

SELECT DATABASE() AS selected_database, VERSION() AS database_version;

SELECT
  COLUMN_NAME,
  COLUMN_TYPE,
  IS_NULLABLE,
  COLUMN_DEFAULT,
  DATETIME_PRECISION,
  EXTRA
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'welcomeOnboardingSeenAt';

SET @fpw_verify_20260724_002_database_ok = DATABASE() = 'FPW';

SELECT COUNT(*)
INTO @fpw_verify_20260724_002_column_definition_ok
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

SELECT
  COUNT(*) AS total_users,
  SUM(welcomeOnboardingSeenAt IS NULL) AS unacknowledged_users,
  SUM(welcomeOnboardingSeenAt IS NOT NULL) AS acknowledged_users
FROM users;

SET @fpw_verify_20260724_002_status = IF(
  @fpw_verify_20260724_002_database_ok = 1
  AND @fpw_verify_20260724_002_column_definition_ok = 1,
  'PASS',
  'FAIL'
);

SELECT
  @fpw_verify_20260724_002_status AS verification_status,
  @fpw_verify_20260724_002_database_ok AS database_ok,
  @fpw_verify_20260724_002_column_definition_ok AS column_definition_ok;

SET @fpw_verify_20260724_002_guard_sql = IF(
  @fpw_verify_20260724_002_status = 'PASS',
  'DO 0',
  'SELECT `_fpw_verification_failed_20260724_002` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_verify_20260724_002_guard
FROM @fpw_verify_20260724_002_guard_sql;
EXECUTE fpw_verify_20260724_002_guard;
DEALLOCATE PREPARE fpw_verify_20260724_002_guard;

SET @fpw_verify_20260724_002_database_ok = NULL;
SET @fpw_verify_20260724_002_column_definition_ok = NULL;
SET @fpw_verify_20260724_002_status = NULL;
SET @fpw_verify_20260724_002_guard_sql = NULL;
