-- Preserve notification history. Reverting is allowed only while slot 1 is unused.
-- Use the explicitly selected FPW development or fpw production schema.
SELECT IF(COUNT(*)=1, MAX(LOWER(REPLACE(REPLACE(REPLACE(REPLACE(cc.CHECK_CLAUSE,CHAR(96),''),' ',''),'(',''),')',''))), NULL)
INTO @fpw_change_slot
FROM information_schema.TABLE_CONSTRAINTS tc
JOIN information_schema.CHECK_CONSTRAINTS cc
  ON cc.CONSTRAINT_SCHEMA=tc.CONSTRAINT_SCHEMA AND cc.CONSTRAINT_NAME=tc.CONSTRAINT_NAME
WHERE BINARY DATABASE() IN ('FPW','fpw') AND tc.TABLE_SCHEMA=BINARY DATABASE()
  AND tc.TABLE_NAME='fpw_arrival_notices' AND tc.CONSTRAINT_NAME='ck_arrival_notice_slot'
  AND tc.CONSTRAINT_TYPE='CHECK';

SET @fpw_change_used = 1;
SET @fpw_change_sql = IF(@fpw_change_slot='slot_noin0,1',
  'SELECT EXISTS(SELECT 1 FROM fpw_arrival_notices WHERE slot_no=1) INTO @fpw_change_used','DO 0');
PREPARE fpw_change_probe FROM @fpw_change_sql;
EXECUTE fpw_change_probe;
DEALLOCATE PREPARE fpw_change_probe;

SET @fpw_change_drop = IF(LOWER(VERSION()) LIKE '%mariadb%', 'DROP CONSTRAINT', 'DROP CHECK');
SET @fpw_change_sql = IF(@fpw_change_slot='slot_noin0,1' AND @fpw_change_used=0,
  CONCAT('ALTER TABLE fpw_arrival_notices ',@fpw_change_drop,
    ' ck_arrival_notice_slot, ADD CONSTRAINT ck_arrival_notice_slot CHECK (slot_no=0)'),
  'DO 0');
PREPARE fpw_change_ddl FROM @fpw_change_sql;
EXECUTE fpw_change_ddl;
DEALLOCATE PREPARE fpw_change_ddl;

SELECT DATABASE() AS selected_database,
  IF(@fpw_change_slot='slot_no=0' OR (@fpw_change_slot='slot_noin0,1' AND @fpw_change_used=0),'PASS','FAIL') AS rollback_status,
  CASE WHEN @fpw_change_slot='slot_no=0' THEN 'Already reverted.'
    WHEN @fpw_change_slot='slot_noin0,1' AND @fpw_change_used=0 THEN 'Original slot constraint restored.'
    WHEN @fpw_change_slot='slot_noin0,1' THEN 'Refused. Preserve existing arrival time change history.'
    ELSE 'Refused. Verify the selected database and constraint.' END AS detail;
