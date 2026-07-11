-- FPW centralized ADMIN authorization support.
-- Adds request audit metadata and the explicitly approved initial ADMIN userId=1.

SET @schema_name := DATABASE();

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'fpw_admin_audit_log'
      AND column_name = 'request_id') = 0,
  'ALTER TABLE fpw_admin_audit_log ADD COLUMN request_id VARCHAR(64) NULL AFTER reason',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'fpw_admin_audit_log'
      AND column_name = 'success') = 0,
  'ALTER TABLE fpw_admin_audit_log ADD COLUMN success TINYINT(1) NOT NULL DEFAULT 1 AFTER request_id',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'fpw_admin_audit_log'
      AND index_name = 'idx_fpw_admin_audit_request') = 0,
  'ALTER TABLE fpw_admin_audit_log ADD INDEX idx_fpw_admin_audit_request (request_id, created_at_utc)',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Idempotent initial ADMIN grant explicitly approved for userId=1.
INSERT INTO member_entitlements (
  user_id, entitlement_type, source, status,
  starts_at_utc, expires_at_utc,
  created_by_user_id, updated_by_user_id,
  created_utc, updated_utc
)
SELECT
  u.userId, 'admin', 'initial_admin_bootstrap', 'active',
  UTC_TIMESTAMP(), NULL,
  u.userId, u.userId,
  UTC_TIMESTAMP(), UTC_TIMESTAMP()
FROM users u
WHERE u.userId = 1
  AND NOT EXISTS (
    SELECT 1
    FROM member_entitlements me
    WHERE me.user_id = u.userId
      AND LOWER(me.entitlement_type) = 'admin'
      AND LOWER(me.status) = 'active'
      AND me.starts_at_utc <= UTC_TIMESTAMP()
      AND (me.expires_at_utc IS NULL OR me.expires_at_utc > UTC_TIMESTAMP())
      AND me.revoked_at_utc IS NULL
  );

INSERT INTO fpw_admin_audit_log (
  admin_user_id, admin_email, action, entity_type, entity_id,
  previous_values_json, new_values_json, reason,
  request_id, success, created_at_utc
)
SELECT
  1, NULL, 'initial_admin_bootstrap', 'member_entitlement', CAST(me.id AS CHAR),
  NULL, JSON_OBJECT('userId', 1, 'entitlementType', 'admin', 'source', 'initial_admin_bootstrap'),
  'Explicitly approved initial ADMIN assignment.',
  'migration-20260711-admin-bootstrap', 1, UTC_TIMESTAMP()
FROM member_entitlements me
WHERE me.user_id = 1
  AND LOWER(me.entitlement_type) = 'admin'
  AND me.source = 'initial_admin_bootstrap'
  AND NOT EXISTS (
    SELECT 1
    FROM fpw_admin_audit_log al
    WHERE al.action = 'initial_admin_bootstrap'
      AND al.entity_type = 'member_entitlement'
      AND al.entity_id = CAST(me.id AS CHAR)
  )
ORDER BY me.id DESC
LIMIT 1;


