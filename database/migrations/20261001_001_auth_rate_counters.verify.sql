-- Select the target fpw database first. Run with a client that stops on the first SQL error; never use --force.
-- No deployment or database execution is implied by this file.
-- SELECT-only verification; returns no stored counter subjects.
SELECT DATABASE() AS selected_database, VERSION() AS database_version;
SELECT TABLE_NAME, ENGINE, TABLE_COLLATION FROM information_schema.TABLES
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='auth_rate_counters';
SELECT COLUMN_NAME,COLUMN_TYPE,IS_NULLABLE,DATETIME_PRECISION,COLLATION_NAME
FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='auth_rate_counters' ORDER BY ORDINAL_POSITION;
SELECT INDEX_NAME,NON_UNIQUE,SEQ_IN_INDEX,COLUMN_NAME
FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='auth_rate_counters' ORDER BY INDEX_NAME,SEQ_IN_INDEX;
SELECT CASE WHEN
 (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='auth_rate_counters' AND ENGINE='InnoDB')=1
 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='auth_rate_counters'
   AND COLUMN_NAME IN ('action_group','subject_scope','subject_hash','window_started_at_utc','expires_at_utc','admitted_count','failure_count','inflight_count')
   AND IS_NULLABLE='NO')=8
 AND (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='auth_rate_counters' AND INDEX_NAME='PRIMARY')=3
 AND (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='auth_rate_counters' AND INDEX_NAME='PRIMARY'
   AND ((SEQ_IN_INDEX=1 AND COLUMN_NAME='action_group') OR (SEQ_IN_INDEX=2 AND COLUMN_NAME='subject_scope') OR (SEQ_IN_INDEX=3 AND COLUMN_NAME='subject_hash')))=3
 AND (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='auth_rate_counters'
   AND INDEX_NAME='ix_auth_rate_expiry' AND COLUMN_NAME='expires_at_utc')=1
 THEN 'PASS' ELSE 'FAIL' END AS schema_status;
