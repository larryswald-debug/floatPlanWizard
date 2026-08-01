USE `FPW`;

SELECT DATABASE() AS selected_database, VERSION() AS database_version;

SELECT
  TABLE_NAME,
  ENGINE,
  TABLE_COLLATION
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'basic_review_send_receipts';

SELECT
  ORDINAL_POSITION,
  COLUMN_NAME,
  COLUMN_TYPE,
  IS_NULLABLE,
  COLUMN_KEY,
  EXTRA
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'basic_review_send_receipts'
ORDER BY ORDINAL_POSITION;

SELECT
  INDEX_NAME,
  NON_UNIQUE,
  SEQ_IN_INDEX,
  COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'FPW'
  AND TABLE_NAME = 'basic_review_send_receipts'
ORDER BY INDEX_NAME, SEQ_IN_INDEX;

SELECT
  tc.CONSTRAINT_NAME,
  tc.CONSTRAINT_TYPE,
  kcu.COLUMN_NAME,
  kcu.REFERENCED_TABLE_NAME,
  kcu.REFERENCED_COLUMN_NAME,
  rc.UPDATE_RULE,
  rc.DELETE_RULE
FROM information_schema.TABLE_CONSTRAINTS tc
LEFT JOIN information_schema.KEY_COLUMN_USAGE kcu
  ON kcu.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
 AND kcu.TABLE_NAME = tc.TABLE_NAME
 AND kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
LEFT JOIN information_schema.REFERENTIAL_CONSTRAINTS rc
  ON rc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
 AND rc.TABLE_NAME = tc.TABLE_NAME
 AND rc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
WHERE tc.CONSTRAINT_SCHEMA = 'FPW'
  AND tc.TABLE_NAME = 'basic_review_send_receipts'
ORDER BY tc.CONSTRAINT_TYPE, tc.CONSTRAINT_NAME, kcu.ORDINAL_POSITION;

SELECT
  CASE
    WHEN (
      SELECT COUNT(*)
      FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = 'FPW'
        AND TABLE_NAME = 'basic_review_send_receipts'
    ) = 14
    AND (
      SELECT COUNT(*)
      FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA = 'FPW'
        AND TABLE_NAME = 'basic_review_send_receipts'
        AND INDEX_NAME = 'uq_basic_review_send_receipts_idempotency'
        AND NON_UNIQUE = 0
    ) = 1
    AND (
      SELECT COUNT(*)
      FROM information_schema.REFERENTIAL_CONSTRAINTS
      WHERE CONSTRAINT_SCHEMA = 'FPW'
        AND TABLE_NAME = 'basic_review_send_receipts'
    ) = 2
    THEN 'PASS'
    ELSE 'FAIL'
  END AS verification_status;

SELECT
  status,
  COUNT(*) AS receipt_count
FROM basic_review_send_receipts
GROUP BY status
ORDER BY status;
