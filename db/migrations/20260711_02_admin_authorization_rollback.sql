-- Roll back schema and the explicitly seeded initial ADMIN grant from 20260711_02_admin_authorization.sql.

UPDATE member_entitlements
SET status = 'revoked',
    revoked_at_utc = COALESCE(revoked_at_utc, UTC_TIMESTAMP()),
    revoked_by_user_id = COALESCE(revoked_by_user_id, 1),
    revocation_reason = COALESCE(NULLIF(revocation_reason, ''), 'Rollback of 20260711_02_admin_authorization.sql'),
    updated_by_user_id = 1,
    updated_utc = UTC_TIMESTAMP()
WHERE user_id = 1
  AND LOWER(entitlement_type) = 'admin'
  AND source = 'initial_admin_bootstrap'
  AND LOWER(status) = 'active'
  AND revoked_at_utc IS NULL;

SET @schema_name := DATABASE();

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'fpw_admin_audit_log'
      AND index_name = 'idx_fpw_admin_audit_request') > 0,
  'ALTER TABLE fpw_admin_audit_log DROP INDEX idx_fpw_admin_audit_request',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'fpw_admin_audit_log'
      AND column_name = 'success') > 0,
  'ALTER TABLE fpw_admin_audit_log DROP COLUMN success',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'fpw_admin_audit_log'
      AND column_name = 'request_id') > 0,
  'ALTER TABLE fpw_admin_audit_log DROP COLUMN request_id',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;


