-- Bahamas guide imports: additive metadata only; no shared destination seeds.
-- Select FPW/fpw explicitly. Run with a client that stops on errors.
SET @fpw_guide_guard = IF(BINARY DATABASE() IN ('FPW','fpw'), 'DO 0', 'SELECT `_fpw_guide_select_database_first`');
PREPARE fpw_guide_guard FROM @fpw_guide_guard;
EXECUTE fpw_guide_guard;
DEALLOCATE PREPARE fpw_guide_guard;
CREATE TABLE guide_route_imports (
 id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
 user_id INT NOT NULL,
 template_key VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 template_version INT NOT NULL,
 import_request_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 user_route_id INT NOT NULL,
 source_snapshot_json LONGTEXT NOT NULL,
 leg_state_json LONGTEXT NOT NULL,
 planning_inputs_json LONGTEXT NOT NULL,
 trip_notes LONGTEXT NOT NULL,
 draft_revision INT NOT NULL DEFAULT 1,
 generated_revision INT NOT NULL DEFAULT 0,
 generated_route_id INT NULL,
 generated_route_instance_id INT NULL,
 save_request_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
 save_payload_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
 request_history_json LONGTEXT NULL,
 created_at DATETIME NOT NULL,
 updated_at DATETIME NOT NULL,
 deleted_at DATETIME NULL,
 UNIQUE KEY uq_guide_import_request (user_id,import_request_id),
 UNIQUE KEY uq_guide_my_route (user_route_id),
 KEY ix_guide_member_template (user_id,template_key,template_version,deleted_at),
 KEY ix_guide_generated_instance (generated_route_instance_id),
 CONSTRAINT ck_guide_request_history CHECK (request_history_json IS NULL OR JSON_VALID(request_history_json)),
 CONSTRAINT ck_guide_versions CHECK (template_version > 0 AND draft_revision > 0 AND generated_revision >= 0),
 CONSTRAINT ck_guide_json CHECK (JSON_VALID(source_snapshot_json) AND JSON_VALID(leg_state_json) AND JSON_VALID(planning_inputs_json))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



