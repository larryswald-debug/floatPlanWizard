-- Destructive rollback is intentionally refused after any recovery activity/reset.
-- Stop all recovery processing and retain a database backup before use.
-- Run with a client that stops on the first SQL error; never continue after a failed guard.
-- DROP CONSTRAINT is supported by MariaDB and MySQL 8.0.19+.
DELIMITER $$
CREATE PROCEDURE fpw_recovery_center_down_guard()
BEGIN
 IF (SELECT COUNT(*) FROM inactive_member_recovery_deliveries) +
    (SELECT COUNT(*) FROM inactive_member_recovery_messages) +
    (SELECT COUNT(*) FROM inactive_member_recovery_evaluations) +
    (SELECT COUNT(*) FROM inactive_member_recovery_runs) +
    (SELECT COUNT(*) FROM inactive_member_recovery_member_state) > 0
    OR (SELECT reset_at_utc IS NOT NULL OR revision<>1 FROM inactive_member_recovery_settings WHERE id=1) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='STOP: recovery history/settings exist; retain data and restore from a reviewed backup';
 END IF;
END$$
DELIMITER ;
CALL fpw_recovery_center_down_guard();
DROP PROCEDURE fpw_recovery_center_down_guard;
DROP TABLE inactive_member_recovery_messages;
DROP TABLE inactive_member_recovery_evaluations;
DROP TABLE inactive_member_recovery_runs;
DROP TABLE inactive_member_recovery_member_state;
DROP TABLE inactive_member_recovery_settings;
ALTER TABLE inactive_member_recovery_deliveries
 DROP FOREIGN KEY fk_recovery_delivery_enrollment,
 DROP INDEX uq_recovery_enrollment_contact,
 DROP INDEX ix_recovery_member_contact,
 DROP CONSTRAINT chk_recovery_contact_number,
 DROP CONSTRAINT chk_recovery_destination_stage,
 DROP COLUMN recovery_enrollment_event_id,
 DROP COLUMN contact_number,
 CHANGE COLUMN destination_stage recovery_stage CHAR(1) NOT NULL,
 ADD UNIQUE KEY uq_inactive_recovery_member_stage(user_id,recovery_stage),
 ADD CONSTRAINT chk_inactive_recovery_stage CHECK(recovery_stage IN('A','B','C','D'));
