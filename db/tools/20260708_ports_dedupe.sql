-- FPW Great Loop Ports de-duplication maintenance script.
-- Default mode is dry-run. To execute locally:
--   docker exec -i cfdev-mysql mysql -uroot -prootpassword --init-command="SET @execute_ports_dedupe=1" FPW < db/tools/20260708_ports_dedupe.sql
-- Run db/migrations/20260708_ports_dedupe_redirects.sql before executing this script.
-- Keep a mysqldump export of the Ports-related tables before execute mode.

SET @execute_ports_dedupe = COALESCE(@execute_ports_dedupe, 0);

START TRANSACTION;

DROP TEMPORARY TABLE IF EXISTS tmp_ports_dedupe_map;
CREATE TEMPORARY TABLE tmp_ports_dedupe_map (
  duplicate_port_id int NOT NULL PRIMARY KEY,
  canonical_port_id int NOT NULL,
  old_slug varchar(220) NOT NULL,
  canonical_slug varchar(220) NOT NULL,
  duplicate_name varchar(160) NOT NULL,
  match_reason varchar(160) NOT NULL
) ENGINE=Memory;

INSERT INTO tmp_ports_dedupe_map
  (duplicate_port_id, canonical_port_id, old_slug, canonical_slug, duplicate_name, match_reason)
VALUES
  (172, 2, '172-annapolis-md', '2-annapolis-md', 'Annapolis', 'same name/state/waterway within 3 NM'),
  (175, 118, '175-atlantic-city-nj', '118-atlantic-city-nj', 'Atlantic City', 'same name/state/waterway within 3 NM'),
  (182, 127, '182-buffalo-ny', '127-buffalo-ny', 'Buffalo', 'same name/state/waterway within 3 NM'),
  (150, 68, '150-carrabelle-fl', '68-carrabelle-fl', 'Carrabelle', 'same name/state/waterway within 3 NM'),
  (173, 10, '173-chesapeake-city-md', '10-chesapeake-city-md', 'Chesapeake City', 'same name/state/waterway within 3 NM'),
  (184, 129, '184-cleveland-oh', '129-cleveland-oh', 'Cleveland', 'same name/state/waterway within 3 NM'),
  (146, 15, '146-demopolis-al', '15-demopolis-al', 'Demopolis', 'same name/state/waterway within 3 NM'),
  (183, 128, '183-erie-pa', '128-erie-pa', 'Erie', 'same name/state/waterway within 3 NM'),
  (158, 108, '158-fort-lauderdale-fl', '108-fort-lauderdale-fl', 'Fort Lauderdale', 'same name/state/waterway within 3 NM'),
  (154, 19, '154-fort-myers-fl', '19-fort-myers-fl', 'Fort Myers', 'same name/state/waterway within 3 NM'),
  (161, 112, '161-jacksonville-fl', '112-jacksonville-fl', 'Jacksonville', 'same name/state/waterway within 3 NM'),
  (186, 27, '186-mackinac-island-mi', '27-mackinac-island-mi', 'Mackinac Island', 'same name/state/waterway within 3 NM'),
  (147, 29, '147-mobile-al', '29-mobile-al', 'Mobile', 'same name/state/waterway within 3 NM'),
  (165, 31, '165-myrtle-beach-sc', '31-myrtle-beach-sc', 'Myrtle Beach', 'same name/state/waterway within 3 NM'),
  (201, 35, '201-oswego-ny', '35-oswego-ny', 'Oswego', 'same name/state/waterway within 3 NM'),
  (142, 37, '142-paducah-ky', '37-paducah-ky', 'Paducah', 'same name/state/waterway within 3 NM'),
  (149, 66, '149-panama-city-fl', '66-panama-city-fl', 'Panama City', 'same name/state/waterway within 3 NM'),
  (148, 64, '148-pensacola-fl', '64-pensacola-fl', 'Pensacola', 'same name/state/waterway within 3 NM'),
  (137, 38, '137-peoria-il', '38-peoria-il', 'Peoria', 'same name/state/waterway within 3 NM'),
  (171, 45, '171-solomons-md', '45-solomons-md', 'Solomons', 'same name/state/waterway within 3 NM'),
  (157, 49, '157-stuart-fl', '49-stuart-fl', 'Stuart', 'same name/state/waterway within 3 NM'),
  (151, 51, '151-tarpon-springs-fl', '51-tarpon-springs-fl', 'Tarpon Springs', 'same name/state/waterway within 3 NM');

SELECT @execute_ports_dedupe AS execute_mode;

SELECT
  'planned_duplicate_map' AS section,
  m.duplicate_port_id,
  m.canonical_port_id,
  m.old_slug,
  m.canonical_slug,
  m.duplicate_name,
  m.match_reason,
  CASE WHEN dup.id IS NULL THEN 'missing duplicate' ELSE 'ok' END AS duplicate_status,
  CASE WHEN canon.id IS NULL THEN 'missing canonical' ELSE 'ok' END AS canonical_status
FROM tmp_ports_dedupe_map m
LEFT JOIN ports dup ON dup.id = m.duplicate_port_id
LEFT JOIN ports canon ON canon.id = m.canonical_port_id
ORDER BY m.duplicate_name, m.duplicate_port_id;

SELECT
  'planned_tag_merge' AS section,
  m.duplicate_port_id,
  m.canonical_port_id,
  COUNT(pt.id) AS duplicate_tags_available
FROM tmp_ports_dedupe_map m
LEFT JOIN port_tags pt ON pt.port_id = m.duplicate_port_id
GROUP BY m.duplicate_port_id, m.canonical_port_id
ORDER BY m.duplicate_port_id;

SELECT
  'planned_segment_start_reference_update' AS section,
  m.duplicate_port_id,
  m.canonical_port_id,
  COUNT(sl.id) AS reference_count
FROM tmp_ports_dedupe_map m
LEFT JOIN segment_library sl ON sl.start_port_id = m.duplicate_port_id
GROUP BY m.duplicate_port_id, m.canonical_port_id
HAVING reference_count > 0
ORDER BY m.duplicate_port_id;

SELECT
  'planned_segment_end_reference_update' AS section,
  m.duplicate_port_id,
  m.canonical_port_id,
  COUNT(sl.id) AS reference_count
FROM tmp_ports_dedupe_map m
LEFT JOIN segment_library sl ON sl.end_port_id = m.duplicate_port_id
GROUP BY m.duplicate_port_id, m.canonical_port_id
HAVING reference_count > 0
ORDER BY m.duplicate_port_id;

INSERT INTO port_slug_redirects
  (old_port_id, old_slug, canonical_port_id, canonical_slug, reason)
SELECT
  m.duplicate_port_id,
  m.old_slug,
  m.canonical_port_id,
  m.canonical_slug,
  'ports_dedupe_20260708'
FROM tmp_ports_dedupe_map m
WHERE @execute_ports_dedupe = 1
ON DUPLICATE KEY UPDATE
  canonical_port_id = VALUES(canonical_port_id),
  canonical_slug = VALUES(canonical_slug),
  reason = VALUES(reason);

INSERT IGNORE INTO port_tags (port_id, tag)
SELECT m.canonical_port_id, pt.tag
FROM tmp_ports_dedupe_map m
INNER JOIN port_tags pt ON pt.port_id = m.duplicate_port_id
WHERE @execute_ports_dedupe = 1;

UPDATE segment_library sl
INNER JOIN tmp_ports_dedupe_map m ON m.duplicate_port_id = sl.start_port_id
SET sl.start_port_id = m.canonical_port_id
WHERE @execute_ports_dedupe = 1;

UPDATE segment_library sl
INNER JOIN tmp_ports_dedupe_map m ON m.duplicate_port_id = sl.end_port_id
SET sl.end_port_id = m.canonical_port_id
WHERE @execute_ports_dedupe = 1;

UPDATE route_template_detours rtd
INNER JOIN tmp_ports_dedupe_map m ON m.duplicate_port_id = rtd.insert_after_port_id
SET rtd.insert_after_port_id = m.canonical_port_id
WHERE @execute_ports_dedupe = 1;

DELETE pna
FROM port_nearby_assets pna
INNER JOIN tmp_ports_dedupe_map m ON m.duplicate_port_id = pna.port_id
WHERE @execute_ports_dedupe = 1;

DELETE pt
FROM port_tags pt
INNER JOIN tmp_ports_dedupe_map m ON m.duplicate_port_id = pt.port_id
WHERE @execute_ports_dedupe = 1;

DELETE pi
FROM port_images pi
INNER JOIN tmp_ports_dedupe_map m ON m.duplicate_port_id = pi.port_id
WHERE @execute_ports_dedupe = 1;

DELETE ps
FROM port_services ps
INNER JOIN tmp_ports_dedupe_map m ON m.duplicate_port_id = ps.port_id
WHERE @execute_ports_dedupe = 1;

DELETE pp
FROM port_profiles pp
INNER JOIN tmp_ports_dedupe_map m ON m.duplicate_port_id = pp.port_id
WHERE @execute_ports_dedupe = 1;

DELETE p
FROM ports p
INNER JOIN tmp_ports_dedupe_map m ON m.duplicate_port_id = p.id
WHERE @execute_ports_dedupe = 1;

SELECT 'post_ports_count' AS section, COUNT(*) AS row_count FROM ports;
SELECT 'post_profiles_count' AS section, COUNT(*) AS row_count FROM port_profiles;
SELECT 'post_services_count' AS section, COUNT(*) AS row_count FROM port_services;
SELECT 'post_tags_count' AS section, COUNT(*) AS row_count FROM port_tags;
SELECT 'post_redirects_count' AS section, COUNT(*) AS row_count FROM port_slug_redirects WHERE reason = 'ports_dedupe_20260708';

COMMIT;
