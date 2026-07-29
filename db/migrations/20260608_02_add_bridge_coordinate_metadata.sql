-- Coordinate metadata for Great Loop bridge coordinate enrichment.
-- Stores source-backed coordinate provenance separately from navigation/source notes.

ALTER TABLE great_loop_bridges
  ADD COLUMN coordinate_source_url TEXT NULL AFTER import_batch_id,
  ADD COLUMN coordinate_source_name VARCHAR(255) NULL AFTER coordinate_source_url,
  ADD COLUMN coordinate_source_type VARCHAR(120) NULL AFTER coordinate_source_name,
  ADD COLUMN coordinate_confidence VARCHAR(120) NULL AFTER coordinate_source_type,
  ADD COLUMN coordinate_notes TEXT NULL AFTER coordinate_confidence,
  ADD COLUMN coordinate_verified_date DATE NULL AFTER coordinate_notes,
  ADD COLUMN coordinate_review_status VARCHAR(120) NULL AFTER coordinate_verified_date,
  ADD KEY idx_glb_coordinate_review_status (coordinate_review_status);
