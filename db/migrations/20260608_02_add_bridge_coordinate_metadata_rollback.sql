-- Roll back Great Loop bridge coordinate metadata columns.

ALTER TABLE great_loop_bridges
  DROP KEY idx_glb_coordinate_review_status,
  DROP COLUMN coordinate_review_status,
  DROP COLUMN coordinate_verified_date,
  DROP COLUMN coordinate_notes,
  DROP COLUMN coordinate_confidence,
  DROP COLUMN coordinate_source_type,
  DROP COLUMN coordinate_source_name,
  DROP COLUMN coordinate_source_url;
