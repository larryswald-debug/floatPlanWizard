-- Guarded rollback for FPW introductory Premium trip Phase 1 only.
-- MySQL DDL implicitly commits. A connection-scoped temporary CHECK guard
-- refuses populated tables before either DROP TABLE statement.

USE `FPW`;

SET @phase1_entitlement_table_exists = (
  SELECT COUNT(*)
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'introductory_trip_entitlements'
);

SET @phase1_outbox_table_exists = (
  SELECT COUNT(*)
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'floatplan_notification_outbox'
);

SET @phase1_entitlement_rows = 0;
SET @phase1_entitlement_count_sql = IF(
  @phase1_entitlement_table_exists = 1,
  'SELECT COUNT(*) INTO @phase1_entitlement_rows FROM `introductory_trip_entitlements`',
  'SET @phase1_entitlement_rows = 0'
);
PREPARE phase1_entitlement_count_statement FROM @phase1_entitlement_count_sql;
EXECUTE phase1_entitlement_count_statement;
DEALLOCATE PREPARE phase1_entitlement_count_statement;

SET @phase1_outbox_rows = 0;
SET @phase1_outbox_count_sql = IF(
  @phase1_outbox_table_exists = 1,
  'SELECT COUNT(*) INTO @phase1_outbox_rows FROM `floatplan_notification_outbox`',
  'SET @phase1_outbox_rows = 0'
);
PREPARE phase1_outbox_count_statement FROM @phase1_outbox_count_sql;
EXECUTE phase1_outbox_count_statement;
DEALLOCATE PREPARE phase1_outbox_count_statement;

DROP TEMPORARY TABLE IF EXISTS `_fpw_rollback_20260721_001_guard`;
CREATE TEMPORARY TABLE `_fpw_rollback_20260721_001_guard` (
  `phase_1_tables_must_be_empty` TINYINT NOT NULL,
  CONSTRAINT `chk_rollback_refused_phase1_tables_contain_data`
    CHECK (`phase_1_tables_must_be_empty` = 0)
) ENGINE=InnoDB;

INSERT INTO `_fpw_rollback_20260721_001_guard` (`phase_1_tables_must_be_empty`)
VALUES (IF(@phase1_entitlement_rows = 0 AND @phase1_outbox_rows = 0, 0, 1));

DROP TEMPORARY TABLE `_fpw_rollback_20260721_001_guard`;
DROP TABLE IF EXISTS `floatplan_notification_outbox`;
DROP TABLE IF EXISTS `introductory_trip_entitlements`;
