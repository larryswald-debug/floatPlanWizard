-- Run after the Phase 3 verifier. Already applied is safe to rerun.
-- Use the explicitly selected FPW development or fpw production schema.
SELECT IF(COUNT(*)=1, MAX(LOWER(REPLACE(REPLACE(REPLACE(REPLACE(cc.CHECK_CLAUSE,CHAR(96),''),' ',''),'(',''),')',''))), NULL)
INTO @fpw_change_slot
FROM information_schema.TABLE_CONSTRAINTS tc
JOIN information_schema.CHECK_CONSTRAINTS cc
  ON cc.CONSTRAINT_SCHEMA=tc.CONSTRAINT_SCHEMA AND cc.CONSTRAINT_NAME=tc.CONSTRAINT_NAME
WHERE BINARY DATABASE() IN ('FPW','fpw') AND tc.TABLE_SCHEMA=BINARY DATABASE()
  AND tc.TABLE_NAME='fpw_arrival_notices' AND tc.CONSTRAINT_NAME='ck_arrival_notice_slot'
  AND tc.CONSTRAINT_TYPE='CHECK';

SELECT DATABASE() AS selected_database, VERSION() AS database_version,
  IF(@fpw_change_slot IN ('slot_no=0','slot_noin0,1'),'PASS','FAIL') AS preflight_status,
  CASE @fpw_change_slot WHEN 'slot_no=0' THEN 'Ready to add arrival time changes.'
    WHEN 'slot_noin0,1' THEN 'Already installed.'
    ELSE 'Select the FPW or fpw database and verify the Phase 3 notice constraint.' END AS detail;
