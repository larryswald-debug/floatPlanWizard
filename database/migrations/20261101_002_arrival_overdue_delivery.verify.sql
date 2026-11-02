-- Read-only postcondition verification. May also run after observation/capture testing.
SELECT DATABASE() AS selected_database, VERSION() AS database_version;
SELECT COUNT(*) INTO @delivery_tables FROM information_schema.TABLES
WHERE TABLE_SCHEMA=BINARY DATABASE() AND TABLE_NAME IN ('fpw_arrival_dispatch_control', 'fpw_arrival_notices', 'fpw_arrival_deliveries', 'fpw_arrival_attempts') AND ENGINE='InnoDB';

SELECT COUNT(*) INTO @delivery_column_sets FROM (
  SELECT TABLE_NAME,GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION) AS cols
  FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=BINARY DATABASE() AND TABLE_NAME IN ('fpw_arrival_dispatch_control', 'fpw_arrival_notices', 'fpw_arrival_deliveries', 'fpw_arrival_attempts')
  GROUP BY TABLE_NAME
) AS actual
WHERE (TABLE_NAME='fpw_arrival_dispatch_control' AND cols='plan_id,mode,activated_at_utc,generation,updated_at_utc')
   OR (TABLE_NAME='fpw_arrival_notices' AND cols='id,revision_id,slot_no,plan_id,state,reason,recipient_count,invalid_count,created_at_utc')
   OR (TABLE_NAME='fpw_arrival_deliveries' AND cols='id,notice_id,recipient_key,state,attempt_count,generation,scope_generation,next_attempt_utc,lease_until_utc,claim_token,submitted_at_utc,reason,created_at_utc,updated_at_utc')
   OR (TABLE_NAME='fpw_arrival_attempts' AND cols='id,delivery_id,attempt_no,status,started_at_utc,finished_at_utc,reason');

SELECT COUNT(*) INTO @delivery_indexes FROM (
  SELECT TABLE_NAME,INDEX_NAME,NON_UNIQUE,GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS cols
  FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=BINARY DATABASE() AND TABLE_NAME IN ('fpw_arrival_dispatch_control', 'fpw_arrival_notices', 'fpw_arrival_deliveries', 'fpw_arrival_attempts')
  GROUP BY TABLE_NAME,INDEX_NAME,NON_UNIQUE
) AS actual
WHERE (TABLE_NAME='fpw_arrival_dispatch_control' AND INDEX_NAME='PRIMARY' AND cols='plan_id')
   OR (TABLE_NAME IN ('fpw_arrival_notices','fpw_arrival_deliveries','fpw_arrival_attempts') AND INDEX_NAME='PRIMARY' AND cols='id')
   OR (TABLE_NAME='fpw_arrival_notices' AND INDEX_NAME='uq_arrival_notice_slot' AND NON_UNIQUE=0 AND cols='revision_id,slot_no')
   OR (TABLE_NAME='fpw_arrival_notices' AND INDEX_NAME='ix_arrival_notices_plan' AND cols='plan_id,id')
   OR (TABLE_NAME='fpw_arrival_deliveries' AND INDEX_NAME='uq_arrival_notice_recipient' AND NON_UNIQUE=0 AND cols='notice_id,recipient_key')
   OR (TABLE_NAME='fpw_arrival_deliveries' AND INDEX_NAME='ix_arrival_delivery_due' AND cols='state,next_attempt_utc,id')
   OR (TABLE_NAME='fpw_arrival_deliveries' AND INDEX_NAME='ix_arrival_delivery_lease' AND cols='state,lease_until_utc,id')
   OR (TABLE_NAME='fpw_arrival_attempts' AND INDEX_NAME='uq_arrival_attempt_no' AND NON_UNIQUE=0 AND cols='delivery_id,attempt_no');

SELECT COUNT(*) INTO @delivery_fks FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA=BINARY DATABASE() AND UPDATE_RULE='RESTRICT' AND DELETE_RULE='RESTRICT' AND (
    (TABLE_NAME='fpw_arrival_notices' AND CONSTRAINT_NAME='fk_arrival_notice_revision' AND REFERENCED_TABLE_NAME='fpw_arrival_revisions')
 OR (TABLE_NAME='fpw_arrival_deliveries' AND CONSTRAINT_NAME='fk_arrival_delivery_notice' AND REFERENCED_TABLE_NAME='fpw_arrival_notices')
 OR (TABLE_NAME='fpw_arrival_attempts' AND CONSTRAINT_NAME='fk_arrival_attempt_delivery' AND REFERENCED_TABLE_NAME='fpw_arrival_deliveries'));

SELECT COUNT(*) INTO @delivery_checks FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA=BINARY DATABASE() AND TABLE_NAME IN ('fpw_arrival_dispatch_control', 'fpw_arrival_notices', 'fpw_arrival_deliveries', 'fpw_arrival_attempts') AND CONSTRAINT_TYPE='CHECK'
  AND CONSTRAINT_NAME IN ('ck_arrival_control_scope','ck_arrival_control_activation','ck_arrival_control_generation',
   'ck_arrival_notice_slot','ck_arrival_notice_state','ck_arrival_notice_counts','ck_arrival_notice_reason',
   'ck_arrival_delivery_key','ck_arrival_delivery_state','ck_arrival_delivery_attempts',
   'ck_arrival_delivery_generation','ck_arrival_delivery_reason','ck_arrival_attempt_no',
   'ck_arrival_attempt_status','ck_arrival_attempt_reason');

SELECT COUNT(*) INTO @delivery_triggers FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA=BINARY DATABASE() AND ACTION_TIMING='BEFORE' AND (
    (EVENT_OBJECT_TABLE='fpw_arrival_dispatch_control' AND TRIGGER_NAME='fpw_arrival_control_start' AND EVENT_MANIPULATION='INSERT')
 OR (EVENT_OBJECT_TABLE='fpw_arrival_dispatch_control' AND TRIGGER_NAME='fpw_arrival_control_generation' AND EVENT_MANIPULATION='UPDATE')
 OR (EVENT_OBJECT_TABLE='fpw_arrival_dispatch_control' AND TRIGGER_NAME='fpw_arrival_control_keep' AND EVENT_MANIPULATION='DELETE')
 OR (EVENT_OBJECT_TABLE='fpw_arrival_notices' AND TRIGGER_NAME='fpw_arrival_notice_binding' AND EVENT_MANIPULATION='INSERT')
 OR (EVENT_OBJECT_TABLE='fpw_arrival_notices' AND TRIGGER_NAME='fpw_arrival_notice_identity' AND EVENT_MANIPULATION='UPDATE'));

SELECT COUNT(*) INTO @delivery_datetimes FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=BINARY DATABASE() AND TABLE_NAME IN ('fpw_arrival_dispatch_control', 'fpw_arrival_notices', 'fpw_arrival_deliveries', 'fpw_arrival_attempts') AND DATA_TYPE='datetime' AND DATETIME_PRECISION=6;
SELECT COUNT(*) INTO @delivery_global FROM fpw_arrival_dispatch_control WHERE plan_id=0;

SET @delivery_error = CASE
  WHEN DATABASE() IS NULL OR BINARY DATABASE() NOT IN ('FPW', 'fpw') THEN 'Select the FPW or fpw database explicitly.'
  WHEN @delivery_tables<>4 OR @delivery_column_sets<>4 OR @delivery_datetimes<>10 THEN 'Invalid delivery tables or columns.'
  WHEN @delivery_indexes<>10 OR @delivery_fks<>3 OR @delivery_checks<>15 THEN 'Invalid delivery indexes or constraints.'
  WHEN @delivery_triggers<>5 OR @delivery_global<>1 THEN 'Missing dispatch control or immutability guard.'
  ELSE NULL
END;
SELECT IF(@delivery_error IS NULL,'PASS','FAIL') AS verification_status, @delivery_error AS verification_error,
  @delivery_tables AS tables_verified,@delivery_column_sets AS column_sets,@delivery_indexes AS indexes_verified,
  @delivery_datetimes AS utc_datetime_columns,@delivery_checks AS checks_verified,
  @delivery_fks AS foreign_keys_verified,@delivery_triggers AS triggers_verified;
SELECT @delivery_error AS refusal_reason;
SET @delivery_sql = IF(@delivery_error IS NULL, 'DO 0',
    'SELECT `_fpw_delivery_verify_refused` FROM (SELECT 1 AS ok) AS fpw_guard');
PREPARE fpw_delivery_guard FROM @delivery_sql;
EXECUTE fpw_delivery_guard;
DEALLOCATE PREPARE fpw_delivery_guard;
