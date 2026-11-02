-- Independent arrival monitoring, Phase 2. No plan backfill, mail or delivery jobs.
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
    'SELECT `_fpw_arrival_up_refused` FROM (SELECT 1 AS ok) AS fpw_guard');
PREPARE fpw_arrival_guard FROM @arrival_guard_sql;
EXECUTE fpw_arrival_guard;
DEALLOCATE PREPARE fpw_arrival_guard;

CREATE TABLE fpw_arrival_rollout (
  id TINYINT UNSIGNED NOT NULL,
  mode VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'OFF',
  cutoff_utc DATETIME(6) NOT NULL,
  created_at_utc DATETIME(6) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT ck_arrival_rollout_single CHECK (id = 1),
  CONSTRAINT ck_arrival_rollout_mode CHECK (mode IN ('OFF','OBSERVE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- The operational plan can be deleted through existing FPW cleanup paths. Keep
-- this identity and history independent of plan deletion or owner reassignment.
CREATE TABLE fpw_arrival_watches (
  plan_id INT NOT NULL,
  owner_id VARCHAR(255) NOT NULL,
  current_revision INT NOT NULL DEFAULT 0,
  terminal_reason VARCHAR(40) NULL,
  terminal_at_utc DATETIME(6) NULL,
  created_at_utc DATETIME(6) NOT NULL,
  updated_at_utc DATETIME(6) NOT NULL,
  PRIMARY KEY (plan_id),
  CONSTRAINT ck_arrival_watch_revision CHECK (current_revision >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE fpw_arrival_revisions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  plan_id INT NOT NULL,
  revision_no INT NOT NULL,
  deadline_utc DATETIME(6) NOT NULL,
  deadline_zone VARCHAR(64) NOT NULL,
  source VARCHAR(48) NOT NULL,
  actor_user_id VARCHAR(255) NULL,
  historical_only TINYINT UNSIGNED NOT NULL,
  state VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  initial_due_utc DATETIME(6) NOT NULL,
  next_due_utc DATETIME(6) NULL,
  last_slot INT NOT NULL DEFAULT -1,
  last_eval_utc DATETIME(6) NULL,
  suppression_reason VARCHAR(48) NULL,
  ended_at_utc DATETIME(6) NULL,
  created_at_utc DATETIME(6) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_arrival_plan_revision (plan_id, revision_no),
  KEY ix_arrival_due (state, next_due_utc, id),
  CONSTRAINT fk_arrival_revision_watch FOREIGN KEY (plan_id) REFERENCES fpw_arrival_watches(plan_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_arrival_revision_seq CHECK (revision_no > 0),
  CONSTRAINT ck_arrival_revision_historical CHECK (historical_only IN (0,1)),
  CONSTRAINT ck_arrival_revision_state CHECK (state IN ('PENDING','OVERDUE','SUPERSEDED','RESOLVED','SUPPRESSED','BLOCKED')),
  CONSTRAINT ck_arrival_revision_initial_due CHECK (initial_due_utc = deadline_utc),
  CONSTRAINT ck_arrival_revision_slot CHECK (last_slot >= -1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Revision zero is reserved for audit events recorded before a usable deadline.
CREATE TABLE fpw_arrival_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  plan_id INT NOT NULL,
  revision_no INT NOT NULL,
  event_type VARCHAR(48) NOT NULL,
  event_at_utc DATETIME(6) NOT NULL,
  reason VARCHAR(48) NULL,
  slot_no INT NULL,
  skipped_slots INT NOT NULL DEFAULT 0,
  actor_user_id VARCHAR(255) NULL,
  PRIMARY KEY (id),
  KEY ix_arrival_events_plan (plan_id, revision_no, id),
  CONSTRAINT fk_arrival_event_watch FOREIGN KEY (plan_id) REFERENCES fpw_arrival_watches(plan_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_arrival_event_revision CHECK (revision_no >= 0),
  CONSTRAINT ck_arrival_event_slot CHECK (slot_no IS NULL OR slot_no >= 0),
  CONSTRAINT ck_arrival_event_skipped CHECK (skipped_slots >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER //
CREATE TRIGGER fpw_arrival_rollout_freeze BEFORE UPDATE ON fpw_arrival_rollout
FOR EACH ROW
BEGIN
  IF NEW.id <> OLD.id OR NEW.cutoff_utc <> OLD.cutoff_utc OR NEW.created_at_utc <> OLD.created_at_utc THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The arrival observation baseline is immutable.';
  END IF;
END//
CREATE TRIGGER fpw_arrival_rollout_keep BEFORE DELETE ON fpw_arrival_rollout
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The arrival observation baseline cannot be deleted.';
END//
CREATE TRIGGER fpw_arrival_revision_freeze BEFORE UPDATE ON fpw_arrival_revisions
FOR EACH ROW
BEGIN
  IF NEW.id <> OLD.id OR NEW.plan_id <> OLD.plan_id OR NEW.revision_no <> OLD.revision_no
      OR NEW.deadline_utc <> OLD.deadline_utc OR BINARY NEW.deadline_zone <> BINARY OLD.deadline_zone
      OR NEW.historical_only <> OLD.historical_only OR NEW.initial_due_utc <> OLD.initial_due_utc
      OR BINARY NEW.source <> BINARY OLD.source OR NOT (BINARY NEW.actor_user_id <=> BINARY OLD.actor_user_id)
      OR NEW.created_at_utc <> OLD.created_at_utc THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Arrival deadline changes require a new revision.';
  END IF;
END//
DELIMITER ;

SET @arrival_baseline_utc = UTC_TIMESTAMP(6);
INSERT INTO fpw_arrival_rollout (id, mode, cutoff_utc, created_at_utc)
VALUES (1, 'OFF', @arrival_baseline_utc, @arrival_baseline_utc);
