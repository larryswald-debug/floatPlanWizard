-- Milepoint coverage audit for a route template.
-- Default route: GREAT_LOOP_CCW
-- This report identifies segment endpoints that do not have a corresponding
-- location/alias entry in waterway_milepoints for the inferred waterway.

SELECT
    r.short_code AS route_code,
    sec.name AS section_name,
    s.id AS segment_id,
    'START' AS point_type,
    s.start_name AS location_name
FROM loop_routes r
INNER JOIN loop_sections sec ON sec.route_id = r.id
INNER JOIN loop_segments s ON s.section_id = sec.id
LEFT JOIN waterway_milepoints wm
  ON wm.is_active = 1
 AND (
      (sec.name LIKE '%Great Lakes%' AND wm.waterway_code = 'GREAT_LAKES')
   OR (sec.name LIKE '%Trent Severn%' AND wm.waterway_code = 'TRENT_SEVERN')
   OR ((sec.name LIKE '%St Lawrence%' OR sec.name LIKE '%Saint Lawrence%') AND wm.waterway_code = 'ST_LAWRENCE')
   OR ((sec.name LIKE '%Erie Canal%' OR sec.name LIKE '%Oswego%') AND wm.waterway_code = 'ERIE_CANAL')
   OR (sec.name LIKE '%Hudson%' AND wm.waterway_code = 'HUDSON')
   OR ((sec.name LIKE '%Atlantic%' AND sec.name LIKE '%ICW%') AND wm.waterway_code = 'ATLANTIC_ICW')
   OR (sec.name LIKE '%Okeechobee%' AND wm.waterway_code = 'OKEECHOBEE')
   OR ((sec.name LIKE '%Gulf%' AND sec.name LIKE '%ICW%') AND wm.waterway_code = 'GULF_ICW')
   OR (sec.name LIKE '%Illinois%' AND wm.waterway_code = 'ILLINOIS')
   OR (sec.name LIKE '%Mississippi%' AND wm.waterway_code = 'MISSISSIPPI')
   OR (sec.name LIKE '%Ohio%' AND wm.waterway_code = 'OHIO')
   OR (sec.name LIKE '%Tennessee River%' AND wm.waterway_code = 'TENNESSEE')
   OR ((sec.name LIKE '%Tenn-Tom%' OR sec.name LIKE '%Tenn Tom%') AND wm.waterway_code = 'TENN_TOM')
 )
 AND (
      LOWER(REPLACE(REPLACE(TRIM(wm.location_name), '.', ''), '''', '')) = LOWER(REPLACE(REPLACE(TRIM(s.start_name), '.', ''), '''', ''))
   OR LOWER(REPLACE(REPLACE(TRIM(COALESCE(wm.alias_name, '')), '.', ''), '''', '')) = LOWER(REPLACE(REPLACE(TRIM(s.start_name), '.', ''), '''', ''))
 )
WHERE r.short_code = 'GREAT_LOOP_CCW'
  AND wm.id IS NULL

UNION ALL

SELECT
    r.short_code AS route_code,
    sec.name AS section_name,
    s.id AS segment_id,
    'END' AS point_type,
    s.end_name AS location_name
FROM loop_routes r
INNER JOIN loop_sections sec ON sec.route_id = r.id
INNER JOIN loop_segments s ON s.section_id = sec.id
LEFT JOIN waterway_milepoints wm
  ON wm.is_active = 1
 AND (
      (sec.name LIKE '%Great Lakes%' AND wm.waterway_code = 'GREAT_LAKES')
   OR (sec.name LIKE '%Trent Severn%' AND wm.waterway_code = 'TRENT_SEVERN')
   OR ((sec.name LIKE '%St Lawrence%' OR sec.name LIKE '%Saint Lawrence%') AND wm.waterway_code = 'ST_LAWRENCE')
   OR ((sec.name LIKE '%Erie Canal%' OR sec.name LIKE '%Oswego%') AND wm.waterway_code = 'ERIE_CANAL')
   OR (sec.name LIKE '%Hudson%' AND wm.waterway_code = 'HUDSON')
   OR ((sec.name LIKE '%Atlantic%' AND sec.name LIKE '%ICW%') AND wm.waterway_code = 'ATLANTIC_ICW')
   OR (sec.name LIKE '%Okeechobee%' AND wm.waterway_code = 'OKEECHOBEE')
   OR ((sec.name LIKE '%Gulf%' AND sec.name LIKE '%ICW%') AND wm.waterway_code = 'GULF_ICW')
   OR (sec.name LIKE '%Illinois%' AND wm.waterway_code = 'ILLINOIS')
   OR (sec.name LIKE '%Mississippi%' AND wm.waterway_code = 'MISSISSIPPI')
   OR (sec.name LIKE '%Ohio%' AND wm.waterway_code = 'OHIO')
   OR (sec.name LIKE '%Tennessee River%' AND wm.waterway_code = 'TENNESSEE')
   OR ((sec.name LIKE '%Tenn-Tom%' OR sec.name LIKE '%Tenn Tom%') AND wm.waterway_code = 'TENN_TOM')
 )
 AND (
      LOWER(REPLACE(REPLACE(TRIM(wm.location_name), '.', ''), '''', '')) = LOWER(REPLACE(REPLACE(TRIM(s.end_name), '.', ''), '''', ''))
   OR LOWER(REPLACE(REPLACE(TRIM(COALESCE(wm.alias_name, '')), '.', ''), '''', '')) = LOWER(REPLACE(REPLACE(TRIM(s.end_name), '.', ''), '''', ''))
 )
WHERE r.short_code = 'GREAT_LOOP_CCW'
  AND wm.id IS NULL
ORDER BY section_name, segment_id, point_type;
