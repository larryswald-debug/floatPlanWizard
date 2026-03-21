-- Repair GREAT_LOOP_CCW continuity:
-- Existing break: section 1 ends at 'Ludington' and next section starts at 'Chicago'.
-- This adds a bridge segment so adjacency remains contiguous for full-loop generation.

SET @route_id := (
  SELECT id
  FROM loop_routes
  WHERE short_code = 'GREAT_LOOP_CCW'
  LIMIT 1
);

SET @section_id := (
  SELECT id
  FROM loop_sections
  WHERE route_id = @route_id
    AND short_code = 'GREAT_LAKES'
  LIMIT 1
);

INSERT INTO loop_segments (
  section_id,
  order_index,
  start_name,
  end_name,
  dist_nm,
  lock_count,
  rm_start,
  rm_end,
  is_signature_event,
  is_milestone_end,
  notes
)
SELECT
  @section_id,
  5,
  'Ludington',
  'Chicago',
  180.00,
  0,
  NULL,
  NULL,
  0,
  0,
  'Continuity bridge for GREAT_LOOP_CCW canonical template'
FROM DUAL
WHERE @section_id IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM loop_segments s4
    WHERE s4.section_id = @section_id
      AND s4.order_index = 4
      AND s4.end_name = 'Ludington'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM loop_segments s5
    WHERE s5.section_id = @section_id
      AND s5.order_index = 5
  );
