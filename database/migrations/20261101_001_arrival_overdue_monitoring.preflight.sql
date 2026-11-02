-- Independent arrival monitoring: read-only preflight for the inspected FPW schema.
-- Requires enforced CHECK constraints (MySQL 8.0.16+ or supported MariaDB) and
-- CREATE TABLE, REFERENCES and TRIGGER privileges when the up script is applied.
-- Run using a client which stops on errors. Do not use --force.
-- DDL is not one transaction. Any partial installation requires inspection.
SET @arrival_version = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @arrival_major = CAST(SUBSTRING_INDEX(@arrival_version,'.',1) AS UNSIGNED);
SET @arrival_minor = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@arrival_version,'.',2),'.',-1) AS UNSIGNED);
SET @arrival_patch = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@arrival_version,'.',3),'.',-1) AS UNSIGNED);
SET @arrival_is_maria = LOWER(VERSION()) LIKE '%mariadb%';
SET @arrival_error = CASE
  WHEN DATABASE() IS NULL OR BINARY DATABASE() NOT IN ('FPW', 'fpw')
    THEN 'Select the FPW or fpw database explicitly.'
  WHEN @arrival_is_maria AND NOT (@arrival_major=10 AND
        ((@arrival_minor=5 AND @arrival_patch>=26) OR (@arrival_minor=6 AND @arrival_patch=24)))
    THEN 'Unsupported MariaDB release for this migration.'
  WHEN NOT @arrival_is_maria AND (@arrival_major<8 OR (@arrival_major=8 AND @arrival_minor=0 AND @arrival_patch<16))
    THEN 'MySQL 8.0.16 or newer is required for enforced CHECK constraints.'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = BINARY DATABASE()
          AND TABLE_NAME IN ('fpw_arrival_rollout', 'fpw_arrival_watches', 'fpw_arrival_revisions', 'fpw_arrival_events')) <> 0
    THEN 'One or more arrival tables already exist. Inspect them before continuing.'
  WHEN (SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = BINARY DATABASE()
          AND TRIGGER_NAME IN ('fpw_arrival_rollout_freeze', 'fpw_arrival_rollout_keep', 'fpw_arrival_revision_freeze')) <> 0
    THEN 'An arrival trigger already exists. Inspect the installation before continuing.'
  -- MariaDB folds the schema prefix of named InnoDB foreign keys.
  WHEN @arrival_is_maria AND EXISTS (
        SELECT 1 FROM information_schema.REFERENTIAL_CONSTRAINTS
        WHERE BINARY LOWER(CONSTRAINT_SCHEMA) = BINARY 'fpw' AND CONSTRAINT_SCHEMA <> BINARY DATABASE()
          AND CONSTRAINT_NAME IN ('fk_arrival_revision_watch','fk_arrival_event_watch'))
    THEN 'MariaDB arrival foreign-key name already exists in another case variant of the selected schema.'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = BINARY DATABASE()
          AND TABLE_NAME IN ('floatplans','floatplan_monitoring','route_instances','route_instance_legs','route_instance_leg_progress')
          AND ENGINE = 'InnoDB') <> 5
    THEN 'Required operational InnoDB tables are missing.'
  WHEN NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = BINARY DATABASE()
          AND TABLE_NAME = 'floatplans' AND COLUMN_NAME = 'floatPlanId' AND DATA_TYPE = 'int'
          AND COLUMN_TYPE NOT LIKE '%unsigned%' AND COLUMN_KEY = 'PRI')
    OR NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = BINARY DATABASE()
          AND TABLE_NAME = 'floatplans' AND COLUMN_NAME = 'returnTimeUTC' AND DATA_TYPE = 'datetime')
    THEN 'Incompatible plan key or authoritative arrival column.'
  ELSE NULL
END;
SELECT @arrival_error AS refusal_reason;
SET @arrival_guard_sql = IF(@arrival_error IS NULL, 'DO 0',
    'SELECT `_fpw_arrival_preflight_refused` FROM (SELECT 1 AS ok) AS fpw_guard');
PREPARE fpw_arrival_guard FROM @arrival_guard_sql;
EXECUTE fpw_arrival_guard;
DEALLOCATE PREPARE fpw_arrival_guard;
SELECT 'PASS' AS preflight_status;
