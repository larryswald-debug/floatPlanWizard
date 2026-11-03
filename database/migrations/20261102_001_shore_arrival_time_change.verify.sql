-- Read-only postcondition.
-- Use the explicitly selected FPW development or fpw production schema.
SELECT IF(COUNT(*)=1, MAX(LOWER(REPLACE(REPLACE(REPLACE(REPLACE(cc.CHECK_CLAUSE,CHAR(96),''),' ',''),'(',''),')',''))), NULL)
INTO @fpw_change_slot
FROM information_schema.TABLE_CONSTRAINTS tc
JOIN information_schema.CHECK_CONSTRAINTS cc
  ON cc.CONSTRAINT_SCHEMA=tc.CONSTRAINT_SCHEMA AND cc.CONSTRAINT_NAME=tc.CONSTRAINT_NAME
WHERE BINARY DATABASE() IN ('FPW','fpw') AND tc.TABLE_SCHEMA=BINARY DATABASE()
  AND tc.TABLE_NAME='fpw_arrival_notices' AND tc.CONSTRAINT_NAME='ck_arrival_notice_slot'
  AND tc.CONSTRAINT_TYPE='CHECK';

SELECT DATABASE() AS selected_database,
  IF(@fpw_change_slot='slot_noin0,1','PASS','FAIL') AS verify_status,
  IF(@fpw_change_slot='slot_noin0,1','Overdue and time-change notices are supported.',
    'The selected schema does not have the expected two-slot constraint.') AS detail;
