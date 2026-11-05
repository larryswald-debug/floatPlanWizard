-- Restore only the ten missing Great Loop port identities and matching profiles.
-- Approved Safest Fix: data only; no reference remapping or deletion-rule change.
-- Source: original 20260220 seed and retained July 2026 port staging records.
-- Select the database explicitly BEFORE execution: USE FPW; (development).
-- Production is a separate approval: USE fpw; only after production preflight/backup.
-- MySQL 8.0.16+ required. Execute as one batch, stop on first SQL error, never --force.
-- Use a fresh noninteractive client connection; an error must close that connection.
-- In a persistent SQL editor, explicitly ROLLBACK after ANY error; never COMMIT it.
-- Existing rows or conflicting slugs cause refusal; reruns do not overwrite.
-- Review status stays needs_review. Coordinates are unverified location references.

SET @fpw_restore_old_mode=@@SESSION.sql_mode;
SET SESSION sql_mode=CONCAT_WS(',',@@SESSION.sql_mode,'STRICT_ALL_TABLES');
CREATE TEMPORARY TABLE fpw_restore_ports LIKE ports;
CREATE TEMPORARY TABLE fpw_restore_profiles LIKE port_profiles;
CREATE TEMPORARY TABLE fpw_restore_assert (
    stage VARCHAR(120) NOT NULL,
    must_pass TINYINT NOT NULL,
    CONSTRAINT fpw_port_restore_required_check CHECK (must_pass=1)
) ENGINE=InnoDB;
INSERT INTO fpw_restore_ports (id,name,state,lat,lng,region,is_major_port,is_hidden_gem) VALUES
(135, 'Joliet', 'IL', '41.516866', '-88.147963', NULL, 0, 0),
(141, 'Cairo', 'IL', '37.006288', '-89.18288', NULL, 0, 0),
(153, 'Sarasota', 'FL', '27.294739', '-82.433175', NULL, 0, 0),
(159, 'West Palm Beach', 'FL', '26.745114', '-80.127038', NULL, 0, 0),
(162, 'Savannah', 'GA', '32.018043', '-81.196492', NULL, 0, 0),
(164, 'Charleston', 'SC', '32.828017', '-79.972896', NULL, 0, 0),
(170, 'Norfolk', 'VA', '36.923015', '-76.244641', NULL, 0, 0),
(177, 'New York', 'NY', '40.662712', '-73.938677', NULL, 0, 0),
(179, 'Albany', 'NY', '42.665745', '-73.798353', NULL, 0, 0),
(185, 'Detroit', 'MI', '42.383037', '-83.102237', NULL, 0, 0);
INSERT INTO fpw_restore_profiles (loop_segment,created_at,approach_notes,mile_marker,data_quality_status,slug,state_code,port_type,country,short_description,last_reviewed_at,port_id,source_url,services_summary,updated_at,waterway,source_notes) VALUES
('Illinois / Mississippi / Ohio / Tennessee rivers', '2026-07-05 00:00:00', NULL, NULL, 'needs_review', '135-joliet-il', 'IL', 'River stop / port town', 'United States', 'Joliet is a Great Loop ports-library location in Illinois. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.', NULL, 135, NULL, NULL, '2026-07-05 00:00:00', 'Inland Rivers', 'Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Illinois / Mississippi / Ohio / Tennessee rivers', '2026-07-05 00:00:00', NULL, NULL, 'needs_review', '141-cairo-il', 'IL', 'Route gateway', 'United States', 'Cairo is a Great Loop ports-library location in Illinois. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.', NULL, 141, NULL, NULL, '2026-07-05 00:00:00', 'Inland Rivers', 'Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Florida Gulf Coast / Gulf ICW', '2026-07-05 00:00:00', NULL, NULL, 'needs_review', '153-sarasota-fl', 'FL', 'Cruising stop / port town', 'United States', 'Sarasota is a Great Loop ports-library location in Florida. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.', NULL, 153, NULL, NULL, '2026-07-05 00:00:00', 'Florida Gulf Coast', 'Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Florida Atlantic ICW', '2026-07-05 00:00:00', NULL, NULL, 'needs_review', '159-west-palm-beach-fl', 'FL', 'Cruising stop / port town', 'United States', 'West Palm Beach is a Great Loop ports-library location in Florida. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.', NULL, 159, NULL, NULL, '2026-07-05 00:00:00', 'Florida Atlantic Coast', 'Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Atlantic ICW', '2026-07-05 00:00:00', NULL, NULL, 'needs_review', '162-savannah-ga', 'GA', 'Cruising stop / port town', 'United States', 'Savannah is a Great Loop ports-library location in Georgia. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.', NULL, 162, NULL, NULL, '2026-07-05 00:00:00', 'Atlantic Intracoastal Waterway', 'Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Atlantic ICW', '2026-07-05 00:00:00', NULL, NULL, 'needs_review', '164-charleston-sc', 'SC', 'Cruising stop / port town', 'United States', 'Charleston is a Great Loop ports-library location in South Carolina. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.', NULL, 164, NULL, NULL, '2026-07-05 00:00:00', 'Atlantic Intracoastal Waterway', 'Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Lower Chesapeake / Atlantic ICW', '2026-07-05 00:00:00', NULL, NULL, 'needs_review', '170-norfolk-va', 'VA', 'Route gateway', 'United States', 'Norfolk is a Great Loop ports-library location in Virginia. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.', NULL, 170, NULL, NULL, '2026-07-05 00:00:00', 'Lower Chesapeake / ICW Mile 0', 'Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Hudson River / Erie Canal', '2026-07-05 00:00:00', NULL, NULL, 'needs_review', '177-new-york-ny', 'NY', 'Route gateway', 'United States', 'New York is a Great Loop ports-library location in New York. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.', NULL, 177, NULL, NULL, '2026-07-05 00:00:00', 'Hudson River / Erie Canal Gateway', 'Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Hudson River / Erie Canal', '2026-07-05 00:00:00', NULL, NULL, 'needs_review', '179-albany-ny', 'NY', 'Cruising stop / port town', 'United States', 'Albany is a Great Loop ports-library location in New York. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.', NULL, 179, NULL, NULL, '2026-07-05 00:00:00', 'Hudson River / Erie Canal Gateway', 'Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Great Lakes / Lake Erie-Lake Huron corridor', '2026-07-05 00:00:00', NULL, NULL, 'needs_review', '185-detroit-mi', 'MI', 'Cruising stop / port town', 'United States', 'Detroit is a Great Loop ports-library location in Michigan. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.', NULL, 185, NULL, NULL, '2026-07-05 00:00:00', 'Great Lakes', 'Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.');

START TRANSACTION;
SELECT COUNT(*),MAX(id) INTO @fpw_restore_routes,@fpw_restore_route
FROM loop_routes WHERE code='GREAT_LOOP_REUSABLE_V2' AND short_code='GL_REUSE_V2' AND is_active=1 AND is_default=1;
SELECT COUNT(*) INTO @fpw_restore_legs FROM route_template_segments WHERE route_id=@fpw_restore_route;
SELECT COUNT(*) INTO @fpw_restore_affected FROM route_template_segments rts
JOIN segment_library sl ON sl.id=rts.segment_id WHERE rts.route_id=@fpw_restore_route
AND (sl.start_port_id IN (135,141,153,159,162,164,170,177,179,185) OR sl.end_port_id IN (135,141,153,159,162,164,170,177,179,185));
SET @fpw_restore_ok = BINARY DATABASE() IN ('FPW','fpw','fpw_port_restore_qa')
 AND @fpw_restore_routes=1 AND @fpw_restore_legs=56 AND @fpw_restore_affected=20
 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE()
      AND TABLE_NAME IN ('ports','port_profiles') AND ENGINE='InnoDB')=2
 AND (SELECT COUNT(*) FROM ports WHERE id IN (135,141,153,159,162,164,170,177,179,185))=0
 AND (SELECT COUNT(*) FROM port_profiles WHERE port_id IN (135,141,153,159,162,164,170,177,179,185))=0
 AND (SELECT COUNT(*) FROM port_profiles p JOIN fpw_restore_profiles s ON p.slug=s.slug)=0
 AND (SELECT COUNT(*) FROM port_slug_redirects WHERE old_port_id IN (135,141,153,159,162,164,170,177,179,185))=0
 AND (SELECT COUNT(*) FROM route_template_segments rts JOIN segment_library sl ON sl.id=rts.segment_id JOIN ports p1 ON p1.id=sl.start_port_id JOIN ports p2 ON p2.id=sl.end_port_id JOIN port_profiles pp1 ON pp1.port_id=p1.id JOIN port_profiles pp2 ON pp2.port_id=p2.id WHERE rts.route_id=@fpw_restore_route AND p1.lat BETWEEN -90 AND 90 AND p1.lng BETWEEN -180 AND 180 AND p2.lat BETWEEN -90 AND 90 AND p2.lng BETWEEN -180 AND 180 AND p1.lat<>0 AND p1.lng<>0 AND p2.lat<>0 AND p2.lng<>0)=36;
SELECT DATABASE() AS selected_database, @fpw_restore_ok AS preflight_pass,
       @fpw_restore_legs AS total_legs, @fpw_restore_affected AS affected_legs;
INSERT INTO fpw_restore_assert VALUES ('preflight: expected missing IDs, free slugs, original template, 36 complete pairs',IF(@fpw_restore_ok,1,0));

INSERT INTO ports (id,name,state,lat,lng,region,is_major_port,is_hidden_gem)
SELECT id,name,state,lat,lng,region,is_major_port,is_hidden_gem FROM fpw_restore_ports WHERE @fpw_restore_ok=1;
SET @fpw_restore_inserted_ports=ROW_COUNT();
INSERT INTO port_profiles (loop_segment,created_at,approach_notes,mile_marker,data_quality_status,slug,state_code,port_type,country,short_description,last_reviewed_at,port_id,source_url,services_summary,updated_at,waterway,source_notes)
SELECT loop_segment,created_at,approach_notes,mile_marker,data_quality_status,slug,state_code,port_type,country,short_description,last_reviewed_at,port_id,source_url,services_summary,updated_at,waterway,source_notes FROM fpw_restore_profiles WHERE @fpw_restore_ok=1 AND @fpw_restore_inserted_ports=10;
SET @fpw_restore_inserted_profiles=ROW_COUNT();

SET @fpw_restore_post_ok=@fpw_restore_ok AND @fpw_restore_inserted_ports=10 AND @fpw_restore_inserted_profiles=10
 AND (SELECT COUNT(*) FROM ports p JOIN fpw_restore_ports s ON p.id=s.id WHERE p.`id` <=> s.`id` AND p.`name` <=> s.`name` AND p.`state` <=> s.`state` AND p.`lat` <=> s.`lat` AND p.`lng` <=> s.`lng` AND p.`region` <=> s.`region` AND p.`is_major_port` <=> s.`is_major_port` AND p.`is_hidden_gem` <=> s.`is_hidden_gem`)=10
 AND (SELECT COUNT(*) FROM port_profiles p JOIN fpw_restore_profiles s ON p.port_id=s.port_id WHERE p.`loop_segment` <=> s.`loop_segment` AND p.`created_at` <=> s.`created_at` AND p.`approach_notes` <=> s.`approach_notes` AND p.`mile_marker` <=> s.`mile_marker` AND p.`data_quality_status` <=> s.`data_quality_status` AND p.`slug` <=> s.`slug` AND p.`state_code` <=> s.`state_code` AND p.`port_type` <=> s.`port_type` AND p.`country` <=> s.`country` AND p.`short_description` <=> s.`short_description` AND p.`last_reviewed_at` <=> s.`last_reviewed_at` AND p.`port_id` <=> s.`port_id` AND p.`source_url` <=> s.`source_url` AND p.`services_summary` <=> s.`services_summary` AND p.`updated_at` <=> s.`updated_at` AND p.`waterway` <=> s.`waterway` AND p.`source_notes` <=> s.`source_notes`)=10
 AND (SELECT COUNT(*) FROM route_template_segments rts JOIN segment_library sl ON sl.id=rts.segment_id JOIN ports p1 ON p1.id=sl.start_port_id JOIN ports p2 ON p2.id=sl.end_port_id JOIN port_profiles pp1 ON pp1.port_id=p1.id JOIN port_profiles pp2 ON pp2.port_id=p2.id WHERE rts.route_id=@fpw_restore_route AND p1.lat BETWEEN -90 AND 90 AND p1.lng BETWEEN -180 AND 180 AND p2.lat BETWEEN -90 AND 90 AND p2.lng BETWEEN -180 AND 180 AND p1.lat<>0 AND p1.lng<>0 AND p2.lat<>0 AND p2.lng<>0)=56;
INSERT INTO fpw_restore_assert VALUES ('postflight: exact ten ports and profiles restored; all 56 endpoint pairs resolve',IF(@fpw_restore_post_ok,1,0));
SET @fpw_restore_finish=IF(@fpw_restore_post_ok,'COMMIT','ROLLBACK');
PREPARE fpw_restore_transaction_end FROM @fpw_restore_finish;
EXECUTE fpw_restore_transaction_end;
DEALLOCATE PREPARE fpw_restore_transaction_end;
SELECT IF(@fpw_restore_post_ok,'COMMITTED','ROLLED_BACK') AS restoration_result,
       @fpw_restore_inserted_ports AS ports_inserted,@fpw_restore_inserted_profiles AS profiles_inserted;
DROP TEMPORARY TABLE fpw_restore_assert,fpw_restore_ports,fpw_restore_profiles;
SET SESSION sql_mode=@fpw_restore_old_mode;
