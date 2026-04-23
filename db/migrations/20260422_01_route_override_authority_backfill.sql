-- Backfill canonical segment overrides from legacy synthetic route_leg_user_overrides rows.
-- This is copy-forward only. Legacy route_id = 0 rows remain in place for fallback during rollout.

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

SELECT
  'legacy_segment_override_rows' AS metric,
  COUNT(*) AS value
FROM route_leg_user_overrides
WHERE route_id = 0

UNION ALL

SELECT
  'canonical_segment_override_rows' AS metric,
  COUNT(*) AS value
FROM user_segment_overrides;
