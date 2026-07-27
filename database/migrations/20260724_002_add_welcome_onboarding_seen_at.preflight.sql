-- FPW welcome-onboarding production preflight.
--
-- Run this script with the production connection explicitly selecting the FPW
-- database. It does not create or modify application tables or application data.
-- Do not use mysql --force: a failed guard must stop the deployment.
--
-- Required execution order:
--   1. This preflight
--   2. 20260724_002_add_welcome_onboarding_seen_at.up.sql
--   3. 20260724_002_add_welcome_onboarding_seen_at.verify.sql

SET @fpw_preflight_20260724_002_error = NULL;
SET @fpw_preflight_20260724_002_users_table_count = 0;
SET @fpw_preflight_20260724_002_user_id_column_count = 0;
SET @fpw_preflight_20260724_002_target_column_count = 0;
SET @fpw_preflight_20260724_002_existing_user_count = 0;
SET @fpw_preflight_20260724_002_existing_user_max_id = 0;

SELECT COUNT(*)
INTO @fpw_preflight_20260724_002_users_table_count
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'users'
  AND TABLE_TYPE = 'BASE TABLE'
  AND ENGINE = 'InnoDB';

SELECT COUNT(*)
INTO @fpw_preflight_20260724_002_user_id_column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'userId'
  AND DATA_TYPE = 'int'
  AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%'
  AND IS_NULLABLE = 'NO'
  AND COLUMN_KEY = 'PRI'
  AND LOWER(EXTRA) = 'auto_increment';

SELECT COUNT(*)
INTO @fpw_preflight_20260724_002_target_column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'welcomeOnboardingSeenAt';

SET @fpw_preflight_20260724_002_users_sql = IF(
  @fpw_preflight_20260724_002_users_table_count = 1,
  'SELECT COUNT(*), COALESCE(MAX(userId), 0) INTO @fpw_preflight_20260724_002_existing_user_count, @fpw_preflight_20260724_002_existing_user_max_id FROM FPW.users',
  'DO 0'
);
PREPARE fpw_preflight_20260724_002_users
FROM @fpw_preflight_20260724_002_users_sql;
EXECUTE fpw_preflight_20260724_002_users;
DEALLOCATE PREPARE fpw_preflight_20260724_002_users;

SET @fpw_preflight_20260724_002_error = CASE
  WHEN DATABASE() IS NULL THEN
    'Refusing production preflight: no database is selected.'
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    CONCAT(
      'Refusing production preflight: selected database is ',
      DATABASE(),
      ', not FPW.'
    )
  WHEN @fpw_preflight_20260724_002_users_table_count <> 1 THEN
    'Refusing production preflight: FPW.users is missing, is not a base table, or is not InnoDB.'
  WHEN @fpw_preflight_20260724_002_user_id_column_count <> 1 THEN
    'Refusing production preflight: users.userId is not the required signed INT NOT NULL AUTO_INCREMENT primary key.'
  WHEN @fpw_preflight_20260724_002_target_column_count <> 0 THEN
    'Refusing production preflight: users.welcomeOnboardingSeenAt already exists.'
  ELSE NULL
END;

SELECT
  DATABASE() AS selected_database,
  VERSION() AS database_version,
  @fpw_preflight_20260724_002_users_table_count AS compatible_users_tables,
  @fpw_preflight_20260724_002_user_id_column_count AS compatible_user_id_columns,
  @fpw_preflight_20260724_002_target_column_count AS existing_target_columns,
  @fpw_preflight_20260724_002_existing_user_count AS existing_user_count,
  @fpw_preflight_20260724_002_existing_user_max_id AS existing_user_max_id,
  IF(
    @fpw_preflight_20260724_002_error IS NULL,
    'PASS',
    'FAIL'
  ) AS preflight_status,
  @fpw_preflight_20260724_002_error AS preflight_error;

SET @fpw_preflight_20260724_002_guard_sql = IF(
  @fpw_preflight_20260724_002_error IS NULL,
  'DO 0',
  'SELECT `_fpw_production_preflight_refused_20260724_002` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_preflight_20260724_002_guard
FROM @fpw_preflight_20260724_002_guard_sql;
EXECUTE fpw_preflight_20260724_002_guard;
DEALLOCATE PREPARE fpw_preflight_20260724_002_guard;

SET @fpw_preflight_20260724_002_error = NULL;
SET @fpw_preflight_20260724_002_users_table_count = NULL;
SET @fpw_preflight_20260724_002_user_id_column_count = NULL;
SET @fpw_preflight_20260724_002_target_column_count = NULL;
SET @fpw_preflight_20260724_002_existing_user_count = NULL;
SET @fpw_preflight_20260724_002_existing_user_max_id = NULL;
SET @fpw_preflight_20260724_002_users_sql = NULL;
SET @fpw_preflight_20260724_002_guard_sql = NULL;
