SELECT CASE WHEN
 (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='guide_route_imports')=20
 AND (SELECT COUNT(DISTINCT INDEX_NAME) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='guide_route_imports' AND INDEX_NAME IN ('uq_guide_import_request','uq_guide_my_route'))=2
 AND EXISTS(SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='guide_route_imports' AND ENGINE='InnoDB')
 THEN 'PASS' ELSE 'FAIL' END AS schema_status;
SELECT COUNT(*) AS imports, SUM(NOT JSON_VALID(source_snapshot_json) OR NOT JSON_VALID(leg_state_json) OR NOT JSON_VALID(planning_inputs_json) OR (request_history_json IS NOT NULL AND NOT JSON_VALID(request_history_json))) AS invalid_json FROM guide_route_imports;




