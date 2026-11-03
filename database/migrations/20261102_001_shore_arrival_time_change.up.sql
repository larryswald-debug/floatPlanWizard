-- Slot 0 is the initial overdue alert. Slot 1 records an explicit change of arrival time.
-- One atomic ALTER retains the constraint name, unique notice identity and existing rows.
-- Use the explicitly selected FPW development or fpw production schema.
SELECT IF(COUNT(*)=1, MAX(LOWER(REPLACE(REPLACE(REPLACE(REPLACE(cc.CHECK_CLAUSE,CHAR(96),''),' ',''),'(',''),')',''))), NULL)
INTO @fpw_change_slot
FROM information_schema.TABLE_CONSTRAINTS tc
JOIN information_schema.CHECK_CONSTRAINTS cc
  ON cc.CONSTRAINT_SCHEMA=tc.CONSTRAINT_SCHEMA AND cc.CONSTRAINT_NAME=tc.CONSTRAINT_NAME
WHERE BINARY DATABASE() IN ('FPW','fpw') AND tc.TABLE_SCHEMA=BINARY DATABASE()
  AND tc.TABLE_NAME='fpw_arrival_notices' AND tc.CONSTRAINT_NAME='ck_arrival_notice_slot'
  AND tc.CONSTRAINT_TYPE='CHECK';
SET @fpw_change_drop = IF(LOWER(VERSION()) LIKE '%mariadb%', 'DROP CONSTRAINT', 'DROP CHECK');
SET @fpw_change_sql = IF(@fpw_change_slot='slot_no=0',
  CONCAT('ALTER TABLE fpw_arrival_notices ',@fpw_change_drop,
    ' ck_arrival_notice_slot, ADD CONSTRAINT ck_arrival_notice_slot CHECK (slot_no IN (0,1))'),
  'DO 0');
PREPARE fpw_change_ddl FROM @fpw_change_sql;
EXECUTE fpw_change_ddl;
DEALLOCATE PREPARE fpw_change_ddl;

SELECT DATABASE() AS selected_database,
  IF(@fpw_change_slot IN ('slot_no=0','slot_noin0,1'),'PASS','FAIL') AS migration_status,
  CASE @fpw_change_slot WHEN 'slot_no=0' THEN 'Constraint extended.'
    WHEN 'slot_noin0,1' THEN 'Already installed.'
    ELSE 'No change. Select the FPW or fpw database and verify Phase 3.' END AS detail;
