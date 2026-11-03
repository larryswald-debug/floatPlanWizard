-- Select FPW (development) or fpw (production) explicitly before running this file.
SELECT COUNT(*) INTO @fpw_base FROM information_schema.columns
WHERE BINARY DATABASE() IN ('FPW','fpw') AND table_schema=BINARY DATABASE()
  AND table_name='floatplan_monitoring' AND column_name='expected_checkin_at' AND data_type='datetime';
SELECT COUNT(*), COALESCE(SUM(BINARY column_type = BINARY 'enum(''EVENING'',''DAILY_START'',''PLANNED_RETURN'',''NO_EVENING'',''LEGACY'')'
  AND is_nullable='YES'),0) INTO @fpw_exists,@fpw_valid FROM information_schema.columns
WHERE table_schema=BINARY DATABASE() AND table_name='floatplan_monitoring' AND column_name='checkpoint_kind';

SELECT DATABASE() AS selected_database, IF(@fpw_base=1 AND (@fpw_exists=0 OR @fpw_valid=1),'PASS','FAIL') AS preflight_status,
  CASE WHEN @fpw_base<>1 THEN 'Select FPW or fpw and verify floatplan_monitoring.'
       WHEN @fpw_exists=0 THEN 'Ready to add checkpoint_kind.'
       WHEN @fpw_valid=1 THEN 'Already installed.' ELSE 'Unexpected checkpoint_kind definition.' END AS detail;
