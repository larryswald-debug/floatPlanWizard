-- FPW production/test-site user data reset.
--
-- Purpose:
--   Remove all FPW user-owned/runtime data from the currently selected database
--   while preserving application/reference data required for QA testing.
--
-- Install or replace the stored procedure:
--   SOURCE scripts/reset-user-data-for-prod.sql;
--
-- Preview only, no data changed:
--   CALL fpw_reset_user_data_for_prod(0, '');
--
-- Execute destructive reset:
--   CALL fpw_reset_user_data_for_prod(
--     1,
--     'I UNDERSTAND THIS DELETES ALL FPW USER DATA'
--   );
--
-- Notes:
--   - This is SQL-only. It does not create filesystem backups.
--   - It does not remove generated PDFs or uploaded files from disk.
--   - It refuses to run if the current schema contains unclassified tables.
--   - It uses the same wipe/preserve table coverage as scripts/reset-user-data-for-qa.sh.

DELIMITER $$

DROP PROCEDURE IF EXISTS fpw_reset_user_data_for_prod$$

CREATE PROCEDURE fpw_reset_user_data_for_prod(
  IN p_execute TINYINT,
  IN p_confirmation VARCHAR(255)
)
main: BEGIN
  DECLARE v_confirm_required VARCHAR(255) DEFAULT 'I UNDERSTAND THIS DELETES ALL FPW USER DATA';
  DECLARE v_execute TINYINT DEFAULT 0;
  DECLARE v_confirmation VARCHAR(255) DEFAULT '';
  DECLARE v_old_fk_checks INT DEFAULT 1;
  DECLARE v_unknown_count INT DEFAULT 0;
  DECLARE v_missing_count INT DEFAULT 0;
  DECLARE v_nonzero_wipe_count INT DEFAULT 0;
  DECLARE v_preserve_changed_count INT DEFAULT 0;
  DECLARE v_i INT DEFAULT 0;
  DECLARE v_max INT DEFAULT 0;
  DECLARE v_table_name VARCHAR(128) DEFAULT '';

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SET FOREIGN_KEY_CHECKS = v_old_fk_checks;
    ROLLBACK;
    RESIGNAL;
  END;

  SET v_execute = COALESCE(p_execute, 0);
  SET v_confirmation = COALESCE(p_confirmation, '');
  SET v_old_fk_checks = @@FOREIGN_KEY_CHECKS;

  IF v_execute NOT IN (0, 1) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'p_execute must be 0 for preview or 1 for execute.';
  END IF;

  IF v_execute = 1 AND v_confirmation <> v_confirm_required THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Confirmation text does not match. No data was changed.';
  END IF;

  DROP TEMPORARY TABLE IF EXISTS _fpw_prod_reset_wipe_tables;
  CREATE TEMPORARY TABLE _fpw_prod_reset_wipe_tables (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(128) NOT NULL UNIQUE
  ) ENGINE=MEMORY;

  INSERT INTO _fpw_prod_reset_wipe_tables (table_name) VALUES
    ('backup_route_instance_legs_endpoint_norm_20260221_222027'),
    ('backup_route_instance_legs_endpoint_norm_20260221_233840'),
    ('backup_route_instance_legs_lockcount_20260221_093626'),
    ('backup_route_instance_legs_lockcount_glreusev2_20260221_103545'),
    ('companion_pairing_codes'),
    ('companion_devices'),
    ('contacts'),
    ('email_optout'),
    ('emails_sent'),
    ('floatplan_activity_segments'),
    ('floatplan_alert_history'),
    ('floatplan_basic_details'),
    ('floatplan_captain_log_entries'),
    ('floatplan_companion_events'),
    ('floatplan_contacts'),
    ('floatplan_emailsent'),
    ('floatplan_events'),
    ('floatplan_history'),
    ('floatplan_monitor_events'),
    ('floatplan_monitoring'),
    ('floatplan_notification_log'),
    ('floatplan_notifications'),
    ('floatplan_operators'),
    ('floatplan_passengers'),
    ('floatplan_vessels'),
    ('floatplan_waypoints'),
    ('floatplans'),
    ('floatplans_sent'),
    ('floatplans_tosend'),
    ('fpw_early_access'),
    ('fpw_email_log'),
    ('fpw_notification_log'),
    ('fpw_promo_redemptions'),
    ('great_loop_bridge_import_logs'),
    ('member_entitlements'),
    ('member_premium_trip_entitlements'),
    ('messages'),
    ('operators'),
    ('passengers'),
    ('premium_send_credits'),
    ('premium_send_receipts'),
    ('premium_trip_creation_sessions'),
    ('premium_trip_entitlement_events'),
    ('product_events'),
    ('reset_tokens'),
    ('route_instance_leg_progress'),
    ('route_instance_legs'),
    ('route_instance_sections'),
    ('route_instances'),
    ('route_leg_user_overrides'),
    ('stripe_webhook_events'),
    ('user_route_legs'),
    ('user_route_progress'),
    ('user_routes'),
    ('user_segment_overrides'),
    ('user_stripe_customers'),
    ('users_address'),
    ('users_hostek'),
    ('users'),
    ('vessel_images'),
    ('vessels'),
    ('voyage_comments'),
    ('voyage_reactions'),
    ('voyage_followers'),
    ('voyage_posts'),
    ('voyage_streams'),
    ('waypoints');

  DROP TEMPORARY TABLE IF EXISTS _fpw_prod_reset_preserve_tables;
  CREATE TEMPORARY TABLE _fpw_prod_reset_preserve_tables (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(128) NOT NULL UNIQUE
  ) ENGINE=MEMORY;

  INSERT INTO _fpw_prod_reset_preserve_tables (table_name) VALUES
    ('backup_segment_library_lockcount_20260221_093626'),
    ('backup_segment_library_lockcount_glreusev2_20260221_103545'),
    ('boat_mans'),
    ('canonical_locks'),
    ('fpw_port_nearby_assets_stage'),
    ('fpw_port_ports_cleaned_stage'),
    ('fpw_port_profiles_stage'),
    ('fpw_port_services_stage'),
    ('fpw_port_tags_stage'),
    ('fpw_promo_codes'),
    ('greatLoop_anchorages'),
    ('great_loop_bridges'),
    ('great_loop_locks'),
    ('gsm_gsmsettings'),
    ('gulf-and-west-coast-anchorages-import-additions'),
    ('lock_delay_model'),
    ('loop_routes'),
    ('loop_sections'),
    ('loop_segment_distance_audit'),
    ('loop_segments'),
    ('loop_segments_backup_20260219_143430'),
    ('ports'),
    ('ports_backup_20260219_165733'),
    ('ports_backup_20260219_165815'),
    ('port_images'),
    ('port_nearby_assets'),
    ('port_profiles'),
    ('port_services'),
    ('port_slug_redirects'),
    ('port_tags'),
    ('rbk_loop_routes_20260213_154747_372853_s3'),
    ('rbk_loop_routes_20260213_155058_984486_s3'),
    ('rbk_ports_20260213_154507_135767_s1'),
    ('rbk_ports_20260213_154747_372853_s1'),
    ('rbk_ports_20260213_155058_984486_s1'),
    ('rbk_route_template_segments_20260213_155058_984486_s4'),
    ('rbk_segment_library_20260213_154747_372853_s2'),
    ('rbk_segment_library_20260213_155058_984486_s2'),
    ('rescuecenters'),
    ('route_leg_locks'),
    ('route_template_detour_segments'),
    ('route_template_detours'),
    ('route_template_segments'),
    ('segment_geometries'),
    ('segment_library'),
    ('states'),
    ('waterway_milepoints'),
    ('weather_cache'),
    ('weather_point_hourly_cache'),
    ('zcta2025_coordinates'),
    ('fpw_admin_audit_log');

  DROP TEMPORARY TABLE IF EXISTS _fpw_prod_reset_unknown_tables;
  CREATE TEMPORARY TABLE _fpw_prod_reset_unknown_tables AS
  SELECT t.TABLE_NAME AS table_name
  FROM information_schema.TABLES t
  LEFT JOIN _fpw_prod_reset_wipe_tables w ON w.table_name = t.TABLE_NAME
  LEFT JOIN _fpw_prod_reset_preserve_tables p ON p.table_name = t.TABLE_NAME
  WHERE t.TABLE_SCHEMA = DATABASE()
    AND t.TABLE_TYPE = 'BASE TABLE'
    AND w.table_name IS NULL
    AND p.table_name IS NULL
  ORDER BY t.TABLE_NAME;

  DROP TEMPORARY TABLE IF EXISTS _fpw_prod_reset_missing_tables;
  CREATE TEMPORARY TABLE _fpw_prod_reset_missing_tables AS
  SELECT c.table_name
  FROM (
    SELECT table_name FROM _fpw_prod_reset_wipe_tables
    UNION ALL
    SELECT table_name FROM _fpw_prod_reset_preserve_tables
  ) c
  LEFT JOIN information_schema.TABLES t
    ON t.TABLE_SCHEMA = DATABASE()
   AND t.TABLE_TYPE = 'BASE TABLE'
   AND t.TABLE_NAME = c.table_name
  WHERE t.TABLE_NAME IS NULL
  ORDER BY c.table_name;

  SELECT COUNT(*) INTO v_unknown_count FROM _fpw_prod_reset_unknown_tables;
  SELECT COUNT(*) INTO v_missing_count FROM _fpw_prod_reset_missing_tables;

  IF v_unknown_count > 0 OR v_missing_count > 0 THEN
    SELECT 'schema_guard_failed_unknown_tables' AS step, table_name
    FROM _fpw_prod_reset_unknown_tables
    ORDER BY table_name;

    SELECT 'schema_guard_failed_missing_tables' AS step, table_name
    FROM _fpw_prod_reset_missing_tables
    ORDER BY table_name;

    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Schema classification mismatch. No data was changed.';
  END IF;

  DROP TEMPORARY TABLE IF EXISTS _fpw_prod_reset_wipe_counts_before;
  CREATE TEMPORARY TABLE _fpw_prod_reset_wipe_counts_before (
    table_name VARCHAR(128) NOT NULL PRIMARY KEY,
    rows_before BIGINT NOT NULL
  ) ENGINE=MEMORY;

  SET v_i = 1;
  SELECT COALESCE(MAX(id), 0) INTO v_max FROM _fpw_prod_reset_wipe_tables;
  WHILE v_i <= v_max DO
    SELECT table_name INTO v_table_name
    FROM _fpw_prod_reset_wipe_tables
    WHERE id = v_i;

    SET @fpw_prod_reset_count = 0;
    SET @fpw_prod_reset_sql = CONCAT(
      'SELECT COUNT(*) INTO @fpw_prod_reset_count FROM `',
      REPLACE(v_table_name, '`', '``'),
      '`'
    );
    PREPARE fpw_prod_reset_stmt FROM @fpw_prod_reset_sql;
    EXECUTE fpw_prod_reset_stmt;
    DEALLOCATE PREPARE fpw_prod_reset_stmt;

    INSERT INTO _fpw_prod_reset_wipe_counts_before (table_name, rows_before)
    VALUES (v_table_name, @fpw_prod_reset_count);

    SET v_i = v_i + 1;
  END WHILE;

  DROP TEMPORARY TABLE IF EXISTS _fpw_prod_reset_preserve_counts_before;
  CREATE TEMPORARY TABLE _fpw_prod_reset_preserve_counts_before (
    table_name VARCHAR(128) NOT NULL PRIMARY KEY,
    rows_before BIGINT NOT NULL
  ) ENGINE=MEMORY;

  SET v_i = 1;
  SELECT COALESCE(MAX(id), 0) INTO v_max FROM _fpw_prod_reset_preserve_tables;
  WHILE v_i <= v_max DO
    SELECT table_name INTO v_table_name
    FROM _fpw_prod_reset_preserve_tables
    WHERE id = v_i;

    SET @fpw_prod_reset_count = 0;
    SET @fpw_prod_reset_sql = CONCAT(
      'SELECT COUNT(*) INTO @fpw_prod_reset_count FROM `',
      REPLACE(v_table_name, '`', '``'),
      '`'
    );
    PREPARE fpw_prod_reset_stmt FROM @fpw_prod_reset_sql;
    EXECUTE fpw_prod_reset_stmt;
    DEALLOCATE PREPARE fpw_prod_reset_stmt;

    INSERT INTO _fpw_prod_reset_preserve_counts_before (table_name, rows_before)
    VALUES (v_table_name, @fpw_prod_reset_count);

    SET v_i = v_i + 1;
  END WHILE;

  SELECT 'preview_wipe_counts_before' AS step, table_name, rows_before
  FROM _fpw_prod_reset_wipe_counts_before
  ORDER BY table_name;

  SELECT 'preview_preserve_counts_before' AS step, table_name, rows_before
  FROM _fpw_prod_reset_preserve_counts_before
  ORDER BY table_name;

  IF v_execute = 0 THEN
    SELECT
      'preview_only_no_data_changed' AS result,
      DATABASE() AS database_name,
      v_confirm_required AS execute_confirmation_required;
    LEAVE main;
  END IF;

  START TRANSACTION;
  SET FOREIGN_KEY_CHECKS = 0;

  SET v_i = 1;
  SELECT COALESCE(MAX(id), 0) INTO v_max FROM _fpw_prod_reset_wipe_tables;
  WHILE v_i <= v_max DO
    SELECT table_name INTO v_table_name
    FROM _fpw_prod_reset_wipe_tables
    WHERE id = v_i;

    SET @fpw_prod_reset_sql = CONCAT(
      'DELETE FROM `',
      REPLACE(v_table_name, '`', '``'),
      '`'
    );
    PREPARE fpw_prod_reset_stmt FROM @fpw_prod_reset_sql;
    EXECUTE fpw_prod_reset_stmt;
    DEALLOCATE PREPARE fpw_prod_reset_stmt;

    SET v_i = v_i + 1;
  END WHILE;

  SET FOREIGN_KEY_CHECKS = v_old_fk_checks;

  DROP TEMPORARY TABLE IF EXISTS _fpw_prod_reset_wipe_counts_after;
  CREATE TEMPORARY TABLE _fpw_prod_reset_wipe_counts_after (
    table_name VARCHAR(128) NOT NULL PRIMARY KEY,
    rows_after BIGINT NOT NULL
  ) ENGINE=MEMORY;

  SET v_i = 1;
  SELECT COALESCE(MAX(id), 0) INTO v_max FROM _fpw_prod_reset_wipe_tables;
  WHILE v_i <= v_max DO
    SELECT table_name INTO v_table_name
    FROM _fpw_prod_reset_wipe_tables
    WHERE id = v_i;

    SET @fpw_prod_reset_count = 0;
    SET @fpw_prod_reset_sql = CONCAT(
      'SELECT COUNT(*) INTO @fpw_prod_reset_count FROM `',
      REPLACE(v_table_name, '`', '``'),
      '`'
    );
    PREPARE fpw_prod_reset_stmt FROM @fpw_prod_reset_sql;
    EXECUTE fpw_prod_reset_stmt;
    DEALLOCATE PREPARE fpw_prod_reset_stmt;

    INSERT INTO _fpw_prod_reset_wipe_counts_after (table_name, rows_after)
    VALUES (v_table_name, @fpw_prod_reset_count);

    SET v_i = v_i + 1;
  END WHILE;

  DROP TEMPORARY TABLE IF EXISTS _fpw_prod_reset_preserve_counts_after;
  CREATE TEMPORARY TABLE _fpw_prod_reset_preserve_counts_after (
    table_name VARCHAR(128) NOT NULL PRIMARY KEY,
    rows_after BIGINT NOT NULL
  ) ENGINE=MEMORY;

  SET v_i = 1;
  SELECT COALESCE(MAX(id), 0) INTO v_max FROM _fpw_prod_reset_preserve_tables;
  WHILE v_i <= v_max DO
    SELECT table_name INTO v_table_name
    FROM _fpw_prod_reset_preserve_tables
    WHERE id = v_i;

    SET @fpw_prod_reset_count = 0;
    SET @fpw_prod_reset_sql = CONCAT(
      'SELECT COUNT(*) INTO @fpw_prod_reset_count FROM `',
      REPLACE(v_table_name, '`', '``'),
      '`'
    );
    PREPARE fpw_prod_reset_stmt FROM @fpw_prod_reset_sql;
    EXECUTE fpw_prod_reset_stmt;
    DEALLOCATE PREPARE fpw_prod_reset_stmt;

    INSERT INTO _fpw_prod_reset_preserve_counts_after (table_name, rows_after)
    VALUES (v_table_name, @fpw_prod_reset_count);

    SET v_i = v_i + 1;
  END WHILE;

  SELECT COUNT(*) INTO v_nonzero_wipe_count
  FROM _fpw_prod_reset_wipe_counts_after
  WHERE rows_after <> 0;

  SELECT COUNT(*) INTO v_preserve_changed_count
  FROM _fpw_prod_reset_preserve_counts_before b
  JOIN _fpw_prod_reset_preserve_counts_after a ON a.table_name = b.table_name
  WHERE a.rows_after <> b.rows_before;

  IF v_nonzero_wipe_count > 0 THEN
    SELECT 'wipe_validation_failed_nonzero_tables' AS step, table_name, rows_after
    FROM _fpw_prod_reset_wipe_counts_after
    WHERE rows_after <> 0
    ORDER BY table_name;

    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Wipe validation failed. User/runtime rows remain.';
  END IF;

  IF v_preserve_changed_count > 0 THEN
    SELECT 'preserve_validation_failed_changed_tables' AS step, b.table_name, b.rows_before, a.rows_after
    FROM _fpw_prod_reset_preserve_counts_before b
    JOIN _fpw_prod_reset_preserve_counts_after a ON a.table_name = b.table_name
    WHERE a.rows_after <> b.rows_before
    ORDER BY b.table_name;

    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Preserve validation failed. Preserved table counts changed.';
  END IF;

  COMMIT;

  SET v_i = 1;
  SELECT COALESCE(MAX(id), 0) INTO v_max FROM _fpw_prod_reset_wipe_tables;
  WHILE v_i <= v_max DO
    SELECT table_name INTO v_table_name
    FROM _fpw_prod_reset_wipe_tables
    WHERE id = v_i;

    IF EXISTS (
      SELECT 1
      FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = v_table_name
        AND EXTRA LIKE '%auto_increment%'
    ) THEN
      SET @fpw_prod_reset_sql = CONCAT(
        'ALTER TABLE `',
        REPLACE(v_table_name, '`', '``'),
        '` AUTO_INCREMENT = 1'
      );
      PREPARE fpw_prod_reset_stmt FROM @fpw_prod_reset_sql;
      EXECUTE fpw_prod_reset_stmt;
      DEALLOCATE PREPARE fpw_prod_reset_stmt;
    END IF;

    SET v_i = v_i + 1;
  END WHILE;

  SELECT 'executed_wipe_counts_after' AS step, table_name, rows_after
  FROM _fpw_prod_reset_wipe_counts_after
  ORDER BY table_name;

  SELECT 'executed_preserve_counts_after' AS step, table_name, rows_after
  FROM _fpw_prod_reset_preserve_counts_after
  ORDER BY table_name;

  SELECT
    'success' AS result,
    DATABASE() AS database_name,
    'All configured FPW user/runtime database tables are empty.' AS message;
END$$

DELIMITER ;
