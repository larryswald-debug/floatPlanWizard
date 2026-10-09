-- Read-only exact tracking schema verification. Never use --force; a FAIL stops the client.
SET @fpw_tracking_verify_error = CASE
  WHEN DATABASE() IS NULL OR CAST(LOWER(DATABASE()) AS BINARY) <> CAST('fpw' AS BINARY)
    THEN 'Selected database must be FPW (case-insensitive).'
  WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE()
        AND TABLE_NAME IN ('companion_tracking_sessions','companion_location_samples') AND ENGINE='InnoDB' AND TABLE_TYPE='BASE TABLE') <> 2
    THEN 'Both tracking InnoDB tables are required.'
  ELSE NULL END;

SET @fpw_tracking_verify_error = COALESCE(@fpw_tracking_verify_error,
  IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='companion_tracking_sessions') = 20
  AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='companion_tracking_sessions' AND (
    (COLUMN_NAME='id' AND DATA_TYPE='bigint' AND IS_NULLABLE='NO' AND LOWER(COLUMN_TYPE) LIKE '%unsigned%' AND EXTRA='auto_increment') OR
    (COLUMN_NAME='client_session_id' AND COLUMN_TYPE='char(36)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin') OR
    (COLUMN_NAME='user_id' AND DATA_TYPE='int' AND IS_NULLABLE='NO' AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%') OR
    (COLUMN_NAME='companion_device_id' AND DATA_TYPE='bigint' AND IS_NULLABLE='NO' AND LOWER(COLUMN_TYPE) LIKE '%unsigned%') OR
    (COLUMN_NAME='floatplan_id' AND DATA_TYPE='int' AND IS_NULLABLE='NO' AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%') OR
    (COLUMN_NAME='route_instance_id' AND DATA_TYPE='int' AND IS_NULLABLE='NO' AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%') OR
    (COLUMN_NAME='status' AND COLUMN_TYPE='enum(''ACTIVE'',''DRAINING'',''CLOSED'')' AND IS_NULLABLE='NO') OR
    (COLUMN_NAME='started_at_utc' AND COLUMN_TYPE='datetime(3)' AND IS_NULLABLE='NO') OR
    (COLUMN_NAME='capture_stopped_at_utc' AND COLUMN_TYPE='datetime(3)' AND IS_NULLABLE='YES') OR
    (COLUMN_NAME='closed_at_utc' AND COLUMN_TYPE='datetime(3)' AND IS_NULLABLE='YES') OR
    (COLUMN_NAME='stop_reason' AND COLUMN_TYPE='varchar(64)' AND IS_NULLABLE='YES') OR
    (COLUMN_NAME='authorization_valid_until_utc' AND COLUMN_TYPE='datetime(3)' AND IS_NULLABLE='NO') OR
    (COLUMN_NAME='drain_until_utc' AND COLUMN_TYPE='datetime(3)' AND IS_NULLABLE='YES') OR
    (COLUMN_NAME='last_sample_captured_at_utc' AND COLUMN_TYPE='datetime(3)' AND IS_NULLABLE='YES') OR
    (COLUMN_NAME='last_received_at_utc' AND COLUMN_TYPE='datetime(3)' AND IS_NULLABLE='YES') OR
    (COLUMN_NAME='consent_version' AND COLUMN_TYPE='varchar(64)' AND IS_NULLABLE='NO') OR
    (COLUMN_NAME='created_utc' AND COLUMN_TYPE='datetime(3)' AND IS_NULLABLE='NO') OR
    (COLUMN_NAME='updated_utc' AND COLUMN_TYPE='datetime(3)' AND IS_NULLABLE='NO') OR
    (COLUMN_NAME='active_device_id' AND DATA_TYPE='bigint' AND IS_NULLABLE='YES' AND LOWER(COLUMN_TYPE) LIKE '%unsigned%' AND EXTRA='VIRTUAL GENERATED' AND LOWER(GENERATION_EXPRESSION) LIKE '%companion_device_id%' AND LOWER(GENERATION_EXPRESSION) LIKE '%active%' AND LOWER(GENERATION_EXPRESSION) LIKE '%null%') OR
    (COLUMN_NAME='active_floatplan_id' AND DATA_TYPE='int' AND IS_NULLABLE='YES' AND LOWER(COLUMN_TYPE) NOT LIKE '%unsigned%' AND EXTRA='VIRTUAL GENERATED' AND LOWER(GENERATION_EXPRESSION) LIKE '%floatplan_id%' AND LOWER(GENERATION_EXPRESSION) LIKE '%active%' AND LOWER(GENERATION_EXPRESSION) LIKE '%null%')
  )) = 20, NULL, 'companion_tracking_sessions column contract failed.'));

SET @fpw_tracking_verify_error = COALESCE(@fpw_tracking_verify_error,
  IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='companion_location_samples') = 11
  AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='companion_location_samples' AND (
    (COLUMN_NAME='id' AND DATA_TYPE='bigint' AND IS_NULLABLE='NO' AND LOWER(COLUMN_TYPE) LIKE '%unsigned%' AND EXTRA='auto_increment') OR
    (COLUMN_NAME='tracking_session_id' AND DATA_TYPE='bigint' AND IS_NULLABLE='NO' AND LOWER(COLUMN_TYPE) LIKE '%unsigned%') OR
    (COLUMN_NAME='client_sample_id' AND COLUMN_TYPE='char(36)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin') OR
    (COLUMN_NAME='latitude' AND COLUMN_TYPE='decimal(10,7)' AND IS_NULLABLE='NO') OR
    (COLUMN_NAME='longitude' AND COLUMN_TYPE='decimal(10,7)' AND IS_NULLABLE='NO') OR
    (COLUMN_NAME='accuracy_meters' AND COLUMN_TYPE='decimal(8,3)' AND IS_NULLABLE='NO') OR
    (COLUMN_NAME='speed_knots' AND COLUMN_TYPE='decimal(8,3)' AND IS_NULLABLE='YES') OR
    (COLUMN_NAME='course_degrees' AND COLUMN_TYPE='decimal(7,3)' AND IS_NULLABLE='YES') OR
    (COLUMN_NAME='captured_at_utc' AND COLUMN_TYPE='datetime(3)' AND IS_NULLABLE='NO') OR
    (COLUMN_NAME='received_at_utc' AND COLUMN_TYPE='datetime(3)' AND IS_NULLABLE='NO') OR
    (COLUMN_NAME='payload_hash' AND COLUMN_TYPE='char(64)' AND IS_NULLABLE='NO' AND COLLATION_NAME='ascii_bin')
  )) = 11, NULL, 'companion_location_samples column contract failed.'));

SET @fpw_tracking_verify_error = COALESCE(@fpw_tracking_verify_error,
  IF((SELECT COUNT(*) FROM (
    SELECT INDEX_NAME, NON_UNIQUE, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',') AS indexed_columns
    FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='companion_tracking_sessions'
    GROUP BY INDEX_NAME, NON_UNIQUE
  ) AS expected_indexes WHERE (
    (INDEX_NAME='PRIMARY' AND NON_UNIQUE=0 AND indexed_columns='id') OR
    (INDEX_NAME='uq_cts_device_client' AND NON_UNIQUE=0 AND indexed_columns='companion_device_id,client_session_id') OR
    (INDEX_NAME='uq_cts_active_device' AND NON_UNIQUE=0 AND indexed_columns='active_device_id') OR
    (INDEX_NAME='uq_cts_active_trip' AND NON_UNIQUE=0 AND indexed_columns='active_floatplan_id') OR
    (INDEX_NAME='ix_cts_user_trip' AND NON_UNIQUE=1 AND indexed_columns='user_id,floatplan_id,started_at_utc,id') OR
    (INDEX_NAME='ix_cts_floatplan' AND NON_UNIQUE=1 AND indexed_columns='floatplan_id') OR
    (INDEX_NAME='ix_cts_route' AND NON_UNIQUE=1 AND indexed_columns='route_instance_id') OR
    (INDEX_NAME='ix_cts_expiration' AND NON_UNIQUE=1 AND indexed_columns='status,authorization_valid_until_utc,id') OR
    (INDEX_NAME='ix_cts_drain' AND NON_UNIQUE=1 AND indexed_columns='status,drain_until_utc,id') OR
    (INDEX_NAME='ix_cts_retention' AND NON_UNIQUE=1 AND indexed_columns='status,closed_at_utc,id') OR
    (INDEX_NAME='ix_cts_reconcile' AND NON_UNIQUE=1 AND indexed_columns='status,updated_utc,id')
  )) = 11, NULL, 'companion_tracking_sessions index contract failed.'));

SET @fpw_tracking_verify_error = COALESCE(@fpw_tracking_verify_error,
  IF((SELECT COUNT(*) FROM (
    SELECT INDEX_NAME, NON_UNIQUE, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',') AS indexed_columns
    FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='companion_location_samples'
    GROUP BY INDEX_NAME, NON_UNIQUE
  ) AS expected_indexes WHERE (
    (INDEX_NAME='PRIMARY' AND NON_UNIQUE=0 AND indexed_columns='id') OR
    (INDEX_NAME='uq_cls_session_sample' AND NON_UNIQUE=0 AND indexed_columns='tracking_session_id,client_sample_id') OR
    (INDEX_NAME='ix_cls_latest' AND NON_UNIQUE=1 AND indexed_columns='tracking_session_id,captured_at_utc,id') OR
    (INDEX_NAME='ix_cls_retention' AND NON_UNIQUE=1 AND indexed_columns='captured_at_utc,id')
  )) = 4, NULL, 'companion_location_samples index contract failed.'));

SET @fpw_tracking_verify_error = COALESCE(@fpw_tracking_verify_error,
  IF((SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE k
    JOIN information_schema.REFERENTIAL_CONSTRAINTS r ON r.CONSTRAINT_SCHEMA=k.CONSTRAINT_SCHEMA
      AND r.TABLE_NAME=k.TABLE_NAME AND r.CONSTRAINT_NAME=k.CONSTRAINT_NAME
    WHERE k.CONSTRAINT_SCHEMA=DATABASE() AND k.REFERENCED_TABLE_SCHEMA=DATABASE()
      AND r.DELETE_RULE='CASCADE' AND r.UPDATE_RULE IN ('RESTRICT','NO ACTION') AND (
    (k.TABLE_NAME='companion_tracking_sessions' AND k.CONSTRAINT_NAME='fk_cts_user' AND k.COLUMN_NAME='user_id' AND k.REFERENCED_TABLE_NAME='users' AND k.REFERENCED_COLUMN_NAME='userId') OR
    (k.TABLE_NAME='companion_tracking_sessions' AND k.CONSTRAINT_NAME='fk_cts_device' AND k.COLUMN_NAME='companion_device_id' AND k.REFERENCED_TABLE_NAME='companion_devices' AND k.REFERENCED_COLUMN_NAME='id') OR
    (k.TABLE_NAME='companion_tracking_sessions' AND k.CONSTRAINT_NAME='fk_cts_floatplan' AND k.COLUMN_NAME='floatplan_id' AND k.REFERENCED_TABLE_NAME='floatplans' AND k.REFERENCED_COLUMN_NAME='floatPlanId') OR
    (k.TABLE_NAME='companion_tracking_sessions' AND k.CONSTRAINT_NAME='fk_cts_route' AND k.COLUMN_NAME='route_instance_id' AND k.REFERENCED_TABLE_NAME='route_instances' AND k.REFERENCED_COLUMN_NAME='id') OR
    (k.TABLE_NAME='companion_location_samples' AND k.CONSTRAINT_NAME='fk_cls_session' AND k.COLUMN_NAME='tracking_session_id' AND k.REFERENCED_TABLE_NAME='companion_tracking_sessions' AND k.REFERENCED_COLUMN_NAME='id')
    )) = 5, NULL, 'Tracking foreign key binding/cascade contract failed.'));
SET @fpw_tracking_verify_error = COALESCE(@fpw_tracking_verify_error,
  IF((SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE()
      AND CONSTRAINT_TYPE='CHECK' AND ((TABLE_NAME='companion_tracking_sessions'
        AND CONSTRAINT_NAME IN ('chk_cts_status','chk_cts_authorization','chk_cts_lifecycle'))
      OR (TABLE_NAME='companion_location_samples'
        AND CONSTRAINT_NAME IN ('chk_cls_latitude','chk_cls_longitude','chk_cls_accuracy','chk_cls_speed','chk_cls_course')))) = 8,
    NULL, 'Tracking CHECK constraint contract failed.'));
SELECT DATABASE() AS selected_database, VERSION() AS database_version,
  IF(@fpw_tracking_verify_error IS NULL, 'PASS', 'FAIL') AS verify_status;
SELECT @fpw_tracking_verify_error AS migration_error;
SET @fpw_tracking_guard_sql = IF(@fpw_tracking_verify_error IS NULL, 'DO 0',
  'SELECT `_fpw_tracking_verify_refused` FROM (SELECT 1 AS ok) AS _fpw_guard');
PREPARE fpw_tracking_guard FROM @fpw_tracking_guard_sql;
EXECUTE fpw_tracking_guard;
DEALLOCATE PREPARE fpw_tracking_guard;

SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, EXTRA, GENERATION_EXPRESSION
FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE()
  AND TABLE_NAME IN ('companion_tracking_sessions','companion_location_samples')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
SELECT TABLE_NAME, INDEX_NAME, NON_UNIQUE, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS indexed_columns
FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE()
  AND TABLE_NAME IN ('companion_tracking_sessions','companion_location_samples')
GROUP BY TABLE_NAME, INDEX_NAME, NON_UNIQUE ORDER BY TABLE_NAME, INDEX_NAME;
SELECT TABLE_NAME, CONSTRAINT_NAME, REFERENCED_TABLE_NAME, DELETE_RULE, UPDATE_RULE
FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE()
  AND TABLE_NAME IN ('companion_tracking_sessions','companion_location_samples')
ORDER BY TABLE_NAME, CONSTRAINT_NAME;
