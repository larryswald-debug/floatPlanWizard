-- Rollback for route generator normalization phase 1 backfill.
-- This removes rows that were backfilled from legacy route rows.

DELETE rilp
FROM route_instance_leg_progress rilp
INNER JOIN route_instance_legs ril
  ON ril.route_instance_id = rilp.route_instance_id
 AND ril.leg_order = rilp.leg_order
WHERE ril.source_loop_segment_id IS NOT NULL;

DELETE FROM route_instance_legs
WHERE source_loop_segment_id IS NOT NULL;

DELETE ris
FROM route_instance_sections ris
LEFT JOIN route_instance_legs ril
  ON ril.route_instance_section_id = ris.id
WHERE ris.source_section_id IS NOT NULL
  AND ril.id IS NULL;

UPDATE loop_segments s
INNER JOIN loop_sections sec
  ON sec.id = s.section_id
INNER JOIN route_instances ri
  ON ri.generated_route_id = sec.route_id
SET s.source_segment_id = NULL
WHERE s.source_segment_id IS NOT NULL;
