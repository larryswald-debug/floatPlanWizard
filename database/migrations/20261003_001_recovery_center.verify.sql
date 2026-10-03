SELECT TABLE_NAME,ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME LIKE 'inactive_member_recovery_%';
SELECT id,revision,first_delay_hours,stage_interval_hours,attribution_window_hours,reset_at_utc,reset_cohort_count
 FROM inactive_member_recovery_settings;
SELECT INDEX_NAME,COLUMN_NAME,SEQ_IN_INDEX FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE()
 AND TABLE_NAME IN ('inactive_member_recovery_deliveries','inactive_member_recovery_messages') ORDER BY TABLE_NAME,INDEX_NAME,SEQ_IN_INDEX;
SELECT COUNT(*) AS invalid_contact_rows FROM inactive_member_recovery_deliveries WHERE contact_number NOT BETWEEN 1 AND 3 OR destination_stage NOT IN('A','B','C','D');
SELECT COUNT(*) AS wrong_enrollment_owner FROM inactive_member_recovery_deliveries d LEFT JOIN product_events e ON e.id=d.recovery_enrollment_event_id
 WHERE e.id IS NULL OR e.user_id<>d.user_id OR e.event_name<>'inactive_member_recovery_enrolled';
SELECT recovery_enrollment_event_id,contact_number,COUNT(*) AS duplicates FROM inactive_member_recovery_deliveries
 GROUP BY recovery_enrollment_event_id,contact_number HAVING COUNT(*)>1;
SELECT delivery_id,transport_attempt_number,COUNT(*) AS duplicates FROM inactive_member_recovery_messages
 WHERE delivery_id IS NOT NULL GROUP BY delivery_id,transport_attempt_number HAVING COUNT(*)>1;

SELECT tc.TABLE_NAME,tc.CONSTRAINT_NAME,cc.CHECK_CLAUSE
 FROM information_schema.TABLE_CONSTRAINTS tc
 JOIN information_schema.CHECK_CONSTRAINTS cc ON cc.CONSTRAINT_SCHEMA=tc.CONSTRAINT_SCHEMA AND cc.CONSTRAINT_NAME=tc.CONSTRAINT_NAME
 WHERE tc.TABLE_SCHEMA=DATABASE() AND tc.TABLE_NAME LIKE 'inactive_member_recovery_%' AND tc.CONSTRAINT_TYPE='CHECK'
 ORDER BY tc.TABLE_NAME,tc.CONSTRAINT_NAME;
