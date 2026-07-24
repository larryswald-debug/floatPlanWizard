-- FPW Premium Send Credit production preflight.
--
-- Run this script with the production connection explicitly selecting the FPW
-- database. It does not create or modify application tables or application data.
-- Do not use mysql --force: a failed guard must stop the deployment.
--
-- Required execution order:
--   1. This preflight
--   2. 20260721_001_membership_premium_send_credits.up.sql
--   3. 20260721_001_membership_premium_send_credits.verify.sql
--
-- Supported database engines:
--   * MySQL 8.0.16 or newer
--   * MariaDB 10.5.26 or newer within the 10.5 release series

SET @fpw_preflight_20260721_001_error = NULL;
SET @fpw_preflight_20260721_001_existing_tables = 0;
SET @fpw_preflight_20260721_001_prerequisite_tables = 0;
SET @fpw_preflight_20260721_001_parent_columns = 0;
SET @fpw_preflight_20260721_001_innodb_parents = 0;
SET @fpw_preflight_20260721_001_is_mariadb =
  LOWER(VERSION()) LIKE '%mariadb%';
SET @fpw_preflight_20260721_001_database_engine =
  IF(@fpw_preflight_20260721_001_is_mariadb = 1, 'MariaDB', 'MySQL');
SET @fpw_preflight_20260721_001_version_core =
  SUBSTRING_INDEX(VERSION(), '-', 1);
SET @fpw_preflight_20260721_001_version_major =
  CAST(SUBSTRING_INDEX(@fpw_preflight_20260721_001_version_core, '.', 1) AS UNSIGNED);
SET @fpw_preflight_20260721_001_version_minor =
  CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@fpw_preflight_20260721_001_version_core, '.', 2), '.', -1) AS UNSIGNED);
SET @fpw_preflight_20260721_001_version_patch =
  CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@fpw_preflight_20260721_001_version_core, '.', 3), '.', -1) AS UNSIGNED);
SET @fpw_preflight_20260721_001_check_enforcement = 1;

SET @fpw_preflight_20260721_001_check_sql = IF(
  @fpw_preflight_20260721_001_is_mariadb = 1,
  'SELECT @@SESSION.check_constraint_checks INTO @fpw_preflight_20260721_001_check_enforcement',
  'SET @fpw_preflight_20260721_001_check_enforcement = 1'
);
PREPARE fpw_preflight_20260721_001_check
FROM @fpw_preflight_20260721_001_check_sql;
EXECUTE fpw_preflight_20260721_001_check;
DEALLOCATE PREPARE fpw_preflight_20260721_001_check;

SELECT COUNT(*)
INTO @fpw_preflight_20260721_001_existing_tables
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME IN ('premium_send_credits', 'premium_send_receipts');

SELECT COUNT(*)
INTO @fpw_preflight_20260721_001_prerequisite_tables
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_TYPE = 'BASE TABLE'
  AND TABLE_NAME IN (
    'users',
    'floatplans',
    'stripe_webhook_events',
    'user_stripe_customers'
  );

SELECT COUNT(*)
INTO @fpw_preflight_20260721_001_parent_columns
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND (
    (
      TABLE_NAME = 'users'
      AND COLUMN_NAME = 'userId'
      AND DATA_TYPE = 'int'
      AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%'
      AND IS_NULLABLE = 'NO'
    )
    OR
    (
      TABLE_NAME = 'floatplans'
      AND COLUMN_NAME = 'floatPlanId'
      AND DATA_TYPE = 'int'
      AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%'
      AND IS_NULLABLE = 'NO'
    )
  );

SELECT COUNT(*)
INTO @fpw_preflight_20260721_001_innodb_parents
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_TYPE = 'BASE TABLE'
  AND ENGINE = 'InnoDB'
  AND TABLE_NAME IN ('users', 'floatplans');

SET @fpw_preflight_20260721_001_error = CASE
  WHEN DATABASE() IS NULL THEN
    'Refusing production preflight: no database is selected.'
  WHEN CAST(DATABASE() AS BINARY) <> CAST('FPW' AS BINARY) THEN
    CONCAT(
      'Refusing production preflight: selected database is ',
      DATABASE(),
      ', not FPW.'
    )
  WHEN
    @fpw_preflight_20260721_001_is_mariadb = 1
    AND (
      @fpw_preflight_20260721_001_version_major <> 10
      OR @fpw_preflight_20260721_001_version_minor <> 5
      OR @fpw_preflight_20260721_001_version_patch < 26
    )
  THEN
    CONCAT(
      'Refusing production preflight: supported MariaDB versions are 10.5.26 or newer within the 10.5 series; found ',
      VERSION(),
      '.'
    )
  WHEN
    @fpw_preflight_20260721_001_is_mariadb = 0
    AND (
      @fpw_preflight_20260721_001_version_major < 8
      OR (
        @fpw_preflight_20260721_001_version_major = 8
        AND @fpw_preflight_20260721_001_version_minor = 0
        AND @fpw_preflight_20260721_001_version_patch < 16
      )
    )
  THEN
    CONCAT(
      'Refusing production preflight: MySQL 8.0.16 or newer is required; found ',
      VERSION(),
      '.'
    )
  WHEN @fpw_preflight_20260721_001_check_enforcement <> 1 THEN
    'Refusing production preflight: MariaDB CHECK constraint enforcement is disabled for this session.'
  WHEN @fpw_preflight_20260721_001_existing_tables <> 0 THEN
    'Refusing production preflight: a Premium Send Credit migration table already exists.'
  WHEN @fpw_preflight_20260721_001_prerequisite_tables <> 4 THEN
    'Refusing production preflight: one or more prerequisite FPW tables are missing.'
  WHEN @fpw_preflight_20260721_001_parent_columns <> 2 THEN
    'Refusing production preflight: users.userId or floatplans.floatPlanId is not the required NOT NULL INT type.'
  WHEN @fpw_preflight_20260721_001_innodb_parents <> 2 THEN
    'Refusing production preflight: users and floatplans must both use InnoDB.'
  ELSE NULL
END;

SELECT
  DATABASE() AS selected_database,
  @fpw_preflight_20260721_001_database_engine AS database_engine,
  VERSION() AS database_version,
  @fpw_preflight_20260721_001_check_enforcement AS check_constraint_enforcement,
  @fpw_preflight_20260721_001_existing_tables AS existing_phase2_tables,
  @fpw_preflight_20260721_001_prerequisite_tables AS prerequisite_tables_found,
  @fpw_preflight_20260721_001_parent_columns AS compatible_parent_columns,
  @fpw_preflight_20260721_001_innodb_parents AS innodb_parent_tables,
  IF(
    @fpw_preflight_20260721_001_error IS NULL,
    'PASS',
    'FAIL'
  ) AS preflight_status,
  @fpw_preflight_20260721_001_error AS preflight_error;

SET @fpw_preflight_20260721_001_guard_sql = IF(
  @fpw_preflight_20260721_001_error IS NULL,
  'DO 0',
  'SELECT `_fpw_production_preflight_refused_20260721_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_preflight_20260721_001_guard
FROM @fpw_preflight_20260721_001_guard_sql;
EXECUTE fpw_preflight_20260721_001_guard;
DEALLOCATE PREPARE fpw_preflight_20260721_001_guard;

SET @fpw_preflight_20260721_001_error = NULL;
SET @fpw_preflight_20260721_001_existing_tables = NULL;
SET @fpw_preflight_20260721_001_prerequisite_tables = NULL;
SET @fpw_preflight_20260721_001_parent_columns = NULL;
SET @fpw_preflight_20260721_001_innodb_parents = NULL;
SET @fpw_preflight_20260721_001_is_mariadb = NULL;
SET @fpw_preflight_20260721_001_database_engine = NULL;
SET @fpw_preflight_20260721_001_version_core = NULL;
SET @fpw_preflight_20260721_001_version_major = NULL;
SET @fpw_preflight_20260721_001_version_minor = NULL;
SET @fpw_preflight_20260721_001_version_patch = NULL;
SET @fpw_preflight_20260721_001_check_enforcement = NULL;
SET @fpw_preflight_20260721_001_check_sql = NULL;
SET @fpw_preflight_20260721_001_guard_sql = NULL;
