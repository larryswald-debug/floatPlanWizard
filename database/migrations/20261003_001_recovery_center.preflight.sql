-- Run while the recovery task and any manual processor invocations are stopped.
SELECT DATABASE() AS database_name,VERSION() AS server_version,UTC_TIMESTAMP(6) AS checked_at_utc;
SELECT COUNT(*) AS delivery_rows_must_be_zero FROM inactive_member_recovery_deliveries;
SELECT COUNT(*) AS raw_enrollment_population FROM product_events WHERE event_name='inactive_member_recovery_enrolled';
SELECT COLUMN_NAME,COLUMN_TYPE,IS_NULLABLE FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='inactive_member_recovery_deliveries' ORDER BY ORDINAL_POSITION;
SELECT INDEX_NAME,COLUMN_NAME,SEQ_IN_INDEX FROM information_schema.STATISTICS
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='inactive_member_recovery_deliveries' ORDER BY INDEX_NAME,SEQ_IN_INDEX;
-- Before a fresh/full retry: the following support-table and routine results must be empty.
SELECT TABLE_NAME,ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN (
 'inactive_member_recovery_settings','inactive_member_recovery_member_state','inactive_member_recovery_runs',
 'inactive_member_recovery_evaluations','inactive_member_recovery_messages') ORDER BY TABLE_NAME;
SELECT ROUTINE_NAME,ROUTINE_TYPE FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE()
 AND ROUTINE_NAME IN ('fpw_recovery_center_guard','fpw_recovery_center_down_guard') ORDER BY ROUTINE_NAME;
-- Original stage column, unique index and CHECK must still exist; new contact columns must be absent.
SELECT CONSTRAINT_NAME,CONSTRAINT_TYPE FROM information_schema.TABLE_CONSTRAINTS
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='inactive_member_recovery_deliveries' ORDER BY CONSTRAINT_NAME;
-- If any expected condition differs, stop and inspect; do not delete history or bypass with IF NOT EXISTS.
-- This read-only preflight is not a substitute for the mandatory executable empty-ledger guard in .up.sql.
