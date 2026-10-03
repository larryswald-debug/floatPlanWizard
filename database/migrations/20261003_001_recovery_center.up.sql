-- Recovery Center: run ONLY with recovery processing stopped and a verified database backup.
-- DROP CONSTRAINT is supported by MariaDB and MySQL 8.0.19+; locally tested on MySQL 8.0.43.
-- Run with a client that stops on the first SQL error; never continue after a failed guard.
-- Inspect the read-only preflight after any interrupted or failed attempt.
-- The guard deliberately rejects an already-migrated or nonempty ledger.
DELIMITER $$
CREATE PROCEDURE fpw_recovery_center_guard()
BEGIN
 IF (SELECT COUNT(*) FROM inactive_member_recovery_deliveries) <> 0 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='STOP: recovery delivery history exists; no inferred contacts are permitted';
 END IF;
 IF (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='inactive_member_recovery_deliveries' AND COLUMN_NAME='contact_number') <> 0 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='STOP: ledger already transitioned';
 END IF;
 IF (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN (
  'inactive_member_recovery_settings','inactive_member_recovery_member_state','inactive_member_recovery_runs',
  'inactive_member_recovery_evaluations','inactive_member_recovery_messages')) <> 0 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='STOP: recovery support tables already exist; inspect partial migration before continuing';
 END IF;
END$$
DELIMITER ;
CALL fpw_recovery_center_guard();
DROP PROCEDURE fpw_recovery_center_guard;
ALTER TABLE inactive_member_recovery_deliveries
 DROP INDEX uq_inactive_recovery_member_stage,
 DROP CONSTRAINT chk_inactive_recovery_stage,
 CHANGE COLUMN recovery_stage destination_stage CHAR(1) NOT NULL,
 ADD COLUMN recovery_enrollment_event_id BIGINT UNSIGNED NOT NULL AFTER user_id,
 ADD COLUMN contact_number TINYINT UNSIGNED NOT NULL AFTER recovery_enrollment_event_id,
 ADD UNIQUE KEY uq_recovery_enrollment_contact (recovery_enrollment_event_id,contact_number),
 ADD KEY ix_recovery_member_contact (user_id,recovery_enrollment_event_id,contact_number),
 ADD CONSTRAINT chk_recovery_destination_stage CHECK(destination_stage IN('A','B','C','D')),
 ADD CONSTRAINT chk_recovery_contact_number CHECK(contact_number BETWEEN 1 AND 3),
 ADD CONSTRAINT fk_recovery_delivery_enrollment FOREIGN KEY(recovery_enrollment_event_id) REFERENCES product_events(id) ON DELETE RESTRICT ON UPDATE RESTRICT;

CREATE TABLE inactive_member_recovery_settings (
 id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
 revision INT UNSIGNED NOT NULL DEFAULT 1,
 first_delay_hours INT UNSIGNED NOT NULL DEFAULT 24,
 stage_interval_hours INT UNSIGNED NOT NULL DEFAULT 24,
 attribution_window_hours INT UNSIGNED NOT NULL DEFAULT 24,
 updated_at_utc DATETIME(6) NOT NULL,
 changed_by INT NULL,
 reset_at_utc DATETIME(6) NULL,
 reset_admin_user_id INT NULL,
 reset_cohort_count INT UNSIGNED NOT NULL DEFAULT 0,
 reset_operation_id CHAR(36) NULL,
 CONSTRAINT chk_recovery_settings_singleton CHECK(id=1),
 CONSTRAINT chk_recovery_first_delay CHECK(first_delay_hours BETWEEN 1 AND 720),
 CONSTRAINT chk_recovery_interval CHECK(stage_interval_hours BETWEEN 1 AND 720),
 CONSTRAINT chk_recovery_attribution CHECK(attribution_window_hours BETWEEN 1 AND 720)
) ENGINE=InnoDB;
INSERT INTO inactive_member_recovery_settings(id,updated_at_utc) VALUES(1,UTC_TIMESTAMP(6));

CREATE TABLE inactive_member_recovery_member_state (
 user_id INT NOT NULL PRIMARY KEY,
 recovery_enrollment_event_id BIGINT UNSIGNED NOT NULL,
 recovery_start_at_utc DATETIME(6) NULL,
 paused TINYINT UNSIGNED NOT NULL DEFAULT 0,
 excluded TINYINT UNSIGNED NOT NULL DEFAULT 0,
 revision INT UNSIGNED NOT NULL DEFAULT 1,
 updated_at_utc DATETIME(6) NOT NULL,
 updated_by INT NULL,
 reset_operation_id CHAR(36) NULL,
 CONSTRAINT fk_recovery_state_user FOREIGN KEY(user_id) REFERENCES users(userId) ON DELETE CASCADE,
 CONSTRAINT fk_recovery_state_enrollment FOREIGN KEY(recovery_enrollment_event_id) REFERENCES product_events(id) ON DELETE RESTRICT,
 CONSTRAINT chk_recovery_state_flags CHECK(paused IN(0,1) AND excluded IN(0,1))
) ENGINE=InnoDB;

CREATE TABLE inactive_member_recovery_runs (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 run_uuid CHAR(36) NOT NULL,
 execution_source VARCHAR(32) NOT NULL,
 dry_run TINYINT NOT NULL,
 started_at_utc DATETIME(6) NOT NULL,
 completed_at_utc DATETIME(6) NULL,
 status VARCHAR(32) NOT NULL,
 settings_revision INT UNSIGNED NULL,
 settings_json JSON NULL,
 evaluated_count INT UNSIGNED NOT NULL DEFAULT 0,
 eligible_count INT UNSIGNED NOT NULL DEFAULT 0,
 accepted_count INT UNSIGNED NOT NULL DEFAULT 0,
 failed_count INT UNSIGNED NOT NULL DEFAULT 0,
 held_count INT UNSIGNED NOT NULL DEFAULT 0,
 waiting_count INT UNSIGNED NOT NULL DEFAULT 0,
 suppressed_count INT UNSIGNED NOT NULL DEFAULT 0,
 attempted_count INT UNSIGNED NOT NULL DEFAULT 0,
 error_code VARCHAR(80) NULL,
 UNIQUE KEY uq_recovery_run_uuid(run_uuid),
 KEY ix_recovery_runs_time(started_at_utc,id)
) ENGINE=InnoDB;

CREATE TABLE inactive_member_recovery_evaluations (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 run_id BIGINT UNSIGNED NOT NULL,
 user_id INT NOT NULL,
 recovery_enrollment_event_id BIGINT UNSIGNED NULL,
 contact_number TINYINT UNSIGNED NULL,
 contact_total TINYINT UNSIGNED NOT NULL DEFAULT 3,
 destination_stage CHAR(1) NULL,
 destination_type VARCHAR(40) NULL,
 destination_id BIGINT UNSIGNED NULL,
 template_id VARCHAR(100) NULL,
 template_version VARCHAR(16) NULL,
 transport_attempt_number INT UNSIGNED NULL,
 initial_decision VARCHAR(40) NOT NULL,
 initial_reason VARCHAR(100) NOT NULL,
 initial_eligible TINYINT NOT NULL DEFAULT 0,
 final_decision VARCHAR(40) NULL,
 final_reason VARCHAR(100) NULL,
 evaluated_at_utc DATETIME(6) NOT NULL,
 finalized_at_utc DATETIME(6) NULL,
 eligible_at_utc DATETIME(6) NULL,
 context_json JSON NULL,
 message_id BIGINT UNSIGNED NULL,
 KEY ix_recovery_evaluation_run(run_id,id),
 KEY ix_recovery_evaluation_member(user_id,evaluated_at_utc,id),
 KEY ix_recovery_evaluation_decision(initial_decision,evaluated_at_utc),
 CONSTRAINT fk_recovery_evaluation_run FOREIGN KEY(run_id) REFERENCES inactive_member_recovery_runs(id) ON DELETE RESTRICT,
 CONSTRAINT fk_recovery_evaluation_user FOREIGN KEY(user_id) REFERENCES users(userId) ON DELETE CASCADE,
 CONSTRAINT chk_recovery_evaluation_contact CHECK(contact_number IS NULL OR contact_number BETWEEN 1 AND 3)
) ENGINE=InnoDB;

CREATE TABLE inactive_member_recovery_messages (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 run_id BIGINT UNSIGNED NULL,
 evaluation_id BIGINT UNSIGNED NULL,
 delivery_id BIGINT UNSIGNED NULL,
 user_id INT NOT NULL,
 recovery_enrollment_event_id BIGINT UNSIGNED NULL,
 message_kind VARCHAR(16) NOT NULL,
 contact_number TINYINT UNSIGNED NULL,
 contact_total TINYINT UNSIGNED NOT NULL DEFAULT 3,
 destination_stage CHAR(1) NULL,
 destination_type VARCHAR(40) NULL,
 destination_id BIGINT UNSIGNED NULL,
 destination_path VARCHAR(500) NULL,
 template_id VARCHAR(100) NOT NULL,
 template_version VARCHAR(16) NOT NULL,
 transport_attempt_number INT UNSIGNED NULL,
 administrator_id INT NULL,
 submission_identity VARCHAR(100) NULL,
 subject VARCHAR(255) NOT NULL,
 recipient VARCHAR(254) NOT NULL,
 text_body MEDIUMTEXT NOT NULL,
 html_body MEDIUMTEXT NOT NULL,
 cta_label VARCHAR(100) NULL,
 status VARCHAR(32) NOT NULL,
 prepared_at_utc DATETIME(6) NOT NULL,
 accepted_at_utc DATETIME(6) NULL,
 finalized_at_utc DATETIME(6) NULL,
 attribution_window_hours INT UNSIGNED NULL,
 attribution_deadline_utc DATETIME(6) NULL,
 public_id CHAR(64) NULL,
 signing_secret CHAR(64) NULL,
 first_open_at_utc DATETIME(6) NULL,
 latest_open_at_utc DATETIME(6) NULL,
 first_click_at_utc DATETIME(6) NULL,
 latest_click_at_utc DATETIME(6) NULL,
 open_count INT UNSIGNED NOT NULL DEFAULT 0,
 click_count INT UNSIGNED NOT NULL DEFAULT 0,
 late_open_count INT UNSIGNED NOT NULL DEFAULT 0,
 late_click_count INT UNSIGNED NOT NULL DEFAULT 0,
 returned_at_utc DATETIME(6) NULL,
 engaged_at_utc DATETIME(6) NULL,
 return_source_event_id BIGINT UNSIGNED NULL,
 engagement_source_event_id BIGINT UNSIGNED NULL,
 UNIQUE KEY uq_recovery_message_submission(submission_identity),
 UNIQUE KEY uq_recovery_message_attempt(delivery_id,transport_attempt_number),
 UNIQUE KEY uq_recovery_message_public(public_id),
 KEY ix_recovery_message_member(user_id,accepted_at_utc,id),
 KEY ix_recovery_message_performance(message_kind,contact_number,destination_stage,accepted_at_utc),
 KEY ix_recovery_message_reconciliation(status,attribution_deadline_utc,id),
 CONSTRAINT fk_recovery_message_user FOREIGN KEY(user_id) REFERENCES users(userId) ON DELETE CASCADE,
 CONSTRAINT fk_recovery_message_run FOREIGN KEY(run_id) REFERENCES inactive_member_recovery_runs(id) ON DELETE RESTRICT,
 CONSTRAINT fk_recovery_message_evaluation FOREIGN KEY(evaluation_id) REFERENCES inactive_member_recovery_evaluations(id) ON DELETE RESTRICT,
 CONSTRAINT chk_recovery_message_kind CHECK(message_kind IN('AUTOMATED','PERSONAL')),
 CONSTRAINT chk_recovery_message_contact CHECK((message_kind='AUTOMATED' AND contact_number BETWEEN 1 AND 3) OR (message_kind='PERSONAL' AND contact_number IS NULL)),
 CONSTRAINT chk_recovery_message_status CHECK(status IN('PREPARED','SEND_ACCEPTED','SEND_FAILED','OUTCOME_UNKNOWN','CANCELED'))
) ENGINE=InnoDB;
