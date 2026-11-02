-- Read-only preflight. Run the Phase 2 verifier first; use a client that stops on errors.
SET @delivery_version = SUBSTRING_INDEX(VERSION(), '-', 1);
SET @delivery_major = CAST(SUBSTRING_INDEX(@delivery_version,'.',1) AS UNSIGNED);
SET @delivery_minor = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@delivery_version,'.',2),'.',-1) AS UNSIGNED);
SET @delivery_patch = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@delivery_version,'.',3),'.',-1) AS UNSIGNED);
SET @delivery_is_maria = LOWER(VERSION()) LIKE '%mariadb%';
SET @delivery_error = CASE
  WHEN DATABASE() IS NULL OR BINARY DATABASE() NOT IN ('FPW', 'fpw')
    THEN 'Select the FPW or fpw database explicitly.'
  WHEN @delivery_is_maria AND NOT (@delivery_major=10 AND
        ((@delivery_minor=5 AND @delivery_patch>=26) OR (@delivery_minor=6 AND @delivery_patch=24)))
    THEN 'Unsupported MariaDB release for this migration.'
  WHEN NOT @delivery_is_maria AND (@delivery_major<8 OR (@delivery_major=8 AND @delivery_minor=0 AND @delivery_patch<16))
    THEN 'MySQL 8.0.16 or newer is required for enforced CHECK constraints.'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=BINARY DATABASE()
          AND TABLE_NAME IN ('fpw_arrival_dispatch_control', 'fpw_arrival_notices', 'fpw_arrival_deliveries', 'fpw_arrival_attempts')) <> 0
    THEN 'Arrival dispatch table already exists; inspect partial or previous installation.'
  WHEN (SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=BINARY DATABASE()
          AND TRIGGER_NAME IN ('fpw_arrival_control_start','fpw_arrival_control_generation', 'fpw_arrival_control_keep', 'fpw_arrival_notice_binding', 'fpw_arrival_notice_identity')) <> 0
    THEN 'Arrival dispatch trigger already exists.'
  -- MariaDB folds the schema prefix of named InnoDB foreign keys.
  WHEN @delivery_is_maria AND EXISTS (
        SELECT 1 FROM information_schema.REFERENTIAL_CONSTRAINTS
        WHERE BINARY LOWER(CONSTRAINT_SCHEMA) = BINARY 'fpw' AND CONSTRAINT_SCHEMA <> BINARY DATABASE()
          AND CONSTRAINT_NAME IN ('fk_arrival_notice_revision','fk_arrival_delivery_notice','fk_arrival_attempt_delivery'))
    THEN 'MariaDB delivery foreign-key name already exists in another case variant of the selected schema.'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=BINARY DATABASE() AND ENGINE='InnoDB'
          AND TABLE_NAME IN ('fpw_arrival_rollout','fpw_arrival_watches','fpw_arrival_revisions','fpw_arrival_events')) <> 4
    THEN 'Verified Phase 2 arrival schema is required.'
  WHEN NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=BINARY DATABASE()
          AND TABLE_NAME='fpw_arrival_revisions' AND COLUMN_NAME='id' AND DATA_TYPE='bigint'
          AND COLUMN_TYPE LIKE '%unsigned%' AND COLUMN_KEY='PRI')
    OR NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=BINARY DATABASE()
          AND TABLE_NAME='fpw_arrival_revisions' AND COLUMN_NAME='plan_id' AND DATA_TYPE='int'
          AND COLUMN_TYPE NOT LIKE '%unsigned%')
    THEN 'Incompatible Phase 2 revision identity.'
  ELSE NULL
END;
SELECT @delivery_error AS refusal_reason;
SET @delivery_sql = IF(@delivery_error IS NULL, 'DO 0',
    'SELECT `_fpw_delivery_preflight_refused` FROM (SELECT 1 AS ok) AS fpw_guard');
PREPARE fpw_delivery_guard FROM @delivery_sql;
EXECUTE fpw_delivery_guard;
DEALLOCATE PREPARE fpw_delivery_guard;
SELECT 'PASS' AS preflight_status;
