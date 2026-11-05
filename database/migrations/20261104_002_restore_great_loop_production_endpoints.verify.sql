USE `fpw`;
-- Read-only verification; select the intended database explicitly first.
SELECT DATABASE() AS selected_database;
SELECT p.id,p.name,p.state,p.lat,p.lng,pp.slug,pp.data_quality_status,pp.last_reviewed_at
FROM ports p JOIN port_profiles pp ON pp.port_id=p.id WHERE p.id IN (135,141,153,159,162,164,170,177,179,185) ORDER BY p.id;
SELECT lr.code,COUNT(*) AS total_legs,
 SUM(p1.id IS NOT NULL AND p2.id IS NOT NULL AND pp1.port_id IS NOT NULL AND pp2.port_id IS NOT NULL
 AND p1.lat BETWEEN -90 AND 90 AND p1.lng BETWEEN -180 AND 180
 AND p2.lat BETWEEN -90 AND 90 AND p2.lng BETWEEN -180 AND 180
 AND p1.lat<>0 AND p1.lng<>0 AND p2.lat<>0 AND p2.lng<>0) AS complete_endpoint_pairs
FROM loop_routes lr JOIN route_template_segments rts ON rts.route_id=lr.id
JOIN segment_library sl ON sl.id=rts.segment_id
LEFT JOIN ports p1 ON p1.id=sl.start_port_id LEFT JOIN ports p2 ON p2.id=sl.end_port_id
LEFT JOIN port_profiles pp1 ON pp1.port_id=p1.id LEFT JOIN port_profiles pp2 ON pp2.port_id=p2.id
WHERE lr.code='GREAT_LOOP_REUSABLE_V2' AND lr.short_code='GL_REUSE_V2' AND lr.is_active=1 AND lr.is_default=1
GROUP BY lr.id,lr.code;

-- Every saved leg endpoint must now reference a real port and profile.
SELECT COUNT(*) AS endpoint_references,
 SUM(p.id IS NULL) AS missing_ports,
 SUM(pp.port_id IS NULL) AS missing_profiles,
 SUM(p.lat IS NULL OR p.lng IS NULL OR p.lat=0 OR p.lng=0 OR ABS(p.lat)>90 OR ABS(p.lng)>180) AS invalid_coordinate_references
FROM (
 SELECT sl.start_port_id AS port_id FROM route_template_segments r
 JOIN segment_library sl ON sl.id=r.segment_id WHERE r.route_id=285
 UNION ALL
 SELECT sl.end_port_id FROM route_template_segments r
 JOIN segment_library sl ON sl.id=r.segment_id WHERE r.route_id=285
) refs
LEFT JOIN ports p ON p.id=refs.port_id
LEFT JOIN port_profiles pp ON pp.port_id=refs.port_id;
-- Expected: 112 endpoint references; 0 missing ports/profiles/invalid coordinates.
