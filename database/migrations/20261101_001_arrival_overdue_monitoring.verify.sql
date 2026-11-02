-- Read-only contract verification; supports both an unused and an observing install.
SELECT DATABASE() AS selected_database, VERSION() AS database_version;

SELECT COUNT(*) INTO @arrival_tables
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = BINARY DATABASE() AND ENGINE = 'InnoDB' AND TABLE_NAME IN ('fpw_arrival_rollout', 'fpw_arrival_watches', 'fpw_arrival_revisions', 'fpw_arrival_events');

SELECT COUNT(*) INTO @arrival_column_sets
FROM (
  SELECT TABLE_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION) AS cols
  FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = BINARY DATABASE() AND TABLE_NAME IN ('fpw_arrival_rollout', 'fpw_arrival_watches', 'fpw_arrival_revisions', 'fpw_arrival_events')
  GROUP BY TABLE_NAME
) AS actual
WHERE (TABLE_NAME = 'fpw_arrival_rollout' AND cols = 'id,mode,cutoff_utc,created_at_utc')
   OR (TABLE_NAME = 'fpw_arrival_watches' AND cols = 'plan_id,owner_id,current_revision,terminal_reason,terminal_at_utc,created_at_utc,updated_at_utc')
   OR (TABLE_NAME = 'fpw_arrival_revisions' AND cols = 'id,plan_id,revision_no,deadline_utc,deadline_zone,source,actor_user_id,historical_only,state,initial_due_utc,next_due_utc,last_slot,last_eval_utc,suppression_reason,ended_at_utc,created_at_utc')
   OR (TABLE_NAME = 'fpw_arrival_events' AND cols = 'id,plan_id,revision_no,event_type,event_at_utc,reason,slot_no,skipped_slots,actor_user_id');

SELECT COUNT(*) INTO @arrival_indexes
FROM (
  SELECT TABLE_NAME, INDEX_NAME, NON_UNIQUE, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS cols
  FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = BINARY DATABASE() AND TABLE_NAME IN ('fpw_arrival_rollout', 'fpw_arrival_watches', 'fpw_arrival_revisions', 'fpw_arrival_events')
  GROUP BY TABLE_NAME, INDEX_NAME, NON_UNIQUE
) AS actual
WHERE (TABLE_NAME='fpw_arrival_rollout' AND INDEX_NAME='PRIMARY' AND cols='id')
   OR (TABLE_NAME='fpw_arrival_watches' AND INDEX_NAME='PRIMARY' AND cols='plan_id')
   OR (TABLE_NAME='fpw_arrival_revisions' AND INDEX_NAME='PRIMARY' AND cols='id')
   OR (TABLE_NAME='fpw_arrival_revisions' AND NON_UNIQUE=0 AND INDEX_NAME='uq_arrival_plan_revision' AND cols='plan_id,revision_no')
   OR (TABLE_NAME='fpw_arrival_revisions' AND INDEX_NAME='ix_arrival_due' AND cols='state,next_due_utc,id')
   OR (TABLE_NAME='fpw_arrival_events' AND INDEX_NAME='PRIMARY' AND cols='id')
   OR (TABLE_NAME='fpw_arrival_events' AND INDEX_NAME='ix_arrival_events_plan' AND cols='plan_id,revision_no,id');

SELECT COUNT(*) INTO @arrival_fks FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA=BINARY DATABASE() AND REFERENCED_TABLE_NAME='fpw_arrival_watches'
  AND DELETE_RULE='RESTRICT' AND UPDATE_RULE='RESTRICT'
  AND ((TABLE_NAME='fpw_arrival_revisions' AND CONSTRAINT_NAME='fk_arrival_revision_watch')
    OR (TABLE_NAME='fpw_arrival_events' AND CONSTRAINT_NAME='fk_arrival_event_watch'));

SELECT COUNT(*) INTO @arrival_checks FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA=BINARY DATABASE() AND CONSTRAINT_TYPE='CHECK' AND TABLE_NAME IN ('fpw_arrival_rollout', 'fpw_arrival_watches', 'fpw_arrival_revisions', 'fpw_arrival_events')
  AND CONSTRAINT_NAME IN ('ck_arrival_rollout_single','ck_arrival_rollout_mode','ck_arrival_watch_revision',
    'ck_arrival_revision_seq','ck_arrival_revision_historical','ck_arrival_revision_state',
    'ck_arrival_revision_initial_due','ck_arrival_revision_slot','ck_arrival_event_revision',
    'ck_arrival_event_slot','ck_arrival_event_skipped');

SELECT COUNT(*) INTO @arrival_datetimes FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=BINARY DATABASE() AND TABLE_NAME IN ('fpw_arrival_rollout', 'fpw_arrival_watches', 'fpw_arrival_revisions', 'fpw_arrival_events') AND DATA_TYPE='datetime' AND DATETIME_PRECISION=6;

SELECT COUNT(*) INTO @arrival_triggers FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA=BINARY DATABASE() AND ACTION_TIMING='BEFORE' AND (
    (TRIGGER_NAME='fpw_arrival_rollout_freeze' AND EVENT_OBJECT_TABLE='fpw_arrival_rollout' AND EVENT_MANIPULATION='UPDATE')
 OR (TRIGGER_NAME='fpw_arrival_rollout_keep' AND EVENT_OBJECT_TABLE='fpw_arrival_rollout' AND EVENT_MANIPULATION='DELETE')
 OR (TRIGGER_NAME='fpw_arrival_revision_freeze' AND EVENT_OBJECT_TABLE='fpw_arrival_revisions' AND EVENT_MANIPULATION='UPDATE'));

SELECT COUNT(*) INTO @arrival_baseline FROM fpw_arrival_rollout
WHERE id=1 AND mode IN ('OFF','OBSERVE') AND cutoff_utc=created_at_utc;

SET @arrival_error = CASE
  WHEN DATABASE() IS NULL OR BINARY DATABASE() NOT IN ('FPW', 'fpw') THEN 'Select the FPW or fpw database explicitly.'
  WHEN @arrival_tables <> 4 OR @arrival_column_sets <> 4 OR @arrival_datetimes <> 12 THEN 'Arrival table or column contract mismatch.'
  WHEN @arrival_indexes <> 7 OR @arrival_fks <> 2 OR @arrival_checks <> 11 THEN 'Arrival index or constraint contract mismatch.'
  WHEN @arrival_triggers <> 3 OR @arrival_baseline <> 1 THEN 'Missing arrival immutability guard or rollout record.'
  ELSE NULL
END;
SELECT IF(@arrival_error IS NULL, 'PASS', 'FAIL') AS verification_status,
  @arrival_error AS verification_error, @arrival_tables AS tables_verified,
  @arrival_column_sets AS column_sets, @arrival_indexes AS indexes_verified,
  @arrival_datetimes AS utc_datetime_columns, @arrival_checks AS checks_verified,
  @arrival_fks AS foreign_keys_verified, @arrival_triggers AS immutability_triggers;
SELECT @arrival_error AS refusal_reason;
SET @arrival_guard_sql = IF(@arrival_error IS NULL, 'DO 0',
    'SELECT `_fpw_arrival_verify_refused` FROM (SELECT 1 AS ok) AS fpw_guard');
PREPARE fpw_arrival_guard FROM @arrival_guard_sql;
EXECUTE fpw_arrival_guard;
DEALLOCATE PREPARE fpw_arrival_guard;
