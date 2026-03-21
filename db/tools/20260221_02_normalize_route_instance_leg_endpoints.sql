-- Normalize route_instance_legs start/end names and coordinates from canonical segment_library + ports.
-- This fixes stale/coarse endpoint coordinates while preserving route direction (CW/CCW).
--
-- Safe run notes:
-- 1) Script creates a timestamped full backup table first.
-- 2) Scope is rows with segment_id > 0 only.

SET @fpw_backup_table = CONCAT('backup_route_instance_legs_endpoint_norm_', DATE_FORMAT(UTC_TIMESTAMP(), '%Y%m%d_%H%i%s'));
SET @fpw_backup_sql = CONCAT('CREATE TABLE `', @fpw_backup_table, '` AS SELECT * FROM route_instance_legs');
PREPARE fpw_stmt_backup FROM @fpw_backup_sql;
EXECUTE fpw_stmt_backup;
DEALLOCATE PREPARE fpw_stmt_backup;

SELECT @fpw_backup_table AS backup_table_created;

UPDATE route_instance_legs ril
INNER JOIN route_instances ri
    ON ri.id = ril.route_instance_id
INNER JOIN segment_library sl
    ON sl.id = ril.segment_id
LEFT JOIN ports p1
    ON p1.id = sl.start_port_id
LEFT JOIN ports p2
    ON p2.id = sl.end_port_id
SET
    ril.is_reversed = CASE
        WHEN UPPER(COALESCE(ri.direction, 'CCW')) = 'CW' THEN 1
        ELSE 0
    END,
    ril.start_name = CASE
        WHEN UPPER(COALESCE(ri.direction, 'CCW')) = 'CW'
            THEN COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '')
        ELSE COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '')
    END,
    ril.end_name = CASE
        WHEN UPPER(COALESCE(ri.direction, 'CCW')) = 'CW'
            THEN COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '')
        ELSE COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '')
    END,
    ril.start_lat = CASE
        WHEN UPPER(COALESCE(ri.direction, 'CCW')) = 'CW' THEN p2.lat
        ELSE p1.lat
    END,
    ril.start_lng = CASE
        WHEN UPPER(COALESCE(ri.direction, 'CCW')) = 'CW' THEN p2.lng
        ELSE p1.lng
    END,
    ril.end_lat = CASE
        WHEN UPPER(COALESCE(ri.direction, 'CCW')) = 'CW' THEN p1.lat
        ELSE p2.lat
    END,
    ril.end_lng = CASE
        WHEN UPPER(COALESCE(ri.direction, 'CCW')) = 'CW' THEN p1.lng
        ELSE p2.lng
    END
WHERE
    ril.segment_id IS NOT NULL
    AND ril.segment_id > 0;

SELECT ROW_COUNT() AS rows_updated;

SELECT COUNT(*) AS mapped_rows
FROM route_instance_legs ril
WHERE ril.segment_id IS NOT NULL
  AND ril.segment_id > 0;

SELECT COUNT(*) AS mismatch_after_normalization
FROM route_instance_legs ril
INNER JOIN route_instances ri
    ON ri.id = ril.route_instance_id
INNER JOIN segment_library sl
    ON sl.id = ril.segment_id
LEFT JOIN ports p1
    ON p1.id = sl.start_port_id
LEFT JOIN ports p2
    ON p2.id = sl.end_port_id
WHERE
    ril.segment_id IS NOT NULL
    AND ril.segment_id > 0
    AND (
        (
            UPPER(COALESCE(ri.direction, 'CCW')) = 'CW'
            AND (
                p2.lat IS NULL OR p2.lng IS NULL OR p1.lat IS NULL OR p1.lng IS NULL
                OR ril.start_lat IS NULL OR ril.start_lng IS NULL OR ril.end_lat IS NULL OR ril.end_lng IS NULL
                OR ABS(ril.start_lat - p2.lat) > 0.000001
                OR ABS(ril.start_lng - p2.lng) > 0.000001
                OR ABS(ril.end_lat - p1.lat) > 0.000001
                OR ABS(ril.end_lng - p1.lng) > 0.000001
            )
        )
        OR
        (
            UPPER(COALESCE(ri.direction, 'CCW')) <> 'CW'
            AND (
                p1.lat IS NULL OR p1.lng IS NULL OR p2.lat IS NULL OR p2.lng IS NULL
                OR ril.start_lat IS NULL OR ril.start_lng IS NULL OR ril.end_lat IS NULL OR ril.end_lng IS NULL
                OR ABS(ril.start_lat - p1.lat) > 0.000001
                OR ABS(ril.start_lng - p1.lng) > 0.000001
                OR ABS(ril.end_lat - p2.lat) > 0.000001
                OR ABS(ril.end_lng - p2.lng) > 0.000001
            )
        )
    );
