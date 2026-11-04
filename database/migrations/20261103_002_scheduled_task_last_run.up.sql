-- Select FPW (development) or fpw (production) explicitly.
SET @fpw_schema_ok = BINARY DATABASE() IN ('FPW','fpw');
SELECT COUNT(*), MAX(engine) INTO @fpw_exists,@fpw_engine FROM information_schema.tables
 WHERE table_schema=BINARY DATABASE() AND table_name='fpw_scheduled_task_last_run';
SELECT COUNT(*), COALESCE(SUM(
 (column_name='environment' AND data_type='varchar' AND character_maximum_length=12 AND is_nullable='NO') OR
 (column_name='task_scope' AND data_type='varchar' AND character_maximum_length=11 AND is_nullable='NO') OR
 (column_name='application_name' AND data_type='varchar' AND character_maximum_length=64 AND is_nullable='NO') OR
 (column_name='task_group' AND data_type='varchar' AND character_maximum_length=40 AND is_nullable='NO') OR
 (column_name='task_name' AND data_type='varchar' AND character_maximum_length=60 AND is_nullable='NO') OR
 (column_name IN ('last_run_utc','valid_from_utc') AND data_type='datetime' AND datetime_precision=3 AND is_nullable='YES')),0)
 , COALESCE(SUM(collation_name='ascii_general_ci'),0)
 INTO @fpw_cols,@fpw_matches,@fpw_ci FROM information_schema.columns
 WHERE table_schema=BINARY DATABASE() AND table_name='fpw_scheduled_task_last_run';
SELECT GROUP_CONCAT(column_name ORDER BY seq_in_index) INTO @fpw_pk FROM information_schema.statistics
 WHERE table_schema=BINARY DATABASE() AND table_name='fpw_scheduled_task_last_run' AND index_name='PRIMARY';
SET @fpw_exact = @fpw_exists=1 AND @fpw_engine='InnoDB' AND @fpw_cols=7 AND @fpw_matches=7 AND @fpw_ci=5
 AND @fpw_pk='environment,task_scope,application_name,task_group,task_name';
SET @fpw_statement=IF(@fpw_schema_ok AND @fpw_exists=0,
 'CREATE TABLE fpw_scheduled_task_last_run (
 environment VARCHAR(12) NOT NULL, task_scope VARCHAR(11) NOT NULL,
 application_name VARCHAR(64) NOT NULL, task_group VARCHAR(40) NOT NULL, task_name VARCHAR(60) NOT NULL,
 last_run_utc DATETIME(3) NULL, valid_from_utc DATETIME(3) NULL,
 PRIMARY KEY(environment,task_scope,application_name,task_group,task_name)
) ENGINE=InnoDB DEFAULT CHARSET=ascii COLLATE=ascii_general_ci', 'DO 0');
PREPARE fpw_task_ddl FROM @fpw_statement;
EXECUTE fpw_task_ddl;
DEALLOCATE PREPARE fpw_task_ddl;
SELECT DATABASE() AS selected_database, IF(@fpw_schema_ok AND (@fpw_exists=0 OR @fpw_exact),'PASS','FAIL') AS migration_status;
