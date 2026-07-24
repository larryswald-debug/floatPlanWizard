USE `FPW`;

SELECT DATABASE() AS selected_database, VERSION() AS database_version;

SELECT
  INDEX_NAME,
  NON_UNIQUE,
  SEQ_IN_INDEX,
  COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'member_entitlements'
  AND INDEX_NAME = 'uq_member_entitlements_stripe_subscription'
ORDER BY SEQ_IN_INDEX;

SELECT
  stripe_subscription_id,
  COUNT(*) AS entitlement_count
FROM member_entitlements
WHERE stripe_subscription_id IS NOT NULL
  AND stripe_subscription_id <> ''
GROUP BY stripe_subscription_id
HAVING COUNT(*) > 1
ORDER BY stripe_subscription_id;

SET @fpw_verify_20260724_001_database_ok = DATABASE() = 'FPW';

SELECT COUNT(*) INTO @fpw_verify_20260724_001_index_ok
FROM (
  SELECT INDEX_NAME
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = 'FPW'
    AND TABLE_NAME = 'member_entitlements'
    AND INDEX_NAME = 'uq_member_entitlements_stripe_subscription'
  GROUP BY INDEX_NAME
  HAVING MIN(NON_UNIQUE) = 0
     AND COUNT(*) = 1
     AND MIN(SEQ_IN_INDEX) = 1
     AND MAX(SEQ_IN_INDEX) = 1
     AND MIN(COLUMN_NAME) = 'stripe_subscription_id'
     AND MAX(COLUMN_NAME) = 'stripe_subscription_id'
) exact_named_index;

SELECT COUNT(*) INTO @fpw_verify_20260724_001_duplicate_count
FROM (
  SELECT stripe_subscription_id
  FROM member_entitlements
  WHERE stripe_subscription_id IS NOT NULL
    AND stripe_subscription_id <> ''
  GROUP BY stripe_subscription_id
  HAVING COUNT(*) > 1
) duplicate_subscriptions;

SET @fpw_verify_20260724_001_status = IF(
  @fpw_verify_20260724_001_database_ok = 1
  AND @fpw_verify_20260724_001_index_ok = 1
  AND @fpw_verify_20260724_001_duplicate_count = 0,
  'PASS',
  'FAIL'
);

SELECT
  @fpw_verify_20260724_001_status AS verification_status,
  @fpw_verify_20260724_001_database_ok AS database_ok,
  @fpw_verify_20260724_001_index_ok AS unique_index_ok,
  @fpw_verify_20260724_001_duplicate_count AS duplicate_subscription_count;

SET @fpw_verify_20260724_001_guard_sql = IF(
  @fpw_verify_20260724_001_status = 'PASS',
  'DO 0',
  'SELECT `_fpw_verification_failed_20260724_001` FROM (SELECT 1 AS `ok`) AS `_fpw_guard`'
);
PREPARE fpw_verify_20260724_001_guard FROM @fpw_verify_20260724_001_guard_sql;
EXECUTE fpw_verify_20260724_001_guard;
DEALLOCATE PREPARE fpw_verify_20260724_001_guard;

SET @fpw_verify_20260724_001_database_ok = NULL;
SET @fpw_verify_20260724_001_index_ok = NULL;
SET @fpw_verify_20260724_001_duplicate_count = NULL;
SET @fpw_verify_20260724_001_status = NULL;
SET @fpw_verify_20260724_001_guard_sql = NULL;
