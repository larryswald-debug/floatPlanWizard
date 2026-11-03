-- Select FPW (development) or fpw (production) explicitly before running this file.
SELECT COUNT(*) INTO @fpw_base FROM information_schema.columns
WHERE BINARY DATABASE() IN ('FPW','fpw') AND table_schema=BINARY DATABASE()
  AND table_name='floatplan_monitoring' AND column_name='expected_checkin_at' AND data_type='datetime';
SELECT COUNT(*), COALESCE(SUM(BINARY column_type = BINARY 'enum(''EVENING'',''DAILY_START'',''PLANNED_RETURN'',''NO_EVENING'',''LEGACY'')'
  AND is_nullable='YES'),0) INTO @fpw_exists,@fpw_valid FROM information_schema.columns
WHERE table_schema=BINARY DATABASE() AND table_name='floatplan_monitoring' AND column_name='checkpoint_kind';

-- Run only after rolling back the application. Refuse to discard recorded checkpoint reasons.
SET @fpw_used=1;
SET @fpw_probe=IF(@fpw_base=1 AND @fpw_valid=1,
  'SELECT EXISTS(SELECT 1 FROM floatplan_monitoring WHERE checkpoint_kind IS NOT NULL) INTO @fpw_used','DO 0');
PREPARE checkpoint_probe FROM @fpw_probe;
EXECUTE checkpoint_probe;
DEALLOCATE PREPARE checkpoint_probe;
SET @fpw_ddl = IF(@fpw_base=1 AND @fpw_valid=1 AND @fpw_used=0,
  'ALTER TABLE floatplan_monitoring DROP COLUMN checkpoint_kind', 'DO 0');
PREPARE checkpoint_ddl FROM @fpw_ddl;
EXECUTE checkpoint_ddl;
DEALLOCATE PREPARE checkpoint_ddl;

SELECT DATABASE() AS selected_database,
  IF(@fpw_base=1 AND (@fpw_exists=0 OR (@fpw_valid=1 AND @fpw_used=0)),'PASS','FAIL') AS rollback_status;
