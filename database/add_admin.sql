INSERT INTO FPW.member_entitlements
    (user_id, entitlement_type, source, grant_kind, status, starts_at_utc, expires_at_utc, revoked_at_utc, admin_notes)
SELECT
    u.userId, 'admin', 'manual_admin', NULL, 'active', UTC_TIMESTAMP(), NULL, NULL,
    'Manual administrator access grant'
FROM FPW.users AS u
WHERE u.userId = 67
  AND NOT EXISTS (
      SELECT 1
      FROM FPW.member_entitlements AS me
      WHERE me.user_id = u.userId
        AND me.entitlement_type = 'admin'
        AND me.status = 'active'
        AND me.revoked_at_utc IS NULL
        AND (me.expires_at_utc IS NULL OR me.expires_at_utc > UTC_TIMESTAMP())
  );