-- Read-only preflight; all required parent tables must exist. Do not rerun an applied up migration.
SELECT DATABASE() AS selected_database, VERSION() AS server_version;
SELECT TABLE_NAME,ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE()
 AND TABLE_NAME IN ('users','waypoints','user_routes','user_route_legs','route_instances','route_instance_legs','route_leg_user_overrides','guide_route_imports');
SELECT TABLE_NAME,COLUMN_NAME,DATA_TYPE,IS_NULLABLE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE()
 AND ((TABLE_NAME='users' AND COLUMN_NAME='userId') OR (TABLE_NAME IN ('user_routes','user_route_legs','route_instances') AND COLUMN_NAME='id')
 OR (TABLE_NAME='route_instances' AND COLUMN_NAME='routegen_inputs_json')) ORDER BY TABLE_NAME,COLUMN_NAME;
SELECT CASE WHEN
 (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ('users','waypoints','user_routes','user_route_legs','route_instances','route_instance_legs','route_leg_user_overrides') AND ENGINE='InnoDB')=7
 AND NOT EXISTS(SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='guide_route_imports')
 THEN 'READY_FOR_NEW_MIGRATION' ELSE 'STOP_REVIEW_PREFLIGHT' END AS preflight_status;

