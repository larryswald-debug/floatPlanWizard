-- Route Generator normalization phase 1 backfill.
-- Prerequisite: 20260220_01_routegen_normalization_phase1.sql applied.

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 1) Seed loop_segments.source_segment_id from existing leg overrides when available.
UPDATE loop_segments s
INNER JOIN route_leg_user_overrides rluo
  ON rluo.route_leg_id = s.id
SET s.source_segment_id = rluo.segment_id
WHERE (s.source_segment_id IS NULL OR s.source_segment_id = 0)
  AND rluo.segment_id IS NOT NULL
  AND rluo.segment_id > 0;

-- 2) Backfill normalized section rows from generated route content.
INSERT INTO route_instance_sections
  (route_instance_id, section_order, name, phase_num, source_section_id)
SELECT
  ri.id AS route_instance_id,
  sec.order_index AS section_order,
  COALESCE(NULLIF(TRIM(sec.name), ''), CONCAT('Section ', sec.order_index)) AS name,
  sec.phase_num,
  sec.id AS source_section_id
FROM route_instances ri
INNER JOIN loop_sections sec
  ON sec.route_id = ri.generated_route_id
LEFT JOIN route_instance_sections ris
  ON ris.route_instance_id = ri.id
 AND ris.section_order = sec.order_index
WHERE ris.id IS NULL;

-- 3) Backfill normalized leg rows from generated loop segments.
INSERT INTO route_instance_legs (
  route_instance_id,
  route_instance_section_id,
  leg_order,
  segment_id,
  source_loop_segment_id,
  is_reversed,
  is_optional,
  detour_code,
  start_name,
  end_name,
  start_lat,
  start_lng,
  end_lat,
  end_lng,
  base_dist_nm,
  lock_count,
  notes
)
SELECT
  ol.route_instance_id,
  ris.id AS route_instance_section_id,
  ol.leg_order,
  ol.segment_id,
  ol.source_loop_segment_id,
  0 AS is_reversed,
  0 AS is_optional,
  NULL AS detour_code,
  ol.start_name,
  ol.end_name,
  ol.start_lat,
  ol.start_lng,
  ol.end_lat,
  ol.end_lng,
  ol.base_dist_nm,
  ol.lock_count,
  ol.notes
FROM (
  SELECT
    src.route_instance_id,
    src.loop_section_id,
    src.loop_segment_id AS source_loop_segment_id,
    src.segment_id,
    src.start_name,
    src.end_name,
    src.start_lat,
    src.start_lng,
    src.end_lat,
    src.end_lng,
    src.base_dist_nm,
    src.lock_count,
    src.notes,
    (@leg_order := IF(@current_route_instance = src.route_instance_id, @leg_order + 1, 1)) AS leg_order,
    (@current_route_instance := src.route_instance_id) AS _route_marker
  FROM (
    SELECT
      ri.id AS route_instance_id,
      sec.id AS loop_section_id,
      s.id AS loop_segment_id,
      NULLIF(s.source_segment_id, 0) AS segment_id,
      s.start_name,
      s.end_name,
      s.start_lat,
      s.start_lng,
      s.end_lat,
      s.end_lng,
      s.dist_nm AS base_dist_nm,
      s.lock_count,
      s.notes
    FROM route_instances ri
    INNER JOIN loop_sections sec
      ON sec.route_id = ri.generated_route_id
    INNER JOIN loop_segments s
      ON s.section_id = sec.id
    ORDER BY ri.id ASC, sec.order_index ASC, s.order_index ASC, s.id ASC
  ) src
  CROSS JOIN (SELECT @current_route_instance := 0, @leg_order := 0) vars
) ol
LEFT JOIN route_instance_sections ris
  ON ris.route_instance_id = ol.route_instance_id
 AND ris.source_section_id = ol.loop_section_id
LEFT JOIN route_instance_legs ril
  ON ril.route_instance_id = ol.route_instance_id
 AND ril.leg_order = ol.leg_order
WHERE ril.id IS NULL;

-- 4) Improve normalized segment link from route-level overrides where possible.
UPDATE route_instance_legs ril
INNER JOIN route_leg_user_overrides rluo
  ON rluo.route_leg_id = ril.source_loop_segment_id
SET ril.segment_id = rluo.segment_id
WHERE (ril.segment_id IS NULL OR ril.segment_id = 0)
  AND rluo.segment_id IS NOT NULL
  AND rluo.segment_id > 0;

-- 5) Backfill normalized progress rows from legacy user_route_progress.
INSERT INTO route_instance_leg_progress
  (user_id, route_instance_id, leg_order, status, completed_at)
SELECT
  CAST(up.user_id AS UNSIGNED) AS user_id,
  ril.route_instance_id,
  ril.leg_order,
  COALESCE(NULLIF(TRIM(up.status), ''), 'NOT_STARTED') AS status,
  up.completed_at
FROM user_route_progress up
INNER JOIN route_instance_legs ril
  ON ril.source_loop_segment_id = up.segment_id
LEFT JOIN route_instance_leg_progress rilp
  ON rilp.user_id = CAST(up.user_id AS UNSIGNED)
 AND rilp.route_instance_id = ril.route_instance_id
 AND rilp.leg_order = ril.leg_order
WHERE rilp.id IS NULL;

-- 6) Backfill segment-level overrides from legacy synthetic entries (route_id = 0).
INSERT INTO user_segment_overrides
  (user_id, segment_id, geometry_json, computed_nm, override_fields_json, created_at, updated_at)
SELECT
  rluo.user_id,
  rluo.segment_id,
  rluo.geometry_json,
  rluo.computed_nm,
  rluo.override_fields_json,
  rluo.created_at,
  rluo.updated_at
FROM route_leg_user_overrides rluo
WHERE rluo.route_id = 0
  AND rluo.segment_id IS NOT NULL
  AND rluo.segment_id > 0
ON DUPLICATE KEY UPDATE
  geometry_json = VALUES(geometry_json),
  computed_nm = VALUES(computed_nm),
  override_fields_json = VALUES(override_fields_json),
  updated_at = VALUES(updated_at);

-- Optional quick audit output.
SELECT 'route_instance_sections' AS table_name, COUNT(*) AS row_count FROM route_instance_sections
UNION ALL
SELECT 'route_instance_legs', COUNT(*) FROM route_instance_legs
UNION ALL
SELECT 'route_instance_leg_progress', COUNT(*) FROM route_instance_leg_progress
UNION ALL
SELECT 'user_segment_overrides', COUNT(*) FROM user_segment_overrides;
