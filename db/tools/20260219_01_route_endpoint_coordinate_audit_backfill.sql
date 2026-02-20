-- Route endpoint coordinate audit + conservative backfill helper (FPW).
-- Safe for mixed collations by matching normalized MD5 keys instead of direct string '='.
--
-- What it does:
-- A) Canonical endpoint coverage audit from segment_library/segement_library -> ports
-- B) Generated route-leg endpoint coverage audit from loop_segments
-- C) Backfill missing start endpoint coords in loop_segments from unique ports.name matches
-- D) Backfill missing end endpoint coords in loop_segments from unique ports.name matches
-- E) Show unresolved route legs after backfill

USE FPW;

-- ---------------------------------------------------------------------------
-- A) Canonical coverage audit (auto-detect canonical segment table)
-- ---------------------------------------------------------------------------
SET @schema_name := DATABASE();
SET @canonical_table := (
  SELECT CASE
    WHEN EXISTS (
      SELECT 1
      FROM information_schema.tables
      WHERE table_schema = @schema_name
        AND table_name = 'segment_library'
    ) THEN 'segment_library'
    WHEN EXISTS (
      SELECT 1
      FROM information_schema.tables
      WHERE table_schema = @schema_name
        AND table_name = 'segement_library'
    ) THEN 'segement_library'
    ELSE ''
  END
);

SET @canonical_sql := IF(
  @canonical_table = '',
  'SELECT ''WARN'' AS status, ''No segment_library/segement_library table found; canonical audit skipped.'' AS message',
  CONCAT(
    'SELECT ',
    'sl.id AS segment_id, ',
    'COALESCE(p1.name, sl.start_port_name) AS start_name, ',
    'p1.id AS start_port_id, p1.lat AS start_lat, p1.lng AS start_lng, ',
    'COALESCE(p2.name, sl.end_port_name) AS end_name, ',
    'p2.id AS end_port_id, p2.lat AS end_lat, p2.lng AS end_lng ',
    'FROM `', @schema_name, '`.`', @canonical_table, '` sl ',
    'LEFT JOIN `', @schema_name, '`.ports p1 ON p1.id = sl.start_port_id ',
    'LEFT JOIN `', @schema_name, '`.ports p2 ON p2.id = sl.end_port_id ',
    'WHERE p1.id IS NULL OR p2.id IS NULL OR p1.lat IS NULL OR p1.lng IS NULL OR p2.lat IS NULL OR p2.lng IS NULL ',
    'ORDER BY sl.id'
  )
);

PREPARE canonical_stmt FROM @canonical_sql;
EXECUTE canonical_stmt;
DEALLOCATE PREPARE canonical_stmt;

-- ---------------------------------------------------------------------------
-- B) Route-leg coverage audit (current generated legs)
-- ---------------------------------------------------------------------------
SELECT
  r.short_code AS route_code,
  sec.route_id,
  s.id AS segment_id,
  sec.order_index AS section_order,
  s.order_index AS segment_order,
  s.start_name,
  s.start_lat,
  s.start_lng,
  s.end_name,
  s.end_lat,
  s.end_lng
FROM loop_segments s
INNER JOIN loop_sections sec ON sec.id = s.section_id
INNER JOIN loop_routes r ON r.id = sec.route_id
WHERE
  s.start_lat IS NULL
  OR s.start_lng IS NULL
  OR s.end_lat IS NULL
  OR s.end_lng IS NULL
ORDER BY sec.route_id, sec.order_index, s.order_index;

-- ---------------------------------------------------------------------------
-- C) Backfill start-point coords from unique ports.name matches
-- ---------------------------------------------------------------------------
UPDATE loop_segments s
INNER JOIN (
  SELECT
    MD5(LOWER(TRIM(CONVERT(name USING utf8mb4)))) AS normalized_key,
    MIN(lat) AS lat,
    MIN(lng) AS lng
  FROM ports
  WHERE
    name IS NOT NULL
    AND LENGTH(TRIM(name)) > 0
    AND lat IS NOT NULL
    AND lng IS NOT NULL
  GROUP BY MD5(LOWER(TRIM(CONVERT(name USING utf8mb4))))
  HAVING COUNT(*) = 1
) p
  ON MD5(LOWER(TRIM(CONVERT(s.start_name USING utf8mb4)))) = p.normalized_key
SET
  s.start_lat = COALESCE(s.start_lat, p.lat),
  s.start_lng = COALESCE(s.start_lng, p.lng)
WHERE
  s.start_name IS NOT NULL
  AND LENGTH(TRIM(s.start_name)) > 0
  AND (s.start_lat IS NULL OR s.start_lng IS NULL);

SELECT ROW_COUNT() AS start_endpoint_rows_updated;

-- ---------------------------------------------------------------------------
-- D) Backfill end-point coords from unique ports.name matches
-- ---------------------------------------------------------------------------
UPDATE loop_segments s
INNER JOIN (
  SELECT
    MD5(LOWER(TRIM(CONVERT(name USING utf8mb4)))) AS normalized_key,
    MIN(lat) AS lat,
    MIN(lng) AS lng
  FROM ports
  WHERE
    name IS NOT NULL
    AND LENGTH(TRIM(name)) > 0
    AND lat IS NOT NULL
    AND lng IS NOT NULL
  GROUP BY MD5(LOWER(TRIM(CONVERT(name USING utf8mb4))))
  HAVING COUNT(*) = 1
) p
  ON MD5(LOWER(TRIM(CONVERT(s.end_name USING utf8mb4)))) = p.normalized_key
SET
  s.end_lat = COALESCE(s.end_lat, p.lat),
  s.end_lng = COALESCE(s.end_lng, p.lng)
WHERE
  s.end_name IS NOT NULL
  AND LENGTH(TRIM(s.end_name)) > 0
  AND (s.end_lat IS NULL OR s.end_lng IS NULL);

SELECT ROW_COUNT() AS end_endpoint_rows_updated;

-- ---------------------------------------------------------------------------
-- E) Remaining unresolved route legs after backfill
-- ---------------------------------------------------------------------------
SELECT
  r.short_code AS route_code,
  sec.route_id,
  s.id AS segment_id,
  sec.order_index AS section_order,
  s.order_index AS segment_order,
  s.start_name,
  s.start_lat,
  s.start_lng,
  s.end_name,
  s.end_lat,
  s.end_lng
FROM loop_segments s
INNER JOIN loop_sections sec ON sec.id = s.section_id
INNER JOIN loop_routes r ON r.id = sec.route_id
WHERE
  s.start_lat IS NULL
  OR s.start_lng IS NULL
  OR s.end_lat IS NULL
  OR s.end_lng IS NULL
ORDER BY sec.route_id, sec.order_index, s.order_index;
