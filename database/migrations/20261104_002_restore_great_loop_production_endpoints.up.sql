-- APPROVED expanded Great Loop production repair. MariaDB 10.6.24 ONLY.
-- Supersedes restore-great-loop-endpoint-ports.sql for production.
-- Back up production ports, port_profiles, segment_library and
-- route_template_segments BEFORE running. The temporary snapshots below
-- provide transaction validation, not a durable production backup.
-- Use a fresh Workbench connection with Auto Commit enabled and no pending
-- transaction. Run this ENTIRE file, including DELIMITER lines; do not run
-- selected INSERT/UPDATE/COMMIT statements. Do not bypass a refused check.
-- This creates no stored procedure and requires no CREATE ROUTINE privilege.
-- All writes are in one transaction. A SQL error/warning rolls back this
-- script's transaction automatically; an existing transaction is left alone.
-- It inserts 10 ports + 10 profiles and changes only 42 endpoint ID fields
-- across 32 existing segment rows. All other segment fields are preserved.
-- Expected final result: COMMITTED,10,10,32,21,21,56.
-- Tested locally on the exact MariaDB version; not executed in production.

USE `fpw`;
DELIMITER $$
BEGIN NOT ATOMIC
 DECLARE v_owned_transaction BOOLEAN DEFAULT FALSE;
 DECLARE v_owns_temps BOOLEAN DEFAULT FALSE;
 DECLARE v_old_mode TEXT DEFAULT @@SESSION.sql_mode;
 DECLARE v_ports INT DEFAULT 0;
 DECLARE v_profiles INT DEFAULT 0;
 DECLARE v_segments INT DEFAULT 0;
 DECLARE v_complete INT DEFAULT 0;
 DECLARE v_failure_message TEXT;
 DECLARE v_failure_state CHAR(5);
 DECLARE EXIT HANDLER FOR SQLEXCEPTION, SQLWARNING
 BEGIN
   GET DIAGNOSTICS CONDITION 1 v_failure_message=MESSAGE_TEXT,v_failure_state=RETURNED_SQLSTATE;
   IF v_owned_transaction THEN ROLLBACK; END IF;
   IF v_owns_temps THEN
     DROP TEMPORARY TABLE IF EXISTS fpw_glfix_ports,fpw_glfix_profiles,fpw_glfix_map,fpw_glfix_route_before,fpw_glfix_segments_before,fpw_glfix_redirects_before,fpw_glfix_endpoint_ids,fpw_glfix_changes,fpw_glfix_memberships;
   END IF;
   SET SESSION sql_mode=v_old_mode;
   IF LEFT(v_failure_state,2)='01' THEN
     SET v_failure_message=LEFT(CONCAT('Repair rolled back after warning: ',v_failure_message),120);
     SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT=v_failure_message;
   END IF;
   RESIGNAL;
 END;

 -- Refuse before START TRANSACTION could commit unrelated pending work.
 IF @@in_transaction=1 OR @@autocommit<>1 THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use a fresh autocommit connection with no pending transaction; nothing was changed.';
 END IF;
 IF BINARY DATABASE()<>BINARY 'fpw' OR VERSION() NOT LIKE '10.6.24-MariaDB%' THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='This repair requires database fpw on MariaDB 10.6.24; nothing was changed.';
 END IF;
 SET SESSION sql_mode=CONCAT_WS(',',@@SESSION.sql_mode,'STRICT_ALL_TABLES');
 CREATE TEMPORARY TABLE fpw_glfix_ports LIKE ports;
 SET v_owns_temps=TRUE;
 CREATE TEMPORARY TABLE fpw_glfix_profiles LIKE port_profiles;
 CREATE TEMPORARY TABLE fpw_glfix_map(old_id INT PRIMARY KEY,new_id INT NOT NULL,expected_name VARCHAR(160) NOT NULL) ENGINE=InnoDB;
 CREATE TEMPORARY TABLE fpw_glfix_route_before LIKE route_template_segments;
 CREATE TEMPORARY TABLE fpw_glfix_memberships LIKE route_template_segments;
 CREATE TEMPORARY TABLE fpw_glfix_segments_before LIKE segment_library;
 CREATE TEMPORARY TABLE fpw_glfix_redirects_before LIKE port_slug_redirects;
 CREATE TEMPORARY TABLE fpw_glfix_endpoint_ids(port_id INT PRIMARY KEY) ENGINE=InnoDB;
 CREATE TEMPORARY TABLE fpw_glfix_changes(
   segment_id INT PRIMARY KEY,old_start INT,old_end INT,new_start INT,new_end INT,before_updated_at DATETIME
 ) ENGINE=InnoDB;
INSERT INTO fpw_glfix_ports (id,name,state,lat,lng,region,is_major_port,is_hidden_gem) VALUES
(135,'Joliet','IL','41.516866','-88.147963',NULL,0,0),
(141,'Cairo','IL','37.006288','-89.18288',NULL,0,0),
(153,'Sarasota','FL','27.294739','-82.433175',NULL,0,0),
(159,'West Palm Beach','FL','26.745114','-80.127038',NULL,0,0),
(162,'Savannah','GA','32.018043','-81.196492',NULL,0,0),
(164,'Charleston','SC','32.828017','-79.972896',NULL,0,0),
(170,'Norfolk','VA','36.923015','-76.244641',NULL,0,0),
(177,'New York','NY','40.662712','-73.938677',NULL,0,0),
(179,'Albany','NY','42.665745','-73.798353',NULL,0,0),
(185,'Detroit','MI','42.383037','-83.102237',NULL,0,0);
INSERT INTO fpw_glfix_profiles (loop_segment,created_at,approach_notes,mile_marker,data_quality_status,slug,state_code,port_type,country,short_description,last_reviewed_at,port_id,source_url,services_summary,updated_at,waterway,source_notes) VALUES
('Illinois / Mississippi / Ohio / Tennessee rivers','2026-07-05 00:00:00',NULL,NULL,'needs_review','135-joliet-il','IL','River stop / port town','United States','Joliet is a Great Loop ports-library location in Illinois. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.',NULL,135,NULL,NULL,'2026-07-05 00:00:00','Inland Rivers','Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Illinois / Mississippi / Ohio / Tennessee rivers','2026-07-05 00:00:00',NULL,NULL,'needs_review','141-cairo-il','IL','Route gateway','United States','Cairo is a Great Loop ports-library location in Illinois. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.',NULL,141,NULL,NULL,'2026-07-05 00:00:00','Inland Rivers','Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Florida Gulf Coast / Gulf ICW','2026-07-05 00:00:00',NULL,NULL,'needs_review','153-sarasota-fl','FL','Cruising stop / port town','United States','Sarasota is a Great Loop ports-library location in Florida. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.',NULL,153,NULL,NULL,'2026-07-05 00:00:00','Florida Gulf Coast','Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Florida Atlantic ICW','2026-07-05 00:00:00',NULL,NULL,'needs_review','159-west-palm-beach-fl','FL','Cruising stop / port town','United States','West Palm Beach is a Great Loop ports-library location in Florida. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.',NULL,159,NULL,NULL,'2026-07-05 00:00:00','Florida Atlantic Coast','Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Atlantic ICW','2026-07-05 00:00:00',NULL,NULL,'needs_review','162-savannah-ga','GA','Cruising stop / port town','United States','Savannah is a Great Loop ports-library location in Georgia. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.',NULL,162,NULL,NULL,'2026-07-05 00:00:00','Atlantic Intracoastal Waterway','Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Atlantic ICW','2026-07-05 00:00:00',NULL,NULL,'needs_review','164-charleston-sc','SC','Cruising stop / port town','United States','Charleston is a Great Loop ports-library location in South Carolina. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.',NULL,164,NULL,NULL,'2026-07-05 00:00:00','Atlantic Intracoastal Waterway','Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Lower Chesapeake / Atlantic ICW','2026-07-05 00:00:00',NULL,NULL,'needs_review','170-norfolk-va','VA','Route gateway','United States','Norfolk is a Great Loop ports-library location in Virginia. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.',NULL,170,NULL,NULL,'2026-07-05 00:00:00','Lower Chesapeake / ICW Mile 0','Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Hudson River / Erie Canal','2026-07-05 00:00:00',NULL,NULL,'needs_review','177-new-york-ny','NY','Route gateway','United States','New York is a Great Loop ports-library location in New York. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.',NULL,177,NULL,NULL,'2026-07-05 00:00:00','Hudson River / Erie Canal Gateway','Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Hudson River / Erie Canal','2026-07-05 00:00:00',NULL,NULL,'needs_review','179-albany-ny','NY','Cruising stop / port town','United States','Albany is a Great Loop ports-library location in New York. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.',NULL,179,NULL,NULL,'2026-07-05 00:00:00','Hudson River / Erie Canal Gateway','Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.'),
('Great Lakes / Lake Erie-Lake Huron corridor','2026-07-05 00:00:00',NULL,NULL,'needs_review','185-detroit-mi','MI','Cruising stop / port town','United States','Detroit is a Great Loop ports-library location in Michigan. Location data came from the FPW ports seed CSV; boater services and approach notes still need source-backed review.',NULL,185,NULL,NULL,'2026-07-05 00:00:00','Great Lakes','Seed CSV location record. State/country/segment/waterway/slug fields derived by FPW research workbook rules. Service fields intentionally left blank unless source-backed.');
INSERT INTO fpw_glfix_map VALUES
(137,38,'Peoria'),
(142,37,'Paducah'),
(146,15,'Demopolis'),
(147,29,'Mobile'),
(148,64,'Pensacola'),
(149,66,'Panama City'),
(150,68,'Carrabelle'),
(151,51,'Tarpon Springs'),
(154,19,'Fort Myers'),
(157,49,'Stuart'),
(158,108,'Fort Lauderdale'),
(161,112,'Jacksonville'),
(165,31,'Myrtle Beach'),
(171,45,'Solomons'),
(172,2,'Annapolis'),
(173,10,'Chesapeake City'),
(175,118,'Atlantic City'),
(182,127,'Buffalo'),
(183,128,'Erie'),
(184,129,'Cleveland'),
(186,27,'Mackinac Island');
IF NOT COALESCE(((SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='fpw' AND TABLE_NAME IN ('ports','port_profiles','segment_library','route_template_segments','loop_routes','port_slug_redirects') AND ENGINE='InnoDB')=6),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Required reference tables must all be InnoDB.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='fpw' AND TABLE_NAME='segment_library')=16),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unexpected segment_library schema; review before repair.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='fpw' AND EVENT_OBJECT_TABLE IN ('ports','port_profiles','segment_library'))=0),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unexpected trigger on a target table; review before repair.';
END IF;

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SET v_owned_transaction=TRUE;
-- Lock reference rows until validation and repair commit together.
SELECT id AS locked_template_id FROM loop_routes WHERE id=285 FOR UPDATE;
INSERT INTO fpw_glfix_route_before SELECT * FROM route_template_segments WHERE route_id=285 FOR UPDATE;
INSERT INTO fpw_glfix_segments_before
 SELECT sl.* FROM segment_library sl JOIN fpw_glfix_route_before r ON r.segment_id=sl.id FOR UPDATE;
INSERT INTO fpw_glfix_redirects_before
 SELECT d.* FROM port_slug_redirects d JOIN fpw_glfix_map m ON m.old_id=d.old_port_id FOR UPDATE;
INSERT INTO fpw_glfix_endpoint_ids
 SELECT sl.start_port_id FROM segment_library sl JOIN route_template_segments r ON r.segment_id=sl.id WHERE r.route_id=285
 UNION SELECT sl.end_port_id FROM segment_library sl JOIN route_template_segments r ON r.segment_id=sl.id WHERE r.route_id=285
 UNION SELECT new_id FROM fpw_glfix_map
 UNION SELECT id FROM fpw_glfix_ports;
SELECT id AS locked_port_id FROM ports WHERE id IN (SELECT port_id FROM fpw_glfix_endpoint_ids) FOR UPDATE;
SELECT port_id AS locked_profile_id FROM port_profiles WHERE port_id IN (SELECT port_id FROM fpw_glfix_endpoint_ids) FOR UPDATE;
SELECT port_id AS conflicting_slug_port_id FROM port_profiles WHERE slug IN (SELECT slug FROM fpw_glfix_profiles) FOR UPDATE;
IF NOT COALESCE(((SELECT COUNT(*) FROM loop_routes WHERE id=285 AND code='GREAT_LOOP_REUSABLE_V2' AND short_code='GL_REUSE_V2' AND is_active=1 AND is_default=1)=1 AND (SELECT COUNT(*) FROM loop_routes WHERE code='GREAT_LOOP_REUSABLE_V2' AND short_code='GL_REUSE_V2' AND is_active=1 AND is_default=1)=1),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='The expected active Great Loop template 285 is missing or ambiguous.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM fpw_glfix_route_before)=56 AND (SELECT COUNT(*) FROM fpw_glfix_segments_before)=56),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Expected 56 unique Great Loop legs/segments; source changed.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM ports WHERE id IN (135,141,153,159,162,164,170,177,179,185))=0 AND (SELECT COUNT(*) FROM port_profiles WHERE port_id IN (135,141,153,159,162,164,170,177,179,185))=0),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Original ten port/profile IDs are not all absent; no overwrite or repeat allowed.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM port_profiles p JOIN fpw_glfix_profiles s ON p.slug=s.slug)=0),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A restored profile slug conflicts with an existing profile.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM port_slug_redirects WHERE old_port_id IN (135,141,153,159,162,164,170,177,179,185))=0),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='An original restore ID now has a redirect; review instead of restoring it.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM ports WHERE id IN (137,142,146,147,148,149,150,151,154,157,158,161,165,171,172,173,175,182,183,184,186))=0),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A deduplicated old port ID exists again; do not remap it automatically.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM fpw_glfix_redirects_before)=21 AND (SELECT COUNT(DISTINCT old_port_id) FROM fpw_glfix_redirects_before)=21 AND (SELECT COUNT(*) FROM fpw_glfix_redirects_before d JOIN fpw_glfix_map m ON m.old_id=d.old_port_id AND m.new_id=d.canonical_port_id WHERE d.reason='ports_dedupe_20260708')=21),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='The 21 approved redirect mappings changed, duplicated, or are missing.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM fpw_glfix_map m JOIN ports p ON p.id=m.new_id JOIN port_profiles pp ON pp.port_id=p.id WHERE BINARY p.name=BINARY m.expected_name AND p.lat BETWEEN -90 AND 90 AND p.lng BETWEEN -180 AND 180 AND p.lat<>0 AND p.lng<>0)=21),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A canonical replacement port/profile/name/coordinate check failed.';
END IF;
SELECT COUNT(*) INTO v_complete FROM route_template_segments rts
 JOIN segment_library sl ON sl.id=rts.segment_id
 JOIN ports p1 ON p1.id=sl.start_port_id JOIN port_profiles pp1 ON pp1.port_id=p1.id
 JOIN ports p2 ON p2.id=sl.end_port_id JOIN port_profiles pp2 ON pp2.port_id=p2.id
 WHERE rts.route_id=285
 AND p1.lat BETWEEN -90 AND 90 AND p1.lng BETWEEN -180 AND 180 AND p1.lat<>0 AND p1.lng<>0
 AND p2.lat BETWEEN -90 AND 90 AND p2.lng BETWEEN -180 AND 180 AND p2.lat<>0 AND p2.lng<>0;
IF NOT COALESCE((v_complete=12),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Expected 12 complete legs before repair; production changed. Rerun discovery.';
END IF;

INSERT INTO fpw_glfix_changes
 SELECT b.id,b.start_port_id,b.end_port_id,CASE b.start_port_id WHEN 137 THEN 38 WHEN 142 THEN 37 WHEN 146 THEN 15 WHEN 147 THEN 29 WHEN 148 THEN 64 WHEN 149 THEN 66 WHEN 150 THEN 68 WHEN 151 THEN 51 WHEN 154 THEN 19 WHEN 157 THEN 49 WHEN 158 THEN 108 WHEN 161 THEN 112 WHEN 165 THEN 31 WHEN 171 THEN 45 WHEN 172 THEN 2 WHEN 173 THEN 10 WHEN 175 THEN 118 WHEN 182 THEN 127 WHEN 183 THEN 128 WHEN 184 THEN 129 WHEN 186 THEN 27 ELSE b.start_port_id END,CASE b.end_port_id WHEN 137 THEN 38 WHEN 142 THEN 37 WHEN 146 THEN 15 WHEN 147 THEN 29 WHEN 148 THEN 64 WHEN 149 THEN 66 WHEN 150 THEN 68 WHEN 151 THEN 51 WHEN 154 THEN 19 WHEN 157 THEN 49 WHEN 158 THEN 108 WHEN 161 THEN 112 WHEN 165 THEN 31 WHEN 171 THEN 45 WHEN 172 THEN 2 WHEN 173 THEN 10 WHEN 175 THEN 118 WHEN 182 THEN 127 WHEN 183 THEN 128 WHEN 184 THEN 129 WHEN 186 THEN 27 ELSE b.end_port_id END,b.updated_at
 FROM fpw_glfix_segments_before b WHERE b.start_port_id IN (137,142,146,147,148,149,150,151,154,157,158,161,165,171,172,173,175,182,183,184,186) OR b.end_port_id IN (137,142,146,147,148,149,150,151,154,157,158,161,165,171,172,173,175,182,183,184,186);
IF NOT COALESCE(((SELECT COUNT(*) FROM fpw_glfix_changes)=32 AND (SELECT SUM(NOT(old_start <=> new_start)) FROM fpw_glfix_changes)=21 AND (SELECT SUM(NOT(old_end <=> new_end)) FROM fpw_glfix_changes)=21),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Expected 32 affected segments and exactly 21 start plus 21 end corrections.';
END IF;
-- Lock all memberships for these segments, including index gaps. Under the
-- transaction's REPEATABLE READ isolation, another template cannot acquire
-- one of these segments between this scope check and commit.
INSERT INTO fpw_glfix_memberships SELECT * FROM route_template_segments
 WHERE segment_id IN (SELECT segment_id FROM fpw_glfix_changes) FOR UPDATE;
IF NOT COALESCE(((SELECT COUNT(*) FROM fpw_glfix_memberships WHERE route_id<>285)=0 AND (SELECT COUNT(*) FROM fpw_glfix_memberships)=32),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Affected segments are also used by another template; scope review required.';
END IF;

-- Exactly the approved twenty inserts, followed by one bounded UPDATE.
INSERT INTO ports (id,name,state,lat,lng,region,is_major_port,is_hidden_gem) SELECT id,name,state,lat,lng,region,is_major_port,is_hidden_gem FROM fpw_glfix_ports;
SET v_ports=ROW_COUNT();
INSERT INTO port_profiles (loop_segment,created_at,approach_notes,mile_marker,data_quality_status,slug,state_code,port_type,country,short_description,last_reviewed_at,port_id,source_url,services_summary,updated_at,waterway,source_notes) SELECT loop_segment,created_at,approach_notes,mile_marker,data_quality_status,slug,state_code,port_type,country,short_description,last_reviewed_at,port_id,source_url,services_summary,updated_at,waterway,source_notes FROM fpw_glfix_profiles;
SET v_profiles=ROW_COUNT();
UPDATE segment_library sl JOIN fpw_glfix_changes c ON c.segment_id=sl.id
 SET sl.start_port_id=c.new_start,sl.end_port_id=c.new_end,sl.updated_at=c.before_updated_at
 WHERE sl.start_port_id <=> c.old_start AND sl.end_port_id <=> c.old_end;
SET v_segments=ROW_COUNT();
IF NOT COALESCE((v_ports=10 AND v_profiles=10 AND v_segments=32),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unexpected write counts; the entire repair has been rolled back.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM ports p JOIN fpw_glfix_ports s ON p.id=s.id WHERE p.`id` <=> s.`id` AND p.`name` <=> s.`name` AND p.`state` <=> s.`state` AND p.`lat` <=> s.`lat` AND p.`lng` <=> s.`lng` AND p.`region` <=> s.`region` AND p.`is_major_port` <=> s.`is_major_port` AND p.`is_hidden_gem` <=> s.`is_hidden_gem`)=10),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Restored port values differ from the approved source.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM port_profiles p JOIN fpw_glfix_profiles s ON p.port_id=s.port_id WHERE p.`loop_segment` <=> s.`loop_segment` AND p.`created_at` <=> s.`created_at` AND p.`approach_notes` <=> s.`approach_notes` AND p.`mile_marker` <=> s.`mile_marker` AND p.`data_quality_status` <=> s.`data_quality_status` AND p.`slug` <=> s.`slug` AND p.`state_code` <=> s.`state_code` AND p.`port_type` <=> s.`port_type` AND p.`country` <=> s.`country` AND p.`short_description` <=> s.`short_description` AND p.`last_reviewed_at` <=> s.`last_reviewed_at` AND p.`port_id` <=> s.`port_id` AND p.`source_url` <=> s.`source_url` AND p.`services_summary` <=> s.`services_summary` AND p.`updated_at` <=> s.`updated_at` AND p.`waterway` <=> s.`waterway` AND p.`source_notes` <=> s.`source_notes`)=10),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Restored profile values differ from the approved source.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM segment_library p JOIN fpw_glfix_segments_before b ON p.id=b.id WHERE p.`id` <=> b.`id` AND p.`start_port_name` <=> b.`start_port_name` AND p.`end_port_name` <=> b.`end_port_name` AND p.`dist_nm` <=> b.`dist_nm` AND p.`lock_count` <=> b.`lock_count` AND p.`region` <=> b.`region` AND p.`is_offshore` <=> b.`is_offshore` AND p.`is_icw` <=> b.`is_icw` AND p.`exposure_level` <=> b.`exposure_level` AND p.`notes` <=> b.`notes` AND p.`created_at` <=> b.`created_at` AND p.`updated_at` <=> b.`updated_at` AND p.`wx_lat` <=> b.`wx_lat` AND p.`wx_lng` <=> b.`wx_lng`)=56),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A non-endpoint segment value changed; the repair has been rolled back.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM segment_library p JOIN fpw_glfix_changes c ON c.segment_id=p.id WHERE p.start_port_id <=> c.new_start AND p.end_port_id <=> c.new_end)=32),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Endpoint corrections did not match the approved mapping.';
END IF;
IF NOT COALESCE(((SELECT COUNT(*) FROM route_template_segments p JOIN fpw_glfix_route_before b ON p.id=b.id WHERE p.`id` <=> b.`id` AND p.`route_id` <=> b.`route_id` AND p.`segment_id` <=> b.`segment_id` AND p.`order_index` <=> b.`order_index` AND p.`is_optional` <=> b.`is_optional` AND p.`created_at` <=> b.`created_at` AND p.`updated_at` <=> b.`updated_at`)=56 AND (SELECT COUNT(*) FROM route_template_segments WHERE route_id=285)=56),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Route order or template membership changed; repair rolled back.';
END IF;
SELECT COUNT(*) INTO v_complete FROM route_template_segments rts
 JOIN segment_library sl ON sl.id=rts.segment_id
 JOIN ports p1 ON p1.id=sl.start_port_id JOIN port_profiles pp1 ON pp1.port_id=p1.id
 JOIN ports p2 ON p2.id=sl.end_port_id JOIN port_profiles pp2 ON pp2.port_id=p2.id
 WHERE rts.route_id=285
 AND p1.lat BETWEEN -90 AND 90 AND p1.lng BETWEEN -180 AND 180 AND p1.lat<>0 AND p1.lng<>0
 AND p2.lat BETWEEN -90 AND 90 AND p2.lng BETWEEN -180 AND 180 AND p2.lat<>0 AND p2.lng<>0;
IF NOT COALESCE((v_complete=56),FALSE) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Not all 56 endpoint pairs resolve after repair; all changes rolled back.';
END IF;

DROP TEMPORARY TABLE fpw_glfix_ports,fpw_glfix_profiles,fpw_glfix_map,fpw_glfix_route_before,fpw_glfix_segments_before,fpw_glfix_redirects_before,fpw_glfix_endpoint_ids,fpw_glfix_changes,fpw_glfix_memberships;
SET v_owns_temps=FALSE;
SET SESSION sql_mode=v_old_mode;
COMMIT;
SET v_owned_transaction=FALSE;
SELECT 'COMMITTED' AS restoration_result,v_ports AS ports_inserted,v_profiles AS profiles_inserted,
 v_segments AS segment_rows_updated,21 AS start_references_corrected,21 AS end_references_corrected,
 v_complete AS complete_endpoint_pairs;
END$$
DELIMITER ;
